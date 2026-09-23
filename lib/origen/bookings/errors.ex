defmodule Origen.Bookings.Errors do
  @moduledoc """
  Error types for booking operations.

  Provides structured error tuples that can be pattern-matched and formatted.
  """

  @type t ::
    {:eligibility_failed, reason :: atom()}
    | {:authorization_denied, reason :: atom()}
    | {:consultation_type_invalid, reason :: atom()}
    | {:availability_failed, reason :: atom()}
    | {:overlap_detected, target :: :professional | :patient}
    | {:d1_window_violation, reason :: atom()}
    | {:invalid_initial_state, reason :: atom()}
    | {:pending_fine_block}
    | {:transaction_failed, reason :: atom()}
    | {:concurrency_conflict}
    | {:state_transition_invalid, from :: atom(), to :: atom()}
    | {:not_found}
    | {:invalid_params, term()}

  @doc """
  Formats an error tuple into a human-readable string.
  """
  @spec format(t()) :: String.t()
  def format(error) do
    case error do
      {:eligibility_failed, reason} ->
        "Eligibility failed: #{reason}"

      {:authorization_denied, reason} ->
        "Authorization denied: #{reason}"

      {:consultation_type_invalid, reason} ->
        "Invalid consultation type: #{reason}"

      {:availability_failed, reason} ->
        "Availability check failed: #{reason}"

      {:overlap_detected, :professional} ->
        "Time slot overlaps with another appointment for this professional"

      {:overlap_detected, :patient} ->
        "Patient already has an appointment at this time"

      {:d1_window_violation, reason} ->
        "D-1 window violation: #{reason}"

      {:invalid_initial_state, reason} ->
        "Invalid initial state: #{reason}"

      {:pending_fine_block} ->
        "Patient has a pending fine with this professional; autonomous booking blocked"

      {:transaction_failed, reason} ->
        "Transaction failed: #{reason}"

      {:concurrency_conflict} ->
        "Concurrent booking conflict; please retry"

      {:state_transition_invalid, from, to} ->
        "Invalid state transition from #{from} to #{to}"

      {:not_found} ->
        "Appointment not found"

      {:invalid_params, details} ->
        "Invalid parameters: #{inspect(details)}"
    end
  end

  @doc """
  Returns a machine-readable code for the error.
  """
  @spec code(t()) :: atom()
  def code(error) do
    case error do
      {:eligibility_failed, _} -> :eligibility_failed
      {:authorization_denied, _} -> :authorization_denied
      {:consultation_type_invalid, _} -> :consultation_type_invalid
      {:availability_failed, _} -> :availability_failed
      {:overlap_detected, _} -> :overlap_detected
      {:d1_window_violation, _} -> :d1_window_violation
      {:invalid_initial_state, _} -> :invalid_initial_state
      {:pending_fine_block} -> :pending_fine_block
      {:transaction_failed, _} -> :transaction_failed
      {:concurrency_conflict} -> :concurrency_conflict
      {:state_transition_invalid, _, _} -> :state_transition_invalid
      {:not_found} -> :not_found
      {:invalid_params, _} -> :invalid_params
    end
  end

  @doc """
  Checks if the error is a validation error (vs system error).
  """
  @spec validation_error?(t()) :: boolean()
  def validation_error?(error) do
    code(error) in [
      :eligibility_failed,
      :authorization_denied,
      :consultation_type_invalid,
      :availability_failed,
      :overlap_detected,
      :d1_window_violation,
      :invalid_initial_state,
      :pending_fine_block,
      :state_transition_invalid,
      :invalid_params
    ]
  end

  @doc """
  Checks if the error indicates a transient failure that may succeed on retry.
  """
  @spec transient?(t()) :: boolean()
  def transient?(error) do
    code(error) in [:concurrency_conflict, :transaction_failed]
  end
end