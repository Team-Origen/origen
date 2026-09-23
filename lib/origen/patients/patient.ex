defmodule Origen.Patients.Patient do
  @moduledoc """
  Ecto schema for patients.

  PAT-01: Authenticated via Google OAuth or Magic Link.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type provider :: :google | :magic_link

  schema "patients" do
    field :auth_subject, :string
    field :auth_provider, Ecto.Enum, values: [:google, :magic_link]
    field :profile_complete, :boolean, default: false
    field :phone_verified, :boolean, default: false
    field :primary_notification_phone, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a new patient.
  """
  @spec create_changeset(__MODULE__, map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = patient, attrs) do
    patient
    |> cast(attrs, [:auth_subject, :auth_provider, :profile_complete, :phone_verified, :primary_notification_phone])
    |> validate_required([:auth_subject, :auth_provider])
    |> validate_inclusion(:auth_provider, [:google, :magic_link])
    |> unique_constraint(:auth_subject, name: :patients_auth_subject_provider_unique)
  end

  @doc """
  Changeset for updating patient profile.
  """
  @spec update_changeset(__MODULE__, map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = patient, attrs) do
    patient
    |> cast(attrs, [:profile_complete, :phone_verified, :primary_notification_phone])
  end

  @doc """
  Returns true if the patient profile is complete.
  """
  @spec profile_complete?(__MODULE__) :: boolean()
  def profile_complete?(%__MODULE__{profile_complete: complete}), do: complete

  @doc """
  Returns true if the patient's primary notification phone is verified.
  """
  @spec phone_verified?(__MODULE__) :: boolean()
  def phone_verified?(%__MODULE__{phone_verified: verified}), do: verified
end