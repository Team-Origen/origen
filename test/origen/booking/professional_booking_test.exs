defmodule Origen.Booking.ProfessionalBookingTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship}
  alias Origen.Repo
  alias Origen.Sessions

  @fixed_now ~U[2026-10-10 10:00:00Z]

  setup do
    professional = professional_principal!()
    other_professional = professional_principal!()
    consultation_type_id = insert_consultation_type!(professional.account_id)
    other_type_id = insert_consultation_type!(other_professional.account_id)
    related_patient = insert_patient!("Ana", "Relacionada", "30111222")
    unrelated_patient = insert_patient!("Bruno", "Nuevo", "30222333")
    other_patient = insert_patient!("Carla", "Ocupante", "30333444")

    first_appointment_id =
      insert_appointment!(
        professional.account_id,
        related_patient,
        consultation_type_id,
        ~U[2026-10-14 09:00:00Z]
      )

    insert_relationship!(professional.account_id, related_patient, first_appointment_id)
    insert_agenda_settings!(professional.account_id, "manual")

    %{
      professional: professional,
      other_professional: other_professional,
      consultation_type_id: consultation_type_id,
      other_type_id: other_type_id,
      related_patient: related_patient,
      unrelated_patient: unrelated_patient,
      other_patient: other_patient
    }
  end

  describe "reserve_professional_appointment/3" do
    test "books a related patient in confirmed state and reuses the existing relationship", ctx do
      params =
        booking_params(ctx.related_patient, ctx.consultation_type_id, ~U[2026-10-15 09:00:00Z])

      assert {:ok, result} =
               Booking.reserve_professional_appointment(ctx.professional, params, now: @fixed_now)

      assert result.status == :confirmed
      assert result.professional_id == ctx.professional.account_id
      assert result.patient_id == ctx.related_patient
      assert result.relationship_created? == false
      assert Repo.get!(Appointment, result.appointment_id).status == "confirmed"
      assert relationship_count(ctx.professional.account_id, ctx.related_patient) == 1
    end

    test "books an exact-DNI selected registered patient and creates the relationship atomically",
         ctx do
      params =
        ctx.unrelated_patient
        |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 10:00:00Z])
        |> Map.put(:patient_document_number, " 30.222.333 ")

      assert {:ok, result} =
               Booking.reserve_professional_appointment(ctx.professional, params, now: @fixed_now)

      assert result.status == :confirmed
      assert result.professional_id == ctx.professional.account_id
      assert result.patient_id == ctx.unrelated_patient
      assert result.relationship_created? == true

      relationship =
        Repo.get_by!(ProfessionalPatientRelationship,
          professional_account_id: ctx.professional.account_id,
          patient_profile_id: ctx.unrelated_patient
        )

      assert relationship.first_appointment_id == result.appointment_id
    end

    test "always confirms in both automatic and manual approval modes", ctx do
      manual_params =
        ctx.unrelated_patient
        |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 11:00:00Z])
        |> Map.put(:patient_document_number, "30222333")

      assert {:ok, manual_result} =
               Booking.reserve_professional_appointment(ctx.professional, manual_params,
                 now: @fixed_now
               )

      Repo.query!(
        "UPDATE agenda_settings SET approval_mode = 'automatic' WHERE owner_account_id = $1",
        [
          ctx.professional.account_id
        ]
      )

      automatic_patient = insert_patient!("Dora", "Automatica", "30444555")

      automatic_params =
        automatic_patient
        |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 12:00:00Z])
        |> Map.put(:patient_document_number, "30444555")

      assert {:ok, automatic_result} =
               Booking.reserve_professional_appointment(ctx.professional, automatic_params,
                 now: @fixed_now
               )

      assert manual_result.status == :confirmed
      assert automatic_result.status == :confirmed
    end

    test "rejects an unrelated patient without the matching exact DNI and leaves no changes",
         ctx do
      before_counts = state_counts()

      for patient_document_number <- [nil, "30999999", "3022233"] do
        params =
          ctx.unrelated_patient
          |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 13:00:00Z])
          |> maybe_put_document(patient_document_number)

        assert {:error, :paciente_no_permitido} =
                 Booking.reserve_professional_appointment(ctx.professional, params,
                   now: @fixed_now
                 )

        assert state_counts() == before_counts
      end
    end

    test "derives the agenda owner from the session and ignores injected professional identities",
         ctx do
      params =
        ctx.unrelated_patient
        |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 14:00:00Z])
        |> Map.merge(%{
          patient_document_number: "30222333",
          professional_id: ctx.other_professional.account_id,
          professional_account_id: ctx.other_professional.account_id
        })

      assert {:ok, result} =
               Booking.reserve_professional_appointment(ctx.professional, params, now: @fixed_now)

      assert result.professional_id == ctx.professional.account_id
    end

    test "rejects another professional's consultation type without creating a relationship",
         ctx do
      before_counts = state_counts()

      params =
        ctx.unrelated_patient
        |> booking_params(ctx.other_type_id, ~U[2026-10-15 15:00:00Z])
        |> Map.put(:patient_document_number, "30222333")

      assert {:error, :consultation_type_not_found} =
               Booking.reserve_professional_appointment(ctx.professional, params, now: @fixed_now)

      assert state_counts() == before_counts
    end

    test "rejects an occupied slot without leaving a relationship for the selected patient",
         ctx do
      start_time = ~U[2026-10-15 16:00:00Z]

      insert_appointment!(
        ctx.professional.account_id,
        ctx.other_patient,
        ctx.consultation_type_id,
        start_time
      )

      before_counts = state_counts()

      params =
        ctx.unrelated_patient
        |> booking_params(ctx.consultation_type_id, start_time)
        |> Map.put(:patient_document_number, "30222333")

      assert {:error, :slot_already_booked} =
               Booking.reserve_professional_appointment(ctx.professional, params, now: @fixed_now)

      assert state_counts() == before_counts
    end

    test "rolls back appointment and relationship when persistence fails", ctx do
      before_counts = state_counts()

      params =
        ctx.unrelated_patient
        |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 17:00:00Z])
        |> Map.put(:patient_document_number, "30222333")

      assert {:error, :fallo_auditoria} =
               Booking.reserve_professional_appointment(ctx.professional, params,
                 now: @fixed_now,
                 fail_at: :audit_event
               )

      assert state_counts() == before_counts
    end

    test "fails closed for invalid, revoked, and non-professional sessions without writes", ctx do
      revoked = professional_principal!()

      Repo.query!(
        "UPDATE internal_account_sessions SET revoked_at = clock_timestamp() WHERE id = $1",
        [revoked.session_id]
      )

      secretary = :secretary |> insert_active_account!() |> principal_for!()

      params =
        ctx.unrelated_patient
        |> booking_params(ctx.consultation_type_id, ~U[2026-10-15 18:00:00Z])
        |> Map.put(:patient_document_number, "30222333")

      for principal <- [revoked, secretary, %{}, nil] do
        before_counts = state_counts()

        assert {:error, :unauthorized} =
                 Booking.reserve_professional_appointment(principal, params, now: @fixed_now)

        assert state_counts() == before_counts
      end
    end
  end

  defp booking_params(patient_id, consultation_type_id, start_time) do
    %{
      patient_id: patient_id,
      consultation_type_id: consultation_type_id,
      start_time: start_time
    }
  end

  defp maybe_put_document(params, nil), do: params

  defp maybe_put_document(params, document_number),
    do: Map.put(params, :patient_document_number, document_number)

  defp professional_principal!, do: :professional |> insert_active_account!() |> principal_for!()

  defp insert_active_account!(role) do
    Repo.query!(
      """
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ($1, 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
      """,
      [Atom.to_string(role)]
    ).rows
    |> hd()
    |> hd()
  end

  defp principal_for!(account_id) do
    {:ok, %{session: principal}} = Sessions.create_session(account_id)
    principal
  end

  defp insert_patient!(first_name, last_name, document_number) do
    persona_id =
      Repo.query!(
        """
        INSERT INTO personas (first_name, last_name, document_type, document_number, birthdate)
        VALUES ($1, $2, 'dni', $3, '1990-01-01') RETURNING id
        """,
        [first_name, last_name, document_number]
      ).rows
      |> hd()
      |> hd()

    Repo.query!(
      """
      INSERT INTO patient_profiles (persona_id, email, state, phone, phone_verified)
      VALUES ($1, $2, 'completed', '+5491100000000', true) RETURNING id
      """,
      [persona_id, "#{document_number}@example.test"]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_consultation_type!(professional_id) do
    id = Ecto.UUID.bingenerate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Consulta General', 15000, '#112233', 1, 'active')
      """,
      [id, professional_id]
    )

    Ecto.UUID.load!(id)
  end

  defp insert_agenda_settings!(professional_id, approval_mode) do
    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, approval_mode, secretary_approval_mode)
      VALUES ($1, 30, $2, 'requested')
      """,
      [professional_id, approval_mode]
    )
  end

  defp insert_appointment!(professional_id, patient_id, consultation_type_id, start_time) do
    {:ok, type_id} = Ecto.UUID.dump(consultation_type_id)

    Repo.query!(
      """
      INSERT INTO appointments
        (patient_profile_id, professional_account_id, consultation_type_id,
         start_time, end_time, status,
         snapshot_consultation_type_name, snapshot_duration_minutes, snapshot_exact_price_ars)
      VALUES ($1, $2, $3, $4, $5, 'confirmed', 'Consulta General', 30, 15000)
      RETURNING id
      """,
      [patient_id, professional_id, type_id, start_time, DateTime.add(start_time, 30, :minute)]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_relationship!(professional_id, patient_id, appointment_id) do
    Repo.query!(
      """
      INSERT INTO professional_patient_relationships
        (professional_account_id, patient_profile_id, first_appointment_id)
      VALUES ($1, $2, $3)
      """,
      [professional_id, patient_id, appointment_id]
    )
  end

  defp relationship_count(professional_id, patient_id) do
    Repo.query!(
      """
      SELECT count(*) FROM professional_patient_relationships
      WHERE professional_account_id = $1 AND patient_profile_id = $2
      """,
      [professional_id, patient_id]
    ).rows
    |> hd()
    |> hd()
  end

  defp state_counts do
    %{
      appointments: scalar!("SELECT count(*) FROM appointments"),
      relationships: scalar!("SELECT count(*) FROM professional_patient_relationships"),
      audit_events: scalar!("SELECT count(*) FROM audit_events")
    }
  end

  defp scalar!(sql), do: Repo.query!(sql).rows |> hd() |> hd()
end
