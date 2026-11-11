defmodule Origen.Repo.Migrations.AddSecretaryApprovalModeToAgendaSettings do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE public.agenda_settings
      ADD COLUMN secretary_approval_mode varchar(16) NOT NULL DEFAULT 'confirmed',
      ADD CONSTRAINT agenda_settings_secretary_approval_mode_check
        CHECK (secretary_approval_mode IN ('confirmed', 'requested'))
    """)
  end

  def down do
    execute("""
    ALTER TABLE public.agenda_settings
      DROP CONSTRAINT IF EXISTS agenda_settings_secretary_approval_mode_check,
      DROP COLUMN IF EXISTS secretary_approval_mode
    """)
  end
end
