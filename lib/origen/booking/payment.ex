defmodule Origen.Booking.Payment do
  @moduledoc "Current total-payment state for one appointment."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :id, autogenerate: true}
  schema "appointment_payments" do
    field :appointment_id, :id
    field :status, :string, default: "pending"
    field :method, :string
    field :paid_amount_ars, :decimal
    field :paid_actor_kind, :string
    field :paid_actor_ref, :string
    field :paid_at, :utc_datetime_usec

    timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :appointment_id,
      :status,
      :method,
      :paid_amount_ars,
      :paid_actor_kind,
      :paid_actor_ref,
      :paid_at
    ])
    |> validate_required([:appointment_id, :status])
    |> validate_inclusion(:status, ["pending", "paid"])
    |> validate_inclusion(:method, ["cash", "transfer"], allow_nil: true)
    |> validate_number(:paid_amount_ars, greater_than_or_equal_to: Decimal.new("0"))
  end
end
