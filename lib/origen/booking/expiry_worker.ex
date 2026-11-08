defmodule Origen.Booking.ExpiryWorker do
  @moduledoc "Runtime backstop for requested appointment expiry."

  use GenServer

  alias Origen.Booking.Expiry

  @default_interval_ms :timer.minutes(1)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    _ = Expiry.sweep()
    schedule_sweep(Keyword.get(opts, :interval_ms, @default_interval_ms))
    {:ok, %{interval_ms: Keyword.get(opts, :interval_ms, @default_interval_ms)}}
  end

  @impl true
  def handle_info(:sweep, state) do
    _ = Expiry.sweep()
    schedule_sweep(state.interval_ms)
    {:noreply, state}
  end

  defp schedule_sweep(interval_ms), do: Process.send_after(self(), :sweep, interval_ms)
end
