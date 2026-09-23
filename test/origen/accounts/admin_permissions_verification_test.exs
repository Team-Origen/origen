defmodule Origen.Accounts.AdminPermissionsVerificationTest do
  @moduledoc """
  Exhaustive domain-level verification for Issue #60:
  Proves that ONLY active administrators can create internal accounts
  (professional or secretary) and issue invitations.

  Upholds the boundaries of PLN-11 (#44):
  - Secretary CANNOT create professionals or secretaries.
  - Professional CANNOT create professionals or secretaries.
  - Inactive / pending administrators CANNOT create accounts.
  - Rejection is strictly opaque, transactional, and side-effect free.
  """

  use Origen.DataCase

  alias Origen.Accounts
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo

  @default_keyring %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  }
  @verifier_key String.duplicate("v", 32)

  defp create_active_account(role) do
    email = "#{role}_#{System.unique_integer([:positive])}@clinicaorigen.com"
    password_hash = Credentials.hash_password("SuperSecurePassword123!")
    seed = NimbleTOTP.secret()
    {:ok, totp_secret} = Credentials.encrypt_seed(seed, @default_keyring)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', $3, $4, clock_timestamp())
        RETURNING id
        """,
        [email, to_string(role), password_hash, totp_secret]
      )

    %{id: id, role: role, email: email}
  end

  defp create_pending_account(role) do
    email = "#{role}_pending_#{System.unique_integer([:positive])}@clinicaorigen.com"

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state)
        VALUES ($1, $2, 'pending_activation')
        RETURNING id
        """,
        [email, to_string(role)]
      )

    %{id: id, role: role, email: email}
  end

  describe "Issue #60: other roles cannot create accounts (PLN-11)" do
    test "active secretary cannot create professional or secretary accounts" do
      secretary = create_active_account(:secretary)

      initial_accounts = Repo.aggregate("internal_accounts", :count)
      initial_invitations = Repo.aggregate("internal_account_invitations", :count)
      initial_audits = audit_issuance_count()

      for target_role <- [:professional, :secretary] do
        email = "unauthorized_by_sec_#{target_role}@clinicaorigen.com"

        assert {:error, :unauthorized} =
                 Accounts.create_and_invite_internal_account(
                   secretary.id,
                   %{email: email, role: target_role},
                   verifier_key: @verifier_key
                 )
      end

      # Zero side effects: no account created, no invitation emitted, no audit appended
      assert Repo.aggregate("internal_accounts", :count) == initial_accounts
      assert Repo.aggregate("internal_account_invitations", :count) == initial_invitations
      assert audit_issuance_count() == initial_audits
    end

    test "active professional cannot create professional or secretary accounts" do
      professional = create_active_account(:professional)

      initial_accounts = Repo.aggregate("internal_accounts", :count)
      initial_invitations = Repo.aggregate("internal_account_invitations", :count)
      initial_audits = audit_issuance_count()

      for target_role <- [:professional, :secretary] do
        email = "unauthorized_by_prof_#{target_role}@clinicaorigen.com"

        assert {:error, :unauthorized} =
                 Accounts.create_and_invite_internal_account(
                   professional.id,
                   %{email: email, role: target_role},
                   verifier_key: @verifier_key
                 )
      end

      assert Repo.aggregate("internal_accounts", :count) == initial_accounts
      assert Repo.aggregate("internal_account_invitations", :count) == initial_invitations
      assert audit_issuance_count() == initial_audits
    end

    test "non-active accounts and invalid actor IDs are denied" do
      pending_admin = create_pending_account(:administrator)
      pending_secretary = create_pending_account(:secretary)

      initial_accounts = Repo.aggregate("internal_accounts", :count)
      initial_invitations = Repo.aggregate("internal_account_invitations", :count)
      initial_audits = audit_issuance_count()

      unauthorized_actors = [
        pending_admin.id,
        pending_secretary.id,
        -1,
        0,
        999_999
      ]

      for actor_id <- unauthorized_actors do
        assert {:error, :unauthorized} =
                 Accounts.create_and_invite_internal_account(
                   actor_id,
                   %{email: "denied_actor_#{actor_id}@clinicaorigen.com", role: :professional},
                   verifier_key: @verifier_key
                 )
      end

      assert Repo.aggregate("internal_accounts", :count) == initial_accounts
      assert Repo.aggregate("internal_account_invitations", :count) == initial_invitations
      assert audit_issuance_count() == initial_audits
    end

    test "active administrator cannot create unauthorized roles like administrator" do
      admin = create_active_account(:administrator)

      initial_accounts = Repo.aggregate("internal_accounts", :count)
      initial_invitations = Repo.aggregate("internal_account_invitations", :count)

      assert {:error, :unauthorized} =
               Accounts.create_and_invite_internal_account(
                 admin.id,
                 %{email: "admin_clone@clinicaorigen.com", role: :administrator},
                 verifier_key: @verifier_key
               )

      assert Repo.aggregate("internal_accounts", :count) == initial_accounts
      assert Repo.aggregate("internal_account_invitations", :count) == initial_invitations
    end

    test "positive contrast: active administrator can create professional and secretary accounts" do
      admin = create_active_account(:administrator)

      for target_role <- [:professional, :secretary] do
        email =
          "authorized_#{target_role}_#{System.unique_integer([:positive])}@clinicaorigen.com"

        assert {:ok, invitation} =
                 Accounts.create_and_invite_internal_account(
                   admin.id,
                   %{email: email, role: target_role},
                   verifier_key: @verifier_key
                 )

        assert invitation.account.role == target_role
        assert invitation.account.state == :pending_activation
        assert invitation.account.email == email
        assert is_binary(invitation.token)
        assert is_integer(invitation.invitation_id)
      end
    end
  end

  defp audit_issuance_count do
    case Repo.query(
           "SELECT count(*) FROM audit_events WHERE event = 'internal_invitation_issued'"
         ) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end
end
