defmodule OrigenWeb.ProviderEventReplay do
  use GenServer
  @table :origen_bootstrap_provider_event_replays
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def claim({event, _, _} = id), do: claim(event, id)
  def complete(id), do: replace(id, :done)

  def release({event, _, _} = id),
    do: :ets.delete_object(@table, {event, id, self(), :working}) && :ok

  def init(nil), do: {:ok, :ets.new(@table, [:named_table, :public, :set])}

  defp claim(event, id) do
    case :ets.insert_new(@table, {event, id, self(), :working}) do
      true -> :ok
      false -> await(event, id, hd(:ets.lookup(@table, event)))
    end
  end

  defp await(_, id, {_, stored, _, :done}) when stored == id, do: {:duplicate, id}

  defp await(event, id, {_, stored, owner, :working} = claim) when stored == id do
    ref = Process.monitor(owner)

    receive do
      {:DOWN, ^ref, :process, ^owner, _} -> :ets.delete_object(@table, claim)
    after
      10 -> Process.demonitor(ref, [:flush])
    end

    claim(event, id)
  end

  defp await(_, _, _), do: :conflict

  defp replace({event, _, _} = id, state) do
    true = :ets.insert(@table, {event, id, self(), state})
    :ok
  end
end
