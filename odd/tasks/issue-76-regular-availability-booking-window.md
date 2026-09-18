# Issue 76: Define regular availability and booking window

## Outcome

Refine the product contract for regular weekly availability and booking-window rules. This work is product definition only: implementation belongs to a separate future issue.

## Problem

The product needs deterministic rules for when a professional is regularly available and how far in advance patients may book. Existing documentation states broad availability requirements but does not define the weekly model, booking boundaries, validation, defaults, or prospective-change behavior precisely enough for implementation.

## Why

A single product contract prevents the future implementation from inventing behavior around time zones, overlapping windows, same-day booking, existing appointments, and audit consistency.

## Authorized scope

- Product refinement and recovery documentation for Issue #76.
- No source code, tests, migrations, implementation specifications, or GitHub Issue mutations.
- Local branch: `feat/76-regular-availability-booking-window`.
- Future implementation requires a separate issue and explicit authorization.

## Product contract

### Ownership and time basis

- Only the owning professional may modify these settings.
- All calculations use the organization's time zone.
- The booking window and minimum lead time apply to every consultation type owned by the professional.

### Regular weekly availability

- A new professional starts with Monday through Friday availability from 08:00–12:00 and 14:00–18:00.
- A professional may configure multiple windows on the same weekday.
- Each window belongs to exactly one weekday; overnight and multi-day windows are not allowed.
- Window boundaries must align with the professional's current agenda interval.
- Each window must last at least one complete agenda interval.
- Touching windows are treated as one continuous period.
- Overlapping windows are merged automatically and a brief notification reports the merge.
- A professional may leave the entire weekly schedule empty.
- Changes apply immediately to new reservations.
- Existing appointments remain intact, do not block saving, and produce no conflict warning.
- Existing appointments must be cancelled manually through the separate appointment flow when required.
- An agenda-interval change is rejected when existing availability boundaries would become misaligned.

### Booking boundaries

- The future booking window is configured only in whole days.
- Valid values range from 7 through 90 days; the default is 30 days.
- The final organization-local calendar day is fully included.
- Autonomous same-day patient booking is allowed while the slot has not started and satisfies the configured lead time.
- Minimum lead time ranges from 0 minutes through 24 hours in five-minute increments; the default is 30 minutes.
- Offered appointment starts align with the professional's agenda-interval grid.
- The full consultation duration must fit within continuous available intervals.

### Occupancy

- `Requested`, `Reserved`, and `Confirmed` appointments occupy their intervals.
- `Cancelled` appointments release their intervals immediately.
- A request pending manual approval therefore prevents another reservation for the same time.

### Saving and audit

- The complete configuration is saved atomically; any invalid value rejects the entire save.
- One notice presents all detected validation errors.
- Concurrent edits use last-write-wins behavior.
- Every successful save records the actor, timestamp, previous values, and new values.
- Configuration and its successful-change audit event persist atomically; if either write fails, neither is applied.
- Rejected attempts are not audited.

## Explicit exclusions

- Vacations, absences, holidays, and future-scheduled recurring changes.
- Immediate walk-ins, post-start appointment creation, and overbooking.
- Appointment cancellation or rescheduling flows.
- Audit-history screens or documentation about such screens.
- Source-code implementation in this issue.

## Checklist

- [x] ODD-76-01 — Establish organization time zone and owner-only configuration.
- [x] ODD-76-02 — Define weekly windows, defaults, alignment, minimum duration, adjacency, overlap, and empty schedules.
- [x] ODD-76-03 — Define the 7–90 day booking horizon and inclusive final-day behavior.
- [x] ODD-76-04 — Define same-day booking and configurable 0-minute to 24-hour lead time.
- [x] ODD-76-05 — Define slot-grid, consultation-duration, and appointment-occupancy rules.
- [x] ODD-76-06 — Define prospective changes that preserve existing appointments without warnings.
- [x] ODD-76-07 — Define atomic validation, last-write-wins behavior, and successful-change auditing.
- [x] ODD-76-08 — Separate temporary exceptions and immediate walk-ins from this scope.
- [ ] ODD-76-09 — Create and authorize a separate implementation issue from this contract.

## Acceptance criteria

- The future implementation issue can derive behavior without inventing unresolved product rules.
- Every included rule has one unambiguous expected outcome.
- Temporary exceptions and appointment-operation flows remain outside this feature boundary.
- No implementation is performed under Issue #76.

## Applicable checks

- Structural readback of this document.
- Engram mirror at topic `odd/issue-76-regular-availability-booking-window/tasks`.
- Confirm the working branch contains no source-code changes.
- TDD is not applicable because implementation is not authorized.

## Progress and evidence

- Product decisions were resolved interactively through ODD discovery.
- Repository contracts consulted: `docs/Origen_Documentacion.md`, `openspec/specs/agenda-interval/spec.md`, and `openspec/specs/consultation-type-catalog/spec.md`.
- The branch was rebased onto local `develop` at `2a04cb4` before refinement.

## Rationale

Regular availability is a recurring weekly pattern. Temporary closures and post-start care have different precedence and lifecycle rules, so keeping them separate avoids schedule versioning and hidden appointment mutations.

## Next step

Create a separate implementation issue that references this document and preserves its scope boundaries.
