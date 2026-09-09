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
end
