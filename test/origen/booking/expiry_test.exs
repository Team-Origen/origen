defmodule Origen.Booking.ExpiryTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Appointments.DatabaseCalendar
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Booking.RequestResolution
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @now ~U[2026-12-01 10:00:00Z]

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "expires due requests, preserves history, and releases both occupancies", %{
    fixture: fixture
  } do
    due = Fixtures.appointment!(fixture, start_time: @now, status: "requested")

    _future =
      Fixtures.appointment!(fixture, start_time: ~U[2026-12-01 11:00:00Z], status: "requested")

    confirmed =
      Fixtures.appointment!(fixture, start_time: ~U[2026-12-01 09:00:00Z], status: "confirmed")

    assert {:ok, %{expired_count: 1, appointment_ids: [id]}} =
             Booking.expire_due_requested(now: @now)

    assert id == due.id
    assert Repo.get!(Appointment, due.id).status == "expired"
    assert Repo.get!(Appointment, confirmed.id).status == "confirmed"

    assert {:ok, :no_conflict} =
             Booking.check_overlaps(
               %{
                 professional_id: fixture.professional_id,
                 patient_id: fixture.other_patient_id,
                 start_time: @now,
                 end_time: DateTime.add(@now, 30, :minute)
               },
               now: @now
             )

    assert {:ok, :no_conflict} =
             Booking.check_overlaps(
               %{
                 professional_id: fixture.other_professional_id,
                 patient_id: fixture.patient_id,
                 start_time: @now,
                 end_time: DateTime.add(@now, 30, :minute)
               },
               now: @now
             )

    assert [
             [
               "system",
               "system:appointment_expiry",
               "appointment_expired",
               "appointment",
               entity_ref,
               "succeeded"
             ]
           ] = Fixtures.audit_events_for(due.id)

    assert entity_ref == "appointment:#{due.id}"
  end

  test "expires only requests at or after their start boundary", %{fixture: fixture} do
    before =
      Fixtures.appointment!(fixture,
        start_time: ~U[2026-12-01 10:01:00Z],
        status: "requested"
      )

    at_start =
      Fixtures.appointment!(fixture,
        professional_account_id: fixture.other_professional_id,
        patient_profile_id: fixture.other_patient_id,
        start_time: @now,
        status: "requested"
      )

    after_start =
      Fixtures.appointment!(fixture,
        professional_account_id: fixture.professional_id,
        patient_profile_id: fixture.other_patient_id,
        start_time: ~U[2026-12-01 09:00:00Z],
        status: "requested"
      )

    assert {:ok, %{expired_count: 2}} = Booking.expire_due_requested(now: @now)
    assert Repo.get!(Appointment, before.id).status == "requested"
    assert Repo.get!(Appointment, at_start.id).status == "expired"
    assert Repo.get!(Appointment, after_start.id).status == "expired"
  end

  test "expiry is idempotent and does not touch confirmed appointments", %{fixture: fixture} do
    due = Fixtures.appointment!(fixture, start_time: @now, status: "requested")

    confirmed =
      Fixtures.appointment!(fixture, start_time: ~U[2026-12-01 08:00:00Z], status: "confirmed")

    assert {:ok, %{expired_count: 1}} = Booking.expire_due_requested(now: @now)

    assert {:ok, %{expired_count: 0, appointment_ids: []}} =
             Booking.expire_due_requested(now: @now)

    assert Repo.get!(Appointment, due.id).status == "expired"
    assert Repo.get!(Appointment, confirmed.id).status == "confirmed"
    assert length(Fixtures.audit_events_for(due.id)) == 1
    assert Fixtures.audit_events_for(confirmed.id) == []
  end

  test "a due request cannot be confirmed before an explicit sweep", %{fixture: fixture} do
    appointment = Fixtures.appointment!(fixture, start_time: @now, status: "requested")

    assert {:error, :appointment_expired} =
             RequestResolution.accept_request(fixture.professional_id, appointment.id, now: @now)

    assert Repo.get!(Appointment, appointment.id).status == "expired"
    assert Fixtures.audit_events_for(appointment.id) != []
  end

  test "database calendar queries sweep due requests before calculating availability", %{
    fixture: fixture
  } do
    SQL.query!(
      Repo,
      """
      INSERT INTO public.agenda_settings
        (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days,
         minimum_lead_minutes, created_at, updated_at)
      VALUES ($1, 30, $2::jsonb, 30, 0, clock_timestamp(), clock_timestamp())
      """,
      [fixture.professional_id, ~s({"tuesday":[{"start":"10:00","end":"11:00"}]})]
    )

    _appointment = Fixtures.appointment!(fixture, start_time: @now, status: "requested")

    assert {:ok, schedule} =
             DatabaseCalendar.get_daily_schedule(fixture.professional_id, ~D[2026-12-01],
               now: @now,
               duration_minutes: 30
             )

    assert Enum.map(schedule.slots, & &1.start_formatted) == ["10:00", "10:30"]
  end

  test "overlap queries sweep due requests before checking availability", %{fixture: fixture} do
    appointment = Fixtures.appointment!(fixture, start_time: @now, status: "requested")

    assert {:ok, :no_conflict} =
             Booking.check_overlaps(
               %{
                 professional_id: fixture.professional_id,
                 patient_id: fixture.other_patient_id,
                 start_time: @now,
                 end_time: DateTime.add(@now, 30, :minute)
               },
               now: @now
             )

    assert Repo.get!(Appointment, appointment.id).status == "expired"
  end
end
