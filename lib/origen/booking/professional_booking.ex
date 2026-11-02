defmodule Origen.Booking.ProfessionalBooking do
  @moduledoc """
  Orquestación de reservas creadas por el Profesional desde su propia agenda.

  La cuenta propietaria se deriva de una sesión interna revalidada y nunca de
  parámetros del cliente. La selección puede ser un paciente previamente
  relacionado o un paciente registrado cuyo DNI exacto acompañe la
  confirmación. El turno siempre nace confirmado y reutiliza el motor
  transaccional compartido de reservas.
  """

  import Ecto.Query
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.Appointments.{AssistedBooking, DatabaseCalendar}
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @doc """
  Confirma un turno en la agenda del Profesional autenticado.

  `params` recibe `patient_id`, `consultation_type_id`, `start_time` y,
  únicamente para un paciente todavía no relacionado, `patient_document_number`
  con el DNI exacto usado en la selección. Cualquier identificador profesional
  enviado por el cliente se ignora.
  """
  @spec reserve(map() | InternalSession.t(), map(), keyword()) ::
          {:ok, Origen.Booking.ReservationResponse.t()} | {:error, term()}
  def reserve(principal, params, opts \\ [])

  def reserve(principal, params, opts) when is_map(params) and is_list(opts) do
    Repo.transaction(fn ->
      with {:ok, professional_id} <- resolve_professional(principal) do
        # Hold the agenda row until commit: settings edits and other confirmations
        # cannot invalidate availability between checking it and persisting.
        Repo.query!(
          "SELECT owner_account_id FROM agenda_settings WHERE owner_account_id = $1 FOR UPDATE",
          [professional_id]
        )

        Repo.query!("SELECT id FROM consultation_types WHERE owner_account_id = $1 FOR SHARE", [
          professional_id
        ])

        request = %{
          actor: %{role: :professional, id: professional_id},
          patient_id: param(params, :patient_id),
          professional_id: professional_id,
          consultation_type_id: param(params, :consultation_type_id),
          start_time: param(params, :start_time),
          patient_document_number: param(params, :patient_document_number)
        }

        with {:ok, validated} <- Booking.validate_request(request),
             {:ok, _authorization} <- Booking.authorize_reservation(validated),
             :ok <- validate_slot(professional_id, validated, opts) do
          Booking.reserve_appointment(validated, Keyword.put(opts, :initial_status, :confirmed))
        end
      end
      |> case do
        {:ok, response} -> response
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def reserve(_principal, _params, _opts), do: {:error, :unauthorized}

  @doc "Lista únicamente el catálogo activo del dueño de la sesión."
  def list_consultation_types(principal) do
    with {:ok, owner} <- resolve_professional(principal) do
      AssistedBooking.list_consultation_types(owner)
    end
  end

  @doc "Consulta slots reales propios, excluyendo turnos activos persistidos."
  def get_schedule(principal, type_id, date, opts \\ []) do
    with {:ok, owner} <- resolve_professional(principal) do
      schedule(owner, type_id, date, opts)
    end
  end

  defp schedule(owner, type_id, %Date{} = date, opts) do
    with {:ok, types} <- AssistedBooking.list_consultation_types(owner),
         %{duration_minutes: duration} <- Enum.find(types, &(&1.id == type_id)) do
      start_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      end_day = DateTime.add(start_day, 1, :day)

      appointments =
        Repo.all(
          from a in Appointment,
            where: a.professional_account_id == ^owner,
            where: a.status not in ["cancelled", "rejected"],
            where: a.start_time < ^end_day and a.end_time > ^start_day
        )

      occupancies =
        Enum.map(appointments, fn a ->
          start_time =
            if DateTime.compare(a.start_time, start_day) == :lt,
              do: ~T[00:00:00],
              else: DateTime.to_time(a.start_time)

          end_time =
            if DateTime.compare(a.end_time, end_day) != :lt,
              do: ~T[23:59:59.999999],
              else: DateTime.to_time(a.end_time)

          {start_time, end_time}
        end)

      DatabaseCalendar.get_daily_schedule(owner, date,
        duration_minutes: duration,
        occupancies: occupancies,
        now: Keyword.get(opts, :now, DateTime.utc_now())
      )
    else
      nil -> {:error, :consultation_type_not_found}
      error -> error
    end
  end

  defp schedule(_owner, _type_id, _date, _opts), do: {:error, :invalid_date}

  defp validate_slot(owner, request, opts) do
    with {:ok, schedule} <-
           schedule(
             owner,
             request.consultation_type_id,
             DateTime.to_date(request.start_time),
             opts
           ) do
      if Enum.any?(
           schedule.slots,
           &(Time.compare(
               &1.start_time,
               DateTime.to_time(request.start_time)
             ) == :eq)
         ) do
        :ok
      else
        case Booking.check_overlaps(%{
               professional_account_id: owner,
               patient_profile_id: request.patient_id,
               start_time: request.start_time,
               end_time: DateTime.add(request.start_time, 1, :second)
             }) do
          {:error, :professional_schedule_conflict} -> {:error, :slot_already_booked}
          _ -> {:error, :slot_unavailable}
        end
      end
    end
  end

  defp resolve_professional(%InternalSession{id: session_id, account_id: account_id}),
    do: resolve_professional(%{session_id: session_id, account_id: account_id})

  defp resolve_professional(%{session_id: session_id, account_id: account_id})
       when is_integer(session_id) and is_integer(account_id) do
    case Sessions.revalidate_principal(session_id, account_id) do
      {:ok, %{account_id: professional_id, role: :professional}} ->
        {:ok, professional_id}

      _denied ->
        {:error, :unauthorized}
    end
  end

  defp resolve_professional(_principal), do: {:error, :unauthorized}

  defp param(params, key), do: Map.get(params, key, Map.get(params, Atom.to_string(key)))
end
