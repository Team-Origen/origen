defmodule Origen.PostgresSecurityCaseTest do
  use ExUnit.Case, async: true

  alias Origen.PostgresSecurityCase

  defmodule FailingConnection do
    use GenServer

    def init(state), do: {:ok, state}

    def terminate(_reason, _state), do: exit(:unexpected_shutdown)
  end

  test "cleanup tolerates a connection that has already stopped" do
    {:ok, connection} = Agent.start(fn -> nil end)
    Agent.stop(connection)

    assert PostgresSecurityCase.stop_connection(connection) == :ok
  end

  test "cleanup stops a live connection synchronously" do
    {:ok, connection} = Agent.start(fn -> nil end)
    monitor = Process.monitor(connection)

    assert PostgresSecurityCase.stop_connection(connection) == :ok
    assert_receive {:DOWN, ^monitor, :process, ^connection, :normal}
    refute Process.alive?(connection)
  end

  test "independent cleanup callers can stop the same connection" do
    {:ok, connection} = Agent.start(fn -> nil end)

    callers =
      for _ <- 1..2 do
        Task.async(fn ->
          receive do
            :stop -> PostgresSecurityCase.stop_connection(connection)
          end
        end)
      end

    Enum.each(callers, &send(&1.pid, :stop))
    assert Enum.map(callers, &Task.await/1) == [:ok, :ok]
    refute Process.alive?(connection)
  end

  @tag capture_log: true
  test "cleanup does not hide unexpected shutdown errors" do
    {:ok, connection} = GenServer.start(FailingConnection, nil)

    assert {:unexpected_shutdown, _} =
             catch_exit(PostgresSecurityCase.stop_connection(connection))
  end
end
