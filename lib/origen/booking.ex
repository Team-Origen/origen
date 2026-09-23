defmodule Origen.Booking do
  @moduledoc """
  Contexto de dominio para la gestión y operación de reservas de turnos (PLN-08).

  Implementa la validación sintáctica de contratos (Issue #62), la persistencia
  transaccional de turnos con snapshots históricos inmutables (Issue #63) y las
  reglas de autorización por actor Paciente / Secretaría / Profesional (Issue #64).
  """

  alias Origen.Booking.Appointment
  alias Origen.Booking.Authorization
  alias Origen.Booking.ReservationRequest
  alias Origen.Booking.ReservationResponse
  alias Origen.Repo

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
  Persiste un turno en la base de datos copiando nombre, duración y precio del tipo
  de consulta como snapshots históricos inmutables propios (Issue #63).

  Acepta un mapa de atributos de turno y opcionalmente un mapa de snapshot precalculado
  o simulado para testing (`%{name: ..., duration_minutes: ..., exact_price_ars: ...}`).
  Si no se pasa snapshot explícito, lo resuelve de la persistencia de tipos de consulta.

  Garantiza atomicidad transaccional: ante cualquier falla o restricción violada,
  no se deja registro parcial y se devuelve un error claro.
  """
  @spec persist_appointment(map(), map() | nil) ::
          {:ok, Appointment.t()} | {:error, term()}
  def persist_appointment(attrs, snapshot_override \\ nil) do
    Repo.transaction(fn ->
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

              %Appointment{}
              |> Appointment.changeset(appointment_params)
              |> Repo.insert()
              |> case do
                {:ok, appointment} ->
                  appointment

                {:error, changeset} ->
                  Repo.rollback({:validation_error, changeset})
              end

            _invalid_start_time ->
              Repo.rollback({:validation_error, :invalid_or_missing_start_time})
          end

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

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
