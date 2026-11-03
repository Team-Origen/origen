# Issue #320 — Professional assisted registration integration

## Objective
Verify the real Professional journey from absent DNI to a persisted confirmed appointment and patient, under parent #283 and the approved #317 contract. Integrate only after completed siblings #317/#318/#319 and parent blockers #278/#282; one-off range blocks belong #286 in Sprint 4.

## Scope and evidence boundaries
- GitHub: `Team-Origen/origen#320`, assigned Saidqr. OpenSpec change `health-center-beta-core`, path `openspec/changes/health-center-beta-core/`, Sprint 3 / parent #283 / integration.
- Sources: `docs/sprints/sprint-3/contrato-283-alta-y-reserva-profesional.md`, OpenSpec identity/booking/beta-boundary specs, `docs/sprints/GUIA_TRABAJO_BETA.md`.
- Existing real `ProfessionalPatientSelectionLive` → selector → `Booking.register_and_reserve_professional_appointment/2` already has focused LiveView and backend tests. This slice proves remaining parent criteria via real persisted flow; it does not claim #286 blocks or close #283 without explicit acceptance.
- Private PostgreSQL only. Tests and any needed fixes remain in the same reviewable work unit, ≤400 diff lines per PR. No review assignment without user request.

## Tasks
- [x] **T1 — Establish baseline and gap matrix.** Branched from `origin/develop` `341901f` with a clean tree. Private PostgreSQL 127.0.0.1:55488 partition `_320baseline`: existing real Professional UI/backend suites passed 29 tests, with 2 opt-in races skipped (seed 285). Missing full-path evidence: contact email absent/personal access not granted, no identity/profile/relationship/audit before confirmation, weekly-window rejection and active `requested` slot rejection through rendered UI. This tracker and baseline are one documentation work unit.
- [ ] **T2 — Verify real success and no premature writes.** Add end-to-end LiveView assertions that absent DNI lookup and abandonment create nothing, final success without email creates one identity/profile/confirmed appointment/own relationship and audit but no personal access; privacy and existing flow remain intact. Observe RED only if a meaningful behavior defect is found; otherwise use direct GREEN verification. Commit tests with any necessary fix.
- [ ] **T3 — Verify real rejection and recoverability.** Recheck weekly availability and pending request occupancy after a slot is selected; verify denial/no partial rows or information leaks, DNI collision/retry and session revocation via the public UI and persisted DB. Correct actual defects only; commit bounded tests/fixes.
- [ ] **T4 — Verify candidate and prepare handoff.** Full isolated suite, opt-in races, format/strict compile/Sobelow/Python/Dialyzer and available browser check; confirm ≤400 review lines, CI on published head only after issue gate. Record failures/skips honestly and seek explicit approval of all #283 criteria before issue closure.

## Progress
2026-11-03: #317/#318/#319 CLOSED with `status:approved`; external #278/#282 CLOSED; user reports #319 approved after PR #401 merged into `develop` at `341901f`. Issue #320 is OPEN, assigned Saidqr, and lacks `status:approved`; this is not permission to apply the protected label. Branch created locally at `341901f`. Existing #319 tests cover real UI success, occupied slot, duplicate DNI and revoked session, but do not yet demonstrate all #283 data/access/weekly/request guarantees through the full UI path. Engram mirror unavailable (`session has already ended`); this file is the durable task record.
