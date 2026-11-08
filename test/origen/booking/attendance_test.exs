defmodule Origen.Booking.AttendanceTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @now ~U[2026-12-01 10:00:00Z]

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "professional records attended and no_show only in own agenda", %{fixture: f} do
    attended = Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:00:00Z], status: "confirmed")

    no_show =
      Fixtures.appointment!(f,
        start_time: ~U[2026-12-01 12:00:00Z],
        status: "confirmed",
        patient_profile_id: f.other_patient_id
      )

    assert {:ok, %Appointment{status: "attended"}} =
             Booking.record_attendance(Fixtures.professional_principal(f), attended.id, :attended)

    assert {:ok, %Appointment{status: "no_show"}} =
             Booking.record_attendance(Fixtures.professional_principal(f), no_show.id, :no_show)

    assert history_statuses(Fixtures.patient_principal(f), [attended.id]) == %{
             attended.id => "attended"
           }

    assert history_statuses(Fixtures.professional_principal(f), [attended.id, no_show.id]) == %{
             attended.id => "attended",
             no_show.id => "no_show"
           }

    assert Fixtures.audit_events_for(attended.id) |> Enum.map(&Enum.at(&1, 2)) == [
             "appointment_attended"
           ]

    assert Fixtures.audit_events_for(no_show.id) |> Enum.map(&Enum.at(&1, 2)) == [
             "appointment_no_show"
           ]
  end

  test "secretary records both outcomes on any agenda", %{fixture: f} do
    own_agenda =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        start_time: ~U[2026-12-01 11:00:00Z],
        status: "confirmed"
      )

    other_agenda =
      Fixtures.appointment!(f,
        professional_account_id: f.professional_id,
        start_time: ~U[2026-12-01 12:00:00Z],
        status: "confirmed",
        patient_profile_id: f.other_patient_id
      )

    assert {:ok, %{status: "attended"}} =
             Booking.record_attendance(Fixtures.secretary_principal(f), own_agenda.id, :attended)

    assert {:ok, %{status: "no_show"}} =
             Booking.record_attendance(
               Fixtures.secretary_principal(f),
               other_agenda.id,
               "no_show"
             )

    assert history_statuses(Fixtures.secretary_principal(f), [own_agenda.id, other_agenda.id]) ==
             %{
               own_agenda.id => "attended",
               other_agenda.id => "no_show"
             }
  end

  test "patient, administrator, and foreign professional are denied without mutation", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:00:00Z], status: "confirmed")

    foreign =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        patient_profile_id: f.other_patient_id,
        start_time: ~U[2026-12-01 12:00:00Z],
        status: "confirmed"
      )

    for {principal, id} <- [
          {Fixtures.patient_principal(f), appointment.id},
          {Fixtures.admin_principal(f), appointment.id},
          {Fixtures.professional_principal(f), foreign.id}
        ] do
      before = observable(id)
      audit_before = Fixtures.audit_events_for(id)
      history_before = history_statuses(Fixtures.secretary_principal(f), [id])
      occupancy_before = overlap_result(f, id)
      relationship_before = relationship_result(id)

      assert {:error, :unauthorized} = Booking.record_attendance(principal, id, :attended)

      assert observable(id) == before
      assert Fixtures.audit_events_for(id) == audit_before
      assert history_statuses(Fixtures.secretary_principal(f), [id]) == history_before
      assert overlap_result(f, id) == occupancy_before
      assert relationship_result(id) == relationship_before
    end
  end

  test "revoked and inactive internal principals are denied", %{fixture: f} do
    revoked = Fixtures.professional_principal(f)

    revoked_appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:00:00Z], status: "confirmed")

    :ok = Sessions.terminate_session(revoked.token)

    assert {:error, :unauthorized} =
             Booking.record_attendance(revoked, revoked_appointment.id, :attended)

    inactive = Fixtures.professional_principal(f)

    inactive_appointment =
      Fixtures.appointment!(f,
        start_time: ~U[2026-12-01 12:00:00Z],
        status: "confirmed",
        patient_profile_id: f.other_patient_id
      )

    Repo.query!(
      "UPDATE internal_accounts SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1",
      [
        inactive.account_id
      ]
    )

    assert {:error, :unauthorized} =
             Booking.record_attendance(inactive, inactive_appointment.id, :no_show)
  end

  test "requested, expired, cancelled, and terminal outcomes cannot change outcome", %{fixture: f} do
    cases = [
      {"requested", :invalid_status_transition},
      {"expired", :invalid_status_transition},
      {"cancelled", :invalid_status_transition},
      {"attended", :invalid_status_transition},
      {"no_show", :invalid_status_transition}
    ]

    Enum.each(Enum.with_index(cases), fn {{status, error}, index} ->
      appointment =
        Fixtures.appointment!(f,
          start_time: DateTime.add(@now, (index + 1) * 3600, :second),
          status: status,
          patient_profile_id: if(rem(index, 2) == 0, do: f.patient_id, else: f.other_patient_id)
        )

      before = observable(appointment.id)
      audit_before = Fixtures.audit_events_for(appointment.id)
      occupancy_before = overlap_result(f, appointment.id)
      relationship_before = relationship_result(appointment.id)

      assert {:error, ^error} =
               Booking.record_attendance(
                 Fixtures.professional_principal(f),
                 appointment.id,
                 :attended
               )

      assert observable(appointment.id) == before
      assert Fixtures.audit_events_for(appointment.id) == audit_before
      assert overlap_result(f, appointment.id) == occupancy_before
      assert relationship_result(appointment.id) == relationship_before
    end)
  end

  test "audit failure rolls back the attendance outcome", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:00:00Z], status: "confirmed")

    before = observable(appointment.id)
    audit_before = Fixtures.audit_events_for(appointment.id)
    relationship_before = relationship_result(appointment.id)

    assert {:error, :audit_unavailable} =
             Booking.record_attendance(
               Fixtures.professional_principal(f),
               appointment.id,
               :attended,
               fail_at: :audit_event
             )

    assert observable(appointment.id) == before
    assert Fixtures.audit_events_for(appointment.id) == audit_before
    assert relationship_result(appointment.id) == relationship_before
  end

  defp observable(id) do
    Repo.query!(
      "SELECT status, cancellation_origin, cancellation_reason FROM appointments WHERE id = $1",
      [id]
    ).rows
  end

  defp history_statuses(principal, ids) do
    {:ok, history} = Booking.list_appointment_history(principal)

    history
    |> Enum.filter(&(&1.id in ids))
    |> Map.new(&{&1.id, &1.status})
  end

  defp relationship_result(appointment_id) do
    Repo.query!(
      """
      SELECT count(*)
      FROM professional_patient_relationships r
      JOIN appointments a
        ON a.professional_account_id = r.professional_account_id
       AND a.patient_profile_id = r.patient_profile_id
      WHERE a.id = $1
      """,
      [appointment_id]
    ).rows
    |> List.flatten()
    |> hd()
  end

  defp overlap_result(f, appointment_id) do
    [start_time, end_time, patient_id, professional_id] =
      Repo.query!(
        "SELECT start_time, end_time, patient_profile_id, professional_account_id FROM appointments WHERE id = $1",
        [appointment_id]
      ).rows
      |> hd()

    Booking.check_overlaps(
      %{
        professional_id: professional_id || f.professional_id,
        patient_id: patient_id,
        start_time: start_time,
        end_time: end_time
      },
      now: @now
    )
  end
end
