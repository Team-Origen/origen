defmodule Origen.Booking.Overlap do
  @moduledoc """
  Reglas de dominio de prevención de solapamientos de turnos (Issue #65 / PLN-08).

  Espejo exacto de las restricciones de exclusión PostgreSQL instaladas por la
  migración `20260927100000_add_appointment_overlap_exclusion_constraints`:

  - **Agenda del profesional**: ningún par de turnos activos del mismo
    profesional puede solaparse en el intervalo semiabierto `[start_time, end_time)`.
  - **Agenda del paciente**: ningún par de turnos activos del mismo paciente
    puede solaparse en `[start_time, end_time)`, incluso con distintos
    profesionales.

  Turno activo: `status NOT IN ('cancelled', 'rejected')`. La semántica `[)`
  permite turnos contiguos (09:00-09:30 y 09:30-10:00); los turnos cancelados
  o rechazados liberan el bloque horario.

  Esta verificación es una precondición amigable para fallear temprano con un
  error de dominio claro. La garantía definitiva ante reservas concurrentes la
  da la restricción de exclusión de la base de datos, que `persist_appointment/2`
  traduce a los mismos átomos de error.
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Booking.Appointment
  alias Origen.Repo

  @slot_freeing_statuses ~w(cancelled rejected)

  @type conflict_reason :: :professional_schedule_conflict | :patient_schedule_conflict

  @doc """
  Valida que el intervalo `[start_time, end_time)` propuesto no solape turnos
  activos ni de la agenda del profesional ni de la del paciente.

  Acepta un mapa con `professional_account_id` (o `professional_id`),
  `patient_profile_id` (o `patient_id`), `start_time` y `end_time`, con claves
  atom o string.

  Retorna `{:ok, :no_conflict}` si el intervalo está libre; `{:error,
  :professional_schedule_conflict}` si el profesional ya tiene un turno activo
  solapado; `{:error, :patient_schedule_conflict}` si el paciente ya tiene un
  turno activo solapado (aunque sea con otro profesional); o `{:error,
  :invalid_overlap_params}` si faltan atributos o son de tipo inválido.
  """
  @spec validate_no_overlap(map()) ::
          {:ok, :no_conflict} | {:error, conflict_reason() | :invalid_overlap_params}
  def validate_no_overlap(attrs) when is_map(attrs) do
    with {:ok, params} <- extract_params(attrs),
         :ok <- reject_scope_conflict(params, :professional_account_id),
         :ok <- reject_scope_conflict(params, :patient_profile_id) do
      {:ok, :no_conflict}
    end
  end

  def validate_no_overlap(_attrs), do: {:error, :invalid_overlap_params}

  @doc """
  Alias de `validate_no_overlap/1` conservado como verbo descriptivo de la
  consulta de conflictos de agenda.
  """
  @spec check_overlaps(map()) ::
          {:ok, :no_conflict} | {:error, conflict_reason() | :invalid_overlap_params}
  def check_overlaps(attrs), do: validate_no_overlap(attrs)

  defp extract_params(attrs) do
    with {:ok, professional_id} <- fetch_id(attrs, :professional_account_id, :professional_id),
         {:ok, patient_id} <- fetch_id(attrs, :patient_profile_id, :patient_id),
         {:ok, start_time} <- fetch_datetime(attrs, :start_time),
         {:ok, end_time} <- fetch_datetime(attrs, :end_time),
         :ok <- ensure_end_after_start(start_time, end_time) do
      {:ok,
       %{
         professional_account_id: professional_id,
         patient_profile_id: patient_id,
         start_time: start_time,
         end_time: end_time
       }}
    end
  end

  defp reject_scope_conflict(params, scope_field) do
    conflict_reason =
      if scope_field == :professional_account_id,
        do: :professional_schedule_conflict,
        else: :patient_schedule_conflict

    query =
      from a in Appointment,
        where: field(a, ^scope_field) == ^Map.fetch!(params, scope_field),
        where: a.status not in ^@slot_freeing_statuses,
        where: a.start_time < ^params.end_time and a.end_time > ^params.start_time,
        limit: 1

    case Repo.one(query) do
      %Appointment{} -> {:error, conflict_reason}
      nil -> :ok
    end
  end

  defp fetch_id(attrs, primary_key, fallback_key) do
    case fetch(attrs, primary_key) || fetch(attrs, fallback_key) do
      id when is_integer(id) -> {:ok, id}
      _other -> {:error, :invalid_overlap_params}
    end
  end

  defp fetch_datetime(attrs, key) do
    case fetch(attrs, key) do
      %DateTime{} = datetime -> {:ok, datetime}
      _other -> {:error, :invalid_overlap_params}
    end
  end

  defp ensure_end_after_start(start_time, end_time) do
    if DateTime.compare(end_time, start_time) == :gt,
      do: :ok,
      else: {:error, :invalid_overlap_params}
  end

  defp fetch(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end
end
