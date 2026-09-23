# Issue 65: Implementar prevención de solapamientos y concurrencia en reservas

## Outcome

Guarantee that no overlapping appointments exist for a professional's agenda or a patient's schedule, and eliminate race conditions in concurrent booking attempts.

## Problem

Under concurrent load or simultaneous requests, standard application-level checks without database-level exclusion constraints are prone to race conditions (double booking).

## Why

PostgreSQL GiST exclusion constraints using `btree_gist` provide mathematical guarantees that two active intervals `[start_time, end_time)` cannot overlap on the same resource, ensuring 100% ACID consistency.

## Authorized scope

- Migration `20260927100000_add_appointment_overlap_exclusion_constraints.exs` adding `btree_gist` and GiST exclusion constraints.
- Domain module `lib/origen/booking/overlap.ex` and constraint handling in `lib/origen/booking.ex`.
- Ecto schema updates in `lib/origen/booking/appointment.ex`.
- Concurrency and overlap test suite in `test/origen/booking/overlap_test.exs`.
- Local branch: `feature/65-overlap-concurrency`.
- Pull Request: [PR #168](https://github.com/Team-Origen/origen/pull/168).

## Checklist

- [x] ODD-65-01 — Add PostgreSQL GiST exclusion constraints for professional agenda (`appointments_no_professional_overlap`) and patient schedule (`appointments_no_patient_overlap`) with half-open intervals `[)`.
- [x] ODD-65-02 — Exclude cancelled appointments from blocking slots.
- [x] ODD-65-03 — Allow contiguous back-to-back appointments (e.g. 09:00-09:30 and 09:30-10:00).
- [x] ODD-65-04 — Implement pre-check logic in `Origen.Booking.Overlap` for early failure feedback.
- [x] ODD-65-05 — Atomic translation of DB constraint violations to `{:error, :slot_already_booked}` and `{:error, :patient_schedule_conflict}` without residual locks.
- [x] ODD-65-06 — 8-process barrier concurrency test proving exactly 1 winner and 7 clean rejections under simultaneous race.

## Acceptance criteria

- [x] Prevents overlapping appointments in Professional's agenda.
- [x] Prevents simultaneous appointments for the same Patient.
- [x] Under concurrent requests for the same slot, exactly one persists.
- [x] Rejected requests leave no residual locks or partial data.

## Applicable checks

- `mix test test/origen/booking/overlap_test.exs` (19 passed).
- `mix test` (517 passed, 29 skipped, 8 excluded).
- `mix format --check-formatted` (clean).

## Progress and evidence

- Commit: `e821159` (`Closes #65`).
- Pull Request: [PR #168](https://github.com/Team-Origen/origen/pull/168).
- Verified by `gentle-ai-verify` subagent.
