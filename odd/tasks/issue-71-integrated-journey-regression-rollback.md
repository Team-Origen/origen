# Issue 71: Construir regresión de fallos y reversión del recorrido integrado

## Outcome

Construir y certificar una suite durable de regresión de fallos y reversión transaccional para el recorrido integrado (PLN-14 / Issue #71): verificar la resolución determinista ante solicitudes concurrentes en el mismo slot, rechazos estrictos ante perfiles incompletos o teléfonos no verificados, denegación de accesos no autorizados, rollback total ante fallos o conflictos (garantizando 0 turnos y 0 relaciones huérfanas) y ausencia total de filtración de datos ajenos en los mensajes de error.

## Problem

En un entorno médico compartido y concurrente, múltiples pacientes pueden disputar el mismo turno o intentar reservar sin haber completado los requisitos de verificación (RF-02 ter). Asimismo, pueden ocurrir fallas transaccionales de red o concurrencia. Es indispensable garantizar que el sistema nunca deje la base de datos en estado inconsistente (turnos sin paciente, relaciones espurias o auditoría parcial) y que los mensajes de error nunca expongan la identidad ni datos de otros pacientes.

## Why

Garantizar la resiliencia transaccional, integridad de datos y confidencialidad médica del prototipo bajo condiciones adversas de concurrencia y fallos, previniendo sobreturnos no autorizados y vulnerabilidades de enumeración o fuga de información privada.

## Authorized scope

- Suite automatizada de regresión de fallos: `test/origen/integration/journey_failure_regression_test.exs`.
- Script ejecutable reproducible de fallos y reversión: `priv/repo/check_journey_failure_regression.exs`.
- Documento de seguimiento ODD: `odd/tasks/issue-71-integrated-journey-regression-rollback.md`.
- Rama local: `feature/71-integrated-journey-regression-rollback`.
- Pull Request: enlazado a la subissue mediante `Closes #71`.

## Checklist

- [x] ODD-71-01 — Crear rama de trabajo `feature/71-integrated-journey-regression-rollback` y verificar baseline limpio.
- [x] ODD-71-02 — Construir suite de regresión de fallos y concurrencia (`test/origen/integration/journey_failure_regression_test.exs`): concurrencia real simultánea (`Task.async`), perfiles incompletos, teléfonos no verificados y accesos denegados.
- [x] ODD-71-03 — Probar rollback completo y verificar forensemente la ausencia de turnos y relaciones huérfanas ante fallos y solapamientos.
- [x] ODD-71-04 — Verificar que los mensajes de rechazo y error no expongan datos ajenos (no enumerantes ni filtrantes).
- [x] ODD-71-05 — Construir script ejecutable reproducible (`priv/repo/check_journey_failure_regression.exs`) para verificación forense de fallos y reversión.
- [x] ODD-71-06 — Ejecutar suite completa, formato, verificación de advertencias y documentar evidencia en el artefacto ODD.
- [x] ODD-71-07 — Preparar commit de unidad de trabajo y Pull Request enlazado a la subissue (`Closes #71`).

## Acceptance criteria

- [x] Prueba solicitudes concurrentes, perfiles incompletos y accesos denegados.
- [x] Verifica rollback completo ante fallos o conflictos.
- [x] Comprueba que no queden turnos o relaciones huérfanas ni se expongan datos ajenos.
- [x] Entrega evidencia reproducible ejecutable por el equipo.

## Applicable checks

- `mix test test/origen/integration/journey_failure_regression_test.exs` (12 passed)
- `mix run priv/repo/check_journey_failure_regression.exs` (ejecución exitosa, 0 warnings)
- `mix test test/origen/integration/` (17 passed)
- `mix test` (623 passed, 0 failures)
- `mix compile --warnings-as-errors` (limpio)
- `mix format --check-formatted` (limpio)

## Progress and evidence

- Rama `feature/71-integrated-journey-regression-rollback` creada a partir de `feature/70-integrate-prototype-journey`.
- Suite automatizada de regresión de fallos creada en `test/origen/integration/journey_failure_regression_test.exs` con 12 pruebas divididas en:
  1. Concurrencia real simultánea (`Origen.Integration.JourneyConcurrencyRegressionTest`): 3 procesos independientes disputan el mismo slot exacto; exactamente 1 gana y los 2 restantes son rechazados atómicamente con `{:error, :slot_already_booked}`, dejando exactamente 1 turno registrado en PostgreSQL.
  2. Perfiles incompletos y barreras de identidad:
     - Usuario no autenticado (`nil`): rechazado con `{:error, :unauthenticated}`.
     - Perfil en estado `pending_completion`: rechazado con `{:error, :patient_not_ready_for_booking}`.
     - Perfil `completed` sin teléfono verificado: rechazado con `{:error, :patient_not_ready_for_booking}`.
     - Colisión documental de DNI (RF-02): derivado a secretaría (`pending_secretary_review`), no duplicación de Persona y bloqueo de reserva.
  3. Reversión transaccional y ausencia de orfandad:
     - Conflicto por solapamiento: transacción abortada y 0 turnos huérfanos.
     - Fallo inducido en inserción de relación (`fail_at: :relationship`): rollback total de turno y auditoría.
     - Fallo inducido en auditoría (`fail_at: :audit_event`): rollback total de turno y relación.
     - Integridad forense relacional: 0 turnos sin paciente/profesional y 0 relaciones sin entidades válidas.
  4. Confidencialidad y minimización de errores:
     - El error `:slot_already_booked` es opaco y no expone datos personales del titular del turno (email, nombre, teléfono o DNI).
     - Inmunidad contra manipulación de identificadores (IDOR): parámetros maliciosos inyectados en la consulta de agenda son ignorados por el backend; la agenda se filtra siempre por la sesión revalidada del profesional.
     - Sesiones revocadas: acceso denegado inmediatamente con `{:error, :unauthorized}` sin exponer datos.
- Script ejecutable reproducible creado en `priv/repo/check_journey_failure_regression.exs`:
  - Ejecutable con `mix run priv/repo/check_journey_failure_regression.exs`.
  - Simula y valida los 4 escenarios de fallo en tiempo real imprimiendo la corroboración forense en terminal sin advertencias.
