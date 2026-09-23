defmodule Origen.Patients.SecretarySearchTest do
  use Origen.DataCase, async: false

  import Ecto.Query

  alias Origen.Audit.Events
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @secretary_account_id 4242

  @valid_attrs %{
    first_name: "Ana",
    last_name: "Torres",
    document_type: "dni",
    document_number: "37.111.222",
    birthdate: ~D[1990-03-05],
    phone: "+5491155554444",
    gender: "femenino"
  }

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)
    :ok
  end

  describe "search_persona_by_document/3" do
    test "finds an existing persona with its linked profile and normalizes the document number" do
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
               Patients.search_persona_by_document(
                 "dni",
                 " 35.987.654 ",
                 @secretary_account_id
               )

      assert result.persona.id == persona.id
      assert result.persona.document_number == "35987654"
      assert result.profile.id == profile.id
      assert result.profile.state == "completed"
    end

    test "returns {:ok, nil} when the persona does not exist" do
      assert {:ok, nil} =
               Patients.search_persona_by_document(
                 "passport",
                 "ZZ999999",
                 @secretary_account_id
               )
    end

    test "returns a nil profile when the persona exists without a linked profile" do
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
               Patients.search_persona_by_document("dni", "30000099", @secretary_account_id)

      assert found.id == persona.id
    end

    test "audits every search in public.audit_events with the secretary as actor" do
      Patients.search_persona_by_document("dni", "35000001", @secretary_account_id)

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

      # The actor reference keeps the plain account id because the Events sanitizer
      # rejects references containing "secret" (any "secretary:<id>" prefix).
      assert search_event.actor_kind == "secretary"
      assert search_event.actor_ref == Integer.to_string(@secretary_account_id)
      assert search_event.entity_kind == "patient"
      assert search_event.entity_ref == "dni:35000001"
      assert search_event.result == "succeeded"
    end
  end

  describe "register_or_reuse_assisted_persona/2 - creation path" do
    test "creates persona and linked profile in pending_completion with placeholder email" do
      assert {:ok, %{persona: persona, profile: profile, outcome: :created}} =
               Patients.register_or_reuse_assisted_persona(@valid_attrs, @secretary_account_id)

      assert persona.document_number == "37111222"
      assert persona.first_name == "Ana"

      assert profile.persona_id == persona.id
      assert profile.state == "pending_completion"
      assert profile.phone == "+5491155554444"
      assert profile.phone_verified == false
      assert profile.email == "asistido-persona-#{persona.id}@origen.local"
    end

    test "uses the provided email instead of the placeholder when present" do
      attrs = Map.put(@valid_attrs, :email, "  Asistida@Example.Test ")

      assert {:ok, %{profile: profile}} =
               Patients.register_or_reuse_assisted_persona(attrs, @secretary_account_id)

      assert profile.email == "asistida@example.test"
    end

    test "audits the creation with the searched document as entity reference" do
      Patients.register_or_reuse_assisted_persona(@valid_attrs, @secretary_account_id)

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
      assert created_event.actor_ref == Integer.to_string(@secretary_account_id)
      assert created_event.entity_kind == "patient"
      assert created_event.entity_ref == "dni:37111222"
      assert created_event.result == "succeeded"
    end
  end

  describe "register_or_reuse_assisted_persona/2 - reuse path" do
    test "reuses an existing persona with profile without duplicating or overwriting identity" do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.complete_profile("reuso@example.test", %{
          first_name: "Original",
          last_name: "Usuario",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1985-01-01]
        })

      tampered_attrs = %{
        @valid_attrs
        | document_number: "35987654",
          first_name: "Nombre",
          last_name: "Distinto"
      }

      assert {:ok, %{persona: reused_persona, profile: reused_profile, outcome: :reused}} =
               Patients.register_or_reuse_assisted_persona(tampered_attrs, @secretary_account_id)

      assert reused_persona.id == persona.id
      assert reused_persona.first_name == "Original"
      assert reused_persona.last_name == "Usuario"

      assert reused_profile.id == profile.id
      assert reused_profile.state == "completed"

      assert Repo.aggregate(Persona, :count) == 1
      assert Repo.aggregate(PatientProfile, :count) == 1
    end

    test "reuses a persona without profile by creating a pending_completion profile" do
      {:ok, persona} =
        %Persona{}
        |> Persona.changeset(%{
          first_name: "Solo",
          last_name: "Persona",
          document_type: "dni",
          document_number: "31555777",
          birthdate: ~D[1970-10-10]
        })
        |> Repo.insert()

      attrs = %{@valid_attrs | document_number: "31.555.777"}

      assert {:ok, %{persona: reused_persona, profile: profile, outcome: :reused}} =
               Patients.register_or_reuse_assisted_persona(attrs, @secretary_account_id)

      assert reused_persona.id == persona.id
      assert reused_persona.first_name == "Solo"

      assert profile.persona_id == persona.id
      assert profile.state == "pending_completion"
      assert profile.email == "asistido-persona-#{persona.id}@origen.local"
      assert profile.phone == "+5491155554444"
    end

    test "audits the reuse without overwriting identity data" do
      {:ok, _} =
        Patients.complete_profile("reuso_audit@example.test", %{
          first_name: "Original",
          last_name: "Usuario",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1985-01-01]
        })

      Patients.register_or_reuse_assisted_persona(
        %{@valid_attrs | document_number: "35987654"},
        @secretary_account_id
      )

      [reused_event] =
        Repo.all(
          from a in "audit_events",
            where: a.event == "persona_reused",
            select: %{
              actor_kind: a.actor_kind,
              actor_ref: a.actor_ref,
              entity_kind: a.entity_kind,
              entity_ref: a.entity_ref,
              result: a.result
            }
        )

      assert reused_event.actor_kind == "secretary"
      assert reused_event.actor_ref == Integer.to_string(@secretary_account_id)
      assert reused_event.entity_kind == "patient"
      assert reused_event.entity_ref == "dni:35987654"
      assert reused_event.result == "succeeded"
    end
  end

  describe "register_or_reuse_assisted_persona/2 - validation" do
    test "returns the changeset error without persisting when attributes are invalid" do
      assert {:error, changeset} =
               Patients.register_or_reuse_assisted_persona(
                 %{@valid_attrs | first_name: nil, birthdate: nil},
                 @secretary_account_id
               )

      assert errors_on(changeset).first_name != nil
      assert errors_on(changeset).birthdate != nil
      assert Repo.aggregate(Persona, :count) == 0
      assert Repo.aggregate(PatientProfile, :count) == 0
    end

    test "rejects documents outside the controlled catalog" do
      assert {:error, changeset} =
               Patients.register_or_reuse_assisted_persona(
                 %{@valid_attrs | document_type: "libreta"},
                 @secretary_account_id
               )

      assert errors_on(changeset).document_type != nil
    end
  end

  test "event constructors validate actor kinds and document references" do
    assert {:error, :invalid_event} =
             Events.persona_searched({:secretary, "secretary:1"}, "dni:12345678")

    assert {:ok, event} = Events.persona_searched({:secretary, "1"}, "dni:12345678")
    assert event.event == "persona_searched"
    assert event.entity_kind == "patient"

    assert {:ok, created} = Events.persona_created({:secretary, "1"}, "dni:12345678")
    assert created.result == "succeeded"

    assert {:ok, reused} = Events.persona_reused({:secretary, "1"}, "dni:12345678")
    assert reused.result == "succeeded"
  end
end
