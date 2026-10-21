defmodule Origen.ProfessionalProfilesTest do
  use Origen.DataCase, async: false

  alias Origen.{Availability, ConsultationTypes, ProfessionalProfiles, Repo, Sessions}

  @fields ~w(first_name last_name specialty license_type license_number)a
  @complete %{
    first_name: "Ana",
    last_name: "Pérez",
    specialty: "Cardiología",
    license_type: "Provincial libre",
    license_number: "AB-001/x"
  }

  test "absence and partial saves remain incomplete and survive a new session" do
    owner = principal!()
    assert {:ok, nil} = ProfessionalProfiles.get_own_profile(owner)
    assert {:ok, profile} = ProfessionalProfiles.save_own_profile(owner, %{first_name: "  Ana  "})
    assert profile.first_name == "Ana"
    refute profile.complete?
    assert profile.owner_account_id == owner.account_id
    assert {:ok, ^profile} = ProfessionalProfiles.get_own_profile(new_session!(owner.account_id))
  end

  test "five declared text fields complete the profile without photo or credential verification" do
    owner = principal!()
    assert {:ok, profile} = ProfessionalProfiles.save_own_profile(owner, @complete)
    assert profile.complete?
    for field <- @fields, do: assert(Map.fetch!(profile, field) == Map.fetch!(@complete, field))
    refute Map.has_key?(profile, :photo)
    assert {:ok, ^profile} = ProfessionalProfiles.get_own_profile(owner)
  end

  test "each absent, empty or whitespace field prevents completeness and can be restored" do
    owner = principal!()

    for field <- @fields, missing <- [nil, "", " \t\n "] do
      assert {:ok, incomplete} =
               ProfessionalProfiles.save_own_profile(owner, Map.put(@complete, field, missing))

      refute incomplete.complete?
      assert Map.fetch!(incomplete, field) == nil

      assert {:ok, complete} =
               ProfessionalProfiles.save_own_profile(owner, %{
                 field => Map.fetch!(@complete, field)
               })

      assert complete.complete?
    end
  end

  test "rejects malformed and owner-supplied data without changing saved profile or settings" do
    owner = principal!()
    assert {:ok, before} = ProfessionalProfiles.save_own_profile(owner, @complete)
    assert {:ok, settings} = ConsultationTypes.get_own_configuration(owner)
    assert {:ok, availability} = Availability.get_own_configuration(owner)

    for attrs <- [
          nil,
          [],
          %{first_name: 123},
          %{"specialty" => %{}},
          %{owner_account_id: 12},
          %{"account_id" => 12}
        ] do
      assert {:error, {:validation, _}} = ProfessionalProfiles.save_own_profile(owner, attrs)
      assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(owner)
      assert {:ok, ^settings} = ConsultationTypes.get_own_configuration(owner)
      assert {:ok, ^availability} = Availability.get_own_configuration(owner)
    end
  end

  test "incomplete Professionals retain preparation and edits preserve existing settings" do
    owner = principal!()
    assert {:ok, settings} = ConsultationTypes.get_own_configuration(owner)
    assert {:ok, availability} = Availability.get_own_configuration(owner)
    assert {:ok, _} = ProfessionalProfiles.save_own_profile(owner, @complete)
    assert {:ok, profile} = ProfessionalProfiles.save_own_profile(owner, %{specialty: ""})
    refute profile.complete?
    assert {:ok, ^settings} = ConsultationTypes.get_own_configuration(owner)
    assert {:ok, ^availability} = Availability.get_own_configuration(owner)
  end

  test "denies Secretary, Administrator, invalid and forged principals without exposure or changes" do
    owner = principal!()
    other = principal!()
    assert {:ok, before} = ProfessionalProfiles.save_own_profile(owner, @complete)

    assert {:ok, other_before} =
             ProfessionalProfiles.save_own_profile(other, %{first_name: "Other"})

    assert {:ok, settings} = ConsultationTypes.get_own_configuration(owner)
    assert {:ok, availability} = Availability.get_own_configuration(owner)

    for denied <- [
          principal!(:secretary),
          principal!(:administrator),
          nil,
          %{},
          %{owner | account_id: other.account_id},
          %{other | account_id: owner.account_id}
        ] do
      assert {:error, :unauthorized} = ProfessionalProfiles.get_own_profile(denied)
      assert {:error, :unauthorized} = ProfessionalProfiles.save_own_profile(denied, @complete)
      assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(owner)
      assert {:ok, ^other_before} = ProfessionalProfiles.get_own_profile(other)
      assert {:ok, ^settings} = ConsultationTypes.get_own_configuration(owner)
      assert {:ok, ^availability} = Availability.get_own_configuration(owner)
    end
  end

  test "revalidates revoked, expired and inactive sessions before reads and writes" do
    for mutation <- [:revoked, :expired, :inactive] do
      owner = principal!()
      observer = new_session!(owner.account_id)
      assert {:ok, before} = ProfessionalProfiles.save_own_profile(owner, @complete)

      case mutation do
        :revoked ->
          Sessions.terminate_all_sessions(owner.account_id)

        :expired ->
          Repo.query!(
            "UPDATE internal_account_sessions SET issued_at = clock_timestamp() - interval '13 hours' WHERE id = $1",
            [owner.session_id]
          )

        :inactive ->
          Repo.query!(
            "UPDATE internal_accounts SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1",
            [owner.account_id]
          )
      end

      assert {:error, :unauthorized} = ProfessionalProfiles.get_own_profile(owner)

      assert {:error, :unauthorized} =
               ProfessionalProfiles.save_own_profile(owner, %{first_name: "Rejected"})

      if mutation == :inactive do
        Repo.query!(
          "UPDATE internal_accounts SET state = 'active', password_hash = 'hash', totp_secret = decode('0102','hex'), activated_at = NOW() WHERE id = $1",
          [owner.account_id]
        )
      end

      reader = if mutation == :expired, do: observer, else: new_session!(owner.account_id)
      assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(reader)
    end
  end

  defp principal!(role \\ :professional) do
    [[id]] =
      Repo.query!(
        "INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at) VALUES ($1, 'active', 'hash', decode('0102','hex'), NOW()) RETURNING id",
        [Atom.to_string(role)]
      ).rows

    new_session!(id)
  end

  defp new_session!(account_id) do
    {:ok, %{session: principal}} = Sessions.create_session(account_id)
    principal
  end
end
