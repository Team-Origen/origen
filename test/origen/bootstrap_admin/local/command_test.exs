defmodule Origen.BootstrapAdmin.Local.CommandTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin.Local.Command
  alias Origen.BootstrapAdmin.Local.MailboxStore
  alias Origen.Repo

  @verifier_key String.duplicate("k", 32)

  defmodule SecretCache do
    def fetch_secret(:verifier_key), do: {:ok, String.duplicate("k", 32)}
  end

  # Lifecycle issuance consumes the endpoint session cache.

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    MailboxStore.clear()

    # Configure verifier key in environment
    temp_dir = System.tmp_dir!()

    key_file =
      Path.join(
        temp_dir,
        "local_verifier_key_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}.txt"
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

    {:ok,
     default_opts: [
       config: valid_config(),
       probes: valid_probes(),
       secret_cache: SecretCache
     ]}
  end

  test "initial run creates pending admin and delivers to mailbox", %{default_opts: opts} do
    assert {:ok, result} = Command.run(%{account_id: nil}, opts)
    assert is_integer(result.account_id)
    assert is_integer(result.invitation_id)
    assert is_binary(result.correlation_ref)

    # Database assertions
    accounts = Repo.query!("SELECT id, role, state FROM internal_accounts").rows
    assert [[acc_id, "administrator", "pending_activation"]] = accounts
    assert acc_id == result.account_id

    # Mailbox contains exactly one message
    assert MailboxStore.count() == 1

    # Security: result never leaks sensitive data
    inspected = inspect(result)
    refute inspected =~ "token"
    refute inspected =~ "example.test"
  end

  test "repeated initial run is denied with compensation/failure", %{default_opts: opts} do
    assert {:ok, _} = Command.run(%{account_id: nil}, opts)
    assert {:error, reason} = Command.run(%{account_id: nil}, opts)
    assert reason in [:mailbox_retained, :target_unauthorized, :administrator_exists]
  end

  test "recovery run with correct account_id succeeds after handoff failure/revocation", %{
    default_opts: opts
  } do
    assert {:ok, first} = Command.run(%{account_id: nil}, opts)

    # Simulate handoff failure / revocation
    Origen.BootstrapAdmin.Delivery.revoke_delivery_failure(first.invitation_id, %{
      account_id: first.account_id
    })

    MailboxStore.clear()

    # Recovery run
    assert {:ok, second} = Command.run(%{account_id: first.account_id}, opts)
    assert second.account_id == first.account_id
    assert second.invitation_id != first.invitation_id
  end

  test "recovery fails if account_id does not match pending administrator", %{default_opts: opts} do
    assert {:ok, first} = Command.run(%{account_id: nil}, opts)

    Origen.BootstrapAdmin.Delivery.revoke_delivery_failure(first.invitation_id, %{
      account_id: first.account_id
    })

    MailboxStore.clear()

    assert {:error, :target_unauthorized} =
             Command.run(%{account_id: first.account_id + 999}, opts)
  end

  test "recovery fails if mailbox still retains an unconsumed message", %{default_opts: opts} do
    assert {:ok, first} = Command.run(%{account_id: nil}, opts)

    Origen.BootstrapAdmin.Delivery.revoke_delivery_failure(first.invitation_id, %{
      account_id: first.account_id
    })

    # Do NOT clear mailbox store!
    assert {:error, :mailbox_retained} = Command.run(%{account_id: first.account_id}, opts)
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
      certificate_file: "certificate-canary",
      certificate_key_file: "certificate-key-canary",
      verifier_key_file: "verifier-canary",
      totp_key_file: "totp-canary",
      totp_key_tag: "local-totp",
      database_name: Repo.config()[:database],
      database_scope: :isolated_workstation
    }
  end

  defp valid_probes do
    %{
      lstat: fn _path -> {:ok, %{type: :regular, size: 32, mode: 0o600, owner: :current_user}} end
    }
  end
end
