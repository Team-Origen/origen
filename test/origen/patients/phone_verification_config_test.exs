defmodule Origen.Patients.PhoneVerificationConfigTest do
  use ExUnit.Case, async: true

  alias Origen.Patients.PhoneVerificationConfig

  describe "security parameters and constants" do
    test "defines expected challenge constraints" do
      assert PhoneVerificationConfig.code_length() == 6
      assert PhoneVerificationConfig.code_ttl_seconds() == 600
      assert PhoneVerificationConfig.max_attempts() == 3
      assert PhoneVerificationConfig.resend_cooldown_seconds() == 60
      assert PhoneVerificationConfig.max_hourly_requests() == 5
    end
  end

  describe "generate_code/0" do
    test "generates a 6-digit numeric string" do
      code = PhoneVerificationConfig.generate_code()

      assert is_binary(code)
      assert String.length(code) == 6
      assert Regex.match?(~r/^[0-9]{6}$/, code)
    end

    test "generates pseudorandom values across calls" do
      codes = for _ <- 1..10, do: PhoneVerificationConfig.generate_code()
      unique_codes = Enum.uniq(codes)

      assert length(unique_codes) > 1
    end
  end

  describe "hash_code/1 and verify_code_hash/2" do
    test "hashes code with lowercase SHA-256" do
      code = "123456"
      hash = PhoneVerificationConfig.hash_code(code)

      assert is_binary(hash)
      assert String.length(hash) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hash)
      assert hash == :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)
    end

    test "verifies code hash in constant-time" do
      code = "849201"
      hash = PhoneVerificationConfig.hash_code(code)

      assert PhoneVerificationConfig.verify_code_hash(code, hash) == true
      assert PhoneVerificationConfig.verify_code_hash("000000", hash) == false
      assert PhoneVerificationConfig.verify_code_hash("849202", hash) == false
      assert PhoneVerificationConfig.verify_code_hash(nil, hash) == false
      assert PhoneVerificationConfig.verify_code_hash(code, nil) == false
    end
  end

  describe "sanitize_phone/1" do
    test "masks phone numbers preserving only prefix and last 4 digits" do
      assert PhoneVerificationConfig.sanitize_phone("+5491133445566") == "+54...5566"
      assert PhoneVerificationConfig.sanitize_phone("  +54 9 11 3344 5566  ") == "+54...5566"
    end

    test "safely masks short or non-standard phone numbers" do
      assert PhoneVerificationConfig.sanitize_phone("123") == "***"
      assert PhoneVerificationConfig.sanitize_phone("") == "***"
      assert PhoneVerificationConfig.sanitize_phone(nil) == "***"
    end
  end

  describe "channel_for_environment/1 and validate_channel_config/1" do
    test "strictly allows :local_mailbox in :dev and :test" do
      assert PhoneVerificationConfig.channel_for_environment(:dev) == {:ok, :local_mailbox}
      assert PhoneVerificationConfig.channel_for_environment(:test) == {:ok, :local_mailbox}

      assert PhoneVerificationConfig.validate_channel_config(%{
               environment: :dev,
               channel: :local_mailbox
             }) == :ok

      assert PhoneVerificationConfig.validate_channel_config(%{
               environment: :test,
               channel: :local_mailbox
             }) == :ok
    end

    test "fails closed for production without explicit authorized adapter" do
      assert PhoneVerificationConfig.channel_for_environment(:prod) ==
               {:error, :production_channel_unauthorized}

      assert PhoneVerificationConfig.validate_channel_config(%{
               environment: :prod,
               channel: :local_mailbox
             }) == {:error, :production_channel_unauthorized}
    end

    test "rejects unauthorized external channels in local environments" do
      assert PhoneVerificationConfig.validate_channel_config(%{
               environment: :dev,
               channel: :twilio
             }) == {:error, :invalid_channel_config}

      assert PhoneVerificationConfig.validate_channel_config(%{
               environment: :dev,
               channel: :whatsapp_cloud_api
             }) == {:error, :invalid_channel_config}

      assert PhoneVerificationConfig.validate_channel_config(%{invalid: :config}) ==
               {:error, :invalid_channel_config}
    end
  end
end
