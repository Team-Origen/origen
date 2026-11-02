defmodule Origen.Booking.ProfessionalPatientRelationship do
  @moduledoc """
  Ecto schema de la relación Profesional-Paciente auditable (Issue #66 / PLN-08, RF-05).

  La relación se establece una única vez, de forma atómica con el primer turno
  válido (`requested`, `reserved` o `confirmed`) entre el profesional y el paciente,
  conforme a la regla beta: completar una solicitud también establece la relación.

  `established_at` se resuelve con el reloj de la base de datos
  (`clock_timestamp()`) mediante `read_after_writes`, y `first_appointment_id`
  apunta al turno originario que estableció la relación.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "professional_patient_relationships" do
    field :professional_account_id, :integer
    field :patient_profile_id, :integer
    field :established_at, :utc_datetime_usec, read_after_writes: true
    field :first_appointment_id, :integer
  end

  @doc false
  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:professional_account_id, :patient_profile_id, :first_appointment_id])
    |> validate_required([:professional_account_id, :patient_profile_id, :first_appointment_id])
    |> unique_constraint(:professional_account_id,
      name: :professional_patient_relationships_unique_pair
    )
  end
end
