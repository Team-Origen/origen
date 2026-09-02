defmodule Origen.Authorization.Request do
  @moduledoc "Complete input to the authorization policy."

  alias Origen.Authorization.Fact

  @enforce_keys [:operation, :subject, :account_state, :target, :scope]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          operation: Fact.t(atom()),
          subject: Fact.t(term()),
          account_state: Fact.t(atom()),
          target: Fact.t(map()),
          scope: Fact.t(map())
        }

  @spec new(keyword()) :: t()
  def new(attributes) do
    struct!(
      __MODULE__,
      Keyword.merge(
        [
          operation: :unknown,
          subject: :unknown,
          account_state: :unknown,
          target: :unknown,
          scope: :unknown
        ],
        attributes
      )
    )
  end
end
