defmodule Origen.Repo.Migrations.CreateConsultationConfiguration do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.agenda_settings (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      owner_account_id bigint NOT NULL
        REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      interval_minutes integer NOT NULL DEFAULT 30,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT agenda_settings_owner_account_unique UNIQUE (owner_account_id),
      CONSTRAINT agenda_settings_interval_check CHECK (
        interval_minutes BETWEEN 5 AND 240 AND interval_minutes % 5 = 0
      )
    )
    """)

    execute("""
    CREATE TABLE public.consultation_types (
      id uuid PRIMARY KEY,
      owner_account_id bigint NOT NULL
        REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      name varchar(32) NOT NULL,
      exact_price_ars numeric NOT NULL,
      color varchar(7) NOT NULL,
      interval_count integer NOT NULL,
      status varchar(16) NOT NULL DEFAULT 'active',
      inactive_duration_minutes integer,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT consultation_types_name_check CHECK (
        btrim(name) <> '' AND char_length(name) <= 32
      ),
      CONSTRAINT consultation_types_price_check CHECK (
        exact_price_ars >= 0 AND exact_price_ars = round(exact_price_ars, 2)
      ),
      CONSTRAINT consultation_types_color_check CHECK (color ~ '^#[0-9A-F]{6}$'),
      CONSTRAINT consultation_types_interval_count_check CHECK (interval_count BETWEEN 1 AND 10),
      CONSTRAINT consultation_types_status_check CHECK (status IN ('active', 'inactive')),
      CONSTRAINT consultation_types_inactive_duration_check CHECK (
        (status = 'active' AND inactive_duration_minutes IS NULL)
        OR
        (status = 'inactive' AND inactive_duration_minutes IS NOT NULL
          AND inactive_duration_minutes BETWEEN 5 AND 240
          AND inactive_duration_minutes % 5 = 0)
      )
    )
    """)

    execute("""
    CREATE INDEX consultation_types_owner_account_id_idx
    ON public.consultation_types (owner_account_id)
    """)

    execute("""
    CREATE FUNCTION public.reject_account_owned_identity_change()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.owner_account_id IS DISTINCT FROM OLD.owner_account_id
      THEN
        RAISE EXCEPTION 'account-owned identity is immutable' USING ERRCODE = '23000';
      END IF;

      RETURN NEW;
    END;
    $$
    """)

    for table <- ~w(agenda_settings consultation_types) do
      execute("""
      CREATE TRIGGER #{table}_immutable_identity
      BEFORE UPDATE ON public.#{table}
      FOR EACH ROW EXECUTE FUNCTION public.reject_account_owned_identity_change()
      """)

      execute("REVOKE ALL ON TABLE public.#{table} FROM PUBLIC")
    end

    execute("REVOKE ALL ON SEQUENCE public.agenda_settings_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.agenda_settings TO origen_runtime;
        GRANT SELECT, INSERT, UPDATE ON public.consultation_types TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.agenda_settings_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute(rollback_guard_sql())

    execute("DROP TABLE IF EXISTS public.consultation_types")
    execute("DROP TABLE IF EXISTS public.agenda_settings")
    execute("DROP FUNCTION IF EXISTS public.reject_account_owned_identity_change()")
  end

  def rollback_guard_sql do
    """
    DO $$
    BEGIN
      LOCK TABLE public.consultation_types, public.agenda_settings
        IN ACCESS EXCLUSIVE MODE;

      IF EXISTS (SELECT FROM public.consultation_types)
        OR EXISTS (SELECT FROM public.agenda_settings)
      THEN
        RAISE EXCEPTION 'refusing to drop populated consultation configuration'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """
  end
end
