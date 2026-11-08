defmodule Origen.Appointments.DatabaseCalendarLifecycleTest do
  use Origen.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Appointments.DatabaseCalendar
  alias Origen.Booking.Appointment
  alias Origen.ProfessionalProfiles
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @now ~U[2026-12-01 10:00:00Z]

  setup do
    fixture = Fixtures.create!()

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

    {:ok, %{session: owner}} = Sessions.create_session(fixture.professional_id)

    {:ok, _profile} =
      ProfessionalProfiles.save_own_profile(owner, %{
        first_name: "Dra.",
        last_name: "Beta",
        specialty: "Medicina General",
        license_type: "Libre",
        license_number: "BETA/001"
      })

    %{fixture: fixture}
  end

  test "returns the beta cancellation policy without changing the real schedule contract", %{
    fixture: fixture
  } do
    due = Fixtures.appointment!(fixture, start_time: @now, status: "requested")

    assert {:ok, schedule} =
             DatabaseCalendar.get_daily_schedule(fixture.professional_id, ~D[2026-12-01],
               now: @now,
               duration_minutes: 30
             )

    assert Repo.get!(Appointment, due.id).status == "expired"
    assert schedule.date == ~D[2026-12-01]
    assert schedule.professional_id == to_string(fixture.professional_id)
    assert schedule.professional_name == "Dra. Beta"
    assert schedule.specialty == "Medicina General"

    assert Enum.map(schedule.slots, &{&1.start_formatted, &1.end_formatted, &1.status}) == [
             {"10:00", "10:30", :available},
             {"10:30", "11:00", :available}
           ]

    assert Map.keys(schedule.cancellation_policy) |> Enum.sort() == [
             :cutoff_description,
             :penalty_description,
             :penalty_percentage
           ]

    assert schedule.cancellation_policy.cutoff_description ==
             "Podés cancelar estrictamente antes del inicio de la cita."

    assert schedule.cancellation_policy.penalty_percentage == 0

    assert schedule.cancellation_policy.penalty_description ==
             "No se aplica penalización automática por cancelación ni inasistencia."

    refute schedule.cancellation_policy.cutoff_description =~ ~r/D-1|50%|multa|RF-16/i
    refute schedule.cancellation_policy.penalty_description =~ ~r/D-1|50%|multa|RF-16/i
  end
end
