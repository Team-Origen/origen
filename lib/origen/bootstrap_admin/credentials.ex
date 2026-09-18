defmodule Origen.BootstrapAdmin.Credentials do
  @moduledoc "Password and authenticated TOTP seed primitives."

  alias Cloak.Ciphers.AES.GCM

  def hash_password(password) when is_binary(password), do: Argon2.hash_pwd_salt(password)

  def verify_password(password, hash) when is_binary(password) and is_binary(hash),
    do: Argon2.verify_pass(password, hash)

  def verify_password(_, _), do: false

  def new_totp_seed, do: {:ok, NimbleTOTP.secret()}

  def validate_keyring(%{active: %{tag: tag, key: key}, retired: retired})
      when is_binary(tag) and is_binary(key) and byte_size(key) == 32 and is_list(retired) do
    keys = [%{tag: tag, key: key} | retired]

    if Enum.all?(keys, &valid_key?/1) and length(Enum.uniq_by(keys, & &1.tag)) == length(keys),
      do: :ok,
      else: {:error, :invalid_keyring}
  end

  def validate_keyring(_), do: {:error, :invalid_keyring}

  def encrypt_seed(seed, keyring) when is_binary(seed) and is_binary(keyring),
    do: encrypt_seed(seed, %{active: %{tag: "seed.v1", key: keyring}, retired: []})

  def encrypt_seed(seed, keyring) when is_binary(seed) do
    with :ok <- validate_keyring(keyring),
         %{active: %{tag: tag, key: key}} <- keyring do
      GCM.encrypt(seed, tag: tag, key: key, iv_length: 12)
    else
      _ -> {:error, :invalid_keyring}
    end
  end

  def encrypt_seed(_seed, _keyring), do: {:error, :invalid_seed}

  def decrypt_seed(ciphertext, keyring) when is_binary(ciphertext) and is_binary(keyring),
    do: decrypt_seed(ciphertext, %{active: %{tag: "seed.v1", key: keyring}, retired: []})

  def decrypt_seed(ciphertext, keyring) when is_binary(ciphertext) do
    with :ok <- validate_keyring(keyring) do
      Enum.find_value([keyring.active | keyring.retired], {:error, :undecryptable}, fn %{
                                                                                         tag: tag,
                                                                                         key: key
                                                                                       } ->
        case GCM.can_decrypt?(ciphertext, tag: tag, key: key, iv_length: 12) do
          true -> GCM.decrypt(ciphertext, tag: tag, key: key, iv_length: 12)
          false -> nil
        end
      end)
    end
  end

  defp valid_key?(%{tag: tag, key: key}),
    do: is_binary(tag) and tag != "" and is_binary(key) and byte_size(key) == 32

  defp valid_key?(_), do: false
end
