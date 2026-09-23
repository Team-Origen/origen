defmodule Origen.Repo.Migrations.CreateFines do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.fines (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      patient_id bigint NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
      professional_id bigint NOT NULL REFERENCES public.internal_accounts(id) ON DELETE RESTRICT,
      amount_ars decimal(12,2) NOT NULL CHECK (amount_ars >= 0),
      reason text NOT NULL,
      status varchar(32) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'waived', 'cancelled')),
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      paid_at timestamptz(6)
    )
    """)

    execute("CREATE INDEX idx_fines_patient_professional ON public.fines (patient_id, professional_id)")
    execute("CREATE INDEX idx_fines_status ON public.fines (status)")

    for table <- ~w(fines) do
      execute("REVOKE ALL ON TABLE public.#{table} FROM PUBLIC")
    end

    for sequence <- ~w(fines_id_seq) do
      execute("REVOKE ALL ON SEQUENCE public.#{sequence} FROM PUBLIC")
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.fines TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.fines_id_seq TO origen_runtime;
      END IF;
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_verifier') THEN
        GRANT SELECT ON public.fines TO origen_verifier;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS public.fines")
  end
end