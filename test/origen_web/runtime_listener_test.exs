defmodule OrigenWeb.RuntimeListenerTest do
  use ExUnit.Case, async: false

  test "production listens on the IPv4 wildcard at the configured PORT and denies bootstrap" do
    with_env(
      %{
        "DATABASE_URL" => "ecto://user:password@localhost/origen",
        "SECRET_KEY_BASE" => String.duplicate("s", 64),
        "PORT" => "4517",
        "PHX_SERVER" => "true",
        "ORIGEN_BOOTSTRAP_ADMIN_ENABLED" => "true"
      },
      fn ->
        config = Config.Reader.read!("config/runtime.exs", env: :prod)
        endpoint = config[:origen][OrigenWeb.Endpoint]

        assert endpoint[:http][:ip] == {0, 0, 0, 0}
        assert endpoint[:http][:port] == 4517
        assert endpoint[:server] == true
        assert config[:origen][:bootstrap_admin_enabled] == false
        assert config[:origen][:bootstrap_admin_local_enabled] == false
      end
    )
  end

  test "local bootstrap keeps the development listener disabled" do
    keys = [:bootstrap_admin_profile, :bootstrap_admin_local_enabled, :bootstrap_admin_local]
    previous = Map.new(keys, &{&1, Application.fetch_env(:origen, &1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:origen, key, value)
        {key, :error} -> Application.delete_env(:origen, key)
      end)
    end)

    Application.put_env(:origen, :bootstrap_admin_profile, :local)
    Application.put_env(:origen, :bootstrap_admin_local_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_local, %{enabled: true})

    with_env(%{"PHX_SERVER" => "true"}, fn ->
      endpoint = Config.Reader.read!("config/runtime.exs", env: :dev)[:origen][OrigenWeb.Endpoint]

      assert endpoint[:http] == false
      assert endpoint[:server] == false
    end)
  end

  defp with_env(overrides, callback) do
    previous = Map.new(overrides, fn {key, _} -> {key, System.get_env(key)} end)

    try do
      Enum.each(overrides, fn {key, value} -> System.put_env(key, value) end)
      callback.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end
end
