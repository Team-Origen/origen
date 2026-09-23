defmodule Origen.Repo.Migrations.AddAppointmentOverlapExclusionConstraints do
  @moduledoc """
  Restricciones de exclusión PostgreSQL que impiden turnos solapados (Issue #65 / PLN-08).

  - `appointments_no_professional_overlap`: la agenda de un profesional no puede
    contener dos turnos activos que se solapen en `[start_time, end_time)`.
  - `appointments_no_patient_overlap`: un paciente no puede tener dos turnos
    activos que se solapen en `[start_time, end_time)`, incluso con distintos
    profesionales.

  Turno activo: `status NOT IN ('cancelled', 'rejected')`. Los intervalos son
  semiabiertos `[)`, por lo que los turnos contiguos (09:00-09:30 y 09:30-10:00)
  quedan permitidos.

  Bajo concurrencia, el índice GiST serializa dos transacciones que insertan
  rangos solapados para la misma agenda: la segunda queda bloqueada en el INSERT
  hasta que la primera confirme o aborte; si la primera confirma, la segunda
  recibe `exclusion_violation` (SQLSTATE 23P01). Esta es la garantía definitiva
  de integridad; la precondición de dominio en `Origen.Booking.Overlap` es solo
  una verificación amigable previa.
  """

  use Ecto.Migration

  def up do
    # btree_gist extiende GiST con igualdad escalar (bigint), requisito para
    # combinar `professional_account_id WITH =` y `tstzrange(...) WITH &&` en
    # una única restricción de exclusión. Es una extensión confiable (trusted):
    # el propietario de la base puede instalarla sin superusuario.
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_no_professional_overlap
    EXCLUDE USING gist (
      professional_account_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'rejected'))
    """)

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_no_patient_overlap
    EXCLUDE USING gist (
      patient_profile_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'rejected'))
    """)

    # Las restricciones no alteran privilegios: origen_runtime ya posee
    # SELECT/INSERT/UPDATE sobre public.appointments (migración
    # 20260926100000) y la validación de exclusión se ejecuta dentro del
    # motor de la tabla sin requerir permisos adicionales.
  end

  def down do
    execute("""
    ALTER TABLE public.appointments
    DROP CONSTRAINT IF EXISTS appointments_no_professional_overlap
    """)

    execute("""
    ALTER TABLE public.appointments
    DROP CONSTRAINT IF EXISTS appointments_no_patient_overlap
    """)

    # La extensión btree_gist es un objeto compartido de la base de datos y
    # es potencialmente usada por otros índices u operadores; no se desinstala
    # para no romper dependencias ajenas a esta migración.
  end
end
