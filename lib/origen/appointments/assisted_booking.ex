defmodule Origen.Appointments.AssistedBooking do
  @moduledoc """
  Coordinación de reserva de turnos asistida por Secretaría para pacientes existentes (Issue #281 / #310).

  Permite a un integrante autenticado con rol `secretary` (los administradores están
  expresamente excluidos de crear turnos, contrato #309):
  - Consultar los profesionales activos del centro y sus agendas.
  - Consultar los tipos de consulta activos de cada profesional.
  - Consultar la disponibilidad diaria real y calcular slots de turnos.
  - Efectuar la reserva asistida para un paciente existente, respetando la modalidad
    de aprobación del profesional (automática -> :confirmed, manual -> :requested o :confirmed).
  - Garantizar la creación de la relación Profesional-Paciente durable.
  - Negar expresamente la facultad de Secretaría de aceptar o rechazar solicitudes (#284).
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias Origen.Appointments.Calendar
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Patients.PatientProfile
  alias Origen.Repo

  @doc """
  Lista todos los profesionales activos del centro aptos para reserva.
  """
  @spec list_professionals() :: {:ok, [map()]} | {:error, term()}
  def list_professionals, do: Calendar.list_professionals()

  @doc """
  Consulta la agenda diaria y slots calculados para un profesional y fecha dados,
  excluyendo automáticamente los turnos activos persistidos en esa fecha.
  """
  @spec get_daily_schedule(String.t() | integer(), Date.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_daily_schedule(professional_id, %Date{} = date, opts \\ []) do
    adapter = Keyword.get(opts, :calendar_adapter) || Calendar

    opts =
      case parse_id(professional_id) do
        {:ok, owner_id} ->
          existing_occ = Keyword.get(opts, :occupancies, [])
          db_occ = fetch_daily_occupancies(owner_id, date)
          Keyword.put(opts, :occupancies, existing_occ ++ db_occ)

        _ ->
          opts
      end

    adapter.get_daily_schedule(to_string(professional_id), date, opts)
  end

  @doc """
  Consulta los tipos de consulta activos de un profesional.
  """
  @spec list_consultation_types(integer() | String.t()) :: {:ok, [map()]} | {:error, term()}
  def list_consultation_types(professional_id) do
    with {:ok, owner_id} <- parse_id(professional_id) do
      query = """
      SELECT ct.id, ct.name, ct.exact_price_ars, ct.color, ct.interval_count, ct.status,
             COALESCE(s.interval_minutes, 30) AS agenda_interval
      FROM public.consultation_types ct
      LEFT JOIN public.agenda_settings s ON s.owner_account_id = ct.owner_account_id
      WHERE ct.owner_account_id = $1 AND ct.status = 'active'
      ORDER BY ct.name ASC
      """

      case SQL.query(Repo, query, [owner_id]) do
        {:ok, %{rows: rows}} ->
          types =
            Enum.map(rows, fn [id, name, price, color, intervals, status, agenda_interval] ->
              {:ok, uuid_str} = Ecto.UUID.load(id)

              %{
                id: uuid_str,
                name: name,
                exact_price_ars: price,
                color: color,
                interval_count: intervals,
                duration_minutes: intervals * agenda_interval,
                status: String.to_existing_atom(status)
              }
            end)

          {:ok, types}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Ejecuta la reserva asistida de un paciente existente por parte de Secretaría.
  """
  @spec reserve(integer(), integer(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def reserve(secretary_account_id, patient_profile_id, params, opts \\ []) do
    with :ok <- authorize_secretary(secretary_account_id),
         {:ok, profile} <- fetch_patient_profile(patient_profile_id),
         {:ok, prof_id} <- parse_id(params[:professional_id] || params["professional_id"]),
         :ok <- ensure_active_professional(prof_id),
         {:ok, consultation_type_id} <- validate_consultation_type_id(params),
         {:ok, start_time} <- resolve_start_time(params),
         :ok <-
           validate_slot_availability(prof_id, profile.id, consultation_type_id, start_time, opts) do
      # La modalidad de aprobación se resuelve estrictamente desde la configuración
      # persistida del profesional (public.agenda_settings) en el momento de reservar;
      # los parámetros del llamador (approval_mode / secretary_approval_mode) se ignoran
      # para impedir que Secretaría o el frontend amplíen su permiso (Contrato #321 §1).
      approval_cfg =
        case Booking.get_approval_configuration(prof_id) do
          {:ok, cfg} -> cfg
          _ -> %{approval_mode: :automatic, secretary_approval_mode: :confirmed}
        end

      status =
        if approval_cfg.approval_mode == :manual and
             approval_cfg.secretary_approval_mode == :requested do
          :requested
        else
          :confirmed
        end

      now = Keyword.get(opts, :now, DateTime.utc_now())

      request_attrs = %{
        actor: %{role: :secretary, id: secretary_account_id},
        patient_id: profile.id,
        professional_id: prof_id,
        consultation_type_id: consultation_type_id,
        start_time: start_time
      }

      booking_opts = [
        initial_status: status,
        now: now,
        create_relationship?: true,
        actor_role: :secretary
      ]

      case Booking.reserve_appointment(request_attrs, booking_opts) do
        {:ok, response} ->
          {:ok,
           %{
             appointment_id: response.appointment_id,
             patient_id: response.patient_id,
             professional_id: response.professional_id,
             consultation_type_id: response.consultation_type_id,
             consultation_type_name: response.consultation_type_name,
             start_time: response.start_time,
             end_time: response.end_time,
             status: response.status,
             duration_minutes: response.duration_minutes,
             price_ars: response.base_price_amount,
             relationship_created?: response.relationship_created?
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Retorna la modalidad de aprobación efectiva para Secretaría sobre un profesional
  (:confirmed o :requested).
  """
  @spec get_secretary_effective_approval_mode(integer() | String.t()) :: :confirmed | :requested
  def get_secretary_effective_approval_mode(professional_id) do
    case Booking.get_approval_configuration(professional_id) do
      {:ok, %{approval_mode: :manual, secretary_approval_mode: :requested}} -> :requested
      _ -> :confirmed
    end
  end

  @doc """
  Retorna la modalidad de aprobación configurada por el profesional (:automatic o :manual).
  """
  @spec get_professional_approval_mode(integer() | String.t()) :: :automatic | :manual
  def get_professional_approval_mode(professional_id) do
    with {:ok, owner_id} <- parse_id(professional_id) do
      query = """
      SELECT approval_mode FROM public.agenda_settings WHERE owner_account_id = $1
      """

      case SQL.query(Repo, query, [owner_id]) do
        {:ok, %{rows: [[mode]]}} when mode in ["manual", "automatic"] ->
          String.to_existing_atom(mode)

        _ ->
          :automatic
      end
    else
      _ -> :automatic
    end
  end

  @doc """
  Secretaría no tiene permiso para aceptar solicitudes pendientes (reservado a #284).
  """
  @spec approve_request(integer(), integer()) :: {:error, :unauthorized}
  def approve_request(secretary_account_id, _appointment_id) do
    case get_account_role(secretary_account_id) do
      {:ok, _role} -> {:error, :unauthorized}
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Secretaría no tiene permiso para rechazar solicitudes pendientes (reservado a #284).
  """
  @spec reject_request(integer(), integer()) :: {:error, :unauthorized}
  def reject_request(secretary_account_id, _appointment_id) do
    case get_account_role(secretary_account_id) do
      {:ok, _role} -> {:error, :unauthorized}
      _ -> {:error, :unauthorized}
    end
  end

  # Helpers privados

  defp authorize_secretary(account_id) when is_integer(account_id) do
    query = """
    SELECT role, state FROM public.internal_accounts
    WHERE id = $1 AND role = 'secretary' AND state = 'active'
    """

    case SQL.query(Repo, query, [account_id]) do
      {:ok, %{rows: [[_role, "active"]]}} -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  defp authorize_secretary(_), do: {:error, :unauthorized}

  defp ensure_active_professional(account_id) do
    query = """
    SELECT state FROM public.internal_accounts
    WHERE id = $1 AND role = 'professional' AND state = 'active'
    """

    case SQL.query(Repo, query, [account_id]) do
      {:ok, %{rows: [["active"]]}} -> :ok
      _ -> {:error, :invalid_professional}
    end
  end

  defp fetch_patient_profile(profile_id) when is_integer(profile_id) do
    case Repo.get(PatientProfile, profile_id) do
      %PatientProfile{} = profile -> {:ok, profile}
      nil -> {:error, :patient_not_found}
    end
  end

  defp fetch_patient_profile(_), do: {:error, :patient_not_found}

  defp parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {num, ""} when num > 0 -> {:ok, num}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}

  defp validate_consultation_type_id(params) do
    type_id = params[:consultation_type_id] || params["consultation_type_id"]

    case Ecto.UUID.cast(type_id) do
      {:ok, valid_uuid} -> {:ok, valid_uuid}
      :error -> {:error, :invalid_consultation_type_id}
    end
  end

  defp resolve_start_time(%{start_time: %DateTime{} = dt}), do: {:ok, dt}
  defp resolve_start_time(%{"start_time" => %DateTime{} = dt}), do: {:ok, dt}

  defp resolve_start_time(%{start_time: dt_str}) when is_binary(dt_str) do
    case DateTime.from_iso8601(dt_str) do
      {:ok, dt, _offset} -> {:ok, dt}
      _ -> {:error, :invalid_start_time}
    end
  end

  defp resolve_start_time(%{"start_time" => dt_str}) when is_binary(dt_str) do
    case DateTime.from_iso8601(dt_str) do
      {:ok, dt, _offset} -> {:ok, dt}
      _ -> {:error, :invalid_start_time}
    end
  end

  defp resolve_start_time(%{date: %Date{} = date, slot: slot}) when is_map(slot) do
    time_str = slot[:start_time] || slot["start_time"] || slot[:time] || slot["time"]
    build_datetime(date, time_str)
  end

  defp resolve_start_time(%{"date" => %Date{} = date, "slot" => slot}) when is_map(slot) do
    time_str = slot[:start_time] || slot["start_time"] || slot[:time] || slot["time"]
    build_datetime(date, time_str)
  end

  defp resolve_start_time(_), do: {:error, :missing_or_invalid_start_time}

  defp build_datetime(date, time_str) when is_binary(time_str) do
    case Time.from_iso8601(time_str <> ":00") do
      {:ok, time} -> DateTime.new(date, time, "Etc/UTC")
      _ -> {:error, :invalid_time_format}
    end
  end

  defp build_datetime(_date, _time), do: {:error, :invalid_time_format}

  defp get_account_role(account_id) when is_integer(account_id) do
    case SQL.query(Repo, "SELECT role FROM public.internal_accounts WHERE id = $1", [account_id]) do
      {:ok, %{rows: [[role]]}} -> {:ok, role}
      _ -> {:error, :not_found}
    end
  end

  defp get_account_role(_), do: {:error, :not_found}

  defp fetch_daily_occupancies(owner_id, %Date{} = date) when is_integer(owner_id) do
    start_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_day = DateTime.add(start_day, 1, :day)

    appointments =
      Repo.all(
        from a in Appointment,
          where: a.professional_account_id == ^owner_id,
          where: a.status not in ["cancelled", "rejected"],
          where: a.start_time < ^end_day and a.end_time > ^start_day
      )

    Enum.map(appointments, fn a ->
      s =
        if DateTime.compare(a.start_time, start_day) == :lt,
          do: ~T[00:00:00],
          else: DateTime.to_time(a.start_time)

      e =
        if DateTime.compare(a.end_time, end_day) != :lt,
          do: ~T[23:59:59.999999],
          else: DateTime.to_time(a.end_time)

      {s, e}
    end)
  end

  defp validate_slot_availability(prof_id, patient_id, consultation_type_id, start_time, opts) do
    with {:ok, types} <- list_consultation_types(prof_id),
         %{duration_minutes: duration} <- Enum.find(types, &(&1.id == consultation_type_id)) do
      date = DateTime.to_date(start_time)
      now = Keyword.get(opts, :now, DateTime.utc_now())

      schedule_opts = [
        duration_minutes: duration,
        now: now,
        calendar_adapter: Origen.Appointments.DatabaseCalendar
      ]

      case get_daily_schedule(prof_id, date, schedule_opts) do
        {:ok, %{slots: slots}} ->
          if Enum.any?(slots, &(Time.compare(&1.start_time, DateTime.to_time(start_time)) == :eq)) do
            :ok
          else
            case Booking.check_overlaps(%{
                   professional_account_id: prof_id,
                   patient_profile_id: patient_id,
                   start_time: start_time,
                   end_time: DateTime.add(start_time, duration, :minute)
                 }) do
              {:error, :professional_schedule_conflict} -> {:error, :slot_already_booked}
              {:error, :patient_schedule_conflict} -> {:error, :patient_schedule_conflict}
              _ -> {:error, :slot_unavailable}
            end
          end

        _ ->
          # Si el profesional no tiene agenda_settings configurada aún, se delega a Booking.reserve_appointment
          :ok
      end
    else
      nil -> {:error, :consultation_type_not_found}
      error -> error
    end
  end
end
