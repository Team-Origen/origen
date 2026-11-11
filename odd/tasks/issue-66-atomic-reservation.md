# Issue 66: Implementar guardado atómico de turno, relación y auditoría

## Outcome

Save the appointment, the professional-patient relationship (when applicable), and the append-only audit event in a single atomic transaction with complete rollback guarantees.

## Problem

Creating a valid reservation requires touching three distinct database entities: the appointment, the professional-patient visibility relationship, and the audit log. If any write fails, partial records or orphan data could be left in the system.

## Why

A single `Ecto.Multi` transaction guarantees that either all three records are committed successfully, or none of them are created (ACID rollback).

## Authorized scope

- Migration `20260928100000_create_professional_patient_relationships.exs` and schema `lib/origen/booking/professional_patient_relationship.ex`.
- Atomic multi-step orchestration in `lib/origen/booking.ex` (`reserve_appointment/2`).
- Append-only audit logging to `public.audit_events`.
- Test suite in `test/origen/booking/atomic_reservation_test.exs`.
- Local branch: `feature/66-atomic-reservation`.
- Pull Request: [PR #169](https://github.com/Team-Origen/origen/pull/169).

## Checklist

- [x] ODD-66-01 — Migration and schema for `professional_patient_relationships` with unique pair constraint.
- [x] ODD-66-02 — Establish relationship only when the first valid appointment is persisted in `:reserved` or `:confirmed` state.
- [x] ODD-66-03 — Do not establish relationship when appointment is in `:requested` state.
- [x] ODD-66-04 — Do not duplicate existing relationships; report `relationship_created?: false`.
- [x] ODD-66-05 — Write append-only audit event with actor, entity, and event details without sensitive clinical data.
- [x] ODD-66-06 — Verify complete rollback on failure: 0 appointments, 0 relationships, and 0 audit events.

## Acceptance criteria

- [x] Saves appointment, relationship, and audit event in a single atomic transaction.
- [x] Relationship is born only if the first valid reservation persists successfully.
- [x] Any error rolls back all changes without leaving orphan records.
- [x] Audit log captures server timestamp and actor details without exposing sensitive data.

## Applicable checks

- `mix test test/origen/booking/atomic_reservation_test.exs` (12 passed).
- `mix test` (517 passed, 29 skipped, 8 excluded).
- `mix format --check-formatted` (clean).

## Progress and evidence

- Commit: `0fff281` (`Closes #66`).
- Pull Request: [PR #169](https://github.com/Team-Origen/origen/pull/169).
- Verified by `gentle-ai-verify` subagent.
