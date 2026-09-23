defmodule Origen.Repo.Migrations.CreateAppointments do
  use Ecto.Migration

  def up do
    # Enable btree_gist extension for EXCLUDE constraints
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    # Create patients table (minimal for PAT-01 support)
    # PAT-01: Google OAuth or Magic Link authentication
    execute("""
    CREATE TABLE public.patients (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      auth_subject varchar(255) NOT NULL,
      auth_provider varchar(32) NOT NULL CHECK (auth_provider IN ('google', 'magic_link')),
      profile_complete boolean NOT NULL DEFAULT false,
      phone_verified boolean NOT NULL DEFAULT false,
      primary_notification_phone varchar(32),
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT patients_auth_subject_provider_unique UNIQUE (auth_subject, auth_provider)
    )
    """)

    execute("CREATE INDEX idx_patients_auth_subject ON public.patients (auth_subject, auth_provider)")

    # Create appointments table
    execute("""
    CREATE TABLE public.appointments (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      professional_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      patient_id bigint NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
      consultation_type_id uuid NOT NULL,  -- FK added in later migration
      consultation_type_snapshot jsonb NOT NULL,
      agenda_interval_minutes integer NOT NULL CHECK (agenda_interval_minutes > 0),
      starts_at timestamptz(6) NOT NULL,
      ends_at timestamptz(6) NOT NULL,
      state varchar(32) NOT NULL DEFAULT 'solicitado'
        CHECK (state IN ('solicitado', 'reservado', 'confirmado', 'asistio', 'cancelado', 'no_asistio')),
      booked_by_actor varchar(16) NOT NULL
        CHECK (booked_by_actor IN ('patient', 'secretary', 'professional')),
      booked_by_account_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      confirmed_at timestamptz(6),
      cancelled_at timestamptz(6),
      cancellation_reason text,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT appointments_duration_check CHECK (ends_at > starts_at)
    )
    """)

    # Indexes for common queries
    execute("CREATE INDEX idx_appointments_professional_starts_at ON public.appointments (professional_id, starts_at)")
    execute("CREATE INDEX idx_appointments_patient_starts_at ON public.appointments (patient_id, starts_at)")
    execute("CREATE INDEX idx_appointments_consultation_type_id ON public.appointments (consultation_type_id)")
    execute("CREATE INDEX idx_appointments_state ON public.appointments (state)")
    execute("CREATE INDEX idx_appointments_booked_by_account ON public.appointments (booked_by_account_id)")

    # EXCLUDE constraints for overlap prevention (professional and patient)
    # Using btree_gist for tstzrange overlap detection
    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_professional_time_overlap_excl
    EXCLUDE USING gist (
      professional_id WITH =,
      tstzrange(starts_at, ends_at) WITH &&
    )
    """)

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_patient_time_overlap_excl
    EXCLUDE USING gist (
      patient_id WITH =,
      tstzrange(starts_at, ends_at) WITH &&
    )
    """)

    # Create professional_patient_relationships table
    execute("""
    CREATE TABLE public.professional_patient_relationships (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      professional_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      patient_id bigint NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
      first_booking_id bigint NOT NULL REFERENCES public.appointments(id) ON DELETE RESTRICT,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT professional_patient_relationships_unique_pair UNIQUE (professional_id, patient_id)
    )
    """)

    execute("CREATE INDEX idx_ppr_first_booking_id ON public.professional_patient_relationships (first_booking_id)")

    # Revoke default permissions and grant to runtime roles
    for table <- ~w(patients appointments professional_patient_relationships) do
      execute("REVOKE ALL ON TABLE public.#{table} FROM PUBLIC")
    end

    for sequence <- ~w(patients_id_seq appointments_id_seq professional_patient_relationships_id_seq) do
      execute("REVOKE ALL ON SEQUENCE public.#{sequence} FROM PUBLIC")
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.patients TO origen_runtime;
        GRANT SELECT, INSERT, UPDATE ON public.appointments TO origen_runtime;
        GRANT SELECT, INSERT, UPDATE ON public.professional_patient_relationships TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.patients_id_seq, public.appointments_id_seq, public.professional_patient_relationships_id_seq TO origen_runtime;
      END IF;
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_verifier') THEN
        GRANT SELECT ON public.patients, public.appointments, public.professional_patient_relationships TO origen_verifier;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute(rollback_guard_sql())

    execute("DROP TABLE IF EXISTS public.professional_patient_relationships")
    execute("DROP TABLE IF EXISTS public.appointments")
    execute("DROP TABLE IF EXISTS public.patients")
    execute("DROP EXTENSION IF EXISTS btree_gist")
  end

  defp rollback_guard_sql do
    """
    DO $$
    BEGIN
      LOCK TABLE public.patients, public.appointments, public.professional_patient_relationships IN ACCESS EXCLUSIVE MODE;

      IF EXISTS (SELECT FROM public.patients)
         OR EXISTS (SELECT FROM public.appointments)
         OR EXISTS (SELECT FROM public.professional_patient_relationships)
      THEN
        RAISE EXCEPTION 'refusing to drop populated booking tables'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """
  end
end
