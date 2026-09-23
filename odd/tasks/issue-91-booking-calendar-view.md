# Issue 91: Construir la vista del calendario de reserva

## Outcome
Deliver the patient booking calendar interface and domain contract under PLN-09 (Father Issue #42), enabling patients to view available slots, navigate dates, handle empty/error states, and inspect cancellation and penalty policies before booking.

## Scope & Constraints
- Subissue: #91 (Father Issue: #42).
- Boundary: Uses deterministic local mock calendar fixtures per #91 policy (real schedule integration belongs to #92; transactional booking engine belongs to #93).
- 400-line budget: Split into 2 stacked PRs (PR 1: Domain & Mock Calendar; PR 2: LiveView & UI).
- Accessibility: Keyboard accessible and responsive for narrow mobile screens.

## Tasks
- [x] 1. Branch setup: create `feature/91-booking-calendar-domain` from `develop`.
- [x] 2. Domain & contract: implement `Origen.Appointments.Calendar` behaviour and `Origen.Appointments.MockCalendar` with slot models, policy definitions, and demo availability.
- [x] 3. Unit tests: add tests for calendar contract and mock slots in `test/origen/appointments/mock_calendar_test.exs`.
- [ ] 4. PR 1/2: open stacked PR 1/2 against `develop`, target <= 400 lines, verify CI green.
- [x] 5. Branch setup 2: create `feature/91-booking-calendar-liveview` from PR 1 branch.
- [x] 6. Frontend LiveView: implement `OrigenWeb.PatientBookingCalendarLive` at `/patient/calendar` with PetalComponents, patient readiness guard, slot selection, empty/error states, and confirmation policy modal/panel.
- [x] 7. LiveView tests: add tests covering readiness guard, date navigation, slot selection, and policy presentation in `test/origen_web/live/patient_booking_calendar_live_test.exs`.
- [x] 8. PR 2/2: open stacked PR 2/2 against PR 1 branch, target <= 400 lines, verify CI green.
- [ ] 9. Verification & manual testing flow: provide step-by-step interactive testing guide for user review.
