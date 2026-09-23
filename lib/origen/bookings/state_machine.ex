defmodule Origen.Bookings.StateMachine do
  @moduledoc """
  Appointment state machine implementation.

  States: :solicitado, :reservado, :confirmado, :asistio, :cancelado, :no_asistio

  Valid transitions per RF-14:
  - solicitado → reservado (professional approves), cancelado (rejected)
  - reservado → confirmado (patient confirms / WhatsApp), cancelado
  - confirmado → asistio, no_asistio, cancelado
  - asistio, no_asistio, cancelado → (terminal, no transitions)
  """

  @valid_states [:solicitado, :reservado, :confirmado, :asistio, :cancelado, :no_asistio]
  @terminal_states [:asistio, :no_asistio, :cancelado]

  @valid_transitions %{
    solicitado: [:reservado, :cancelado],
    reservado: [:confirmado, :cancelado],
    confirmado: [:asistio, :no_asistio, :cancelado],
    asistio: [],
    no_asistio: [],
    cancelado: []
  }

  @doc """
  Returns all valid states.
  """
  @spec valid_states() :: [atom()]
  def valid_states, do: @valid_states

  @doc """
  Returns all terminal states.
  """
  @spec terminal_states() :: [atom()]
  def terminal_states, do: @terminal_states

  @doc """
  Returns the valid transitions map.
  """
  @spec valid_transitions() :: %{atom() => [atom()]}
  def valid_transitions, do: @valid_transitions

  @doc """
  Checks if a state is valid.
  """
  @spec valid_state?(atom()) :: boolean()
  def valid_state?(state), do: state in @valid_states

  @doc """
  Checks if a state is terminal.
  """
  @spec terminal?(atom()) :: boolean()
  def terminal?(state), do: state in @terminal_states

  @doc """
  Checks if a transition from `from_state` to `to_state` is valid.
  """
  @spec can_transition?(atom(), atom()) :: boolean()
  def can_transition?(from_state, to_state) do
    to_state in Map.get(@valid_transitions, from_state, [])
  end

  @doc """
  Returns valid next states for a given state.
  """
  @spec next_states(atom()) :: [atom()]
  def next_states(from_state) do
    Map.get(@valid_transitions, from_state, [])
  end

  @doc """
  Validates and executes a state transition.

  Returns {:ok, new_state} or {:error, :invalid_transition}.
  """
  @spec transition(atom(), atom()) :: {:ok, atom()} | {:error, :invalid_transition}
  def transition(from_state, to_state) do
    if can_transition?(from_state, to_state) do
      {:ok, to_state}
    else
      {:error, :invalid_transition}
    end
  end

  @doc """
  Returns the initial state for a booking based on actor, timing, and modality.

  Delegates to D1Window for the actual logic.
  """
  @spec initial_state(atom(), atom(), atom() | nil, keyword()) ::
          {:ok, atom()} | {:error, term()}
  def initial_state(actor, timing, modality, opts) do
    Origen.Bookings.D1Window.initial_state_for(actor, timing, modality, opts)
  end

  @doc """
  Validates that a requested initial state is allowed.
  """
  @spec validate_initial_state(atom(), Date.t(), atom(), atom() | nil, keyword()) ::
          :ok | {:error, term()}
  def validate_initial_state(actor, requested_date, requested_state, modality, opts) do
    Origen.Bookings.D1Window.validate_initial_state(actor, requested_date, requested_state, modality, opts)
  end

  @doc """
  Checks if an appointment can be cancelled from its current state.
  """
  @spec can_cancel?(atom()) :: boolean()
  def can_cancel?(state) do
    state in [:solicitado, :reservado, :confirmado]
  end

  @doc """
  Checks if an appointment can be confirmed from its current state.
  """
  @spec can_confirm?(atom()) :: boolean()
  def can_confirm?(state) do
    state in [:reservado]
  end

  @doc """
  Checks if an appointment can be marked as attended.
  """
  @spec can_mark_attended?(atom()) :: boolean()
  def can_mark_attended?(state) do
    state == :confirmado
  end

  @doc """
  Checks if an appointment can be marked as no-show.
  """
  @spec can_mark_no_show?(atom()) :: boolean()
  def can_mark_no_show?(state) do
    state == :confirmado
  end

  @doc """
  Checks if an appointment can be approved (solicitado -> reservado).
  """
  @spec can_approve?(atom()) :: boolean()
  def can_approve?(state) do
    state == :solicitado
  end

  @doc """
  Returns a human-readable description of a state.
  """
  @spec describe_state(atom()) :: String.t()
  def describe_state(state) do
    case state do
      :solicitado -> "Solicitado - Waiting for professional approval"
      :reservado -> "Reservado - Approved, pending confirmation"
      :confirmado -> "Confirmado - Attendance confirmed"
      :asistio -> "Asistió - Appointment completed"
      :cancelado -> "Cancelado - Cancelled"
      :no_asistio -> "No asistió - Patient did not attend"
      _ -> "Unknown state"
    end
  end
end