defmodule Origen.Audit.Events do
  @moduledoc false

  @actor_kinds [
    :system,
    :provider,
    :anonymous,
    :administrator,
    :professional,
    :secretary,
    :patient
  ]
  @entity_kinds [:account, :invitation, :patient, :audit_event]
  @marker {__MODULE__, :constructed}

  @opaque t :: %__MODULE__{
            actor_kind: String.t(),
            actor_ref: String.t() | nil,
            event: String.t(),
            entity_kind: String.t() | nil,
            entity_ref: String.t() | nil,
            result: String.t(),
            marker: term()
          }

  @enforce_keys [:actor_kind, :event, :result, :marker]
  defstruct [:actor_kind, :actor_ref, :event, :entity_kind, :entity_ref, :result, :marker]

  def allowed(actor, entity), do: build(actor, "operation_allowed", entity, "allowed")
  def denied(actor, entity), do: build(actor, "operation_denied", entity, "denied")
  def succeeded(actor, entity), do: build(actor, "operation_succeeded", entity, "succeeded")
  def failed(actor, entity), do: build(actor, "operation_failed", entity, "failed")

  def bootstrap_allowed(actor, ref), do: lifecycle(actor, "bootstrap_admin", ref, "allowed")
  def bootstrap_denied(actor, ref), do: lifecycle(actor, "bootstrap_admin", ref, "denied")
  def reissue_allowed(actor, ref), do: lifecycle(actor, "invitation_reissue", ref, "allowed")
  def reissue_denied(actor, ref), do: lifecycle(actor, "invitation_reissue", ref, "denied")

  def internal_invitation_issued(actor, ref),
    do: invitation(actor, "internal_invitation_issued", ref, "succeeded")

  def internal_invitation_reissued(actor, ref),
    do: invitation(actor, "internal_invitation_reissued", ref, "succeeded")

  def activation_succeeded(actor, ref),
    do: lifecycle(actor, "account_activation", ref, "succeeded")

  def activation_failed(actor, ref) when is_binary(ref),
    do: lifecycle(actor, "account_activation", ref, "failed")

  def activation_failed(actor, nil),
    do: build(actor, "account_activation", nil, "failed")

  def invitation_consumed(actor, ref),
    do: lifecycle(actor, "invitation_consumption", ref, "succeeded")

  def invitation_approval_confirmed(actor, ref),
    do: invitation(actor, "invitation_approval_confirmation", ref, "allowed")

  def invitation_delivery_handoff(actor, ref),
    do: invitation(actor, "invitation_delivery_handoff", ref, "succeeded")

  def invitation_delivery_failed(actor, ref),
    do: invitation(actor, "invitation_delivery_failure", ref, "failed")

  def invitation_delivery_revoked(actor, ref),
    do: invitation(actor, "invitation_delivery_revocation", ref, "succeeded")

  def delivery_revocation_failed(actor, ref),
    do: invitation(actor, "delivery_revocation_failed", ref, "failed")

  def internal_login_succeeded(actor, ref) when is_binary(ref),
    do: lifecycle(actor, "internal_login", ref, "succeeded")

  def internal_login_failed(actor, ref) when is_binary(ref),
    do: lifecycle(actor, "internal_login", ref, "failed")

  def internal_login_failed(actor, nil),
    do: build(actor, "internal_login", nil, "failed")

  def magic_link_issued(actor, ref) when is_binary(ref),
    do: build(actor, "magic_link_issued", {:patient, ref}, "succeeded")

  def magic_link_consumed(actor, ref) when is_binary(ref),
    do: build(actor, "magic_link_consumed", {:patient, ref}, "succeeded")

  def magic_link_failed(actor, ref) when is_binary(ref),
    do: build(actor, "magic_link_consumed", {:patient, ref}, "failed")

  def magic_link_failed(actor, nil),
    do: build(actor, "magic_link_consumed", nil, "failed")

  def patient_profile_completed(actor, ref) when is_binary(ref),
    do: build(actor, "patient_profile_completed", {:patient, ref}, "succeeded")

  def document_collision_derived(actor, ref) when is_binary(ref),
    do: build(actor, "document_collision_derived", {:patient, ref}, "succeeded")

  def phone_challenge_issued(actor, ref) when is_binary(ref),
    do: build(actor, "phone_challenge_issued", {:patient, ref}, "succeeded")

  def persistable?(%__MODULE__{marker: @marker}), do: true
  def persistable?(_event), do: false

  defp build({actor_kind, actor_ref}, event, entity, result) do
    with true <- actor_kind in @actor_kinds,
         true <- valid_actor_ref?(actor_kind, actor_ref),
         {:ok, entity_kind, entity_ref} <- validate_entity(entity) do
      {:ok,
       %__MODULE__{
         actor_kind: Atom.to_string(actor_kind),
         actor_ref: actor_ref,
         event: event,
         entity_kind: entity_kind,
         entity_ref: entity_ref,
         result: result,
         marker: @marker
       }}
    else
      _invalid -> {:error, :invalid_event}
    end
  end

  defp build(_actor, _event, _entity, _result), do: {:error, :invalid_event}

  defp lifecycle(actor, event, ref, result), do: build(actor, event, {:account, ref}, result)
  defp invitation(actor, event, ref, result), do: build(actor, event, {:invitation, ref}, result)

  defp valid_actor_ref?(kind, nil), do: kind in [:system, :anonymous]
  defp valid_actor_ref?(_kind, reference), do: valid_reference?(reference)

  defp validate_entity(nil), do: {:ok, nil, nil}

  defp validate_entity({kind, reference}) do
    if kind in @entity_kinds and valid_reference?(reference) do
      {:ok, Atom.to_string(kind), reference}
    else
      :error
    end
  end

  defp validate_entity(_entity), do: :error

  defp valid_reference?(reference) when is_binary(reference) do
    byte_size(reference) <= 128 and String.trim(reference) != "" and
      not Regex.match?(~r/(https?:\/\/|token|secret|password|otp|session|digest|key)/i, reference)
  end

  defp valid_reference?(_reference), do: false
end
