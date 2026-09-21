defmodule Origen.Patients.PhoneVerificationChallenge do
  @moduledoc """
  Schema representing a phone verification challenge.
  Never persists plain verification codes; only stores SHA-256 code hashes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_states ["pending", "consumed", "expired", "max_attempts_exceeded"]

  schema "phone_verification_challenges" do
    field :phone, :string
    field :code_hash, :string
    field :state, :string, default: "pending"
    field :attempts_count, :integer, default: 0
    field :expires_at, :utc_datetime_usec

    belongs_to :patient_profile, Origen.Patients.PatientProfile

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def valid_states, do: @valid_states

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [
      :patient_profile_id,
      :phone,
      :code_hash,
      :state,
      :attempts_count,
      :expires_at,
      :created_at,
      :updated_at
    ])
    |> validate_required([
      :patient_profile_id,
      :phone,
      :code_hash,
      :state,
      :attempts_count,
      :expires_at
    ])
    |> validate_inclusion(:state, @valid_states)
    |> validate_length(:code_hash, is: 64)
    |> validate_number(:attempts_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:patient_profile_id)
  end
end
