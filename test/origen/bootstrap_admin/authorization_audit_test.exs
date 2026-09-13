defmodule Origen.BootstrapAdmin.AuthorizationAuditTest do
  use ExUnit.Case, async: true

  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.Audit.Events

  test "bootstrap primitives expose explicit default-deny authorization facts" do
    request =
      Request.new(
        operation: Fact.known(:bootstrap_first_administrator),
        subject: Fact.known({:channel, :deployment}),
        account_state: :not_applicable,
        target: Fact.known(%{administrator_exists: false}),
        scope: Fact.known(%{approved_command: true, assigned_operator: true})
      )

    assert Authorization.decide(%{
             request
             | scope:
                 Fact.known(%{
                   approved_command: true,
                   assigned_operator: true,
                   approval_authorized: true
                 })
           }) == {:allow, :dep_01}

    assert Authorization.decide(%{request | target: :unknown}) ==
             {:deny, {:unknown_dimension, :target}}

    assert Authorization.decide(request) == {:deny, :no_matching_rule}
  end

  test "approval authority is explicit and never inferred from a role" do
    approval =
      Request.new(
        operation: Fact.known(:approve_bootstrap_invitation),
        subject: Fact.known({:channel, :deployment_approval}),
        account_state: :not_applicable,
        target: Fact.known(%{distinct_principals: true}),
        scope:
          Fact.known(%{
            destination_matches: true,
            environment_matches: true,
            operation_matches: true,
            account_matches: true,
            non_production: true,
            assertion_valid: true,
            confirmer_authorized: true
          })
      )

    assert Authorization.decide(approval) == {:allow, :apr_01}

    assert Authorization.decide(%{approval | scope: :unknown}) ==
             {:deny, {:unknown_dimension, :scope}}

    assert Authorization.decide(%{approval | subject: Fact.known({:role, :administrator})}) ==
             {:deny, :no_matching_rule}

    reissue =
      Request.new(
        operation: Fact.known(:reissue_internal_invitation),
        subject: Fact.known({:channel, :deployment}),
        account_state: :not_applicable,
        target: Fact.known(%{role: :administrator, state: :pending_activation}),
        scope:
          Fact.known(%{
            active_administrator_exists: false,
            approved_command: true,
            assigned_operator: true
          })
      )

    assert Authorization.decide(reissue) == {:deny, :no_matching_rule}
  end

  test "typed lifecycle constructors allow safe references and reject secret-like ones" do
    assert {:ok, event} = Events.bootstrap_allowed({:system, nil}, "42")
    assert event.event == "bootstrap_admin"
    assert {:ok, _} = Events.activation_succeeded({:system, nil}, "42")
    assert {:error, :invalid_event} = Events.reissue_denied({:system, nil}, "token-value")
  end

  test "typed approval, handoff, failure, and revocation events contain allowlisted references only" do
    constructors = [
      {&Events.invitation_approval_confirmed/2, {:administrator, "operator-samuel"}, "41",
       "invitation_approval_confirmation"},
      {&Events.invitation_delivery_handoff/2, {:provider, "handoff_42"}, "42",
       "invitation_delivery_handoff"},
      {&Events.invitation_delivery_failed/2, {:system, nil}, "42", "invitation_delivery_failure"},
      {&Events.invitation_delivery_revoked/2, {:system, nil}, "42",
       "invitation_delivery_revocation"}
    ]

    for {constructor, actor, reference, type} <- constructors do
      assert {:ok, event} = constructor.(actor, reference)
      assert event.event == type
      assert event.entity_kind == "invitation"
      assert event.entity_ref == reference
    end

    for unsafe <- [
          "token-value",
          "https://approved-host/admin/activate#secret",
          String.duplicate("x", 129)
        ] do
      assert {:error, :invalid_event} =
               Events.invitation_delivery_handoff({:provider, unsafe}, "42")

      assert {:error, :invalid_event} = Events.invitation_delivery_failed({:system, nil}, unsafe)
    end
  end

  test "corrections are represented as a new typed event rather than mutating an event" do
    assert {:ok, original} = Events.invitation_delivery_handoff({:provider, "handoff-1"}, "42")
    assert {:ok, correction} = Events.invitation_delivery_failed({:system, nil}, "42")
    assert original.event == "invitation_delivery_handoff"
    assert correction.event == "invitation_delivery_failure"
    assert original.entity_ref == correction.entity_ref
  end

  test "local profile primitives expose explicit default-deny authorization facts" do
    request =
      Request.new(
        operation: Fact.known(:bootstrap_local_first_administrator),
        subject: Fact.known({:channel, :local_profile}),
        account_state: :not_applicable,
        target: Fact.known(%{administrator_exists: false}),
        scope:
          Fact.known(%{
            profile: :dev,
            readiness: :ready,
            destination: :example_test,
            database: :isolated,
            account: :none
          })
      )

    assert Authorization.decide(request) == {:allow, :loc_01}
  end

  test "local recovery primitive exposes explicit facts" do
    request =
      Request.new(
        operation: Fact.known(:reissue_local_first_administrator),
        subject: Fact.known({:channel, :local_profile}),
        account_state: :not_applicable,
        target: Fact.known(%{role: :administrator, state: :pending_activation}),
        scope:
          Fact.known(%{
            profile: :dev,
            readiness: :ready,
            destination: :example_test,
            database: :isolated,
            active_administrator_exists: false,
            account: :sole_pending
          })
      )

    assert Authorization.decide(request) == {:allow, :loc_02}
  end

  test "loc_01 and loc_02 reject extra/over-broad facts due to exact-map matching" do
    base_loc_01 =
      Request.new(
        operation: Fact.known(:bootstrap_local_first_administrator),
        subject: Fact.known({:channel, :local_profile}),
        account_state: :not_applicable,
        target: Fact.known(%{administrator_exists: false}),
        scope:
          Fact.known(%{
            profile: :dev,
            readiness: :ready,
            destination: :example_test,
            database: :isolated,
            account: :none
          })
      )

    extra_scope_loc_01 =
      Request.new(
        operation: Fact.known(:bootstrap_local_first_administrator),
        subject: Fact.known({:channel, :local_profile}),
        account_state: :not_applicable,
        target: Fact.known(%{administrator_exists: false}),
        scope:
          Fact.known(%{
            profile: :dev,
            readiness: :ready,
            destination: :example_test,
            database: :isolated,
            account: :none,
            extra_fact: true
          })
      )

    extra_target_loc_01 =
      Request.new(
        operation: Fact.known(:bootstrap_local_first_administrator),
        subject: Fact.known({:channel, :local_profile}),
        account_state: :not_applicable,
        target: Fact.known(%{administrator_exists: false, extra_fact: true}),
        scope:
          Fact.known(%{
            profile: :dev,
            readiness: :ready,
            destination: :example_test,
            database: :isolated,
            account: :none
          })
      )

    assert Authorization.decide(base_loc_01) == {:allow, :loc_01}
    assert Authorization.decide(extra_scope_loc_01) == {:deny, :no_matching_rule}
    assert Authorization.decide(extra_target_loc_01) == {:deny, :no_matching_rule}
  end
end
