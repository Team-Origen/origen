# Issue 92: Integrar horarios reales en el calendario del Paciente

## Outcome
Implement the core appointment availability calculation engine and integrate consultation type durations and existing occupancies into the patient booking calendar (PLN-09 / Father Issue #42), ensuring only truly bookable slots fitting continuous windows and respecting lead time are offered.

## Scope & Constraints
- Subissue: #92 (Father Issue: #42).
- Boundary: Pure functional availability calculation engine and UI integration using available consultation types (#74) and in-memory mock fixtures/contracts before final DB schema merge of #77 and #63.
- Budget: Strictly <= 400 lines per PR (split into 2 stacked PRs: PR 1 Domain Engine, PR 2 UI Consultation Integration).

## Tasks
- [x] 1. Branch setup: create `feature/92-availability-engine` from `develop`.
- [x] 2. Domain engine: implement `Origen.Appointments.Availability` pure functional module with grid alignment, duration fitting, collision avoidance, and minimum lead time rules.
- [x] 3. Unit tests: create comprehensive test suite in `test/origen/appointments/availability_test.exs` testing all edge cases of window boundaries, multi-interval durations, occupancies, and lead times.
- [ ] 4. PR 1/2: open stacked PR 1/2 against `develop` (<= 400 lines) and verify CI checks.
- [x] 5. Branch setup 2: create `feature/92-patient-calendar-consultation-selection` from PR 1 branch.
- [x] 6. Frontend integration: integrate consultation type selector and dynamic duration slot computation into `PatientBookingCalendarLive`.
- [x] 7. LiveView tests: test dynamic consultation type selection and slot recalculation in `PatientBookingCalendarLiveTest`.
- [x] 8. PR 2/2: open stacked PR 2/2 against PR 1 branch (<= 400 lines) and verify CI checks.
- [ ] 9. Verification & manual testing flow: provide interactive step-by-step verification guide.
