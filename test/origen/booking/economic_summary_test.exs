defmodule Origen.Booking.EconomicSummaryTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Booking
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @month %{"mode" => "month", "month" => "2026-11"}
  @range %{"mode" => "range", "from" => "2026-11-01", "to" => "2026-11-30"}

  setup do
    previous_timezone = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "Etc/UTC")

    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous_timezone) end)
    %{fixture: Fixtures.create!()}
  end

  test "returns exact paid, pending and total amounts for eligible current marks", %{fixture: f} do
    professional = Fixtures.professional_principal(f)

    paid_confirmed = appointment!(f, ~D[2026-11-05], 9, "confirmed", "10000")
    paid_cancelled = appointment!(f, ~D[2026-11-06], 9, "confirmed", "8000")
    paid_no_show = appointment!(f, ~D[2026-11-07], 9, "confirmed", "7000")
    _pending_confirmed = appointment!(f, ~D[2026-11-08], 9, "confirmed", "6000")
    pending_attended = appointment!(f, ~D[2026-11-09], 9, "confirmed", "4000")

    assert {:ok, _} = Booking.record_payment(professional, paid_confirmed.id, :cash)
    assert {:ok, _} = Booking.record_payment(professional, paid_cancelled.id, :cash)

    assert {:ok, _} =
             Booking.cancel_appointment(professional, paid_cancelled.id, reason: "Cambio")

    assert {:ok, _} = Booking.record_payment(professional, paid_no_show.id, :transfer)
    assert {:ok, _} = Booking.record_attendance(professional, paid_no_show.id, :no_show)
    assert {:ok, _} = Booking.record_attendance(professional, pending_attended.id, :attended)

    assert {:ok, summary} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(summary.paid, Decimal.new("25000"))
    assert Decimal.equal?(summary.pending, Decimal.new("10000"))
    assert Decimal.equal?(summary.total, Decimal.new("35000"))
    assert summary.professional == %{id: f.professional_id}
    assert summary.period.from == ~D[2026-11-01]
    assert summary.period.to == ~D[2026-11-30]
  end

  test "excludes every unpaid operational state outside confirmed and attended", %{fixture: f} do
    professional = Fixtures.professional_principal(f)

    for {date, status} <- [
          {~D[2026-11-10], "cancelled"},
          {~D[2026-11-11], "requested"},
          {~D[2026-11-12], "expired"},
          {~D[2026-11-15], "reserved"},
          {~D[2026-11-13], "no_show"}
        ] do
      appointment!(f, date, 9, status, "9000")
    end

    rejected = appointment!(f, ~D[2026-11-14], 9, "requested", "9000")
    assert {:ok, %{status: "cancelled"}} = Booking.reject_request(f.professional_id, rejected.id)

    assert {:ok, summary} = Booking.economic_summary(professional, f.professional_id, @range)
    assert zero_summary?(summary)
  end

  test "month and equivalent range use the same database bounds, including adjacent exclusions",
       %{
         fixture: f
       } do
    professional = Fixtures.professional_principal(f)
    appointment!(f, ~D[2026-10-31], 23, "confirmed", "1000")
    appointment!(f, ~D[2026-11-01], 0, "confirmed", "2000")
    appointment!(f, ~D[2026-11-30], 23, "confirmed", "3000")
    appointment!(f, ~D[2026-12-01], 0, "confirmed", "4000")

    assert {:ok, month} = Booking.economic_summary(professional, f.professional_id, @month)
    assert {:ok, range} = Booking.economic_summary(professional, f.professional_id, @range)

    assert Map.take(month, [:paid, :pending, :total, :professional]) ==
             Map.take(range, [:paid, :pending, :total, :professional])

    assert Decimal.equal?(month.pending, Decimal.new("5000"))
  end

  test "appointments are assigned to the local organization date, not the UTC date", %{
    fixture: f
  } do
    Application.put_env(:origen, :organization_timezone, "America/Argentina/Buenos_Aires")
    professional = Fixtures.professional_principal(f)

    # 2026-11-01 02:00 UTC is 2026-10-31 23:00 in Buenos Aires.
    appointment_at!(f, ~U[2026-11-01 02:00:00Z], "1000")
    # 2026-11-01 03:00 UTC is the first local minute of November.
    appointment_at!(f, ~U[2026-11-01 03:00:00Z], "2000")
    # 2026-12-01 00:30 UTC is 2026-11-30 21:30 in Buenos Aires.
    appointment_at!(f, ~U[2026-12-01 00:30:00Z], "4000")
    # 2026-12-01 03:00 UTC is the first local minute of December.
    appointment_at!(f, ~U[2026-12-01 03:00:00Z], "8000")

    assert {:ok, november} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(november.pending, Decimal.new("6000"))

    assert {:ok, last_day} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "range",
               "from" => "2026-11-30",
               "to" => "2026-11-30"
             })

    assert Decimal.equal?(last_day.pending, Decimal.new("4000"))

    assert {:ok, december} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "month",
               "month" => "2026-12"
             })

    assert Decimal.equal?(december.pending, Decimal.new("8000"))
  end

  test "equal range endpoints include the complete local day and reversed ranges do not query", %{
    fixture: f
  } do
    professional = Fixtures.professional_principal(f)
    appointment!(f, ~D[2026-11-15], 0, "confirmed", "1000")
    appointment!(f, ~D[2026-11-15], 23, "confirmed", "2000")
    appointment!(f, ~D[2026-11-14], 23, "confirmed", "4000")
    appointment!(f, ~D[2026-11-16], 0, "confirmed", "8000")

    assert {:ok, summary} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "range",
               "from" => "2026-11-15",
               "to" => "2026-11-15"
             })

    assert Decimal.equal?(summary.pending, Decimal.new("3000"))

    assert {:error, :range_reversed} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "range",
               "from" => "2026-11-20",
               "to" => "2026-11-19"
             })
  end

  test "a late payment changes the appointment date period, not the collection period", %{
    fixture: f
  } do
    professional = Fixtures.professional_principal(f)
    appointment = appointment!(f, ~D[2026-11-20], 9, "confirmed", "6000")

    assert {:ok, before} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(before.pending, Decimal.new("6000"))

    assert {:ok, _} = Booking.record_payment(professional, appointment.id, :cash)
    assert {:ok, november} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(november.paid, Decimal.new("6000"))
    assert Decimal.equal?(november.pending, Decimal.new("0"))

    assert {:ok, december} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "month",
               "month" => "2026-12"
             })

    assert zero_summary?(december)
  end

  test "reverting an eligible paid mark moves it to pending and ignores reverted history", %{
    fixture: f
  } do
    professional = Fixtures.professional_principal(f)
    appointment = appointment!(f, ~D[2026-11-21], 9, "confirmed", "6000")

    assert {:ok, _} = Booking.record_payment(professional, appointment.id, :cash)
    assert {:ok, paid} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(paid.paid, Decimal.new("6000"))

    assert {:ok, _} = Booking.revert_payment(professional, appointment.id, true)
    assert {:ok, pending} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(pending.paid, Decimal.new("0"))
    assert Decimal.equal?(pending.pending, Decimal.new("6000"))
    assert Decimal.equal?(pending.total, Decimal.new("6000"))
    assert {:ok, actions} = Booking.list_payment_actions(professional, appointment.id)
    assert Enum.map(actions, & &1.action) == ["paid", "reverted"]
  end

  test "reverting paid cancelled and no-show appointments removes paid without pending", %{
    fixture: f
  } do
    professional = Fixtures.professional_principal(f)

    for {date, transition} <- [
          {~D[2026-11-22], :cancelled},
          {~D[2026-11-23], :no_show}
        ] do
      appointment = appointment!(f, date, 9, "confirmed", "6000")
      assert {:ok, _} = Booking.record_payment(professional, appointment.id, :cash)

      if transition == :cancelled do
        assert {:ok, _} =
                 Booking.cancel_appointment(professional, appointment.id, reason: "Cambio")
      else
        assert {:ok, _} = Booking.record_attendance(professional, appointment.id, :no_show)
      end

      assert {:ok, paid} = Booking.economic_summary(professional, f.professional_id, @month)
      assert Decimal.equal?(paid.paid, Decimal.new("6000"))

      assert {:ok, _} = Booking.revert_payment(professional, appointment.id, true)
      assert {:ok, corrected} = Booking.economic_summary(professional, f.professional_id, @month)
      assert Decimal.equal?(corrected.paid, Decimal.new("0"))
      assert Decimal.equal?(corrected.pending, Decimal.new("0"))
    end
  end

  test "uses editable final price rather than catalog or immutable snapshot and includes zero", %{
    fixture: f
  } do
    professional = Fixtures.professional_principal(f)
    appointment = appointment!(f, ~D[2026-11-24], 9, "confirmed", "6000")

    SQL.query!(Repo, "UPDATE consultation_types SET exact_price_ars = 99999 WHERE id = $1", [
      Ecto.UUID.dump!(f.consultation_type_id)
    ])

    assert {:ok, %{final_price_ars: price}} =
             Booking.update_final_price(professional, appointment.id, "5000")

    assert Decimal.equal?(price, Decimal.new("5000"))
    assert {:ok, summary} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(summary.pending, Decimal.new("5000"))

    zero = appointment!(f, ~D[2026-11-25], 9, "confirmed", "0")
    assert {:ok, zero_summary} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(zero_summary.pending, Decimal.new("5000"))
    assert {:ok, _} = Booking.record_payment(professional, zero.id, :cash)
    assert {:ok, final} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(final.paid, Decimal.new("0"))
    assert Decimal.equal?(final.pending, Decimal.new("5000"))
    assert Decimal.equal?(final.total, Decimal.new("5000"))
  end

  test "empty periods return zero values without presenting a debt", %{fixture: f} do
    professional = Fixtures.professional_principal(f)

    assert {:ok, summary} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "month",
               "month" => "2026-12"
             })

    assert zero_summary?(summary)
    refute Map.has_key?(summary, :debt)
    refute Map.has_key?(summary, :balance)
    refute Map.has_key?(summary, :net_income)
    refute Map.has_key?(summary, :cash)
  end

  test "professional is restricted to own summary and secretary selects one existing professional",
       %{
         fixture: f
       } do
    professional = Fixtures.professional_principal(f)
    secretary = Fixtures.secretary_principal(f)
    appointment!(f, ~D[2026-11-26], 9, "confirmed", "1000")

    other =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        patient_profile_id: f.other_patient_id,
        start_time: ~U[2026-11-26 10:00:00Z],
        status: "confirmed"
      )

    assert {:ok, own} = Booking.economic_summary(professional, f.professional_id, @month)
    assert Decimal.equal?(own.pending, Decimal.new("1000"))

    assert {:error, :unauthorized} =
             Booking.economic_summary(professional, f.other_professional_id, @month)

    assert {:error, :unauthorized} =
             Booking.economic_summary(professional, 999_999, @month)

    assert {:ok, selected} = Booking.economic_summary(secretary, f.other_professional_id, @month)
    assert selected.professional == %{id: f.other_professional_id}
    assert Decimal.equal?(selected.pending, Decimal.new("100"))
    assert other.id > 0

    assert {:error, :invalid_professional_selection} =
             Booking.economic_summary(
               secretary,
               [f.professional_id, f.other_professional_id],
               @month
             )

    assert {:error, :invalid_professional_selection} =
             Booking.economic_summary(secretary, 9_223_372_036_854_775_808, @month)
  end

  test "denies invalid actors, stale sessions, inactive accounts and invalid selections without leakage",
       %{
         fixture: f
       } do
    patient = Fixtures.patient_principal(f)
    admin = Fixtures.admin_principal(f)
    professional = Fixtures.professional_principal(f)
    before = Booking.economic_summary(professional, f.professional_id, @month)

    for principal <- [nil, %{}, patient, admin] do
      assert {:error, :unauthorized} =
               Booking.economic_summary(principal, f.professional_id, @month)
    end

    forged = Map.put(professional, :account_id, f.other_professional_id)
    assert {:error, :unauthorized} = Booking.economic_summary(forged, f.professional_id, @month)

    revoked = Fixtures.professional_principal(f)
    assert :ok = Sessions.terminate_session(revoked.token)
    assert {:error, :unauthorized} = Booking.economic_summary(revoked, f.professional_id, @month)

    {:ok, %{token: inactive_token, session: inactive_session}} =
      Sessions.create_session(f.other_professional_id)

    inactive = Map.put(inactive_session, :token, inactive_token)

    SQL.query!(
      Repo,
      "UPDATE internal_accounts SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1",
      [inactive.account_id]
    )

    assert {:error, :unauthorized} = Booking.economic_summary(inactive, f.professional_id, @month)

    assert {:error, :unauthorized} =
             Booking.economic_summary(professional, 999_999, @month)

    assert {:error, :invalid_professional_selection} =
             Booking.economic_summary(professional, "1", @month)

    assert {:error, :invalid_period} =
             Booking.economic_summary(professional, f.professional_id, %{"mode" => "month"})

    assert Booking.economic_summary(professional, f.professional_id, @month) == before
  end

  test "valid and rejected summaries are read-only through public observable operations", %{
    fixture: f
  } do
    professional = Fixtures.professional_principal(f)
    appointment = appointment!(f, ~D[2026-11-27], 9, "confirmed", "6000")
    before = observable_state(professional, appointment.id)

    assert {:ok, _} = Booking.economic_summary(professional, f.professional_id, @month)
    assert observable_state(professional, appointment.id) == before

    assert {:error, :range_reversed} =
             Booking.economic_summary(professional, f.professional_id, %{
               "mode" => "range",
               "from" => "2026-11-28",
               "to" => "2026-11-27"
             })

    assert observable_state(professional, appointment.id) == before
  end

  defp appointment!(fixture, date, hour, status, price) do
    appointment_at!(fixture, DateTime.new!(date, Time.new!(hour, 0, 0), "Etc/UTC"), price, status)
  end

  defp appointment_at!(fixture, start_time, price, status \\ "confirmed") do
    appointment = Fixtures.appointment!(fixture, start_time: start_time, status: status)

    principal = Fixtures.professional_principal(fixture)

    assert {:ok, %{final_price_ars: final_price}} =
             Booking.update_final_price(principal, appointment.id, price)

    assert Decimal.equal?(final_price, Decimal.new(price))
    appointment
  end

  defp observable_state(principal, appointment_id) do
    {:ok, payment} = Booking.get_payment(principal, appointment_id)
    {:ok, actions} = Booking.list_payment_actions(principal, appointment_id)
    {:ok, history} = Booking.list_appointment_history(principal)

    %{
      payment: payment,
      actions: actions,
      appointment: Enum.find(history, &(&1.id == appointment_id))
    }
  end

  defp zero_summary?(summary) do
    Decimal.equal?(summary.paid, Decimal.new("0")) and
      Decimal.equal?(summary.pending, Decimal.new("0")) and
      Decimal.equal?(summary.total, Decimal.new("0"))
  end
end
