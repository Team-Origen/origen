defmodule Origen.Patients.PatientAccessMaintenanceTest do
  use Origen.DataCase, async: false

  import Ecto.Query
  import Swoosh.TestAssertions

  alias Origen.PatientAccess.MagicLink
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @assisted_attrs %{
    first_name: "Mateo",
    last_name: "Fernández",
    document_type: "dni",
    document_number: "38.222.333",
    birthdate: ~D[1992-05-15],
    phone: "+5491133334444",
    email: nil
  }

  setup do
    Repo.delete_all(MagicLink)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    secretary_id = insert_internal_account!("secretary", "active")
    professional_id = insert_internal_account!("professional", "active")
    admin_id = insert_internal_account!("administrator", "active")
    inactive_secretary_id = insert_internal_account!("secretary", "pending_activation")

    %{
      secretary_id: secretary_id,
      professional_id: professional_id,
      admin_id: admin_id,
      inactive_secretary_id: inactive_secretary_id
    }
  end

  describe "link_patient_access_email/3" do
    test "C1: successfully links access email to assisted patient and dispatches proof-of-possession magic link",
         %{secretary_id: secretary_id} do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      assert profile.email == nil

      new_email = "mateo.fernandez@example.test"

      assert {:ok, %{patient_profile: updated_profile, outcome: :linked}} =
               Patients.link_patient_access_email(profile.id, new_email, secretary_id)

      assert updated_profile.email == new_email
      assert updated_profile.persona_id == persona.id

      # Assert persona data remains completely intact
      reloaded_persona = Repo.get!(Persona, persona.id)
      assert reloaded_persona.first_name == "Mateo"
      assert reloaded_persona.last_name == "Fernández"
      assert reloaded_persona.document_number == "38222333"

      # Assert magic link email sent for proof of possession
      assert_email_sent(fn email ->
        assert email.to == [{"", new_email}]
        assert email.html_body =~ "/access/verify?token="
      end)

      # Assert audit log entry
      audit_row =
        Repo.one(
          from a in "audit_events",
            where: a.event == "patient_access_email_linked",
            select: %{
              actor_kind: a.actor_kind,
              actor_ref: a.actor_ref,
              entity_ref: a.entity_ref,
              result: a.result
            }
        )

      assert audit_row != nil
      assert audit_row.actor_kind == "secretary"
      assert audit_row.actor_ref == Integer.to_string(secretary_id)
      assert audit_row.entity_ref == "profile:#{profile.id}"
      assert audit_row.result == "succeeded"
    end

    test "allows active professional to link access email", %{
      professional_id: professional_id,
      secretary_id: secretary_id
    } do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      email = "pro.linked@example.test"

      assert {:ok, %{patient_profile: updated, outcome: :linked}} =
               Patients.link_patient_access_email(profile, email, professional_id)

      assert updated.email == email
    end

    test "C3: rejects linking when email is already in use by another patient", %{
      secretary_id: secretary_id
    } do
      # Patient A
      {:ok, %{profile: profile_a}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      existing_email = "titular@example.test"
      {:ok, _} = Patients.link_patient_access_email(profile_a, existing_email, secretary_id)

      # Patient B
      attrs_b = %{@assisted_attrs | document_number: "39.444.555"}
      {:ok, %{profile: profile_b}} = Patients.register_absent_patient(attrs_b, secretary_id)

      assert {:error, :email_already_in_use} =
               Patients.link_patient_access_email(profile_b, existing_email, secretary_id)

      # Ensure B remains without email
      reloaded_b = Repo.get!(PatientProfile, profile_b.id)
      assert reloaded_b.email == nil
    end

    test "C5: rejects linking when patient already has an access email", %{
      secretary_id: secretary_id
    } do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      {:ok, _} = Patients.link_patient_access_email(profile, "first@example.test", secretary_id)

      reloaded = Repo.get!(PatientProfile, profile.id)

      assert {:error, :already_has_access_email} =
               Patients.link_patient_access_email(reloaded, "second@example.test", secretary_id)
    end

    test "C6: denegates linking to administrator or inactive staff", %{
      admin_id: admin_id,
      inactive_secretary_id: inactive_secretary_id,
      secretary_id: secretary_id
    } do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      assert {:error, :unauthorized} =
               Patients.link_patient_access_email(profile, "admin.try@example.test", admin_id)

      assert {:error, :unauthorized} =
               Patients.link_patient_access_email(
                 profile,
                 "inactive.try@example.test",
                 inactive_secretary_id
               )
    end

    test "rejects invalid email formats", %{secretary_id: secretary_id} do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      assert {:error, :invalid_email} =
               Patients.link_patient_access_email(profile, "correo-invalido", secretary_id)

      assert {:error, :invalid_email} =
               Patients.link_patient_access_email(profile, "", secretary_id)
    end

    test "returns :patient_not_found for non-existent id", %{secretary_id: secretary_id} do
      assert {:error, :patient_not_found} =
               Patients.link_patient_access_email(999_999, "valid@example.test", secretary_id)
    end
  end

  describe "replace_patient_access_email/4" do
    test "C2: successfully replaces email, dispatches new link, preserves persona and history", %{
      secretary_id: secretary_id,
      professional_id: professional_id
    } do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      old_email = "viejo@example.test"
      new_email = "nuevo@example.test"
      reason = "Actualización solicitada en consultorio"

      {:ok, _} = Patients.link_patient_access_email(profile, old_email, secretary_id)

      assert_email_sent(fn email ->
        email.to == [{"", old_email}]
      end)

      # Insert a historical appointment to verify preservation
      ct_id = insert_consultation_type!(professional_id)
      start_time = DateTime.utc_now() |> DateTime.add(3600, :second)
      end_time = DateTime.utc_now() |> DateTime.add(5400, :second)

      %{rows: [[appt_id]]} =
        Repo.query!(
          """
          INSERT INTO appointments (
            patient_profile_id, professional_account_id, consultation_type_id,
            start_time, end_time, status,
            snapshot_consultation_type_name, snapshot_duration_minutes, snapshot_exact_price_ars,
            created_at, updated_at
          ) VALUES (
            $1, $2, $3,
            $4, $5, 'confirmed',
            'Consulta General', 30, 10000.00,
            NOW(), NOW()
          ) RETURNING id
          """,
          [profile.id, professional_id, Ecto.UUID.dump!(ct_id), start_time, end_time]
        )

      assert {:ok, %{patient_profile: updated, outcome: :replaced}} =
               Patients.replace_patient_access_email(
                 profile.id,
                 new_email,
                 professional_id,
                 reason
               )

      assert updated.email == new_email
      assert updated.persona_id == persona.id
      assert updated.sessions_invalidated_at != nil

      # Assert appointment is fully preserved and linked to same profile
      %{rows: [[appt_patient_id, appt_status]]} =
        Repo.query!("SELECT patient_profile_id, status FROM appointments WHERE id = $1", [appt_id])

      assert appt_patient_id == profile.id
      assert appt_status == "confirmed"

      # Assert magic link sent to new email
      assert_email_sent(fn email ->
        email.to == [{"", new_email}] and email.html_body =~ "/access/verify?token="
      end)

      # Assert audit log entry
      audit_row =
        Repo.one(
          from a in "audit_events",
            where: a.event == "patient_access_email_replaced",
            select: %{
              actor_kind: a.actor_kind,
              actor_ref: a.actor_ref,
              entity_ref: a.entity_ref,
              result: a.result
            }
        )

      assert audit_row != nil
      assert audit_row.actor_kind == "professional"
      assert audit_row.actor_ref == Integer.to_string(professional_id)
      assert audit_row.entity_ref == "profile:#{profile.id}"
      assert audit_row.result == "succeeded"
    end

    test "C4: invalidates prior unconsumed magic links and marks sessions_invalidated_at", %{
      secretary_id: secretary_id
    } do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      old_email = "activo@example.test"
      new_email = "renovado@example.test"

      {:ok, _} = Patients.link_patient_access_email(profile, old_email, secretary_id)

      # There is an active unconsumed link for old_email
      old_link =
        Repo.one(from m in MagicLink, where: m.email == ^old_email and is_nil(m.consumed_at))

      assert old_link != nil

      t_before_replace = DateTime.utc_now() |> DateTime.add(-1, :second)

      # Replace email
      {:ok, %{patient_profile: _updated}} =
        Patients.replace_patient_access_email(
          profile,
          new_email,
          secretary_id,
          "Reemplazo por pérdida de acceso"
        )

      # 1. Prior magic link for old_email is now consumed/invalidated
      reloaded_old_link = Repo.get!(MagicLink, old_link.id)
      assert reloaded_old_link.consumed_at != nil

      # 2. Session verification before replacement is invalidated
      assert {:error, :session_invalidated} =
               Patients.verify_patient_session(new_email, t_before_replace)

      # 3. Session verification after replacement is valid
      t_after_replace = DateTime.utc_now() |> DateTime.add(1, :second)
      assert {:ok, _} = Patients.verify_patient_session(new_email, t_after_replace)
    end

    test "rejects replacement if reason is missing or whitespace", %{secretary_id: secretary_id} do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      {:ok, _} = Patients.link_patient_access_email(profile, "base@example.test", secretary_id)

      assert {:error, :reason_required} =
               Patients.replace_patient_access_email(
                 profile,
                 "new@example.test",
                 secretary_id,
                 ""
               )

      assert {:error, :reason_required} =
               Patients.replace_patient_access_email(
                 profile,
                 "new@example.test",
                 secretary_id,
                 "   "
               )
    end

    test "rejects replacement with the same current email", %{secretary_id: secretary_id} do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      {:ok, _} = Patients.link_patient_access_email(profile, "same@example.test", secretary_id)

      assert {:error, :same_email} =
               Patients.replace_patient_access_email(
                 profile,
                 " SAME@EXAMPLE.TEST ",
                 secretary_id,
                 "Motivo válido"
               )
    end

    test "rejects replacement when email is occupied by another patient", %{
      secretary_id: secretary_id
    } do
      # Patient A
      {:ok, %{profile: profile_a}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      {:ok, _} = Patients.link_patient_access_email(profile_a, "owner@example.test", secretary_id)

      # Patient B
      attrs_b = %{@assisted_attrs | document_number: "40.999.888"}
      {:ok, %{profile: profile_b}} = Patients.register_absent_patient(attrs_b, secretary_id)
      {:ok, _} = Patients.link_patient_access_email(profile_b, "b@example.test", secretary_id)

      assert {:error, :email_already_in_use} =
               Patients.replace_patient_access_email(
                 profile_b,
                 "owner@example.test",
                 secretary_id,
                 "Motivo de prueba"
               )
    end

    test "denegates replacement to administrator", %{
      admin_id: admin_id,
      secretary_id: secretary_id
    } do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      {:ok, _} = Patients.link_patient_access_email(profile, "base@example.test", secretary_id)

      assert {:error, :unauthorized} =
               Patients.replace_patient_access_email(
                 profile,
                 "admin.fail@example.test",
                 admin_id,
                 "Motivo"
               )
    end
  end

  describe "verify_patient_session/2" do
    test "validates session when sessions_invalidated_at is nil", %{secretary_id: secretary_id} do
      {:ok, %{profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_id)

      {:ok, _} = Patients.link_patient_access_email(profile, "plain@example.test", secretary_id)

      assert {:ok, %PatientProfile{}} =
               Patients.verify_patient_session("plain@example.test", nil)
    end

    test "returns :unauthenticated for nil or empty email" do
      assert {:error, :unauthenticated} = Patients.verify_patient_session(nil, DateTime.utc_now())
      assert {:error, :unauthenticated} = Patients.verify_patient_session("", DateTime.utc_now())
    end

    test "returns :patient_not_found when email does not exist" do
      assert {:error, :patient_not_found} =
               Patients.verify_patient_session("nonexistent@example.test", DateTime.utc_now())
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

  defp insert_consultation_type!(prof_id) do
    ct_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types (
        id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at
      ) VALUES (
        $1, $2, 'Consulta General', 15000.00, '#112233', 1, 'active', NOW(), NOW()
      )
      """,
      [Ecto.UUID.dump!(ct_id), prof_id]
    )

    ct_id
  end
end
