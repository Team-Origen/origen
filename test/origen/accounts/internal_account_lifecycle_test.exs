defmodule Origen.Accounts.InternalAccountLifecycleTest do
  @moduledoc """
  Domain-level verification for Issue #373 (contract #372): the internal
  account lifecycle for Professional and Secretary accounts.

  Covers scenarios C1-C11 of `docs/sprints/contracts/372-ciclo-cuentas-internas.md`
  that belong to the backend domain: sanitized listing, email editing with
  case-insensitive uniqueness, deactivation with immediate access cut, session
  and invitation revocation, appointment preservation, the future affected
  appointments count, reactivation without restoring cancelled appointments,
  and strict default-deny for every other actor or target.
  """

  use Origen.DataCase

  alias Origen.Accounts
  alias Origen.Booking.Lifecycle
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo
  alias Origen.Sessions

  @keyring %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  }
  @fixed_now ~U[2026-12-20 12:00:00Z]

  # ---------------------------------------------------------------- helpers

  defp create_active_account(role, attrs \\ []) do
    email =
      Keyword.get_lazy(attrs, :email, fn ->
        "#{role}_#{System.unique_integer([:positive])}@clinicaorigen.com"
      end)

    password = "SuperSecurePassword123!"
    password_hash = Credentials.hash_password(password)
    seed = NimbleTOTP.secret()
    {:ok, totp_secret} = Credentials.encrypt_seed(seed, @keyring)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', $3, $4, clock_timestamp())
        RETURNING id
        """,
        [email, Atom.to_string(role), password_hash, totp_secret]
      )

    %{id: id, email: email, role: role, password: password, seed: seed}
  end

  defp insert_pending_account(role) do
    email = "#{role}_pending_#{System.unique_integer([:positive])}@clinicaorigen.com"

    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO internal_accounts (email, role, state) VALUES ($1, $2, 'pending_activation') RETURNING id",
        [email, Atom.to_string(role)]
      )

    %{id: id, email: email, role: role}
  end

  defp deactivate_account!(account_id) do
    Repo.query!(
      "UPDATE internal_accounts SET state = 'deactivated', updated_at = clock_timestamp() WHERE id = $1",
      [account_id]
    )
  end

  defp insert_patient_profile!(tag) do
    unique = System.unique_integer([:positive])

    %{rows: [[persona_id]]} =
      Repo.query!(
        """
        INSERT INTO personas (first_name, last_name, document_type, document_number, birthdate)
        VALUES ('Nombre', 'Apellido', 'dni', $1, '1990-01-01')
        RETURNING id
        """,
        [Integer.to_string(unique)]
      )

    %{rows: [[profile_id]]} =
      Repo.query!(
        """
        INSERT INTO patient_profiles (persona_id, email, state, phone_verified)
        VALUES ($1, $2, 'completed', true)
        RETURNING id
        """,
        [persona_id, "#{tag}_#{unique}@example.test"]
      )

    profile_id
  end

  defp insert_consultation_type!(owner_account_id, tag) do
    type_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, 100.00, '#123456', 1, 'active')
      """,
      [Ecto.UUID.dump!(type_id), owner_account_id, "Consulta #{tag}"]
    )

    type_id
  end

  defp insert_appointment!(professional_id, patient_id, type_id, start_time, status) do
    {:ok, %{id: appointment_id}} =
      Origen.Booking.persist_appointment(
        %{
          patient_profile_id: patient_id,
          professional_account_id: professional_id,
          consultation_type_id: type_id,
          start_time: start_time,
          status: status
        },
        %{
          name: "Consulta",
          duration_minutes: 30,
          exact_price_ars: Decimal.new("100.00")
        }
      )

    appointment_id
  end

  defp appointment_status(appointment_id) do
    %{rows: [[status]]} =
      Repo.query!("SELECT status FROM appointments WHERE id = $1", [appointment_id])

    status
  end

  defp audit_events(event) do
    Repo.query!(
      "SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result FROM audit_events WHERE event = $1",
      [event]
    ).rows
  end

  defp admin_session!(admin) do
    {:ok, %{session: session}} = Sessions.create_session(admin.id)
    session
  end

  # ------------------------------------------------------- C4/C5 deactivation

  describe "deactivate_internal_account/3 (C4/C5/C6)" do
    setup do
      admin = create_active_account(:administrator)
      professional = create_active_account(:professional)
      %{admin: admin, professional: professional}
    end

    test "deactivating a professional preserves history, cuts access, and returns the exact affected count",
         %{admin: admin, professional: professional} do
      patient_id = insert_patient_profile!("c4")
      type_id = insert_consultation_type!(professional.id, "c4")

      confirmed_a =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 09:00:00Z],
          "confirmed"
        )

      confirmed_b =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 10:00:00Z],
          "confirmed"
        )

      requested =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 11:00:00Z],
          "requested"
        )

      cancelled =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 12:00:00Z],
          "cancelled"
        )

      attended =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-19 09:00:00Z],
          "attended"
        )

      {:ok, %{token: token, session: session}} = Sessions.create_session(professional.id)

      assert {:ok, result} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      assert result.state == :deactivated
      assert result.id == professional.id
      assert result.email == professional.email
      assert result.role == :professional
      assert result.future_affected_appointments_count == 3
      assert result.account.state == :deactivated
      assert result.account.future_affected_appointments_count == 3

      # State changed while credentials and identity are preserved for reactivation
      assert [%{rows: [[state, password_hash, totp_secret, activated_at]]}] = [
               Repo.query!(
                 "SELECT state, password_hash, totp_secret, activated_at FROM internal_accounts WHERE id = $1",
                 [professional.id]
               )
             ]

      assert state == "deactivated"
      assert is_binary(password_hash)
      assert is_binary(totp_secret)
      assert not is_nil(activated_at)

      # Sessions are immediately revoked (C6)
      assert {:error, :unauthenticated} = Sessions.fetch_session(token)
      assert {:error, :unauthenticated} = Sessions.touch_session(token)

      assert {:error, :unauthenticated} =
               Sessions.revalidate_principal(session.session_id, professional.id)

      # No appointment is cancelled or modified automatically
      assert appointment_status(confirmed_a) == "confirmed"
      assert appointment_status(confirmed_b) == "confirmed"
      assert appointment_status(requested) == "requested"
      assert appointment_status(cancelled) == "cancelled"
      assert appointment_status(attended) == "attended"

      # Append-only audit records the administrative action
      assert audit_events("internal_account_deactivated") == [
               [
                 "administrator",
                 to_string(admin.id),
                 "internal_account_deactivated",
                 "account",
                 to_string(professional.id),
                 "succeeded"
               ]
             ]
    end

    test "deactivating a secretary returns zero affected appointments and revokes her session", %{
      admin: admin
    } do
      secretary = create_active_account(:secretary)
      {:ok, %{token: token}} = Sessions.create_session(secretary.id)

      assert {:ok, result} =
               Accounts.deactivate_internal_account(admin.id, secretary.id, now: @fixed_now)

      assert result.role == :secretary
      assert result.state == :deactivated
      assert result.future_affected_appointments_count == 0

      assert {:error, :unauthenticated} = Sessions.fetch_session(token)
      assert audit_events("internal_account_deactivated") != []
    end

    test "deactivation revokes pending invitations without consuming them", %{admin: admin} do
      assert {:ok, invitation} =
               Accounts.create_and_invite_internal_account(
                 admin.id,
                 %{email: "pending.deactivate@clinicaorigen.com", role: :professional},
                 verifier_key: String.duplicate("v", 32)
               )

      assert {:ok, result} =
               Accounts.deactivate_internal_account(admin.id, invitation.account_id,
                 now: @fixed_now
               )

      assert result.state == :deactivated
      assert result.future_affected_appointments_count == 0

      assert [%{rows: [[nil, revoked_at]]}] = [
               Repo.query!(
                 "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1",
                 [invitation.invitation_id]
               )
             ]

      assert not is_nil(revoked_at)
    end

    test "deactivating a pending_activation staff account keeps credentials NULL", %{
      admin: admin
    } do
      pending = insert_pending_account(:secretary)

      assert {:ok, result} =
               Accounts.deactivate_internal_account(admin.id, pending.id, now: @fixed_now)

      assert result.state == :deactivated

      assert Repo.query!(
               "SELECT password_hash, totp_secret, activated_at FROM internal_accounts WHERE id = $1",
               [pending.id]
             ).rows == [[nil, nil, nil]]
    end

    test "deactivating an already deactivated account is denied without side effects", %{
      admin: admin,
      professional: professional
    } do
      assert {:ok, _} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      initial_audits = length(audit_events("internal_account_deactivated"))

      assert {:error, :unauthorized} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      assert Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [
               professional.id
             ]).rows == [["deactivated"]]

      assert length(audit_events("internal_account_deactivated")) == initial_audits
    end
  end

  # ----------------------------------------------------------- C6 access cut

  describe "post-deactivation access cut (C6)" do
    test "a deactivated professional cannot authenticate again" do
      admin = create_active_account(:administrator)
      professional = create_active_account(:professional)

      assert {:ok, _} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      code = NimbleTOTP.verification_code(professional.seed)

      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(
                 professional.email,
                 professional.password,
                 code,
                 keyring: @keyring
               )
    end
  end

  # -------------------------------------------------- C7 secretary follow-up

  describe "secretary follow-up on a deactivated professional (C7)" do
    test "secretary can still cancel a future confirmed appointment with a reason" do
      admin = create_active_account(:administrator)
      secretary = create_active_account(:secretary)
      professional = create_active_account(:professional)

      patient_id = insert_patient_profile!("c7")
      type_id = insert_consultation_type!(professional.id, "c7")

      future_confirmed =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 09:00:00Z],
          "confirmed"
        )

      future_requested =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 10:00:00Z],
          "requested"
        )

      assert {:ok, _} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      {:ok, %{session: session}} = Sessions.create_session(secretary.id)

      assert {:ok, cancelled} =
               Lifecycle.cancel(
                 %{session_id: session.session_id, account_id: secretary.id},
                 future_confirmed,
                 %{reason: "profesional de baja administrativa"}
               )

      assert cancelled.status == "cancelled"
      assert appointment_status(future_confirmed) == "cancelled"
      assert appointment_status(future_requested) == "requested"
    end
  end

  # ------------------------------------------------------------ C8 reactivate

  describe "reactivate_internal_account/3 (C8)" do
    setup do
      admin = create_active_account(:administrator)
      %{admin: admin}
    end

    test "reactivating an activated professional restores active without restoring cancelled appointments",
         %{admin: admin} do
      professional = create_active_account(:professional)
      patient_id = insert_patient_profile!("c8")
      type_id = insert_consultation_type!(professional.id, "c8")

      cancelled =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 09:00:00Z],
          "cancelled"
        )

      confirmed =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 10:00:00Z],
          "confirmed"
        )

      requested =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 11:00:00Z],
          "requested"
        )

      assert {:ok, deactivated} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      assert deactivated.state == :deactivated

      assert {:ok, result} =
               Accounts.reactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      assert result.state == :active
      assert result.role == :professional
      assert result.account.state == :active
      assert result.future_affected_appointments_count == 2

      assert appointment_status(cancelled) == "cancelled"
      assert appointment_status(confirmed) == "confirmed"
      assert appointment_status(requested) == "requested"

      assert audit_events("internal_account_reactivated") == [
               [
                 "administrator",
                 to_string(admin.id),
                 "internal_account_reactivated",
                 "account",
                 to_string(professional.id),
                 "succeeded"
               ]
             ]

      # The restored professional can open a session again
      assert {:ok, %{session: _}} = Sessions.create_session(professional.id)
    end

    test "reactivating a deactivated pending_activation account returns it to pending_activation",
         %{admin: admin} do
      pending = insert_pending_account(:secretary)

      assert {:ok, deactivated} =
               Accounts.deactivate_internal_account(admin.id, pending.id, now: @fixed_now)

      assert deactivated.state == :deactivated

      assert {:ok, result} = Accounts.reactivate_internal_account(admin.id, pending.id)

      assert result.state == :pending_activation
      assert result.account.state == :pending_activation

      assert Repo.query!(
               "SELECT state, password_hash, totp_secret, activated_at FROM internal_accounts WHERE id = $1",
               [pending.id]
             ).rows == [["pending_activation", nil, nil, nil]]
    end

    test "reactivating a deactivated pending_activation account allows reissuing its invitation (C8 / §2.3.D.1)",
         %{admin: admin} do
      verifier_key = String.duplicate("v", 32)

      assert {:ok, initial_inv} =
               Accounts.create_and_invite_internal_account(
                 admin.id,
                 %{email: "pending.reissue@clinicaorigen.com", role: :professional},
                 verifier_key: verifier_key
               )

      assert {:ok, deactivated} =
               Accounts.deactivate_internal_account(admin.id, initial_inv.account_id,
                 now: @fixed_now
               )

      assert deactivated.state == :deactivated

      assert {:ok, reactivated} =
               Accounts.reactivate_internal_account(admin.id, initial_inv.account_id,
                 now: @fixed_now
               )

      assert reactivated.state == :pending_activation

      assert {:ok, reissued} =
               Accounts.reissue_internal_invitation(
                 admin.id,
                 initial_inv.account_id,
                 verifier_key: verifier_key
               )

      assert reissued.account_id == initial_inv.account_id
      assert reissued.invitation_id != initial_inv.invitation_id
    end

    test "database constraints reject invalid states and partial credentials on deactivated rows (Req 1)" do
      assert_raise Postgrex.Error, ~r/internal_accounts_state_check/, fn ->
        Repo.query!(
          "INSERT INTO internal_accounts (email, role, state) VALUES ('invalid_state@clinicaorigen.com', 'professional', 'suspended')"
        )
      end

      assert_raise Postgrex.Error, ~r/internal_accounts_state_fields_check/, fn ->
        Repo.query!(
          "INSERT INTO internal_accounts (email, role, state, password_hash) VALUES ('partial_creds@clinicaorigen.com', 'professional', 'deactivated', 'hash_only')"
        )
      end
    end

    test "reactivating a non-deactivated account is denied without mutations", %{admin: admin} do
      professional = create_active_account(:professional)
      pending = insert_pending_account(:professional)

      for target <- [professional.id, pending.id] do
        assert {:error, :unauthorized} = Accounts.reactivate_internal_account(admin.id, target)
      end

      assert Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [
               professional.id
             ]).rows == [["active"]]

      assert Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [
               pending.id
             ]).rows == [["pending_activation"]]

      assert audit_events("internal_account_reactivated") == []
    end
  end

  # -------------------------------------------------------------- C2/C3 edit

  describe "update_internal_account/4 (C2/C3)" do
    setup do
      admin = create_active_account(:administrator)
      %{admin: admin}
    end

    test "updates the email preserving identity, appointments, and history", %{admin: admin} do
      professional = create_active_account(:professional)
      patient_id = insert_patient_profile!("c2")
      type_id = insert_consultation_type!(professional.id, "c2")

      appointment_id =
        insert_appointment!(
          professional.id,
          patient_id,
          type_id,
          ~U[2026-12-21 09:00:00Z],
          "confirmed"
        )

      Repo.query!(
        """
        INSERT INTO professional_patient_relationships
          (professional_account_id, patient_profile_id, first_appointment_id)
        VALUES ($1, $2, $3)
        """,
        [professional.id, patient_id, appointment_id]
      )

      assert {:ok, result} =
               Accounts.update_internal_account(
                 admin.id,
                 professional.id,
                 %{
                   email: "  Doctor.Nuevo@ClinicaOrigen.com  "
                 },
                 now: @fixed_now
               )

      assert result.id == professional.id
      assert result.email == "doctor.nuevo@clinicaorigen.com"
      assert result.role == :professional
      assert result.state == :active
      assert result.future_affected_appointments_count == 1

      assert Repo.query!(
               "SELECT id, email, role, state FROM internal_accounts WHERE id = $1",
               [professional.id]
             ).rows == [
               [professional.id, "doctor.nuevo@clinicaorigen.com", "professional", "active"]
             ]

      assert appointment_status(appointment_id) == "confirmed"

      assert Repo.query!(
               "SELECT count(*) FROM professional_patient_relationships WHERE professional_account_id = $1",
               [professional.id]
             ).rows == [[1]]

      assert audit_events("internal_account_updated") == [
               [
                 "administrator",
                 to_string(admin.id),
                 "internal_account_updated",
                 "account",
                 to_string(professional.id),
                 "succeeded"
               ]
             ]
    end

    test "rejects a duplicate email case-insensitively without mutations or audits", %{
      admin: admin
    } do
      professional = create_active_account(:professional)
      other = create_active_account(:secretary)

      assert {:error, :email_taken} =
               Accounts.update_internal_account(admin.id, other.id, %{
                 email: String.upcase(professional.email)
               })

      assert {:error, :email_taken} =
               Accounts.update_internal_account(admin.id, other.id, %{email: professional.email})

      assert Repo.query!("SELECT email FROM internal_accounts WHERE id = $1", [
               other.id
             ]).rows == [[other.email]]

      assert audit_events("internal_account_updated") == []
    end

    test "rejects an invalid or missing email without mutations or audits", %{admin: admin} do
      professional = create_active_account(:professional)

      for bad_email <- ["", "   ", "not-an-email", "a b@c.com", "missing-at.com", nil] do
        assert {:error, :invalid_email} =
                 Accounts.update_internal_account(admin.id, professional.id, %{email: bad_email})
      end

      assert {:error, :invalid_email} =
               Accounts.update_internal_account(admin.id, professional.id, %{})

      assert Repo.query!("SELECT email FROM internal_accounts WHERE id = $1", [
               professional.id
             ]).rows == [[professional.email]]

      assert audit_events("internal_account_updated") == []
    end

    test "supports string-keyed attrs and the update_staff_account_email/3 alias", %{
      admin: admin
    } do
      professional = create_active_account(:professional)

      assert {:ok, result} =
               Accounts.update_staff_account_email(admin.id, professional.id, %{
                 "email" => "Alias.Email@ClinicaOrigen.com"
               })

      assert result.email == "alias.email@clinicaorigen.com"
    end
  end

  # ---------------------------------------------------------------- listing

  describe "list_internal_accounts/2" do
    test "returns a sanitized administrative projection of staff accounts only" do
      admin = create_active_account(:administrator)
      professional = create_active_account(:professional)
      secretary = create_active_account(:secretary)
      pending = insert_pending_account(:professional)

      patient_id = insert_patient_profile!("list")
      type_id = insert_consultation_type!(professional.id, "list")

      insert_appointment!(
        professional.id,
        patient_id,
        type_id,
        ~U[2026-12-21 09:00:00Z],
        "confirmed"
      )

      insert_appointment!(
        professional.id,
        patient_id,
        type_id,
        ~U[2026-12-21 10:00:00Z],
        "requested"
      )

      assert {:ok, accounts} = Accounts.list_internal_accounts(admin.id, now: @fixed_now)

      staff_ids = Enum.map(accounts, & &1.id)
      assert professional.id in staff_ids
      assert secretary.id in staff_ids
      assert pending.id in staff_ids
      refute admin.id in staff_ids
      assert staff_ids == Enum.sort(staff_ids)

      professional_entry = Enum.find(accounts, &(&1.id == professional.id))

      assert professional_entry.role == :professional
      assert professional_entry.state == :active
      assert professional_entry.email == professional.email
      assert professional_entry.future_affected_appointments_count == 2
      assert %DateTime{} = professional_entry.activated_at
      assert %DateTime{} = professional_entry.created_at
      assert %DateTime{} = professional_entry.updated_at

      assert Map.keys(professional_entry) |> Enum.sort() ==
               Enum.sort([
                 :id,
                 :email,
                 :role,
                 :state,
                 :activated_at,
                 :created_at,
                 :updated_at,
                 :future_affected_appointments_count
               ])

      for account <- accounts do
        dump = inspect(account)
        refute dump =~ "password_hash"
        refute dump =~ "totp"
      end

      secretary_entry = Enum.find(accounts, &(&1.id == secretary.id))
      assert secretary_entry.future_affected_appointments_count == 0
    end

    test "accepts a session principal and an id map as actor" do
      admin = create_active_account(:administrator)
      professional = insert_pending_account(:professional)
      session = admin_session!(admin)

      assert {:ok, accounts} =
               Accounts.list_internal_accounts(%{
                 session_id: session.session_id,
                 account_id: admin.id
               })

      assert [%{id: id}] = accounts
      assert id == professional.id

      assert {:ok, ^accounts} = Accounts.list_internal_accounts(%{id: admin.id})
      assert {:ok, ^accounts} = Accounts.list_internal_accounts(%{"id" => admin.id})
    end

    test "deactivated staff accounts appear with their credential timestamps preserved" do
      admin = create_active_account(:administrator)
      professional = create_active_account(:professional)

      assert {:ok, _} =
               Accounts.deactivate_internal_account(admin.id, professional.id, now: @fixed_now)

      assert {:ok, accounts} = Accounts.list_internal_accounts(admin.id, now: @fixed_now)

      entry = Enum.find(accounts, &(&1.id == professional.id))
      assert entry.state == :deactivated
      assert %DateTime{} = entry.activated_at
    end
  end

  # ------------------------------------------------- C9/C10 default-deny

  describe "default-deny for non-administrator actors (C9)" do
    setup do
      admin = create_active_account(:administrator)
      professional = create_active_account(:professional)
      secretary = create_active_account(:secretary)
      pending_admin = insert_pending_account(:administrator)

      %{
        admin: admin,
        professional: professional,
        secretary: secretary,
        pending_admin: pending_admin
      }
    end

    test "no non-administrator actor can list, edit, deactivate, or reactivate", ctx do
      unauthorized_actors = [
        ctx.professional.id,
        ctx.secretary.id,
        ctx.pending_admin.id,
        -1,
        nil,
        "not-an-actor"
      ]

      for actor <- unauthorized_actors do
        assert {:error, :unauthorized} = Accounts.list_internal_accounts(actor)

        assert {:error, :unauthorized} =
                 Accounts.update_internal_account(actor, ctx.professional.id, %{
                   email: "hijack@clinicaorigen.com"
                 })

        assert {:error, :unauthorized} =
                 Accounts.deactivate_internal_account(actor, ctx.professional.id, now: @fixed_now)

        assert {:error, :unauthorized} =
                 Accounts.reactivate_internal_account(actor, ctx.professional.id)
      end

      # An expired or stale session principal is rejected too
      assert {:error, :unauthorized} =
               Accounts.list_internal_accounts(%{session_id: -1, account_id: ctx.admin.id})

      # Zero mutations and zero audit events occurred
      assert Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [
               ctx.professional.id
             ]).rows == [["active"]]

      assert audit_events("internal_account_updated") == []
      assert audit_events("internal_account_deactivated") == []
      assert audit_events("internal_account_reactivated") == []
    end

    test "administrator targets are always rejected (C10)", ctx do
      other_admin = create_active_account(:administrator)

      for target <- [ctx.admin.id, other_admin.id] do
        assert {:error, :unauthorized} =
                 Accounts.update_internal_account(ctx.admin.id, target, %{
                   email: "mutated@clinicaorigen.com"
                 })

        assert {:error, :unauthorized} =
                 Accounts.deactivate_internal_account(ctx.admin.id, target, now: @fixed_now)

        assert {:error, :unauthorized} =
                 Accounts.reactivate_internal_account(ctx.admin.id, target)
      end

      assert Repo.query!(
               "SELECT email, state FROM internal_accounts WHERE id IN ($1, $2) ORDER BY id",
               [ctx.admin.id, other_admin.id]
             ).rows == [
               [ctx.admin.email, "active"],
               [other_admin.email, "active"]
             ]

      assert audit_events("internal_account_updated") == []
      assert audit_events("internal_account_deactivated") == []
      assert audit_events("internal_account_reactivated") == []
    end

    test "missing targets are rejected without mutations", ctx do
      assert {:error, :unauthorized} =
               Accounts.update_internal_account(ctx.admin.id, -1, %{email: "x@y.com"})

      assert {:error, :unauthorized} =
               Accounts.deactivate_internal_account(ctx.admin.id, -1, now: @fixed_now)

      assert {:error, :unauthorized} = Accounts.reactivate_internal_account(ctx.admin.id, -1)
    end

    test "an active administrator gains no operational authority from this lifecycle (C11)" do
      admin = create_active_account(:administrator)
      session = admin_session!(admin)
      principal = %{session_id: session.session_id, account_id: admin.id}

      assert {:error, :unauthorized} = Lifecycle.history(principal)
      assert {:error, :unauthorized} = Lifecycle.cancel(principal, 1, %{reason: "x"})
    end
  end

  # ------------------------------------------------- deactivated state rows

  describe "deactivated state persistence" do
    test "an activated account keeps its credentials when deactivated directly at the database level" do
      admin = create_active_account(:administrator)

      deactivate_account!(admin.id)

      assert Repo.query!("SELECT state, password_hash FROM internal_accounts WHERE id = $1", [
               admin.id
             ]).rows == [["deactivated", admin_password_hash()]]
    end
  end

  defp admin_password_hash do
    %{rows: [[hash]]} =
      Repo.query!(
        "SELECT password_hash FROM internal_accounts WHERE role = 'administrator' LIMIT 1"
      )

    hash
  end
end
