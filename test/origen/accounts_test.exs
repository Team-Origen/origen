defmodule Origen.AccountsTest do
  use Origen.DataCase

  alias Origen.Accounts
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo
  alias Origen.Sessions

  @default_keyring %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  }

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
end
