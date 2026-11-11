defmodule Origen.Booking.PaymentCleanupCompatibilityTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Booking
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "a pending appointment without history can be deleted through the compatibility path", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: DateTime.add(DateTime.utc_now(), 36_000, :second))

    principal = Fixtures.professional_principal(f)

    assert {:ok, %{payment_status: "pending"}} =
             Booking.get_payment(principal, appointment.id)

    assert {:ok, %{num_rows: 1}} =
             SQL.query(
               Repo,
               "DELETE FROM public.appointments WHERE id = $1",
               [appointment.id],
               mode: :savepoint
             )

    assert {:error, :unauthorized} = Booking.get_payment(principal, appointment.id)

    assert SQL.query!(
             Repo,
             "SELECT count(*) FROM public.appointments WHERE id = $1",
             [appointment.id]
           ).rows == [[0]]

    assert SQL.query!(
             Repo,
             "SELECT count(*) FROM public.appointment_payments WHERE appointment_id = $1",
             [appointment.id]
           ).rows == [[0]]
  end
end
