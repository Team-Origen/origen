# Issue #307 — Patient self-booking frontend evidence

Implementation is verified on `feat/307-patient-booking-frontend`, based on backend commit `3d0a5e7`: 19 focused tests and the full suite pass. Native assessment is medium risk and does not require a native review. Human acceptance is not granted. No publishing or issue closure occurred.

## Scope and traceability

- Issue: #307; parent: #280; contract: #305 (closed and approved).
- OpenSpec change: `health-center-beta-core`.
- Path: `openspec/changes/health-center-beta-core/`.
- Scope: Sprint 3 / parent #280 / frontend.
- Task document: `odd/tasks/issue-307-patient-booking-frontend.md`.

The existing LiveView now distinguishes confirmed appointments from pending requests, removes phone-verification and D-1 policy presentation, validates selections, renders professional-list failures safely, refreshes availability on overlap, and ignores repeated confirmation events after success. Backend services, authentication, router, database schemas and shared adapters are unchanged. Fixtures are not evidence of production availability or completion of integration #308.

## Observed checks

Writer: `mw22hn76-2-xwyk`. Commands used PostgreSQL environment overrides with credential values intentionally omitted here, and `MIX_TEST_PARTITION=_307_frontend`.

| Check | Observed result |
| --- | --- |
| Focused RED: `mix test test/origen_web/live/patient_booking_calendar_live_test.exs` | Exit 2; 7 passed, 6 failed before implementation. |
| Focused GREEN: same test file | Exit 0; 13 tests, 0 failures. |
| Formatter/check-formatted on three changed Elixir files | Exit 0. |
| `git diff --check` | Exit 0, also confirmed by parent. |
| Full `mix test`, bounded with `timeout 30s` | Timed out; no final ExUnit summary or complete counts. This is failed/incomplete verification, not a passing suite. No automatic retry. |
| Native `gentle_review assess` | `nativeRisk: unassessable`: explicit untracked-file declaration required. No review started or approved. |

The full-suite output excluded `postgres_security: true` and emitted existing deprecated-helper warnings. Exact skipped/excluded totals and the final suite result are unavailable.

## Authorized follow-up

The user answered “Si, autorizo.” to a new bounded/background full-suite execution and completion of outstanding proof before commits. Follow-up writer `mw23a2nj-3-8ir3` added catalog failure/empty, daily-schedule failure, no-slot confirmation, incomplete-profile reminder and sanitized booking failure coverage. Duplicate confirmation now checks stable rendered results, occupied availability through the public Calendar boundary and conflict through BookingService. Starting another booking refreshes availability so the occupied slot is not offered again.

- Focused baseline: 13 tests, 0 failures, exit 0.
- Expanded first run: 18 passed, 1 failed, exit 2. The test fixture used unsupported account state `inactive`; it was corrected to an incomplete professional profile. This was a fixture error, not a production defect.
- Final focused run: 19 tests, 0 failures, exit 0. Existing behavior tests were regression-only, not fabricated RED evidence.
- Touched-file format/check-formatted and whitespace: exit 0.
- Authorized full suite: background job-3 under `timeout 600s`, exit 0 after 52 seconds; ExUnit 50.1 seconds, seed `444250`: **894 passed, 32 skipped, 8 excluded**. `postgres_security: true` remained excluded. Existing OTP regex/deprecated-helper warnings did not fail the run.
- After staging intended files, native assessment succeeded: `nativeRisk: medium`, `reviewDue: false`, `reviewDueReason: under_budget`; writer self-verification required, independent verifier not required. No native review started or approval claimed.

## Remaining proof and approval

No interactive browser verification was performed; browser loading behavior remains unverified. No browser tool was found in the available petal tool lookup. The full-suite timeout above remains recorded; the successful new execution was explicitly authorized, not an automatic retry. All remaining checks named in this evidence are accounted for; fixture corrections and earlier unsuccessful assessment remain recorded rather than erased.

Human approval of this frontend slice is **not granted**. #307, #280 and #308 remain open; no integration work is authorized or claimed by these fixtures. Review workload is approximately 794 source/test diff lines including the new fixture, before tracking/evidence documentation. The smallest cohesive current unit keeps state transitions, rendering and their tests together; do not hide its size by compressing code or dropping tests. Local commits keep behavior, tests and this evidence together, with tracking/commit references in a subsequent bookkeeping commit. No PR-size policy exception or publishing authorization is implied.
