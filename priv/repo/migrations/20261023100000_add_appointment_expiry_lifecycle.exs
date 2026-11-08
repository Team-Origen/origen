defmodule Origen.Repo.Migrations.AddAppointmentExpiryLifecycle do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE public.appointments DROP CONSTRAINT appointments_status_check")

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_status_check CHECK (
      status IN ('requested', 'reserved', 'confirmed', 'expired', 'attended', 'cancelled', 'no_show')
    )
    """)

    execute("""
    ALTER TABLE public.appointments
    DROP CONSTRAINT appointments_no_professional_overlap
    """)

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_no_professional_overlap
    EXCLUDE USING gist (
      professional_account_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'rejected', 'expired'))
    """)

    execute("""
    ALTER TABLE public.appointments
    DROP CONSTRAINT appointments_no_patient_overlap
    """)

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_no_patient_overlap
    EXCLUDE USING gist (
      patient_profile_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'rejected', 'expired'))
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM public.appointments WHERE status = 'expired') THEN
        RAISE EXCEPTION 'refusing to remove expired appointment state from populated data'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """)

    execute(
      "ALTER TABLE public.appointments DROP CONSTRAINT appointments_no_professional_overlap"
    )

    execute("ALTER TABLE public.appointments DROP CONSTRAINT appointments_no_patient_overlap")

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_no_professional_overlap
    EXCLUDE USING gist (
      professional_account_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'rejected'))
    """)

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_no_patient_overlap
    EXCLUDE USING gist (
      patient_profile_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'rejected'))
    """)

    execute("ALTER TABLE public.appointments DROP CONSTRAINT appointments_status_check")

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_status_check CHECK (
      status IN ('requested', 'reserved', 'confirmed', 'attended', 'cancelled', 'no_show')
    )
    """)
  end
end
