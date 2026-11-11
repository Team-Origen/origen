defmodule Origen.Booking.PaymentConcurrencyTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Booking
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @enabled System.get_env("ORIGEN_PAYMENT_CONCURRENCY") == "1"
  @database_prefix "origen_test_385_concurrency_"

  if not @enabled do
    @moduletag :skip
  end

  setup do
    if @enabled do
      assert_task_owned_database!()
      :ok = Sandbox.checkout(Repo, sandbox: false)

      on_exit(fn ->
        Sandbox.checkin(Repo)
      end)
    end

    :ok
  end

  test "distinct PostgreSQL connections allow only one concurrent registration" do
    fixture = Fixtures.create!()

    appointment =
      Fixtures.appointment!(fixture,
        start_time: ~U[2030-02-01 09:00:00Z],
        status: "confirmed"
      )

    principal = Fixtures.professional_principal(fixture)

    results =
      run_concurrently(
        2,
        fn -> Booking.record_payment(principal, appointment.id, "cash") end
      )

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :payment_already_paid})) == 1

    assert {:ok, projection} = Booking.get_payment(principal, appointment.id)
    assert projection.payment_status == "paid"
    assert {:ok, [action]} = Booking.list_payment_actions(principal, appointment.id)
    assert action.action == "paid"
  end

  test "distinct PostgreSQL connections serialize registration and price edit lawfully" do
    fixture = Fixtures.create!()

    appointment =
      Fixtures.appointment!(fixture,
        start_time: ~U[2030-02-02 09:00:00Z],
        status: "confirmed"
      )

    principal = Fixtures.professional_principal(fixture)

    results =
      run_concurrently([
        fn -> Booking.record_payment(principal, appointment.id, "cash") end,
        fn -> Booking.update_final_price(principal, appointment.id, "80.00") end
      ])

    assert Enum.count(results, &match?({:ok, %{payment_status: "paid"}}, &1)) == 1

    assert Enum.any?(results, fn
             {:ok, %{payment_status: "pending"}} -> true
             {:error, :payment_already_paid} -> true
             _ -> false
           end)

    assert {:ok, projection} = Booking.get_payment(principal, appointment.id)
    assert projection.payment_status == "paid"
    assert Decimal.equal?(projection.paid_amount_ars, projection.final_price_ars)
    assert {:ok, [action]} = Booking.list_payment_actions(principal, appointment.id)
    assert Decimal.equal?(action.amount_ars, projection.final_price_ars)
  end

  defp run_concurrently(count, fun),
    do: run_concurrently(Enum.map(1..count, fn _ -> fun end))

  defp run_concurrently(functions) do
    parent = self()

    tasks =
      Enum.map(functions, fn fun ->
        Task.async(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          backend_pid = backend_pid!()
          send(parent, {:ready, self(), backend_pid})

          receive do
            :start -> :ok
          after
            10_000 -> exit(:barrier_timeout)
          end

          started_at = System.monotonic_time(:microsecond)
          send(parent, {:started, self(), started_at})
          Repo.query!("SELECT pg_sleep(0.05)")

          receive do
            :run -> :ok
          after
            10_000 -> exit(:barrier_timeout)
          end

          try do
            fun.()
          after
            Sandbox.checkin(Repo)
          end
        end)
      end)

    ready =
      Enum.map(tasks, fn task ->
        pid = task.pid
        assert_receive {:ready, ^pid, backend_pid}, 10_000
        backend_pid
      end)

    assert length(Enum.uniq(ready)) == length(tasks)
    Enum.each(tasks, fn task -> send(task.pid, :start) end)

    started =
      Enum.map(tasks, fn task ->
        pid = task.pid
        assert_receive {:started, ^pid, started_at}, 10_000
        started_at
      end)

    assert Enum.max(started) - Enum.min(started) < 1_000_000
    Enum.each(tasks, fn task -> send(task.pid, :run) end)
    Enum.map(tasks, &Task.await(&1, 15_000))
  end

  defp backend_pid! do
    %{rows: [[backend_pid]]} = Repo.query!("SELECT pg_backend_pid()")
    backend_pid
  end

  defp assert_task_owned_database! do
    database = Application.get_env(:origen, Origen.Repo)[:database] |> to_string()
    partition = System.get_env("MIX_TEST_PARTITION", "")

    valid_database? =
      String.starts_with?(database, @database_prefix) and
        Regex.match?(~r/^origen_test_385_concurrency_[0-9]+_[0-9]+$/, database) and
        partition == String.replace_prefix(database, "origen_test", "")

    if not valid_database? do
      raise "payment concurrency tests require a task-owned disposable database with prefix #{@database_prefix}"
    end
  end
end
