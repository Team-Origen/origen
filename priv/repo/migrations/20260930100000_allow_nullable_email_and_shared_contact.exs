defmodule Origen.Repo.Migrations.AllowNullableEmailAndSharedContact do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE public.patient_profiles ALTER COLUMN email DROP NOT NULL")

    execute(
      "ALTER TABLE public.patient_profiles DROP CONSTRAINT IF EXISTS patient_profiles_email_key"
    )

    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS patient_profiles_email_key ON public.patient_profiles (email) WHERE email IS NOT NULL"
    )

    execute("ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS contact_email text")
  end

  def down do
    execute("ALTER TABLE public.patient_profiles DROP COLUMN IF EXISTS contact_email")
    execute("DROP INDEX IF EXISTS public.patient_profiles_email_key")

    execute(
      "UPDATE public.patient_profiles SET email = 'rollback-' || id || '@origen.local' WHERE email IS NULL"
    )

    execute(
      "ALTER TABLE public.patient_profiles ADD CONSTRAINT patient_profiles_email_key UNIQUE (email)"
    )

    execute("ALTER TABLE public.patient_profiles ALTER COLUMN email SET NOT NULL")
  end
end
