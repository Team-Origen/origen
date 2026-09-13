defmodule Origen.BootstrapAdmin.Local.LifecycleTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin.Local.{Command, MailboxStore}
  alias Origen.Repo

  @verifier_key String.duplicate("k", 32)

  defmodule FailingMailbox do
    def deliver(_transient, _opts), do: {:error, :simulated_mailer_crash}
  end

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    MailboxStore.clear()

    temp_dir = System.tmp_dir!()

    key_file =
      Path.join(
        temp_dir,
        "lifecycle_verifier_key_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}.txt"
      )

    encoded_key = Base.encode64(@verifier_key)
    File.write!(key_file, encoded_key)

    Application.put_env(:origen, :bootstrap_admin_verifier_key, {:file, key_file})
    Application.put_env(:origen, :bootstrap_admin_local_profile, "true")

    on_exit(fn ->
      File.rm(key_file)
      Application.delete_env(:origen, :bootstrap_admin_verifier_key)
      Application.delete_env(:origen, :bootstrap_admin_local_profile)
    end)

    {:ok, default_opts: [config: valid_config(), probes: valid_probes()]}
  end

  test "failed handoff triggers automatic compensation revoking the invitation", %{
    default_opts: opts
  } do
    run_opts = opts ++ [mailbox: FailingMailbox]

    assert {:error, :delivery_failed, references} = Command.run(%{account_id: nil}, run_opts)
    assert references.outcome == :revoked
    assert references.account_id > 0
    assert references.invitation_id > 0

    # Ensure database shows account pending_activation and invitation revoked
    accounts = Repo.query!("SELECT id, state FROM internal_accounts").rows
    assert [[acc_id, "pending_activation"]] = accounts
    assert acc_id == references.account_id

    invitations =
      Repo.query!("SELECT id, consumed_at, revoked_at FROM internal_account_invitations").rows

    assert [[inv_id, nil, revoked_at]] = invitations
    assert inv_id == references.invitation_id
    assert not is_nil(revoked_at)
  end

  test "TTL expiry purges message and prevents access", %{default_opts: opts} do
    clock_val = :atomics.new(1, [])
    :atomics.put(clock_val, 1, 1_000)
    fake_clock = fn -> :atomics.get(clock_val, 1) end

    run_opts = opts ++ [clock: fake_clock, ttl_seconds: 60]
    assert {:ok, _result} = Command.run(%{account_id: nil}, run_opts)

    # Within TTL: message exists in store
    assert MailboxStore.count(clock: fake_clock) == 1

    # Advance time past TTL
    :atomics.put(clock_val, 1, 1_061)

    # Expired: message is purged from store
    assert MailboxStore.count(clock: fake_clock) == 0
  end

  test "concurrent initial runs serialize: exactly one succeeds and other fails", %{
    default_opts: opts
  } do
    results =
      1..2
      |> Task.async_stream(fn _ -> Command.run(%{account_id: nil}, opts) end, ordered: false)
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1

    assert Enum.count(results, fn
             {:error, reason}
             when reason in [:administrator_exists, :target_unauthorized, :mailbox_retained] ->
               true

             _ ->
               false
           end) == 1

    # DB state: exactly 1 account, 1 invitation
    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 1
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
