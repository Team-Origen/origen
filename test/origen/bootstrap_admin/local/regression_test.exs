defmodule Origen.BootstrapAdmin.Local.RegressionTest do
  use Origen.DataCase, async: false
  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.Local.{Command, MailboxStore}
  alias Origen.Repo
  @key String.duplicate("k", 32)
  defmodule RecordingMailbox do
    def deliver(transient, opts) do
      send(opts[:test_pid], {:handoff, transient})
      {:ok, %{correlation_ref: "synthetic-handoff"}}
    end
  end

  defmodule UncertainMailbox do
    def deliver(transient, opts) do
      send(opts[:test_pid], {:uncertain_handoff, transient})
      {:error, :uncertain}
    end
  end

  defmodule SecretCache do
    def fetch_secret(:verifier_key), do: {:ok, String.duplicate("k", 32)}
  end

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    MailboxStore.clear()
    previous_key = Application.get_env(:origen, :bootstrap_admin_verifier_key)

    key_file =
      Path.join(System.tmp_dir!(), "origen-regression-key-#{System.unique_integer([:positive])}")

    File.write!(key_file, Base.encode64(@key))
    Application.put_env(:origen, :bootstrap_admin_verifier_key, {:file, key_file})

    on_exit(fn ->
      File.rm(key_file)
      restore_env(:bootstrap_admin_verifier_key, previous_key)
      MailboxStore.clear()
    end)

    {:ok,
     opts: [
       config: config(),
       probes: probes(),
       mailbox: RecordingMailbox,
       secret_cache: SecretCache,
       test_pid: self()
     ]}
  end

  test "uncertain handoff revokes, recovery keeps the account, and stale tokens stay denied", %{
    opts: opts
  } do
    assert {:error, :delivery_failed, failed} =
             Command.run(%{account_id: nil}, Keyword.put(opts, :mailbox, UncertainMailbox))

    assert_receive {:uncertain_handoff, %{token: revoked_token}}
    assert failed.outcome == :revoked
    assert [[nil, revoked_at]] = invitation_state(failed.invitation_id)
    assert not is_nil(revoked_at)
    assert {:ok, fresh} = Command.run(%{account_id: failed.account_id}, opts)
    assert_receive {:handoff, %{token: fresh_token}}
    assert fresh.account_id == failed.account_id
    assert fresh.invitation_id != failed.invitation_id
    refute inspect(fresh) =~ fresh_token
    refute revoked_token == fresh_token

    assert {:error, :invalid_invitation} =
             BootstrapAdmin.exchange(failed.invitation_id, revoked_token, @key)
  end

  test "expired invitation and active account both deny terminal operations", %{opts: opts} do
    assert {:ok, issued} = Command.run(%{account_id: nil}, opts)
    assert_receive {:handoff, %{token: token}}

    Repo.query!(
      "UPDATE internal_account_invitations SET issued_at = NOW() - interval '2 seconds', expires_at = NOW() - interval '1 second' WHERE id = $1",
      [issued.invitation_id]
    )

    assert {:error, :invalid_invitation} =
             BootstrapAdmin.exchange(issued.invitation_id, token, @key)

    Repo.query!(
      "UPDATE internal_accounts SET state = 'active', password_hash = 'hash', totp_secret = decode('00', 'hex'), activated_at = NOW() WHERE id = $1",
      [issued.account_id]
    )

    before_denial =
      {Repo.aggregate("internal_accounts", :count),
       Repo.aggregate("internal_account_invitations", :count)}

    assert {:error, :target_unauthorized} = Command.run(%{account_id: nil}, opts)

    assert before_denial ==
             {Repo.aggregate("internal_accounts", :count),
              Repo.aggregate("internal_account_invitations", :count)}

    assert MailboxStore.count() == 0
  end

  test "readiness and authorization default deny unsafe facts", %{opts: opts} do
    unsafe =
      config()
      |> Map.put(:destination, "private@example.com")
      |> Map.put(:database_scope, :shared)

    assert {:error, {:local_not_ready, findings}} =
             Command.run(%{account_id: nil}, Keyword.put(opts, :config, unsafe))

    assert :destination_invalid in findings
    assert :database_isolation_unconfigured in findings
  end

  test "concurrent initial runs serialize to one administrator", %{opts: opts} do
    tasks =
      for _ <- 1..2 do
        Task.async(fn -> Command.run(%{account_id: nil}, opts) end)
      end

    results = Task.await_many(tasks)
    assert Enum.count(results, &match?({:ok, _}, &1)) == 1

    assert Enum.count(results, fn
             {:error, reason} when reason in [:administrator_exists, :target_unauthorized] -> true
             _ -> false
           end) == 1

    assert Repo.aggregate("internal_accounts", :count) == 1
  end

  defp invitation_state(id) do
    Repo.query!(
      "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1",
      [id]
    ).rows
  end

  def config do
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
      certificate_file: "cert",
      certificate_key_file: "cert-key",
      verifier_key_file: "verifier-key",
      totp_key_file: "totp-key",
      totp_key_tag: "local-test",
      database_name: Repo.config()[:database],
      database_scope: :isolated_workstation
    }
  end

  def probes,
    do: %{
      lstat: fn _ -> {:ok, %{type: :regular, size: 32, mode: 0o600, owner: :current_user}} end
    }

  defp restore_env(key, nil), do: Application.delete_env(:origen, key)
  defp restore_env(key, value), do: Application.put_env(:origen, key, value)
end
