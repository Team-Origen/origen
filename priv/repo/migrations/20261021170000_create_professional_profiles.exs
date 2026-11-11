defmodule Origen.Repo.Migrations.CreateProfessionalProfiles do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.professional_profiles (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      owner_account_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      first_name text,
      last_name text,
      specialty text,
      license_type text,
      license_number text,
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT professional_profiles_owner_unique UNIQUE (owner_account_id)
    )
    """)

    execute("""
    CREATE TRIGGER professional_profiles_immutable_identity
    BEFORE UPDATE ON public.professional_profiles
    FOR EACH ROW EXECUTE FUNCTION public.reject_account_owned_identity_change()
    """)

    execute("REVOKE ALL ON TABLE public.professional_profiles FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.professional_profiles_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.professional_profiles TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.professional_profiles_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      LOCK TABLE public.professional_profiles IN ACCESS EXCLUSIVE MODE;
      IF EXISTS (SELECT FROM public.professional_profiles) THEN
        RAISE EXCEPTION 'refusing to drop populated professional profiles' USING ERRCODE = '55000';
      END IF;
    END
    $$
    """)

    execute("DROP TABLE public.professional_profiles")
  end
end
