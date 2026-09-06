defmodule Origen.BootstrapAdmin.PrimitivesTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.{Credentials, Gate, Redaction, Verifier}

  @key :crypto.hash(:sha256, "test invitation key")
  @seed :crypto.strong_rand_bytes(20)

  test "gate is exact, fail-closed, and production-denied" do
    assert Gate.allowed?(true, :dev)
    refute Gate.allowed?(false, :dev)
    refute Gate.allowed?("true", :dev)
    refute Gate.allowed?(nil, :dev)
    refute Gate.allowed?(true, :prod)
  end

  test "verifier generates a raw token and only persists a keyed versioned digest" do
    issue = Verifier.issue(@key)
    assert %{token: token, verifier_version: "v1", verifier_digest: digest} = issue
    assert is_binary(token) and byte_size(token) >= 32
    refute Map.has_key?(issue, :raw_token)
    assert Verifier.verify(token, "v1", digest, @key)
    refute Verifier.verify(token <> "x", "v1", digest, @key)
    refute Verifier.verify(token, "v1", digest, :crypto.strong_rand_bytes(32))
  end

  test "passwords use Argon2id PHC hashes and TOTP seeds use tagged authenticated encryption" do
    hash = Credentials.hash_password("correct horse battery staple")
    assert String.starts_with?(hash, "$argon2id$")
    assert Credentials.verify_password("correct horse battery staple", hash)
    refute Credentials.verify_password("wrong", hash)
    assert {:ok, ciphertext} = Credentials.encrypt_seed(@seed, @key)
    assert ciphertext != @seed
    assert {:ok, @seed} = Credentials.decrypt_seed(ciphertext, @key)
    assert {:ok, seed} = Credentials.new_totp_seed()
    assert byte_size(seed) == 20
  end

  test "keyring rejects duplicate or malformed tags and decrypts retained keys" do
    retired = %{
      active: %{tag: "seed.v2", key: :crypto.strong_rand_bytes(32)},
      retired: [%{tag: "seed.v1", key: @key}]
    }

    assert {:ok, ciphertext} = Credentials.encrypt_seed(@seed, retired)
    assert {:ok, @seed} = Credentials.decrypt_seed(ciphertext, retired)

    assert {:error, :invalid_keyring} =
             Credentials.validate_keyring(%{
               active: %{tag: "x", key: @key},
               retired: [%{tag: "x", key: @key}]
             })

    assert {:error, :invalid_keyring} =
             Credentials.validate_keyring(%{active: %{tag: "x", key: "short"}, retired: []})
  end

  test "redaction rejects secret fields and token-like references before sinks" do
    assert {:ok, %{event: "bootstrap", result: "denied", account_ref: "42"}} =
             Redaction.sanitize(%{event: "bootstrap", result: "denied", account_ref: "42"})

    assert {:error, :sensitive_field} = Redaction.sanitize(%{password: "secret"})
    assert {:error, :sensitive_field} = Redaction.sanitize(%{"password" => "secret"})
    assert {:error, :sensitive_field} = Redaction.sanitize(%{token: "bearer-token"})
    assert {:error, :sensitive_reference} = Redaction.sanitize(%{account_ref: "https://x/token"})
  end
end
