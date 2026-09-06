defmodule Origen.Repo.Migrations.CreateFirstAdminBootstrap do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.internal_accounts (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      role varchar(32) NOT NULL DEFAULT 'administrator',
      state varchar(32) NOT NULL,
      password_hash text,
      totp_secret bytea,
      totp_last_period bigint,
      activated_at timestamptz(6),
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT internal_accounts_role_check CHECK (role = 'administrator'),
      CONSTRAINT internal_accounts_state_check CHECK (state IN ('pending_activation', 'active')),
      CONSTRAINT internal_accounts_state_fields_check CHECK (
        (state = 'pending_activation' AND password_hash IS NULL AND totp_secret IS NULL AND activated_at IS NULL)
        OR
        (state = 'active' AND password_hash IS NOT NULL AND totp_secret IS NOT NULL AND activated_at IS NOT NULL)
      )
    )
    """)

    execute("""
    CREATE TABLE public.admin_bootstrap_controls (
      id smallint PRIMARY KEY DEFAULT 1,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT admin_bootstrap_controls_singleton CHECK (id = 1)
    )
    """)

    execute("INSERT INTO public.admin_bootstrap_controls (id) VALUES (1)")

    execute("""
    CREATE TABLE public.internal_account_invitations (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      account_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      verifier_version varchar(32) NOT NULL,
      verifier_digest bytea NOT NULL,
      issued_by_ref varchar(128),
      issued_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      expires_at timestamptz(6) NOT NULL DEFAULT (clock_timestamp() + interval '24 hours'),
      consumed_at timestamptz(6),
      revoked_at timestamptz(6),
      CONSTRAINT internal_account_invitations_expiry_check CHECK (expires_at > issued_at),
      CONSTRAINT internal_account_invitations_digest_check CHECK (octet_length(verifier_digest) >= 32),
      CONSTRAINT internal_account_invitations_terminal_state_check CHECK (
        consumed_at IS NULL OR revoked_at IS NULL
      ),
      CONSTRAINT internal_account_invitations_issuer_check CHECK (
        issued_by_ref IS NULL OR btrim(issued_by_ref) <> ''
      )
    )
    """)

    execute("""
    CREATE UNIQUE INDEX internal_account_invitations_one_active
    ON public.internal_account_invitations (account_id)
    WHERE consumed_at IS NULL AND revoked_at IS NULL
    """)

    for table <- ~w(internal_accounts admin_bootstrap_controls internal_account_invitations) do
      execute("REVOKE ALL ON TABLE public.#{table} FROM PUBLIC")
    end

    for sequence <- ~w(internal_accounts_id_seq internal_account_invitations_id_seq) do
      execute("REVOKE ALL ON SEQUENCE public.#{sequence} FROM PUBLIC")
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.internal_accounts TO origen_runtime;
        GRANT SELECT, UPDATE ON public.admin_bootstrap_controls TO origen_runtime;
        GRANT SELECT, INSERT, UPDATE ON public.internal_account_invitations TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.internal_accounts_id_seq,
          public.internal_account_invitations_id_seq TO origen_runtime;
      END IF;
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_verifier') THEN
        GRANT SELECT ON public.internal_accounts,
          public.admin_bootstrap_controls,
          public.internal_account_invitations TO origen_verifier;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute(rollback_guard_sql())

    execute("DROP TABLE IF EXISTS public.internal_account_invitations")
    execute("DROP TABLE IF EXISTS public.admin_bootstrap_controls")
    execute("DROP TABLE IF EXISTS public.internal_accounts")
  end

  def rollback_guard_sql do
    """
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM public.internal_account_invitations)
        OR EXISTS (SELECT FROM public.internal_accounts)
        OR EXISTS (SELECT FROM public.admin_bootstrap_controls)
      THEN
        RAISE EXCEPTION 'refusing to drop populated first-admin bootstrap history'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """
  end
end
