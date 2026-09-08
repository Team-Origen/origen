defmodule Origen.ScaffoldSupportTest do
  use ExUnit.Case, async: false

  test "data-case error helper returns interpolated validation messages by field" do
    changeset =
      {%{}, %{attempts: :integer}}
      |> Ecto.Changeset.cast(%{attempts: 1}, [:attempts])
      |> Ecto.Changeset.validate_number(:attempts, greater_than: 2)

    assert Origen.DataCase.errors_on(changeset) == %{
             attempts: ["must be greater than 2"]
           }
  end

  test "telemetry exposes endpoint, router, database, and VM measurements" do
    metric_names = Enum.map(OrigenWeb.Telemetry.metrics(), & &1.name)

    assert [:phoenix, :endpoint, :start, :system_time] in metric_names
    assert [:phoenix, :router_dispatch, :stop, :duration] in metric_names
    assert [:origen, :repo, :query, :total_time] in metric_names
    assert [:vm, :memory, :total] in metric_names
    assert [:vm, :total_run_queue_lengths, :io] in metric_names
    assert length(metric_names) == 18
  end

  test "web scaffold exposes the supported integration quotes" do
    assert Macro.to_string(OrigenWeb.router()) =~ "Phoenix.Router"
    assert Macro.to_string(OrigenWeb.channel()) =~ "Phoenix.Channel"
    assert Macro.to_string(OrigenWeb.controller()) =~ "Phoenix.Controller"
    assert Macro.to_string(OrigenWeb.live_view()) =~ "Phoenix.LiveView"
    assert Macro.to_string(OrigenWeb.live_component()) =~ "Phoenix.LiveComponent"
    assert Macro.to_string(OrigenWeb.html()) =~ "Phoenix.Component"
    assert Macro.to_string(OrigenWeb.verified_routes()) =~ "Phoenix.VerifiedRoutes"
  end

  test "authorization facts accept declared absence while malformed requests remain denied" do
    alias Origen.Authorization
    alias Origen.Authorization.{Fact, Request}

    assert Fact.valid?(:unknown)
    refute Fact.valid?(:invalid)
    assert Authorization.decide(:invalid_request) == {:deny, :invalid_request}

    request =
      Request.new(
        operation: :not_applicable,
        subject: :not_applicable,
        account_state: :not_applicable,
        target: :not_applicable,
        scope: :not_applicable
      )

    assert Authorization.decide(request) == {:deny, :no_matching_rule}
  end

  test "audit lifecycle constructors preserve typed outcomes and reject unconstructed payloads" do
    alias Origen.Audit.Events

    assert {:ok, bootstrap_denial} =
             Events.bootstrap_denied({:system, nil}, "account-17")

    assert bootstrap_denial.event == "bootstrap_admin"
    assert bootstrap_denial.result == "denied"

    assert {:ok, activation_failure} =
             Events.activation_failed({:anonymous, nil}, "account-17")

    assert activation_failure.event == "account_activation"
    assert activation_failure.result == "failed"
    refute Events.persistable?(%{event: "account_activation"})
    assert Events.allowed(:system, nil) == {:error, :invalid_event}
  end

  test "migration role setup fails closed for absent and malformed owner roles" do
    previous_role = System.get_env("ORIGEN_OWNER_ROLE")

    on_exit(fn -> restore_env("ORIGEN_OWNER_ROLE", previous_role) end)

    System.delete_env("ORIGEN_OWNER_ROLE")
    assert_raise System.EnvError, fn -> Origen.MigrationRepo.set_owner_role(self()) end

    System.put_env("ORIGEN_OWNER_ROLE", "owner; DROP TABLE audit_events")

    assert_raise RuntimeError, "ORIGEN_OWNER_ROLE must be a PostgreSQL identifier", fn ->
      Origen.MigrationRepo.set_owner_role(self())
    end
  end

  defp restore_env(variable, nil), do: System.delete_env(variable)
  defp restore_env(variable, value), do: System.put_env(variable, value)
end
