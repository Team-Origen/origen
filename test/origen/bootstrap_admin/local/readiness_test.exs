defmodule Origen.BootstrapAdmin.Local.ReadinessTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Local.Readiness

  # Canonical readiness exercises only the fixed *_file contract.

  test "aggregates sorted, deduplicated sanitized findings without crossing protected boundaries" do
    secret = "do-not-expose@example.invalid"

    config =
      valid_config()
      |> Map.merge(%{
        profile: :staging,
        channel: :packaged_release,
        destination: secret,
        activation_origin: "http://127.0.0.1:4444/not-activate",
        endpoint: %{scheme: :http, ip: {0, 0, 0, 0}, port: 4443, http: true, http_port: 4000},
        mailer: Swoosh.Adapters.Test,
        adapter: Swoosh.Adapters.Test,
        preview: Swoosh.Adapters.Test,
        retention_ttl_seconds: 901,
        max_messages: 2,
        database_scope: :shared
      })

    assert {:error, {:local_not_ready, findings}} = Readiness.inspect(config, probes(secret))
    assert findings == Enum.uniq(Enum.sort(findings))

    assert findings == [
             :activation_origin_invalid,
             :command_channel_invalid,
             :database_isolation_unconfigured,
             :destination_invalid,
             :endpoint_http_enabled,
             :endpoint_https_invalid,
             :endpoint_not_ipv4_loopback,
             :endpoint_port_mismatch,
             :mailbox_adapter_invalid,
             :mailbox_preview_unavailable,
             :mailbox_retention_invalid,
             :profile_invalid,
             :verifier_source_unavailable
           ]

    refute inspect({:error, {:local_not_ready, findings}}) =~ secret
    assert_receive {:lstat, "verifier-canary"}
    refute_receive {:protected_boundary, _}
  end

  test "rejects stale, missing, unknown, and split canonical configuration" do
    for config <- [
          valid_config()
          |> Map.put(:verifier_key_path, "stale")
          |> Map.delete(:verifier_key_file),
          Map.delete(valid_config(), :totp_key_file),
          Map.put(valid_config(), :unknown_security_key, true)
        ] do
      assert {:error, {:local_not_ready, findings}} = Readiness.inspect(config, probes("unused"))
      assert :local_config_keys_invalid in findings
      assert findings == Enum.sort(findings)
    end

    Application.put_env(:origen, :bootstrap_admin_local_config, valid_config())

    try do
      assert {:error, {:local_not_ready, split_findings}} =
               Readiness.inspect(
                 Application.get_env(:origen, :bootstrap_admin_local, %{}),
                 probes("unused")
               )

      assert :local_config_keys_invalid in split_findings
      assert :profile_invalid in split_findings
    after
      Application.delete_env(:origen, :bootstrap_admin_local_config)
    end
  end

  test "returns a redacted ready type after metadata-only probes" do
    assert {:ok, ready} = Readiness.inspect(valid_config(), probes("unused"))
    refute inspect(ready) =~ "student@example.test"
    refute inspect(ready) =~ "certificate-canary"
    assert_receive {:lstat, "certificate-canary"}
    assert_receive {:lstat, "certificate-key-canary"}
    assert_receive {:lstat, "verifier-canary"}
    assert_receive {:lstat, "totp-canary"}
    refute_receive {:protected_boundary, _}
  end

  test "rejects retention outside the one-to-nine-hundred-second range" do
    for ttl <- [0, 901] do
      assert {:error, {:local_not_ready, findings}} =
               Readiness.inspect(%{valid_config() | retention_ttl_seconds: ttl}, probes("unused"))

      assert :mailbox_retention_invalid in findings
    end
  end

  test "malformed binary activation origins return sanitized sorted findings" do
    origin = <<"https://127.0.0.1:4443/", 255>>

    raising_probes =
      Map.put(probes("unused"), :uri_parse, fn ^origin -> raise "origin-canary: #{origin}" end)

    assert {:error, {:local_not_ready, findings}} =
             Readiness.inspect(%{valid_config() | activation_origin: origin}, raising_probes)

    assert findings == Enum.sort(findings)
    assert :activation_origin_invalid in findings
    assert :endpoint_port_mismatch in findings
    refute inspect(findings) =~ inspect(origin)
  end

  test "unavailable current-directory metadata returns sanitized sorted findings" do
    for result <- [:error, :raise] do
      probes = %{
        lstat: fn _ -> {:ok, %File.Stat{type: :regular, size: 1, mode: 0o600, uid: 1}} end,
        current_uid: fn -> if result == :raise, do: raise("uid-canary"), else: result end
      }

      assert {:error, {:local_not_ready, findings}} = Readiness.inspect(valid_config(), probes)
      assert findings == Enum.sort(findings)

      assert findings ==
               ~w(certificate_source_unavailable totp_source_unavailable verifier_source_unavailable)a

      refute inspect(findings) =~ "uid-canary"
    end
  end

  test "normalizes unavailable, malformed, and raising certificate metadata" do
    for result <- [
          :error,
          {:ok, %{type: :symlink, size: 1, mode: 0o600, owner: :current_user}},
          :raise
        ] do
      probe = fn _path -> if result == :raise, do: raise("metadata-canary"), else: result end

      assert {:error, {:local_not_ready, findings}} =
               Readiness.inspect(valid_config(), %{lstat: probe})

      assert :certificate_source_unavailable in findings
      refute inspect(findings) =~ "metadata-canary"
    end
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
      database_name: "origen_dev",
      database_scope: :isolated_workstation
    }
  end

  defp probes(secret) do
    %{
      lstat: fn path ->
        send(self(), {:lstat, path})
        if path == "verifier-canary" and secret != "unused", do: :error, else: {:ok, metadata()}
      end,
      repo: fn -> send(self(), {:protected_boundary, secret}) end,
      fetch: fn -> send(self(), {:protected_boundary, secret}) end,
      start: fn -> send(self(), {:protected_boundary, secret}) end,
      mailbox: fn -> send(self(), {:protected_boundary, secret}) end,
      message: fn -> send(self(), {:protected_boundary, secret}) end,
      token: fn -> send(self(), {:protected_boundary, secret}) end,
      output: fn -> send(self(), {:protected_boundary, secret}) end
    }
  end

  defp metadata, do: %{type: :regular, size: 1, mode: 0o600, owner: :current_user}
end
