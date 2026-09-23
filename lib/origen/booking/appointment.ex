defmodule Origen.Booking.Appointment do
  @moduledoc """
  Ecto schema para turnos persistidos con snapshots históricos inmutables (Issue #63 / PLN-08).

  Congela el nombre del tipo de consulta, la duración calculada en minutos y el precio base exacto
  en ARS (`Decimal`) al momento de la reserva.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses ~w(requested reserved confirmed attended cancelled no_show)

  @primary_key {:id, :id, autogenerate: true}
  schema "appointments" do
    field :patient_profile_id, :integer
    field :professional_account_id, :integer
    field :consultation_type_id, Ecto.UUID
    field :start_time, :utc_datetime_usec
    field :end_time, :utc_datetime_usec
    field :status, :string, default: "reserved"

    # Snapshots históricos inmutables (#63)
    field :snapshot_consultation_type_name, :string
    field :snapshot_duration_minutes, :integer
    field :snapshot_exact_price_ars, :decimal

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime_usec)
  end

  def statuses, do: @statuses

  @doc false
  def changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [
      :patient_profile_id,
      :professional_account_id,
      :consultation_type_id,
      :start_time,
      :end_time,
      :status,
      :snapshot_consultation_type_name,
      :snapshot_duration_minutes,
      :snapshot_exact_price_ars
    ])
    |> validate_required([
      :patient_profile_id,
      :professional_account_id,
      :consultation_type_id,
      :start_time,
      :end_time,
      :status,
      :snapshot_consultation_type_name,
      :snapshot_duration_minutes,
      :snapshot_exact_price_ars
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:snapshot_duration_minutes,
      greater_than_or_equal_to: 5,
      less_than_or_equal_to: 240
    )
    |> validate_number(:snapshot_exact_price_ars,
      greater_than_or_equal_to: Decimal.new("0.00")
    )
    |> validate_end_after_start()
    |> exclusion_constraint(:start_time,
      name: :appointments_no_professional_overlap,
      message: "overlaps an active appointment in the professional schedule"
    )
    |> exclusion_constraint(:start_time,
      name: :appointments_no_patient_overlap,
      message: "overlaps an active appointment in the patient schedule"
    )
  end

  defp validate_end_after_start(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(end_time, start_time) != :gt do
      add_error(changeset, :end_time, "must be greater than start_time")
    else
      changeset
    end
  end
end
