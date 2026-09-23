defmodule Origen.Authorization.RulesTest do
  @moduledoc """
  Tests for authorization rules including BOOK-01, BOOK-02, BOOK-03.
  """

  use Origen.DataCase, async: true

  alias Origen.Authorization.Rules
  alias Origen.Authorization.Request

  @valid_patient_actor %{
    type: :patient,
    account_id: 1,
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
    patient_related: true,
    patient_in_allowed_list: true
  }

  @base_target %{
    professional_id: 1,
    patient_id: 1,
    consultation_type_id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
    starts_at: ~U[2026-01-15 10:00:00Z]
  }

  @base_scope %{
    consultation_type: :active_owned,
    availability: :valid,
    overlap: :none,
    d1_window: :valid
  }

  defp build_request(actor, target, scope) do
    %Request{
      operation: {:known, :create_booking},
      subject: {:known, {:role, actor.type}},
      account_state: :active,
      target: {:known, target},
      scope: {:known, scope}
    }
  end

  describe "BOOK-01 (S1-11) - Paciente autónomo" do
    test "allows patient with all required facts" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: true
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:allow, :book_01}
    end

    test "denies when profile incomplete" do
      scope = Map.merge(@base_scope, %{
        profile_complete: false,
        phone_verified: true,
        own_profile: true
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when phone not verified" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: false,
        own_profile: true
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when not own profile" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: false
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when consultation type not active_owned" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: true,
        consultation_type: :inactive
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when availability invalid" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: true,
        availability: :invalid
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when overlap detected" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: true,
        overlap: :professional
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when d1_window invalid" do
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: true,
        d1_window: :invalid
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies administrator" do
      admin_actor = %{@valid_patient_actor | type: :administrator}
      scope = Map.merge(@base_scope, %{
        profile_complete: true,
        phone_verified: true,
        own_profile: true
      })
      request = build_request(admin_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end
  end

  describe "BOOK-02 (S1-12) - Secretaría asistida" do
    test "allows secretary with all required facts" do
      scope = Map.merge(@base_scope, %{
        center_scope: :valid,
        minimum_identity: :complete,
        state: :valid
      })
      request = build_request(@valid_secretary_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:allow, :book_02}
    end

    test "denies when center_scope invalid" do
      scope = Map.merge(@base_scope, %{
        center_scope: :invalid,
        minimum_identity: :complete,
        state: :valid
      })
      request = build_request(@valid_secretary_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when minimum_identity incomplete" do
      scope = Map.merge(@base_scope, %{
        center_scope: :valid,
        minimum_identity: :incomplete,
        state: :valid
      })
      request = build_request(@valid_secretary_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when state invalid" do
      scope = Map.merge(@base_scope, %{
        center_scope: :valid,
        minimum_identity: :complete,
        state: :invalid
      })
      request = build_request(@valid_secretary_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies patient actor" do
      scope = Map.merge(@base_scope, %{
        center_scope: :valid,
        minimum_identity: :complete,
        state: :valid
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies professional actor" do
      scope = Map.merge(@base_scope, %{
        center_scope: :valid,
        minimum_identity: :complete,
        state: :valid
      })
      request = build_request(@valid_professional_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies administrator" do
      admin_actor = %{@valid_secretary_actor | type: :administrator}
      scope = Map.merge(@base_scope, %{
        center_scope: :valid,
        minimum_identity: :complete,
        state: :valid
      })
      request = build_request(admin_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end
  end

  describe "BOOK-03 (S1-13) - Profesional sobre paciente relacionado" do
    test "allows professional with related patient" do
      scope = Map.merge(@base_scope, %{
        patient_related: true,
        patient_in_allowed_list: true,
        state: :valid
      })
      request = build_request(@valid_professional_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:allow, :book_03}
    end

    test "denies when patient not related" do
      scope = Map.merge(@base_scope, %{
        patient_related: false,
        patient_in_allowed_list: false,
        state: :valid
      })
      request = build_request(@valid_professional_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when patient not in allowed list" do
      scope = Map.merge(@base_scope, %{
        patient_related: true,
        patient_in_allowed_list: false,
        state: :valid
      })
      request = build_request(@valid_professional_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies when state invalid" do
      scope = Map.merge(@base_scope, %{
        patient_related: true,
        patient_in_allowed_list: true,
        state: :invalid
      })
      request = build_request(@valid_professional_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies secretary actor" do
      scope = Map.merge(@base_scope, %{
        patient_related: true,
        patient_in_allowed_list: true,
        state: :valid
      })
      request = build_request(@valid_secretary_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies patient actor" do
      scope = Map.merge(@base_scope, %{
        patient_related: true,
        patient_in_allowed_list: true,
        state: :valid
      })
      request = build_request(@valid_patient_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end

    test "denies administrator" do
      admin_actor = %{@valid_professional_actor | type: :administrator}
      scope = Map.merge(@base_scope, %{
        patient_related: true,
        patient_in_allowed_list: true,
        state: :valid
      })
      request = build_request(admin_actor, @base_target, scope)
      
      assert Rules.decide(request) == {:deny, :no_matching_rule}
    end
  end

  describe "operations/0" do
    test "includes create_booking" do
      assert :create_booking in Rules.operations()
    end
  end

  describe "subjects/0" do
    test "includes patient role" do
      assert {:role, :patient} in Rules.subjects()
    end
  end
end