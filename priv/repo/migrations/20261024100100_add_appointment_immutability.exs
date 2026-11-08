defmodule Origen.Repo.Migrations.AddAppointmentImmutability do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION public.reject_appointment_snapshot_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.snapshot_consultation_type_name IS DISTINCT FROM OLD.snapshot_consultation_type_name
        OR NEW.snapshot_duration_minutes IS DISTINCT FROM OLD.snapshot_duration_minutes
        OR NEW.snapshot_exact_price_ars IS DISTINCT FROM OLD.snapshot_exact_price_ars
        OR NEW.consultation_type_id IS DISTINCT FROM OLD.consultation_type_id
        OR NEW.patient_profile_id IS DISTINCT FROM OLD.patient_profile_id
        OR NEW.professional_account_id IS DISTINCT FROM OLD.professional_account_id
        OR NEW.start_time IS DISTINCT FROM OLD.start_time
        OR NEW.end_time IS DISTINCT FROM OLD.end_time
      THEN
        RAISE EXCEPTION 'appointment snapshots and core identity are immutable' USING ERRCODE = '23000';
      END IF;

      RETURN NEW;
    END;
    $$
    """)
  end

  def down do
    execute("""
    CREATE OR REPLACE FUNCTION public.reject_appointment_snapshot_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.snapshot_consultation_type_name IS DISTINCT FROM OLD.snapshot_consultation_type_name
        OR NEW.snapshot_duration_minutes IS DISTINCT FROM OLD.snapshot_duration_minutes
        OR NEW.snapshot_exact_price_ars IS DISTINCT FROM OLD.snapshot_exact_price_ars
        OR NEW.consultation_type_id IS DISTINCT FROM OLD.consultation_type_id
        OR NEW.patient_profile_id IS DISTINCT FROM OLD.patient_profile_id
        OR NEW.professional_account_id IS DISTINCT FROM OLD.professional_account_id
      THEN
        RAISE EXCEPTION 'appointment snapshots and core identity are immutable' USING ERRCODE = '23000';
      END IF;

      RETURN NEW;
    END;
    $$
    """)
  end
end
