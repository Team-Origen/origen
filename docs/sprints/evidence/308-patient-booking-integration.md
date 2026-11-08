# Evidence: patient booking integration (#308)

Status: human acceptance recorded on 2026-11-07; CI verification reopened after the reported failures. Calendar fixture correction is locally verified, but full local suites have additional varying failures. Updated GitHub CI is pending; not merge-ready.

## Scope and criterion mapping

The feature covers T1 and S1, S4-S8, and S10 across two local review slices on verified default branch `develop` (`a735b37`):

1. HTTP/session/LiveView: `test/origen_web/live/patient_booking_integration_test.exs` (3 tests).
2. Self-booking rejection/atomicity follow-up: `test/origen/integration/patient_self_booking_test.exs` (3 tests), plus final tracking.

The checks below were observed on the combined working tree. Slice 1 is commit `ece09e6` on local branch `feat/308-01-real-booking` (317 authored lines with evidence); slice 2 is the following rejection/atomicity commit on `feat/308-patient-booking-integration`. No publishing or merge is authorized. Combined coverage includes:

- patient magic-link delivery, the public `GET /access/verify` route, the resulting session, and `PatientBookingCalendarLive`;
- persisted professional profile, agenda configuration, the production `Origen.ConsultationTypes.DatabaseCatalog`, and `DatabaseCalendar` availability;
- automatic `confirmed` and manual `requested` patient bookings through `BookingService.reserve/2`;
- unverified phone booking, a same-day booking with a deterministic reference time, and a D-1 booking without the legacy status rule;
- slot occupancy, durable professional-patient visibility through public booking context APIs, stale occupancy conflicts through the real LiveView, incomplete-identity denial, and self-only patient identity.

Payments, family/dependant booking, approval/rejection configuration, and manual request resolution are not included.

## Checks and observed results

The secure runner loaded repository-local database settings without printing credentials and used port `5432` with `MIX_TEST_PARTITION=_308_integration`.

- Parent `job-5` on the original files: **2/4 passed**; the only failure was the `Calendar.strftime` module-shadowing error in `patient_self_booking_test.exs`. The test fixture was corrected to call `Elixir.Calendar.strftime/2`.
- Parent `job-6` after switching to the production catalog adapter: **5/6 passed**, exit 2, seed `233616`; the remaining failure was the forged mixed atom/string patient-id assertion, which expected success while the service returned `{:error, :rollback}`.
- Focused secure command, equivalent to `MIX_TEST_PARTITION=_308_integration mix test test/origen_web/live/patient_booking_integration_test.exs test/origen/integration/patient_self_booking_test.exs` with credentials loaded privately from `config/dev.local.exs`: **exit 0**, seed `837522`, **6 passed** in 1.0 seconds.
- Affected-suite secure command for `test/origen/appointments/booking_service_test.exs`, `test/origen/appointments/database_calendar_test.exs`, `test/origen_web/live/patient_booking_calendar_live_test.exs`, and `test/origen/integration/journey_failure_regression_test.exs`: **exit 0**, seed `39039`, **53 passed** in 2.6 seconds. Existing deprecation warnings for the legacy `determine_initial_status/2` compatibility tests were observed; no failures occurred.
- `mix format --check-formatted test/origen_web/live/patient_booking_integration_test.exs test/origen/integration/patient_self_booking_test.exs`: **exit 0**.
- `git diff --check`: **exit 0**.
- Full secure `mix test` on the same isolated partition (parent `job-7`): **exit 0**, seed `929635`, **918 passed, 32 skipped, 8 excluded**, 50.1 seconds ExUnit / 52 seconds elapsed. `postgres_security: true` remained excluded; no claim is made that skipped/excluded tests ran. Existing OTP 28.0 regex and deprecated-helper warnings did not fail the suite.
- Native read-only assessment: **medium**, `reviewDue: false`, `reviewDueReason: under_budget`, RDD off; writer self-verification required, independent verifier not required. No native review or approval was run.

The forged third-party request is now asserted as the exact observed rejection `{:error, :rollback}`. The test also verifies unchanged public agenda and relationship projections and confirms that the requested free slot remains available. This satisfies the contract's permitted reject-or-force-self behavior without an unnecessary production change.

## Incident L10-L11: CI date-dependent fixture correction

The original CI runs failed on both published candidates: PR #418 reported 906/915 passed with 9 failures, and PR #419 reported 909/918 passed with 9 failures. The validation and secret-scan checks passed; only the test job failed. New CI is still pending, so no merge-readiness is claimed.

The reproduced cause was a test fixture date assumption, not adapter leakage or product behavior. On CI's Saturday date, 2026-11-07, `next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))` selected Saturday 2026-11-14, while the fixture's persisted weekly availability intentionally has Saturday and Sunday empty. The public `PatientBookingCalendarLive` therefore rendered `No hay turnos disponibles para este día`, proving why the expected `09:00` slot and subsequent public selectors were absent. The existing Saturday assertion remains unchanged.

- Local RED: secure `MIX_TEST_PARTITION=_308_ci mix test test/origen_web/live/patient_booking_calendar_live_test.exs` reproduced exit 2, 10/19 passed, and the same 9 tests failed.
- Correction: the test-only `next_booking_weekday/1` fixture helper skips weekend candidates while preserving the existing `next_weekday/2` behavior and public calendar assertions; the new regression exercises reference dates at offsets 0 through 6 through public `render_change/3`, covering all seven weekdays. No production code, adapter, clock, timeout, or expectation weakening changed.
- Local GREEN: the same calendar command passed 20 tests; related integration/self-booking passed 6 tests; booking service/database calendar passed 20 tests with only pre-existing deprecation warnings.
- Correction commits: `d98d936` on the cumulative branch; `ca5b778` on the first-slice branch; normal ancestry propagation into the cumulative branch, no force push. The first slice remains 362 authored diff lines; final slice stays below 400.
- Full local suite job-14: exit 2, seed `639458`, **918/919 passed, 32 skipped, 8 excluded**; the original nine failures were absent. One different failure occurred in the professional booking wall-time test during session-authorized patient lookup; it passed isolated (1 passed, 17 excluded).
- Same-seed diagnostic job-15: exit 2, **918/919 passed, 32 skipped, 8 excluded**, but a different availability LiveView token initialization failed with `{:error, :invalid}`; the prior professional booking failure did not recur. No production root cause was established, and no unrelated authorization/token behavior was changed.
- Isolated first-slice full suite job-16: exit 2, seed `902208`, **914/916 passed, 32 skipped, 8 excluded**; two other failures involved internal login (422 instead of 302) and restoring professional profile completeness. Original nine calendar failures were absent here too.
- These failing full-suite results remain failures, not green proof. The previous 918-pass run is historical evidence and is not substituted for the new candidate. Updated GitHub CI on each corrected head is required before merge-readiness; no more local full-suite reruns are planned for this correction.

## Test coverage added

`test/origen_web/live/patient_booking_integration_test.exs` enters through a real captured local magic-link email and HTTP verification route, mounts the patient calendar with the production `DatabaseCatalog` and `DatabaseCalendar` adapters, selects a persisted professional/type/date/slot, and confirms both automatic and manual outcomes. It also reserves a selected slot through a second patient before confirmation and verifies the real LiveView stale-slot rejection without a partial first booking.

`test/origen/integration/patient_self_booking_test.exs` verifies same-day booking without phone verification against a fixed reference time, incomplete-identity denial, occupied-slot rejection, and forged patient-id isolation. Rejected patients leave the public agenda and related-patient projection unchanged; the mixed forged patient-id request is rejected and leaves its requested free slot available.

## Limitations and pending proof

- No production implementation change was required: the existing `PatientBookingCalendarLive`, `DatabaseCatalog`, `DatabaseCalendar`, `BookingService`, and transaction invariants are exercised by the new tests. The earlier custom SQL catalog test double was removed.
- No interactive browser execution was performed; the HTTP/session/LiveView journey is covered through Phoenix integration tests, not a browser automation claim.
- Initial runner attempts failed before test execution (connection refused on the default test port, then missing password at the available local port). Using existing repository-local settings recovered the test environment without changing configuration; no timeout or permission denial was retried.
- The user explicitly accepted the verified integration on 2026-11-07 (see below). Acceptance is not publishing, merge, or GitHub closure. The parent tracking document records local commit boundaries. No GitHub issue was closed or commented on, no PR was created, and publication subsequently proceeded only after explicit user authorization. PR #418 and PR #419 exist; the user is responsible for merge.

## Human acceptance

User statement, verbatim: "Ok, apruebo la integración si es que vos ya determinaste que la implementación técnica quedó verificada."

The condition is satisfied by the observed focused, affected-suite and full-suite results above. This records explicit acceptance of integration #308 and its parent #280 acceptance scope, with the documented skipped/excluded tests and absence of interactive browser execution unchanged. No new test run or independent/native approval is implied. The implementation is accepted locally; publishing, integration into `develop`, and recording the corresponding GitHub issue closures remain delivery steps, not completed actions.

Risk: none (Task Size high-risk items). The diff adds tests and evidence only; production authentication, authorization, concurrency, persistence contracts, schemas and configuration are unchanged. Existing production behavior passes the new integrated checks; no production fix is claimed.
