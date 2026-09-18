defmodule OrigenWeb.InternalActivationSessionStore do
  @moduledoc false
  use GenServer

  @name __MODULE__
  @maximum_ttl_seconds 900

  defmodule Session do
    @moduledoc false
    @derive {Inspect, only: [:invitation_id, :account_id, :expires_at, :rendered?]}
    @enforce_keys [
      :invitation_id,
      :account_id,
      :token,
      :seed,
      :expires_at,
      :rendered?
    ]
    defstruct @enforce_keys
  end

  def start_link(_options), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  def create(invitation_id, account_id, token)
      when is_integer(invitation_id) and is_integer(account_id) and is_binary(token) do
    call({:create, invitation_id, account_id, token})
  end

  def create(_invitation_id, _account_id, _token), do: {:error, :invalid_session}

  def take_for_render(nonce), do: call({:take_for_render, nonce})
  def fetch(nonce), do: call({:fetch, nonce})
  def delete(nonce), do: call({:delete, nonce})

  @doc false
  def clear, do: call(:clear)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def format_status(status) do
    status
    |> Map.put(:state, :redacted)
    |> Map.put(:message, :redacted)
    |> Map.put(:log, [])
  end

  @impl true
  def handle_call({:create, invitation_id, account_id, token}, _from, sessions) do
    ttl = Application.get_env(:origen, :internal_activation_session_ttl_seconds, 600)

    if is_integer(ttl) and ttl > 0 and ttl <= @maximum_ttl_seconds do
      nonce = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      session = %Session{
        invitation_id: invitation_id,
        account_id: account_id,
        token: token,
        seed: NimbleTOTP.secret(),
        expires_at: System.monotonic_time(:second) + ttl,
        rendered?: false
      }

      {:reply, {:ok, nonce}, Map.put(purge(sessions), nonce, session)}
    else
      {:reply, {:error, :invalid_configuration}, purge(sessions)}
    end
  end

  def handle_call({:take_for_render, nonce}, _from, sessions) do
    sessions = purge(sessions)

    case Map.fetch(sessions, nonce) do
      {:ok, %Session{rendered?: false} = session} ->
        {:reply, {:ok, session}, put_in(sessions, [nonce, Access.key(:rendered?)], true)}

      _missing_or_rendered ->
        {:reply, {:error, :invalid_session}, Map.delete(sessions, nonce)}
    end
  end

  def handle_call({:fetch, nonce}, _from, sessions) do
    sessions = purge(sessions)

    case Map.fetch(sessions, nonce) do
      {:ok, %Session{rendered?: true} = session} -> {:reply, {:ok, session}, sessions}
      _missing -> {:reply, {:error, :invalid_session}, sessions}
    end
  end

  def handle_call(:clear, _from, _sessions), do: {:reply, :ok, %{}}

  def handle_call({:delete, nonce}, _from, sessions),
    do: {:reply, :ok, Map.delete(sessions, nonce)}

  defp call(message) do
    with :ok <- ensure_started() do
      GenServer.call(@name, message)
    end
  catch
    :exit, _reason -> {:error, :invalid_session}
  end

  defp ensure_started do
    case Process.whereis(@name) do
      nil -> start_supervised()
      _pid -> :ok
    end
  end

  defp start_supervised do
    case Supervisor.start_child(Origen.Supervisor, {__MODULE__, []}) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, :already_present} -> restart_supervised()
      {:error, reason} -> {:error, reason}
    end
  end

  defp restart_supervised do
    case Supervisor.restart_child(Origen.Supervisor, __MODULE__) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, {:running, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp purge(sessions) do
    now = System.monotonic_time(:second)
    Map.reject(sessions, fn {_nonce, session} -> session.expires_at <= now end)
  end
end
