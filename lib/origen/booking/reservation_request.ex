defmodule Origen.Booking.ReservationRequest do
  @moduledoc """
  Contrato y validación sintáctica de entrada para solicitar una reserva (Issue #62 / PLN-08).

  Valida presencia, formato y tipos primitivos de Paciente, Profesional, Tipo de Consulta,
  Horario y Actor solicitante de manera *fail-fast*, rechazando estructuras mal formadas
  antes de que el sistema evalúe cualquier regla de negocio o toque la base de datos.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type role :: :patient | :secretary | :professional

  @type actor :: %{
          role: role(),
          id: pos_integer()
        }

  @type t :: %__MODULE__{
          actor: actor(),
          patient_id: pos_integer(),
          professional_id: pos_integer(),
          consultation_type_id: Ecto.UUID.t(),
          start_time: DateTime.t(),
          patient_agreed_schedule: boolean()
        }

  @primary_key false
  embedded_schema do
    field :patient_id, :integer
    field :professional_id, :integer
    field :consultation_type_id, Ecto.UUID
    field :start_time, :utc_datetime
    field :patient_agreed_schedule, :boolean, default: false

    embeds_one :actor, Actor, primary_key: false do
      field :role, Ecto.Enum, values: [:patient, :secretary, :professional]
      field :id, :integer
    end
  end

  @doc """
  Parsea y valida la estructura sintáctica de una solicitud de reserva.

  Retorna `{:ok, %ReservationRequest{}}` si los campos y tipos son válidos.
  Retorna `{:error, {:malformed_request, keyword_errors}}` si la estructura es inválida o faltan campos.
  """
  @spec cast_and_validate(term()) ::
          {:ok, t()} | {:error, {:malformed_request, keyword()}}
  def cast_and_validate(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = cs ->
        {:ok, apply_changes(cs)}

      %{valid?: false} = cs ->
        {:error, {:malformed_request, extract_errors(cs)}}
    end
  end

  def cast_and_validate(_invalid_payload) do
    {:error, {:malformed_request, [payload: {"must be a map", [validation: :cast]}]}}
  end

  @doc false
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :patient_id,
      :professional_id,
      :consultation_type_id,
      :start_time,
      :patient_agreed_schedule
    ])
    |> validate_required([
      :patient_id,
      :professional_id,
      :consultation_type_id,
      :start_time
    ])
    |> cast_embed(:actor, required: true, with: &actor_changeset/2)
  end

  defp actor_changeset(actor_schema, attrs) do
    actor_schema
    |> cast(attrs, [:role, :id])
    |> validate_required([:role, :id])
  end

  defp extract_errors(changeset) do
    traverse_errors(changeset, fn {msg, opts} ->
      {msg, opts}
    end)
    |> flatten_errors()
  end

  defp flatten_errors(nested_errors) do
    Enum.flat_map(nested_errors, fn
      {key, [%{} | _] = embeds} ->
        # Error en campos anidados (ej. actor)
        Enum.flat_map(embeds, fn embed_errs ->
          Enum.map(embed_errs, fn {_sub_key, val} -> {key, val} end)
        end)

      {key, %{} = map} ->
        Enum.map(map, fn {_sub_key, val} -> {key, val} end)

      {key, list} when is_list(list) ->
        Enum.map(list, fn val -> {key, val} end)

      {key, val} ->
        [{key, val}]
    end)
  end
end
