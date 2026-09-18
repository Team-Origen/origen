defmodule Origen.BootstrapAdmin.Verifier do
  @moduledoc "CSPRNG invitation tokens represented by versioned keyed digests."

  @version "v1"

  def issue(key) when is_binary(key) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    %{token: token, verifier_version: @version, verifier_digest: digest(token, key)}
  end

  def digest(token, key) when is_binary(token) and is_binary(key) and byte_size(key) >= 32 do
    :crypto.mac(:hmac, :sha256, key, @version <> ":" <> token)
  end

  def digest(_token, _key), do: :error

  def verify(token, @version, expected, key)
      when is_binary(token) and is_binary(expected) and is_binary(key) do
    case digest(token, key) do
      digest when is_binary(digest) and byte_size(digest) == byte_size(expected) ->
        Plug.Crypto.secure_compare(digest, expected)

      _ ->
        false
    end
  end

  def verify(_token, _version, _expected, _key), do: false
end
