# Exploration: Booking Scenarios Matrix (GitHub #61)

## Change Overview
- **Change**: `booking-scenarios-matrix`
- **GitHub Issue**: #61
- **Branch**: `feature/61-booking-scenarios-matrix` (parent: `develop`)
- **Artifact Store**: OpenSpec (detected by native dispatcher)
- **Responsible**: `@Saidqr`

## Current State Analysis

### What Exists (Ready to Build On)

| Area | Artifact | Status |
|------|----------|--------|
| **Authorization Matrix** | `docs/security/AUTHORIZATION_MATRIX.md` v0.6-draft | Defines S1-11/BOOK-01, S1-12/BOOK-02, S1-13/BOOK-03 with conditions |
| **Domain Specs** | `openspec/specs/agenda-interval/spec.md` | Agenda interval, consultation types, derived durations |
| | `openspec/specs/consultation-type-catalog/spec.md` | Catalog ownership, snapshots, booking snapshot rules |
| | `openspec/specs/default-deny-authorization/spec.md` | Default-deny, explicit matrix, ownership rules |
| **Scenarios Document** | `odd/tasks/issue-61-booking-scenarios-matrix.md` | 262 lines: 3 actors, 31 scenarios, elegibilidad, estados D-1, atomicidad |
| **Consultation Types** | `lib/origen/consultation_types/catalog.ex` | Replaceable boundary, snapshot with name/duration/price |
| **Authorization Engine** | `lib/origen/authorization/rules.ex` | Default-deny engine (bootstrap ops only, NO booking rules) |
| **Sessions** | `lib/origen/sessions.ex`, `internal_session.ex` | Internal account sessions with roles |
| **Bootstrap Profile** | `openspec/changes/local-bootstrap-profile/` | In progress (PRs 1-3 done, PRs 4-6 pending) |

### What's Missing (Gaps to Implement)

| Gap | Description | Source |
|-----|-------------|--------|
| **Booking Context** | No `lib/origen/Bookings` or `lib/origen/Appointments` module | Exploration |
| **Appointment Schema** | No Ecto schema/migration for `appointments`/`turnos` table | Exploration |
| **Profesional-Paciente Relationship** | No model/table for the relationship created on first booking | Issue #61, RF-05 |
| **Authorization Rules** | `rules.ex` lacks BOOK-01, BOOK-02, BOOK-03 rules for S1-11, S1-12, S1-13 | Auth Matrix |
| **State Machine** | No implementation of states: `Solicitado`, `Reservado`, `Confirmado`, `Asistió`, `Cancelado`, `No asistió` | CONTEXT.md, Issue #61 |
| **Validation Logic** | No eligibility checks, overlap validation (RF-12), D-1 window (23:59 cutoff), atomic persistence | Issue #61, RF-10, RF-12 |
| **Snapshot Logic** | No logic to copy name/duration/price to booking on creation | Consultation Type Catalog spec |
| **Authorization Tests** | Missing minimal tests for S1-11, S1-12, S1-13 per matrix lines 102-104 | Auth Matrix |
| **Concurrency Handling** | No advisory locks or optimistic locking for concurrent booking conflicts | Issue #61 scenarios |

## Scope Clarification

### IN SCOPE (This Change)
- Appointment schema and migration
- Booking context with operations for 3 actors
- Authorization rules BOOK-01, BOOK-02, BOOK-03 in `rules.ex`
- State machine for appointment lifecycle
- Validation: eligibility, overlaps, D-1 window, atomic transaction
- Snapshot persistence (name, duration, price from consultation type)
- Professional-Paciente relationship model
- Tests for authorization boundaries and core scenarios

### OUT OF SCOPE (Explicit per Issue #61)
- Patient representation in autonomous booking (excluded from auth matrix)
- Absences, holidays, availability changes affecting existing bookings (RF-07, issues #76/#77)
- Manual approval flow post-booking, WhatsApp, waitlist, payments, receipts, reports
- Overbooking (RF-15) as distinct modality
- Code implementation/tests/migrations for T1.6, T1.7, T1.9 (require separate authorization)

## Technical Approach Options

### Option A: Single `Origen.Bookings` Context (Recommended)
```
lib/origen/bookings/
  ├── appointment.ex          # Ecto schema
  ├── booking.ex              # Core operations
  ├── eligibility.ex          # Actor eligibility checks
  ├── availability.ex         # Slot validation, overlaps (RF-12)
  ├── state_machine.ex        # State transitions
  ├── snapshots.ex            # Booking snapshot logic
  └── relationship.ex         # Profesional-Paciente relationship
```
**Pros**: Cohesive, single ownership, easier transactions
**Cons**: Larger context, may need splitting later

### Option B: Split Contexts
- `Origen.Appointments` - schema, persistence, state machine
- `Origen.Bookings` - operations, eligibility, validation
- `Origen.Relationships` - Profesional-Paciente relationship

**Pros**: Separation of concerns, smaller contexts
**Cons**: Cross-context transactions more complex, over-engineering for v1

### Schema Design (Appointment)
```elixir
# appointments table
- id (PK)
- professional_id (FK -> internal_accounts)
- patient_id (FK -> patients or internal_accounts?)
- consultation_type_id (FK -> consultation_types)
- consultation_type_snapshot (JSON: name, duration_minutes, price_ars)
- agenda_interval_minutes (snapshot at booking time)
- starts_at (utc_datetime_usec)
- ends_at (utc_datetime_usec)
- state (enum: solicitado, reservado, confirmado, asistio, cancelado, no_asistio)
- booked_by_actor (enum: patient, secretary, professional)
- booked_by_account_id (FK -> internal_accounts or patients)
- confirmed_at (utc_datetime_usec, nullable)
- cancelled_at (utc_datetime_usec, nullable)
- cancellation_reason (text, nullable)
- created_at, updated_at

# professional_patient_relationships table
- id (PK)
- professional_id (FK -> internal_accounts)
- patient_id (FK -> patients)
- first_booking_id (FK -> appointments)
- created_at
```

## Risks and Unknowns

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Patient identity model** | High | High | Patient accounts use Google OAuth (PAT-01), not internal_accounts. Need to clarify FK target. |
| **Concurrency control** | High | High | Advisory locks on professional_id + time range; test concurrent scenarios explicitly. |
| **Transaction scope** | Medium | High | Atomic: appointment + relationship + snapshots + audit event. Use `Repo.transaction/2` with proper isolation. |
| **D-1 window logic** | Medium | Medium | Organization clock vs UTC; timezone handling for "23:59 D-1" cutoff. |
| **Auth matrix drift** | Low | High | Rules.ex must stay in sync with AUTHORIZATION_MATRIX.md v0.6-draft. |
| **Dependency on local-bootstrap-profile** | Medium | Medium | Booking ops need active internal accounts (Profesional, Secretaría). Bootstrap must work first. |
| **Large change size** | High | Medium | Estimated 2000+ lines across schema, context, rules, tests → chained PRs needed. |

## Dependencies

| Dependency | Status | Impact |
|------------|--------|--------|
| `local-bootstrap-profile` (GitHub #50) | PRs 1-3 done, PRs 4-6 pending | Provides local bootstrap for dev; booking tests need active Profesional/Secretaría accounts |
| `secure-bootstrap-invitation-delivery` (GitHub #49) | Staging prepared/not executed | Activation TLS, invitation delivery; needed for real account activation in tests |
| `consultation-type-catalog` spec | Done | Provides snapshot contract (name, duration, price) |
| `agenda-interval` spec | Done | Provides interval granularity for slot validation |
| `default-deny-authorization` spec | Done | Provides authorization framework |

## Recommended Next Steps

1. **Create Proposal** (`proposal.md`) - Define intent, scope, approach, acceptance criteria
2. **Create Spec** (`spec.md`) - Formal requirements with Given/When/Then from issue-61 scenarios
3. **Create Design** (`design.md`) - Schema, context API, state machine, authorization rules mapping
4. **Create Tasks** (`tasks.md`) - Break into chained PRs (likely 4-6 PRs given size)
5. **Apply** - Implement in chained PRs with work-unit commits
6. **Verify** - Run tests, verify against spec
7. **Archive** - Sync delta specs

### Suggested PR Split (aligning with local-bootstrap-profile pattern)
- **PR 1**: Schema/migration + Appointment Ecto schema + basic CRUD
- **PR 2**: Booking context core operations + eligibility + availability validation
- **PR 3**: Authorization rules (BOOK-01/02/03) + state machine + snapshots
- **PR 4**: Professional-Paciente relationship + atomic transaction + concurrency
- **PR 5**: Integration tests + authorization minimal tests (S1-11, S1-12, S1-13)
- **PR 6**: Edge cases, regression, documentation sync

---

**Prepared by**: Gentle AI Orchestrator
**Date**: 2026-09-18
**Status**: Exploration complete → Ready for Proposal