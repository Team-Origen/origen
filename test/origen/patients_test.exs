defmodule Origen.PatientsTest do
  use Origen.DataCase

  import Ecto.Query
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @valid_attrs %{
    first_name: "María",
    last_name: "González",
    document_type: "dni",
    document_number: "40.123.456",
    birthdate: ~D[1995-04-15],
    gender: "femenino"
  }

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)
    :ok
  end

  describe "complete_profile/3" do
    test "completes profile with valid identity, creates Persona and normalizes document" do
      email = "paciente_nuevo@example.test"

      assert {:ok, result} = Patients.complete_profile(email, @valid_attrs)

      assert result.outcome == :completed
      assert result.profile.state == "completed"
      assert result.profile.phone_verified == false
      assert result.persona != nil
      assert result.persona.first_name == "María"
      assert result.persona.last_name == "González"
      assert result.persona.document_type == "dni"
      # Document number normalized (no dots)
      assert result.persona.document_number == "40123456"
      assert result.persona.birthdate == ~D[1995-04-15]

      # Criterion 4: profile not ready for booking until phone is verified in #90
      refute Patients.ready_for_booking?(result.profile)

      # Audit event logged
      audit_event =
        Repo.one(
          from a in "audit_events",
            select: a.id,
            where: a.event == "patient_profile_completed" and a.entity_ref == ^email
        )

      assert audit_event != nil
    end

    test "normalizes document numbers with spaces, dots, and hyphens" do
      email = "paciente_normalizacion@example.test"
      attrs = Map.put(@valid_attrs, :document_number, "p- 123.456 ")

      assert {:ok, result} = Patients.complete_profile(email, attrs)
      assert result.persona.document_number == "P123456"
    end

    test "rejects uncontrolled document types" do
      email = "paciente_doc_invalido@example.test"
      attrs = Map.put(@valid_attrs, :document_type, "cedula_invalida")

      assert {:error, changeset} = Patients.complete_profile(email, attrs)
      assert "is invalid" in errors_on(changeset).document_type
    end

    test "rejects future birthdates" do
      email = "paciente_futuro@example.test"
      future = Date.add(Date.utc_today(), 1)
      attrs = Map.put(@valid_attrs, :birthdate, future)

      assert {:error, changeset} = Patients.complete_profile(email, attrs)
      assert "debe ser una fecha en el pasado" in errors_on(changeset).birthdate
    end

    test "detects document collision, derives to Secretary without duplicating or auto-linking Persona" do
      # 1. Existing patient registers first
      email_1 = "paciente_original@example.test"
      assert {:ok, res_1} = Patients.complete_profile(email_1, @valid_attrs)
      assert res_1.outcome == :completed
      _persona_original_id = res_1.persona.id

      # 2. Second patient with DIFFERENT account presents the SAME document
      email_2 = "paciente_colision@example.test"

      attrs_colision = %{
        first_name: "Otra",
        last_name: "Persona",
        document_type: "dni",
        document_number: "40.123.456",
        birthdate: ~D[1990-01-01]
      }

      assert {:ok, res_2} = Patients.complete_profile(email_2, attrs_colision)

      # Criterion: Derived to Secretary
      assert res_2.outcome == :derived_to_secretary
      assert res_2.profile.state == "pending_secretary_review"
      assert res_2.profile.collision_detected_at != nil
      assert res_2.profile.collision_notes =~ "Colisión documental"

      # CRITICAL: Persona is NOT duplicated! Exactly 1 Persona in DB.
      assert Repo.aggregate(Persona, :count, :id) == 1

      # CRITICAL: Profile is NOT automatically linked to the existing Persona!
      assert res_2.persona == nil
      assert res_2.profile.persona_id == nil

      # Audit event logged for collision derivation
      audit_event =
        Repo.one(
          from a in "audit_events",
            select: a.id,
            where: a.event == "document_collision_derived" and a.entity_ref == ^email_2
        )

      assert audit_event != nil
    end

    test "preserves phone_verified false even if phone is provided in attributes" do
      email = "paciente_telefono@example.test"
      attrs = Map.put(@valid_attrs, :phone, "+5491122334455")

      assert {:ok, result} = Patients.complete_profile(email, attrs)
      assert result.profile.phone == "+5491122334455"
      assert result.profile.phone_verified == false
      refute Patients.ready_for_booking?(result.profile)
    end
  end
end
