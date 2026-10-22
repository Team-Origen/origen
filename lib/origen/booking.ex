defmodule Origen.Booking do
  @moduledoc """
  Contexto de dominio para la gestión y operación de reservas de turnos (PLN-08).

  Implementa la validación sintáctica de contratos (Issue #62), la persistencia
  transaccional de turnos con snapshots históricos inmutables (Issue #63), las
  reglas de autorización por actor Paciente / Secretaría / Profesional (Issue #64),
  la prevención de solapamientos y concurrencia de turnos (Issue #65), la
  operación única y transaccional de reserva con relación Profesional-Paciente
  y auditoría append-only (Issue #66), y la consulta de agenda propia del
  Profesional autenticado con proyección no clínica (Issue #79 / PLN-10).
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Origen.Booking.Agenda
  alias Origen.Booking.Appointment
  alias Origen.Booking.Authorization
  alias Origen.Booking.Overlap
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Booking.RequestResolution
  alias Origen.Booking.ReservationRequest
  alias Origen.Booking.ReservationResponse
  alias Origen.Repo

  @initial_statuses [:requested, :reserved, :confirmed]

  @relationship_establishing_statuses [:reserved, :confirmed]

  @audit_event_insert """
  INSERT INTO public.audit_events
    (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
  VALUES ($1, $2, $3, $4, $5, $6)
  RETURNING id, recorded_at
  """

  @doc """
  Parsea y valida la estructura sintáctica de una solicitud de reserva conforme al contrato de entrada.

  Retorna `{:ok, %ReservationRequest{}}` si los datos estructurales son válidos.
  Retorna `{:error, {:malformed_request, errors}}` si la estructura es inválida.
  """
  @spec validate_request(term()) ::
          {:ok, ReservationRequest.t()} | {:error, {:malformed_request, keyword()}}
  def validate_request(attrs) do
    ReservationRequest.cast_and_validate(attrs)
  end

  @doc """
  Autoriza una solicitud de reserva evaluando los permisos del actor solicitante
  (Issue #64): paciente autónomo, secretaría asistida o profesional.

  Delega en `Origen.Booking.Authorization.authorize_reservation/1`.
  """
  @spec authorize_reservation(ReservationRequest.t() | map()) ::
          {:ok, map()} | {:error, atom()}
  defdelegate authorize_reservation(request_or_params), to: Authorization

  @doc """
  Valida que el intervalo `[start_time, end_time)` propuesto no solape turnos
  activos de la agenda del profesional ni de la del paciente (Issue #65).

  Delega en `Origen.Booking.Overlap.validate_no_overlap/1`: retorna
  `{:ok, :no_conflict}`, `{:error, :professional_schedule_conflict}` o
  `{:error, :patient_schedule_conflict}`.
  """
  @spec validate_no_overlap(map()) :: {:ok, :no_conflict} | {:error, atom()}
  defdelegate validate_no_overlap(attrs), to: Overlap

  @doc """
  Alias de `validate_no_overlap/1` expuesto como verbo descriptivo de la
  consulta de conflictos de agenda (Issue #65).
  """
  @spec check_overlaps(map()) :: {:ok, :no_conflict} | {:error, atom()}
  defdelegate check_overlaps(attrs), to: Overlap

  @doc """
  Consulta la agenda diaria de turnos propios del Profesional autenticado
  (Issue #79 / PLN-10).

  Deriva la identidad del Profesional exclusivamente de la sesión activa
  revalidada en el servidor (`Origen.Sessions.revalidate_principal/2`) y la
  autoriza con `Origen.Authorization.decide/1`; ningún parámetro del cliente
  puede ampliar el alcance hacia agendas ajenas. Proyecta únicamente horario,
  estado, tipo de consulta y datos de Paciente no clínicos.

  Delega en `Origen.Booking.Agenda.get_professional_agenda/2`: retorna
  `{:ok, %{date: date, professional_account_id: id, appointments: list}}` o
  falla cerrado con `{:error, :unauthorized}` / `{:error, :invalid_date}`.
  """
  @spec get_professional_agenda(map() | Origen.Sessions.InternalSession.t(), map()) ::
          {:ok, %{date: Date.t(), professional_account_id: integer(), appointments: [map()]}}
          | {:error, :unauthorized | :invalid_date}
  defdelegate get_professional_agenda(principal, params \\ %{}), to: Agenda

  @doc """
  Acepta una solicitud de turno pendiente (Issue #284 / #322). Exclusivo del profesional dueño.
  """
  defdelegate accept_request(actor_account_id, appointment_id), to: RequestResolution

  @doc """
  Rechaza una solicitud de turno pendiente (Issue #284 / #322), liberando el horario. Exclusivo del profesional dueño.
  """
  defdelegate reject_request(actor_account_id, appointment_id), to: RequestResolution

  @doc """
  Consulta la configuración de modalidad de aprobación del profesional (Issue #284 / #322).
  """
  defdelegate get_approval_configuration(professional_id), to: RequestResolution

  @doc """
  Actualiza la modalidad de aprobación y subconfiguración de secretaría del profesional (Issue #284 / #322).
  """
  defdelegate update_approval_configuration(professional_id, attrs), to: RequestResolution

  @doc """
  Persiste un turno en la base de datos copiando nombre, duración y precio del tipo
  de consulta como snapshots históricos inmutables propios (Issue #63).

  Acepta un mapa de atributos de turno y opcionalmente un mapa de snapshot precalculado
  o simulado para testing (`%{name: ..., duration_minutes: ..., exact_price_ars: ...}`).
  Si no se pasa snapshot explícito, lo resuelve de la persistencia de tipos de consulta.

  Previene solapamientos (Issue #65): verifica con `Origen.Booking.Overlap` que el
  intervalo `[start_time, end_time)` no solape turnos activos del profesional ni del
  paciente, y traduce las violaciones de las restricciones de exclusión de PostgreSQL
  (`appointments_no_professional_overlap` / `appointments_no_patient_overlap`) que
  sobrevivan a una carrera concurrente. Un conflicto de agenda del profesional retorna
  `{:error, :slot_already_booked}` y uno del paciente `{:error, :patient_schedule_conflict}`.

  Garantiza atomicidad transaccional: ante cualquier falla o restricción violada,
  no se deja registro parcial y se devuelve un error claro.
  """
  @spec persist_appointment(map(), map() | nil) ::
          {:ok, Appointment.t()} | {:error, term()}
  def persist_appointment(attrs, snapshot_override \\ nil) do
    try do
      Repo.transaction(fn ->
        case build_appointment(attrs, snapshot_override) do
          {:ok, appointment} -> appointment
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    rescue
      e in Postgrex.Error ->
        case e.postgres do
          %{pg_code: "40P01"} ->
            {:error, :slot_already_booked}

          %{pg_code: "40001"} ->
            {:error, :slot_already_booked}

          %{pg_code: "23P01", constraint: "appointments_no_patient_overlap"} ->
            {:error, :patient_schedule_conflict}

          %{pg_code: "23P01"} ->
            {:error, :slot_already_booked}

          _ ->
            reraise e, __STACKTRACE__
        end
    end
  end

  @doc """
  Ejecuta la operación única y transaccional de reserva (Issue #66 / PLN-08,
  `docs/booking/RESERVATION_CASES.md` §2.4).

  Encadena fail-fast: validación sintáctica del contrato (Issue #62),
  autorización del actor (Issue #64), determinación del estado inicial según
  actor y momento (RF-10 / RF-14) y una única transacción atómica que persiste
  el turno con snapshots históricos (Issue #63), valida solapamientos (Issue #65),
  establece la relación Profesional-Paciente cuando corresponde (RF-05) y emite
  el evento de auditoría append-only minimizado. Ante cualquier falla, la
  transacción entera se revierte: no quedan turnos huérfanos, relaciones
  espurias ni auditoría parcial.

  Opciones:

    - `:now` — instante de referencia para calcular el momento de la reserva
      (por defecto `DateTime.utc_now/0`); útil para pruebas determinísticas.
    - `:initial_status` — estado inicial explícito (`:requested`, `:reserved` o
      `:confirmed`); modela la aprobación manual del profesional (V02) y otros
      flujos que nacen con estado pactado.
    - `:fail_at` — inyección de falla para verificación transaccional (T02/T03):
      `:relationship` o `:audit_event`.

  Retorna `{:ok, %ReservationResponse{}}` con `relationship_created?` indicando
  si esta operación estableció la relación, o `{:error, reason}`.
  """
  @spec reserve_appointment(ReservationRequest.t() | map(), keyword()) ::
          {:ok, ReservationResponse.t()} | {:error, term()}
  def reserve_appointment(request_or_attrs, opts \\ [])

  def reserve_appointment(%ReservationRequest{} = request, opts) do
    with {:ok, authorization} <- authorize_reservation(request),
         {:ok, status} <- determine_initial_status(request, authorization.actor, opts) do
      execute_atomic_reservation(request, authorization, status, opts)
    end
  end

  def reserve_appointment(attrs, opts) when is_map(attrs) do
    case validate_request(attrs) do
      {:ok, %ReservationRequest{} = request} -> reserve_appointment(request, opts)
      {:error, _reason} = error -> error
    end
  end

  def reserve_appointment(_invalid_payload, _opts),
    do: {:error, {:malformed_request, [payload: {"must be a map", [validation: :cast]}]}}

  @doc """
  Construye un struct `ReservationResponse` a partir de un `Appointment` persistido.
  """
  @spec to_response(Appointment.t(), boolean()) :: ReservationResponse.t()
  def to_response(%Appointment{} = appt, relationship_created? \\ false) do
    %ReservationResponse{
      appointment_id: appt.id,
      patient_id: appt.patient_profile_id,
      professional_id: appt.professional_account_id,
      consultation_type_id: appt.consultation_type_id,
      start_time: appt.start_time,
      end_time: appt.end_time,
      status: String.to_existing_atom(appt.status),
      consultation_type_name: appt.snapshot_consultation_type_name,
      duration_minutes: appt.snapshot_duration_minutes,
      base_price_amount: appt.snapshot_exact_price_ars,
      relationship_created?: relationship_created?
    }
  end

  # Construcción y persistencia del turno (compartida por persist_appointment/2
  # y la transacción atómica de reserve_appointment/2). No usa Repo.rollback:
  # retorna `{:ok, appointment}` o `{:error, reason}` para que ambos llamadores
  # decidan la semántica de reversión.

  defp build_appointment(attrs, snapshot_override) do
    patient_id =
      attrs[:patient_profile_id] || attrs["patient_profile_id"] || attrs[:patient_id] ||
        attrs["patient_id"]

    professional_id =
      attrs[:professional_account_id] || attrs["professional_account_id"] ||
        attrs[:professional_id] || attrs["professional_id"]

    consultation_type_id = attrs[:consultation_type_id] || attrs["consultation_type_id"]
    start_time = attrs[:start_time] || attrs["start_time"]
    status = attrs[:status] || attrs["status"] || "reserved"

    snapshot =
      case snapshot_override do
        %{name: _, duration_minutes: _, exact_price_ars: _} = s ->
          {:ok, s}

        _ ->
          resolve_consultation_type_snapshot(consultation_type_id, professional_id)
      end

    case snapshot do
      {:ok, %{name: name, duration_minutes: duration, exact_price_ars: price}} ->
        case start_time do
          %DateTime{} ->
            end_time = DateTime.add(start_time, duration, :minute)

            appointment_params = %{
              patient_profile_id: patient_id,
              professional_account_id: professional_id,
              consultation_type_id: consultation_type_id,
              start_time: start_time,
              end_time: end_time,
              status: to_string(status),
              snapshot_consultation_type_name: name,
              snapshot_duration_minutes: duration,
              snapshot_exact_price_ars: price
            }

            case Overlap.validate_no_overlap(appointment_params) do
              {:ok, :no_conflict} ->
                %Appointment{}
                |> Appointment.changeset(appointment_params)
                |> Repo.insert()
                |> case do
                  {:ok, appointment} -> {:ok, appointment}
                  {:error, changeset} -> translate_appointment_error(changeset)
                end

              {:error, :professional_schedule_conflict} ->
                {:error, :slot_already_booked}

              {:error, :patient_schedule_conflict} ->
                {:error, :patient_schedule_conflict}

              {:error, reason} ->
                {:error, reason}
            end

          _invalid_start_time ->
            {:error, {:validation_error, :invalid_or_missing_start_time}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp translate_appointment_error(changeset) do
    cond do
      constraint_violation?(changeset, "appointments_no_professional_overlap") ->
        {:error, :slot_already_booked}

      constraint_violation?(changeset, "appointments_no_patient_overlap") ->
        {:error, :patient_schedule_conflict}

      true ->
        {:error, {:validation_error, changeset}}
    end
  end

  # Determinación del estado inicial (RF-10 / RF-14, §2.2)

  defp determine_initial_status(%ReservationRequest{} = request, %{role: role}, opts) do
    case Keyword.get(opts, :initial_status) do
      nil -> initial_status_by_moment(role, request.start_time, reservation_now(opts))
      explicit -> normalize_initial_status(explicit)
    end
  end

  defp normalize_initial_status(status) when status in @initial_statuses, do: {:ok, status}

  defp normalize_initial_status(status) when is_binary(status) do
    case Enum.find(@initial_statuses, &(Atom.to_string(&1) == status)) do
      nil -> {:error, {:invalid_initial_status, status}}
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_initial_status(invalid), do: {:error, {:invalid_initial_status, invalid}}

  defp reservation_now(opts) do
    case Keyword.get(opts, :now) do
      %DateTime{} = now -> now
      _default -> DateTime.utc_now()
    end
  end

  # El momento se mide sobre días UTC del turno: «antes de D-1» nace Reservado,
  # «durante D-1» nace Confirmado y el día D cierra la ventana autónoma del
  # paciente (`:corte_reserva_cerrado`, R04). Secretaría y Profesional operan
  # hasta el inicio del turno (RF-10).
  defp initial_status_by_moment(:patient, start_time, now) do
    appointment_day = DateTime.to_date(start_time)

    cond do
      DateTime.compare(now, start_of_day(appointment_day)) != :lt ->
        {:error, :corte_reserva_cerrado}

      DateTime.compare(now, start_of_day(Date.add(appointment_day, -1))) != :lt ->
        {:ok, :confirmed}

      true ->
        {:ok, :reserved}
    end
  end

  defp initial_status_by_moment(role, start_time, now) when role in [:secretary, :professional] do
    appointment_day = DateTime.to_date(start_time)

    if DateTime.compare(now, start_of_day(Date.add(appointment_day, -1))) == :lt do
      {:ok, :reserved}
    else
      {:ok, :confirmed}
    end
  end

  defp start_of_day(date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  # Transacción atómica de reserva (§2.4): turno + relación + auditoría.
  # Cualquier paso fallido revierte la transacción completa.

  defp execute_atomic_reservation(%ReservationRequest{} = request, authorization, status, opts) do
    attrs = %{
      patient_profile_id: request.patient_id,
      professional_account_id: request.professional_id,
      consultation_type_id: request.consultation_type_id,
      start_time: request.start_time,
      status: Atom.to_string(status)
    }

    multi =
      Multi.new()
      |> Multi.run(:appointment, fn _repo, _changes -> build_appointment(attrs, nil) end)
      |> Multi.run(:relationship, fn _repo, %{appointment: appointment} ->
        establish_relationship(appointment, status, opts)
      end)
      |> Multi.run(:audit_event, fn _repo, %{appointment: appointment} ->
        append_reservation_audit_event(authorization.actor, appointment, status, opts)
      end)

    try do
      case Repo.transaction(multi) do
        {:ok, %{appointment: appointment, relationship: relationship}} ->
          {:ok, to_response(appointment, relationship.created?)}

        {:error, _failed_operation, reason, _changes} ->
          {:error, reason}
      end
    rescue
      e in Postgrex.Error ->
        case e.postgres do
          %{pg_code: "40P01"} ->
            {:error, :slot_already_booked}

          %{pg_code: "40001"} ->
            {:error, :slot_already_booked}

          %{pg_code: "23P01", constraint: "appointments_no_patient_overlap"} ->
            {:error, :patient_schedule_conflict}

          %{pg_code: "23P01"} ->
            {:error, :slot_already_booked}

          _ ->
            reraise e, __STACKTRACE__
        end
    end
  end

  defp establish_relationship(%Appointment{} = appointment, status, opts) do
    establish_for_status? =
      status in @relationship_establishing_statuses or
        (status == :requested and
           (opts[:create_relationship?] == true or opts[:actor_role] == :secretary))

    cond do
      opts[:fail_at] == :relationship ->
        {:error, :relationship_insertion_failed}

      not establish_for_status? ->
        # Un turno nacido en :requested nunca crea relación en flujos autónomos históricos (§2.4 / V02).
        {:ok, %{relationship: nil, created?: false}}

      relationship_exists?(appointment.professional_account_id, appointment.patient_profile_id) ->
        {:ok, %{relationship: nil, created?: false}}

      true ->
        %ProfessionalPatientRelationship{}
        |> ProfessionalPatientRelationship.changeset(%{
          professional_account_id: appointment.professional_account_id,
          patient_profile_id: appointment.patient_profile_id,
          first_appointment_id: appointment.id
        })
        |> Repo.insert()
        |> case do
          {:ok, relationship} ->
            {:ok, %{relationship: relationship, created?: true}}

          {:error, %Ecto.Changeset{} = changeset} ->
            if constraint_violation?(
                 changeset,
                 "professional_patient_relationships_unique_pair"
               ) do
              # Carrera concurrente: otra transacción estableció la relación primero.
              {:ok, %{relationship: nil, created?: false}}
            else
              {:error, {:relationship_validation_error, changeset}}
            end
        end
    end
  end

  defp relationship_exists?(professional_account_id, patient_profile_id) do
    query =
      from(r in ProfessionalPatientRelationship,
        where: r.professional_account_id == ^professional_account_id,
        where: r.patient_profile_id == ^patient_profile_id,
        select: 1,
        limit: 1
      )

    Repo.one(query) == 1
  end

  # Auditoría append-only minimizada (§2.4.3): actor, entidad y resultado;
  # sin datos clínicos ni sensibles. La inserción viaja en la misma transacción.

  defp append_reservation_audit_event(actor, %Appointment{} = appointment, status, opts) do
    if opts[:fail_at] == :audit_event do
      {:error, :fallo_auditoria}
    else
      values = [
        Atom.to_string(actor.role),
        audit_actor_ref(actor),
        audit_event_name(status),
        "appointment",
        "appointment:#{appointment.id}",
        "succeeded"
      ]

      case Ecto.Adapters.SQL.query(Repo, @audit_event_insert, values) do
        {:ok, %{rows: [[id, recorded_at]]}} ->
          {:ok, %{id: id, recorded_at: recorded_at}}

        {:error, _reason} ->
          {:error, :fallo_auditoria}
      end
    end
  end

  defp audit_actor_ref(%{role: :patient, id: id}), do: "patient:#{id}"

  defp audit_actor_ref(%{role: role, id: id}) when role in [:secretary, :professional],
    do: "internal_account:#{id}"

  defp audit_event_name(:reserved), do: "appointment_reserved"
  defp audit_event_name(:confirmed), do: "appointment_confirmed"
  defp audit_event_name(:requested), do: "appointment_created"

  defp constraint_violation?(changeset, constraint_name) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
      Keyword.get(opts, :constraint_name) == constraint_name
    end)
  end

  defp resolve_consultation_type_snapshot(nil, _owner_id),
    do: {:error, :missing_consultation_type_id}

  defp resolve_consultation_type_snapshot(_type_id, nil), do: {:error, :missing_professional_id}

  defp resolve_consultation_type_snapshot(consultation_type_id, professional_id) do
    with {:ok, uuid_bin} <- Ecto.UUID.dump(consultation_type_id) do
      query = """
      SELECT
        ct.name,
        ct.exact_price_ars,
        ct.status,
        ct.interval_count,
        ct.inactive_duration_minutes,
        COALESCE(s.interval_minutes, 30) AS agenda_interval
      FROM public.consultation_types ct
      LEFT JOIN public.agenda_settings s ON s.owner_account_id = ct.owner_account_id
      WHERE ct.id = $1 AND ct.owner_account_id = $2
      """

      case Ecto.Adapters.SQL.query(Repo, query, [uuid_bin, professional_id]) do
        {:ok, %{rows: [[name, price, "active", interval_count, _inactive_dur, agenda_interval]]}} ->
          duration = interval_count * agenda_interval
          {:ok, %{name: name, duration_minutes: duration, exact_price_ars: price}}

        {:ok, %{rows: [[_name, _price, "inactive", _count, _dur, _interval]]}} ->
          {:error, :consultation_type_inactive}

        {:ok, %{rows: []}} ->
          {:error, :consultation_type_not_found}

        {:error, reason} ->
          {:error, reason}
      end
    else
      :error ->
        {:error, :invalid_consultation_type_id}
    end
  end
end
