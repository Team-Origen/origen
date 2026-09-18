defmodule Origen.Repo.Migrations.ExpandInternalAccountsRoles do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE public.internal_accounts
    DROP CONSTRAINT internal_accounts_role_check,
    ADD CONSTRAINT internal_accounts_role_check
      CHECK (role IN ('administrator', 'professional', 'secretary'))
    """)
  end

  def down do
    execute("""
    ALTER TABLE public.internal_accounts
    DROP CONSTRAINT internal_accounts_role_check,
    ADD CONSTRAINT internal_accounts_role_check
      CHECK (role = 'administrator')
    """)
  end
end
