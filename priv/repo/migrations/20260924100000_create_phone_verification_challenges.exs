defmodule Origen.Repo.Migrations.CreatePhoneVerificationChallenges do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.phone_verification_challenges (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      patient_profile_id bigint NOT NULL REFERENCES public.patient_profiles(id) ON DELETE CASCADE,
      phone text NOT NULL,
      code_hash text NOT NULL,
      state text NOT NULL DEFAULT 'pending',
      attempts_count integer NOT NULL DEFAULT 0,
      expires_at timestamptz(6) NOT NULL,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT phone_verification_challenges_state_check CHECK (state IN ('pending', 'consumed', 'expired', 'max_attempts_exceeded')),
      CONSTRAINT phone_verification_challenges_code_hash_check CHECK (length(code_hash) = 64)
    )
    """)

    execute("""
    CREATE INDEX phone_verification_challenges_profile_state_idx
    ON public.phone_verification_challenges (patient_profile_id, state)
    """)

    execute("""
    CREATE INDEX phone_verification_challenges_profile_created_idx
    ON public.phone_verification_challenges (patient_profile_id, created_at)
    """)

    execute("REVOKE ALL ON TABLE public.phone_verification_challenges FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.phone_verification_challenges_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.phone_verification_challenges TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.phone_verification_challenges_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS public.phone_verification_challenges CASCADE")
  end
end
