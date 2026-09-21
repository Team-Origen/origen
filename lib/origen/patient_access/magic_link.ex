defmodule Origen.PatientAccess.MagicLink do
  @moduledoc """
  Ecto schema for patient passwordless access tokens (Magic Links).
  Stores cryptographic token digests, target email, expiration, and consumption timestamp.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "patient_magic_links" do
    field :email, :string
    field :token_digest, :binary
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(magic_link, attrs) do
    magic_link
    |> cast(attrs, [:email, :token_digest, :expires_at, :consumed_at])
    |> validate_required([:email, :token_digest, :expires_at])
    |> validate_format(:email, ~r/^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+.[a-zA-Z0-9-.]+$/)
    |> validate_digest_size(:token_digest)
    |> unique_constraint(:token_digest, name: :patient_magic_links_token_digest_idx)
  end

  defp validate_digest_size(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      if is_binary(value) and byte_size(value) == 32 do
        []
      else
        [{field, "must be a 32-byte SHA-256 digest"}]
      end
    end)
  end
end
