defmodule Origen.BootstrapAdmin.ActivationEmailTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin

  @key String.duplicate("k", 32)
  @credentials %{password_hash: "argon2id-hash", totp_secret: <<1, 2, 3>>}

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    :ok
  end

  test "stores the sign-in email chosen at activation, trimmed and lowercased" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:ok, _result} =
             BootstrapAdmin.activate_bound(
               invitation.invitation_id,
               invitation.account_id,
               Map.put(@credentials, :email, "  Admin.Demo@Gmail.com ")
             )

    assert account(invitation.account_id) == [["active", "admin.demo@gmail.com"]]
  end

  test "keeps activating without an email when none is given" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:ok, _result} =
             BootstrapAdmin.activate_bound(
               invitation.invitation_id,
               invitation.account_id,
               @credentials
             )

    assert account(invitation.account_id) == [["active", nil]]
  end

  test "rejects a malformed email without consuming the invitation" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    for email <- ["", "not-an-email", "a@b", "two words@gmail.com"] do
      assert {:error, :invalid_email} =
               BootstrapAdmin.activate_bound(
                 invitation.invitation_id,
                 invitation.account_id,
                 Map.put(@credentials, :email, email)
               )
    end

    assert account(invitation.account_id) == [["pending_activation", nil]]
    assert invitation_consumed?(invitation.invitation_id) == false
  end

  test "rejects an email another internal account already uses, ignoring case" do
    Repo.query!("""
    INSERT INTO internal_accounts (role, state, email)
    VALUES ('secretary', 'pending_activation', 'taken@gmail.com')
    """)

    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:error, :email_taken} =
             BootstrapAdmin.activate_bound(
               invitation.invitation_id,
               invitation.account_id,
               Map.put(@credentials, :email, "Taken@Gmail.com")
             )

    assert account(invitation.account_id) == [["pending_activation", nil]]
    assert invitation_consumed?(invitation.invitation_id) == false
  end

  defp account(account_id) do
    Repo.query!("SELECT state, email FROM internal_accounts WHERE id = $1", [account_id]).rows
  end

  defp invitation_consumed?(invitation_id) do
    [[consumed_at]] =
      Repo.query!(
        "SELECT consumed_at FROM internal_account_invitations WHERE id = $1",
        [invitation_id]
      ).rows

    not is_nil(consumed_at)
  end
end
