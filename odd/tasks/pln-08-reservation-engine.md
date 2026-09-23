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
- Chained local branches: `feature/61-reservation-cases`, `feature/62-reservation-contracts`, `feature/63-appointment-persistence-snapshots`.

## Checklist

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
- [ ] ODD-08-11 — Push feature branches and open GitHub Pull Requests for #61, #62, and #63 without merging.

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
- `mix test` (459 passed, 29 skipped, 8 excluded).
- `mix format --check-formatted` (clean).
- Independent verification subagent audit (`gentle-ai-verify`).

## Progress and evidence

- Commits generated:
  - `73bd027`: `docs(booking): define durable reservation scenario matrix for PLN-08` (Closes #61)
  - `cd195ad`: `feat(booking): define reservation data contracts and input validation for PLN-08` (Closes #62)
  - `ba9a0b1`: `feat(booking): implement appointment persistence with historical snapshots for PLN-08` (Closes #63)
- Subagent verification by `gentle-ai-verify` confirmed full compliance with all acceptance criteria.

## Next step

Publish the 3 chained branches and open Pull Requests for review (without merging). Downstream subissues #64 (authorization), #65 (overlap resolution & database exclusion constraint), and #66 (full ACID transaction integration) will build upon this foundation.
