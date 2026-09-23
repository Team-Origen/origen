# Issue 93: Construir envío de la primera reserva autónoma del Paciente

## Outcome
Enable verified patients to submit autonomous appointment reservations directly from the booking calendar (PLN-09 / Father Issue #42), persisting historical snapshots of consultation type, price, and duration, determining initial status per RF-10, and presenting the confirmed reservation outcome.

## Scope & Constraints
- Subissue: #93 (Father Issue: #42).
- Boundary: Connects patient booking calendar LiveView to the transactional reservation engine (`Origen.Booking.persist_appointment/2`), verifies profile readiness, captures snapshots, and renders success card.
- Budget: Strictly <= 400 lines per PR (split into 2 stacked PRs: PR 1 Backend Reservation Service, PR 2 LiveView Submission & Outcome Presentation).

## Tasks
- [x] 1. Branch setup: create `feature/93-autonomous-booking-service` from `develop`.
- [x] 2. Backend service: implement `Origen.Appointments.BookingService` encapsulating patient readiness verification, slot datetime calculation, snapshot persistence via `Origen.Booking`, and RF-10 initial status resolution.
- [x] 3. Unit tests: create test suite in `test/origen/appointments/booking_service_test.exs` testing successful booking, snapshot preservation, unverified patient rejection, and atomic rollback.
- [x] 4. PR 1/2: open stacked PR 1/2 against `develop` (<= 400 lines) and verify CI checks. Evidence: PR #172.
- [x] 5. Branch setup 2: create `feature/93-booking-calendar-submission` from PR 1 branch.
- [x] 6. Frontend integration: connect `PatientBookingCalendarLive` submit action to `BookingService`, display real appointment ID, price, and status in outcome view.
- [x] 7. LiveView tests: test end-to-end booking submission, flash feedback, and success view rendering.
- [x] 8. PR 2/2: open stacked PR 2/2 against PR 1 branch (<= 400 lines) and verify CI checks.
- [x] 9. Verification & manual testing flow: provide step-by-step interactive testing guide. Evidence: `docs/qa/qa-93-patient-autonomous-booking.md` and `priv/repo/check_autonomous_booking_e2e.exs`.

## Post-QA defect corrections
- [x] 10. Reset confirmation state and booking result when starting another reservation. Evidence: repeated-booking LiveView regression test.
- [x] 11. Reset and re-render consultation type when the professional changes. Evidence: professional/type-duration regression test.
- [x] 12. Repair mojibake in booking confirmation literals. Evidence: UTF-8 assertions and zero mojibake marker matches.
- [x] 13. Guard unauthenticated calendar access and provide an explicit patient-session exit path. Evidence: LiveView redirect and controller session-deletion tests.
- [x] 14. Add regression tests, run verification, and commit the correction work unit. Evidence: 33 focused tests passing; work-unit commit `fdc77c4`. Native review was explicitly declined for this candidate before delivery.
