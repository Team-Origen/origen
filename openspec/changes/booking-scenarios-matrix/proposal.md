# Proposal: Booking Scenarios Matrix (GitHub #61)

## Intent
Implement the durable, reviewable booking scenarios matrix defined in Issue #61 and the Authorization Matrix v0.6-draft, enabling three distinct booking pathways with atomic persistence, explicit authorization, and full scenario coverage.

## Scope
**In Scope:**
- Appointment schema, migration, and Ecto model
- Booking context with operations for 3 actors (Paciente autónomo, Secretaría asistida, Profesional)
- Authorization rules BOOK-01, BOOK-02, BOOK-03 in `lib/origen/authorization/rules.ex`
- Appointment state machine (Solicitado, Reservado, Confirmado, Asistió, Cancelado, No asistió)
- Validation: actor eligibility, consultation type ownership/active, slot availability, overlap detection (RF-12), D-1 window (23:59 cutoff)
- Atomic transaction: appointment + Profesional-Paciente relationship + snapshots + audit event
- Snapshot persistence (name, duration_minutes, price_ARS from consultation type at booking time)
- Profesional-Paciente relationship model (created on first successful booking)
- Minimal authorization tests for S1-11, S1-12, S1-13 per matrix

**Out of Scope (per Issue #61):**
- Patient representation in autonomous booking
- Absences, holidays, availability changes affecting existing bookings (RF-07, #76/#77)
- Manual approval flow, WhatsApp, waitlist, payments, receipts, reports
- Overbooking (RF-15) as distinct modality
- T1.6/T1.7/T1.9 implementation (separate authorization)

## Approach
Single `Origen.Bookings` context owning:
- `Appointment` schema and persistence
- `Booking` operations (create, validate, transition)
- `Eligibility` checks per actor (BOOK-01/02/03 conditions)
- `Availability` validation (contiguous agenda intervals, no overlaps)
- `StateMachine` for appointment lifecycle
- `Snapshots` for booking-time consultation type data
- `Relationship` for Profesional-Paciente link

Authorization rules added to existing `Origen.Authorization.Rules` engine (default-deny, explicit matrix).

Database: Two new tables (`appointments`, `professional_patient_relationships`) with proper FKs, indexes, and constraints.

## Acceptance Criteria (from Issue #61)

| Criterion | Verification |
|-----------|--------------|
| 1. Document scenarios for 3 actors | Scenarios implemented as executable tests |
| 2. Detail eligibility, overlaps, D-1 states, rollback | Validation functions + transaction tests |
| 3. Include success, denial, concurrent cases | Test cases covering all 31 scenarios |
| 4. Durable, reviewable artifact | Spec/design/tasks in OpenSpec; tests in CI |

## Dependencies
- **Hard**: `local-bootstrap-profile` (active Profesional/Secretaría accounts for tests)
- **Soft**: `secure-bootstrap-invitation-delivery` (real activation flow)
- **Specs**: `consultation-type-catalog`, `agenda-interval`, `default-deny-authorization` (already done)

## Risks
| Risk | Mitigation |
|------|------------|
| Large change size (~2000+ lines) | Chained PRs (6 PRs), work-unit commits, 400-line budget |
| Patient identity (Google OAuth vs internal) | Schema supports both via polymorphic or separate patient_id FK |
| Concurrency conflicts | Advisory locks on (professional_id, time_range); explicit test scenarios |
| Auth matrix drift | Rules.ex generated from matrix; CI check for sync |
| D-1 timezone | Use organization timezone config; UTC storage with local conversion |

## Deliverables
1. `openspec/changes/booking-scenarios-matrix/proposal.md` (this file)
2. `openspec/changes/booking-scenarios-matrix/spec.md` - Formal requirements
3. `openspec/changes/booking-scenarios-matrix/design.md` - Technical design
4. `openspec/changes/booking-scenarios-matrix/tasks.md` - Implementation tasks (chained PRs)
5. Implementation across 6 chained PRs
6. `verify-report.md` - Verification evidence
7. `archive-report.md` - Final archive

## Chained PR Strategy
- **Chain strategy**: `feature-branch-chain` (tracker branch accumulates, final merge to main)
- **PR boundaries**: Aligned with task groups, each ≤400 changed lines
- **Delivery strategy**: `ask-on-risk` (ask before PR if forecast >400 lines)

---

**Status**: Proposed — ready for Spec phase
**Author**: @Saidqr (orchestrator-assisted)
**Date**: 2026-09-18