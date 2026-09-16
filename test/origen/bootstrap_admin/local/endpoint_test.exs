defmodule Origen.BootstrapAdmin.Local.EndpointTest do
  use ExUnit.Case, async: false
  alias Origen.BootstrapAdmin.Local.Endpoint

  setup do
    Endpoint.cleanup()
    on_exit(&Endpoint.cleanup/0)
  end

  test "accepts only an exact IPv4 loopback HTTPS listener and activation URL" do
    parent = self()

    assert :ok =
             Endpoint.start_session(local_config(),
               server_start: fn options ->
                 send(parent, {:server_options, options})
                 {:ok, spawn(fn -> Process.sleep(:infinity) end)}
               end,
               secret_loader: fn -> {:ok, %{verifier_key: "verifier", totp_keyring: :keyring}} end
             )

    assert_receive {:server_options, options}
    assert options[:scheme] == :https
    assert options[:ip] == {127, 0, 0, 1}
    assert options[:port] == 4443
    refute Keyword.has_key?(options, :http)
    assert {:ok, "verifier"} = Endpoint.fetch_secret(:verifier_key)
    assert {:ok, :keyring} = Endpoint.fetch_secret(:totp_keyring)
    refute inspect(:sys.get_state(Endpoint)) =~ "verifier"
    Endpoint.cleanup()
    invalid = put_in(local_config(), [:endpoint, :ip], {0, 0, 0, 0})
    assert {:error, :local_endpoint_invalid} = Endpoint.start_session(invalid)
  end

  test "activation and expiry release waiters and clear cached secrets" do
    server = spawn(fn -> Process.sleep(:infinity) end)
    assert :ok = start_session(fn -> server end)
    waiter = Task.async(&Endpoint.await/0)
    Endpoint.activation_complete()
    assert Task.await(waiter) == :activated
    assert {:error, :secrets_unavailable} = Endpoint.fetch_secret(:verifier_key)
    refute Process.alive?(server)
    expiring = put_in(local_config(), [:retention_ttl_seconds], 1)

    assert :ok = start_session(fn -> spawn(fn -> Process.sleep(:infinity) end) end, expiring)
    assert Endpoint.await() == :expired
    assert {:error, :secrets_unavailable} = Endpoint.fetch_secret(:totp_keyring)
  end

  test "stale expiry from a cleaned-up session does not expire the current session" do
    assert :ok = start_session(fn -> spawn(fn -> Process.sleep(:infinity) end) end)
    %{session_ref: stale_ref} = :sys.get_state(Endpoint)
    Endpoint.cleanup()
    assert :ok = start_session(fn -> spawn(fn -> Process.sleep(:infinity) end) end)
    send(Endpoint, {:expire, stale_ref})
    assert {:ok, "secret"} = Endpoint.fetch_secret(:verifier_key)
  end

  test "listener crash cleans protected state and notifies waiters" do
    assert :ok = start_session(fn -> spawn_link(fn -> Process.sleep(:infinity) end) end)
    %{server: server} = :sys.get_state(Endpoint)
    :ok = Origen.BootstrapAdmin.Local.MailboxStore.push(%{id: "retained"})
    waiter = Task.async(&Endpoint.await/0)
    Process.exit(server, :listener_crashed)

    assert Task.await(waiter) == :listener_failed
    assert Origen.BootstrapAdmin.Local.MailboxStore.count() == 0
    assert {:error, :secrets_unavailable} = Endpoint.fetch_secret(:verifier_key)
  end

  test "cleanup waits until the listener has terminated" do
    parent = self()

    assert :ok =
             start_session(fn ->
               spawn_link(fn ->
                 Process.flag(:trap_exit, true)
                 receive do: ({:EXIT, _, :shutdown} -> Process.sleep(50))
                 send(parent, :listener_stopped)
               end)
             end)

    cleanup = Task.async(&Endpoint.cleanup/0)
    refute Task.yield(cleanup, 10)
    assert Task.await(cleanup) == :ok
    assert_receive :listener_stopped
  end

  test "bounded slow startup can complete beyond the GenServer default call timeout" do
    assert :ok =
             Endpoint.start_session(local_config(),
               startup_timeout: 6_000,
               server_start: fn _options ->
                 Process.sleep(5_100)
                 {:ok, spawn(fn -> Process.sleep(:infinity) end)}
               end,
               secret_loader: fn ->
                 {:ok, %{verifier_key: "secret", totp_keyring: :keyring}}
               end
             )

    assert {:ok, "secret"} = Endpoint.fetch_secret(:verifier_key)
  end

  test "startup timeout owns and terminates a listener before returning" do
    parent = self()

    assert {:error, :local_endpoint_invalid} =
             Endpoint.start_session(local_config(),
               startup_timeout: 25,
               server_start: fn _options ->
                 listener = spawn_link(fn -> Process.sleep(:infinity) end)
                 send(parent, {:listener_started, listener})
                 Process.sleep(100)
                 {:ok, listener}
               end,
               secret_loader: fn ->
                 {:ok, %{verifier_key: "secret", totp_keyring: :keyring}}
               end
             )

    assert_receive {:listener_started, listener}
    monitor = Process.monitor(listener)
    assert_receive {:DOWN, ^monitor, :process, ^listener, _reason}
    refute Process.alive?(listener)
    assert :inactive = :sys.get_state(Endpoint)
    assert {:error, :secrets_unavailable} = Endpoint.fetch_secret(:verifier_key)
  end

  test "accepts configuration with structured Origin without infinite recursion" do
    alias Origen.BootstrapAdmin.Local.Origin

    {:ok, origin} =
      Origin.validate("https://127.0.0.1:4443/admin/activate", %{
        scheme: :https,
        ip: {127, 0, 0, 1},
        port: 4443,
        http: false
      })

    config =
      local_config()
      |> Map.delete(:activation_origin)
      |> Map.put(:origin, origin)

    assert :ok =
             Endpoint.start_session(config,
               server_start: fn _ -> {:ok, spawn(fn -> Process.sleep(:infinity) end)} end,
               secret_loader: fn -> {:ok, %{verifier_key: "secret", totp_keyring: :keyring}} end
             )

    assert {:ok, "secret"} = Endpoint.fetch_secret(:verifier_key)
  end

  defp start_session(server, config \\ local_config()) do
    Endpoint.start_session(config,
      server_start: fn _ -> {:ok, server.()} end,
      secret_loader: fn -> {:ok, %{verifier_key: "secret", totp_keyring: :keyring}} end
    )
  end

  defp local_config do
    %{
      activation_origin: "https://127.0.0.1:4443/admin/activate",
      endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false},
      certificate_file: "/synthetic/cert.pem",
      certificate_key_file: "/synthetic/key.pem",
      retention_ttl_seconds: 30
    }
  end
end
