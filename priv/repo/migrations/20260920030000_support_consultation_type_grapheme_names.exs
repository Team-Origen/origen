defmodule Origen.Repo.Migrations.SupportConsultationTypeGraphemeNames do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE public.consultation_types
    DROP CONSTRAINT consultation_types_name_check,
    ALTER COLUMN name TYPE text,
    ADD CONSTRAINT consultation_types_name_check CHECK (btrim(name) <> '')
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT FROM public.consultation_types WHERE char_length(name) > 32
      ) THEN
        RAISE EXCEPTION 'refusing to narrow persisted consultation type names'
          USING ERRCODE = '22001';
      END IF;
    END
    $$
    """)

    execute("""
    ALTER TABLE public.consultation_types
    DROP CONSTRAINT consultation_types_name_check,
    ALTER COLUMN name TYPE varchar(32),
    ADD CONSTRAINT consultation_types_name_check CHECK (
      btrim(name) <> '' AND char_length(name) <= 32
    )
    """)
  end
end
