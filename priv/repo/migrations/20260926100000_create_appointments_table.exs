defmodule Origen.Repo.Migrations.CreateAppointmentsTable do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.appointments (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      patient_profile_id bigint NOT NULL
        REFERENCES public.patient_profiles(id) ON DELETE RESTRICT,
      professional_account_id bigint NOT NULL
        REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      consultation_type_id uuid NOT NULL
        REFERENCES public.consultation_types(id) ON DELETE RESTRICT,
      start_time timestamptz(6) NOT NULL,
      end_time timestamptz(6) NOT NULL,
      status varchar(16) NOT NULL DEFAULT 'reserved',
      snapshot_consultation_type_name varchar(32) NOT NULL,
      snapshot_duration_minutes integer NOT NULL,
      snapshot_exact_price_ars numeric NOT NULL,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT appointments_time_window_check CHECK (end_time > start_time),
      CONSTRAINT appointments_status_check CHECK (
        status IN ('requested', 'reserved', 'confirmed', 'attended', 'cancelled', 'no_show')
      ),
      CONSTRAINT appointments_snapshot_name_check CHECK (
        btrim(snapshot_consultation_type_name) <> '' AND char_length(snapshot_consultation_type_name) <= 32
      ),
      CONSTRAINT appointments_snapshot_duration_check CHECK (
        snapshot_duration_minutes BETWEEN 5 AND 240
      ),
      CONSTRAINT appointments_snapshot_price_check CHECK (
        snapshot_exact_price_ars >= 0 AND snapshot_exact_price_ars = round(snapshot_exact_price_ars, 2)
      )
    )
    """)

    execute("""
    CREATE INDEX appointments_professional_time_idx
    ON public.appointments (professional_account_id, start_time)
    """)

    execute("""
    CREATE INDEX appointments_patient_time_idx
    ON public.appointments (patient_profile_id, start_time)
    """)

    execute("""
    CREATE FUNCTION public.reject_appointment_snapshot_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.snapshot_consultation_type_name IS DISTINCT FROM OLD.snapshot_consultation_type_name
        OR NEW.snapshot_duration_minutes IS DISTINCT FROM OLD.snapshot_duration_minutes
        OR NEW.snapshot_exact_price_ars IS DISTINCT FROM OLD.snapshot_exact_price_ars
        OR NEW.consultation_type_id IS DISTINCT FROM OLD.consultation_type_id
        OR NEW.patient_profile_id IS DISTINCT FROM OLD.patient_profile_id
        OR NEW.professional_account_id IS DISTINCT FROM OLD.professional_account_id
      THEN
        RAISE EXCEPTION 'appointment snapshots and core identity are immutable' USING ERRCODE = '23000';
      END IF;

      RETURN NEW;
    END;
    $$
    """)

    execute("""
    CREATE TRIGGER appointments_immutable_snapshots
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW EXECUTE FUNCTION public.reject_appointment_snapshot_mutation()
    """)

    execute("REVOKE ALL ON TABLE public.appointments FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.appointments_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.appointments TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.appointments_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute(rollback_guard_sql())

    execute("DROP TRIGGER IF EXISTS appointments_immutable_snapshots ON public.appointments")
    execute("DROP FUNCTION IF EXISTS public.reject_appointment_snapshot_mutation()")
    execute("DROP TABLE IF EXISTS public.appointments")
  end

  def rollback_guard_sql do
    """
    DO $$
    BEGIN
      LOCK TABLE public.appointments IN ACCESS EXCLUSIVE MODE;

      IF EXISTS (SELECT FROM public.appointments) THEN
        RAISE EXCEPTION 'refusing to drop populated appointments table'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """
  end
end
