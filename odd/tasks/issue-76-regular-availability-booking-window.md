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
- Ordinary availability changes apply immediately to new reservations under their own save contract.
- An Agenda Interval proposal keeps one global midnight-anchored grid, previews incompatible weekly boundaries and future active appointment conflicts, and never silently rounds or resets availability.
- The Professional must explicitly review and adjust the complete resulting week; a future active appointment that no longer fits blocks final interval confirmation with privacy-minimized evidence.
- Existing appointments remain intact and must be reprogrammed or cancelled manually through their separate flows; an interval change never moves, resizes, or cancels them automatically.

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
- Ordinary standalone availability edits use last-write-wins behavior; an Agenda Interval confirmation rejects a stale preview and requires a fresh review.
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
- [x] ODD-76-09 — Analyze backend Issue #77 and frontend Issue #78 and define their implementation handoff.
- [ ] ODD-76-10 — Implement the backend configuration slice under Issue #77 after explicit authorization.
- [ ] ODD-76-11 — Implement and integrate the frontend configuration slice under Issue #78 after Issue #77 is ready.

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

Implement the backend slice under Issue #77 after its existing dependencies are satisfied and implementation is explicitly authorized. Integrate Issue #78 with that backend before considering the frontend slice complete.

## Implementation handoff

This handoff maps the product contract above to the existing execution issues. It does not modify either GitHub Issue and does not authorize implementation.

### Existing execution issues

| Issue | Responsibility | Existing dependency |
| --- | --- | --- |
| [#77](https://github.com/Team-Origen/origen/issues/77) | Backend persistence and isolation of the professional's availability configuration | May start from #76 rules and #54 authorization; integration and completion remain blocked by #54 and #76 |
| [#78](https://github.com/Team-Origen/origen/issues/78) | Professional-facing availability configuration interface | May start with fixtures; integration and completion remain blocked by #77 |

### Known contract drift

- Issue #77 currently says overlapping windows are rejected.
- Issue #78 currently treats overlap as a displayed error.
- The approved product contract instead merges overlapping windows and shows a brief non-blocking notification.
- Issue #77 describes availability auditing broadly; this contract audits successful changes only and requires the configuration plus audit event to persist atomically.
- Issue #78 names the future booking window but does not mention the configurable minimum lead time.
- Implementation must reconcile these differences before execution rather than silently following the conflicting wording.

### Backend handoff — Issue #77

Issue #77 owns the canonical persisted configuration and the rules required to save it safely:

- Persist exactly one regular-availability configuration for the authenticated professional.
- Deny reading or modifying another professional's configuration.
- Evaluate local weekday and clock values using the organization's time zone.
- Persist the professional-wide booking window and minimum lead time for all consultation types.
- Apply the defaults and accepted ranges from the product contract above.
- Normalize touching and overlapping same-day windows into continuous canonical windows before persistence.
- Reject overnight or multi-day windows, boundaries outside the agenda grid, and windows shorter than one agenda interval.
- Allow a completely empty weekly schedule.
- Replace the complete configuration atomically; invalid input leaves the previous configuration unchanged.
- Use last-write-wins behavior for concurrent saves.
- Preserve existing appointments during ordinary standalone availability replacement. For an Agenda Interval change, preflight future active conflicts against the reviewed complete week and block final confirmation until each conflict is resolved explicitly.
- Record actor, timestamp, previous values, and new values for successful changes only.
- Persist the successful-change audit event and configuration in the same transaction.
- Return normalized configuration and actionable validation details suitable for the frontend's single error notice.

Issue #77 should not silently absorb reservable-slot generation or appointment-occupancy integration merely because those rules are defined here. That downstream backend responsibility needs explicit tracker ownership before implementation if it is not already assigned elsewhere.

#### Backend verification focus

- Owner access succeeds; cross-professional read and write attempts fail.
- Defaults and valid boundaries persist correctly.
- Adjacent and overlapping windows persist in normalized form.
- Every invalid shape rejects the complete save and preserves previous state.
- Empty availability persists successfully.
- Existing appointments do not block configuration changes and remain unchanged.
- Successful configuration and audit records commit or roll back together.
- Rejected validation attempts do not create audit events.

### Frontend handoff — Issue #78

Issue #78 owns the professional-facing editor for the configuration exposed by Issue #77:

- Present the organization-local weekly schedule with multiple windows per weekday.
- Initialize new professionals with Monday through Friday, 08:00–12:00 and 14:00–18:00.
- Allow adding and removing windows and clearing the complete weekly schedule.
- Prevent representing overnight or multi-day ranges in the editor.
- Align selectable boundaries to the current agenda interval and enforce one interval as the minimum window length.
- Treat touching windows as continuous.
- Show a brief non-blocking notice when the resulting configuration merges overlaps; do not present overlap as an error.
- Provide a whole-day booking-window control from 7 through 90 days with a 30-day default.
- Provide a minimum-lead-time control from 0 minutes through 24 hours in five-minute increments with a 30-minute default, supporting minute and hour presentation.
- Submit the complete configuration as one save operation.
- Show one notice containing all validation errors returned for a rejected save.
- Display the normalized configuration returned by the backend after a successful save.
- Preserve keyboard operation and usability on narrow screens as already required by Issue #78.
- Keep fixtures aligned with the Issue #77 contract and remove them before Issue #78 is complete.
- Before any Agenda Interval review, show an accessible warning that names consultation-duration and weekly-availability effects and states that nothing changes before final confirmation.
- Use a read-only preflight, allow explicit complete-week adjustment without rounding or reset, and submit one stale-safe final confirmation for the interval, derived type durations, reviewed availability, and audit event.
- Keep the patient slot-grid interval independent from consultation duration: the persisted Agenda Interval determines candidate starts, while duration determines the contiguous span that must fit.

#### Frontend verification focus

- Keyboard-only users can add, remove, clear, and save windows and booking settings.
- The editor remains usable on narrow screens.
- Valid defaults, minimums, maximums, and five-minute increments are represented correctly.
- Overlap produces normalization feedback rather than a validation error.
- Rejected saves show one consolidated error notice without presenting partial success.
- Backend-normalized data replaces local draft values after success.
- Completion evidence uses the real Issue #77 integration rather than fixtures.
