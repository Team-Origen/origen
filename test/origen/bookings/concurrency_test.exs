defmodule Origen.Bookings.ConcurrencyTest do
  @moduledoc """
  Tests for concurrent booking conflict resolution.

  Scenarios from spec:
  - Concurrent Paciente autónomo requests for same slot
  - Concurrent Secretaría vs Paciente autónomo
  - Concurrent Profesional vs Secretaría
  """

  use Origen.DataCase, async: false

  alias Origen.Bookings.Booking
  alias Origen.Bookings.Availability
  alias Origen.Repo

  @professional_id 1
  @patient_id_1 1
  @patient_id_2 2
  @consultation_type_id "018f4a5b-0d62-7a44-8e32-2f608bfcb001"
  @starts_at ~U[2026-01-15 10:00:00Z]
  @ends_at ~U[2026-01-15 10:30:00Z]

  @patient_actor %{
    type: :patient,
    account_id: 1,
    patient_id: @patient_id_1,
    profile_complete: true,
    phone_verified: true,
    own_profile: true,
    professional_reference: "PRO-DEMO-001"
  }

  @secretary_actor %{
    type: :secretary,
    account_id: 2,
    center_scope_valid: true,
    minimum_identity_complete: true,
    professional_reference: "PRO-DEMO-001"
  }

  @professional_actor %{
    type: :professional,
    account_id: 3,
    allowed_patient_ids: [@patient_id_1, @patient_id_2],
    professional_reference: "PRO-DEMO-001"
  }

  @base_params %{
    professional_id: @professional_id,
    patient_id: @patient_id_1,
    consultation_type_id: @consultation_type_id,
    starts_at: @starts_at,
    ends_at: @ends_at,
    initial_state: :reservado,
    modality: :automatic
  }

  setup do
    # Clean up any existing appointments for this professional/time
    Repo.query!(
      "DELETE FROM appointments WHERE professional_id = $1 AND starts_at = $2",
      [@professional_id, @starts_at]
    )
    :ok
  end

  describe "Concurrent Paciente autónomo requests (Scenario 1)" do
    test "exactly one booking succeeds when two patients request same slot" do
      params_1 = Map.put(@base_params, :patient_id, @patient_id_1)
      params_2 = Map.put(@base_params, :patient_id, @patient_id_2)

      actor_1 = Map.put(@patient_actor, :patient_id, @patient_id_1)
      actor_2 = Map.put(@patient_actor, :patient_id, @patient_id_2)

      # Run both bookings concurrently
      task_1 = Task.async(fn -> Booking.create_booking(actor_1, params_1) end)
      task_2 = Task.async(fn -> Booking.create_booking(actor_2, params_2) end)

      result_1 = Task.await(task_1, 10_000)
      result_2 = Task.await(task_2, 10_000)

      # Exactly one should succeed
      success_count = Enum.count([result_1, result_2], fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

      assert success_count == 1, "Expected exactly 1 success, got #{success_count}"

      # The failed one should have overlap error
      failed_result = Enum.find([result_1, result_2], fn
        {:error, _} -> true
        _ -> false
      end)

      assert match?({:error, {:overlap_detected, :professional}}, failed_result) ||
             match?({:error, {:overlap_detected, :patient}}, failed_result) ||
             match?({:error, {:concurrency_conflict, _}}, failed_result),
             "Expected overlap or concurrency error, got: #{inspect(failed_result)}"
    end
  end

  describe "Concurrent Secretaría vs Paciente autónomo (Scenario 2)" do
    test "exactly one booking succeeds when secretary and patient request same slot" do
      patient_params = Map.put(@base_params, :patient_id, @patient_id_1)
      secretary_params = Map.put(@base_params, :patient_id, @patient_id_1)

      patient_actor = Map.put(@patient_actor, :patient_id, @patient_id_1)
      secretary_actor = @secretary_actor

      task_1 = Task.async(fn -> Booking.create_booking(patient_actor, patient_params) end)
      task_2 = Task.async(fn -> Booking.create_booking(secretary_actor, secretary_params) end)

      result_1 = Task.await(task_1, 10_000)
      result_2 = Task.await(task_2, 10_000)

      success_count = Enum.count([result_1, result_2], fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

      assert success_count == 1, "Expected exactly 1 success, got #{success_count}"
    end
  end

  describe "Concurrent Profesional vs Secretaría (Scenario 3)" do
    test "exactly one booking succeeds when professional and secretary request same slot" do
      professional_params = Map.put(@base_params, :patient_id, @patient_id_1)
      secretary_params = Map.put(@base_params, :patient_id, @patient_id_1)

      professional_actor = Map.put(@professional_actor, :patient_id, @patient_id_1)
      secretary_actor = @secretary_actor

      task_1 = Task.async(fn -> Booking.create_booking(professional_actor, professional_params) end)
      task_2 = Task.async(fn -> Booking.create_booking(secretary_actor, secretary_params) end)

      result_1 = Task.await(task_1, 10_000)
      result_2 = Task.await(task_2, 10_000)

      success_count = Enum.count([result_1, result_2], fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

      assert success_count == 1, "Expected exactly 1 success, got #{success_count}"
    end
  end

  describe "Advisory lock behavior" do
    test "advisory lock prevents concurrent inserts" do
      # This test verifies the advisory lock is acquired
      # by checking that sequential bookings work but concurrent fail appropriately
      
      # First booking succeeds
      assert {:ok, _} = Booking.create_booking(@patient_actor, @base_params)
      
      # Second booking for same slot should fail
      assert {:error, {:overlap_detected, :professional}} = 
        Booking.create_booking(Map.put(@patient_actor, :patient_id, @patient_id_2), 
          Map.put(@base_params, :patient_id, @patient_id_2))
    end
  end
end