defmodule Origen.Booking.PaymentRegistrationTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "professional and secretary register one total payment for confirmed and attended appointments",
       %{fixture: f} do
    for {actor, scope} <- [
          {:professional, Fixtures.professional_principal(f)},
          {:secretary, Fixtures.secretary_principal(f)}
        ],
        status <- [:confirmed, :attended],
        method <- ["cash", "transfer"] do
      appointment = appointment_for_status!(f, status, unique_offset())

      principal = if actor == :professional, do: scope, else: scope
      assert {:ok, projection} = Booking.record_payment(principal, appointment.id, method)
      assert projection.payment_status == "paid"
      assert projection.payment_method == method
      assert Decimal.equal?(projection.paid_amount_ars, Decimal.new("100.00"))
      assert projection.paid_actor_kind == Atom.to_string(actor)
      assert is_binary(projection.paid_actor_ref)
      assert %DateTime{} = projection.paid_at

      assert {:ok, [action]} = Booking.list_payment_actions(principal, appointment.id)
      assert action.action == "paid"
      assert action.method == method
      assert Decimal.equal?(action.amount_ars, Decimal.new("100.00"))
      assert action.actor_kind == Atom.to_string(actor)
      assert %DateTime{} = action.occurred_at

      assert {:ok, history} = Booking.list_appointment_history(principal)
      assert Enum.find(history, &(&1.id == appointment.id)).status == Atom.to_string(status)
    end
  end

  test "zero final price is a complete paid registration", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(1), status: "confirmed")
    principal = Fixtures.professional_principal(f)

    assert {:ok, %{final_price_ars: zero}} =
             Booking.update_final_price(principal, appointment.id, "0")

    assert Decimal.equal?(zero, Decimal.new("0"))

    assert {:ok, projection} = Booking.record_payment(principal, appointment.id, :transfer)
    assert projection.payment_status == "paid"
    assert Decimal.equal?(projection.final_price_ars, Decimal.new("0"))
    assert Decimal.equal?(projection.paid_amount_ars, Decimal.new("0"))
  end

  test "method, amount, actor and time are server-controlled", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(2), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    before = financial_state(principal, appointment.id)

    for options <- [
          [amount: Decimal.new("1")],
          [actor: "forged"],
          [paid_at: ~U[2000-01-01 00:00:00Z]]
        ] do
      assert {:error, :invalid_payment_options} =
               Booking.record_payment(principal, appointment.id, "cash", options)

      assert financial_state(principal, appointment.id) == before
    end

    assert {:error, :invalid_payment_method} =
             Booking.record_payment(principal, appointment.id, "check")

    assert financial_state(principal, appointment.id) == before
  end

  test "requested, reserved, expired, cancelled and no-show appointments reject without mutation",
       %{
         fixture: f
       } do
    for status <- [:requested, :reserved, :expired, :cancelled, :no_show] do
      appointment = appointment_for_status!(f, status, unique_offset())
      principal = Fixtures.professional_principal(f)
      before = rejection_state(principal, appointment.id)

      assert {:error, :payment_not_eligible} =
               Booking.record_payment(principal, appointment.id, "cash")

      assert rejection_state(principal, appointment.id) == before
    end
  end

  test "a second registration rejects without overwriting payment, action, audit, history or snapshot",
       %{
         fixture: f
       } do
    appointment = Fixtures.appointment!(f, start_time: future_time(3), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")

    before = rejection_state(principal, appointment.id)

    assert {:error, :payment_already_paid} =
             Booking.record_payment(principal, appointment.id, "transfer")

    assert rejection_state(principal, appointment.id) == before
  end

  test "price editing is rejected after registration", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(4), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(principal, appointment.id, "cash")

    assert {:error, :payment_already_paid} =
             Booking.update_final_price(principal, appointment.id, "80.00")

    assert {:ok, projection} = Booking.get_payment(principal, appointment.id)
    assert Decimal.equal?(projection.final_price_ars, Decimal.new("100.00"))
  end

  test "patient and administrator never receive internal payment action fields", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(5), status: "confirmed")
    professional = Fixtures.professional_principal(f)
    assert {:ok, _} = Booking.record_payment(professional, appointment.id, "cash")

    assert {:error, :unauthorized} =
             Booking.list_payment_actions(Fixtures.patient_principal(f), appointment.id)

    assert {:error, :unauthorized} =
             Booking.list_payment_actions(Fixtures.admin_principal(f), appointment.id)

    assert {:ok, patient_projection} =
             Booking.get_payment(Fixtures.patient_principal(f), appointment.id)

    refute Map.has_key?(patient_projection, :payment_method)
    refute Map.has_key?(patient_projection, :paid_actor_ref)
    refute Map.has_key?(patient_projection, :paid_at)
  end

  test "foreign, nonexistent, forged, inactive and revoked principals fail closed without leakage",
       %{
         fixture: f
       } do
    appointment = Fixtures.appointment!(f, start_time: future_time(6), status: "confirmed")

    foreign =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        start_time: future_time(7),
        status: "confirmed"
      )

    own_principal = Fixtures.professional_principal(f)

    foreign_errors = [
      Booking.record_payment(own_principal, foreign.id, "cash"),
      Booking.record_payment(own_principal, 9_999_999, "cash")
    ]

    assert Enum.all?(foreign_errors, &(&1 == {:error, :unauthorized}))

    forged = Map.put(own_principal, :account_id, f.other_professional_id)
    assert {:error, :unauthorized} = Booking.record_payment(forged, appointment.id, "cash")

    assert {:error, :unauthorized} =
             Booking.record_payment(Fixtures.patient_principal(f), appointment.id, "cash")

    assert {:error, :unauthorized} =
             Booking.record_payment(Fixtures.admin_principal(f), appointment.id, "cash")

    revoked = Fixtures.professional_principal(f)
    :ok = Sessions.terminate_session(revoked.token)
    assert {:error, :unauthorized} = Booking.record_payment(revoked, appointment.id, "cash")

    inactive = Fixtures.professional_principal(f)

    SQL.query!(
      Repo,
      "UPDATE internal_accounts SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1",
      [inactive.account_id]
    )

    assert {:error, :unauthorized} = Booking.record_payment(inactive, appointment.id, "cash")

    assert financial_state(Fixtures.secretary_principal(f), appointment.id).payment.payment_status ==
             "pending"
  end

  test "payment, immutable action and audit are atomic", %{fixture: f} do
    appointment = Fixtures.appointment!(f, start_time: future_time(8), status: "confirmed")
    principal = Fixtures.professional_principal(f)
    before = rejection_state(principal, appointment.id)

    assert {:error, :audit_unavailable} =
             Booking.record_payment(principal, appointment.id, "cash", fail_at: :audit_event)

    assert rejection_state(principal, appointment.id) == before
  end

  defp appointment_for_status!(fixture, :attended, offset) do
    appointment =
      Fixtures.appointment!(fixture, start_time: future_time(offset), status: "confirmed")

    assert {:ok, %Appointment{status: "attended"}} =
             Booking.record_attendance(
               Fixtures.professional_principal(fixture),
               appointment.id,
               :attended
             )

    appointment
  end

  defp appointment_for_status!(fixture, :no_show, offset) do
    appointment =
      Fixtures.appointment!(fixture, start_time: future_time(offset), status: "confirmed")

    assert {:ok, %Appointment{status: "no_show"}} =
             Booking.record_attendance(
               Fixtures.professional_principal(fixture),
               appointment.id,
               :no_show
             )

    appointment
  end

  defp appointment_for_status!(fixture, :cancelled, offset) do
    appointment =
      Fixtures.appointment!(fixture, start_time: future_time(offset), status: "confirmed")

    assert {:ok, %Appointment{status: "cancelled"}} =
             Booking.cancel_appointment(
               Fixtures.professional_principal(fixture),
               appointment.id,
               reason: "Prueba de estado"
             )

    appointment
  end

  defp appointment_for_status!(fixture, status, offset) do
    Fixtures.appointment!(fixture,
      start_time: future_time(offset),
      status: Atom.to_string(status)
    )
  end

  defp financial_state(principal, appointment_id) do
    {:ok, payment} = Booking.get_payment(principal, appointment_id)
    {:ok, actions} = Booking.list_payment_actions(principal, appointment_id)
    {:ok, history} = Booking.list_appointment_history(principal)

    %{
      payment: payment,
      actions: actions,
      history: Enum.filter(history, &(&1.id == appointment_id))
    }
  end

  defp rejection_state(principal, appointment_id) do
    %{
      financial: financial_state(principal, appointment_id),
      audit: Fixtures.audit_events_for(appointment_id),
      snapshot: snapshot(appointment_id)
    }
  end

  defp snapshot(appointment_id) do
    SQL.query!(
      Repo,
      "SELECT snapshot_exact_price_ars, final_price_ars, status FROM appointments WHERE id = $1",
      [appointment_id]
    ).rows
  end

  defp future_time(offset), do: DateTime.add(~U[2030-01-01 09:00:00Z], offset * 3600, :second)
  defp unique_offset, do: rem(System.unique_integer([:positive]), 1000)
end
