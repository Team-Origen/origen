defmodule Origen.Repo.Migrations.CreatePatientMagicLinks do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.patient_magic_links (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      email text NOT NULL,
      token_digest bytea NOT NULL,
      expires_at timestamptz(6) NOT NULL,
      consumed_at timestamptz(6),
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT patient_magic_links_digest_check CHECK (octet_length(token_digest) = 32),
      CONSTRAINT patient_magic_links_email_format CHECK (email ~ '^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
    )
    """)

    execute("""
    CREATE UNIQUE INDEX patient_magic_links_token_digest_idx
    ON public.patient_magic_links (token_digest)
    """)

    execute("""
    CREATE INDEX patient_magic_links_email_active_idx
    ON public.patient_magic_links (email)
    WHERE consumed_at IS NULL
    """)

    execute("REVOKE ALL ON TABLE public.patient_magic_links FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.patient_magic_links_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.patient_magic_links TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.patient_magic_links_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS public.patient_magic_links CASCADE")
  end
end
