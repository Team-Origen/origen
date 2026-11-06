# Evidence: patient booking integration (#308)

Status: implementation evidence prepared; human acceptance and parent closure remain outstanding.

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

## Test coverage added

`test/origen_web/live/patient_booking_integration_test.exs` enters through a real captured local magic-link email and HTTP verification route, mounts the patient calendar with the production `DatabaseCatalog` and `DatabaseCalendar` adapters, selects a persisted professional/type/date/slot, and confirms both automatic and manual outcomes. It also reserves a selected slot through a second patient before confirmation and verifies the real LiveView stale-slot rejection without a partial first booking.

`test/origen/integration/patient_self_booking_test.exs` verifies same-day booking without phone verification against a fixed reference time, incomplete-identity denial, occupied-slot rejection, and forged patient-id isolation. Rejected patients leave the public agenda and related-patient projection unchanged; the mixed forged patient-id request is rejected and leaves its requested free slot available.

## Limitations and pending proof

- No production implementation change was required: the existing `PatientBookingCalendarLive`, `DatabaseCatalog`, `DatabaseCalendar`, `BookingService`, and transaction invariants are exercised by the new tests. The earlier custom SQL catalog test double was removed.
- No interactive browser execution was performed; the HTTP/session/LiveView journey is covered through Phoenix integration tests, not a browser automation claim.
- Initial runner attempts failed before test execution (connection refused on the default test port, then missing password at the available local port). Using existing repository-local settings recovered the test environment without changing configuration; no timeout or permission denial was retried.
- The evidence is not approval or closure. Human acceptance of #308/#280 remains pending. The parent tracking document records final local commit boundaries. No GitHub issue was closed or commented on, no PR was created, and nothing was pushed.

Risk: none (Task Size high-risk items). The diff adds tests and evidence only; production authentication, authorization, concurrency, persistence contracts, schemas and configuration are unchanged. Existing production behavior passes the new integrated checks; no production fix is claimed.
