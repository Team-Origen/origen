defmodule Origen.Repo.Migrations.AddDeactivatedStateToInternalAccounts do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE public.internal_accounts
      DROP CONSTRAINT internal_accounts_state_check,
      ADD CONSTRAINT internal_accounts_state_check
        CHECK (state IN ('pending_activation', 'active', 'deactivated'))
    """)

    execute("""
    ALTER TABLE public.internal_accounts
      DROP CONSTRAINT internal_accounts_state_fields_check,
      ADD CONSTRAINT internal_accounts_state_fields_check CHECK (
        (state = 'pending_activation' AND password_hash IS NULL AND totp_secret IS NULL AND activated_at IS NULL)
        OR
        (state = 'active' AND password_hash IS NOT NULL AND totp_secret IS NOT NULL AND activated_at IS NOT NULL)
        OR
        (state = 'deactivated' AND (
          (password_hash IS NULL AND totp_secret IS NULL AND activated_at IS NULL)
          OR
          (password_hash IS NOT NULL AND totp_secret IS NOT NULL AND activated_at IS NOT NULL)
        ))
      )
    """)
  end

  def down do
    # A deactivated account has no representation in the previous constraint set:
    # refuse to remove the state while any row still uses it.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM public.internal_accounts WHERE state = 'deactivated') THEN
        RAISE EXCEPTION 'refusing to remove deactivated state while deactivated accounts exist'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """)

    execute("""
    ALTER TABLE public.internal_accounts
      DROP CONSTRAINT internal_accounts_state_fields_check,
      DROP CONSTRAINT internal_accounts_state_check,
      ADD CONSTRAINT internal_accounts_state_check
        CHECK (state IN ('pending_activation', 'active')),
      ADD CONSTRAINT internal_accounts_state_fields_check CHECK (
        (state = 'pending_activation' AND password_hash IS NULL AND totp_secret IS NULL AND activated_at IS NULL)
        OR
        (state = 'active' AND password_hash IS NOT NULL AND totp_secret IS NOT NULL AND activated_at IS NOT NULL)
      )
    """)
  end
end
