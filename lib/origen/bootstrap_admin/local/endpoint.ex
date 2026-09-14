defmodule Origen.BootstrapAdmin.Local.Endpoint do
  use GenServer
  alias Origen.BootstrapAdmin.Local.{MailboxStore, Origin, Secrets}
  alias OrigenWeb.AdminActivationSessionStore

  defmodule Cache do
    @derive {Inspect, only: []}
    defstruct [:verifier_key, :totp_keyring]
  end

  @startup_timeout 30_000
  @startup_call_grace 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :inactive, name: __MODULE__)

  @doc """
  Starts the serialized local activation session within a 30-second startup budget.

  The endpoint owns the startup worker and its linked listener until startup is accepted,
  so a timeout terminates both before returning an error. `:startup_timeout` may override
  the budget for deterministic tests.
  """
  def start_session(config, opts \\ []) do
    timeout = startup_timeout(opts)

    GenServer.call(
      __MODULE__,
      {:start_session, config, opts, timeout},
      timeout + @startup_call_grace
    )
  end

  def fetch_secret(name) when name in [:verifier_key, :totp_keyring],
    do: GenServer.call(__MODULE__, {:fetch_secret, name})

  def await, do: GenServer.call(__MODULE__, :await, :infinity)
  def activation_complete, do: GenServer.cast(__MODULE__, {:finish, :activated})
  def cleanup, do: GenServer.call(__MODULE__, :cleanup)

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @impl true
  def handle_call({:start_session, config, opts, timeout}, from, state)
      when state == :inactive or elem(state, 0) == :finished do
    MailboxStore.clear()
    AdminActivationSessionStore.clear()
    endpoint = self()
    startup_ref = make_ref()

    {worker, monitor} =
      spawn_monitor(fn ->
        result =
          with {:ok, server_options, ttl} <- listener_options(config),
               {:ok, secrets} <- load_secrets(config, opts),
               {:ok, server} <- start_server(server_options, opts),
               do: {:ok, server, secrets, ttl}

        case result do
          {:ok, server, secrets, ttl} ->
            Process.unlink(server)
            send(endpoint, {:startup_result, startup_ref, {:ok, server, secrets, ttl}})

          failure ->
            send(endpoint, {:startup_result, startup_ref, failure})
        end
      end)

    timer = Process.send_after(self(), {:startup_timeout, startup_ref}, timeout)

    {:noreply,
     %{
       status: :starting,
       from: from,
       worker: worker,
       monitor: monitor,
       timer: timer,
       startup_ref: startup_ref
     }}
  end

  def handle_call({:start_session, _config, _opts, _timeout}, _from, state),
    do: {:reply, {:error, :local_endpoint_active}, state}

  def handle_call({:fetch_secret, name}, _from, %{secrets: secrets} = state) do
    case Map.fetch(secrets, name) do
      {:ok, value} -> {:reply, {:ok, value}, state}
      :error -> {:reply, {:error, :secrets_unavailable}, state}
    end
  end

  def handle_call({:fetch_secret, _name}, _from, state),
    do: {:reply, {:error, :secrets_unavailable}, state}

  def handle_call(:await, from, %{waiters: waiters} = state),
    do: {:noreply, %{state | waiters: [from | waiters]}}

  def handle_call(:await, _from, {:finished, reason} = state), do: {:reply, reason, state}
  def handle_call(:await, _from, :inactive), do: {:reply, :inactive, :inactive}

  def handle_call(:cleanup, _from, state),
    do: cleanup_transition(state, :terminated, {:reply, :ok, :inactive})

  @impl true
  def handle_cast({:finish, reason}, state),
    do: cleanup_transition(state, reason, {:noreply, {:finished, reason}})

  @impl true
  def handle_info(
        {:startup_result, startup_ref, {:ok, server, secrets, ttl}},
        %{status: :starting, startup_ref: startup_ref} = state
      ) do
    Process.cancel_timer(state.timer)
    Process.demonitor(state.monitor, [:flush])
    Process.link(server)
    session_ref = make_ref()
    timer = Process.send_after(self(), {:expire, session_ref}, ttl * 1_000)
    GenServer.reply(state.from, :ok)

    {:noreply,
     %{server: server, secrets: secrets, timer: timer, waiters: [], session_ref: session_ref}}
  end

  def handle_info(
        {:startup_result, startup_ref, _failure},
        %{status: :starting, startup_ref: startup_ref} = state
      ) do
    finish_startup(state)
    GenServer.reply(state.from, {:error, :local_endpoint_invalid})
    {:noreply, :inactive}
  end

  def handle_info({:startup_result, _stale_ref, {:ok, server, _secrets, _ttl}}, state) do
    stop_server(server)
    {:noreply, state}
  end

  def handle_info({:startup_result, _stale_ref, _failure}, state), do: {:noreply, state}

  def handle_info(
        {:startup_timeout, startup_ref},
        %{status: :starting, startup_ref: startup_ref} = state
      ) do
    finish_startup(state)
    GenServer.reply(state.from, {:error, :local_endpoint_invalid})
    {:noreply, :inactive}
  end

  def handle_info({:startup_timeout, _stale_ref}, state), do: {:noreply, state}

  def handle_info({:DOWN, monitor, :process, worker, _reason}, %{status: :starting} = state)
      when monitor == state.monitor and worker == state.worker do
    Process.cancel_timer(state.timer)
    GenServer.reply(state.from, {:error, :local_endpoint_invalid})
    {:noreply, :inactive}
  end

  def handle_info({:DOWN, _monitor, :process, _worker, _reason}, state), do: {:noreply, state}

  def handle_info({:expire, session_ref}, %{session_ref: session_ref} = state),
    do: cleanup_transition(state, :expired, {:noreply, {:finished, :expired}})

  def handle_info({:expire, _stale_ref}, state), do: {:noreply, state}

  def handle_info({:EXIT, server, _reason}, %{server: server} = state) do
    cleanup_state(state, :listener_failed)
    {:noreply, {:finished, :listener_failed}}
  end

  defp listener_options(%{origin: %Origin{} = origin} = config) do
    config
    |> Map.delete(:origin)
    |> Map.put(:activation_origin, Origin.to_uri(origin))
    |> listener_options()
  end

  defp listener_options(%{
         activation_origin: origin,
         endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: port, http: false} = endpoint,
         certificate_file: certfile,
         certificate_key_file: keyfile,
         retention_ttl_seconds: ttl
       })
       when is_integer(port) and port in 1..65_535 and is_integer(ttl) and ttl in 1..900 and
              is_binary(certfile) and is_binary(keyfile) do
    with {:ok, _exact_origin} <- Origin.validate(origin, endpoint) do
      {:ok,
       [
         plug: OrigenWeb.Endpoint,
         scheme: :https,
         ip: {127, 0, 0, 1},
         port: port,
         certfile: certfile,
         keyfile: keyfile
       ], ttl}
    end
  end

  defp listener_options(_config), do: {:error, :invalid_listener}

  defp load_secrets(ready, opts) do
    loader =
      Keyword.get(opts, :secret_loader, fn ->
        with {:ok, verifier_key} <- Secrets.get_verifier_key(ready),
             {:ok, totp_keyring} <- Secrets.get_totp_keyring(ready),
             do: {:ok, %{verifier_key: verifier_key, totp_keyring: totp_keyring}}
      end)

    case loader.() do
      {:ok, %{verifier_key: verifier_key, totp_keyring: totp_keyring}} ->
        {:ok, %Cache{verifier_key: verifier_key, totp_keyring: totp_keyring}}

      _ ->
        {:error, :secrets_unavailable}
    end
  rescue
    _ -> {:error, :secrets_unavailable}
  catch
    _, _ -> {:error, :secrets_unavailable}
  end

  defp start_server(options, opts) do
    starter = Keyword.get(opts, :server_start, &Bandit.start_link/1)

    case starter.(options) do
      {:ok, pid} when is_pid(pid) -> {:ok, pid}
      _ -> {:error, :listener_unavailable}
    end
  rescue
    _ -> {:error, :listener_unavailable}
  catch
    _, _ -> {:error, :listener_unavailable}
  end

  defp cleanup_transition(state, reason, transition) do
    cleanup_state(state, reason)
    transition
  end

  defp cleanup_state(:inactive, _reason), do: :ok
  defp cleanup_state({:finished, _reason}, _new_reason), do: :ok

  defp cleanup_state(%{status: :starting} = state, _reason) do
    finish_startup(state)
    GenServer.reply(state.from, {:error, :local_endpoint_invalid})
    MailboxStore.clear()
    AdminActivationSessionStore.clear()
    :ok
  end

  defp cleanup_state(state, reason) do
    Process.cancel_timer(state.timer)
    stop_server(state.server)
    MailboxStore.clear()
    AdminActivationSessionStore.clear()
    Enum.each(state.waiters, &GenServer.reply(&1, reason))
    :ok
  end

  defp finish_startup(state) do
    Process.cancel_timer(state.timer)
    Process.demonitor(state.monitor, [:flush])
    Process.exit(state.worker, :kill)
    :ok
  end

  defp startup_timeout(opts) do
    case Keyword.get(opts, :startup_timeout, @startup_timeout) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _invalid -> @startup_timeout
    end
  end

  defp stop_server(pid) when is_pid(pid) do
    monitor = Process.monitor(pid)
    Process.unlink(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
    end
  end
end
