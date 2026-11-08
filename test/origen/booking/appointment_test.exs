defmodule Origen.Booking.AppointmentTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship}
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "start, end, consultation type and patient/professional identity are immutable", %{
    fixture: f
  } do
    appointment =
      Fixtures.appointment!(f, start_time: ~U[2026-12-03 09:00:00Z], status: "confirmed")

    updates = [
      {"start_time", ~U[2026-12-03 10:00:00Z]},
      {"end_time", ~U[2026-12-03 10:30:00Z]},
      {"consultation_type_id", Ecto.UUID.dump!(Ecto.UUID.generate())},
      {"patient_profile_id", f.other_patient_id},
      {"professional_account_id", f.other_professional_id}
    ]

    for {column, value} <- updates do
      assert_raise Postgrex.Error,
                   ~r/appointment snapshots and core identity are immutable/,
                   fn ->
                     Repo.query!("UPDATE appointments SET #{column} = $1 WHERE id = $2", [
                       value,
                       appointment.id
                     ])
                   end
    end

    persisted = Repo.get!(Appointment, appointment.id)
    assert persisted.start_time == appointment.start_time
    assert persisted.end_time == appointment.end_time
    assert persisted.patient_profile_id == appointment.patient_profile_id
    assert persisted.professional_account_id == appointment.professional_account_id
    assert persisted.consultation_type_id == appointment.consultation_type_id
  end

  test "changing the date cancels the original and creates a new authorized reservation", %{
    fixture: f
  } do
    {original, response} =
      replace_appointment(f, ~U[2026-12-03 11:00:00Z], ~U[2026-12-04 11:00:00Z])

    assert response.status == :reserved

    assert DateTime.compare(Repo.get!(Appointment, original.id).start_time, original.start_time) ==
             :eq

    assert DateTime.compare(response.start_time, ~U[2026-12-04 11:00:00Z]) == :eq
  end

  test "changing the hour cancels the original and creates a new authorized reservation", %{
    fixture: f
  } do
    {original, response} =
      replace_appointment(f, ~U[2026-12-03 11:00:00Z], ~U[2026-12-03 12:00:00Z])

    assert response.status == :reserved

    assert DateTime.compare(Repo.get!(Appointment, original.id).start_time, original.start_time) ==
             :eq

    assert DateTime.compare(response.start_time, ~U[2026-12-03 12:00:00Z]) == :eq
  end

  test "changing the consultation type cancels the original and creates a new authorized reservation",
       %{
         fixture: f
       } do
    replacement_type = insert_consultation_type!(f.professional_id, "Replacement consultation")

    {original, response} =
      replace_appointment(
        f,
        ~U[2026-12-03 11:00:00Z],
        ~U[2026-12-03 12:00:00Z],
        replacement_type
      )

    assert response.status == :reserved
    assert response.consultation_type_id == replacement_type
    assert Repo.get!(Appointment, original.id).consultation_type_id == f.consultation_type_id
  end

  defp replace_appointment(fixture, original_start, replacement_start, type_id \\ nil) do
    original = Fixtures.appointment!(fixture, start_time: original_start, status: "confirmed")
    principal = Fixtures.professional_principal(fixture)

    %ProfessionalPatientRelationship{}
    |> ProfessionalPatientRelationship.changeset(%{
      professional_account_id: fixture.professional_id,
      patient_profile_id: fixture.patient_id,
      first_appointment_id: original.id
    })
    |> Repo.insert!()

    assert {:ok, _} =
             Booking.cancel_appointment(principal, original.id, reason: "Cambio solicitado")

    Repo.query!(
      "UPDATE patient_profiles SET phone = '+5491100000000', phone_verified = true WHERE id = $1",
      [fixture.patient_id]
    )

    type_id = type_id || fixture.consultation_type_id

    assert {:ok, response} =
             Booking.reserve_appointment(
               %{
                 actor: %{role: :patient, id: fixture.patient_id},
                 patient_id: fixture.patient_id,
                 professional_id: fixture.professional_id,
                 consultation_type_id: type_id,
                 start_time: replacement_start
               },
               now: ~U[2026-12-01 10:00:00Z]
             )

    {original, response}
  end

  defp insert_consultation_type!(professional_id, name) do
    type_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, 100.00, '#445566', 1, 'active')
      """,
      [Ecto.UUID.dump!(type_id), professional_id, name]
    )

    type_id
  end
end
