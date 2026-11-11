defmodule Origen.Booking.LifecycleTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @now ~U[2026-12-01 10:00:00Z]

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "patient cancels own requested appointment before start and releases occupancy", %{
    fixture: f
  } do
    appointment = Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:00:00Z])
    principal = Fixtures.patient_principal(f)

    assert {:ok, cancelled} = Booking.cancel_appointment(principal, appointment.id, now: @now)
    assert cancelled.status == "cancelled"
    assert Repo.get!(Appointment, appointment.id).status == "cancelled"
    assert {:ok, :no_conflict} = free_slot(f, appointment.start_time, f.other_patient_id)
    assert Fixtures.audit_events_for(appointment.id) |> length() == 1
  end

  test "patient cancels own confirmed appointment before start without requiring reason", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:30:00Z], status: "confirmed")

    assert {:ok, %{status: "cancelled", cancellation_origin: "patient", cancellation_reason: nil}} =
             Booking.cancel_appointment(Fixtures.patient_principal(f), appointment.id, now: @now)
  end

  test "patient boundary and foreign appointment are rejected without mutation", %{fixture: f} do
    at_start = Fixtures.appointment!(f, start_time: @now, status: "confirmed")

    after_start =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 09:00:00Z], status: "confirmed")

    other =
      Fixtures.appointment!(f,
        start_time: ~U[2026-12-01 12:00:00Z],
        patient_profile_id: f.other_patient_id
      )

    before = observable(other.id)
    audit_count = audit_count(other.id)

    assert {:error, :patient_cancellation_not_allowed} =
             Booking.cancel_appointment(Fixtures.patient_principal(f), at_start.id, now: @now)

    assert {:error, :patient_cancellation_not_allowed} =
             Booking.cancel_appointment(Fixtures.patient_principal(f), after_start.id, now: @now)

    assert {:error, :unauthorized} =
             Booking.cancel_appointment(Fixtures.patient_principal(f), other.id, now: @now)

    assert observable(other.id) == before
    assert audit_count(other.id) == audit_count
  end

  test "map now controls cannot bypass the patient cutoff", %{fixture: f} do
    for {key, index} <- Enum.with_index([:now, "now"]) do
      past_start = DateTime.add(DateTime.utc_now(), -3600 * (index + 1), :second)
      appointment = Fixtures.appointment!(f, start_time: past_start, status: "confirmed")
      attrs = Map.put(%{}, key, DateTime.add(past_start, -3600, :second))

      assert {:error, :patient_cancellation_not_allowed} =
               Booking.cancel_appointment(Fixtures.patient_principal(f), appointment.id, attrs)

      assert Repo.get!(Appointment, appointment.id).status == "confirmed"
    end
  end

  test "map fail_at cannot suppress a successful staff cancellation", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f,
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "confirmed"
      )

    assert {:ok, cancelled} =
             Booking.cancel_appointment(Fixtures.professional_principal(f), appointment.id, %{
               "reason" => "Guardia reprogramada",
               "fail_at" => :audit_event
             })

    assert cancelled.status == "cancelled"
    assert length(Fixtures.audit_events_for(appointment.id)) == 1
  end

  test "atom-key keyword infrastructure clock remains deterministic", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 11:00:00Z], status: "confirmed")

    assert {:ok, %{status: "cancelled"}} =
             Booking.cancel_appointment(Fixtures.patient_principal(f), appointment.id, now: @now)
  end

  test "professional cancels own agenda with visible origin and reason at or after start", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 09:00:00Z], status: "confirmed")

    assert {:ok, result} =
             Booking.cancel_appointment(Fixtures.professional_principal(f), appointment.id,
               reason: "Guardia reprogramada",
               now: @now
             )

    assert result.cancellation_origin == "professional"
    assert result.cancellation_reason == "Guardia reprogramada"
    assert {:ok, [history]} = Booking.list_appointment_history(Fixtures.patient_principal(f))
    assert history.cancellation_reason == "Guardia reprogramada"
    assert history.cancellation_origin == "professional"
  end

  test "secretary cancels any agenda and administrator has no implicit access", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 12:30:00Z], status: "confirmed")

    assert {:ok, result} =
             Booking.cancel_appointment(Fixtures.secretary_principal(f), appointment.id,
               reason: "Cierre operativo",
               now: @now
             )

    assert result.cancellation_origin == "secretary"

    assert {:error, :unauthorized} =
             Booking.list_appointment_history(Fixtures.admin_principal(f))
  end

  test "staff reason is mandatory and rejection preserves state, history, occupancy and audit", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-01 12:00:00Z], status: "confirmed")

    before = observable(appointment.id)
    audit_count = audit_count(appointment.id)

    for reason <- [nil, "", "   "] do
      assert {:error, :cancellation_reason_required} =
               Booking.cancel_appointment(Fixtures.professional_principal(f), appointment.id,
                 reason: reason,
                 now: @now
               )
    end

    assert observable(appointment.id) == before
    assert audit_count(appointment.id) == audit_count

    assert {:error, :professional_schedule_conflict} =
             Booking.check_overlaps(
               %{
                 professional_id: f.professional_id,
                 patient_id: f.other_patient_id,
                 start_time: appointment.start_time,
                 end_time: appointment.end_time
               },
               now: @now
             )
  end

  test "professional cannot cancel another agenda even when patient is shared", %{fixture: f} do
    appointment =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        patient_profile_id: f.patient_id,
        start_time: ~U[2026-12-01 13:00:00Z],
        status: "confirmed"
      )

    assert {:error, :unauthorized} =
             Booking.cancel_appointment(Fixtures.professional_principal(f), appointment.id,
               reason: "No",
               now: @now
             )
  end

  defp free_slot(f, start_time, patient_id) do
    Booking.check_overlaps(
      %{
        professional_id: f.professional_id,
        patient_id: patient_id,
        start_time: start_time,
        end_time: DateTime.add(start_time, 30, :minute)
      },
      now: @now
    )
  end

  defp observable(id) do
    Repo.query!(
      "SELECT status, cancellation_origin, cancellation_reason FROM appointments WHERE id = $1",
      [id]
    ).rows
  end

  defp audit_count(id) do
    Repo.query!("SELECT count(*) FROM audit_events WHERE entity_ref = $1", ["appointment:#{id}"]).rows
    |> List.flatten()
    |> hd()
  end
end
