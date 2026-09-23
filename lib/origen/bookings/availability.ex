defmodule Origen.Bookings.Availability do
  @moduledoc """
  Slot availability validation and overlap detection for booking operations.

  Implements RF-12: validates contiguous agenda intervals, prevents professional
  and patient double-booking.
  """

  alias Origen.Repo
  alias Origen.Bookings.Errors

  @doc """
  Validates that a time slot has enough contiguous agenda intervals for the consultation type.

  Checks professional's availability schedule and existing appointments.
  """
  @spec validate_availability(integer(), binary(), DateTime.t(), DateTime.t()) ::
          :ok | {:error, Errors.t()}
  def validate_availability(professional_id, consultation_type_id, starts_at, ends_at) do
    with {:ok, type} <- fetch_consultation_type(consultation_type_id),
         :ok <- validate_contiguous_intervals(professional_id, type, starts_at, ends_at),
         :ok <- validate_professional_availability(professional_id, starts_at, ends_at) do
      :ok
    else
      {:error, :not_found} ->
        {:error, {:availability_failed, :consultation_type_not_found}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches consultation type from database for validation.
  """
  @spec fetch_consultation_type(binary()) :: {:ok, map()} | {:error, :not_found}
  def fetch_consultation_type(consultation_type_id) do
    case Repo.query(
           """
           SELECT id, professional_id, name, interval_count, exact_price_ars, status, agenda_interval_minutes
           FROM consultation_types
           WHERE id = $1
           """,
           [consultation_type_id]
         ) do
      {:ok, %{rows: [[id, professional_id, name, interval_count, price, status, agenda_interval] | _]}} ->
        {:ok, %{
          id: id,
          professional_id: professional_id,
          name: name,
          interval_count: interval_count,
          exact_price_ars: price,
          status: status,
          agenda_interval_minutes: agenda_interval
        }}
      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Validates that the professional's schedule has enough contiguous intervals.

  This checks the professional's regular availability (not yet implemented - uses default).
  """
  @spec validate_contiguous_intervals(integer(), map(), DateTime.t(), DateTime.t()) ::
          :ok | {:error, Errors.t()}
  def validate_contiguous_intervals(professional_id, type, starts_at, ends_at) do
    required_intervals = type.interval_count
    agenda_interval = type.agenda_interval_minutes

    # Get professional's agenda interval
    professional_interval = get_professional_agenda_interval(professional_id)
    effective_interval = professional_interval || agenda_interval

    # Calculate duration in minutes
    duration_minutes = DateTime.diff(ends_at, starts_at, :minute) |> round()

    # Required duration = intervals * interval_minutes
    required_duration = required_intervals * effective_interval

    if duration_minutes >= required_duration do
      :ok
    else
      {:error, {:availability_failed, :insufficient_intervals}}
    end
  end

  @doc """
  Gets the professional's configured agenda interval.
  """
  @spec get_professional_agenda_interval(integer()) :: integer() | nil
  def get_professional_agenda_interval(professional_id) do
    case Repo.query(
           "SELECT agenda_interval_minutes FROM professionals WHERE id = $1",
           [professional_id]
         ) do
      {:ok, %{rows: [[interval] | _]}} -> interval
      _ -> nil
    end
  end

  @doc """
  Validates professional's regular availability for the time slot.

  Placeholder - full availability schedule (RF-07) is out of scope for this issue.
  """
  @spec validate_professional_availability(integer(), DateTime.t(), DateTime.t()) :: :ok
  def validate_professional_availability(_professional_id, _starts_at, _ends_at) do
    # TODO: Implement when availability schedule exists (RF-07, issue #76/#77)
    # For now, assume professional is available
    :ok
  end

  @doc """
  Checks for overlap with professional's existing appointments.

  Uses advisory lock for concurrency control.
  """
  @spec check_professional_overlap(integer(), DateTime.t(), DateTime.t()) ::
          :ok | {:error, Errors.t()}
  def check_professional_overlap(professional_id, starts_at, ends_at) do
    # Advisory lock to prevent race conditions
    Repo.query("SELECT pg_advisory_xact_lock($1)", [professional_id])

    case Repo.query(
           """
           SELECT id FROM appointments
           WHERE professional_id = $1
           AND tsrange(starts_at, ends_at) && tsrange($2, $3)
           AND state NOT IN ('cancelado', 'no_asistio')
           LIMIT 1
           """,
           [professional_id, starts_at, ends_at]
         ) do
      {:ok, %{rows: []}} -> :ok
      {:ok, %{rows: [_ | _]}} ->
        {:error, {:overlap_detected, :professional}}
      _ ->
        {:error, {:availability_failed, :db_error}}
    end
  end

  @doc """
  Checks for overlap with patient's existing appointments.

  Uses advisory lock for concurrency control.
  """
  @spec check_patient_overlap(integer(), DateTime.t(), DateTime.t()) ::
          :ok | {:error, Errors.t()}
  def check_patient_overlap(patient_id, starts_at, ends_at) do
    # Advisory lock on patient_id as well
    Repo.query("SELECT pg_advisory_xact_lock($1)", [patient_id + 1_000_000])  # Offset to avoid collision

    case Repo.query(
           """
           SELECT id FROM appointments
           WHERE patient_id = $1
           AND tsrange(starts_at, ends_at) && tsrange($2, $3)
           AND state NOT IN ('cancelado', 'no_asistio')
           LIMIT 1
           """,
           [patient_id, starts_at, ends_at]
         ) do
      {:ok, %{rows: []}} -> :ok
      {:ok, %{rows: [_ | _]}} ->
        {:error, {:overlap_detected, :patient}}
      _ ->
        {:error, {:availability_failed, :db_error}}
    end
  end

  @doc """
  Acquires advisory lock on professional_id for booking transaction.
  """
  @spec advisory_lock(integer()) :: :ok
  def advisory_lock(professional_id) do
    Repo.query("SELECT pg_advisory_xact_lock($1)", [professional_id])
    :ok
  end

  @doc """
  Acquires advisory locks on both professional and patient for booking transaction.
  """
  @spec advisory_lock_both(integer(), integer()) :: :ok
  def advisory_lock_both(professional_id, patient_id) do
    Repo.query("SELECT pg_advisory_xact_lock($1)", [professional_id])
    Repo.query("SELECT pg_advisory_xact_lock($1)", [patient_id + 1_000_000])
    :ok
  end

  @doc """
  Checks if a slot is available for booking (no overlaps, valid availability).

  Convenience function that runs all availability checks.
  """
  @spec check_slot_available(integer(), integer(), binary(), DateTime.t(), DateTime.t()) ::
          :ok | {:error, Errors.t()}
  def check_slot_available(professional_id, patient_id, consultation_type_id, starts_at, ends_at) do
    with :ok <- validate_availability(professional_id, consultation_type_id, starts_at, ends_at),
         :ok <- check_professional_overlap(professional_id, starts_at, ends_at),
         :ok <- check_patient_overlap(patient_id, starts_at, ends_at) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
end