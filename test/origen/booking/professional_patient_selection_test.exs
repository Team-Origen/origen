defmodule Origen.Booking.ProfessionalPatientSelectionTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Repo
  alias Origen.Sessions

  setup do
    professional_a = professional_principal!()
    professional_b = professional_principal!()
    related_to_a = insert_patient!("Ana", "Relacionada", "30111222")
    related_to_b = insert_patient!("Bruno", "Ajeno", "30222333")
    unrelated = insert_patient!("Carla", "Sin Relacion", "30333444")

    insert_relationship!(professional_a.account_id, related_to_a)
    insert_relationship!(professional_b.account_id, related_to_b)

    %{
      professional_a: professional_a,
      professional_b: professional_b,
      related_to_a: related_to_a,
      related_to_b: related_to_b,
      unrelated: unrelated
    }
  end

  describe "list_professional_patients/1" do
    test "lists only the authenticated professional's related patients with the minimal projection",
         ctx do
      assert {:ok, patients} = Booking.list_professional_patients(ctx.professional_a)

      assert patients == [
               %{
                 id: ctx.related_to_a,
                 first_name: "Ana",
                 last_name: "Relacionada",
                 document_number: "30111222"
               }
             ]

      assert Enum.sort(Map.keys(hd(patients))) ==
               [:document_number, :first_name, :id, :last_name]
    end

    test "returns an empty list and never includes patients related only to another professional",
         ctx do
      professional_c = professional_principal!()

      assert {:ok, []} = Booking.list_professional_patients(professional_c)
      assert {:ok, patients_a} = Booking.list_professional_patients(ctx.professional_a)
      refute Enum.any?(patients_a, &(&1.id == ctx.related_to_b))
      refute Enum.any?(patients_a, &(&1.id == ctx.unrelated))
    end
  end

  describe "find_professional_patient_by_dni/2" do
    test "finds a registered patient by normalized exact DNI without exposing contact or activity",
         ctx do
      before_counts = state_counts()

      assert {:ok, patient} =
               Booking.find_professional_patient_by_dni(ctx.professional_a, " 30.333.444 ")

      assert patient == %{
               id: ctx.unrelated,
               first_name: "Carla",
               last_name: "Sin Relacion",
               document_number: "30333444"
             }

      assert Enum.sort(Map.keys(patient)) ==
               [:document_number, :first_name, :id, :last_name]

      assert state_counts() == before_counts
    end

    test "does not reveal whether the patient is related to another professional", ctx do
      before_counts = state_counts()

      assert {:ok, patient} =
               Booking.find_professional_patient_by_dni(ctx.professional_a, "30222333")

      assert patient == %{
               id: ctx.related_to_b,
               first_name: "Bruno",
               last_name: "Ajeno",
               document_number: "30222333"
             }

      assert state_counts() == before_counts
    end

    test "returns no result for an absent DNI or a Persona without a patient profile and creates nothing",
         ctx do
      insert_persona!("Persona", "Sin Perfil", "30444555")
      before_counts = state_counts()

      assert {:ok, nil} =
               Booking.find_professional_patient_by_dni(ctx.professional_a, "30999999")

      assert {:ok, nil} =
               Booking.find_professional_patient_by_dni(ctx.professional_a, "30444555")

      assert state_counts() == before_counts
    end

    test "rejects incomplete or invalid DNI without partial matches or writes", ctx do
      before_counts = state_counts()

      for invalid <- ["3033", "3033344x", "", "   ", nil, 30_333_444] do
        assert {:error, :invalid_dni} =
                 Booking.find_professional_patient_by_dni(ctx.professional_a, invalid)
      end

      assert state_counts() == before_counts
    end
  end

  describe "session authorization" do
    test "both operations fail closed for tampered, revoked, inactive, and non-professional sessions",
         ctx do
      tampered = %{ctx.professional_a | account_id: ctx.professional_b.account_id}

      revoked = professional_principal!()

      Repo.query!(
        "UPDATE internal_account_sessions SET revoked_at = clock_timestamp() WHERE id = $1",
        [revoked.session_id]
      )

      inactive = professional_principal!()

      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL
        WHERE id = $1
        """,
        [inactive.account_id]
      )

      secretary = :secretary |> insert_active_account!() |> principal_for!()

      for principal <- [tampered, revoked, inactive, secretary, %{}, nil] do
        before_counts = state_counts()

        assert {:error, :unauthorized} = Booking.list_professional_patients(principal)

        assert {:error, :unauthorized} =
                 Booking.find_professional_patient_by_dni(principal, "30333444")

        assert state_counts() == before_counts
      end
    end
  end

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
    persona_id = insert_persona!(first_name, last_name, document_number)

    Repo.query!(
      """
      INSERT INTO patient_profiles (persona_id, email, state, phone, phone_verified)
      VALUES ($1, $2, 'completed', '+5491100000000', true)
      RETURNING id
      """,
      [persona_id, "#{document_number}@example.test"]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_persona!(first_name, last_name, document_number) do
    Repo.query!(
      """
      INSERT INTO personas (first_name, last_name, document_type, document_number, birthdate)
      VALUES ($1, $2, 'dni', $3, '1990-01-01')
      RETURNING id
      """,
      [first_name, last_name, document_number]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_relationship!(professional_id, patient_id) do
    appointment_id = insert_appointment_stub!(professional_id, patient_id)

    Repo.query!(
      """
      INSERT INTO professional_patient_relationships
        (professional_account_id, patient_profile_id, first_appointment_id)
      VALUES ($1, $2, $3)
      """,
      [professional_id, patient_id, appointment_id]
    )
  end

  defp insert_appointment_stub!(professional_id, patient_id) do
    consultation_type_id = Ecto.UUID.bingenerate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Consulta', 1000, '#112233', 1, 'active')
      """,
      [consultation_type_id, professional_id]
    )

    Repo.query!(
      """
      INSERT INTO appointments
        (patient_profile_id, professional_account_id, consultation_type_id,
         start_time, end_time, status,
         snapshot_consultation_type_name, snapshot_duration_minutes, snapshot_exact_price_ars)
      VALUES ($1, $2, $3, '2035-01-01 09:00:00Z', '2035-01-01 09:30:00Z', 'confirmed',
              'Consulta', 30, 1000)
      RETURNING id
      """,
      [patient_id, professional_id, consultation_type_id]
    ).rows
    |> hd()
    |> hd()
  end

  defp state_counts do
    %{
      appointments: scalar!("SELECT count(*) FROM appointments"),
      relationships: scalar!("SELECT count(*) FROM professional_patient_relationships")
    }
  end

  defp scalar!(sql), do: Repo.query!(sql).rows |> hd() |> hd()
end
