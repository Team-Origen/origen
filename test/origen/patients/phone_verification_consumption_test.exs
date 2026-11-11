defmodule Origen.Patients.PhoneVerificationConsumptionTest do
  use Origen.DataCase

  import Ecto.Query
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, PhoneVerificationChallenge}
  alias Origen.Repo

  @valid_email "paciente_consumo@example.test"
  @valid_phone "+5491133445566"
  @fixed_code "849201"

  setup do
    Repo.delete_all(PhoneVerificationChallenge)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Origen.Patients.Persona)

    {:ok, _} = Patients.get_or_create_profile(@valid_email)

    {:ok, %{profile: profile}} =
      Patients.complete_profile(@valid_email, %{
        first_name: "Ana María",
        last_name: "Gómez",
        document_type: "dni",
        document_number: "38123456",
        birthdate: ~D[1994-05-20],
        phone: @valid_phone
      })

    %{profile: profile}
  end

  describe "verify_phone_code/3 - successful consumption" do
    test "consumes challenge atomically and marks phone_verified: true", %{profile: profile} do
      {:ok, %{challenge: ch}} =
        Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)

      assert ch.state == "pending"
      assert profile.phone_verified == false

      assert {:ok, %{profile: updated_profile, challenge: consumed}} =
               Patients.verify_phone_code(profile, @fixed_code)

      assert consumed.state == "consumed"
      assert updated_profile.phone_verified == true

      # Corroborar en BD
      persisted_profile = Repo.get!(PatientProfile, profile.id)
      assert persisted_profile.phone_verified == true

      persisted_ch = Repo.get!(PhoneVerificationChallenge, ch.id)
      assert persisted_ch.state == "consumed"

      # Corroborar auditoría exitosa sin exponer secretos
      audit_event =
        Repo.one(
          from a in "audit_events",
            where: a.event == "phone_challenge_consumed" and a.entity_ref == @valid_email,
            select: %{event: a.event, result: a.result, entity_ref: a.entity_ref}
        )

      assert audit_event != nil
      assert audit_event.result == "succeeded"
    end

    test "prevents reutilization of already consumed challenge", %{profile: profile} do
      {:ok, _} = Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)
      assert {:ok, _} = Patients.verify_phone_code(profile, @fixed_code)

      # Segundo intento con el mismo código
      assert {:error, :challenge_consumed} = Patients.verify_phone_code(profile, @fixed_code)
    end
  end

  describe "verify_phone_code/3 - attempts limiting and errors" do
    test "increments attempts and locks upon reaching 3 failed attempts", %{profile: profile} do
      {:ok, %{challenge: ch}} =
        Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)

      # 1er fallo
      assert {:error, :invalid_code} = Patients.verify_phone_code(profile, "000000")
      assert Repo.get!(PhoneVerificationChallenge, ch.id).attempts_count == 1
      assert Repo.get!(PhoneVerificationChallenge, ch.id).state == "pending"

      # 2do fallo
      assert {:error, :invalid_code} = Patients.verify_phone_code(profile, "111111")
      assert Repo.get!(PhoneVerificationChallenge, ch.id).attempts_count == 2
      assert Repo.get!(PhoneVerificationChallenge, ch.id).state == "pending"

      # 3er fallo: excede el límite y se bloquea
      assert {:error, :max_attempts_exceeded} = Patients.verify_phone_code(profile, "222222")
      assert Repo.get!(PhoneVerificationChallenge, ch.id).attempts_count == 3
      assert Repo.get!(PhoneVerificationChallenge, ch.id).state == "max_attempts_exceeded"

      # 4to intento con el código correcto: rechazado por límite de intentos
      assert {:error, :max_attempts_exceeded} = Patients.verify_phone_code(profile, @fixed_code)

      # El teléfono sigue sin verificarse
      assert Repo.get!(PatientProfile, profile.id).phone_verified == false

      # Auditoría de fallo registrada
      failed_audit =
        Repo.one(
          from a in "audit_events",
            where: a.event == "phone_challenge_consumed" and a.result == "failed",
            limit: 1,
            select: %{id: a.id, event: a.event, result: a.result}
        )

      assert failed_audit != nil
    end

    test "rejects expired challenge and marks it as expired", %{profile: profile} do
      t0 = ~U[2026-09-24 12:00:00.000000Z]

      {:ok, %{challenge: ch}} =
        Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code, now: t0)

      # Tiempo después de 10 minutos (601 segundos)
      t_expired = DateTime.add(t0, 601, :second)

      assert {:error, :challenge_expired} =
               Patients.verify_phone_code(profile, @fixed_code, now: t_expired)

      assert Repo.get!(PhoneVerificationChallenge, ch.id).state == "expired"
      assert Repo.get!(PatientProfile, profile.id).phone_verified == false
    end

    test "validates challenge corresponds to the same phone number", %{profile: profile} do
      {:ok, _} = Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)

      # Cambiar el teléfono del perfil para simular discordancia
      profile
      |> Ecto.Changeset.change(%{phone: "+5491199998888"})
      |> Repo.update!()

      assert {:error, :phone_mismatch} = Patients.verify_phone_code(profile, @fixed_code)
      assert Repo.get!(PatientProfile, profile.id).phone_verified == false
    end

    test "rejects malformed codes", %{profile: profile} do
      assert {:error, :invalid_code} = Patients.verify_phone_code(profile, "123")
      assert {:error, :invalid_code} = Patients.verify_phone_code(profile, "")
      assert {:error, :invalid_code} = Patients.verify_phone_code(profile, "abcdef")
      assert {:error, :invalid_code} = Patients.verify_phone_code(profile, nil)
    end
  end
end
