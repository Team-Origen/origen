defmodule Origen.AccountsTest do
  use Origen.DataCase

  alias Origen.Accounts
  alias Origen.Audit.Events
  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.{Credentials, Verifier}
  alias Origen.Repo
  alias Origen.Sessions

  @default_keyring %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  }
  @verifier_key String.duplicate("v", 32)

  defp create_active_account(attrs \\ %{}) do
    email =
      Map.get(attrs, :email, "admin_#{System.unique_integer([:positive])}@clinicaorigen.com")

    role = Map.get(attrs, :role, "administrator")
    password = Map.get(attrs, :password, "SuperSecurePassword123!")
    password_hash = Credentials.hash_password(password)
    seed = Map.get(attrs, :seed, NimbleTOTP.secret())
    {:ok, totp_secret} = Credentials.encrypt_seed(seed, @default_keyring)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', $3, $4, clock_timestamp())
        RETURNING id
        """,
        [email, role, password_hash, totp_secret]
      )

    %{
      id: id,
      email: email,
      role: role,
      password: password,
      seed: seed
    }
  end

  describe "authenticate_internal_account/4" do
    test "authenticates an active account with email, password, and valid TOTP" do
      account = create_active_account()
      code = NimbleTOTP.verification_code(account.seed)

      assert {:ok, result} =
               Accounts.authenticate_internal_account(
                 account.email,
                 account.password,
                 code,
                 keyring: @default_keyring
               )

      assert result.account.id == account.id
      assert result.account.email == account.email
      assert result.account.role == account.role
      assert is_binary(result.token)
      assert result.session.account_id == account.id

      # Session is immediately usable in Sessions context
      assert {:ok, session_data} = Sessions.fetch_session(result.token)
      assert session_data.account_id == account.id

      # Audit event was persisted
      %{rows: [[event, result_str, actor_kind, entity_kind, entity_ref]]} =
        Repo.query!(
          "SELECT event, result, actor_kind, entity_kind, entity_ref FROM audit_events WHERE event = 'internal_login' ORDER BY id DESC LIMIT 1"
        )

      assert event == "internal_login"
      assert result_str == "succeeded"
      assert actor_kind == account.role
      assert entity_kind == "account"
      assert entity_ref == to_string(account.id)
    end

    test "authenticates by account ID integer" do
      account = create_active_account()
      code = NimbleTOTP.verification_code(account.seed)

      assert {:ok, result} =
               Accounts.authenticate_internal_account(
                 account.id,
                 account.password,
                 code,
                 keyring: @default_keyring
               )

      assert result.account.id == account.id
    end

    test "matches email case-insensitively with leading/trailing whitespace" do
      account = create_active_account(%{email: "Doctor.House@ClinicaOrigen.com"})
      code = NimbleTOTP.verification_code(account.seed)

      assert {:ok, result} =
               Accounts.authenticate_internal_account(
                 "   DOCTOR.HOUSE@CLINICAORIGEN.COM   ",
                 account.password,
                 code,
                 keyring: @default_keyring
               )

      assert result.account.id == account.id
    end

    test "prevents TOTP code reuse within the same period (replay attack protection)" do
      account = create_active_account()
      fixed_time = 1_700_000_000
      code = NimbleTOTP.verification_code(account.seed, time: fixed_time)

      # First attempt succeeds
      assert {:ok, _} =
               Accounts.authenticate_internal_account(
                 account.email,
                 account.password,
                 code,
                 time: fixed_time,
                 keyring: @default_keyring
               )

      # Replay within same period fails closed
      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(
                 account.email,
                 account.password,
                 code,
                 time: fixed_time,
                 keyring: @default_keyring
               )

      # Failure audit was logged
      %{rows: [[event, result_str]]} =
        Repo.query!(
          "SELECT event, result FROM audit_events WHERE event = 'internal_login' ORDER BY id DESC LIMIT 1"
        )

      assert event == "internal_login"
      assert result_str == "failed"
    end

    test "rejects wrong password with generic error and records audit" do
      account = create_active_account()
      code = NimbleTOTP.verification_code(account.seed)

      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(
                 account.email,
                 "WrongPassword999!",
                 code,
                 keyring: @default_keyring
               )

      %{rows: [[event, result_str, entity_ref]]} =
        Repo.query!(
          "SELECT event, result, entity_ref FROM audit_events WHERE event = 'internal_login' ORDER BY id DESC LIMIT 1"
        )

      assert event == "internal_login"
      assert result_str == "failed"
      assert entity_ref == to_string(account.id)
    end

    test "rejects wrong TOTP code with generic error and records audit" do
      account = create_active_account()

      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(
                 account.email,
                 account.password,
                 "000000",
                 keyring: @default_keyring
               )

      %{rows: [[event, result_str, entity_ref]]} =
        Repo.query!(
          "SELECT event, result, entity_ref FROM audit_events WHERE event = 'internal_login' ORDER BY id DESC LIMIT 1"
        )

      assert event == "internal_login"
      assert result_str == "failed"
      assert entity_ref == to_string(account.id)
    end

    test "rejects non-existent account with uniform generic error (anti-enumeration)" do
      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(
                 "does.not.exist@clinicaorigen.com",
                 "AnyPassword123!",
                 "123456",
                 keyring: @default_keyring
               )

      %{rows: [[event, result_str, entity_kind, entity_ref]]} =
        Repo.query!(
          "SELECT event, result, entity_kind, entity_ref FROM audit_events WHERE event = 'internal_login' ORDER BY id DESC LIMIT 1"
        )

      assert event == "internal_login"
      assert result_str == "failed"
      assert is_nil(entity_kind)
      assert is_nil(entity_ref)
    end

    test "rejects pending_activation account" do
      email = "pending_#{System.unique_integer([:positive])}@clinicaorigen.com"

      %{rows: [[id]]} =
        Repo.query!(
          "INSERT INTO internal_accounts (email, role, state) VALUES ($1, 'administrator', 'pending_activation') RETURNING id",
          [email]
        )

      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(
                 email,
                 "AnyPassword123!",
                 "123456",
                 keyring: @default_keyring
               )

      %{rows: [[event, result_str, entity_ref]]} =
        Repo.query!(
          "SELECT event, result, entity_ref FROM audit_events WHERE event = 'internal_login' ORDER BY id DESC LIMIT 1"
        )

      assert event == "internal_login"
      assert result_str == "failed"
      assert entity_ref == to_string(id)
    end

    test "rejects invalid or malformed arguments fail-closed" do
      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(nil, nil, nil)

      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account("", "", "")

      assert {:error, :unauthenticated} =
               Accounts.authenticate_internal_account(123, "pass", "not-a-code")
    end

    test "supports create_session: false to only verify credentials" do
      account = create_active_account()
      code = NimbleTOTP.verification_code(account.seed)

      assert {:ok, result} =
               Accounts.authenticate_internal_account(
                 account.email,
                 account.password,
                 code,
                 create_session: false,
                 keyring: @default_keyring
               )

      assert result.account.id == account.id
      refute Map.has_key?(result, :token)
      refute Map.has_key?(result, :session)

      # No sessions were created in the database
      %{rows: [[count]]} =
        Repo.query!(
          "SELECT count(*) FROM internal_account_sessions WHERE account_id = $1",
          [account.id]
        )

      assert count == 0
    end
  end

  describe "internal account invitation lifecycle" do
    test "an active administrator atomically creates and invites professionals and secretaries" do
      administrator = create_active_account()
      ttl = Application.fetch_env!(:origen, :internal_invitation_ttl_seconds)

      for role <- [:professional, :secretary] do
        email = "#{role}_#{System.unique_integer([:positive])}@clinicaorigen.com"

        assert {:ok, invitation} =
                 Accounts.create_and_invite_internal_account(
                   administrator.id,
                   %{email: email, role: role},
                   verifier_key: @verifier_key
                 )

        assert invitation.account.role == role
        assert invitation.account.state == :pending_activation
        assert invitation.account.email == email
        assert invitation.account.id == invitation.account_id
        assert is_binary(invitation.token)
        assert DateTime.diff(invitation.expires_at, invitation.issued_at, :second) == ttl

        assert Repo.query!(
                 "SELECT role, state, email FROM internal_accounts WHERE id = $1",
                 [invitation.account_id]
               ).rows == [[Atom.to_string(role), "pending_activation", email]]

        [[version, digest]] =
          Repo.query!(
            "SELECT verifier_version, verifier_digest FROM internal_account_invitations WHERE id = $1",
            [invitation.invitation_id]
          ).rows

        assert version == "v1"
        assert is_binary(digest)
        refute digest == invitation.token
      end
    end

    test "create-and-invite denies every non-active-administrator path opaquely" do
      professional = create_active_account(%{role: "professional"})
      pending_admin = insert_pending_account(:administrator)
      initial_accounts = Repo.aggregate("internal_accounts", :count)
      initial_invitations = Repo.aggregate("internal_account_invitations", :count)

      for actor_id <- [professional.id, pending_admin, -1] do
        assert {:error, :unauthorized} =
                 Accounts.create_and_invite_internal_account(
                   actor_id,
                   %{email: "denied_#{actor_id}@clinicaorigen.com", role: :professional},
                   verifier_key: @verifier_key
                 )
      end

      assert {:error, :unauthorized} =
               Accounts.create_and_invite_internal_account(
                 pending_admin,
                 %{email: "admin@clinicaorigen.com", role: :administrator},
                 verifier_key: @verifier_key
               )

      assert Repo.aggregate("internal_accounts", :count) == initial_accounts
      assert Repo.aggregate("internal_account_invitations", :count) == initial_invitations
    end

    test "an active administrator atomically revokes and replaces a pending account invitation" do
      administrator = create_active_account()

      assert {:ok, first} =
               Accounts.create_and_invite_internal_account(
                 administrator.id,
                 %{email: "pending.professional@clinicaorigen.com", role: :professional},
                 verifier_key: @verifier_key
               )

      assert {:ok, replacement} =
               Accounts.reissue_internal_invitation(
                 administrator.id,
                 first.account_id,
                 verifier_key: @verifier_key
               )

      assert replacement.account_id == first.account_id
      assert replacement.invitation_id != first.invitation_id
      assert replacement.token != first.token

      assert [[nil, %DateTime{}]] =
               Repo.query!(
                 "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1",
                 [first.invitation_id]
               ).rows

      assert Repo.query!(
               "SELECT count(*) FROM internal_account_invitations WHERE account_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL",
               [first.account_id]
             ).rows == [[1]]

      assert {:error, :invalid_invitation} =
               BootstrapAdmin.exchange(first.invitation_id, first.token, @verifier_key)

      assert {:ok, %{account_id: account_id}} =
               BootstrapAdmin.exchange(
                 replacement.invitation_id,
                 replacement.token,
                 @verifier_key
               )

      assert account_id == first.account_id
    end

    test "reissue denies non-administrators and non-pending targets opaquely without revocation" do
      administrator = create_active_account()
      professional = create_active_account(%{role: "professional"})

      assert {:ok, invitation} =
               Accounts.create_and_invite_internal_account(
                 administrator.id,
                 %{email: "pending.secretary@clinicaorigen.com", role: :secretary},
                 verifier_key: @verifier_key
               )

      for {actor_id, target_id} <- [
            {professional.id, invitation.account_id},
            {administrator.id, professional.id},
            {administrator.id, -1}
          ] do
        assert {:error, :unauthorized} =
                 Accounts.reissue_internal_invitation(
                   actor_id,
                   target_id,
                   verifier_key: @verifier_key
                 )
      end

      assert Repo.query!(
               "SELECT revoked_at FROM internal_account_invitations WHERE id = $1",
               [invitation.invitation_id]
             ).rows == [[nil]]
    end

    test "issuance and reissue audits contain references but no raw token or digest" do
      administrator = create_active_account()

      assert {:ok, first} =
               Accounts.create_and_invite_internal_account(
                 administrator.id,
                 %{email: "audit.target@clinicaorigen.com", role: :professional},
                 verifier_key: @verifier_key
               )

      assert {:ok, replacement} =
               Accounts.reissue_internal_invitation(
                 administrator.id,
                 first.account_id,
                 verifier_key: @verifier_key
               )

      audit_rows =
        Repo.query!(
          "SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result FROM audit_events WHERE event IN ('internal_invitation_issued', 'internal_invitation_reissued') ORDER BY id"
        ).rows

      assert audit_rows == [
               [
                 "administrator",
                 to_string(administrator.id),
                 "internal_invitation_issued",
                 "invitation",
                 to_string(first.invitation_id),
                 "succeeded"
               ],
               [
                 "administrator",
                 to_string(administrator.id),
                 "internal_invitation_reissued",
                 "invitation",
                 to_string(replacement.invitation_id),
                 "succeeded"
               ]
             ]

      [[first_digest], [replacement_digest]] =
        Repo.query!(
          "SELECT verifier_digest FROM internal_account_invitations WHERE account_id = $1 ORDER BY id",
          [first.account_id]
        ).rows

      audit_dump = inspect(audit_rows)
      refute audit_dump =~ first.token
      refute audit_dump =~ replacement.token
      refute audit_dump =~ Base.encode16(first_digest)
      refute audit_dump =~ Base.encode16(replacement_digest)
    end

    test "a required issuance audit failure rolls back both account and invitation" do
      administrator = create_active_account()
      initial_accounts = Repo.aggregate("internal_accounts", :count)

      Repo.query!("""
      CREATE OR REPLACE FUNCTION pg_temp.reject_internal_invitation_audit() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.event = 'internal_invitation_issued' THEN
          RAISE EXCEPTION 'audit unavailable' USING ERRCODE = '55000';
        END IF;
        RETURN NEW;
      END $$
      """)

      Repo.query!("""
      CREATE TRIGGER reject_internal_invitation_audit BEFORE INSERT ON audit_events
      FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_internal_invitation_audit()
      """)

      assert {:error, :audit_unavailable} =
               Accounts.create_and_invite_internal_account(
                 administrator.id,
                 %{email: "rollback@clinicaorigen.com", role: :secretary},
                 verifier_key: @verifier_key
               )

      assert Repo.aggregate("internal_accounts", :count) == initial_accounts
      assert Repo.aggregate("internal_account_invitations", :count) == 0
    end

    test "professional and secretary invitations activate through the existing verifier protocol" do
      administrator = create_active_account()

      for role <- [:professional, :secretary] do
        assert {:ok, invitation} =
                 Accounts.create_and_invite_internal_account(
                   administrator.id,
                   %{
                     email: "activation.#{role}@clinicaorigen.com",
                     role: role
                   },
                   verifier_key: @verifier_key
                 )

        credentials = %{password_hash: "argon2id-hash", totp_secret: <<1, 2, 3>>}

        activation =
          case role do
            :professional ->
              BootstrapAdmin.activate(
                invitation.invitation_id,
                invitation.token,
                @verifier_key,
                credentials
              )

            :secretary ->
              assert {:ok, binding} =
                       BootstrapAdmin.exchange(
                         invitation.invitation_id,
                         invitation.token,
                         @verifier_key
                       )

              BootstrapAdmin.activate_bound(
                binding.invitation_id,
                binding.account_id,
                credentials
              )
          end

        assert {:ok, %{account_id: account_id}} = activation
        assert account_id == invitation.account_id

        assert Repo.query!("SELECT role, state FROM internal_accounts WHERE id = $1", [account_id]).rows ==
                 [[Atom.to_string(role), "active"]]
      end
    end
  end

  describe "prepare_internal_account_activation/3" do
    test "returns a short binding for pending professional and secretary invitations without mutating them" do
      administrator = create_active_account()

      for role <- [:professional, :secretary] do
        assert {:ok, invitation} =
                 Accounts.create_and_invite_internal_account(
                   administrator.id,
                   %{
                     email: "prepare.#{role}@clinicaorigen.com",
                     role: role
                   },
                   verifier_key: @verifier_key
                 )

        assert {:ok,
                %{
                  account_id: invitation.account_id,
                  invitation_id: invitation.invitation_id
                }} ==
                 Accounts.prepare_internal_account_activation(
                   invitation.invitation_id,
                   invitation.token,
                   verifier_key: @verifier_key
                 )

        assert [["pending_activation", nil, nil]] =
                 Repo.query!(
                   """
                   SELECT a.state, i.consumed_at, i.revoked_at
                   FROM internal_accounts AS a
                   JOIN internal_account_invitations AS i ON i.account_id = a.id
                   WHERE i.id = $1
                   """,
                   [invitation.invitation_id]
                 ).rows
      end

      assert Repo.query!("SELECT count(*) FROM audit_events WHERE event = 'account_activation'").rows ==
               [[0]]
    end

    test "fails closed for unusable invitations and records only opaque audit failures" do
      administrator = create_active_account()

      invitations =
        for label <- [:invalid_token, :revoked, :expired, :consumed] do
          assert {:ok, invitation} =
                   Accounts.create_and_invite_internal_account(
                     administrator.id,
                     %{
                       email: "#{label}@clinicaorigen.com",
                       role: :professional
                     },
                     verifier_key: @verifier_key
                   )

          invitation
        end

      [invalid_token, revoked, expired, consumed] = invitations

      Repo.query!(
        "UPDATE internal_account_invitations SET revoked_at = clock_timestamp() WHERE id = $1",
        [revoked.invitation_id]
      )

      Repo.query!(
        """
        UPDATE internal_account_invitations
        SET issued_at = clock_timestamp() - interval '2 hours',
            expires_at = clock_timestamp() - interval '1 hour'
        WHERE id = $1
        """,
        [expired.invitation_id]
      )

      Repo.query!(
        "UPDATE internal_account_invitations SET consumed_at = clock_timestamp() WHERE id = $1",
        [consumed.invitation_id]
      )

      attempts = [
        {invalid_token.invitation_id, "wrong-token"},
        {-1, "nonexistent-token"},
        {revoked.invitation_id, revoked.token},
        {expired.invitation_id, expired.token},
        {consumed.invitation_id, consumed.token},
        {nil, nil}
      ]

      for {invitation_id, token} <- attempts do
        assert {:error, :activation_failed} =
                 Accounts.prepare_internal_account_activation(
                   invitation_id,
                   token,
                   verifier_key: @verifier_key
                 )
      end

      audit_rows =
        Repo.query!("""
        SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result
        FROM audit_events
        WHERE event = 'account_activation'
        ORDER BY id
        """).rows

      assert length(audit_rows) == length(attempts)

      assert Enum.all?(audit_rows, fn row ->
               row == ["anonymous", nil, "account_activation", nil, nil, "failed"]
             end)

      audit_dump = inspect(audit_rows)
      refute audit_dump =~ invalid_token.token
      refute audit_dump =~ to_string(invalid_token.invitation_id)
      refute audit_dump =~ to_string(invalid_token.account_id)
    end

    test "rejects administrator invitations from the staff boundary with an opaque audit" do
      %{token: token, verifier_version: version, verifier_digest: digest} =
        Verifier.issue(@verifier_key)

      account_id = insert_pending_account(:administrator)

      %{rows: [[invitation_id]]} =
        Repo.query!(
          """
          INSERT INTO internal_account_invitations
            (account_id, verifier_version, verifier_digest, expires_at)
          VALUES ($1, $2, $3, clock_timestamp() + interval '1 hour')
          RETURNING id
          """,
          [account_id, version, digest]
        )

      assert {:error, :activation_failed} =
               Accounts.prepare_internal_account_activation(invitation_id, token,
                 verifier_key: @verifier_key
               )

      assert Repo.query!("""
             SELECT actor_kind, actor_ref, entity_kind, entity_ref, result
             FROM audit_events
             WHERE event = 'account_activation'
             """).rows == [["anonymous", nil, nil, nil, "failed"]]
    end

    test "activation failures support an anonymous actor with no entity reference" do
      assert {:ok, event} = Events.activation_failed({:anonymous, nil}, nil)
      assert event.actor_kind == "anonymous"
      assert is_nil(event.actor_ref)
      assert is_nil(event.entity_kind)
      assert is_nil(event.entity_ref)
      assert event.result == "failed"
    end
  end

  defp insert_pending_account(role) do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO internal_accounts (role, state) VALUES ($1, 'pending_activation') RETURNING id",
        [Atom.to_string(role)]
      )

    id
  end
end
