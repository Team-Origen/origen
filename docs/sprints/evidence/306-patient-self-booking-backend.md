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
- User selected `feature-branch-chain`. First slice: `feat/306-patient-calendar-availability`, commit `1e177d681b121f6451c3f17d95b71f43c90baf9e` (147 authored changed lines). Dependent transactional booking slice: `feat/306-patient-booking-backend`, commit `8500c2dce6c2efa668a46e35d82d0b38d9651e49` (1165 authored changed lines). The booking unit intentionally keeps transaction code, security/concurrency tests and regression fixtures together despite exceeding the review-size heuristic.
- Native calendar review `review-848188208626b04f` initially encountered missing reviewer model configuration. After the user requested retry, readability and reliability captures succeeded; exact acknowledgement completed for approved target `sha256:22514abbbdaf4c63f5cfbfc0a8678c3a31c51c5a347cb04540967e758bcca971`, authority burned. Three informative advisories (fixture isolation, occupancy status policy, test coverage) are nonblocking and offer no correction route. No global configuration or review-mode change was made by the agent.
- Native assessment of committed booking slice `1e177d6..8500c2d` returned `nativeRisk: medium`, `reviewDue: false`, `reviewDueReason: under_budget`; no further native review was started. Explicit identity/security escalation required independent verification, already completed for the unchanged final source. This is not a native approval of the booking slice.
- No push, PR creation, issue closure, frontend delivery, or parent integration was performed.

## Compatibility follow-up: T4 / S7

This bounded follow-up covers S7 while preserving S2-S4 and S6. The production LiveView no longer constructs or sends the unused `snapshot_override` payload. `BookingService.reserve/2` still accepts that optional legacy input shape, explicitly ignores it, and passes `nil` to `Booking.persist_appointment/2`; persisted catalog name, duration, and price remain authoritative. The existing public reserve tests continue to supply forged overrides and assert the persisted catalog snapshots, so older payloads still succeed without gaining trust over stored values. No meaningful RED applies to removing an ignored caller payload; the existing public behavior regression is pinned instead.

The exported `BookingService.determine_initial_status/2` retains its pre-#306 compatibility behavior and arity: D-1 and D return `"confirmed"`, while dates more than one day ahead return `"reserved"`. It is marked deprecated with migration guidance. Autonomous `reserve/2` does not call it: automatic approval remains `"confirmed"`, manual approval remains `"requested"`, including for distant dates and patients without verified phones. Existing reservation, relationship, identity, overlap, and persisted snapshot assertions remain unchanged.

## Compatibility verification

The required focused command was run before source edits as RED after adding the historical-helper tests: exit 2, 23 passed, 1 failed (the distant-date assertion still observed `"confirmed"`). After the bounded source changes it passed as GREEN: exit 0, 24 passed, 0 failed, 0 skipped, 0 excluded. The run emitted only the expected deprecation warning at the compatibility test call sites and the existing OTP regex warning.

The writer's first full suite on isolated `_306_resume1` exited 2: 883 passed, 1 failed, 32 skipped, 8 excluded. The failure was the existing `OrigenWeb.InternalSessionControllerTest` login-redirection assertion (`expected status 302, got 422`), outside modified files. Parent then ran the controller file (6 passed, exit 0) and the complete suite (884 passed, 32 skipped, 8 excluded, seed 169866, exit 0), followed by format/whitespace checks (exit 0). The original login failure did not reproduce; its cause is not established and no login code was changed.

`mix format --check-formatted` passed after formatting only the touched Elixir files. `mix dialyzer` passed successfully with the repository's existing 54 configured warnings skipped. `git diff --check` passed on the final source state before these evidence-only updates. No credentials are recorded here.

Changed surfaces for this unit are `lib/origen/appointments/booking_service.ex`, `lib/origen_web/live/patient_booking_calendar_live.ex`, `test/origen/appointments/booking_service_test.exs`, and this evidence file. The existing self-booking and LiveView tests remain the regression coverage for catalog snapshots, identity/effects, approval-mode status, unverified-phone booking, and real persisted LiveView reservation behavior; no CLI, schema, dependency, UI text, or workflow change was made.

### Independent compatibility verification

Initial verifier `mw19k3la-3-i208` found no concrete source-level blocker for S7 or preserved S2-S4/S6, but its scratch test and formatter exited 1 before execution due to a `Hex.Netrc.Cache` beam load failure. No tests from that attempt are counted as passed. The user subsequently selected environment investigation rather than accepting missing runtime proof.

Authorized verifier `mw1ah2m3-5-mh7g` established that redirecting HOME had broken asdf plugin discovery; bypassing those shims and copying cached Hex binaries had then caused OTP 28 module-load failure. Different cwd-selected runtime versions were not confirmed. The correction retained the working installed runtime/HOME (Elixir 1.20.3 compiled for OTP 28, Erlang 28.0) and isolated only build/dependency paths using `MIX_BUILD_ROOT` and `MIX_DEPS_PATH`. No install, upgrade, toolchain/global configuration change, dependency-source change or application edit was required.

Independent commands using the isolated `_306_resume1` database partition:

```text
mix test test/origen/appointments/booking_service_test.exs \
  test/origen/appointments/patient_self_booking_test.exs \
  test/origen_web/live/patient_booking_calendar_live_test.exs
exit 0: 24 passed, 0 failed, 0 skipped, 0 excluded.

mix format --check-formatted: exit 0.
git diff --check: exit 0.
```

Verdicts: S7 met; S2-S4/S6 preserved. Historical helper behavior, ignored legacy snapshot input, autonomous approval-mode outcomes and persisted LiveView bookings pass independently. The expected helper deprecation and existing OTP 28 regex performance warnings remain. The earlier runtime limitation is resolved; the previous native `escalated/unknown_causality` outcome is not reclassified or altered.

## Compatibility delivery and assessment

- Compatibility commit: `135406c7ab7fa86a0b304f3815a540724dc5fae1` on `feat/306-patient-booking-backend`, assessed against exact prior boundary `bb1074c5ce9a5dcf37fac4da595d376227b90ad4` (92 authored changed lines, five paths). This is a separate reviewable unit in the existing `feature-branch-chain`, not the accumulated branch candidate.
- Committed-only native assessment returned `nativeRisk: medium`, `reviewDue: false`, `reviewDueReason: under_budget`, `rddLine: on`, and `nativeReviewOutcome: unknown`. Item-3 escalation retains the independent-verifier requirement; it is satisfied by the completed 24-test independent run and static inspection on unchanged application source. Writer/parent functional checks also passed.
- No further native review route was offered, so no new review was started. This assessment is not native approval and does not supersede the prior backend `escalated/unknown_causality` result.
- The following closeout changes only evidence and task tracking. No source changes, publishing, PR creation, merge or issue closure are included.

## Approval boundary

This evidence records implementation, passing self-verification and independent compatibility verification. Human approval belongs to the user. It does not close #280, start #308, or authorize frontend/integration work.
