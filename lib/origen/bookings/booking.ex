defmodule Origen.Bookings.Booking do
  @moduledoc """
  Public API for booking operations.

  Provides:
  - create_booking/2 — Creates a new appointment with atomic persistence
  - transition_state/3 — Transitions appointment state
  - get_booking/1 — Fetches appointment by ID
  - list_bookings/2 — Lists appointments with filters
  """

  import Ecto.Query, only: [where: 3, order_by: 2, limit: 2, offset: 2]

  alias Origen.Repo
  alias Origen.Bookings.Appointment
  alias Origen.Bookings.Validators
  alias Origen.Bookings.Snapshots
  alias Origen.Bookings.StateMachine
  alias Origen.Bookings.Relationship
  alias Origen.Bookings.Errors
  alias Origen.Audit.{Events, Writer}

  @type actor :: %{
          type: :patient | :secretary | :professional,
          account_id: integer(),
          patient_id: integer() | nil,
          profile_complete: boolean() | nil,
          phone_verified: boolean() | nil,
          own_profile: boolean() | nil,
          center_scope_valid: boolean() | nil,
          minimum_identity_complete: boolean() | nil,
          allowed_patient_ids: [integer()] | nil,
          professional_reference: String.t() | nil
        }

  @type booking_params :: %{
          professional_id: integer(),
          patient_id: integer(),
          consultation_type_id: binary(),
          starts_at: DateTime.t(),
          ends_at: DateTime.t(),
          initial_state: atom() | nil,
          modality: atom() | nil,
          agreement_declaration: boolean() | nil,
          is_first_booking: boolean() | nil
        }

  @doc """
  Creates a new booking with full validation and atomic persistence.

  ## Flow:
  1. Run validation pipeline (auth, eligibility, type, availability, D-1 window)
  2. Acquire advisory locks
  3. Atomic transaction: appointment + relationship + audit
  4. Return created appointment

  Returns {:ok, %Appointment{}} | {:error, Errors.t()}
  """
  @spec create_booking(actor(), booking_params()) ::
          {:ok, Appointment.t()} | {:error, Errors.t()}
  def create_booking(actor, params) do
    with {:ok, validated_params} <- Validators.validate_booking(actor, params),
         {:ok, appointment} <- persist_booking(actor, validated_params) do
      {:ok, appointment}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Transitions an appointment to a new state.

  Validates the transition is allowed per the state machine.
  """
  @spec transition_state(Appointment.t(), atom(), actor()) ::
          {:ok, Appointment.t()} | {:error, Errors.t()}
  def transition_state(appointment, new_state, _actor) do
    current_state = Appointment.current_state(appointment)

    case StateMachine.transition(current_state, new_state) do
      {:ok, _valid_state} ->
        update_appointment_state(appointment, new_state)

      {:error, :invalid_transition} ->
        {:error, {:state_transition_invalid, current_state, new_state}}
    end
  end

  @doc """
  Fetches an appointment by ID.
  """
  @spec get_booking(integer()) :: {:ok, Appointment.t()} | {:error, :not_found}
  def get_booking(id) do
    case Repo.get(Appointment, id) do
      nil -> {:error, :not_found}
      appointment -> {:ok, appointment}
    end
  end

  @doc """
  Lists appointments with optional filters.

  Filters: professional_id, patient_id, state, date_from, date_to
  """
  @spec list_bookings(map(), keyword()) :: {:ok, [Appointment.t()]}
  def list_bookings(filters \\ %{}, opts \\ []) do
    query = Appointment
    |> apply_filters(filters)
    |> apply_sorting(opts)
    |> apply_pagination(opts)

    {:ok, Repo.all(query)}
  end

  # Private functions

  @spec persist_booking(actor(), map()) :: {:ok, Appointment.t()} | {:error, Errors.t()}
  defp persist_booking(actor, params) do
    # Acquire advisory locks for concurrency control
    Origen.Bookings.Availability.advisory_lock_both(params.professional_id, params.patient_id)

    Repo.transaction(fn ->
      # 1. Create appointment with snapshot
      snapshot = capture_booking_snapshot(params)
      appointment_changeset = build_appointment_changeset(params, snapshot, actor)

      case Repo.insert(appointment_changeset) do
        {:ok, appointment} ->
          # 2. Ensure professional-patient relationship exists
          relationship = Relationship.ensure_relationship(appointment.professional_id, appointment.patient_id, appointment.id)

          # 3. Write audit event
          write_booking_audit_event(appointment, relationship)

          {:ok, appointment}

        {:error, changeset} ->
          {:error, {:transaction_failed, format_changeset_errors(changeset)}}
      end
    end)
  end

  @spec capture_booking_snapshot(map()) :: map()
  defp capture_booking_snapshot(params) do
    # The consultation_type is already validated and included in params
    type = params.consultation_type

    with {:ok, snapshot} <- Snapshots.capture_snapshot(type, type.agenda_interval_minutes) do
      snapshot
    else
      {:error, _reason} ->
        # Fallback - shouldn't happen if validation passed
        %{
          name: type.name,
          duration_minutes: type.interval_count * type.agenda_interval_minutes,
          price_ars: type.exact_price_ars
        }
    end
  end

  @spec build_appointment_changeset(map(), map(), actor()) :: Ecto.Changeset.t()
  defp build_appointment_changeset(params, snapshot, actor) do
    %Appointment{}
    |> Appointment.create_changeset(%{
      professional_id: params.professional_id,
      patient_id: params.patient_id,
      consultation_type_id: params.consultation_type_id,
      consultation_type_snapshot: snapshot,
      agenda_interval_minutes: params.consultation_type.agenda_interval_minutes,
      starts_at: params.starts_at,
      ends_at: params.ends_at,
      state: params.initial_state,
      booked_by_actor: actor.type,
      booked_by_account_id: actor.account_id
    })
  end

  @spec update_appointment_state(Appointment.t(), atom()) ::
          {:ok, Appointment.t()} | {:error, Errors.t()}
  defp update_appointment_state(appointment, new_state) do
    changeset = Appointment.state_transition_changeset(appointment, %{state: new_state}, appointment.state)

    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} ->
        {:error, {:transaction_failed, format_changeset_errors(changeset)}}
    end
  end

  @spec write_booking_audit_event(Appointment.t(), map() | nil) :: :ok
  defp write_booking_audit_event(appointment, relationship) do
    with {:ok, event} <- Events.booking_created(appointment, relationship),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok  # Audit failure shouldn't rollback booking
    end
  end

  @spec apply_filters(Ecto.Query.t(), map()) :: Ecto.Query.t()
  defp apply_filters(query, filters) do
    professional_id = filters[:professional_id]
    patient_id = filters[:patient_id]
    state = filters[:state]
    date_from = filters[:date_from]
    date_to = filters[:date_to]

    query
    |> maybe_where(professional_id, fn q, v -> where(q, [a], a.professional_id == ^v) end)
    |> maybe_where(patient_id, fn q, v -> where(q, [a], a.patient_id == ^v) end)
    |> maybe_where(state, fn q, v -> where(q, [a], a.state == ^v) end)
    |> maybe_where(date_from, fn q, v -> where(q, [a], a.starts_at >= ^v) end)
    |> maybe_where(date_to, fn q, v -> where(q, [a], a.starts_at <= ^v) end)
  end

  defp maybe_where(query, nil, _fun), do: query
  defp maybe_where(query, value, fun) do
    fun.(query, value)
  end

  @spec apply_sorting(Ecto.Query.t(), keyword()) :: Ecto.Query.t()
  defp apply_sorting(query, opts) do
    sort_by = Keyword.get(opts, :sort_by, :starts_at)
    sort_order = Keyword.get(opts, :sort_order, :asc)
    order_by(query, [{^sort_order, ^sort_by}])
  end

  @spec apply_pagination(Ecto.Query.t(), keyword()) :: Ecto.Query.t()
  defp apply_pagination(query, opts) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    query |> limit(^limit) |> offset(^offset)
  end

  @spec format_changeset_errors(Ecto.Changeset.t()) :: String.t()
  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {msg, params}} ->
      "#{field}: #{Kernel.inspect(Keyword.put(params, :message, msg))}"
    end)
    |> Enum.join("; ")
  end
end