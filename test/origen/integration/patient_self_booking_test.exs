defmodule Origen.Integration.PatientSelfBookingTest do
  use Origen.DataCase, async: false

  alias Origen.{Availability, Booking, ConsultationTypes, Patients, Repo, Sessions}
  alias Origen.Appointments.{BookingService, Calendar, DatabaseCalendar}

  setup do
    previous = Application.get_env(:origen, :appointments_calendar_adapter)
    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)

    on_exit(fn -> Application.put_env(:origen, :appointments_calendar_adapter, previous) end)

    suffix = System.unique_integer([:positive])
    professional_id = insert_professional!(suffix)
    {:ok, %{session: principal}} = Sessions.create_session(professional_id)

    assert {:ok, _} =
             Origen.ProfessionalProfiles.save_own_profile(principal, %{
               first_name: "Laura",
               last_name: "Gómez",
               specialty: "Cardiología",
               license_type: "Libre",
               license_number: "MN-#{suffix}"
             })

    assert {:ok, _} =
             Availability.replace_own_configuration(principal, %{
               weekly_availability: weekday_availability(),
               booking_horizon_days: 30,
               minimum_lead_minutes: 0
             })

    assert {:ok, type} =
             ConsultationTypes.create_type(principal, %{
               name: "Consulta de integración",
               exact_price_ars: "22000.00",
               color: "#0A3847",
               interval_count: 1
             })

    %{
      professional_id: professional_id,
      principal: principal,
      consultation_type_id: type.id,
      suffix: suffix
    }
  end

  test "same-day booking does not require phone verification and uses the real calendar", ctx do
    date = Date.utc_today()
    now = DateTime.new!(date, ~T[08:00:00], "Etc/UTC")
    profile = complete_patient!("same-day-#{ctx.suffix}@example.test", "410#{ctx.suffix}")

    assert profile.phone_verified == false

    params = reservation(ctx, profile, date, ~T[10:00:00], now)
    assert {:ok, result} = BookingService.reserve(profile, params)
    assert result.status == "confirmed"

    assert {:ok, schedule} =
             Calendar.get_daily_schedule(to_string(ctx.professional_id), date,
               duration_minutes: 30,
               now: now
             )

    refute Enum.any?(schedule.slots, &(&1.start_formatted == "10:00"))

    assert {:ok, agenda} = Booking.get_professional_agenda(ctx.principal, %{date: date})
    assert [%{status: "confirmed", patient: %{id: patient_id}}] = agenda.appointments
    assert patient_id == profile.id
    assert {:ok, patients} = Booking.list_professional_patients(ctx.principal)
    assert Enum.any?(patients, &(&1.id == profile.id))
  end

  test "incomplete patient identity is denied without appointment or relationship effects", ctx do
    date = Date.add(Date.utc_today(), 3)
    now = DateTime.new!(Date.utc_today(), ~T[08:00:00], "Etc/UTC")
    email = "incomplete-#{ctx.suffix}@example.test"
    assert {:ok, profile} = Patients.get_or_create_profile(email)
    refute Patients.ready_for_booking?(profile)

    assert {:error, :patient_not_ready_for_booking} =
             BookingService.reserve(profile, reservation(ctx, profile, date, ~T[10:00:00], now))

    assert public_agenda!(ctx, date).appointments == []
    assert {:ok, related} = Booking.list_professional_patients(ctx.principal)
    assert related == []
  end

  test "occupied slots and forged patient ids leave no third-party effects", ctx do
    date = Date.add(Date.utc_today(), 5)
    now = DateTime.new!(Date.utc_today(), ~T[08:00:00], "Etc/UTC")
    first = complete_patient!("first-#{ctx.suffix}@example.test", "412#{ctx.suffix}")
    second = complete_patient!("second-#{ctx.suffix}@example.test", "413#{ctx.suffix}")

    assert {:ok, _first_result} =
             BookingService.reserve(first, reservation(ctx, first, date, ~T[11:00:00], now))

    agenda_before = public_agenda!(ctx, date)
    assert length(agenda_before.appointments) == 1

    assert {:error, :overlap_detected} =
             BookingService.reserve(second, reservation(ctx, second, date, ~T[11:00:00], now))

    assert public_agenda!(ctx, date) == agenda_before
    assert {:ok, related} = Booking.list_professional_patients(ctx.principal)
    assert Enum.any?(related, &(&1.id == first.id))
    refute Enum.any?(related, &(&1.id == second.id))

    forged =
      reservation(ctx, first, date, ~T[12:00:00], now)
      |> Map.put(:patient_profile_id, second.id)
      |> Map.put("patient_profile_id", second.id)

    assert {:ok, before_schedule} =
             Calendar.get_daily_schedule(to_string(ctx.professional_id), date,
               duration_minutes: 30,
               now: now
             )

    assert Enum.any?(before_schedule.slots, &(&1.start_formatted == "12:00"))
    assert {:error, :rollback} = BookingService.reserve(first, forged)
    assert public_agenda!(ctx, date) == agenda_before

    assert {:ok, related_after} = Booking.list_professional_patients(ctx.principal)
    assert Enum.count(related_after, &(&1.id == first.id)) == 1
    refute Enum.any?(related_after, &(&1.id == second.id))

    assert {:ok, after_schedule} =
             Calendar.get_daily_schedule(to_string(ctx.professional_id), date,
               duration_minutes: 30,
               now: now
             )

    assert Enum.any?(after_schedule.slots, &(&1.start_formatted == "12:00"))
  end

  defp reservation(ctx, _profile, date, start_time, now) do
    %{
      professional_id: ctx.professional_id,
      consultation_type_id: ctx.consultation_type_id,
      date: date,
      slot: %{
        start_time: start_time,
        start_formatted: Elixir.Calendar.strftime(start_time, "%H:%M")
      },
      now: now
    }
  end

  defp public_agenda!(ctx, date) do
    assert {:ok, agenda} = Booking.get_professional_agenda(ctx.principal, %{date: date})
    agenda
  end

  defp complete_patient!(email, document_number) do
    {:ok, %{profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: "Paciente",
        last_name: "Integración",
        document_type: "dni",
        document_number: document_number,
        birthdate: ~D[1991-01-01],
        phone: "+5491112345678"
      })

    profile
  end

  defp insert_professional!(suffix) do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ('professional', 'active', $1, 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        ["self-booking-professional-#{suffix}@example.test"]
      )

    id
  end

  defp weekday_availability do
    Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
      {day, [%{"start" => "08:00", "end" => "18:00"}]}
    end)
  end
end
