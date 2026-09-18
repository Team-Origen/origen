defmodule Origen.BootstrapAdmin.Local.SecretsTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Local.Secrets

  setup do
    Application.put_env(:origen, :bootstrap_admin_verifier_key, {:file, "test_verifier.key"})
    Application.put_env(:origen, :bootstrap_admin_totp_keyring, {:file, "test_totp.key"})

    valid_key = Base.encode64(:crypto.strong_rand_bytes(32))
    File.write!("test_verifier.key", valid_key)
    File.write!("test_totp.key", valid_key)
    File.chmod!("test_verifier.key", 0o600)
    File.chmod!("test_totp.key", 0o600)

    on_exit(fn ->
      File.rm("test_verifier.key")
      File.rm("test_totp.key")
      Application.delete_env(:origen, :bootstrap_admin_verifier_key)
      Application.delete_env(:origen, :bootstrap_admin_totp_keyring)
    end)
  end

  test "get_verifier_key/0 reads and decodes the verifier key securely" do
    assert {:ok, key} = Secrets.get_verifier_key(%{verifier_key_file: "test_verifier.key"})
    assert byte_size(key) == 32
  end

  test "get_totp_keyring/0 reads and structures the totp keyring" do
    assert {:ok, %{active: %{tag: "local.dev.v1", key: key}, retired: []}} =
             Secrets.get_totp_keyring(%{
               totp_key_file: "test_totp.key",
               totp_key_tag: "local.dev.v1"
             })

    assert byte_size(key) == 32
  end

  test "handles missing config gracefully" do
    assert {:error, :secrets_unavailable} = Secrets.get_verifier_key(%{})
  end

  test "handles oversized files safely" do
    File.write!("test_verifier.key", String.duplicate("a", 5000))

    assert {:error, :secrets_unavailable} =
             Secrets.get_verifier_key(%{verifier_key_file: "test_verifier.key"})
  end

  test "never logs or returns key contents on invalid encoding" do
    File.write!("test_verifier.key", "invalid base64 content !@#$")

    assert {:error, :secrets_unavailable} =
             Secrets.get_verifier_key(%{verifier_key_file: "test_verifier.key"})
  end
end
