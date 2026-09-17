defmodule Origen.Repo.Migrations.CreateInternalAccountSessions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.internal_account_sessions (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      account_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE CASCADE,
      token_digest bytea NOT NULL,
      issued_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      last_activity_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      idle_timeout_seconds integer NOT NULL DEFAULT 900,
      max_duration_seconds integer NOT NULL DEFAULT 43200,
      revoked_at timestamptz(6),
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT internal_account_sessions_digest_check CHECK (octet_length(token_digest) = 32),
      CONSTRAINT internal_account_sessions_timeout_check CHECK (idle_timeout_seconds > 0 AND max_duration_seconds >= idle_timeout_seconds)
    )
    """)

    execute("""
    CREATE UNIQUE INDEX internal_account_sessions_token_digest_idx
    ON public.internal_account_sessions (token_digest)
    """)

    execute("""
    CREATE INDEX internal_account_sessions_account_id_active_idx
    ON public.internal_account_sessions (account_id)
    WHERE revoked_at IS NULL
    """)

    execute("REVOKE ALL ON TABLE public.internal_account_sessions FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.internal_account_sessions_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.internal_account_sessions TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.internal_account_sessions_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS public.internal_account_sessions CASCADE")
  end
end
