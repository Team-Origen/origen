defmodule Origen.Bookings.ConsultationType do
  @moduledoc """
  Consultation type validation for booking operations.

  Validates ownership, active state, and identity per BOOK-01/02/03 conditions.
  """

  alias Origen.ConsultationTypes.Catalog
  alias Origen.Bookings.Snapshots
  alias Origen.Bookings.Errors

  @type professional_reference :: String.t()
  @type consultation_type_id :: binary()

  @doc """
  Validates a consultation type for booking.

  Checks:
  - Type exists and is active
  - Type belongs to the target professional (ownership)
  - Type identified by immutable identity (not name)
  - Returns type with professional's agenda_interval_minutes for duration calculation
  """
  @spec validate_consultation_type(professional_reference(), consultation_type_id()) ::
          {:ok, map()} | {:error, Errors.t()}
  def validate_consultation_type(professional_reference, consultation_type_id) do
    with {:ok, type} <- fetch_type_for_booking(professional_reference, consultation_type_id),
         :active <- type.status,
         {:ok, _snapshot} <- Snapshots.capture_snapshot(type, type.agenda_interval_minutes) do
      {:ok, type}
    else
      {:error, :not_found_or_inactive} ->
        {:error, {:consultation_type_invalid, :not_found_or_inactive}}

      {:error, :inactive_type} ->
        {:error, {:consultation_type_invalid, :inactive}}

      {:error, :invalid_duration} ->
        {:error, {:consultation_type_invalid, :invalid_duration}}

      {:error, :invalid_price} ->
        {:error, {:consultation_type_invalid, :invalid_price}}

      {:error, :invalid_type} ->
        {:error, {:consultation_type_invalid, :invalid_type}}

      _ ->
        {:error, {:consultation_type_invalid, :unknown}}
    end
  end

  @doc """
  Fetches a consultation type from the catalog for booking validation.

  Returns the type with the professional's agenda_interval_minutes included.
  """
  @spec fetch_type_for_booking(professional_reference(), consultation_type_id()) ::
          {:ok, map()} | {:error, :not_found_or_inactive}
  def fetch_type_for_booking(professional_reference, consultation_type_id) do
    with {:ok, %{
      consultation_types: types,
      agenda_interval_minutes: agenda_interval_minutes
    }} <- Catalog.execute({:list, %{professional_reference: professional_reference}}),
         type <- Enum.find(types, fn t -> t.id == consultation_type_id end),
         true <- type do
      {:ok, Map.put(type, :agenda_interval_minutes, agenda_interval_minutes)}
    else
      _ -> {:error, :not_found_or_inactive}
    end
  end

  @doc """
  Validates that the consultation type belongs to the professional and is active.

  Used by authorization layer for scope facts.
  """
  @spec validate_ownership_and_active(professional_reference(), consultation_type_id()) ::
          {:ok, :active_owned} | {:error, :inactive | :foreign | :not_found}
  def validate_ownership_and_active(professional_reference, consultation_type_id) do
    case fetch_type_for_booking(professional_reference, consultation_type_id) do
      {:ok, type} when type.status == :active ->
        {:ok, :active_owned}
      {:ok, _type} ->
        {:error, :inactive}
      {:error, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Calculates the required number of contiguous agenda intervals for a type.
  """
  @spec required_intervals(map()) :: pos_integer()
  def required_intervals(%{interval_count: count}) when is_integer(count) and count > 0, do: count

  @doc """
  Validates that a time slot provides enough contiguous agenda intervals.
  """
  @spec validate_slot_intervals(professional_reference(), map(), DateTime.t(), DateTime.t()) ::
          :ok | {:error, Errors.t()}
  def validate_slot_intervals(professional_reference, type, starts_at, ends_at) do
    required = required_intervals(type)
    available = calculate_available_intervals(professional_reference, starts_at, ends_at)

    if available >= required do
      :ok
    else
      {:error, {:availability_failed, :insufficient_intervals}}
    end
  end

  @doc """
  Calculates available contiguous intervals in a time slot.

  This is a simplified check - real implementation would query the professional's
  availability schedule and exclude booked slots.
  """
  @spec calculate_available_intervals(professional_reference(), DateTime.t(), DateTime.t()) :: non_neg_integer()
  def calculate_available_intervals(_professional_reference, starts_at, ends_at) do
    duration_minutes = DateTime.diff(ends_at, starts_at, :minute) |> round()
    agenda_interval = Application.get_env(:origen, :default_agenda_interval_minutes, 30)
    div(duration_minutes, agenda_interval)
  end
end