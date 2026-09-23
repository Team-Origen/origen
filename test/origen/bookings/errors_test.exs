defmodule Origen.Bookings.ErrorsTest do
  @moduledoc """
  Tests for Origen.Bookings.Errors error formatting and classification.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.Errors

  describe "format/1" do
    test "formats eligibility_failed" do
      assert Errors.format({:eligibility_failed, :incomplete_profile}) ==
             "Eligibility failed: incomplete_profile"
    end

    test "formats authorization_denied" do
      assert Errors.format({:authorization_denied, :missing_scope}) ==
             "Authorization denied: missing_scope"
    end

    test "formats consultation_type_invalid" do
      assert Errors.format({:consultation_type_invalid, :inactive}) ==
             "Invalid consultation type: inactive"
    end

    test "formats availability_failed" do
      assert Errors.format({:availability_failed, :insufficient_intervals}) ==
             "Availability check failed: insufficient_intervals"
    end

    test "formats overlap_detected for professional" do
      assert Errors.format({:overlap_detected, :professional}) ==
             "Time slot overlaps with another appointment for this professional"
    end

    test "formats overlap_detected for patient" do
      assert Errors.format({:overlap_detected, :patient}) ==
             "Patient already has an appointment at this time"
    end

    test "formats d1_window_violation" do
      assert Errors.format({:d1_window_violation, :past_cutoff}) ==
             "D-1 window violation: past_cutoff"
    end

    test "formats invalid_initial_state" do
      assert Errors.format({:invalid_initial_state, :not_allowed_for_actor}) ==
             "Invalid initial state: not_allowed_for_actor"
    end

    test "formats pending_fine_block" do
      assert Errors.format({:pending_fine_block}) ==
             "Patient has a pending fine with this professional; autonomous booking blocked"
    end

    test "formats transaction_failed" do
      assert Errors.format({:transaction_failed, :db_error}) ==
             "Transaction failed: db_error"
    end

    test "formats concurrency_conflict" do
      assert Errors.format({:concurrency_conflict}) ==
             "Concurrent booking conflict; please retry"
    end

    test "formats state_transition_invalid" do
      assert Errors.format({:state_transition_invalid, :solicitado, :confirmado}) ==
             "Invalid state transition from solicitado to confirmado"
    end

    test "formats not_found" do
      assert Errors.format({:not_found}) == "Appointment not found"
    end

    test "formats invalid_params" do
      assert Errors.format({:invalid_params, %{field: "value"}}) ==
             "Invalid parameters: %{field: \"value\"}"
    end
  end

  describe "code/1" do
    test "returns correct code for each error type" do
      assert Errors.code({:eligibility_failed, :reason}) == :eligibility_failed
      assert Errors.code({:authorization_denied, :reason}) == :authorization_denied
      assert Errors.code({:consultation_type_invalid, :reason}) == :consultation_type_invalid
      assert Errors.code({:availability_failed, :reason}) == :availability_failed
      assert Errors.code({:overlap_detected, :professional}) == :overlap_detected
      assert Errors.code({:d1_window_violation, :reason}) == :d1_window_violation
      assert Errors.code({:invalid_initial_state, :reason}) == :invalid_initial_state
      assert Errors.code({:pending_fine_block}) == :pending_fine_block
      assert Errors.code({:transaction_failed, :reason}) == :transaction_failed
      assert Errors.code({:concurrency_conflict}) == :concurrency_conflict
      assert Errors.code({:state_transition_invalid, :a, :b}) == :state_transition_invalid
      assert Errors.code({:not_found}) == :not_found
      assert Errors.code({:invalid_params, _}) == :invalid_params
    end
  end

  describe "validation_error?/1" do
    test "returns true for validation errors" do
      assert Errors.validation_error?({:eligibility_failed, :reason})
      assert Errors.validation_error?({:authorization_denied, :reason})
      assert Errors.validation_error?({:consultation_type_invalid, :reason})
      assert Errors.validation_error?({:availability_failed, :reason})
      assert Errors.validation_error?({:overlap_detected, :professional})
      assert Errors.validation_error?({:d1_window_violation, :reason})
      assert Errors.validation_error?({:invalid_initial_state, :reason})
      assert Errors.validation_error?({:pending_fine_block})
      assert Errors.validation_error?({:state_transition_invalid, :a, :b})
      assert Errors.validation_error?({:invalid_params, %{}})
    end

    test "returns false for system errors" do
      assert not Errors.validation_error?({:transaction_failed, :reason})
      assert not Errors.validation_error?({:concurrency_conflict})
      assert not Errors.validation_error?({:not_found})
    end
  end

  describe "transient?/1" do
    test "returns true for transient errors" do
      assert Errors.transient?({:concurrency_conflict})
      assert Errors.transient?({:transaction_failed, :reason})
    end

    test "returns false for non-transient errors" do
      assert not Errors.transient?({:eligibility_failed, :reason})
      assert not Errors.transient?({:authorization_denied, :reason})
      assert not Errors.transient?({:not_found})
    end
  end
end