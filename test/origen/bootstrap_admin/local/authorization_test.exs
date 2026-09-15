defmodule Origen.BootstrapAdmin.Local.AuthorizationTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin.Local.Authorization
  alias Origen.BootstrapAdmin.Local.Target
  alias Origen.Repo

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")

    Application.put_env(:origen, :bootstrap_admin_local_profile, "true")

    on_exit(fn ->
      Application.delete_env(:origen, :bootstrap_admin_local_profile)
    end)

    :ok
  end

  test "authorizes initial bootstrap when database is isolated and no active administrators exist" do
    assert {:ok, _destination, nil} =
             Authorization.authorize(config: valid_config(), probes: valid_probes())
  end

  test "authorizes recovery when exactly one pending administrator exists" do
    %{id: account_id} = insert_account!("administrator", "pending_activation")
    insert_invitation!(account_id, "revoked")

    assert {:ok, _destination, %Target{id: ^account_id}} =
             Authorization.authorize(config: valid_config(), probes: valid_probes())
  end

  test "denies authorization when multiple pending administrators exist" do
    account1 = insert_account!("administrator", "pending_activation")
    account2 = insert_account!("administrator", "pending_activation")

    insert_invitation!(account1.id, "revoked")
    insert_invitation!(account2.id, "revoked")

    assert {:error, :target_unauthorized} =
             Authorization.authorize(config: valid_config(), probes: valid_probes())
  end

  test "denies authorization when an active administrator exists" do
    insert_account!("administrator", "active")

    assert {:error, :target_unauthorized} =
             Authorization.authorize(config: valid_config(), probes: valid_probes())
  end

  test "denies authorization when shared database is detected" do
    # Simulating shared DB by changing the config name
    original = Repo.config()[:database]

    Application.put_env(
      :origen,
      Origen.Repo,
      Keyword.put(Repo.config(), :database, "production_db")
    )

    # Needs to restart or re-evaluate. Actually Repo.config/0 reads env.
    assert {:error, :shared_database} =
             Authorization.authorize(config: valid_config(), probes: valid_probes())

    Application.put_env(:origen, Origen.Repo, Keyword.put(Repo.config(), :database, original))
  end

  defp insert_account!(role, "active") do
    {:ok, %{rows: [[id]]}} =
      Repo.query(
        "INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at) VALUES ($1, 'active', 'hash', decode('010203', 'hex'), NOW()) RETURNING id",
        [role]
      )

    %{id: id}
  end

  defp insert_account!(role, state) do
    {:ok, %{rows: [[id]]}} =
      Repo.query(
        "INSERT INTO internal_accounts (role, state) VALUES ($1, $2) RETURNING id",
        [role, state]
      )

    %{id: id}
  end

  defp insert_invitation!(account_id, _handoff_state) do
    Repo.query!(
      "INSERT INTO internal_account_invitations (account_id, verifier_version, verifier_digest, issued_by_ref, revoked_at) VALUES ($1, 'v1', decode('0000000000000000000000000000000000000000000000000000000000000000', 'hex'), 'system', NOW())",
      [account_id]
    )
  end

  defp valid_config do
    %{
      profile: :local,
      enabled: true,
      channel: :source_checkout,
      destination: "student@example.test",
      activation_origin: "https://127.0.0.1:4443/admin/activate",
      endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false},
      mailer: Origen.Mailer,
      adapter: Swoosh.Adapters.Local,
      storage: Swoosh.Adapters.Local.Storage.Memory,
      preview: Plug.Swoosh.MailboxPreview,
      retention_owner: Origen.BootstrapAdmin.Local.Mailbox,
      retention_ttl_seconds: 60,
      max_messages: 1,
      certificate_path: "certificate-canary",
      certificate_key_path: "certificate-key-canary",
      verifier_key_path: "verifier-canary",
      totp_key_path: "totp-canary",
      totp_key_tag: "local-totp",
      database_name: "origen_dev",
      database_scope: :isolated_workstation
    }
  end

  defp valid_probes do
    %{
      lstat: fn _path -> {:ok, %{type: :regular, size: 32, mode: 0o600, owner: :current_user}} end
    }
  end
end
