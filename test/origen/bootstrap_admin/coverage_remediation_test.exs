defmodule Origen.BootstrapAdmin.CoverageRemediationTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.{Credentials, Redaction, Verifier}

  @key String.duplicate("k", 32)

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    :ok
  end

  test "unknown, revoked, and expired invitations never establish an activation binding" do
    assert {:error, :invalid_invitation} = BootstrapAdmin.exchange(999_999, "token", @key)

    assert {:ok, revoked} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    Repo.query!(
      "UPDATE internal_account_invitations SET revoked_at = clock_timestamp() WHERE id = $1",
      [revoked.invitation_id]
    )

    assert {:error, :invalid_invitation} =
             BootstrapAdmin.exchange(revoked.invitation_id, revoked.token, @key)

    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")

    assert {:ok, expired} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    Repo.query!(
      "UPDATE internal_account_invitations SET expires_at = clock_timestamp() WHERE id = $1",
      [expired.invitation_id]
    )

    assert {:error, :invalid_invitation} =
             BootstrapAdmin.exchange(expired.invitation_id, expired.token, @key)
  end

  test "malformed invitation operations are denied before credential or invitation state changes" do
    assert {:error, :invalid_request} = BootstrapAdmin.exchange("1", "token", @key)
    assert {:error, :invalid_request} = BootstrapAdmin.consume(1, "token", :not_a_key)

    assert {:error, :invalid_request} =
             BootstrapAdmin.activate(1, "token", @key, %{password_hash: "hash"})

    assert {:error, :invalid_request} =
             BootstrapAdmin.activate_bound(1, "1", %{password_hash: "hash", totp_secret: "seed"})

    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
  end

  test "missing invitations are denied by consuming and activating paths" do
    credentials = %{password_hash: "argon2id-hash", totp_secret: <<1, 2, 3>>}

    assert {:error, :invitation_not_found} = BootstrapAdmin.consume(999_999, "token", @key)

    assert {:error, :invitation_not_found} =
             BootstrapAdmin.activate(999_999, "token", @key, credentials)

    assert {:error, :invalid_session_binding} =
             BootstrapAdmin.activate_bound(999_999, 999_998, credentials)
  end

  test "a verifier mismatch leaves a usable invitation and pending account untouched" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:error, :invalid_token} =
             BootstrapAdmin.activate(invitation.invitation_id, "wrong-token", @key, %{
               password_hash: "argon2id-hash",
               totp_secret: <<1, 2, 3>>
             })

    assert invitation_state(invitation.invitation_id) == [[nil, nil]]
    assert account_state(invitation.account_id) == [["pending_activation", nil, nil]]
  end

  test "session binding rejects a different account without consuming the invitation" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:error, :invalid_session_binding} =
             BootstrapAdmin.activate_bound(invitation.invitation_id, invitation.account_id + 1, %{
               password_hash: "argon2id-hash",
               totp_secret: <<1, 2, 3>>
             })

    assert invitation_state(invitation.invitation_id) == [[nil, nil]]
    assert account_state(invitation.account_id) == [["pending_activation", nil, nil]]
  end

  test "credential primitives reject malformed values and unknown encryption keys" do
    assert Credentials.verify_password("password", :not_a_hash) == false

    assert {:error, :invalid_seed} = Credentials.encrypt_seed(:not_a_seed, @key)
    assert {:error, :invalid_keyring} = Credentials.decrypt_seed("ciphertext", %{active: %{}})

    assert {:error, :undecryptable} =
             Credentials.decrypt_seed("seed.unknown.ciphertext", %{
               active: %{tag: "seed.v1", key: @key},
               retired: []
             })
  end

  test "verifier rejects short keys, malformed digests, and unsupported versions" do
    issue = Verifier.issue(@key)

    assert :error = Verifier.digest(issue.token, String.duplicate("x", 31))
    refute Verifier.verify(issue.token, "v2", issue.verifier_digest, @key)
    refute Verifier.verify(issue.token, "v1", "short", @key)
  end

  test "redaction rejects malformed payloads, unknown key types, and non-string references" do
    assert {:error, :invalid_payload} = Redaction.sanitize(event: "bootstrap")
    assert {:error, :unapproved_field} = Redaction.sanitize(%{123 => "value"})
    assert {:error, :sensitive_reference} = Redaction.sanitize(%{account_ref: 42})
  end

  defp invitation_state(invitation_id) do
    Repo.query!(
      "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1",
      [invitation_id]
    ).rows
  end

  defp account_state(account_id) do
    Repo.query!(
      "SELECT state, password_hash, totp_secret FROM internal_accounts WHERE id = $1",
      [account_id]
    ).rows
  end
end
