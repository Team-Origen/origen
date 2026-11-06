defmodule Origen.Appointments.PatientSelfBookingTest do
  use Origen.DataCase

  alias Origen.Appointments.{BookingService, DatabaseCalendar}
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship}
  alias Origen.Patients
  alias Origen.Repo

  @now ~U[2026-09-25 08:00:00Z]
  @booking_date ~D[2026-09-28]
  @slot %{start_time: ~T[09:00:00]}

  setup do
    Repo.query!("DELETE FROM professional_patient_relationships")
    Repo.query!("DELETE FROM appointments")
    Repo.query!("DELETE FROM consultation_types")
    Repo.query!("DELETE FROM agenda_settings")
    Repo.query!("DELETE FROM professional_profiles")
    Repo.query!("DELETE FROM patient_profiles")
    Repo.query!("DELETE FROM personas")
    Repo.query!("DELETE FROM internal_accounts")

    professional_id = insert_professional!("self-booking-prof@example.test")
    insert_professional_profile!(professional_id)
    insert_agenda!(professional_id, "automatic")
    consultation_type_id = insert_consultation_type!(professional_id)

    {:ok, %{profile: patient}} =
      complete_patient!("self-booking-patient@example.test", "40111222")

    {:ok, %{profile: other_patient}} = complete_patient!("other-patient@example.test", "40111223")

    %{
      professional_id: professional_id,
      consultation_type_id: consultation_type_id,
      patient: patient,
      other_patient: other_patient
    }
  end

  test "books an unverified patient with server catalog snapshots and automatic confirmation",
       ctx do
    refute ctx.patient.phone_verified

    params =
      params(ctx,
        snapshot_override: %{
          name: "forged",
          duration_minutes: 5,
          exact_price_ars: Decimal.new("1")
        }
      )

    assert {:ok, result} = BookingService.reserve(ctx.patient, params)
    assert result.status == "confirmed"
    assert result.consultation_type_name == "Consulta Real"
    assert result.duration_minutes == 30
    assert Decimal.equal?(result.exact_price_ars, Decimal.new("12500.00"))

    appointment = Repo.get!(Appointment, result.appointment_id)
    assert appointment.patient_profile_id == ctx.patient.id
    assert appointment.snapshot_consultation_type_name == "Consulta Real"
    assert appointment.snapshot_duration_minutes == 30
    assert Decimal.equal?(appointment.snapshot_exact_price_ars, Decimal.new("12500.00"))
  end

  test "manual approval creates a requested appointment and relationship", ctx do
    Repo.query!(
      "UPDATE agenda_settings SET approval_mode = 'manual' WHERE owner_account_id = $1",
      [ctx.professional_id]
    )

    assert {:ok, result} = BookingService.reserve(ctx.patient, params(ctx))
    assert result.status == "requested"
    assert Repo.get!(Appointment, result.appointment_id).status == "requested"

    assert %ProfessionalPatientRelationship{first_appointment_id: appointment_id} =
             Repo.get_by(ProfessionalPatientRelationship,
               professional_account_id: ctx.professional_id,
               patient_profile_id: ctx.patient.id
             )

    assert appointment_id == result.appointment_id

    assert {:ok, schedule} =
             DatabaseCalendar.get_daily_schedule(ctx.professional_id, @booking_date,
               duration_minutes: 30,
               now: @now
             )

    refute Enum.any?(schedule.slots, &(&1.start_time == @slot.start_time))
  end

  test "rejects a slot outside the real schedule without appointment or relationship", ctx do
    before = counts()

    assert {:error, :invalid_slot_time} =
             BookingService.reserve(ctx.patient, params(ctx, slot: %{start_time: ~T[13:00:00]}))

    assert counts() == before
  end

  test "rejects an inactive or foreign consultation type without side effects", ctx do
    before = counts()
    inactive_type = insert_consultation_type!(ctx.professional_id, status: "inactive")

    assert {:error, :consultation_type_inactive} =
             BookingService.reserve(ctx.patient, params(ctx, consultation_type_id: inactive_type))

    assert counts() == before

    foreign_professional = insert_professional!("foreign-self-booking@example.test")
    insert_agenda!(foreign_professional, "automatic")
    foreign_type = insert_consultation_type!(foreign_professional)

    assert {:error, :consultation_type_not_found} =
             BookingService.reserve(ctx.patient, params(ctx, consultation_type_id: foreign_type))

    assert counts() == before
  end

  test "forces the profile argument as identity and rejects a collision at the service boundary",
       ctx do
    forged_params = Map.put(params(ctx), :patient_profile_id, ctx.other_patient.id)
    assert {:ok, winner} = BookingService.reserve(ctx.patient, forged_params)
    assert winner.appointment.patient_profile_id == ctx.patient.id

    assert {:error, :overlap_detected} = BookingService.reserve(ctx.other_patient, params(ctx))
    assert Repo.aggregate(Appointment, :count, :id) == 1
    assert Repo.aggregate(ProfessionalPatientRelationship, :count, :id) == 1

    assert Repo.get_by(ProfessionalPatientRelationship,
             professional_account_id: ctx.professional_id,
             patient_profile_id: ctx.patient.id
           )

    refute Repo.get_by(ProfessionalPatientRelationship,
             professional_account_id: ctx.professional_id,
             patient_profile_id: ctx.other_patient.id
           )
  end

  defp params(ctx, overrides \\ []) do
    %{
      professional_id: Keyword.get(overrides, :professional_id, ctx.professional_id),
      consultation_type_id:
        Keyword.get(overrides, :consultation_type_id, ctx.consultation_type_id),
      date: @booking_date,
      slot: Keyword.get(overrides, :slot, @slot),
      snapshot_override: Keyword.get(overrides, :snapshot_override),
      now: @now
    }
  end

  defp counts do
    {Repo.aggregate(Appointment, :count, :id),
     Repo.aggregate(ProfessionalPatientRelationship, :count, :id)}
  end

  defp complete_patient!(email, document_number) do
    Patients.complete_profile(email, %{
      first_name: "Paciente",
      last_name: "Autónomo",
      document_type: "dni",
      document_number: document_number,
      birthdate: ~D[1990-01-01],
      phone: "+5491100000000"
    })
  end

  defp insert_professional!(email) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ('professional', 'active', $1, 'hash', decode('010203', 'hex'), clock_timestamp())
        RETURNING id
        """,
        [email]
      ).rows

    id
  end

  defp insert_professional_profile!(professional_id) do
    Repo.query!(
      """
      INSERT INTO professional_profiles
        (owner_account_id, first_name, last_name, specialty, license_type, license_number)
      VALUES ($1, 'Self', 'Booking', 'General', 'Free', $2)
      """,
      [professional_id, "SELF-#{professional_id}"]
    )
  end

  defp insert_agenda!(professional_id, approval_mode) do
    week =
      ~s({"monday":[{"start":"09:00","end":"12:00"}],"tuesday":[],"wednesday":[],"thursday":[],"friday":[],"saturday":[],"sunday":[]})

    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days,
         minimum_lead_minutes, approval_mode, secretary_approval_mode)
      VALUES ($1, 30, $2::jsonb, 30, 30, $3, 'confirmed')
      """,
      [professional_id, week, approval_mode]
    )
  end

  defp insert_consultation_type!(professional_id, opts \\ []) do
    id = Ecto.UUID.generate()
    status = Keyword.get(opts, :status, "active")

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status, inactive_duration_minutes)
      VALUES ($1, $2, 'Consulta Real', 12500.00, '#0A7C86', 1, $3::varchar,
              CASE WHEN $3::varchar = 'inactive' THEN 30 ELSE NULL END)
      """,
      [Ecto.UUID.dump!(id), professional_id, status]
    )

    id
  end
end
