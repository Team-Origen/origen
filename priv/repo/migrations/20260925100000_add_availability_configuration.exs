defmodule Origen.Repo.Migrations.AddAvailabilityConfiguration do
  use Ecto.Migration

  @default_week ~s({"monday":[{"end":"12:00","start":"08:00"},{"end":"18:00","start":"14:00"}],"tuesday":[{"end":"12:00","start":"08:00"},{"end":"18:00","start":"14:00"}],"wednesday":[{"end":"12:00","start":"08:00"},{"end":"18:00","start":"14:00"}],"thursday":[{"end":"12:00","start":"08:00"},{"end":"18:00","start":"14:00"}],"friday":[{"end":"12:00","start":"08:00"},{"end":"18:00","start":"14:00"}],"saturday":[],"sunday":[]})

  def up do
    execute("""
    ALTER TABLE public.agenda_settings
      ADD COLUMN weekly_availability jsonb NOT NULL DEFAULT '#{@default_week}'::jsonb,
      ADD COLUMN booking_horizon_days integer NOT NULL DEFAULT 30,
      ADD COLUMN minimum_lead_minutes integer NOT NULL DEFAULT 30,
      ADD CONSTRAINT agenda_settings_booking_horizon_check
        CHECK (booking_horizon_days BETWEEN 7 AND 90),
      ADD CONSTRAINT agenda_settings_minimum_lead_check
        CHECK (minimum_lead_minutes BETWEEN 0 AND 1440 AND minimum_lead_minutes % 5 = 0)
    """)
  end

  def down do
    execute(rollback_guard_sql())

    execute("""
    ALTER TABLE public.agenda_settings
      DROP COLUMN minimum_lead_minutes,
      DROP COLUMN booking_horizon_days,
      DROP COLUMN weekly_availability
    """)
  end

  def rollback_guard_sql do
    """
    DO $$
    BEGIN
      LOCK TABLE public.agenda_settings IN ACCESS EXCLUSIVE MODE;

      IF EXISTS (
        SELECT FROM public.agenda_settings
        WHERE weekly_availability IS DISTINCT FROM '#{@default_week}'::jsonb
           OR booking_horizon_days IS DISTINCT FROM 30
           OR minimum_lead_minutes IS DISTINCT FROM 30
      ) THEN
        RAISE EXCEPTION 'refusing to remove persisted availability configuration'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """
  end
end
