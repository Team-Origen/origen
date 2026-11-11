defmodule Origen.Authorization.Policy do
  @moduledoc """
  Narrow authorization predicates for appointment lifecycle operations.

  Identity and scope are resolved by the domain operation after session
  revalidation; this module only describes which roles may request each action.
  """

  @lifecycle_operations [:cancel_appointment, :read_appointment_history, :record_attendance]
  @payment_operations [
    :read_payment,
    :edit_appointment_price,
    :register_payment,
    :read_payment_history
  ]

  @spec lifecycle_allowed?(atom(), atom()) :: boolean()
  def lifecycle_allowed?(role, operation) when operation in @lifecycle_operations do
    case {role, operation} do
      {:patient, :cancel_appointment} -> true
      {:professional, :cancel_appointment} -> true
      {:secretary, :cancel_appointment} -> true
      {:patient, :read_appointment_history} -> true
      {:professional, :read_appointment_history} -> true
      {:secretary, :read_appointment_history} -> true
      {:professional, :record_attendance} -> true
      {:secretary, :record_attendance} -> true
      _ -> false
    end
  end

  def lifecycle_allowed?(_role, _operation), do: false

  @spec payment_allowed?(atom(), atom()) :: boolean()
  def payment_allowed?(role, operation) when operation in @payment_operations do
    case {role, operation} do
      {:patient, :read_payment} -> true
      {:professional, :read_payment} -> true
      {:secretary, :read_payment} -> true
      {:professional, :edit_appointment_price} -> true
      {:secretary, :edit_appointment_price} -> true
      {:professional, :register_payment} -> true
      {:secretary, :register_payment} -> true
      {:professional, :read_payment_history} -> true
      {:secretary, :read_payment_history} -> true
      _ -> false
    end
  end

  def payment_allowed?(_role, _operation), do: false
end
