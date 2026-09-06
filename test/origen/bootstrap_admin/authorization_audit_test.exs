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

    assert Authorization.decide(request) == {:allow, :dep_01}

    assert Authorization.decide(%{request | target: :unknown}) ==
             {:deny, {:unknown_dimension, :target}}
  end

  test "typed lifecycle constructors allow safe references and reject secret-like ones" do
    assert {:ok, event} = Events.bootstrap_allowed({:system, nil}, "42")
    assert event.event == "bootstrap_admin"
    assert {:ok, _} = Events.activation_succeeded({:system, nil}, "42")
    assert {:error, :invalid_event} = Events.reissue_denied({:system, nil}, "token-value")
  end
end
