defmodule Origen.Booking.PaymentPersistenceTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "new appointments have a pending payment and retain the snapshot", %{fixture: f} do
    assert {:ok, appointment} =
             Booking.persist_appointment(
               %{
                 patient_profile_id: f.patient_id,
                 professional_account_id: f.professional_id,
                 consultation_type_id: f.consultation_type_id,
                 start_time: DateTime.add(DateTime.utc_now(), 7200, :second),
                 status: "confirmed"
               },
               %{
                 name: "Lifecycle consultation",
                 duration_minutes: 30,
                 exact_price_ars: Decimal.new("125.50")
               }
             )

    assert {:ok, projection} =
             Booking.get_payment(Fixtures.professional_principal(f), appointment.id)

    assert Decimal.equal?(projection.final_price_ars, Decimal.new("125.50"))
    assert projection.payment_status == "pending"
  end

  test "general appointment changesets cannot inject the final price", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f, start_time: DateTime.add(DateTime.utc_now(), 9_000, :second))

    changeset = Appointment.changeset(appointment, %{final_price_ars: Decimal.new("1.00")})

    refute Map.has_key?(changeset.changes, :final_price_ars)

    assert {:ok, projection} =
             Booking.get_payment(Fixtures.professional_principal(f), appointment.id)

    assert Decimal.equal?(projection.final_price_ars, Decimal.new("100.00"))
  end

  test "migration-compatible payment rows can be queried without changing the snapshot", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: DateTime.add(DateTime.utc_now(), 10_800, :second))

    assert {:ok, %{payment_status: "pending", final_price_ars: price}} =
             Booking.get_payment(Fixtures.professional_principal(f), appointment.id)

    assert Decimal.equal?(price, Decimal.new("100.00"))
  end

  test "existing cancellation preserves the pending payment through the public facade", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f,
        status: "confirmed",
        start_time: DateTime.add(DateTime.utc_now(), 12_600, :second)
      )

    assert {:ok, %{status: "cancelled"}} =
             Booking.cancel_appointment(
               Fixtures.professional_principal(f),
               appointment.id,
               reason: "Prueba de preservación"
             )

    assert {:ok, projection} =
             Booking.get_payment(Fixtures.professional_principal(f), appointment.id)

    assert projection.payment_status == "pending"
    assert Decimal.equal?(projection.final_price_ars, Decimal.new("100.00"))
  end

  test "existing public reservation initializes a pending payment", %{fixture: f} do
    assert {:ok, response} =
             Booking.reserve_appointment(
               %{
                 actor: %{role: :secretary, id: f.secretary_id},
                 patient_id: f.patient_id,
                 professional_id: f.professional_id,
                 consultation_type_id: f.consultation_type_id,
                 start_time: DateTime.add(DateTime.utc_now(), 28_800, :second),
                 patient_agreed_schedule: true
               },
               now: DateTime.utc_now()
             )

    assert {:ok, projection} =
             Booking.get_payment(Fixtures.secretary_principal(f), response.appointment_id)

    assert projection.payment_status == "pending"
  end

  test "a preexisting pending appointment without history can be deleted", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f, start_time: DateTime.add(DateTime.utc_now(), 36_000, :second))

    assert {:ok, %{num_rows: 1}} =
             SQL.query(Repo, "DELETE FROM public.appointments WHERE id = $1", [appointment.id])

    assert SQL.query!(Repo, "SELECT count(*) FROM public.appointments WHERE id = $1", [
             appointment.id
           ]).rows ==
             [[0]]

    assert SQL.query!(
             Repo,
             "SELECT count(*) FROM public.appointment_payments WHERE appointment_id = $1",
             [appointment.id]
           ).rows == [[0]]
  end

  test "a paid appointment cannot be deleted and remains observable through financial history", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f,
        start_time: DateTime.add(DateTime.utc_now(), 39_600, :second),
        status: "confirmed"
      )

    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")

    assert_delete_rejected!(appointment.id)

    assert {:ok, %{payment_status: "paid"}} = Booking.get_payment(principal, appointment.id)
    assert {:ok, [%{action: "paid"}]} = Booking.list_payment_actions(principal, appointment.id)
  end

  test "a paid then reverted appointment cannot be deleted and retains its full history", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f,
        start_time: DateTime.add(DateTime.utc_now(), 43_200, :second),
        status: "confirmed"
      )

    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "transfer")

    assert {:ok, %{payment_status: "pending"}} =
             Booking.revert_payment(principal, appointment.id, true)

    assert_delete_rejected!(appointment.id)

    assert {:ok, %{payment_status: "pending"}} = Booking.get_payment(principal, appointment.id)
    assert {:ok, actions} = Booking.list_payment_actions(principal, appointment.id)
    assert Enum.map(actions, & &1.action) == ["paid", "reverted"]
  end

  defp assert_delete_rejected!(appointment_id) do
    result =
      SQL.query(
        Repo,
        "DELETE FROM public.appointments WHERE id = $1",
        [appointment_id],
        mode: :savepoint
      )

    assert {:error, %Postgrex.Error{} = error} = result
    assert error.postgres.code == :restrict_violation
  end
end
