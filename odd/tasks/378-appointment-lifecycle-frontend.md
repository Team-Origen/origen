# Issue 378 — Appointment lifecycle frontend
Branch: `feat/378-appointment-lifecycle-frontend`; base: `5284df1`; delivery: auto-chain / stacked-to-main (`develop`); no publication authorized.
Runner: Phoenix LiveView / `mix test`; forecast: 900–1600 authored lines in patient, professional, secretary work units plus final verification; slices kept as cohesive commits, no PRs opened.

## Specs

### S1 — Original implementation authorization
Tengo que iniciar con la subissue #378 (el frontend del ciclo operativo del turno). Implementa el frontend según lo que pide la subissue. Alimenta las decisiones que vayas a tomar de la documentación de origen según lo que te indique la subissue. Cumple con los criterios de aceptación y desarrolla el frontend de forma prolija. Voy a dejar ejecutando el agente por un tiempo, sin estar con la computadora. Crea la rama correspondiente e inicia con la implementación del frontend.

### S2 — Issue 378 authoritative scope and acceptance criteria (verbatim)
### Objetivo

Implementar y probar la interfaz de #285 dentro de su alcance aprobado.

### Contexto y alcance

Issue padre: #285. Mapa aprobado: #266. Sprint 4 — Operación y beta integrada.

Vencimiento, cancelación, asistencia, ausencia e historial del turno, respetando permisos y privacidad existentes.

## OpenSpec

- Change: `health-center-beta-core`
- Path: `openspec/changes/health-center-beta-core/`
- Scope: Sprint 4 / parent #285 / implementation slice 10 of 17 / frontend

### Lecturas obligatorias

- Leer completa la padre #285, sus comentarios/decisiones vigentes y sus dependencias.
- Consultar `openspec/changes/health-center-beta-core/proposal.md` y `openspec/changes/health-center-beta-core/design.md`.
- Leer `openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md`: Expiry, cancellation, attendance, and history.
- Consultar `openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md` y `docs/sprints/GUIA_TRABAJO_BETA.md`.

Componentes, formularios, mensajes y estados visuales del recorrido propio. Reutilizar componentes y permisos vigentes; la visibilidad del menú no sustituye autorización. No inventar backend ni alterar contratos de otros slices.

### Área principal

Frontend

### Criterios de aceptación

- [ ] El Paciente puede ingresar a «Mis turnos» y consultar todos sus propios turnos y su historial, con sus estados, sin ver turnos ajenos. Esta consulta debe estar disponible al volver a ingresar, no solo como confirmación de la reserva recién creada. La entrada de navegación debe abrir la pantalla funcional, no un aviso de sección pendiente. Desde esa pantalla puede cancelar sus solicitudes o turnos confirmados estrictamente antes del inicio, sin multa, y consultar el origen y el motivo de las cancelaciones realizadas por el personal.
- [ ] Profesional: desde su agenda, puede cancelar solicitudes o turnos confirmados de su propia agenda con motivo obligatorio, y registrar asistencia o ausencia únicamente sobre turnos confirmados.
- [ ] Secretaría: puede cancelar solicitudes o turnos confirmados de cualquier agenda del centro con motivo obligatorio, y registrar asistencia o ausencia únicamente sobre turnos confirmados.
- [ ] Las pantallas utilizan las operaciones reales del backend de #377 y respetan sus autorizaciones y transiciones. Ocultar botones no sustituye la validación del servidor. El Paciente no puede registrar asistencia o ausencia.
- [ ] Implementar la presentación e interacciones aplicables a los puntos siguientes, conforme al contrato o decisión aprobados:
- [ ] Una solicitud no resuelta pasa a expired al llegar su inicio: permanece en historial, libera la ocupación y no se confirma ni produce ausencia o multa.
- [ ] El Paciente cancela sus solicitudes o turnos confirmados antes del inicio, sin multa y liberando horario; Profesional en su agenda y Secretaría en todas cancelan con motivo visible al paciente y origen distinguible, sin notificación automática implícita.
- [ ] Profesional y Secretaría marcan asistencia o ausencia dentro de su alcance autorizado; los estados y el historial son observables sin exponer actividad de otros profesionales.
- [ ] Cambiar fecha, hora o tipo de consulta exige cancelar y crear otro turno, nunca reprogramar directamente.
- [ ] Ejecutar pruebas de interfaz y regresiones aplicables al recorrido afectado; identificar expresamente el uso de fixtures/dobles, que no prueba integración real.
- [ ] Registrar evidencia y aprobación de esta parte sin declarar terminada la padre antes de la integración.

### Dependencias y bloqueos

Blockers nativos directos de esta hija: #376.

Blockers de la padre, que se conservan: #284. No se copian automáticamente a preparación o implementación independiente; la Integración final los tendrá explícitos. Solo adelantar trabajo realmente independiente, sin duplicar otro slice ni suponer un contrato pendiente.

Si aparece una dependencia técnica imprescindible no registrada, documentar el comportamiento impedido y evidencia y consultar el ajuste del plan antes de añadirla o condicionar el cierre. No añadir bloqueos hacia funcionalidades posteriores.

### Fuera de alcance

Sin WhatsApp, multas, notificaciones automáticas ni reprogramación directa. No exigir bloqueos puntuales, pagos o resumen económico de slices posteriores. No asignar responsables o aprobadores distintos, agregar requisitos ajenos ni declarar aprobaciones por anticipado.

### Evidencia esperada

Pruebas de interfaz con resultados observados y evidencia visual/funcional aplicable; diferenciar fixtures de conexión real y registrar aprobación.


## Tasks

- T1 [S1,S2] Patient persistent appointments/history, navigation and own cancellation; route: gentle-ai-worker (context backstop); status: done; commit: 491e29b; checks: 9 focused tests passed, format/whitespace passed; independent feature verification pending T4.
- T2 [S1,S2] Professional own-agenda lifecycle controls/history; route: gentle-ai-worker (context backstop); status: done; commit: 2ff45e3; checks: RED 6 failures then GREEN 50 tests; format/whitespace passed.
- T3 [S1,S2] Secretary center-agenda lifecycle controls/history; route: gentle-ai-worker (context backstop); status: done; commit: ad3ff27; checks: RED 6 failures then GREEN 6 secretary tests, 54 scoped regressions; format/whitespace passed.
- T4 [S1,S2] Integrated regression, independent privacy/security verification, evidence and approval status; route: parent + gentle-ai-verify; status: blocked; commit: pending (local integration fixes); waits for: explicit authorization for one new bounded independent verification attempt after setup repair; missing full-suite/baseline proof; Risk: item 2 (private history, server authorization boundaries).

## Log

L1: Tengo que iniciar con la subissue #378 (el frontend del ciclo operativo del turno). Implementa el frontend según lo que pide la subissue. Alimenta las decisiones que vayas a tomar de la documentación de origen según lo que te indique la subissue. Cumple con los criterios de aceptación y desarrolla el frontend de forma prolija. Voy a dejar ejecutando el agente por un tiempo, sin estar con la computadora. Crea la rama correspondiente e inicia con la implementación del frontend.

L2: User selected “Cadena sobre develop” (`stacked-to-main`). Default branch verified as develop. All code remains local until separate publication authorization. Branch created from fetched origin/develop 5284df1, clean baseline. No approval of #378 or closure of #285 is inferred.

L3: Read-only explorer mw8cy7df-1-vokg mapped approved #376 contract, backend Origen.Booking lifecycle APIs, missing patient appointments screen and staff surfaces. JSON evidence now in tmp/issue-378. #376 approved and closed; #285 open. Mandatory sources must be read by each implementing worker. Generated code follows project Spanish UI conventions; docs follow existing language. Parent context backstop requires bounded workers; background-subagents off, so sequential foreground handoffs. Test-first and all required functional checks remain mandatory. No source changes at initial planning.

L4: T1 implemented and self-verified: required focused patient/navigation/booking command passed 9 tests on isolated PostgreSQL 127.0.0.1:55438/origen_378_test. Initial attempts failed setup at default port 5433 and then database creation (zero tests); observed behavioral RED 6 failures, corrected to GREEN. Compile, format and whitespace passed. Uses real backend with synthetic DB fixtures, not browser/cloud integration. Exact-at-start enforcement relies on #377 deterministic backend tests; forged foreign cancellation and patient attendance events preserve public history.

L5: Slice 1 = 491e29b (674 authored lines including feature tracking; coherent patient route/navigation/history/cancel behavior with tests and docs exceeds advisory 400-line target). Delivery auto-chain / stacked-to-main retains this as first future review slice; slice 2 starts after 491e29b for professional workflow. No PR/publication. Risk: item 2 (private patient history, session principal). Independent verification planned at T4 before delivery.

L6: T2 completed in 2ff45e3: professional cancellation with reason, confirmed-only attendance/absence, scoped history with origin/reason. RED six new failing lifecycle tests, GREEN 50 focused tests including request-resolution and date navigation regressions. Format and whitespace passed. Synthetic DB fixtures exercise real backend; no browser/cloud verification claimed. Slice 2 = 2ff45e3, 630 authored lines (cohesive behavior + tests/docs); cumulative 1304. Slice 3 starts after 2ff45e3 for secretary workflow. Risk: item 2 (professional agenda scope and private history). No publishing.

L7: T3 completed in ad3ff27: /secretaria/agenda uses real scoped history/cancel/attendance APIs, mandatory reason and confirmed-only attendance, all center agendas. RED six failures then GREEN six new tests and 54 applicable regressions using real DB fixtures. Missing secretary_patients_live_test.exs replaced by actual secretary booking/access tests. Shared history component keeps professional defaults; format/whitespace passed. Slice 3 = ad3ff27, 777 authored lines (cohesive secretary workflow/tests/docs); cumulative 2081. Slice 4 starts after ad3ff27 for final verification fixes/evidence. Risk: item 2 (secretary role authorization). Full suite started as job-4; no browser/cloud evidence yet.

L8: T4 integration fixes implemented by worker mw8evwdz-7-qpfr: functional home Mis turnos and secretary patient-management agenda entry, organization-local secretary day grouping, public patient identifier, OpenSpec #378 reverse tracking. RED four expected failures (33/37), GREEN 37 focused tests; format/whitespace passed. No browser/cloud approval.

L9: Parent full suite job-4 exit 2: 981/986 passed, 32 skipped, 8 excluded; four URL-only config failures plus SQLASCII migration failure. Prepared separate UTF8 cluster and explicit config. Job-5 exit 2: 885/986 passed, 32 skipped, 8 excluded, 101 failures after ExpiryWorker sandbox ownership crash, followed by Repo unavailable. Baseline attribution unproven; no further current full-suite runs allowed in this automatic cycle.

L10: Independent verifier mw8f73se-8-jal8 failed preparation before probes while resolving initdb/pg_ctl via PATH: zero tests/probes, no scratch or DB created. No child active or uncertain. Parent confirmed binaries exist at /usr/lib/postgresql/18/bin/{initdb,pg_ctl}; no automatic retry. Required next decision: authorize one new bounded gentle-ai-verify attempt with absolute paths, isolated UTF8 database, focused UI/backend tests and baseline-only worker differential diagnosis, no application edits or publication. Existing correction budgets and previous failed evidence are retained. T4 blocked; #378 implementation is not accepted and #285 not closed. Local completed implementation remains preserved.
