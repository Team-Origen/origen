defmodule Origen.ProtectedOperation do
  @moduledoc "Authorizes protected business operations and records their outcomes."

  alias Origen.Authorization
  alias Origen.Authorization.Request
  alias Origen.Audit.{Events, Writer}
  alias Origen.Repo

  alias Ecto.Multi

  @audit_decision {:allow, :sys_01}

  @spec execute(Request.t(), {atom(), String.t() | nil}, {atom(), String.t()} | nil, function()) ::
          {:ok, term()} | {:error, term()}
  def execute(%Request{} = request, actor, entity, business_operation) do
    case Authorization.decide(request) do
      {:deny, reason} -> audit_denial(actor, entity, reason)
      {:allow, _rule} -> execute_allowed(actor, entity, business_operation)
    end
  end

  defp execute_allowed(actor, entity, business_operation) do
    with {:ok, succeeded_event} <- Events.succeeded(actor, entity),
         {:ok, failed_event} <- Events.failed(actor, entity) do
      Multi.new()
      |> Multi.run(:business, business_operation)
      |> Writer.append_to_multi(succeeded_event, @audit_decision)
      |> Repo.transaction()
      |> finish_allowed(failed_event)
    else
      _error -> {:error, :audit_unavailable}
    end
  end

  defp finish_allowed({:ok, %{business: result}}, _failed_event), do: {:ok, result}

  defp finish_allowed({:error, :business, reason, _changes}, failed_event) do
    with {:ok, _audit_event} <- Writer.append(failed_event, @audit_decision) do
      {:error, reason}
    else
      _error -> {:error, :audit_unavailable}
    end
  end

  defp finish_allowed({:error, :audit_event, _reason, _changes}, _failed_event),
    do: {:error, :audit_unavailable}

  defp audit_denial(actor, entity, reason) do
    with {:ok, event} <- Events.denied(actor, entity),
         {:ok, _audit_event} <- Writer.append(event, @audit_decision) do
      {:error, reason}
    else
      _error -> {:error, :audit_unavailable}
    end
  end
end
