defmodule Origen.Repo.Migrations.CreateProfessionalPatientRelationships do
  @moduledoc """
  Tabla durable de la relación Profesional-Paciente (Issue #66 / PLN-08, RF-05).

  Cada fila registra la primera vez que un paciente persiste un turno válido
  (`reserved` / `confirmed`) con un profesional, de forma auditable: el reloj de
  la base de datos fija `established_at` (`clock_timestamp()`) y
  `first_appointment_id` apunta al turno originario. El par
  `(professional_account_id, patient_profile_id)` es único: la relación se
  establece una sola vez y jamás se duplica.
  """

  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.professional_patient_relationships (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      professional_account_id bigint NOT NULL
        REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      patient_profile_id bigint NOT NULL
        REFERENCES public.patient_profiles(id) ON DELETE RESTRICT,
      established_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      first_appointment_id bigint
        REFERENCES public.appointments(id) ON DELETE RESTRICT,
      CONSTRAINT professional_patient_relationships_unique_pair
        UNIQUE (professional_account_id, patient_profile_id)
    )
    """)

    execute("""
    CREATE INDEX professional_patient_relationships_patient_idx
    ON public.professional_patient_relationships (patient_profile_id)
    """)

    execute("REVOKE ALL ON TABLE public.professional_patient_relationships FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.professional_patient_relationships_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT ON public.professional_patient_relationships TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.professional_patient_relationships_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute(rollback_guard_sql())

    execute("DROP TABLE IF EXISTS public.professional_patient_relationships")
  end

  defp rollback_guard_sql do
    """
    DO $$
    BEGIN
      IF to_regclass('public.professional_patient_relationships') IS NOT NULL
        AND EXISTS (SELECT FROM public.professional_patient_relationships) THEN
        RAISE EXCEPTION 'refusing to drop populated professional_patient_relationships'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """
  end
end
