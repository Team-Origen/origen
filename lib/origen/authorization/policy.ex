defmodule Origen.Authorization.Policy do
  @moduledoc """
  Narrow authorization predicates for appointment lifecycle operations.

  Identity and scope are resolved by the domain operation after session
  revalidation; this module only describes which roles may request each action.
  """

  @lifecycle_operations [:cancel_appointment, :read_appointment_history]

  @spec lifecycle_allowed?(atom(), atom()) :: boolean()
  def lifecycle_allowed?(role, operation) when operation in @lifecycle_operations do
    case {role, operation} do
      {:patient, :cancel_appointment} -> true
      {:professional, :cancel_appointment} -> true
      {:secretary, :cancel_appointment} -> true
      {:patient, :read_appointment_history} -> true
      {:professional, :read_appointment_history} -> true
      {:secretary, :read_appointment_history} -> true
      _ -> false
    end
  end

  def lifecycle_allowed?(_role, _operation), do: false
end
