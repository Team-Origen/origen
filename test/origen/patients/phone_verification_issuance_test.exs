defmodule Origen.Patients.PhoneVerificationIssuanceTest do
  use Origen.DataCase

  import Ecto.Query
  import Swoosh.TestAssertions
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, PhoneVerificationChallenge, PhoneVerificationConfig}
  alias Origen.Repo

  @valid_email "paciente_tel@example.test"
  @valid_phone "+5491133445566"

  setup do
    Repo.delete_all(PhoneVerificationChallenge)
    Repo.delete_all(PatientProfile)

    {:ok, profile} = Patients.get_or_create_profile(@valid_email)
    %{profile: profile}
  end

  describe "request_phone_verification/3 - successful issuance and delivery" do
    test "creates challenge with SHA-256 hash, 10 min TTL, and delivers email via Swoosh", %{
      profile: profile
    } do
      now = ~U[2026-09-24 12:00:00Z]

      assert {:ok, %{challenge: challenge, delivery: :delivered}} =
               Patients.request_phone_verification(profile, @valid_phone, now: now)

      # 1. State and counters
      assert challenge.state == "pending"
      assert challenge.attempts_count == 0
      assert challenge.phone == @valid_phone
      assert challenge.patient_profile_id == profile.id
      assert String.length(challenge.code_hash) == 64

      # 2. Expiration is 10 minutes (600s)
      expected_expires_at = DateTime.add(now, 600, :second)
      assert DateTime.diff(challenge.expires_at, expected_expires_at) == 0

      # 3. Email sent via Swoosh local channel with 6-digit code
      assert_email_sent(fn email ->
        assert email.to == [{"", @valid_email}]
        assert email.subject == "Tu código de verificación telefónica de Origen"
        assert email.html_body =~ "+54...5566"

        [plain_code] = Regex.run(~r/[0-9]{6}/, email.text_body)

        # 4. Verify plain code matches stored hash, and plain code is NOT stored
        assert PhoneVerificationConfig.verify_code_hash(plain_code, challenge.code_hash) == true
        assert Repo.get_by(PhoneVerificationChallenge, code_hash: plain_code) == nil
        true
      end)

      # 5. Audit event logged
      audit_event =
        Repo.one(
          from a in "audit_events",
            where: a.event == "phone_challenge_issued",
            select: %{event: a.event, result: a.result, entity_ref: a.entity_ref}
        )

      assert audit_event != nil
      assert audit_event.result == "succeeded"
      assert audit_event.entity_ref == @valid_email
    end
  end

  describe "request_phone_verification/3 - rate limiting" do
    test "enforces 60-second cooldown between resend requests", %{profile: profile} do
      t0 = ~U[2026-09-24 12:00:00Z]

      assert {:ok, _} = Patients.request_phone_verification(profile, @valid_phone, now: t0)

      # Attempt at t0 + 30s -> cooldown active
      t1 = DateTime.add(t0, 30, :second)

      assert {:error, :cooldown_active} =
               Patients.request_phone_verification(profile, @valid_phone, now: t1)

      # Attempt at t0 + 61s -> allowed and marks previous challenge expired
      t2 = DateTime.add(t0, 61, :second)

      assert {:ok, %{challenge: new_challenge}} =
               Patients.request_phone_verification(profile, @valid_phone, now: t2)

      # Check previous challenge is now expired
      expired_count =
        Repo.aggregate(
          from(c in PhoneVerificationChallenge,
            where: c.patient_profile_id == ^profile.id and c.state == "expired"
          ),
          :count
        )

      assert expired_count == 1
      assert new_challenge.state == "pending"
    end

    test "enforces hourly limit of 5 requests per profile", %{profile: profile} do
      base_time = ~U[2026-09-24 12:00:00Z]

      # Perform 5 requests with 70s intervals (respecting cooldown)
      for i <- 0..4 do
        req_time = DateTime.add(base_time, i * 70, :second)

        assert {:ok, _} =
                 Patients.request_phone_verification(profile, @valid_phone, now: req_time)
      end

      # 6th request within the same hour is rejected
      req_time_6 = DateTime.add(base_time, 350, :second)

      assert {:error, :hourly_limit_exceeded} =
               Patients.request_phone_verification(profile, @valid_phone, now: req_time_6)
    end
  end

  describe "request_phone_verification/3 - validations" do
    test "rejects invalid or too short phone numbers", %{profile: profile} do
      assert {:error, :invalid_phone} = Patients.request_phone_verification(profile, "123")
      assert {:error, :invalid_phone} = Patients.request_phone_verification(profile, "")
      assert {:error, :invalid_phone} = Patients.request_phone_verification(profile, nil)
    end

    test "rejects non-existent profile email" do
      assert {:error, :profile_not_found} =
               Patients.request_phone_verification("unknown@example.test", @valid_phone)
    end
  end
end
