defmodule Origen.Booking.PaymentAction do
  @moduledoc "Append-only payment marks and corrections for future payment operations."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :id, autogenerate: true}
  schema "payment_actions" do
    field :appointment_id, :id
    field :action, :string
    field :amount_ars, :decimal
    field :method, :string
    field :actor_kind, :string
    field :actor_ref, :string
    field :occurred_at, :utc_datetime_usec
  end

  @doc false
  def changeset(action, attrs) do
    action
    |> cast(attrs, [
      :appointment_id,
      :action,
      :amount_ars,
      :method,
      :actor_kind,
      :actor_ref,
      :occurred_at
    ])
    |> validate_required([
      :appointment_id,
      :action,
      :amount_ars,
      :actor_kind,
      :actor_ref,
      :occurred_at
    ])
    |> validate_inclusion(:action, ["paid", "reverted"])
    |> validate_inclusion(:method, ["cash", "transfer"], allow_nil: true)
    |> validate_number(:amount_ars, greater_than_or_equal_to: Decimal.new("0"))
  end
end
