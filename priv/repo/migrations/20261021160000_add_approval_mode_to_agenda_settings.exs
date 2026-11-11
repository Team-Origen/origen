defmodule Origen.Repo.Migrations.AddApprovalModeToAgendaSettings do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE public.agenda_settings
      ADD COLUMN approval_mode varchar(16) NOT NULL DEFAULT 'automatic',
      ADD CONSTRAINT agenda_settings_approval_mode_check
        CHECK (approval_mode IN ('automatic', 'manual'))
    """)
  end

  def down do
    execute("""
    ALTER TABLE public.agenda_settings
      DROP CONSTRAINT IF EXISTS agenda_settings_approval_mode_check,
      DROP COLUMN IF EXISTS approval_mode
    """)
  end
end
