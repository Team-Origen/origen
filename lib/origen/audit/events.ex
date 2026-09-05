defmodule Origen.Audit.Events do
  @moduledoc false

  @actor_kinds [:system, :anonymous, :administrator, :professional, :secretary, :patient]
  @entity_kinds [:account, :patient, :audit_event]
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
    byte_size(reference) <= 128 and String.trim(reference) != ""
  end

  defp valid_reference?(_reference), do: false
end
