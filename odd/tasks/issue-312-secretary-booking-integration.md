# Issue #312 — Secretary existing patient booking integration
Branch: `feat/312-secretary-booking-integration`; baseline: `61d1685`.
Scope: integrate and verify parent #281 (#309 contract, #310 backend, #311 frontend); runner: isolated PostgreSQL partition + `mix test`.

## Specs
- S1: #312: "Con paciente existente y profesional/configuración reales, completar el turno asistido desde Secretaría."
- S2: #312: "Verificar todos los criterios de #281: agendas del centro, disponibilidad, ocupación y contrato de aprobación sin habilitar aceptación/rechazo."
- S3: #312: "Comprobar rechazos y permisos en servidor con evidencia del recorrido completo; mantener alta de inexistentes fuera de este slice."
- S4: #312: "Iniciar esta subtarea sólo cuando todas las otras subissues de esta padre estén terminadas y aprobadas y todos los tickets que bloquean a la padre estén resueltos."
- S5: #312: "Resolver aquí los defectos encontrados, incluidos cambios en backend/frontend, sin reabrir sus subissues; registrar arreglos y ejecutar/actualizar las pruebas afectadas sin ampliar alcance."
- S6: #312: "Registrar aprobación explícita con evidencia de todos los criterios de la padre: significa que la padre está terminada y corresponde registrar su cierre; no asumir cierre automático."

## Tasks
- T1 | S1–S5 | inline | done | Align real occupancy and slot validation in `AssistedBooking` and `SecretaryPatientLive`, add end-to-end integration tests and integration doc `docs/sprints/integration/312-secretary-booking.md`. RED: 2 failures in `AssistedBookingTest` (occupied slot still shown in schedule, outside-window booking allowed). GREEN: 47 passed in focused suite (`SecretaryBookingIntegrationTest`, `SecretaryPatientLiveTest`, `AssistedBookingTest`), 29 passed in `RequestResolutionTest`.
- T2 | S1–S6 | inline + independent gentle-ai-verify | done | Independent verifier `mw0pl4ku-1-yoe6` returned PASS across S1–S6 (60 passed + 3 spec probes passed, now added to `SecretaryBookingIntegrationTest` for 61 passed). `mix dialyzer --format short` passed (0 emitted errors, 54 baseline skipped), `mix sobelow` passed, `mix format --check-formatted` and `mix compile --warnings-as-errors` passed. Native review `review-1ba3b8367989db59` approved and acknowledged (`authority: burned`).

## Log
- L1: User request verbatim: "Bueno, fijate que issues puedo hacer (soy chordanDev)" -> "Dale".
- L2: Checked blockers: #309, #310, #311, #276, #278 are all CLOSED (`blocked_by: 0`).
- L3: Integration gap identified during review of #310/#311 against #281/#309: (1) `AssistedBooking.get_daily_schedule/3` did not pass persisted active appointment occupancies to `DatabaseCalendar`, leaving already-booked slots visible as available in the UI; (2) `AssistedBooking.reserve/4` did not verify that `start_time` belongs to the professional's real available schedule (windows, lead time, horizon) before inserting; (3) `SecretaryPatientLive` needs to reflect real `secretary_approval_mode` and refresh available slots after booking; (4) Administrators must not execute assisted booking.
- L4: Implemented T1 fixes and `test/origen_web/live/secretary_booking_integration_test.exs` + `docs/sprints/integration/312-secretary-booking.md`. Full test suite: 878 passed, 32 skipped, 8 excluded (`postgres_security`), exit 0.
- L5: Independent verifier `mw0pl4ku-1-yoe6` confirmed RED on baseline `61d1685` (5 failures) and GREEN on candidate (S1–S6 MET, 0 blockers). Added durable probe regression test to `SecretaryBookingIntegrationTest` (61 passed). `mix dialyzer --format short` passed in 20s (0 errors, 54 skipped).
- L6: Native review `review-1ba3b8367989db59` (`review-risk`, `review-reliability`) approved and acknowledged (`consumed_revision: sha256:0f0877ee2cf97b583597f54e7fc4c28e29b237d5e63f65fb022a2bbd7920a696`, `authority: burned`).
