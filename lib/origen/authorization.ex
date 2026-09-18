defmodule Origen.Authorization do
  @moduledoc "Pure matrix-v0.4 authorization with default denial."

  alias Origen.Authorization.{Fact, Request, Rules}

  @dimensions [:operation, :subject, :account_state, :target, :scope]

  @spec decide(Request.t()) :: Origen.Authorization.Decision.t()
  def decide(%Request{} = request) do
    with :ok <- validate_facts(request),
         :ok <- validate_operation(request.operation),
         :ok <- validate_subject(request.subject) do
      Rules.decide(request)
    end
  end

  def decide(_request), do: {:deny, :invalid_request}

  defp validate_facts(request) do
    Enum.find_value(@dimensions, :ok, fn dimension ->
      case Map.fetch!(request, dimension) do
        :unknown -> {:deny, {:unknown_dimension, dimension}}
        fact -> if Fact.valid?(fact), do: false, else: {:deny, {:unknown_dimension, dimension}}
      end
    end)
  end

  defp validate_operation({:known, operation}) do
    if operation in Rules.operations(), do: :ok, else: {:deny, :unknown_operation}
  end

  defp validate_operation(_operation), do: :ok

  defp validate_subject({:known, subject}) do
    if subject in Rules.subjects(), do: :ok, else: {:deny, :unknown_subject}
  end

  defp validate_subject(_subject), do: :ok
end
