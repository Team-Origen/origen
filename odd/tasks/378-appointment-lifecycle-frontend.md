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

- T1 [S1,S2] Patient persistent appointments/history, navigation and own cancellation; route: gentle-ai-worker (context backstop); status: in_progress; commit: pending; checks: RED/GREEN LiveView and regressions.
- T2 [S1,S2] Professional own-agenda lifecycle controls/history; route: gentle-ai-worker (context backstop); status: pending; commit: pending; checks: RED/GREEN LiveView and request-resolution regression.
- T3 [S1,S2] Secretary center-agenda lifecycle controls/history; route: gentle-ai-worker (context backstop); status: pending; commit: pending; checks: RED/GREEN LiveView and authorization regressions.
- T4 [S1,S2] Integrated regression, independent privacy/security verification, evidence and approval status; route: parent + gentle-ai-verify; status: pending; commit: pending; Risk: item 2 (private history, server authorization boundaries).

## Log

L1: Tengo que iniciar con la subissue #378 (el frontend del ciclo operativo del turno). Implementa el frontend según lo que pide la subissue. Alimenta las decisiones que vayas a tomar de la documentación de origen según lo que te indique la subissue. Cumple con los criterios de aceptación y desarrolla el frontend de forma prolija. Voy a dejar ejecutando el agente por un tiempo, sin estar con la computadora. Crea la rama correspondiente e inicia con la implementación del frontend.

L2: User selected “Cadena sobre develop” (`stacked-to-main`). Default branch verified as develop. All code remains local until separate publication authorization. Branch created from fetched origin/develop 5284df1, clean baseline. No approval of #378 or closure of #285 is inferred.

L3: Read-only explorer mw8cy7df-1-vokg mapped approved #376 contract, backend Origen.Booking lifecycle APIs, missing patient appointments screen and staff surfaces. JSON evidence now in tmp/issue-378. #376 approved and closed; #285 open. Mandatory sources must be read by each implementing worker. Generated code follows project Spanish UI conventions; docs follow existing language. Parent context backstop requires bounded workers; background-subagents off, so sequential foreground handoffs. Test-first and all required functional checks remain mandatory. No source changes yet.
