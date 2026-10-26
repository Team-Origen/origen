defmodule Origen.Patients.SecretarySearchTest do
  use Origen.DataCase, async: false

  import Ecto.Query

  alias Origen.Audit.Events
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @valid_attrs %{
    first_name: "Ana",
    last_name: "Torres",
    document_type: "dni",
    document_number: "37.111.222",
    birthdate: ~D[1990-03-05],
    phone: "+5491155554444",
    gender: "femenino",
    email: nil
  }

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    secretary_account_id = insert_internal_account!("secretary", "active")
    admin_account_id = insert_internal_account!("administrator", "active")
    professional_account_id = insert_internal_account!("professional", "active")
    inactive_secretary_id = insert_internal_account!("secretary", "pending_activation")

    %{
      secretary_id: secretary_account_id,
      admin_id: admin_account_id,
      professional_id: professional_account_id,
      inactive_secretary_id: inactive_secretary_id
    }
  end

  describe "search_persona_by_document/3" do
    test "finds an existing persona with its linked profile and normalizes document number", %{
      secretary_id: secretary_id
    } do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.complete_profile("busqueda@example.test", %{
          first_name: "Carlos",
          last_name: "López",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1988-07-20],
          phone: "+5491144332211"
        })

      assert {:ok, result} =
               Patients.search_persona_by_document("dni", " 35.987.654 ", secretary_id)

      assert result.persona.id == persona.id
      assert result.persona.document_number == "35987654"
      assert result.profile.id == profile.id
      assert result.profile.state == "completed"
    end

    test "returns {:ok, nil} when the persona does not exist", %{secretary_id: secretary_id} do
      assert {:ok, nil} =
               Patients.search_persona_by_document("passport", "ZZ999999", secretary_id)
    end

    test "returns a nil profile when the persona exists without a linked profile", %{
      secretary_id: secretary_id
    } do
      {:ok, persona} =
        %Persona{}
        |> Persona.changeset(%{
          first_name: "Sin",
          last_name: "Perfil",
          document_type: "dni",
          document_number: "30000099",
          birthdate: ~D[1975-01-01]
        })
        |> Repo.insert()

      assert {:ok, %{persona: found, profile: nil}} =
               Patients.search_persona_by_document("dni", "30000099", secretary_id)

      assert found.id == persona.id
    end

    test "audits every search in public.audit_events with the secretary as actor", %{
      secretary_id: secretary_id
    } do
      Patients.search_persona_by_document("dni", "35000001", secretary_id)

      [search_event] =
        Repo.all(
          from a in "audit_events",
            where: a.event == "persona_searched",
            select: %{
              actor_kind: a.actor_kind,
              actor_ref: a.actor_ref,
              entity_kind: a.entity_kind,
              entity_ref: a.entity_ref,
              result: a.result
            }
        )

      assert search_event.actor_kind == "secretary"
      assert search_event.actor_ref == Integer.to_string(secretary_id)
      assert search_event.entity_kind == "patient"
      assert search_event.entity_ref == "dni:35000001"
      assert search_event.result == "succeeded"
    end

    test "rejects unauthorized actors without implicit access", %{
      admin_id: admin_id,
      professional_id: professional_id,
      inactive_secretary_id: inactive_secretary_id
    } do
      assert {:error, :unauthorized} =
               Patients.search_persona_by_document("dni", "35000001", admin_id)

      assert {:error, :unauthorized} =
               Patients.search_persona_by_document("dni", "35000001", professional_id)

      assert {:error, :unauthorized} =
               Patients.search_persona_by_document("dni", "35000001", inactive_secretary_id)

      assert {:error, :unauthorized} =
               Patients.search_persona_by_document("dni", "35000001", 999_999)
    end
  end

  describe "register_absent_patient/2 - creation path and beta boundaries" do
    test "creates persona and linked profile with mandatory fields and without personal access",
         %{secretary_id: secretary_id} do
      assert {:ok, %{persona: persona, profile: profile, outcome: :created}} =
               Patients.register_absent_patient(@valid_attrs, secretary_id)

      assert persona.document_number == "37111222"
      assert persona.first_name == "Ana"
      assert persona.last_name == "Torres"

      assert profile.persona_id == persona.id
      assert profile.state == "completed"
      assert profile.phone == "+5491155554444"
      assert profile.phone_verified == false
      assert profile.email == nil
      assert profile.contact_email == nil
    end

    test "defaults string-keyed assisted input to DNI", %{secretary_id: secretary_id} do
      attrs =
        @valid_attrs
        |> Map.delete(:document_type)
        |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)

      assert {:ok, %{persona: persona}} = Patients.register_absent_patient(attrs, secretary_id)
      assert persona.document_type == "dni"
    end

    test "stores optional contact email without granting personal account", %{
      secretary_id: secretary_id
    } do
      attrs = Map.put(@valid_attrs, :email, "  Contacto@Example.Test ")
      links_before = Repo.aggregate(Origen.PatientAccess.MagicLink, :count)
      challenges_before = Repo.aggregate(Origen.Patients.PhoneVerificationChallenge, :count)

      assert {:ok, %{profile: profile}} = Patients.register_absent_patient(attrs, secretary_id)

      assert profile.contact_email == "contacto@example.test"
      assert profile.email == nil
      refute profile.phone_verified
      assert Repo.aggregate(Origen.PatientAccess.MagicLink, :count) == links_before

      assert Repo.aggregate(Origen.Patients.PhoneVerificationChallenge, :count) ==
               challenges_before
    end

    test "allows shared contact email and phone between distinct patients without collision",
         %{secretary_id: secretary_id} do
      attrs_1 = %{
        @valid_attrs
        | document_number: "37111222",
          first_name: "Hijo Uno",
          email: "familia@example.test",
          phone: "+5491199887766"
      }

      attrs_2 = %{
        @valid_attrs
        | document_number: "38222333",
          first_name: "Hijo Dos",
          email: "familia@example.test",
          phone: "+5491199887766"
      }

      assert {:ok, %{profile: p1}} = Patients.register_absent_patient(attrs_1, secretary_id)
      assert {:ok, %{profile: p2}} = Patients.register_absent_patient(attrs_2, secretary_id)

      assert p1.contact_email == "familia@example.test"
      assert p2.contact_email == "familia@example.test"
      assert p1.email == nil
      assert p2.email == nil
      assert Repo.aggregate(Persona, :count) == 2
      assert Repo.aggregate(PatientProfile, :count) == 2
    end

    test "audits the creation in append-only log", %{secretary_id: secretary_id} do
      Patients.register_absent_patient(@valid_attrs, secretary_id)

      [created_event] =
        Repo.all(
          from a in "audit_events",
            where: a.event == "persona_created",
            select: %{
              actor_kind: a.actor_kind,
              actor_ref: a.actor_ref,
              entity_kind: a.entity_kind,
              entity_ref: a.entity_ref,
              result: a.result
            }
        )

      assert created_event.actor_kind == "secretary"
      assert created_event.actor_ref == Integer.to_string(secretary_id)
      assert created_event.entity_kind == "patient"
      assert created_event.entity_ref == "dni:37111222"
      assert created_event.result == "succeeded"
    end
  end

  describe "register_absent_patient/2 - duplicate DNI and missing fields rejection" do
    test "requires each minimum field independently", %{secretary_id: secretary_id} do
      for field <- [:first_name, :last_name, :document_number, :birthdate, :phone],
          value <- [nil, "", "   "] do
        assert {:error, changeset} =
                 Patients.register_absent_patient(
                   Map.put(@valid_attrs, field, value),
                   secretary_id
                 )

        assert Map.has_key?(errors_on(changeset), field)
      end

      assert Repo.aggregate(Persona, :count) == 0
      assert Repo.aggregate(PatientProfile, :count) == 0
    end

    test "preserves other document types and schema default without requiring gender", %{
      secretary_id: secretary_id
    } do
      for type <- [nil, "passport", "identity_card", "other"] do
        attrs = @valid_attrs |> Map.drop([:document_type, :gender])
        attrs = if type, do: Map.put(attrs, :document_type, type), else: attrs

        assert {:ok, %{persona: persona}} = Patients.register_absent_patient(attrs, secretary_id)
        assert persona.document_type == (type || "dni")
        assert persona.gender == nil
      end
    end

    test "rejects duplicate DNI and preserves existing identity without partial writes", %{
      secretary_id: secretary_id
    } do
      assert {:ok, %{persona: original}} =
               Patients.register_absent_patient(@valid_attrs, secretary_id)

      tampered_attrs = %{
        @valid_attrs
        | document_number: " 37.111.222 ",
          first_name: "Nombre Distinto",
          last_name: "Apellido Distinto"
      }

      assert {:error, changeset} =
               Patients.register_absent_patient(tampered_attrs, secretary_id)

      assert errors_on(changeset).document_number != nil
      assert Repo.aggregate(Persona, :count) == 1
      assert Repo.aggregate(PatientProfile, :count) == 1

      persisted = Repo.get!(Persona, original.id)
      assert persisted.first_name == "Ana"
      assert persisted.last_name == "Torres"
    end

    test "rejects when mandatory fields are missing without creating records", %{
      secretary_id: secretary_id
    } do
      # Missing phone
      assert {:error, cs_phone} =
               Patients.register_absent_patient(
                 Map.put(@valid_attrs, :phone, ""),
                 secretary_id
               )

      assert errors_on(cs_phone).phone != nil

      # Missing first_name and birthdate
      assert {:error, cs_fields} =
               Patients.register_absent_patient(
                 %{@valid_attrs | first_name: nil, birthdate: nil},
                 secretary_id
               )

      assert errors_on(cs_fields).first_name != nil
      assert errors_on(cs_fields).birthdate != nil

      # Future birthdate
      future_date = Date.add(Date.utc_today(), 1)

      assert {:error, cs_future} =
               Patients.register_absent_patient(
                 %{@valid_attrs | birthdate: future_date},
                 secretary_id
               )

      assert errors_on(cs_future).birthdate != nil

      # Invalid email format
      assert {:error, cs_email} =
               Patients.register_absent_patient(
                 Map.put(@valid_attrs, :email, "correo-invalido"),
                 secretary_id
               )

      assert errors_on(cs_email).email != nil

      # Document outside controlled catalog
      assert {:error, cs_doc} =
               Patients.register_absent_patient(
                 %{@valid_attrs | document_type: "libreta"},
                 secretary_id
               )

      assert errors_on(cs_doc).document_type != nil

      assert Repo.aggregate(Persona, :count) == 0
      assert Repo.aggregate(PatientProfile, :count) == 0
    end

    test "rejects unauthorized actors on registration without partial writes", %{
      admin_id: admin_id,
      professional_id: professional_id,
      inactive_secretary_id: inactive_secretary_id
    } do
      assert {:error, :unauthorized} =
               Patients.register_absent_patient(@valid_attrs, admin_id)

      assert {:error, :unauthorized} =
               Patients.register_absent_patient(@valid_attrs, professional_id)

      assert {:error, :unauthorized} =
               Patients.register_absent_patient(@valid_attrs, inactive_secretary_id)

      assert {:error, :unauthorized} =
               Patients.register_absent_patient(@valid_attrs, 888_888)

      assert Repo.aggregate(Persona, :count) == 0
      assert Repo.aggregate(PatientProfile, :count) == 0
    end
  end

  describe "event constructors" do
    test "validate actor kinds and document references" do
      assert {:error, :invalid_event} =
               Events.persona_searched({:secretary, "secretary:1"}, "dni:12345678")

      assert {:ok, event} = Events.persona_searched({:secretary, "1"}, "dni:12345678")
      assert event.event == "persona_searched"
      assert event.entity_kind == "patient"

      assert {:ok, created} = Events.persona_created({:secretary, "1"}, "dni:12345678")
      assert created.result == "succeeded"
    end
  end

  defp insert_internal_account!(role, "active") do
    %{rows: [[account_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [role]
      )

    account_id
  end

  defp insert_internal_account!(role, "pending_activation") do
    %{rows: [[account_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'pending_activation', NULL, NULL, NULL)
        RETURNING id
        """,
        [role]
      )

    account_id
  end
end
