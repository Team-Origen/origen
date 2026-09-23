defmodule Origen.Patients.PatientTest do
  @moduledoc """
  Tests for Origen.Patients.Patient schema and changesets.
  """

  use Origen.DataCase, async: true

  alias Origen.Patients.Patient

  @valid_attrs %{
    auth_subject: "google-oauth2|123456789",
    auth_provider: :google,
    profile_complete: true,
    phone_verified: true,
    primary_notification_phone: "+5491112345678"
  }

  @invalid_attrs %{
    auth_subject: nil,
    auth_provider: nil
  }

  describe "create_changeset/2" do
    test "validates required fields" do
      changeset = Patient.create_changeset(%Patient{}, @invalid_attrs)
      assert not changeset.valid?
      assert [:auth_subject, :auth_provider] == Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "validates auth_provider inclusion" do
      attrs = Map.put(@valid_attrs, :auth_provider, :invalid)
      changeset = Patient.create_changeset(%Patient{}, attrs)
      assert not changeset.valid?
      assert {:auth_provider, "is not included in the list"} in changeset.errors
    end

    test "accepts valid google provider" do
      attrs = Map.put(@valid_attrs, :auth_provider, :google)
      changeset = Patient.create_changeset(%Patient{}, attrs)
      assert changeset.valid?
    end

    test "accepts valid magic_link provider" do
      attrs = Map.put(@valid_attrs, :auth_provider, :magic_link)
      changeset = Patient.create_changeset(%Patient{}, attrs)
      assert changeset.valid?
    end

    test "enforces unique auth_subject per provider" do
      # This would need a database to test properly
      # Just verify the constraint is in the changeset
      changeset = Patient.create_changeset(%Patient{}, @valid_attrs)
      assert changeset.constraints |> Enum.any?(fn c -> c.name == :patients_auth_subject_provider_unique end)
    end
  end

  describe "update_changeset/2" do
    test "allows updating profile_complete" do
      patient = %Patient{profile_complete: false}
      changeset = Patient.update_changeset(patient, %{profile_complete: true})
      assert changeset.valid?
      assert get_change(changeset, :profile_complete) == true
    end

    test "allows updating phone_verified" do
      patient = %Patient{phone_verified: false}
      changeset = Patient.update_changeset(patient, %{phone_verified: true})
      assert changeset.valid?
      assert get_change(changeset, :phone_verified) == true
    end

    test "allows updating primary_notification_phone" do
      patient = %Patient{primary_notification_phone: nil}
      changeset = Patient.update_changeset(patient, %{primary_notification_phone: "+5491187654321"})
      assert changeset.valid?
      assert get_change(changeset, :primary_notification_phone) == "+5491187654321"
    end
  end

  describe "profile_complete?/1" do
    test "returns true when profile_complete is true" do
      patient = %Patient{profile_complete: true}
      assert Patient.profile_complete?(patient)
    end

    test "returns false when profile_complete is false" do
      patient = %Patient{profile_complete: false}
      assert not Patient.profile_complete?(patient)
    end
  end

  describe "phone_verified?/1" do
    test "returns true when phone_verified is true" do
      patient = %Patient{phone_verified: true}
      assert Patient.phone_verified?(patient)
    end

    test "returns false when phone_verified is false" do
      patient = %Patient{phone_verified: false}
      assert not Patient.phone_verified?(patient)
    end
  end
end