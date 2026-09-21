defmodule Origen.Repo.Migrations.CreatePersonasAndPatientProfiles do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.personas (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      first_name text NOT NULL,
      last_name text NOT NULL,
      document_type text NOT NULL,
      document_number text NOT NULL,
      birthdate date NOT NULL,
      gender text,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT personas_document_type_check CHECK (document_type IN ('dni', 'passport', 'identity_card', 'other')),
      CONSTRAINT personas_document_number_format CHECK (document_number ~ '^[A-Za-z0-9]{1,32}$'),
      CONSTRAINT personas_document_unique UNIQUE (document_type, document_number)
    )
    """)

    execute("""
    CREATE TABLE public.patient_profiles (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      email text NOT NULL UNIQUE,
      persona_id bigint REFERENCES public.personas(id) ON DELETE SET NULL,
      state text NOT NULL DEFAULT 'pending_completion',
      phone text,
      phone_verified boolean NOT NULL DEFAULT false,
      collision_detected_at timestamptz(6),
      collision_notes text,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT patient_profiles_state_check CHECK (state IN ('pending_completion', 'completed', 'pending_secretary_review')),
      CONSTRAINT patient_profiles_phone_verified_false_check CHECK (phone_verified = false OR state = 'completed')
    )
    """)

    execute("""
    CREATE INDEX patient_profiles_persona_id_idx ON public.patient_profiles (persona_id)
    """)

    execute("""
    CREATE INDEX patient_profiles_state_idx ON public.patient_profiles (state)
    """)

    execute("REVOKE ALL ON TABLE public.personas, public.patient_profiles FROM PUBLIC")

    execute(
      "REVOKE ALL ON SEQUENCE public.personas_id_seq, public.patient_profiles_id_seq FROM PUBLIC"
    )

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.personas, public.patient_profiles TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.personas_id_seq, public.patient_profiles_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS public.patient_profiles CASCADE")
    execute("DROP TABLE IF EXISTS public.personas CASCADE")
  end
end
