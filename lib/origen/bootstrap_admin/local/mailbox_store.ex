defmodule Origen.BootstrapAdmin.Local.MailboxStore do
  @moduledoc """
  Atomic, thread-safe bounded in-memory message store for local bootstrap.
  Holds at most 1 message and expires messages based on TTL (<= 900 seconds).
  """

  use GenServer

  @name __MODULE__
  @default_max_ttl 900

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def ensure_started do
    case Process.whereis(@name) do
      nil ->
        case start_link() do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end

      pid ->
        {:ok, pid}
    end
  end

  @doc """
  Pushes a message into the store if empty.
  Returns `:ok` or `{:error, :mailbox_full}`.
  Options can include:
  - `:ttl_seconds`: TTL in seconds (1..900, defaults to 900)
  - `:clock`: nullary function returning current unix timestamp in seconds
  """
  def call_store(msg) do
    case Process.whereis(@name) do
      nil ->
        case start_link() do
          {:ok, _pid} -> GenServer.call(@name, msg)
          {:error, {:already_started, _pid}} -> GenServer.call(@name, msg)
        end

      pid when is_pid(pid) ->
        try do
          GenServer.call(@name, msg)
        catch
          :exit, {:noproc, _} ->
            case start_link() do
              {:ok, _} -> GenServer.call(@name, msg)
              {:error, {:already_started, _}} -> GenServer.call(@name, msg)
            end
        end
    end
  end

  def push(message, opts \\ []) do
    call_store({:push, message, opts})
  end

  def get(id, opts \\ []) do
    call_store({:get, id, opts})
  end

  def all(opts \\ []) do
    call_store({:all, opts})
  end

  def count(opts \\ []) do
    call_store({:count, opts})
  end

  def clear do
    call_store(:clear)
  end

  def delete_all, do: clear()

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    # State is nil or %{id: id, message: msg, expires_at: pos_integer}
    clear_preview()
    {:ok, nil}
  end

  @impl true
  def handle_call({:push, message, opts}, _from, state) do
    clock = Keyword.get(opts, :clock, &now_seconds/0)
    now = clock.()
    ttl = Keyword.get(opts, :ttl_seconds, @default_max_ttl) |> min(@default_max_ttl) |> max(1)

    state = purge_if_expired(state, now)

    case state do
      nil ->
        id = message_id(message)
        item = %{id: id, message: message, expires_at: now + ttl}
        {:reply, :ok, item}

      _already_retained ->
        {:reply, {:error, :mailbox_full}, state}
    end
  end

  @impl true
  def handle_call({:get, id, opts}, _from, state) do
    clock = Keyword.get(opts, :clock, &now_seconds/0)
    now = clock.()
    state = purge_if_expired(state, now)

    case state do
      %{id: ^id, message: msg} ->
        {:reply, msg, state}

      _ ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:all, opts}, _from, state) do
    clock = Keyword.get(opts, :clock, &now_seconds/0)
    now = clock.()
    state = purge_if_expired(state, now)

    case state do
      nil -> {:reply, [], nil}
      %{message: msg} -> {:reply, [msg], state}
    end
  end

  @impl true
  def handle_call({:count, opts}, _from, state) do
    clock = Keyword.get(opts, :clock, &now_seconds/0)
    now = clock.()
    state = purge_if_expired(state, now)

    count = if is_nil(state), do: 0, else: 1
    {:reply, count, state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    clear_preview()
    {:reply, :ok, nil}
  end

  defp purge_if_expired(nil, _now), do: nil

  defp purge_if_expired(%{expires_at: expires_at}, now) when now >= expires_at do
    clear_preview()
    nil
  end

  defp purge_if_expired(state, _now), do: state

  defp clear_preview do
    Swoosh.Adapters.Local.Storage.Memory.delete_all()
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp now_seconds do
    System.system_time(:second)
  end

  defp message_id(%{id: id}) when not is_nil(id), do: to_string(id)
  defp message_id(%Swoosh.Email{headers: %{"Message-ID" => id}}), do: to_string(id)
  defp message_id(_), do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
end
