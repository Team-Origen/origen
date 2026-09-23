defmodule Origen.Bookings.Validators do
  @moduledoc """
  Composed validation pipeline for booking creation.

  Integrates: authorization → eligibility → consultation type → availability → D-1 window → initial state
  """

  alias Origen.Authorization.Rules
  alias Origen.Authorization.Request
  alias Origen.Bookings.Eligibility
  alias Origen.Bookings.ConsultationType
  alias Origen.Bookings.Availability
  alias Origen.Bookings.D1Window
  alias Origen.Bookings.Errors

  @type actor ::
    %{
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

  @type booking_params ::
    %{
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

  @type validation_result ::
    {:ok, validated_params :: map()} | {:error, Errors.t()}

  @doc """
  Runs the complete validation pipeline for a booking request.

  Returns {:ok, validated_params} with computed initial_state, or {:error, reason}.
  """
  @spec validate_booking(actor(), booking_params()) :: validation_result()
  def validate_booking(actor, params) do
    with :ok <- authorize_booking(actor, params),
         :ok <- validate_eligibility(actor, params),
         {:ok, type} <- validate_consultation_type(actor, params),
         :ok <- validate_availability(actor, params, type),
         {:ok, initial_state} <- validate_d1_window_and_state(actor, params),
         validated_params = Map.merge(params, %{
           initial_state: initial_state,
           consultation_type: type
         }) do
      {:ok, validated_params}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Authorization via Authorization Rules engine

  @spec authorize_booking(actor(), booking_params()) :: :ok | {:error, Errors.t()}
  defp authorize_booking(actor, params) do
    operation = :create_booking
    subject = {:role, actor.type}
    account_state = :active  # Validated by session layer

    target = %{
      professional_id: params.professional_id,
      patient_id: params.patient_id,
      consultation_type_id: params.consultation_type_id,
      starts_at: params.starts_at
    }

    scope = build_scope_facts(actor, params)

    request = %Request{
      operation: {:known, operation},
      subject: {:known, subject},
      account_state: account_state,
      target: {:known, target},
      scope: {:known, scope}
    }

    case Rules.decide(request) do
      {:allow, _rule_id} -> :ok
      {:deny, _reason} -> {:error, {:authorization_denied, :policy_denied}}
    end
  end

  @spec build_scope_facts(actor(), booking_params()) :: map()
  defp build_scope_facts(actor, params) do
    base = %{
      consultation_type: :active_owned,  # Validated later
      availability: :valid,              # Validated later
      overlap: :none,                    # Validated later
      d1_window: :valid,                 # Validated later
      state: :valid                      # Validated later
    }

    actor_specific = case actor.type do
      :patient ->
        %{
          profile_complete: actor.profile_complete || false,
          phone_verified: actor.phone_verified || false,
          own_profile: actor.own_profile || false
        }
      :secretary ->
        %{
          center_scope: if(actor.center_scope_valid, do: :valid, else: :invalid),
          minimum_identity: if(actor.minimum_identity_complete, do: :complete, else: :incomplete)
        }
      :professional ->
        %{
          patient_related: (params.patient_id in (actor.allowed_patient_ids || [])),
          patient_in_allowed_list: (params.patient_id in (actor.allowed_patient_ids || []))
        }
      _ -> %{}
    end

    Map.merge(base, actor_specific)
  end

  # Eligibility validation

  @spec validate_eligibility(actor(), booking_params()) :: :ok | {:error, Errors.t()}
  defp validate_eligibility(actor, params) do
    Eligibility.validate_actor_eligibility(actor, params)
  end

  # Consultation type validation

  @spec validate_consultation_type(actor(), booking_params()) ::
          {:ok, map()} | {:error, Errors.t()}
  defp validate_consultation_type(actor, params) do
    professional_reference = actor.professional_reference

    if is_nil(professional_reference) do
      {:error, {:consultation_type_invalid, :professional_reference_missing}}
    else
      ConsultationType.validate_consultation_type(professional_reference, params.consultation_type_id)
    end
  end

  # Availability validation

  @spec validate_availability(actor(), booking_params(), map()) :: :ok | {:error, Errors.t()}
  defp validate_availability(_actor, params, _type) do
    # Advisory lock acquired in Availability.check_slot_available
    Availability.check_slot_available(
      params.professional_id,
      params.patient_id,
      params.consultation_type_id,
      params.starts_at,
      params.ends_at
    )
  end

  # D-1 window and initial state validation

  @spec validate_d1_window_and_state(actor(), booking_params()) ::
          {:ok, atom()} | {:error, Errors.t()}
  defp validate_d1_window_and_state(actor, params) do
    requested_date = DateTime.to_date(params.starts_at)
    requested_state = params.initial_state || default_initial_state(actor)
    modality = params.modality

    # Validate initial state is allowed for actor/timing
    opts = %{
      agreement_declaration: params.agreement_declaration || false
    }

    case D1Window.validate_initial_state(actor.type, requested_date, requested_state, modality, opts) do
      :ok ->
        {:ok, requested_state}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec default_initial_state(actor()) :: atom()
  defp default_initial_state(%{type: :patient}), do: :solicitado
  defp default_initial_state(%{type: :secretary}), do: :reservado
  defp default_initial_state(%{type: :professional}), do: :reservado
  defp default_initial_state(_), do: :solicitado
end