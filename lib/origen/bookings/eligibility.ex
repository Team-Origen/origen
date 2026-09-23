defmodule Origen.Bookings.Eligibility do
  @moduledoc """
  Actor eligibility checks for booking operations per BOOK-01, BOOK-02, BOOK-03.

  Validates preconditions before any availability or state validation.
  """

  alias Origen.Bookings.Errors

  @type actor ::
    %{
      type: :patient | :secretary | :professional,
      account_id: integer(),
      # Patient-specific
      patient_id: integer() | nil,
      profile_complete: boolean() | nil,
      phone_verified: boolean() | nil,
      own_profile: boolean() | nil,
      # Secretary-specific
      center_scope_valid: boolean() | nil,
      minimum_identity_complete: boolean() | nil,
      # Professional-specific
      allowed_patient_ids: [integer()] | nil
    }

  @type booking_params ::
    %{
      professional_id: integer(),
      patient_id: integer(),
      consultation_type_id: binary(),
      starts_at: DateTime.t(),
      ends_at: DateTime.t()
    }

  @doc """
  Validates Paciente autónomo eligibility (BOOK-01).

  Requires:
  - Authenticated via PAT-01 (Google OAuth or Magic Link)
  - Own profile selected (own_profile: true)
  - Profile complete (profile_complete: true)
  - Primary notification phone verified (phone_verified: true)
  - No prior relationship required
  """
  @spec validate_patient_autonomo(actor(), booking_params()) ::
          :ok | {:error, Errors.t()}
  def validate_patient_autonomo(actor, params) do
    cond do
      actor.type != :patient ->
        {:error, {:eligibility_failed, :not_patient_actor}}

      not actor.own_profile ->
        {:error, {:eligibility_failed, :not_own_profile}}

      not actor.profile_complete ->
        {:error, {:eligibility_failed, :incomplete_profile}}

      not actor.phone_verified ->
        {:error, {:eligibility_failed, :phone_not_verified}}

      true ->
        # Check pending fine for autonomous bookings only
        check_pending_fine(params.patient_id, params.professional_id)
    end
  end

  @doc """
  Validates Secretaría asistida eligibility (BOOK-02).

  Requires:
  - Internal account Activa (validated by authorization layer)
  - Patient within center's operational scope (center_scope_valid: true)
  - Minimum identity complete for first booking (minimum_identity_complete: true)
    - Nombres, apellidos
    - Tipo de documento controlado
    - Número normalizado
    - Fecha de nacimiento
  - Other fields may remain pending
  """
  @spec validate_secretaria_asistida(actor(), booking_params()) ::
          :ok | {:error, Errors.t()}
  def validate_secretaria_asistida(actor, params) do
    cond do
      actor.type != :secretary ->
        {:error, {:eligibility_failed, :not_secretary_actor}}

      not actor.center_scope_valid ->
        {:error, {:eligibility_failed, :patient_outside_center_scope}}

      # Check if this is a first booking for this patient-professional pair
      # If so, minimum identity must be complete
      is_first_booking = params[:is_first_booking] || false
      if is_first_booking and not actor.minimum_identity_complete do
        {:error, {:eligibility_failed, :minimum_identity_incomplete}}
      else
        :ok
      end
    end
  end

  @doc """
  Validates Profesional eligibility (BOOK-03).

  Requires:
  - Internal account Activa (validated by authorization layer)
  - Patient already in allowed list (previous successful booking created relationship)
  - Cannot access global registry or use manipulated identifiers
  """
  @spec validate_profesional(actor(), booking_params()) ::
          :ok | {:error, Errors.t()}
  def validate_profesional(actor, params) do
    cond do
      actor.type != :professional ->
        {:error, {:eligibility_failed, :not_professional_actor}}

      patient_id = params.patient_id
      allowed_ids = actor.allowed_patient_ids || []

      if patient_id in allowed_ids do
        :ok
      else
        {:error, {:eligibility_failed, :patient_not_related}}
      end
    end
  end

  @doc """
  Dispatches to the appropriate eligibility validator based on actor type.
  """
  @spec validate_actor_eligibility(actor(), booking_params()) ::
          :ok | {:error, Errors.t()}
  def validate_actor_eligibility(actor, params) do
    case actor.type do
      :patient -> validate_patient_autonomo(actor, params)
      :secretary -> validate_secretaria_asistida(actor, params)
      :professional -> validate_profesional(actor, params)
      _ -> {:error, {:eligibility_failed, :unknown_actor_type}}
    end
  end

  @doc """
  Checks if patient has a pending fine with the professional (blocks autonomous only).
  """
  @spec check_pending_fine(integer(), integer()) :: :ok | {:error, Errors.t()}
  def check_pending_fine(patient_id, professional_id) do
    case Origen.Repo.query(
           """
           SELECT id FROM fines
           WHERE patient_id = $1 AND professional_id = $2 AND status = 'pending'
           LIMIT 1
           """,
           [patient_id, professional_id]
         ) do
      {:ok, %{rows: []}} ->
        :ok

      {:ok, %{rows: [_ | _]}} ->
        {:error, {:pending_fine_block, :patient_has_pending_fine}}

      _ ->
        {:error, {:availability_failed, :db_error}}
    end
  end
end