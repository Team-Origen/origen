defmodule Origen.Bookings.EligibilityTest do
  @moduledoc """
  Tests for actor eligibility checks.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.Eligibility
  alias Origen.Bookings.Errors

  @valid_patient_actor %{
    type: :patient,
    account_id: 1,
    patient_id: 1,
    profile_complete: true,
    phone_verified: true,
    own_profile: true
  }

  @valid_secretary_actor %{
    type: :secretary,
    account_id: 2,
    center_scope_valid: true,
    minimum_identity_complete: true
  }

  @valid_professional_actor %{
    type: :professional,
    account_id: 3,
    allowed_patient_ids: [1, 2, 3]
  }

  @base_params %{
    professional_id: 1,
    patient_id: 1,
    consultation_type_id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
    starts_at: ~U[2026-01-15 10:00:00Z],
    ends_at: ~U[2026-01-15 10:30:00Z]
  }

  describe "validate_patient_autonomo/2" do
    test "succeeds with valid actor" do
      assert Eligibility.validate_patient_autonomo(@valid_patient_actor, @base_params) == :ok
    end

    test "fails for non-patient actor" do
      actor = Map.put(@valid_patient_actor, :type, :secretary)
      assert Eligibility.validate_patient_autonomo(actor, @base_params) ==
             {:error, {:eligibility_failed, :not_patient_actor}}
    end

    test "fails when not own profile" do
      actor = Map.put(@valid_patient_actor, :own_profile, false)
      assert Eligibility.validate_patient_autonomo(actor, @base_params) ==
             {:error, {:eligibility_failed, :not_own_profile}}
    end

    test "fails when profile incomplete" do
      actor = Map.put(@valid_patient_actor, :profile_complete, false)
      assert Eligibility.validate_patient_autonomo(actor, @base_params) ==
             {:error, {:eligibility_failed, :incomplete_profile}}
    end

    test "fails when phone not verified" do
      actor = Map.put(@valid_patient_actor, :phone_verified, false)
      assert Eligibility.validate_patient_autonomo(actor, @base_params) ==
             {:error, {:eligibility_failed, :phone_not_verified}}
    end
  end

  describe "validate_secretaria_asistida/2" do
    test "succeeds with valid actor" do
      assert Eligibility.validate_secretaria_asistida(@valid_secretary_actor, @base_params) == :ok
    end

    test "fails for non-secretary actor" do
      actor = Map.put(@valid_secretary_actor, :type, :patient)
      assert Eligibility.validate_secretaria_asistida(actor, @base_params) ==
             {:error, {:eligibility_failed, :not_secretary_actor}}
    end

    test "fails when patient outside center scope" do
      actor = Map.put(@valid_secretary_actor, :center_scope_valid, false)
      assert Eligibility.validate_secretaria_asistida(actor, @base_params) ==
             {:error, {:eligibility_failed, :patient_outside_center_scope}}
    end

    test "fails when first booking and minimum identity incomplete" do
      actor = Map.put(@valid_secretary_actor, :minimum_identity_complete, false)
      params = Map.put(@base_params, :is_first_booking, true)
      assert Eligibility.validate_secretaria_asistida(actor, params) ==
             {:error, {:eligibility_failed, :minimum_identity_incomplete}}
    end

    test "succeeds when not first booking and minimum identity incomplete" do
      actor = Map.put(@valid_secretary_actor, :minimum_identity_complete, false)
      params = Map.put(@base_params, :is_first_booking, false)
      assert Eligibility.validate_secretaria_asistida(actor, params) == :ok
    end
  end

  describe "validate_profesional/2" do
    test "succeeds with related patient" do
      assert Eligibility.validate_profesional(@valid_professional_actor, @base_params) == :ok
    end

    test "fails for non-professional actor" do
      actor = Map.put(@valid_professional_actor, :type, :patient)
      assert Eligibility.validate_profesional(actor, @base_params) ==
             {:error, {:eligibility_failed, :not_professional_actor}}
    end

    test "fails when patient not in allowed list" do
      params = Map.put(@base_params, :patient_id, 999)
      assert Eligibility.validate_profesional(@valid_professional_actor, params) ==
             {:error, {:eligibility_failed, :patient_not_related}}
    end
  end

  describe "validate_actor_eligibility/2" do
    test "dispatches to patient validator" do
      assert Eligibility.validate_actor_eligibility(@valid_patient_actor, @base_params) == :ok
    end

    test "dispatches to secretary validator" do
      assert Eligibility.validate_actor_eligibility(@valid_secretary_actor, @base_params) == :ok
    end

    test "dispatches to professional validator" do
      assert Eligibility.validate_actor_eligibility(@valid_professional_actor, @base_params) == :ok
    end

    test "fails for unknown actor type" do
      actor = %{type: :unknown, account_id: 1}
      assert Eligibility.validate_actor_eligibility(actor, @base_params) ==
             {:error, {:eligibility_failed, :unknown_actor_type}}
    end
  end

  describe "check_pending_fine/2" do
    test "returns ok (placeholder)" do
      assert Eligibility.check_pending_fine(1, 1) == :ok
    end
  end
end