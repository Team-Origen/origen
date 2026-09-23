defmodule Origen.Bookings.Appointment do
  @moduledoc """
  Ecto schema for appointments (turnos).

  Represents a booked appointment with all snapshots, state, and audit trail.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type state :: :solicitado | :reservado | :confirmado | :asistio | :cancelado | :no_asistio
  @type actor :: :patient | :secretary | :professional

  @valid_states ~w(solicitado reservado confirmado asistio cancelado no_asistio)a
  @valid_actors ~w(patient secretary professional)a

  schema "appointments" do
    belongs_to :professional, Origen.Accounts.InternalAccount, foreign_key: :professional_id, references: :id
    belongs_to :patient, Origen.Patients.Patient, foreign_key: :patient_id, references: :id
    field :consultation_type_id, :binary_id
    field :consultation_type_snapshot, :map
    field :agenda_interval_minutes, :integer
    field :starts_at, :utc_datetime_usec
    field :ends_at, :utc_datetime_usec
    field :state, Ecto.Enum, values: @valid_states
    field :booked_by_actor, Ecto.Enum, values: @valid_actors
    field :booked_by_account_id, :integer
    field :confirmed_at, :utc_datetime_usec
    field :cancelled_at, :utc_datetime_usec
    field :cancellation_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a new appointment.
  Validates required fields, state, actor, and datetime ordering.
  """
  @spec create_changeset(__MODULE__, map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = appointment, attrs) do
    appointment
    |> cast(attrs, [
      :professional_id,
      :patient_id,
      :consultation_type_id,
      :consultation_type_snapshot,
      :agenda_interval_minutes,
      :starts_at,
      :ends_at,
      :state,
      :booked_by_actor,
      :booked_by_account_id
    ])
    |> validate_required([
      :professional_id,
      :patient_id,
      :consultation_type_id,
      :consultation_type_snapshot,
      :agenda_interval_minutes,
      :starts_at,
      :ends_at,
      :state,
      :booked_by_actor,
      :booked_by_account_id
    ])
    |> validate_state()
    |> validate_actor()
    |> validate_datetime_order()
    |> validate_snapshot_structure()
    |> unique_constraint(:consultation_type_id, name: :appointments_consultation_type_id_fkey)
    |> foreign_key_constraint(:professional_id, name: :appointments_professional_id_fkey)
    |> foreign_key_constraint(:patient_id, name: :appointments_patient_id_fkey)
    |> foreign_key_constraint(:booked_by_account_id, name: :appointments_booked_by_account_id_fkey)
  end

  @doc """
  Changeset for updating an appointment (non-state fields).
  """
  @spec update_changeset(__MODULE__, map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = appointment, attrs) do
    appointment
    |> cast(attrs, [
      :confirmed_at,
      :cancelled_at,
      :cancellation_reason
    ])
    |> validate_datetime_order()
  end

  @doc """
  Changeset for state transitions.
  Validates that the transition is allowed per the state machine.
  """
  @spec state_transition_changeset(__MODULE__, map(), atom()) :: Ecto.Changeset.t()
  def state_transition_changeset(%__MODULE__{} = appointment, attrs, from_state) do
    allowed_transitions = %{
      solicitado: [:reservado, :cancelado],
      reservado: [:confirmado, :cancelado],
      confirmado: [:asistio, :no_asistio, :cancelado],
      asistio: [],
      no_asistio: [],
      cancelado: []
    }

    to_state = attrs[:state] |> Map.get(:state, nil) |> (fn
      nil -> nil
      s when is_atom(s) -> s
      s when is_binary(s) -> String.to_atom(s)
    end).()

    if to_state in (allowed_transitions[from_state] || []) do
      appointment
      |> cast(attrs, [:state, :confirmed_at, :cancelled_at, :cancellation_reason])
      |> validate_required([:state])
      |> validate_state()
    else
      appointment
      |> cast(attrs, [:state])
      |> add_error(:state, "invalid transition from #{from_state} to #{to_state}")
    end
  end

  @doc """
  Returns the current state as an atom.
  """
  @spec current_state(__MODULE__) :: state()
  def current_state(%__MODULE__{state: state}), do: state

  @doc """
  Checks if the appointment is in a terminal state.
  """
  @spec terminal?(__MODULE__) :: boolean()
  def terminal?(%__MODULE__{state: state}) do
    state in [:asistio, :no_asistio, :cancelado]
  end

  @doc """
  Checks if the appointment is active (can be confirmed or cancelled).
  """
  @spec active?(__MODULE__) :: boolean()
  def active?(%__MODULE__{state: state}) do
    state in [:solicitado, :reservado, :confirmado]
  end

  @doc """
  Returns the duration in minutes.
  """
  @spec duration_minutes(__MODULE__) :: integer()
  def duration_minutes(%__MODULE__{starts_at: starts_at, ends_at: ends_at}) do
    DateTime.diff(ends_at, starts_at, :minute) |> round()
  end

  # Private validation functions

  defp validate_state(changeset) do
    validate_inclusion(changeset, :state, @valid_states, message: "invalid state")
  end

  defp validate_actor(changeset) do
    validate_inclusion(changeset, :booked_by_actor, @valid_actors, message: "invalid actor")
  end

  defp validate_datetime_order(changeset) do
    validate_change(changeset, :ends_at, fn :ends_at, ends_at ->
      starts_at = get_field(changeset, :starts_at)

      cond do
        is_nil(starts_at) or is_nil(ends_at) ->
          []

        ends_at <= starts_at ->
          [ends_at: "must be after starts_at"]

        true ->
          []
      end
    end)
  end

  defp validate_snapshot_structure(changeset) do
    validate_change(changeset, :consultation_type_snapshot, fn :consultation_type_snapshot, snapshot ->
      cond do
        not is_map(snapshot) ->
          [consultation_type_snapshot: "must be a map"]

        not Map.has_key?(snapshot, "name") or not is_binary(snapshot["name"]) ->
          [consultation_type_snapshot: "missing or invalid 'name'"]

        not Map.has_key?(snapshot, "duration_minutes") or not is_integer(snapshot["duration_minutes"]) ->
          [consultation_type_snapshot: "missing or invalid 'duration_minutes'"]

        not Map.has_key?(snapshot, "price_ars") ->
          [consultation_type_snapshot: "missing 'price_ars'"]

        true ->
          []
      end
    end)
  end
end