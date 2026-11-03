# Issue #306 — Patient self-booking backend evidence

## Scope

This backend-only slice covers T1 and S1–S4/S6 from `odd/tasks/issue-306-patient-self-booking.md`. It does not claim completion of the parent issue, frontend integration, feature tracking, or human approval/signoff.

## Implemented behavior

- `BookingService.reserve/2` now accepts a completed patient profile without requiring `phone_verified: true`.
- Automatic approval creates `confirmed`; manual approval creates `requested`, independent of D-1 proximity.
- The service locks professional eligibility and the persisted consultation/agenda configuration, validates the real server-side slot, and delegates persistence to `Booking.persist_appointment/2`.
- Catalog snapshots are resolved from the persisted consultation type. Client `snapshot_override` values are ignored by the autonomous service.
- Patient identity is forced from the profile argument; request parameters cannot select a different patient.
- Collisions from the shared booking engine are translated to `:overlap_detected` at the autonomous service boundary.
- Database calendar availability now reads persisted appointment occupancy and excludes cancelled/rejected records, matching the existing schema and GiST constraint while retaining legacy `reserved` compatibility.
- Professional-patient relationship creation remains transactional with appointment persistence.
- The unsafe `PRO-DEMO-*` professional-id fallback was removed from the real autonomous service.

## Contract scenarios covered

- C1/C2: automatic confirmation and manual requested status.
- C3: durable relationship creation for both autonomous outcomes.
- C4: persisted catalog snapshots rather than client snapshots.
- C5: real two-connection collision test with one winner and one `:overlap_detected` loser.
- C6: completed patient with an unverified phone can reserve.
- C7/C8: ineligible professional and unauthenticated rejection without appointment mutation.
- C9: requested occupancy removes the slot from database availability.
- C11: forged patient id is ignored in favor of the authenticated profile argument.
- C10 and C12 remain outside this backend slice because the existing agenda privacy and cancellation lifecycle are not changed here.

## Verification evidence

The original RED command for the newly allowed legacy regression surface was observed before edits with the isolated PostgreSQL partition:

```text
MIX_TEST_PARTITION=_306_resume1 mix test test/origen/integration/journey_failure_regression_test.exs
exit 2: 11 passed, 3 failed, 0 skipped, 0 excluded.
```

The three failures were the outdated unverified-phone refusal, the legacy `:slot_already_booked` expectation, and a 12:00 fixture outside the persisted 08:00–12:00 / 14:00–18:00 agenda windows. The bounded test correction updated those expectations, changed the collision fixture to 10:00, and made the forensic rejection test use a unique incomplete profile with exact no-side-effect assertions.

Final isolated runtime verification, using the required PostgreSQL environment variables with credential values omitted here:

```text
MIX_TEST_PARTITION=_306_resume1 mix test test/origen/integration/journey_failure_regression_test.exs
exit 0: 14 passed, 0 failed, 0 skipped, 0 excluded.

MIX_TEST_PARTITION=_306_resume1 mix test <six focused files>
exit 0: 51 passed, 0 failed, 0 skipped, 0 excluded.

MIX_TEST_PARTITION=_306_resume1 mix test
exit 0: 878 passed, 0 failed, 32 skipped, 8 excluded.
```

Scenario coverage remains C1/C2, C3, C4, C5, C6, C7/C8, C9, and C11. The corrected legacy regression additionally covers successful completed-profile booking without phone verification, exact `:overlap_detected` collision behavior, real agenda slot selection, privacy-preserving opaque errors, rollback, and rejection side effects. C10 and C12 remain outside this backend slice.

Final structural checks:

```text
mix format --check-formatted: exit 0.
git diff --check: exit 0.
mix dialyzer: exit 0; Dialyzer reported configured warnings but no halting errors.
```

Writer boundary: the writer invoked no independent review or approval ceremony. Parent verification and native outcomes are recorded below.

## Parent verification and delivery state

- Independent verifier found no severe implementation blocker: focused 51 passed, journey 14 passed, format/whitespace/Dialyzer exit 0 (54 configured Dialyzer warnings skipped).
- Parent repeated the full suite: 878 passed, 32 skipped, 8 excluded; format/whitespace exit 0, seed 911023.
- Four additional direct calendar occupancy regressions then passed with the full calendar file (10 tests). No application source changed after independent verification; the full-suite count above predates these four added tests.
- User selected `feature-branch-chain`. First slice: `feat/306-patient-calendar-availability`, commit `1e177d681b121f6451c3f17d95b71f43c90baf9e` (147 authored changed lines). The dependent transactional booking slice remains uncommitted.
- Native calendar review `review-848188208626b04f` initially encountered missing reviewer model configuration. After the user requested retry, readability and reliability captures succeeded; exact acknowledgement completed for approved target `sha256:22514abbbdaf4c63f5cfbfc0a8678c3a31c51c5a347cb04540967e758bcca971`, authority burned. Three informative advisories (fixture isolation, occupancy status policy, test coverage) are nonblocking and offer no correction route. No global configuration or review-mode change was made by the agent.
- No push, PR creation, issue closure, frontend delivery, or parent integration was performed.

## Approval boundary

This receipt records implementation and attempted self-verification only. Approval belongs to the user. It does not close #280, start #308, or authorize frontend/integration work.
