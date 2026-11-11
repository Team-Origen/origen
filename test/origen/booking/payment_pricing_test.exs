defmodule Origen.Booking.PaymentPricingTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "persists an editable final price separately from the immutable snapshot", %{fixture: f} do
    appointment = persist_appointment!(f, Decimal.new("100.00"))
    principal = Fixtures.professional_principal(f)

    assert {:ok, projection} = Booking.update_final_price(principal, appointment.id, "80.00")
    assert Decimal.equal?(projection.final_price_ars, Decimal.new("80.00"))

    assert {:ok, public_projection} = Booking.get_payment(principal, appointment.id)
    assert Decimal.equal?(public_projection.final_price_ars, Decimal.new("80.00"))

    persisted = Repo.get!(Appointment, appointment.id)
    assert Decimal.equal?(persisted.snapshot_exact_price_ars, Decimal.new("100.00"))
  end

  test "accepts zero and rejects negative or malformed prices without mutation", %{fixture: f} do
    appointment = persist_appointment!(f, Decimal.new("100.00"))
    principal = Fixtures.professional_principal(f)

    assert {:ok, projection} =
             Booking.update_final_price(principal, appointment.id, Decimal.new("0"))

    assert Decimal.equal?(projection.final_price_ars, Decimal.new("0"))

    assert {:ok, precise_projection} =
             Booking.update_final_price(principal, appointment.id, "80.125")

    assert Decimal.equal?(precise_projection.final_price_ars, Decimal.new("80.125"))

    for invalid <- ["-0.01", "not-money", Decimal.new("NaN"), Decimal.new("Infinity")] do
      {:ok, before} = Booking.get_payment(principal, appointment.id)

      assert {:error, :invalid_final_price} =
               Booking.update_final_price(principal, appointment.id, invalid)

      assert {:ok, after_rejection} = Booking.get_payment(principal, appointment.id)
      assert after_rejection.final_price_ars == before.final_price_ars
      assert after_rejection.payment_status == before.payment_status
    end
  end

  test "paid price is immutable through the public pricing operation", %{fixture: f} do
    appointment = persist_appointment!(f, Decimal.new("100.00"))
    principal = Fixtures.professional_principal(f)

    assert {:ok, _payment} = Booking.record_payment(principal, appointment.id, "cash")

    assert {:error, :payment_already_paid} =
             Booking.update_final_price(principal, appointment.id, "80.00")

    assert {:ok, projection} = Booking.get_payment(principal, appointment.id)
    assert Decimal.equal?(projection.final_price_ars, Decimal.new("100.00"))
    assert projection.payment_status == "paid"
  end

  defp persist_appointment!(fixture, price) do
    assert {:ok, appointment} =
             Booking.persist_appointment(
               %{
                 patient_profile_id: fixture.patient_id,
                 professional_account_id: fixture.professional_id,
                 consultation_type_id: fixture.consultation_type_id,
                 start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
                 status: "confirmed"
               },
               %{
                 name: "Lifecycle consultation",
                 duration_minutes: 30,
                 exact_price_ars: price
               }
             )

    appointment
  end
end
