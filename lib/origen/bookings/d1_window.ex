defmodule Origen.Bookings.D1Window do
  @moduledoc """
  D-1 window logic and initial state assignment per RF-10.

  Organization clock uses configured timezone (default: America/Argentina/Buenos_Aires).
  D-1 = calendar day before appointment date in org timezone.
  Cutoff = 23:59 D-1 org time.
  """

  alias Origen.Bookings.Errors

  @organization_timezone "America/Argentina/Buenos_Aires"
  @cutoff_hour 23
  @cutoff_minute 59

  @type timing :: :before_d1 | :during_d1 | :dia_d
  @type modality :: :manual | :automatic
  @type actor :: :patient | :secretary | :professional
  @type initial_state :: :solicitado | :reservado | :confirmado

  @doc """
  Returns the organization timezone.
  """
  @spec organization_timezone() :: String.t()
  def organization_timezone, do: @organization_timezone

  @doc """
  Returns the D-1 cutoff time (23:59) in organization timezone for a given date.
  """
  @spec d1_cutoff(Date.t()) :: DateTime.t()
  def d1_cutoff(appointment_date) do
    DateTime.from_naive!(
      NaiveDateTime.new(appointment_date, Time.new(@cutoff_hour, @cutoff_minute, 0)),
      @organization_timezone
    )
  end

  @doc """
  Determines the timing category for a requested appointment date.

  Returns :before_d1, :during_d1, or :dia_d based on organization clock.
  """
  @spec timing_for(Date.t(), DateTime.t()) :: timing()
  def timing_for(requested_date, now \\ DateTime.utc_now()) do
    org_now = DateTime.shift_zone(now, @organization_timezone)
    org_today = DateTime.to_date(org_now)

    cond do
      requested_date < org_today ->
        :dia_d

      requested_date == org_today ->
        :dia_d

      requested_date == Date.add(org_today, 1) ->
        # This is D-1 (tomorrow in org time)
        if DateTime.compare(org_now, d1_cutoff(requested_date)) == :gt do
          :dia_d  # Past 23:59 D-1 cutoff
        else
          :during_d1
        end

      requested_date > Date.add(org_today, 1) ->
        :before_d1

      true ->
        :before_d1
    end
  end

  @doc """
  Checks if a requested date is Día D (past the D-1 cutoff).
  """
  @spec is_dia_d(Date.t(), DateTime.t()) :: boolean()
  def is_dia_d(requested_date, now \\ DateTime.utc_now()) do
    timing_for(requested_date, now) == :dia_d
  end

  @doc """
  Determines the initial appointment state per actor, timing, and modality.

  Returns {:ok, state} or {:error, reason}.
  """
  @spec initial_state_for(actor(), timing(), modality() | nil, keyword()) ::
          {:ok, initial_state()} | {:error, Errors.t()}
  def initial_state_for(:patient, :before_d1, :manual, _opts), do: {:ok, :solicitado}
  def initial_state_for(:patient, :before_d1, :automatic, _opts), do: {:ok, :reservado}
  def initial_state_for(:patient, :during_d1, _modality, _opts), do: {:ok, :confirmado}
  def initial_state_for(:patient, :dia_d, _modality, _opts),
    do: {:error, {:d1_window_violation, :autonomous_channel_closed}}

  def initial_state_for(:secretary, :before_d1, state, opts) when state in [:reservado, :confirmado] do
    if state == :confirmado and not Keyword.get(opts, :agreement_declaration, false) do
      {:error, {:invalid_initial_state, :agreement_declaration_required}}
    else
      {:ok, state}
    end
  end
  def initial_state_for(:secretary, :before_d1, :solicitado, _opts),
    do: {:error, {:invalid_initial_state, :solicitado_not_allowed_for_secretary}}
  def initial_state_for(:secretary, :during_d1, :confirmado, opts) do
    if Keyword.get(opts, :agreement_declaration, false) do
      {:ok, :confirmado}
    else
      {:error, {:invalid_initial_state, :agreement_declaration_required}}
    end
  end
  def initial_state_for(:secretary, :during_d1, _state, _opts),
    do: {:error, {:invalid_initial_state, :only_confirmado_allowed_during_d1}}
  def initial_state_for(:secretary, :dia_d, :confirmado, opts) do
    if Keyword.get(opts, :agreement_declaration, false) do
      {:ok, :confirmado}
    else
      {:error, {:invalid_initial_state, :agreement_declaration_required}}
    end
  end
  def initial_state_for(:secretary, :dia_d, _state, _opts),
    do: {:error, {:invalid_initial_state, :only_confirmado_allowed_dia_d}}

  def initial_state_for(:professional, :before_d1, _modality, _opts), do: {:ok, :reservado}
  def initial_state_for(:professional, :during_d1, _modality, _opts), do: {:ok, :confirmado}
  def initial_state_for(:professional, :dia_d, :confirmado, _opts), do: {:ok, :confirmado}
  def initial_state_for(:professional, :dia_d, _state, _opts),
    do: {:error, {:invalid_initial_state, :only_confirmado_allowed_dia_d}}

  def initial_state_for(_actor, _timing, _state, _opts),
    do: {:error, {:invalid_initial_state, :invalid_actor_timing_combination}}

  @doc """
  Validates that the requested initial state is allowed for the actor/timing combination.
  """
  @spec validate_initial_state(actor(), Date.t(), initial_state(), modality() | nil, keyword()) ::
          :ok | {:error, Errors.t()}
  def validate_initial_state(actor, requested_date, requested_state, modality, opts) do
    timing = timing_for(requested_date)
    case initial_state_for(actor, timing, modality, opts) do
      {:ok, ^requested_state} -> :ok
      {:ok, _allowed_state} ->
        {:error, {:invalid_initial_state, :state_not_allowed_for_timing}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end