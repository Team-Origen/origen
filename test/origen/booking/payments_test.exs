defmodule Origen.Booking.PaymentsTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "patient receives only final price and payment state for their appointment", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f, start_time: DateTime.add(DateTime.utc_now(), 14_400, :second))

    assert {:ok, projection} = Booking.get_payment(Fixtures.patient_principal(f), appointment.id)

    assert projection == %{
             appointment_id: appointment.id,
             final_price_ars: Decimal.new("100.00"),
             payment_status: "pending"
           }
  end

  test "patient, administrator and foreign professional cannot edit price", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        start_time: DateTime.add(DateTime.utc_now(), 18_000, :second)
      )

    assert {:error, :unauthorized} =
             Booking.update_final_price(Fixtures.patient_principal(f), appointment.id, "90.00")

    assert {:error, :unauthorized} =
             Booking.update_final_price(Fixtures.admin_principal(f), appointment.id, "90.00")

    assert {:error, :unauthorized} =
             Booking.update_final_price(
               Fixtures.professional_principal(f),
               appointment.id,
               "90.00"
             )

    assert {:ok, projection} =
             Booking.get_payment(Fixtures.secretary_principal(f), appointment.id)

    assert Decimal.equal?(projection.final_price_ars, Decimal.new("100.00"))
  end

  test "secretary can read and edit an appointment from any agenda", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        start_time: DateTime.add(DateTime.utc_now(), 19_800, :second)
      )

    assert {:ok, %{payment_status: "pending"}} =
             Booking.get_payment(Fixtures.secretary_principal(f), appointment.id)

    assert {:ok, %{final_price_ars: price}} =
             Booking.update_final_price(Fixtures.secretary_principal(f), appointment.id, "75.00")

    assert Decimal.equal?(price, Decimal.new("75.00"))
  end

  test "patient cannot read another patient's payment projection", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f,
        patient_profile_id: f.other_patient_id,
        start_time: DateTime.add(DateTime.utc_now(), 21_600, :second)
      )

    assert {:error, :unauthorized} =
             Booking.get_payment(Fixtures.patient_principal(f), appointment.id)
  end
end
