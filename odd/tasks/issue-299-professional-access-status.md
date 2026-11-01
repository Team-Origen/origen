# Issue #299 follow-up: professional patient access maintenance

## Specs

1. **S1** — “Permitir que Profesionales vinculen/reemplacen correos desde su interfaz.”
2. **S2** — “Mostrar explícitamente los estados de posesión/acceso del correo.”
3. **S3** — “Implementa las dos soluciones a los problemas que hay en la implementación de la subissue #299 para poder cerrar el PR #364.”

## Tasks

- T1 — S2 — Add domain access-status classification from persisted email and magic-link possession proof — commit: 51f176f
- T2 — S1-S2 — Add professional agenda access maintenance UI using authorized domain operations — commit: 51f176f
- T3 — S1-S2 — Add domain and LiveView regression tests, run focused and full verification — commit: 51f176f

## Log

- L1 — Implementa las dos soluciones a los problemas que hay en la implementación de la subissue #299 para poder cerrar el PR #364.
- L2 — Added `Origen.PatientAccess.access_status/1`, classifying profiles as `:unlinked`, `:pending_verification`, or `:verified` from persisted email and consumed Magic Links.
- L3 — Added ProfessionalAgendaLive controls for professional link/replace operations, explicit status badges, feedback, and reuse of Patients domain authorization; SecretaryPatientLive now shows the same possession state.
- L4 — Added regression coverage for all three access states and professional link/replace UI. Focused tests: 59 passed. Full suite: 845 passed, 30 skipped, 8 excluded. Formatting and `git diff --check` passed.
- L5 — Delivery strategy: keep this follow-up as one reviewable PR #364 slice; commit boundary is `51f176f` and no additional commit is planned for this scope.
- L6 — CI Dialyzer exposed unreachable fallback clauses in SecretaryPatientLive. Removed them in follow-up commit `ae5f9bf`; `mix dialyzer --format short` passes, as do 59 focused tests and the full suite (845 passed, 30 skipped, 8 excluded).
