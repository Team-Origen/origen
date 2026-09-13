defmodule Origen.BootstrapAdmin.Local.EligibilityTest do
  use ExUnit.Case, async: false

  alias Origen.BootstrapAdmin.Local.Eligibility

  @eligible %{
    environment: :dev,
    shared_enabled: true,
    profile: :local,
    local_enabled: true,
    local_config_enabled: true,
    channel: :source_checkout
  }

  test "only the exact trusted development facts are eligible" do
    assert Eligibility.evaluate(@eligible) == :ok

    for environment <- [:test, :prod, :staging, "dev", nil] do
      assert Eligibility.evaluate(%{@eligible | environment: environment}) ==
               {:error, :local_bootstrap_ineligible}
    end

    for channel <- [:packaged_release, :deployment, "source_checkout", nil] do
      assert Eligibility.evaluate(%{@eligible | channel: channel}) ==
               {:error, :local_bootstrap_ineligible}
    end
  end

  test "missing, false, and malformed gates and selectors fail closed" do
    cases = [
      %{shared_enabled: false},
      %{shared_enabled: "true"},
      %{local_enabled: false},
      %{local_enabled: 1},
      %{local_config_enabled: false},
      %{local_config_enabled: "true"},
      %{profile: :staging},
      %{profile: "local"},
      %{profile: :unknown}
    ]

    for override <- cases do
      assert Eligibility.evaluate(Map.merge(@eligible, override)) ==
               {:error, :local_bootstrap_ineligible}
    end

    assert Eligibility.evaluate(%{}) == {:error, :local_bootstrap_ineligible}
    assert Eligibility.evaluate(nil) == {:error, :local_bootstrap_ineligible}
  end

  test "runtime check uses the compiled test environment and cannot be made local eligible" do
    keys = [
      :bootstrap_admin_enabled,
      :bootstrap_admin_profile,
      :bootstrap_admin_local_enabled,
      :bootstrap_admin_local
    ]

    previous = Map.new(keys, &{&1, Application.fetch_env(:origen, &1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:origen, key, value)
        {key, :error} -> Application.delete_env(:origen, key)
      end)
    end)

    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_profile, :local)
    Application.put_env(:origen, :bootstrap_admin_local_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_local, %{enabled: true})

    assert Eligibility.check(:source_checkout) == {:error, :local_bootstrap_ineligible}
    assert Eligibility.check(:packaged_release) == {:error, :local_bootstrap_ineligible}
  end
end
