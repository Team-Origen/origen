# Fix patient bookings with an existing relationship — #434
Branch: `fix/434-patient-existing-relationship` (from `3cb24c7`); delivery: `ask-on-risk`; forecast: ~300–400 authored lines.
Runner: isolated PostgreSQL SQL Sandbox with `MIX_ENV=test mix test`; no application/development data writes.

## Specs

S1. Bueno, ahora implementa el arreglo. Realiza la subissue #434, cumple con los criterios de aceptación y desarrollala de forma ordenada y prolija. Crea una nueva rama.

S2. Antes de modificar código, se verificaron y registraron las URLs vigentes, su correspondencia con la convención canónica y la compatibilidad de las rutas anteriores.

S3. La primera reserva del Paciente sin relación previa sigue funcionando y establece una única relación.

S4. El Paciente puede reservar otro turno con el mismo profesional cuando el primer turno fue registrado por el propio Paciente.

S5. El Paciente puede reservar otro turno con el mismo profesional cuando el primer turno fue registrado por el Profesional.

S6. El Paciente puede reservar otro turno con el mismo profesional cuando el primer turno fue registrado por Secretaría.

S7. Las nuevas reservas conservan una única relación y no alteran su identificador, fecha de establecimiento ni referencia al turno originario.

S8. Los casos anteriores funcionan con aprobación automática y manual, conservando el estado correspondiente.

S9. Se mantienen las validaciones de disponibilidad, solapamientos y autorización, sin efectos parciales ante rechazos.

S10. Secretaría y Profesional siguen pudiendo registrar nuevos turnos cuando la relación ya existe.

S11. Las pruebas de regresión reproducen el fallo antes del arreglo y pasan después.

S12. Registrar las rutas vigentes y referencias a la documentación y router revisados. Aportar RED/GREEN de la regresión a través del recorrido del Paciente para los tres roles de origen y ambos modos de aprobación, usando datos ficticios en estado aislado. Verificar persistencia de ambos turnos, unicidad e invariancia de la relación original, y ausencia de efectos parciales ante rechazos. Adjuntar comprobaciones de regresión para las reservas desde Secretaría y Profesional. Registrar comandos, resultados y limitaciones, sin datos personales, credenciales ni tokens.

## Tasks

- T1 | S1–S2 | parent/explorer | done | Branch created; route review: current `/patient/calendar`, access `/access`; Spanish routes remain planned, no alias present on this checkout. Commit: `73c3cb2` (traceability); this document records preparation.
- T2 | S3–S12 | gentle-ai-worker + parent test execution | done | Behavioral RED: six expected failures; GREEN: 26 passed. Affected suite: 71 passed, 1 skipped. Final corrected integration: 3 passed. Commit: `73c3cb2`.
- T3 | S2–S12 | parent + gentle-ai-verify (Risk item 4: transaction conflict handling) | done | Final full suite: 926 passed, 32 skipped, 8 excluded; independent verification approved S3–S12. OpenSpec traceability and reviewed implementation committed as `73c3cb2`; this document closes the evidence record.

## Log

L1. Bueno, ahora implementa el arreglo. Realiza la subissue #434, cumple con los criterios de aceptación y desarrollala de forma ordenada y prolija. Crea una nueva rama.

L2. Authoritative issue #434 at implementation start (verbatim):

### Objetivo

Permitir que el Paciente reserve nuevos turnos con un profesional con quien ya existe una relación, sin importar si el primer turno fue registrado por el propio Paciente, el Profesional o Secretaría.

### Contexto y alcance

Relacionado con #280 — Reserva propia del Paciente, y #308 — Integración y verificación de reserva propia del Paciente. Este bug es un seguimiento correctivo de ese alcance; no requiere reabrir esas issues ni afirma, sin evidencia histórica, qué cambio introdujo el defecto.

La relación paciente-profesional se crea cuando se registra el primer turno que vincula a ambas entidades. Debe persistir y permitir nuevos turnos entre el mismo paciente y profesional.

Según la reproducción manual reportada, Secretaría y Profesional pueden crear más de un turno para un mismo paciente. El fallo ocurre cuando el Paciente solicita un nuevo turno con un profesional con quien ya tiene una relación, independientemente de cuál de los tres roles registró el turno que la originó.

Mensaje observado:

> No se pudo completar la reserva. Volvé a intentar más tarde.

#### Reproducción

Repetir con cada rol de origen: Paciente, Profesional y Secretaría.

1. Contar con un paciente y un profesional sin relación previa entre sí.
2. Registrar un primer turno entre ambos desde el rol que se está probando.
3. Comprobar que el turno se registró y estableció la relación.
4. Ingresar con la cuenta de ese Paciente y abrir el recorrido vigente de reserva.
5. Seleccionar el mismo profesional y otro horario disponible, sin superposición.
6. Confirmar la reserva.

Resultado actual: la nueva reserva desde Paciente falla con el mensaje genérico.

Resultado esperado: se registra el nuevo turno con el estado correspondiente a la configuración del profesional y se reutiliza una única relación existente.

| Origen del primer turno y de la relación | Quién solicita el nuevo turno | Resultado esperado |
| --- | --- | --- |
| Paciente | Paciente | Reserva exitosa |
| Profesional | Paciente | Reserva exitosa |
| Secretaría | Paciente | Reserva exitosa |

#### Evidencia técnica y diagnóstico

La investigación de solo lectura verificó catálogo y disponibilidad reales (`DatabaseCatalog` y `DatabaseCalendar`), con modo demo desactivado. Los logs muestran que los intentos llegan al servicio y fallan en un INSERT sobre `professional_patient_relationships`, seguido de rollback. Para la pareja afectada ya existe una relación y la tabla tiene una restricción única por pareja profesional-paciente.

`lib/origen/appointments/booking_service.ex`, función `establish_relationship!/1`, intenta insertar la relación y contempla el error de unicidad dentro de la transacción. Causa probable: el error SQL deja abortada la transacción aunque el código trate el conflicto como aceptable. No se capturó el SQLSTATE exacto; confirmar el diagnóstico con una prueba de regresión antes del arreglo.

No se encontró evidencia de que el cambio de URLs cause el fallo: en la instancia investigada, `/patient/calendar` redirigió a `/paciente/turnos/reservar`, y esta última, sin sesión, a `/paciente/acceso`. Estos valores son evidencia histórica, no sustituyen la verificación previa de rutas vigentes.

#### Verificación previa obligatoria: URLs vigentes

Antes de implementar el arreglo:

1. Leer `docs/navigation/URL_CONVENTIONS.md`.
2. Contrastar sus convenciones y destinos con `lib/origen_web/router.ex` y los enlaces y redirecciones del recorrido.
3. Confirmar las URLs vigentes de acceso y reserva del Paciente y el tratamiento de las rutas anteriores.
4. Usar las rutas vigentes en implementación y pruebas, sin asumir que las URLs históricas de #280 o #308 siguen siendo canónicas.
5. Si documentación y código difieren, registrar la discrepancia y resolver cuál corresponde antes de modificar el recorrido.

Esta revisión no autoriza otra migración de URLs ni un rediseño de navegación.

#### Alcance del arreglo

Crear la relación cuando no exista y reutilizarla cuando exista, cualquiera sea el rol que registró el primer turno. Conservar sus datos originales y evitar que una relación existente revierta una reserva válida. No eliminar la restricción de unicidad ni borrar relaciones como solución.

#### OpenSpec

- Change: `health-center-beta-core`
- Path: `openspec/changes/health-center-beta-core/`
- Scope: Corrección de la reserva propia del Paciente cuando ya existe una relación con el profesional, independientemente del rol que la originó, dentro del alcance de #280.

### Área principal

Backend

### Criterios de aceptación

- [ ] Antes de modificar código, se verificaron y registraron las URLs vigentes, su correspondencia con la convención canónica y la compatibilidad de las rutas anteriores.
- [ ] La primera reserva del Paciente sin relación previa sigue funcionando y establece una única relación.
- [ ] El Paciente puede reservar otro turno con el mismo profesional cuando el primer turno fue registrado por el propio Paciente.
- [ ] El Paciente puede reservar otro turno con el mismo profesional cuando el primer turno fue registrado por el Profesional.
- [ ] El Paciente puede reservar otro turno con el mismo profesional cuando el primer turno fue registrado por Secretaría.
- [ ] Las nuevas reservas conservan una única relación y no alteran su identificador, fecha de establecimiento ni referencia al turno originario.
- [ ] Los casos anteriores funcionan con aprobación automática y manual, conservando el estado correspondiente.
- [ ] Se mantienen las validaciones de disponibilidad, solapamientos y autorización, sin efectos parciales ante rechazos.
- [ ] Secretaría y Profesional siguen pudiendo registrar nuevos turnos cuando la relación ya existe.
- [ ] Las pruebas de regresión reproducen el fallo antes del arreglo y pasan después.

### Dependencias y bloqueos

Seguimiento correctivo de #280 y #308, ambas cerradas; no se requiere reabrirlas. No se identificaron bloqueos externos para iniciar el diagnóstico y la corrección acotada. La verificación de URLs y la reproducción automatizada son pasos previos obligatorios del trabajo.

### Fuera de alcance

- Migrar URLs o rediseñar navegación.
- Modificar autenticación o permisos.
- Cambiar las reglas de aprobación de turnos.
- Rediseñar la relación paciente-profesional o eliminar su restricción de unicidad.
- Eliminar o alterar datos históricos para evitar el error.
- Reabrir #280 o #308.
- Corregir defectos no relacionados.

### Evidencia esperada

Registrar las rutas vigentes y referencias a la documentación y router revisados. Aportar RED/GREEN de la regresión a través del recorrido del Paciente para los tres roles de origen y ambos modos de aprobación, usando datos ficticios en estado aislado. Verificar persistencia de ambos turnos, unicidad e invariancia de la relación original, y ausencia de efectos parciales ante rechazos. Adjuntar comprobaciones de regresión para las reservas desde Secretaría y Profesional. Registrar comandos, resultados y limitaciones, sin datos personales, credenciales ni tokens.


L3. Preparation: clean worktree; feature branch starts at the existing checkout `3cb24c7` (128 commits ahead of local develop). No checkout reset or URL migration. Current routes differ from earlier reported instance: `/patient/calendar` exists; `/paciente/turnos/reservar` is a documented planned migration. Use routes actually implemented, preserving authorization. Explorer handoff checked against router and URL convention table. RED not yet run. RDD off.

L4. Worker `mw82hb8a-3-fc4z` finished partial; no active child. Added targeted `Repo.insert(on_conflict: :nothing, conflict_target: [:professional_account_id, :patient_profile_id])` and six LiveView regression cases (three origin roles × two approval modes), plus Secretary existing-relation regression. Diff: 157 additions / 2 deletions across three files. No shared helper or route modified. Parent reviewed diff; functional assertions remain unverified.

L5. Setup failure, NOT behavioral RED: `MIX_ENV=test mix test test/origen_web/live/patient_booking_calendar_live_test.exs` exited 1; connection to `localhost:5433` refused during database creation, **0 tests ran**. stdout/stderr and status preserved at `/tmp/gpKYT4S6/ga02QzV6/tmp.QSN8L7Bshs/red.log` and `red-status.log`. No retry. Worker reported `mix format --check-formatted` for changed files and `git diff --check` passed. GREEN, rejection regressions, affected suite, full suite, and independent functional verification remain pending. No completion or delivery claim; no commit/push.

L6. Read-only environment diagnosis: `config/test.exs:8-34` supports `ORIGEN_TEST_DB_PORT` and selects sandbox database `origen_test` unless a runtime database URL overrides it. No runtime URL was set in this session. `pg_lsclusters` shows local PostgreSQL 18/main online at port 5432, not 5433. No database probes, configuration changes, service changes, or application data writes were performed by the parent. A new bounded verification attempt requires an explicit human request after selecting/validating the isolated test endpoint. Need preserve original setup failure and reproduce against original service before claiming RED, then current implementation GREEN. Risk: item 4 (transaction conflict handling); independent verifier still required. Task remains blocked, not complete.

L7. Independent verifier `mw82s0f6-4-ra08` finished partial: target matches unique index; original fields preserved; no shared helper changed. Format/diff/compile checks passed; no DB tests run. S3–S12 remained functionally unverified.

L8. Human authorization (verbatim): Autorizo que configures la ejecución para ese PostgreSQL

L9. Preparation for new authorized cycle: no active children. Port 5432 ready. Default-role read-only metadata query lacked credentials; used the explicit local test credentials documented in `docs/sprints/contracts/305-reserva-propia-paciente.md:73` (not reproduced in logs). Metadata validation succeeded: PostgreSQL18.6, role can create test database. Dedicated database `origen_test434` does not exist; use `MIX_TEST_PARTITION=434`, explicit test-only environment and no `ORIGEN_DATABASE_URL` to isolate from application data. Scratch capacity validated (946GB free); no oversized copy needed. Prior failed verification is retained, not reclassified as RED.

L10. Worker credential-boundary interaction resolved via option 2: parent-only execution and raw evidence relay, no secret injection or worker credential reads. Worker follow-ups `mw832y55-6-7dst` and `mw83bhpt-8-4n7x` completed; one behavioral correction round used (of three), none exhausted. Parent preserves source bytes when comparing original insert and restores fixed SHA256 `aaa705a02625dd8a4c69be55c4ae51067d143937ffa2e5fa15c5e4f86ceecd44` in finally.

L11. Executed with test-only env (`MIX_ENV=test`, `ORIGEN_TEST_DB_PORT=5432`, `MIX_TEST_PARTITION=434`, no runtime DB URL; credentials process-only): setup `mix do ecto.create, ecto.migrate` exit0; primary `mix test test/origen_web/live/patient_booking_calendar_live_test.exs --seed 434` RED exit2 (20/26 passed, six expected generic-message failures), fixed GREEN exit0 (26 passed). Logs: `/tmp/gpKYT4S6/issue434-cycle-xkdgm_1h/{setup,red,green}.{stdout,stderr,status}`. SQL Sandbox isolates each fictitious-data test.

L12. Affected six-file suite exit0: 71 passed, 1 skipped. First complete suite exit2: 924/926 passed, 32 skipped, 8 excluded. Failures: integration expected the old duplicate-relation rollback; unrelated catalog editor-collapse assertion. Corrected only the integration expectation, asserting the authenticated patient receives the appointment, client-forged patient IDs are ignored, original appointment/relation remain unchanged and the other patient receives no records. Catalog not modified; isolated original-source and fixed-source catalog probes both passed (1 passed, 52 excluded each), so no claim its transient failure was diagnosed or fixed.

L13. Corrected integration subset exit0 (3 passed); final `mix test --seed 434` exit0 (926 passed, 32 skipped, 8 excluded). Evidence files `{affected,full,baseline-catalog,fixed-catalog,corrected-integration,full-corrected}.{stdout,stderr,status}` under L11 directory. Existing skipped tests and `postgres_security` exclusions retained, not counted as passes. Runtime warnings: Erlang/OTP regex compatibility and existing deprecated compatibility-helper tests. No timeout; no unrelated fixes. Full-suite source/test state includes every final assertion.

L14. Independent verifier `mw83ioh6-9-nc0u`: approve within verification scope, all S3–S12 met. It inspected final source, exact unique index, public API tests, and raw parent execution artifacts; did not execute DB tests itself. No behavioral blocker remains for Risk item 4. No unrequested shared helper, parser, URL, auth, config, or contract change; differential checks for unrelated shared consumers are not applicable. Remaining work is traceability, final structural checks, and local commit only; push/PR/merge not authorized.

L15. Human continuation (verbatim): Prosigue con lo que estabas haciendo.

L16. Closure: `mix format --check-formatted` on all six changed Elixir files and `git diff --check` passed. Added corrective #434 reverse reference under OpenSpec proposal Tracking. Implementation work-unit commit `73c3cb2d1c6d8d193bf2e410b28581dff50b2327` (`fix(booking): reuse patient relationships without aborting reservations`): 231 additions, 7 deletions across seven files. Tracking is a separate documentation-only closing unit (~170 lines); no behavior changed after the full suite. RDD off; no native review started. No push, PR, merge, or issue closure performed.

L17. Route evidence: `docs/navigation/URL_CONVENTIONS.md:40–42` lists the Spanish destinations as planned; `lib/origen_web/router.ex:45–51` mounts `/access`, `/access/verify` and `/patient/calendar`. Current patient authorization tests assert absent/invalidated sessions redirect to `/access`. This checkout has not migrated those routes, so historical reports of Spanish redirects do not apply here. No links/redirects/routes changed.

L18. Reproduction commands: with the isolated env in L11, affected suite was `mix test test/origen/appointments/booking_service_test.exs test/origen/appointments/patient_self_booking_test.exs test/origen_web/live/patient_booking_calendar_live_test.exs test/origen/booking/atomic_reservation_test.exs test/origen/booking/professional_booking_test.exs test/origen_web/live/secretary_booking_integration_test.exs --seed 434`; corrected integration was `mix test test/origen/integration/patient_self_booking_test.exs --seed 434`. Final full suite is the complete verification of their combined final state. The unrelated one-off catalog failure and initial setup failure remain disclosed in L5/L12; neither is represented as a successful check. All implementation acceptance tasks are complete; next optional action is human-authorized publication/review.
