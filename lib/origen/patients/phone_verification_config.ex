defmodule Origen.Patients.PhoneVerificationConfig do
  @moduledoc """
  Pure configuration, security parameters, and fail-closed validation
  for phone verification challenges under PLN-15 / subissue #88.
  """

  @code_length 6
  @code_ttl_seconds 600
  @max_attempts 3
  @resend_cooldown_seconds 60
  @max_hourly_requests 5

  @doc "Returns the length in digits for the challenge code."
  def code_length, do: @code_length

  @doc "Returns the time-to-live in seconds for a challenge (10 minutes)."
  def code_ttl_seconds, do: @code_ttl_seconds

  @doc "Returns the maximum number of failed attempts allowed."
  def max_attempts, do: @max_attempts

  @doc "Returns the cooldown in seconds before allowing a code resend."
  def resend_cooldown_seconds, do: @resend_cooldown_seconds

  @doc "Returns the maximum number of challenge requests per hour."
  def max_hourly_requests, do: @max_hourly_requests

  @doc """
  Generates a cryptographically strong random 6-digit numeric code.
  """
  def generate_code do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(900_000)
    |> Kernel.+(100_000)
    |> Integer.to_string()
  end

  @doc """
  Computes a secure SHA-256 hash of the plain verification code.
  Never stores the plain code in persistent storage.
  """
  def hash_code(code) when is_binary(code) do
    :crypto.hash(:sha256, String.trim(code))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Constant-time comparison between a user-supplied code and the stored hash.
  Mitigates timing attacks.
  """
  def verify_code_hash(code, expected_hash)
      when is_binary(code) and is_binary(expected_hash) do
    computed_hash = hash_code(code)
    Plug.Crypto.secure_compare(computed_hash, expected_hash)
  end

  def verify_code_hash(_code, _expected_hash), do: false

  @doc """
  Masks a phone number for safe logging and audit records.
  Never outputs the full phone number.
  E.g. "+5491133445566" -> "+54...5566"
  """
  def sanitize_phone(phone) when is_binary(phone) do
    cleaned = phone |> String.trim() |> String.replace(~r/s+/, "")
    len = String.length(cleaned)

    if len <= 4 do
      "***"
    else
      prefix = String.slice(cleaned, 0..2)
      suffix = String.slice(cleaned, (len - 4)..(len - 1))
      "#{prefix}...#{suffix}"
    end
  end

  def sanitize_phone(_), do: "***"

  @doc """
  Resolves the delivery channel according to the environment.
  In :dev and :test, strictly uses :local_mailbox (Swoosh local adapter).
  In :prod, requires explicit authorized provider configuration.
  """
  def channel_for_environment(env) when env in [:dev, :test], do: {:ok, :local_mailbox}
  def channel_for_environment(:prod), do: {:error, :production_channel_unauthorized}
  def channel_for_environment(_), do: {:error, :invalid_environment}

  @doc """
  Fail-closed validation of channel configuration.
  Ensures no unapproved external providers are accepted in local environments.
  """
  def validate_channel_config(%{environment: env, channel: :local_mailbox})
      when env in [:dev, :test],
      do: :ok

  def validate_channel_config(%{environment: :prod}),
    do: {:error, :production_channel_unauthorized}

  def validate_channel_config(_), do: {:error, :invalid_channel_config}
end
