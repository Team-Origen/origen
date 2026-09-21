defmodule Origen.Patients.PatientProfile do
  @moduledoc """
  Ecto schema for patient profile linked to an access account (email) and optionally to a Persona.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @states ~w(pending_completion completed pending_secretary_review)

  @primary_key {:id, :id, autogenerate: true}
  schema "patient_profiles" do
    field :email, :string
    field :state, :string, default: "pending_completion"
    field :phone, :string
    field :phone_verified, :boolean, default: false
    field :collision_detected_at, :utc_datetime_usec
    field :collision_notes, :string

    belongs_to :persona, Origen.Patients.Persona

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime_usec)
  end

  def states, do: @states

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :email,
      :persona_id,
      :state,
      :phone,
      :phone_verified,
      :collision_detected_at,
      :collision_notes
    ])
    |> validate_required([:email, :state])
    |> validate_inclusion(:state, @states)
    |> unique_constraint(:email)
  end
end
