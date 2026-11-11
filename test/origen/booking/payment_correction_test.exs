defmodule Origen.Booking.PaymentCorrectionTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Booking
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "false, nil and cancelled confirmation are no-ops", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(1), status: "confirmed")
    professional = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(professional, appointment.id, "cash")
    before = rejection_state(professional, appointment.id)

    for confirmation <- [false, nil, :cancelled] do
      assert {:error, :confirmation_required} =
               Booking.revert_payment(professional, appointment.id, confirmation)

      assert rejection_state(professional, appointment.id) == before
    end
  end

  test "confirmed reversal clears active metadata and appends immutable trace", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(2), status: "confirmed")
    professional = Fixtures.professional_principal(f)
    secretary = Fixtures.secretary_principal(f)

    assert {:ok, paid} = Booking.record_payment(professional, appointment.id, "cash")
    assert {:ok, [paid_action]} = Booking.list_payment_actions(professional, appointment.id)
    assert paid_action.action == "paid"

    assert {:ok, reverted} = Booking.revert_payment(secretary, appointment.id, true)
    assert reverted.payment_status == "pending"
    assert reverted.payment_method == nil
    assert reverted.paid_amount_ars == nil
    assert reverted.paid_actor_kind == nil
    assert reverted.paid_actor_ref == nil
    assert reverted.paid_at == nil
    assert Decimal.equal?(reverted.final_price_ars, paid.final_price_ars)

    assert {:ok, actions} = Booking.list_payment_actions(secretary, appointment.id)
    assert Enum.map(actions, & &1.action) == ["paid", "reverted"]
    [original, correction] = actions
    assert original == paid_action
    assert Decimal.equal?(correction.amount_ars, Decimal.new("100.00"))
    assert correction.method == "cash"
    assert correction.actor_kind == "secretary"
    assert correction.actor_ref == "internal_account:#{f.secretary_id}"
    assert %DateTime{} = correction.occurred_at
    assert DateTime.compare(correction.occurred_at, original.occurred_at) in [:gt, :eq]

    events = Fixtures.audit_events_for(appointment.id)

    assert Enum.map(events, &Enum.at(&1, 2)) == [
             "appointment_payment_registered",
             "appointment_payment_reverted"
           ]

    assert Enum.all?(events, &(Enum.at(&1, 3) == "appointment"))
  end

  test "repeat reversal is rejected without duplicate action or audit", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(3), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "transfer")
    assert {:ok, _} = Booking.revert_payment(principal, appointment.id, true)
    before = rejection_state(principal, appointment.id)

    assert {:error, :payment_not_paid} = Booking.revert_payment(principal, appointment.id, true)
    assert rejection_state(principal, appointment.id) == before
  end

  test "reversal failure rolls back payment, action and audit atomically", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(4), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")
    before = rejection_state(principal, appointment.id)

    for fail_at <- [:payment_action, :audit_event] do
      assert {:error, error} =
               Booking.revert_payment(principal, appointment.id, true, fail_at: fail_at)

      assert error in [:payment_action_unavailable, :audit_unavailable]
      assert rejection_state(principal, appointment.id) == before
    end
  end

  test "a paid cancelled or no-show appointment can be corrected but not repaid", %{fixture: f} do
    for status <- [:cancelled, :no_show] do
      appointment =
        Fixtures.appointment!(f, start_time: future_time(unique_offset()), status: "confirmed")

      principal = Fixtures.professional_principal(f)

      assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")

      if status == :cancelled do
        assert {:ok, %{status: "cancelled"}} =
                 Booking.cancel_appointment(principal, appointment.id, reason: "Prueba")
      else
        assert {:ok, %{status: "no_show"}} =
                 Booking.record_attendance(principal, appointment.id, :no_show)
      end

      assert {:ok, _} = Booking.revert_payment(principal, appointment.id, true)
      assert {:ok, %{payment_status: "pending"}} = Booking.get_payment(principal, appointment.id)
      assert {:ok, _} = Booking.update_final_price(principal, appointment.id, "80.00")

      assert {:error, :payment_not_eligible} =
               Booking.record_payment(principal, appointment.id, "cash")
    end
  end

  test "eligible correction, price edit and repayment retain one current payment sequence", %{
    fixture: f
  } do
    appointment = Fixtures.appointment!(f, start_time: future_time(7), status: "confirmed")
    principal = Fixtures.professional_principal(f)

    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")
    assert {:ok, _} = Booking.revert_payment(principal, appointment.id, true)

    assert {:ok, %{final_price_ars: price}} =
             Booking.update_final_price(principal, appointment.id, "80.00")

    assert Decimal.equal?(price, Decimal.new("80.00"))
    assert {:ok, projection} = Booking.record_payment(principal, appointment.id, "transfer")
    assert projection.payment_status == "paid"
    assert Decimal.equal?(projection.paid_amount_ars, Decimal.new("80.00"))

    assert {:ok, actions} = Booking.list_payment_actions(principal, appointment.id)
    assert Enum.map(actions, & &1.action) == ["paid", "reverted", "paid"]
    assert Decimal.equal?(Enum.at(actions, 0).amount_ars, Decimal.new("100.00"))
    assert Decimal.equal?(Enum.at(actions, 1).amount_ars, Decimal.new("100.00"))
    assert Decimal.equal?(Enum.at(actions, 2).amount_ars, Decimal.new("80.00"))
    assert Enum.at(actions, 1).method == "cash"
    assert Enum.at(actions, 2).method == "transfer"

    assert {:ok, current} = Booking.get_payment(principal, appointment.id)
    assert current.payment_status == "paid"
    assert Decimal.equal?(current.paid_amount_ars, current.final_price_ars)
  end

  test "zero payment can be corrected and paid again", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(8), status: "confirmed")
    principal = Fixtures.professional_principal(f)

    assert {:ok, %{final_price_ars: zero}} =
             Booking.update_final_price(principal, appointment.id, "0")

    assert Decimal.equal?(zero, Decimal.new("0"))
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, :transfer)
    assert {:ok, _} = Booking.revert_payment(principal, appointment.id, true)
    assert {:ok, projection} = Booking.record_payment(principal, appointment.id, :cash)
    assert Decimal.equal?(projection.paid_amount_ars, Decimal.new("0"))
  end

  test "reversal preserves operational state, appointment date and other appointments", %{
    fixture: f
  } do
    start_time = ~U[2031-01-10 09:00:00Z]
    appointment = Fixtures.appointment!(f, start_time: start_time, status: "confirmed")
    other = Fixtures.appointment!(f, start_time: ~U[2031-01-11 09:00:00Z], status: "confirmed")
    catalog_before = catalog_price(f.consultation_type_id)
    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")
    assert {:ok, _} = Booking.revert_payment(principal, appointment.id, true)

    assert {:ok, history} = Booking.list_appointment_history(principal)
    assert Enum.find(history, &(&1.id == appointment.id)).status == "confirmed"

    assert DateTime.compare(Enum.find(history, &(&1.id == appointment.id)).start_time, start_time) ==
             :eq

    assert Enum.find(history, &(&1.id == other.id)).status == "confirmed"

    assert DateTime.compare(
             Enum.find(history, &(&1.id == other.id)).start_time,
             ~U[2031-01-11 09:00:00Z]
           ) == :eq

    assert {:ok, actions} = Booking.list_payment_actions(principal, appointment.id)
    assert DateTime.to_date(List.last(actions).occurred_at) != DateTime.to_date(start_time)
    assert {:ok, other_payment} = Booking.get_payment(principal, other.id)
    assert other_payment.payment_status == "pending"
    assert snapshot(appointment.id) == [[Decimal.new("100.00"), Decimal.new("100.00")]]
    assert catalog_price(f.consultation_type_id) == catalog_before
  end

  test "patient and administrator cannot reverse and rejection is invariant", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(9), status: "confirmed")
    professional = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(professional, appointment.id, "cash")
    before = rejection_state(professional, appointment.id)

    for principal <- [Fixtures.patient_principal(f), Fixtures.admin_principal(f)] do
      assert {:error, :unauthorized} = Booking.revert_payment(principal, appointment.id, true)
      assert rejection_state(professional, appointment.id) == before
    end
  end

  test "server rejects client attributes without writing a reason", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(10), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")
    before = rejection_state(principal, appointment.id)

    assert {:error, :invalid_payment_options} =
             Booking.revert_payment(principal, appointment.id, true, reason: "forged")

    assert rejection_state(principal, appointment.id) == before
  end

  defp rejection_state(principal, appointment_id) do
    {:ok, payment} = Booking.get_payment(principal, appointment_id)
    {:ok, actions} = Booking.list_payment_actions(principal, appointment_id)
    {:ok, history} = Booking.list_appointment_history(principal)

    %{
      payment: payment,
      actions: actions,
      history: Enum.filter(history, &(&1.id == appointment_id)),
      audit: Fixtures.audit_events_for(appointment_id),
      snapshot: snapshot(appointment_id)
    }
  end

  defp catalog_price(consultation_type_id) do
    SQL.query!(
      Repo,
      "SELECT exact_price_ars FROM consultation_types WHERE id = $1",
      [Ecto.UUID.dump!(consultation_type_id)]
    ).rows
  end

  defp snapshot(appointment_id) do
    SQL.query!(
      Repo,
      "SELECT snapshot_exact_price_ars, final_price_ars FROM appointments WHERE id = $1",
      [appointment_id]
    ).rows
  end

  defp future_time(offset), do: DateTime.add(~U[2031-01-01 09:00:00Z], offset * 3600, :second)
  defp unique_offset, do: rem(System.unique_integer([:positive]), 1000) + 20
end
