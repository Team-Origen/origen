# Feature: Unified Transactional Reservation Engine (PLN-08 / Issues #61, #62, #63)

## Outcome

Deliver the initial durable specifications, syntactic contracts, and database persistence foundations for the shared appointment reservation engine (PLN-08) across Issues #61, #62, and #63.

## Problem

Appointment booking in Origen requires a single transactional engine shared by autonomous Patients, assisted Secretaries, and Professionals. Before building end-to-end booking logic, three foundational slices must be established:
1. A durable specification matrix defining valid, rejected, concurrent, and rollback scenarios (Issue #61).
2. Pure syntactic data contracts that validate presence and format fail-fast before evaluating business rules (Issue #62).
3. Database persistence for appointments with immutable historical snapshots of consultation type name, duration minutes, and exact price in ARS (Issue #63).

## Why

Separating scenario definition, syntactic contracts, and snapshot persistence into reviewable chained work units protects review focus, guarantees data integrity in PostgreSQL via triggers, and prevents downstream features from inventing conflicting rules.

## Authorized scope

- Subissue #61: Durable scenario matrix (`docs/booking/RESERVATION_CASES.md`) and non-breaking ExUnit test skeletons (`test/origen/booking/reservation_cases_test.exs`).
- Subissue #62: In-memory request contract (`ReservationRequest`), response struct (`ReservationResponse`), and fail-fast validation in `Origen.Booking`.
- Subissue #63: Migration `20260926100000_create_appointments_table.exs` with immutable snapshot trigger, Ecto schema `Appointment`, and transactional persistence `Origen.Booking.persist_appointment/2`.
- Subissue #64: Actor authorization rules for Patient (completed profile + verified phone), Secretary (assisted mode + schedule agreement), and Professional (permitted patient list).
- Subissue #65: Overlap prevention (professional agenda and patient schedule) and race condition exclusion in concurrency.
- Subissue #66: Atomic transactional orchestration (`Ecto.Multi`) of appointment, professional-patient relationship creation, and append-only audit event.
- Chained branches: `feature/61-reservation-scenarios`, `feature/62-reservation-contracts`, `feature/63-appointment-persistence-snapshots`, `feature/64-reservation-authorization`, `feature/65-overlap-concurrency`, `feature/66-atomic-reservation`.

## Checklist

### Phase 1: Foundation (Completed in PRs #161, #162, #163)
- [x] ODD-08-01 — Document reservation scenarios for Patient, Secretary, and Professional with eligibility, overlaps, and ACID rollback (Issue #61).
- [x] ODD-08-02 — Define non-breaking test skeletons for valid, rejected, concurrent, and rollback cases (Issue #61).
- [x] ODD-08-03 — Define `ReservationRequest` embedded schema with fail-fast syntactic validation (Issue #62).
- [x] ODD-08-04 — Define `ReservationResponse` output struct aligned with #61 and #63 contracts (Issue #62).
- [x] ODD-08-05 — Implement unit test suite for syntactic request validation without database access (Issue #62).
- [x] ODD-08-06 — Implement `appointments` migration with PostgreSQL immutability trigger for snapshots and least-privilege grants (Issue #63).
- [x] ODD-08-07 — Implement `Appointment` Ecto schema with validation of snapshots, times, and statuses (Issue #63).
- [x] ODD-08-08 — Implement `Origen.Booking.persist_appointment/2` with consultation type catalog resolution and simulated snapshot fallback (Issue #63).
- [x] ODD-08-09 — Implement integration test suite verifying snapshot copy, PostgreSQL trigger immutability, exact decimal precision, and atomic rollback (Issue #63).
- [x] ODD-08-10 — Independent read-only technical audit by `gentle-ai-verify` subagent (Report: PASSED).
- [x] ODD-08-11 — Push feature branches and open GitHub Pull Requests for #61, #62, and #63 without merging.

### Phase 2: Engine Integration (Issues #64, #65, #66)
- [x] ODD-08-12 — Implement actor authorization (`Origen.Booking.Authorization`): Patient profile completion & phone verification, Secretary assisted flow, Professional permitted patient check (Issue #64).
- [x] ODD-08-13 — Implement overlap and concurrency prevention: non-overlapping agenda validation and database-level exclusion / atomic locking (Issue #65).
- [x] ODD-08-14 — Implement atomic multi-step reservation orchestration: Appointment + ProfessionalPatientRelationship + AuditEvent with complete rollback guarantee (Issue #66).
- [x] ODD-08-15 — Technical audit and verification by subagent (Report: PASSED).
- [ ] ODD-08-16 — Open chained Pull Requests for #64, #65, and #66 without merging.

## Acceptance criteria

- Every scenario class (valid, rejected, concurrent, transactional rollback) has an unambiguous observable outcome.
- Request parsing rejects malformed input purely in-memory before database or authorization queries.
- Persisted appointments copy name, duration, and exact price; subsequent edits to consultation types do not mutate existing appointments.
- Attempted snapshot updates fail at the database level with PostgreSQL error code 23000.
- All test suites pass cleanly (`mix test`) with zero compiler warnings and clean formatting (`mix format`).

## Applicable checks

- `mix test test/origen/booking/reservation_cases_test.exs` (0 failures, 29 skipped skeletons).
- `mix test test/origen/booking/reservation_request_test.exs` (15 passed).
- `mix test test/origen/booking/persistence_test.exs` (8 passed).
- `mix test test/origen/booking/authorization_test.exs` (20 passed).
- `mix test test/origen/booking/overlap_test.exs` (19 passed, including 8-process barrier concurrency race).
- `mix test test/origen/booking/atomic_reservation_test.exs` (12 passed).
- `mix test` (517 passed, 29 skipped, 8 excluded).
- `mix format --check-formatted` (clean).
- Independent verification subagent audit (`gentle-ai-verify` PASSED).

## Progress and evidence

- Commits and Pull Requests (Phase 1):
  - `73bd027` / [PR #161](https://github.com/Team-Origen/origen/pull/161): `docs(booking): define durable reservation scenario matrix for PLN-08` (Closes #61)
  - `cd195ad` / [PR #162](https://github.com/Team-Origen/origen/pull/162): `feat(booking): define reservation data contracts and input validation for PLN-08` (Closes #62)
  - `ba9a0b1` / [PR #163](https://github.com/Team-Origen/origen/pull/163): `feat(booking): implement appointment persistence with historical snapshots for PLN-08` (Closes #63)
- Commits (Phase 2):
  - `09b76d1`: `feat(booking): implement actor authorization for reservation operations for PLN-08` (Closes #64)
  - `e821159`: `feat(booking): implement overlap and concurrency prevention for PLN-08` (Closes #65)
  - `f48e2f0`: `feat(booking): implement atomic reservation of appointment, relationship, and audit for PLN-08` (Closes #66)
- Subagent verification by `gentle-ai-verify` confirmed full compliance with all acceptance criteria.

## Next step

Publish the 3 chained branches and open Pull Requests for review (without merging).
