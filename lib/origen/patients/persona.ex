defmodule Origen.Patients.Persona do
  @moduledoc """
  Ecto schema for physical human identity (Persona) according to RF-02.
  Enforces uniqueness by document type and normalized document number.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @controlled_document_types ~w(dni passport identity_card other)

  @primary_key {:id, :id, autogenerate: true}
  schema "personas" do
    field :first_name, :string
    field :last_name, :string
    field :document_type, :string
    field :document_number, :string
    field :birthdate, :date
    field :gender, :string

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime_usec)
  end

  def document_types, do: @controlled_document_types

  @doc false
  def changeset(persona, attrs) do
    persona
    |> cast(attrs, [
      :first_name,
      :last_name,
      :document_type,
      :document_number,
      :birthdate,
      :gender
    ])
    |> validate_required([:first_name, :last_name, :document_type, :document_number, :birthdate])
    |> validate_inclusion(:document_type, @controlled_document_types)
    |> normalize_document_number()
    |> validate_format(:document_number, ~r/^[A-Za-z0-9]{1,32}$/)
    |> validate_birthdate_in_past()
    |> unique_constraint([:document_type, :document_number], name: :personas_document_unique)
  end

  def normalize_number(nil), do: nil

  def normalize_number(number) when is_binary(number) do
    number
    |> String.replace(~r/[-.\s]/, "")
    |> String.upcase()
  end

  defp normalize_document_number(changeset) do
    case get_change(changeset, :document_number) do
      nil ->
        changeset

      number when is_binary(number) ->
        put_change(changeset, :document_number, normalize_number(number))
    end
  end

  defp validate_birthdate_in_past(changeset) do
    validate_change(changeset, :birthdate, fn _, date ->
      if Date.compare(date, Date.utc_today()) == :lt do
        []
      else
        [birthdate: "debe ser una fecha en el pasado"]
      end
    end)
  end
end
