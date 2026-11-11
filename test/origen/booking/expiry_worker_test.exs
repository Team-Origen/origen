defmodule Origen.Booking.ExpiryWorkerTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Booking.Appointment
  alias Origen.Booking.ExpiryWorker
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    owner = Sandbox.start_owner!(Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    %{fixture: Fixtures.create!(), owner: owner}
  end

  test "keeps the supervised worker alive when a periodic sweep lacks sandbox ownership", %{
    owner: owner
  } do
    worker = Process.whereis(ExpiryWorker)
    assert is_pid(worker)

    ref = Process.monitor(worker)
    Sandbox.mode(Repo, :manual)
    send(worker, :sweep)

    refute_receive {:DOWN, ^ref, :process, ^worker, _reason}, 1_000
    Sandbox.mode(Repo, {:shared, owner})
    Process.demonitor(ref, [:flush])
  end

  test "background sweeps expire due requests after the worker receives test ownership", %{
    fixture: fixture,
    owner: owner
  } do
    worker = Process.whereis(ExpiryWorker)
    assert is_pid(worker)
    :ok = Sandbox.allow(Repo, owner, worker)

    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), -60, :second),
        status: "requested"
      )

    send(worker, :sweep)
    :sys.get_state(worker)

    assert Repo.get!(Appointment, appointment.id).status == "expired"
  end
end
