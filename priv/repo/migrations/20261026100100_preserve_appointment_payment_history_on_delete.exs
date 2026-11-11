defmodule Origen.Repo.Migrations.PreserveAppointmentPaymentHistoryOnDelete do
  use Ecto.Migration

  @moduledoc """
  Lets parent appointment cleanup remove its current pending payment projection
  while leaving immutable payment history attached to the appointment.

  The payment-actions foreign key remains RESTRICT, so a paid or reverted
  appointment cannot be deleted. The down migration restores the original
  RESTRICT behavior without removing any rows.
  """

  def up do
    execute(
      "ALTER TABLE public.appointment_payments DROP CONSTRAINT appointment_payments_appointment_id_fkey"
    )

    execute("""
    ALTER TABLE public.appointment_payments
    ADD CONSTRAINT appointment_payments_appointment_id_fkey
      FOREIGN KEY (appointment_id)
      REFERENCES public.appointments(id)
      ON DELETE CASCADE
    """)
  end

  def down do
    execute(
      "ALTER TABLE public.appointment_payments DROP CONSTRAINT appointment_payments_appointment_id_fkey"
    )

    execute("""
    ALTER TABLE public.appointment_payments
    ADD CONSTRAINT appointment_payments_appointment_id_fkey
      FOREIGN KEY (appointment_id)
      REFERENCES public.appointments(id)
      ON DELETE RESTRICT
    """)
  end
end
