defmodule Origen.Repo.Migrations.AddEmailToInternalAccounts do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE public.internal_accounts
    ADD COLUMN email text;
    """)

    execute("""
    CREATE UNIQUE INDEX internal_accounts_lower_email_idx
    ON public.internal_accounts (lower(email))
    WHERE email IS NOT NULL;
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS public.internal_accounts_lower_email_idx")

    execute("""
    ALTER TABLE public.internal_accounts
    DROP COLUMN IF EXISTS email;
    """)
  end
end
