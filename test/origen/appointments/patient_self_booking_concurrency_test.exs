defmodule Origen.Appointments.PatientSelfBookingConcurrencyTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Appointments.BookingService
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship}
  alias Origen.Patients.PatientProfile
  alias Origen.Repo

  @slot_date ~D[2026-11-03]
  @slot_time ~T[09:00:00]
  @now ~U[2026-10-20 08:00:00Z]

  test "concurrent self-bookings produce one success, one overlap, and one relationship" do
    :ok = Sandbox.checkout(Repo, sandbox: false)
    fixture = insert_fixture!()
    Sandbox.checkin(Repo)

    on_exit(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        cleanup_fixture!(fixture)
      after
        Sandbox.checkin(Repo)
      end
    end)

    parent = self()

    tasks =
      Enum.map(fixture.patient_ids, fn patient_id ->
        Task.async(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          send(parent, {:ready, patient_id})

          receive do
            :go -> :ok
          after
            10_000 -> exit(:barrier_timeout)
          end

          profile = %PatientProfile{id: patient_id, state: "completed", phone_verified: false}

          try do
            BookingService.reserve(profile, %{
              professional_id: fixture.professional_id,
              consultation_type_id: fixture.consultation_type_id,
              date: @slot_date,
              slot: %{start_time: @slot_time},
              now: @now
            })
          after
            Sandbox.checkin(Repo)
          end
        end)
      end)

    Enum.each(fixture.patient_ids, fn patient_id ->
      assert_receive {:ready, ^patient_id}, 10_000
    end)

    Enum.each(tasks, fn task -> send(task.pid, :go) end)
    results = Task.await_many(tasks, 15_000)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :overlap_detected})) == 1

    :ok = Sandbox.checkout(Repo, sandbox: false)

    try do
      assert Repo.aggregate(
               from(a in Appointment,
                 where: a.professional_account_id == ^fixture.professional_id
               ),
               :count,
               :id
             ) == 1

      assert Repo.aggregate(
               from(r in ProfessionalPatientRelationship,
                 where: r.professional_account_id == ^fixture.professional_id
               ),
               :count,
               :id
             ) == 1
    after
      Sandbox.checkin(Repo)
    end
  end

  defp insert_fixture! do
    suffix = System.unique_integer([:positive])
    professional_id = insert_professional!(suffix)
    insert_professional_profile!(professional_id)
    insert_agenda!(professional_id)
    consultation_type_id = insert_consultation_type!(professional_id)
    patient_ids = Enum.map(1..2, &insert_patient!(&1, suffix))

    %{
      professional_id: professional_id,
      consultation_type_id: consultation_type_id,
      patient_ids: patient_ids
    }
  end

  defp insert_professional!(suffix) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, 'professional', 'active', 'hash', decode('010203', 'hex'), clock_timestamp())
        RETURNING id
        """,
        ["concurrent-self-booking-#{suffix}@example.test"]
      ).rows

    id
  end

  defp insert_professional_profile!(professional_id) do
    Repo.query!(
      """
      INSERT INTO professional_profiles
        (owner_account_id, first_name, last_name, specialty, license_type, license_number)
      VALUES ($1, 'Concurrent', 'Professional', 'General', 'Free', $2)
      """,
      [professional_id, "LIC-#{professional_id}"]
    )
  end

  defp insert_agenda!(professional_id) do
    week =
      ~s({"tuesday":[{"start":"09:00","end":"12:00"}],"monday":[],"wednesday":[],"thursday":[],"friday":[],"saturday":[],"sunday":[]})

    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days,
         minimum_lead_minutes, approval_mode, secretary_approval_mode)
      VALUES ($1, 30, $2::jsonb, 30, 0, 'automatic', 'confirmed')
      """,
      [professional_id, week]
    )
  end

  defp insert_consultation_type!(professional_id) do
    id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Concurrent Consultation', 100.00, '#445566', 1, 'active')
      """,
      [Ecto.UUID.dump!(id), professional_id]
    )

    id
  end

  defp insert_patient!(index, suffix) do
    [[persona_id]] =
      Repo.query!(
        """
        INSERT INTO personas
          (first_name, last_name, document_type, document_number, birthdate)
        VALUES ('Concurrent', $1, 'dni', $2, '1990-01-01')
        RETURNING id
        """,
        ["Patient #{index}", Integer.to_string(50_000_000 + suffix * 10 + index)]
      ).rows

    [[profile_id]] =
      Repo.query!(
        """
        INSERT INTO patient_profiles
          (persona_id, email, state, phone, phone_verified)
        VALUES ($1, $2, 'completed', '+5491100000000', false)
        RETURNING id
        """,
        [persona_id, "concurrent-patient-#{suffix}-#{index}@example.test"]
      ).rows

    profile_id
  end

  defp cleanup_fixture!(fixture) do
    persona_ids =
      Repo.query!(
        "SELECT persona_id FROM patient_profiles WHERE id = ANY($1)",
        [fixture.patient_ids]
      ).rows
      |> Enum.map(&hd/1)

    Repo.query!(
      "DELETE FROM professional_patient_relationships WHERE professional_account_id = $1",
      [fixture.professional_id]
    )

    Repo.query!("DELETE FROM appointments WHERE professional_account_id = $1", [
      fixture.professional_id
    ])

    Repo.query!("DELETE FROM consultation_types WHERE id = $1", [
      Ecto.UUID.dump!(fixture.consultation_type_id)
    ])

    Repo.query!("DELETE FROM agenda_settings WHERE owner_account_id = $1", [
      fixture.professional_id
    ])

    Repo.query!("DELETE FROM professional_profiles WHERE owner_account_id = $1", [
      fixture.professional_id
    ])

    Repo.query!("DELETE FROM patient_profiles WHERE id = ANY($1)", [fixture.patient_ids])
    Repo.query!("DELETE FROM personas WHERE id = ANY($1)", [persona_ids])
    Repo.query!("DELETE FROM internal_accounts WHERE id = $1", [fixture.professional_id])
  end
end
