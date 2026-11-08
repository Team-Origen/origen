defmodule Origen.TestSupport.AppointmentLifecycleFixtures do
  alias Ecto.Adapters.SQL
  alias Origen.Booking.Appointment
  alias Origen.Repo

  def create! do
    professional_id = internal_account!("lifecycle-prof")
    other_professional_id = internal_account!("lifecycle-other-prof")
    patient_id = patient_profile!("lifecycle-patient")
    other_patient_id = patient_profile!("lifecycle-other-patient")
    consultation_type_id = Ecto.UUID.generate()

    SQL.query!(
      Repo,
      """
      INSERT INTO public.consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at)
      VALUES ($1, $2, 'Lifecycle consultation', 100.00, '#112233', 1, 'active', clock_timestamp(), clock_timestamp())
      """,
      [Ecto.UUID.dump!(consultation_type_id), professional_id]
    )

    %{
      professional_id: professional_id,
      other_professional_id: other_professional_id,
      patient_id: patient_id,
      other_patient_id: other_patient_id,
      consultation_type_id: consultation_type_id
    }
  end

  def appointment!(fixture, attrs) do
    attrs = Map.new(attrs)
    start_time = Map.fetch!(attrs, :start_time)
    duration = Map.get(attrs, :duration_minutes, 30)

    %Appointment{}
    |> Appointment.changeset(%{
      patient_profile_id: Map.get(attrs, :patient_profile_id, fixture.patient_id),
      professional_account_id: Map.get(attrs, :professional_account_id, fixture.professional_id),
      consultation_type_id: fixture.consultation_type_id,
      start_time: start_time,
      end_time: DateTime.add(start_time, duration, :minute),
      status: Map.get(attrs, :status, "requested"),
      snapshot_consultation_type_name: "Lifecycle consultation",
      snapshot_duration_minutes: duration,
      snapshot_exact_price_ars: Decimal.new("100.00")
    })
    |> Repo.insert!()
  end

  def audit_events_for(appointment_id) do
    SQL.query!(
      Repo,
      """
      SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result
      FROM public.audit_events
      WHERE entity_ref = $1
      ORDER BY id
      """,
      ["appointment:#{appointment_id}"]
    ).rows
  end

  defp internal_account!(label) do
    SQL.query!(
      Repo,
      """
      INSERT INTO public.internal_accounts
        (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
      VALUES ($1, 'professional', 'active', 'hash', decode('0102', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
      RETURNING id
      """,
      ["#{label}-#{System.unique_integer([:positive])}@example.test"]
    ).rows
    |> hd()
    |> hd()
  end

  defp patient_profile!(label) do
    SQL.query!(
      Repo,
      """
      INSERT INTO public.patient_profiles
        (email, state, created_at, updated_at)
      VALUES ($1, 'completed', clock_timestamp(), clock_timestamp())
      RETURNING id
      """,
      ["#{label}-#{System.unique_integer([:positive])}@example.test"]
    ).rows
    |> hd()
    |> hd()
  end
end
