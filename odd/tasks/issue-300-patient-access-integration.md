# ODD Feature: Issue #300 — Patient access integration and verification
Change: `health-center-beta-core`
Scope: Integration slice for parent #277; branch `feat/300-patient-access-integration`

## Specs

1. **S1** — "Sobre un paciente real de alta asistida, vincular correo y consumir magic link para acceder únicamente a información propia."
2. **S2** — "Reemplazar correo, comprobar misma identidad e historia e invalidación real de enlaces/sesiones anteriores, con actor/fecha registrados."
3. **S3** — "Verificar todos los criterios de #277, correo ocupado, permisos y no enumeración pública con evidencia sanitizada."
4. **S4** — "Iniciar esta subtarea sólo cuando todas las otras subissues de esta padre estén terminadas y aprobadas y todos los tickets que bloquean a la padre estén resueltos."
5. **S5** — "Resolver aquí los defectos encontrados, incluidos cambios en backend/frontend, sin reabrir sus subissues; registrar arreglos y ejecutar/actualizar las pruebas afectadas sin ampliar alcance."
6. **S6** — "Registrar aprobación explícita con evidencia de todos los criterios de la padre: significa que la padre está terminada y corresponde registrar su cierre; no asumir cierre automático."
7. **S7** — Contract scenarios C1-C10 from `docs/sprints/contracts/297-acceso-paciente-magic-link.md`, including separation of `contact_email` and personal access `email`, opaque public responses, and denial of patient self-editing.

## Tasks

- [x] T1 (S4): Reconcile GitHub blockers and prior subissue evidence; record integration baseline.
- [ ] T2 (S1-S3, S7): Map and execute the real end-to-end access, linking, replacement, possession, authorization, privacy, and non-enumeration flows.
- [x] T3 (S2, S5): Fix only integration defects found by the real flows; add/update public-interface regression tests.
- [x] T4 (S1-S7): Run focused, full, formatting, Dialyzer, and manual verification; record exact evidence and limitations. Automated verification is complete; manual real-data walkthrough remains outstanding.
- [ ] T5 (S6): Update this document with final evidence and commit boundary; prepare sanitized issue/parent closure evidence.

## Log

- L1 — User request: "Ok. Vamos a trabajar en la subissue #300. Crea una rama para esta subissue, examina los criterios de aceptación para poder realizarla y procede con la implementación."
- L2 — Created branch `feat/300-patient-access-integration` from `feat/299-patient-access-frontend` at commit `4302b06` after confirming #276, #297, #298, and #299 are closed on GitHub.
- L3 — Read the mandatory integration guidance, approved proposal/design, patient identity/access specification, and contract C1-C10. Integration must use real implementations, not fixtures as evidence, and may correct defects without reopening sibling subtasks.
- L4 — Baseline access-related suites passed 56 tests. Integration review identified missing validation of `patient_authenticated_at`, public profile self-editing, development email fallbacks, and Magic Link issuance for unlinked emails.
- L5 — Implemented `OrigenWeb.PatientSessionAuthLive` and applied it to patient phone/calendar LiveViews; invalid or invalidated sessions redirect to `/access`. Profile completion now rejects autonomous edits and tests assert no identity mutation. `/access` retains the opaque response but issues links only for linked patient emails. Focused verification passed 27 tests.
- L6 — Updated legacy integration fixtures to provide linked patient profiles and valid `patient_authenticated_at` sessions. Compatibility tests passed 9/9.
- L7 — Final automated verification passed: full suite 843 passed, 30 skipped, 8 excluded; `mix dialyzer --format short` passed with 54 existing ignored warnings; `mix format --check-formatted` and `git diff --check` passed. Manual real-data walkthrough is not yet executed.
