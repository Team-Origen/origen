defmodule Origen.Repo.Migrations.AddAppointmentCancellationMetadata do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE public.appointments ADD COLUMN cancellation_origin varchar(16)")
    execute("ALTER TABLE public.appointments ADD COLUMN cancellation_reason text")

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_cancellation_metadata_check CHECK (
      (status = 'cancelled' AND (
        cancellation_origin IS NULL
        OR (cancellation_origin IN ('patient', 'professional', 'secretary')
          AND (cancellation_origin = 'patient' OR NULLIF(btrim(cancellation_reason), '') IS NOT NULL))
      ))
      OR
      (status <> 'cancelled' AND cancellation_origin IS NULL AND cancellation_reason IS NULL)
    )
    """)
  end

  def down do
    execute(
      "ALTER TABLE public.appointments DROP CONSTRAINT appointments_cancellation_metadata_check"
    )

    execute("ALTER TABLE public.appointments DROP COLUMN cancellation_reason")
    execute("ALTER TABLE public.appointments DROP COLUMN cancellation_origin")
  end
end
