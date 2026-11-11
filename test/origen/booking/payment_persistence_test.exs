defmodule Origen.Booking.PaymentPersistenceTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
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
end
