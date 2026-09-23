# Booking Scenarios Matrix — Implementation Tasks

## Overview

Tasks are organized into 6 chained PRs (feature-branch-chain strategy). Each PR targets ≤400 changed lines. The tracker branch `feature/61-booking-scenarios-matrix` accumulates all PRs; only the tracker merges to `main`.

## PR 1: Schema, Migration & Appointment Schema (Core Data Layer)

**Branch:** `feature/61-booking-scenarios-matrix-pr1-schema`
**Base:** `feature/61-booking-scenarios-matrix`
**Target:** Tracker branch `feature/61-booking-scenarios-matrix`

### Tasks

- [ ] **T1.1** Create migration `priv/repo/migrations/20260921100000_create_appointments.exs`
  - `appointments` table with all columns, constraints, indexes
  - `professional_patient_relationships` table
  - `btree_gist` extension enable
  - EXCLUDE constraints for professional and patient overlap prevention
- [ ] **T1.2** Create `lib/origen/bookings/appointment.ex` (Ecto schema)
  - Schema with all fields, types, associations
  - Changesets: `create_changeset/2`, `update_changeset/2`, `state_transition_changeset/2`
  - Validations: required fields, state enum, actor enum, datetime ordering
- [ ] **T1.3** Create `lib/origen/bookings/errors.ex`
  - Error types module with all booking error variants
  - Helper functions for error formatting
- [ ] **T1.4** Create `lib/origen/bookings/snapshots.ex` (snapshot capture logic)
  - `capture_snapshot/2` — captures name, duration_minutes, price_ars from consultation type
  - `calculate_duration/2` — interval_count * agenda_interval_minutes
  - Unit tests for snapshot capture
- [ ] **T1.5** Add `Origen.Bookings` to `lib/origen/application.ex` supervision tree (if needed)
- [ ] **T1.6** Run migration, verify schema with `mix ecto.migrate` and `mix ecto.dump`
- [ ] **T1.7** Basic schema tests: insert, update, state transitions, constraint violations

**Deliverables:**
- Migration file
- Appointment schema with changesets
- Snapshot capture logic
- Error types
- Passing schema tests

---

## PR 2: Booking Context Core — Eligibility, Availability & Validation

**Branch:** `feature/61-booking-scenarios-matrix-pr2-core`
**Base:** `feature/61-booking-scenarios-matrix-pr1-schema`
**Target:** Tracker branch `feature/61-booking-scenarios-matrix`

### Tasks

- [ ] **T2.1** Create `lib/origen/bookings/eligibility.ex`
  - `validate_patient_autonomo/2` — BOOK-01 preconditions
  - `validate_secretaria_asistida/2` — BOOK-02 preconditions
  - `validate_profesional/2` — BOOK-03 preconditions
  - `validate_actor_eligibility/2` — dispatcher by actor type
- [ ] **T2.2** Create `lib/origen/bookings/availability.ex`
  - `validate_availability/2` — contiguous agenda intervals check
  - `check_professional_overlap/2` — overlap with professional's appointments
  - `check_patient_overlap/2` — overlap with patient's appointments
  - `advisory_lock/1` / `advisory_unlock/1` — pg_advisory_xact_lock helpers
- [ ] **T2.3** Create `lib/origen/bookings/consultation_type.ex`
  - `validate_consultation_type/3` — ownership, active state, identity
  - `fetch_type_for_booking/2` — loads type with professional's agenda interval
- [ ] **T2.4** Create `lib/origen/bookings/validators.ex`
  - `validate_booking_params/2` — composed validation pipeline
  - Integrates eligibility, consultation type, availability, D-1 window
- [ ] **T2.5** Create `lib/origen/bookings/d1_window.ex`
  - `organization_timezone/0` — configured timezone
  - `d1_cutoff/1` — 23:59 D-1 in org timezone for given appointment date
  - `is_dia_d/1` — checks if requested date is Día D (past cutoff)
  - `initial_state_for/3` — computes initial state per actor/timing/modality table
- [ ] **T2.6** Unit tests for each validator module
- [ ] **T2.7** Integration tests for validation pipeline with various scenarios

**Deliverables:**
- Eligibility validators for 3 actors
- Availability & overlap validation
- Consultation type validation
- D-1 window & initial state logic
- Composed validator pipeline
- Comprehensive unit/integration tests

---

## PR 3: Authorization Rules, State Machine & Snapshots Integration

**Branch:** `feature/61-booking-scenarios-matrix-pr3-auth-state`
**Base:** `feature/61-booking-scenarios-matrix-pr2-core`
**Target:** Tracker branch `feature/61-booking-scenarios-matrix`

### Tasks

- [ ] **T3.1** Add BOOK-01, BOOK-02, BOOK-03 rules to `lib/origen/authorization/rules.ex`
  - Rule entries for `create_booking` operation with 3 subjects
  - Scope facts for each actor pathway
  - Update `@operations` and `@subjects` lists
- [ ] **T3.2** Create `lib/origen/bookings/state_machine.ex`
  - `valid_transitions/0` — map of allowed state transitions
  - `can_transition?/2` — checks if transition is valid
  - `transition/3` — executes transition with validation
  - `initial_state/3` — re-exports from D1Window (or delegates)
- [ ] **T3.3** Create `lib/origen/bookings/booking.ex` (public API)
  - `create_booking/2` — main entry point
  - `transition_state/3` — state transitions
  - `get_booking/1` — fetch by ID
  - `list_bookings/2` — filtered queries
- [ ] **T3.4** Integrate snapshots into booking creation
  - Call `Snapshots.capture_snapshot/2` during create
  - Store snapshot in appointment changeset
- [ ] **T3.5** Authorization tests for S1-11, S1-12, S1-13 (minimal per matrix)
  - Positive: allow when all facts satisfied
  - Negative: deny for each missing/unmet fact
  - Administrator denied for booking operations
- [ ] **T3.6** State machine tests: valid/invalid transitions, initial state assignment
- [ ] **T3.7** Snapshot persistence tests: values captured, immutable after creation

**Deliverables:**
- Authorization rules for 3 booking pathways
- State machine with transitions
- Public Booking API
- Snapshot integration
- Authorization tests (matrix compliance)
- State machine tests
- Snapshot tests

---

## PR 4: Professional-Patient Relationship, Atomic Transaction & Concurrency

**Branch:** `feature/61-booking-scenarios-matrix-pr4-relationship-concurrency`
**Base:** `feature/61-booking-scenarios-matrix-pr3-auth-state`
**Target:** Tracker branch `feature/61-booking-scenarios-matrix`

### Tasks

- [ ] **T4.1** Create `lib/origen/bookings/relationship.ex`
  - `ensure_relationship/2` — creates relationship if first booking for pair
  - `relationship_exists?/2` — checks if relationship exists
  - `get_allowed_patients/1` — returns patient IDs for a professional
- [ ] **T4.2** Implement atomic transaction in `Booking.create_booking/2`
  - Single `Repo.transaction/2` for appointment + relationship + audit
  - Advisory lock on professional_id during validation + insert
  - Rollback on any failure
- [ ] **T4.3** Concurrency handling
  - Advisory lock acquisition in `create_booking`
  - Test: concurrent patient requests for same slot → exactly one succeeds
  - Test: concurrent secretary + patient → exactly one succeeds
  - Test: concurrent professional + secretary → exactly one succeeds
- [ ] **T4.4** Pending fine block (BOOK-01 only)
  - `check_pending_fine/2` — queries fines for patient+professional
  - Blocks only autonomous bookings with that professional
  - Allows other professionals and existing appointments
- [ ] **T4.5** Audit event integration
  - `Origen.Audit.Events.booking_created/2` — creates audit event
  - `Origen.Audit.Writer.append/2` — appends with `:sys_01` authorization
  - Sanitized event (no sensitive data)
- [ ] **T4.6** Relationship tests: creation on first booking, reuse on subsequent, persistence after cancellation
- [ ] **T4.7** Concurrency tests (explicit scenarios from spec)
- [ ] **T4.8** Rollback tests: force failures at each persistence step

**Deliverables:**
- Professional-Patient relationship module
- Atomic transaction with rollback guarantees
- Advisory lock concurrency control
- Pending fine block
- Audit event emission
- Concurrency & rollback tests

---

## PR 5: Integration Tests & Authorization Minimal Tests

**Branch:** `feature/61-booking-scenarios-matrix-pr5-integration-tests`
**Base:** `feature/61-booking-scenarios-matrix-pr4-relationship-concurrency`
**Target:** Tracker branch `feature/61-booking-scenarios-matrix`

### Tasks

- [ ] **T5.1** Full integration tests for `create_booking` (all 3 actors)
  - Success scenarios from spec (31 scenarios covered)
  - Denial scenarios (incomplete profile, phone not verified, invalid type, etc.)
  - Concurrent conflict scenarios
- [ ] **T5.2** Authorization minimal tests per matrix lines 102-104
  - S1-11: Patient autonomous booking — positive + all negative boundaries
  - S1-12: Secretary assisted booking — positive + all negative boundaries
  - S1-13: Professional related booking — positive + all negative boundaries
- [ ] **T5.3** D-1 window integration tests
  - Time-travel tests for before D-1, D-1, Día D
  - Each actor/modality combination
  - Invalid state rejection
- [ ] **T5.4** State transition integration tests
  - Full lifecycle: solicitado → reservado → confirmado → asistio
  - Rejection paths: solicitado → cancelado, reservado → cancelado
- [ ] **T5.5** Snapshot immutability tests
  - Create booking → change consultation type → verify snapshot unchanged
- [ ] **T5.6** Test helpers for booking scenarios (factories, time travel)

**Deliverables:**
- Complete integration test suite
- Authorization minimal tests (matrix compliance)
- D-1 window integration tests
- State transition tests
- Snapshot immutability tests
- Test infrastructure

---

## PR 6: Edge Cases, Regression & Documentation Sync

**Branch:** `feature/61-booking-scenarios-matrix-pr6-polish`
**Base:** `feature/61-booking-scenarios-matrix-pr5-integration-tests`
**Target:** Tracker branch `feature/61-booking-scenarios-matrix`

### Tasks

- [ ] **T6.1** Edge case tests
  - Duplicate document rejection (Secretaría)
  - Patient outside center scope (Secretaría)
  - Manipulated identifier attempts (Profesional)
  - Global registry access attempts (Profesional)
  - Invalid state for actor/timing combinations
  - Waitlist exit on direct assignment (Secretaría/Profesional Día D)
- [ ] **T6.2** Regression tests for existing functionality
  - Internal account sessions unchanged
  - Consultation type catalog unchanged
  - Authorization bootstrap operations unchanged
  - Audit append-only unchanged
- [ ] **T6.3** Update `docs/security/AUTHORIZATION_MATRIX.md` if needed (sync with implementation)
- [ ] **T6.4** Update `openspec/specs/default-deny-authorization/spec.md` if needed
- [ ] **T6.5** Verify all 31 scenarios from `odd/tasks/issue-61-booking-scenarios-matrix.md` have test coverage
- [ ] **T6.6** Run full test suite, verify no regressions
- [ ] **T6.7** Verify PR size ≤400 lines each (split if needed)

**Deliverables:**
- Edge case coverage
- Regression test suite
- Documentation sync
- Scenario coverage verification
- Clean test suite

---

## Dependency Graph

```
T1.1-T1.7 (PR 1: Schema)
    ↓
T2.1-T2.7 (PR 2: Core Validation)
    ↓
T3.1-T3.7 (PR 3: Auth + State Machine + API)
    ↓
T4.1-T4.8 (PR 4: Relationship + Transaction + Concurrency)
    ↓
T5.1-T5.6 (PR 5: Integration Tests)
    ↓
T6.1-T6.7 (PR 6: Polish + Documentation)
```

## Chained PR Strategy

- **Chain strategy:** `feature-branch-chain` (tracker branch accumulates, final merge to main)
- **Each PR:** ≤400 changed lines, work-unit commits
- **Delivery strategy:** `ask-on-risk` (ask before PR if forecast >400 lines)
- **Review:** Each PR reviewed independently before merging to tracker

## Tracking

- **GitHub Issue:** #61
- **Parent Issue:** #41 (PLN-08)
- **Tracker Branch:** `feature/61-booking-scenarios-matrix`
- **OpenSpec Change:** `booking-scenarios-matrix`
- **ODD Tasks:** `odd/tasks/issue-61-booking-scenarios-matrix.md`

---

**Status**: Draft — ready for Apply phase
**Version**: 0.1-draft
**Date**: 2026-09-21
**Author**: @Saidqr (orchestrator-assisted)