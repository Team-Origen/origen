defmodule Origen.BootstrapAdmin.LifecycleTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin

  @key String.duplicate("k", 32)
  @short_key String.duplicate("k", 31)

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    :ok
  end

  test "exposes the declared lifecycle module boundaries" do
    assert {:module, _} = Code.ensure_loaded(Origen.BootstrapAdmin.Account)
    assert {:module, _} = Code.ensure_loaded(Origen.BootstrapAdmin.Invitation)
    assert {:module, _} = Code.ensure_loaded(Origen.BootstrapAdmin.Delivery)
    assert function_exported?(Origen.BootstrapAdmin.Account, :issue_first, 1)
    assert function_exported?(Origen.BootstrapAdmin.Invitation, :consume, 3)
    assert function_exported?(Origen.BootstrapAdmin.Delivery, :create_invitation, 4)
  end

  test "issues one pending administrator invitation with a 24-hour expiry" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert invitation.account_id > 0
    assert invitation.invitation_id > 0
    assert is_binary(invitation.token)
    assert DateTime.diff(invitation.expires_at, invitation.issued_at, :second) == 24 * 60 * 60

    row = Repo.query!("SELECT state FROM internal_accounts").rows
    assert row == [["pending_activation"]]

    stored = Repo.query!("SELECT verifier_digest FROM internal_account_invitations").rows
    refute stored == [[invitation.token]]
  end

  test "denies a repeated first-admin issue without creating another account" do
    assert {:ok, _first} = BootstrapAdmin.issue_first(%{verifier_key: @key})
    assert {:error, :administrator_exists} = BootstrapAdmin.issue_first(%{verifier_key: @key})
    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 1
  end

  test "rejects a short verifier key before issuing any rows" do
    assert {:error, :invalid_verifier_key} =
             BootstrapAdmin.issue_first(%{verifier_key: @short_key})

    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
  end

  test "rejects a short reissue key before changing the invitation lifecycle" do
    assert {:ok, first} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:error, :invalid_verifier_key} =
             BootstrapAdmin.reissue_first(first.account_id, %{verifier_key: @short_key})

    assert Repo.query!("SELECT count(*) FROM internal_accounts").rows == [[1]]

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_invitations WHERE revoked_at IS NULL"
           ).rows == [[1]]
  end

  test "serializes concurrent first-admin issues through the control row" do
    results =
      1..2
      |> Task.async_stream(fn _ -> BootstrapAdmin.issue_first(%{verifier_key: @key}) end,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :administrator_exists})) == 1
    assert Repo.aggregate("internal_accounts", :count) == 1
  end

  test "reissue revokes the predecessor and leaves one active invitation" do
    assert {:ok, first} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:ok, replacement} =
             BootstrapAdmin.reissue_first(first.account_id, %{verifier_key: @key})

    assert replacement.invitation_id != first.invitation_id

    [[consumed_at, revoked_at], _replacement] =
      Repo.query!("SELECT consumed_at, revoked_at FROM internal_account_invitations ORDER BY id").rows

    assert is_nil(consumed_at)
    assert not is_nil(revoked_at)

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_invitations WHERE consumed_at IS NULL AND revoked_at IS NULL"
           ).rows == [[1]]
  end

  test "consumption is one-time and rejects expiry or revocation" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:ok, %{account_id: account_id}} =
             BootstrapAdmin.consume(invitation.invitation_id, invitation.token, @key)

    assert account_id == invitation.account_id

    assert {:error, :already_consumed} =
             BootstrapAdmin.consume(invitation.invitation_id, invitation.token, @key)

    assert {:ok, replacement} = BootstrapAdmin.reissue_first(account_id, %{verifier_key: @key})

    Repo.query!(
      "UPDATE internal_account_invitations SET expires_at = clock_timestamp() WHERE id = $1",
      [replacement.invitation_id]
    )

    assert {:error, :expired} =
             BootstrapAdmin.consume(replacement.invitation_id, replacement.token, @key)
  end

  test "required audit failure rolls back invitation lifecycle writes" do
    Repo.query!("""
    CREATE OR REPLACE FUNCTION pg_temp.reject_bootstrap_audit() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'audit unavailable' USING ERRCODE = '55000'; END $$
    """)

    Repo.query!("""
    CREATE TRIGGER reject_bootstrap_audit BEFORE INSERT ON audit_events
    FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_bootstrap_audit()
    """)

    assert {:error, :audit_unavailable} = BootstrapAdmin.issue_first(%{verifier_key: @key})
    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
  end

  test "delivery failure revocation is idempotent and denies exchange and activation" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:ok, :revoked} =
             BootstrapAdmin.revoke_delivery_failure(invitation.invitation_id, %{
               account_id: invitation.account_id
             })

    assert {:ok, :already_revoked} =
             BootstrapAdmin.revoke_delivery_failure(invitation.invitation_id, %{})

    assert Repo.query!(
             "SELECT count(*) FROM audit_events WHERE event = 'invitation_delivery_revocation'"
           ).rows == [[1]]

    assert {:error, :invalid_invitation} =
             BootstrapAdmin.exchange(invitation.invitation_id, invitation.token, @key)

    assert {:error, :revoked} =
             BootstrapAdmin.consume(invitation.invitation_id, invitation.token, @key)
  end

  test "revocation denies unknown and consumed invitations" do
    assert {:error, :invitation_not_found} = BootstrapAdmin.revoke_delivery_failure(-1, %{})
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})
    assert {:ok, _} = BootstrapAdmin.consume(invitation.invitation_id, invitation.token, @key)

    assert {:error, :invitation_consumed} =
             BootstrapAdmin.revoke_delivery_failure(invitation.invitation_id, %{})
  end

  test "required revocation audit failure rolls back the row update" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    Repo.query!("""
    CREATE OR REPLACE FUNCTION pg_temp.reject_revocation_audit() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.event IN ('invitation_delivery_failure', 'invitation_delivery_revocation') THEN
        RAISE EXCEPTION 'audit unavailable' USING ERRCODE = '55000';
      END IF;
      RETURN NEW;
    END $$
    """)

    Repo.query!("""
    CREATE TRIGGER reject_revocation_audit BEFORE INSERT ON audit_events
    FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_revocation_audit()
    """)

    assert {:error, :audit_unavailable} =
             BootstrapAdmin.revoke_delivery_failure(invitation.invitation_id, %{})

    assert Repo.query!("SELECT revoked_at FROM internal_account_invitations WHERE id = $1", [
             invitation.invitation_id
           ]).rows == [[nil]]
  end

  test "consume versus delivery failure has one terminal winner under row lock" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    consume =
      Task.async(fn ->
        BootstrapAdmin.consume(invitation.invitation_id, invitation.token, @key)
      end)

    revoke =
      Task.async(fn -> BootstrapAdmin.revoke_delivery_failure(invitation.invitation_id, %{}) end)

    results = Task.await_many([consume, revoke])

    assert Enum.sort(results) in [
             Enum.sort([
               {:ok,
                %{account_id: invitation.account_id, invitation_id: invitation.invitation_id}},
               {:error, :invitation_consumed}
             ]),
             Enum.sort([{:error, :revoked}, {:ok, :revoked}])
           ]

    assert Repo.query!(
             "SELECT consumed_at IS NOT NULL, revoked_at IS NOT NULL FROM internal_account_invitations WHERE id = $1",
             [invitation.invitation_id]
           ).rows in [[[true, false]], [[false, true]]]
  end

  test "activation consumes before credential persistence and rejects replay" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    assert {:ok, %{account_id: account_id}} =
             BootstrapAdmin.activate(invitation.invitation_id, invitation.token, @key, %{
               password_hash: "argon2id-hash",
               totp_secret: <<1, 2, 3>>
             })

    assert Repo.query!("SELECT state, password_hash FROM internal_accounts WHERE id = $1", [
             account_id
           ]).rows ==
             [["active", "argon2id-hash"]]

    assert {:error, :already_consumed} =
             BootstrapAdmin.activate(invitation.invitation_id, invitation.token, @key, %{
               password_hash: "other",
               totp_secret: <<4>>
             })
  end

  test "serializes reissue and activation without a PostgreSQL deadlock" do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @key})

    operations =
      for _ <- 1..8 do
        [
          Task.async(fn ->
            BootstrapAdmin.reissue_first(invitation.account_id, %{verifier_key: @key})
          end),
          Task.async(fn ->
            BootstrapAdmin.activate(invitation.invitation_id, invitation.token, @key, %{
              password_hash: "argon2id-hash",
              totp_secret: <<1, 2, 3>>
            })
          end)
        ]
      end
      |> List.flatten()

    results = Task.await_many(operations, 5_000)

    refute Enum.any?(
             results,
             &match?({:error, %Postgrex.Error{postgres: %{code: :deadlock_detected}}}, &1)
           )

    refute Enum.any?(results, &match?({:error, %Postgrex.Error{postgres: %{code: "40P01"}}}, &1))
  end
end
