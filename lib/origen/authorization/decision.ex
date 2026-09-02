defmodule Origen.Authorization.Decision do
  @moduledoc "Stable, structured authorization outcomes."

  @type reason ::
          :invalid_request
          | :unknown_operation
          | :unknown_subject
          | :no_matching_rule
          | {:unknown_dimension, atom()}

  @type t :: {:allow, atom()} | {:deny, reason()}
end
