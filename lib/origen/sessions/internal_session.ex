defmodule Origen.Sessions.InternalSession do
  @moduledoc """
  Ecto schema for server-side internal account sessions.
  Stores cryptographic token digests, timestamps, and inactivity / maximum duration limits.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "internal_account_sessions" do
    field :account_id, :integer
    field :token_digest, :binary
    field :issued_at, :utc_datetime_usec
    field :last_activity_at, :utc_datetime_usec
    field :idle_timeout_seconds, :integer, default: 900
    field :max_duration_seconds, :integer, default: 43200
    field :revoked_at, :utc_datetime_usec

    timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :account_id,
      :token_digest,
      :issued_at,
      :last_activity_at,
      :idle_timeout_seconds,
      :max_duration_seconds,
      :revoked_at
    ])
    |> validate_required([:account_id, :token_digest, :issued_at, :last_activity_at])
    |> unique_constraint(:token_digest)
  end
end
