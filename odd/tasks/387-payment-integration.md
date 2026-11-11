# Issue #387 — Real payment integration
Tracker: `feat/387-payment-integration-verification`; baseline refreshed to `7372371` (original `32d1489`); delivery: feature-branch-chain, publishing authorized with nonclosing `Refs #387`.
Runner: isolated PostgreSQL partitions with `MIX_TEST_PARTITION=_387_* mix test`; no existing database cleanup. Forecast: 900–1500 authored lines including integration tests.

## Specs
S1. User instruction: «IMLEMENTA, TENIENDO EN CUENTA EN LO QUE SE HIZO EN LA ISSUE HERMANA Y LO QUE INDICA LA ISSUE PADRE».
S2. #387: «Comprobar y registrar que todas las hermanas están terminadas y aprobadas; cerrar una issue no sustituye evidencia de aprobación.»
S3. #387: «Profesional opera sus turnos y Secretaría todos: registrar un único pago total en efectivo o transferencia solo para confirmado o asistido; conservar método, actor y fecha. El pago no bloquea reservas ni se admite para solicitudes pendientes.»
S4. #387: «Editar el precio final del turno antes del pago sin cambiar el catálogo; bloquear su edición al pagar.»
S5. #387: «Revertir una marca pagada mediante confirmación breve, sin motivo escrito obligatorio; conservar acción previa, actor y fecha, volver a pendiente y habilitar el precio. No representa una devolución.»
S6. #387: «Cancelar un turno no borra su pago. Paciente solo consulta precio final y estado de pago; Administrador no tiene acceso financiero.»
S7. #387: «La pantalla o flujo incorporado por esta issue puede alcanzarse desde la navbar del rol correspondiente, ya sea mediante una entrada directa o a través de la navegación interna de una sección accesible desde ella, sin necesidad de ingresar la URL manualmente y respetando los permisos existentes.»
S8. #387: «La corrección deja los datos de pago consistentes para el resumen que entregará #288; no exige implementar ese resumen para cerrar #287.»
S9. #387: «Corregir los defectos que incumplan estos criterios, conservar/actualizar las pruebas afectadas y ejecutar regresiones aplicables.»
S10. #387: «Registrar resultados, limitaciones y aprobación final explícita; solo entonces registrar el cierre de la padre. No aprobar si falta una decisión, dependencia o prueba necesaria.»
S11. #387: «Sin comprobantes, parciales, cuentas corrientes, devoluciones, créditos ni traslados de pagos. No implementar ni exigir el resumen económico de #288. No asignar responsables o aprobadores distintos, agregar requisitos ajenos ni declarar aprobaciones por anticipado.»
S12. #287: «Un pago total efectivo/transferencia sólo para confirmado o asistido.» «Ajusta precio final antes de pago y lo bloquea después.» «Reversión preserva actor/fecha/acción, vuelve pendiente y habilita precio.» «Cancelar no borra pago.»

S13. User correction: «Eliminar de las tarjetas los formularios de pago y edición de precio.» «Agregar un botón «Ver turno» de color celeste, junto a «Cancelar con motivo», «Marcar asistencia» y «Marcar ausencia», respetando el mismo diseño.» «Al tocar «Ver turno», abrir un modal con los detalles del turno, incluyendo la información de pago, edición de precio y registro de pago.» «Revisar el modal del mockeo original que se había diseñado para esta pantalla y reutilizar su estructura y flujo.» «Aplicar el mismo comportamiento a los turnos del historial operativo cuando corresponda.» «Importante: mantener la estructura actual de «Mi agenda» y reutilizar las funcionalidades existentes. No mostrar formularios de pago directamente en las tarjetas. MANTENER EL RESTO DE LA ESTRCUITRA»

S14. User correction: «### Corrección — Historial de turnos del profesional

1. **Título:** mostrar el tipo de consulta y el nombre del paciente atendido.
2. **Número de turno:** eliminarlo de la tarjeta.
3. **Botón «Ver turno»:** ubicarlo dentro de la tarjeta, inmediatamente debajo de la fecha y el horario, alineado a la izquierda.
4. **Estado:** mantener la etiqueta de estado en la esquina superior derecha.

### Borrador

```text
┌──────────────────────────────────────────────────────────────┐
│ Consulta Manual — Juan Pérez                   [Confirmado]  │
│ 30/10/2026 · 04:30 a 05:30 hs                               │
│ [Ver turno]                                                  │
└──────────────────────────────────────────────────────────────┘
```

**Importante:** conservar el diseño y las funcionalidades actuales. Solo modificar la disposición de estos elementos.(esto en la seccion de historial operativo)»

S15. User correction (verbatim):

### Corrección visual — Turnos del centro (Secretaría)

Mantener **exactamente la estructura y el funcionamiento actuales**, tanto en las tarjetas como en el modal «Detalle del turno».

Realizar únicamente estos cambios:

1. **Paciente:** reemplazar «Paciente #15» por el nombre real del paciente.
2. **Profesional:** mostrar el nombre del profesional correspondiente, identificado como «Profesional».
3. **Número de turno:** eliminar «Turno #69» y cualquier otro ID de turno visible.
4. **Tipo de consulta:** mantener el nombre del tipo de consulta, como «Tipo 1».
5. **Modal «Detalle del turno»:** aplicar los mismos cambios de información que en la tarjeta.

**Importante:** no modificar el diseño general, los estados, las fechas, los horarios, los pagos, los botones ni ninguna funcionalidad existente. Solo reemplazar los identificadores por nombres y mostrar el profesional correspondiente.

## Tasks
- T1 | S1–S5,S6–S9,S11–S13 | inline | done | Connect real staff payment controls in existing agendas; RED/GREEN integration tests; commit: authorized, recorded in delivery log.
- T2 | S1,S6–S7,S9,S11 | inline | done | Patient final price/payment projection and privacy tests; commit: authorized, recorded in delivery log.
- T3 | S1–S12 | delegated verify + inline evidence | done | Full regression, independent verification, reproducible integration evidence and approval limitations; commit: authorized, recorded in delivery log.

- T4 | S9,S13 | inline | done | Correction full suite: 1167 passed, 35 skipped, 8 excluded, exit 0; formatting/diff check exit 0; evidence updated; commit: authorized, recorded in delivery log.
- T5 | S14 | inline + bounded independent verify | done | Implementation done, shared defaults preserved; focused64 and final suite1168 passed, format/diff check0. Independent S14 verifier failed without verdict; human accepted recorded limits; commit: authorized, recorded in delivery log.

- T6 | S15 | inline | done | Implementation complete; focused73 and full1169 passed,35 skipped,8 excluded; format/diff check0. Independent/browser proof unavailable as recorded for integration; human accepted recorded limits, no automatic retry. Commit: not authorized.

## Log

L15. Human approval and delivery authorization, verbatim: «perfevcto, por ahora esta aprovado HA LO PR». User then selected «Sí, PR con «Refs #387» (recomendado)» authorizing configured GitHub session, commits, push and PRs to Team-Origen/origen develop, excluding odd/tasks/491-stack-rebase.md and merge. User explicitly authorized adding status:approved to #387; ADMIN permission and resulting label verified. Human accepts current delivery with independent/browser proof unavailable; this does not manufacture either proof or close #387/#287. T1–T6 complete under this human acceptance. Delivery uses draft tracker plus Patient and Staff child slices. Single bounded slicing pass retains shared staff modal, agenda wiring, visual corrections and matching tests together despite advisory 400-line overage. No source/tests/docs removed to reduce size. New develop commits touch only unrelated secretary assisted-booking files and sprint docs; branch fast-forwarded before delivery checks.

L14. S15 user correction recorded verbatim above; scoped test covers two corresponding professionals in cards, history and detail. Initial job21 exit2 (7/9), including fixture DNI corrected to dni. Functional RED job22 exit2:7/9 missing names/fallback. Implementation adds names only to secretary authorized projection, optional shared history ID hiding/label and modal professional text. Existing layout/classes/actions retained. Job23 exit2:71/73; new identity regression passed, two old tests still expected visible IDs. Updated only identity assertions to no-identity fallback and DOM identification, preserving cancellation and forged-ID mutation checks. Job24 exit0:73 focused passed; full suite1169 passed,35 skipped,8 excluded; formatting/diff check0. Sandbox ownership messages remain in log but no failed tests. Own checks complete; independent/browser proof still unavailable, so T6 blocked only on missing external proof. Evidence document updated; no independent or browser approval claimed.
L13. S14 functional RED job-17: 37 passed/1 failed, missing patient title. GREEN job-18:64 passed exit0 across professional agenda, secretary agenda, payments integration and lifecycle tests. Optional professional-only layout keeps shared defaults for Secretary; professional-only scoped projection adds patient_name, with Paciente fallback if no persona. T5 first full suite job-19 exit2:1167/1168 passed; old lifecycle UI test required visible appointment IDs now explicitly removed by S14. Updated assertions to stable DOM IDs and absence of visible number. Job-20 focused lifecycle test and full suite exit0:1168 passed,35 skipped,8 excluded; format/diff check0. Evidence updated. New bounded S14/shared-caller independent verifier mwccvbt7-3-a05m failed with assistant reported an error, no verdict, no retry. T5 blocked only for missing independent proof; own implementation/checks complete.
L12. User correction S14 is recorded verbatim above. Scope only Professional operational history. No change to Secretary/Patient cards or day agenda. Test preparation first failed because fetch_session returns session_id rather than id; fixed test setup before observing behavior RED.
L1. User request verbatim: «IMLEMENTA, TENIENDO EN CUENTA EN LO QUE SE HIZO EN LA ISSUE HERMANA Y LO QUE INDICA LA ISSUE PADRE».
L2. Starting state: develop synchronized, branch created at 32d1489. Preserve unrelated untracked `odd/tasks/491-stack-rebase.md`. No push, PR, issue closure, or explicit final approval authorized. No commits without explicit user request.
L3. GitHub readback: #384 CLOSED with explicit contract approval and merge #453; #385 CLOSED with prior explicit backend acceptance, publication chain #474–#478, current baseline includes merge #478; #386 CLOSED with explicit mock-only acceptance and merge #469; #285 CLOSED with integrated #379 lifecycle evidence. #385 comments predate publication and retain historical LOCALONLY caveat; current Git history supplies delivery evidence. Approval of these slices is not approval of #387/#287.
L4. Read-only exploration mapped backend `Booking.get_payment/update_final_price/record_payment/revert_payment/list_payment_actions`, production staff agendas without payment integration, PatientAppointmentsLive showing initial rather than final price, and mock-only preview. Contract requires correction after cancellation/no_show, not repayment of those terminal appointments.
L5. User selected «Cadena sobre rama de la funcionalidad (recomendado)». Delivery shape: feature-branch-chain; no publishing authority. Background-subagent policy off means parallel writer reason unavailable; parent implements inline, independent verification mandatory for permissions/payment persistence (risk items 1 and 2).
L6. Baseline suite on isolated partition `_387_baseline`: exit 0, 1158 passed, 35 skipped, 8 excluded; sandbox ownership log noise retained. Functional LiveView tests use real domain persistence, not mock preview. Browser proof is separate and must be reported honestly.
L7. T1 RED: 7 failures before UI integration, exit 2. Initial GREEN attempt: 1 passed/6 failed, revealing test expectations mismatched existing actor/error tokens, unsupported precision assumption and HTTP 403 versus redirect. Corrected expectations to existing public contract, no backend behavior changes; final focused run exit 0, 7 passed. Component delegates every read/write to real Booking API, drops cached projection on denied refresh and keeps correction available in historical/terminal appointments. T2 patient RED: exit 2, 1 failed/5 passed before projection change. GREEN: 58 passed across payment integration, patient appointments and both staff agenda regression files. Final full suite running job-11. ASSESS unavailable (package-local-binary-missing), high-risk independent verification applies. RDD CLI mode status is off; no native review started. Browser tool unavailable: Tidewave connection refused at localhost:4000, no browser proof claimed.
L9. User correction verbatim: «La implementación del mockeo es incorrecta. Actualmente, los campos de pago y edición de precio aparecen directamente dentro de las tarjetas de «Mi agenda».

Quiero realizar estos ajustes:

1. **Eliminar** de las tarjetas los formularios de pago y edición de precio.
2. **Agregar un botón «Ver turno»** de color celeste, junto a «Cancelar con motivo», «Marcar asistencia» y «Marcar ausencia», respetando el mismo diseño.
3. Al tocar **«Ver turno»**, abrir un modal con los detalles del turno, incluyendo la información de pago, edición de precio y registro de pago.
4. **Revisar el modal del mockeo original** que se había diseñado para esta pantalla y reutilizar su estructura y flujo.
5. Aplicar el mismo comportamiento a los turnos del historial operativo cuando corresponda.

**Importante:** mantener la estructura actual de «Mi agenda» y reutilizar las funcionalidades existentes. No mostrar formularios de pago directamente en las tarjetas. MANTENER EL RESTO DE LA ESTRCUITRA»
L11. Modal correction RED: 8/8 failed before implementation. First GREEN 58/59; helper tried to open an edit action already active after invalid input; adjusted helper only. Final focused run 59 passed exit 0 across four UI files. T1 done; T4 full suite job-15 completed exit 0: 1167 passed, 35 skipped, 8 excluded; formatting and diff check exit 0. Integration evidence updated; T4 done. This is a shell-job result, not an independent subagent verdict. Phoenix now HTTP200; Tidewave help responds no browser connected. No repeat of previously failed independent verification; T3 remains blocked. Cards/history only show Ver turno trigger; single focus-wrapped modal uses original mock sections and staged actions with unchanged real Booking APIs.
L10. T1 reopened for S13. Existing inline forms reproduced in current render source. Original mock reviewed at appointment_payment_preview_live.ex:356–507: focus-wrapped dialog, schedule/status/payment sections, staged edit/pay/correct action and cancel, Escape/close. Reuse that structure with real Booking APIs; preserve card layout and lifecycle operations. T3 historical missing proof remains blocked, not silently retried.
L8. Final full suite exit 0: 1166 passed, 35 skipped, 8 excluded. Formatting and git diff --check exit 0. Independent gentle-ai-verify failed with «assistant reported an error», no verdict; no retry. T3 waits for human decision on unavailable independent/browser proof. Evidence: docs/sprints/integration/387-simple-payments-integration.md; reverse #387 Tracking reference added to OpenSpec proposal. No final approval, commits, publishing or issue closure. Risk items 1 (persistent payment writes through UI) and 2 (financial authorization/privacy).
