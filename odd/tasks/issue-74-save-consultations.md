# Issue 74: Persist professional consultation settings

## Objective

Persist every behavior currently offered by `/configuracion/profesional`: the authenticated Professional's Agenda Interval and Consultation Type catalog, including create, update, deactivate, reactivate, and atomic interval changes.

## Problem

The existing LiveView is authenticated but still loads `PRO-DEMO-001` and mutates socket-local mock data. Reloading the page loses changes, and the backend cannot yet enforce the screen's domain rules.

## Why

Issue #74 must provide a reviewable backend for the already-built Issue #75 screen without waiting for the future Person/Profile model. This implementation deliberately uses the authenticated internal Professional account as temporary ownership while preserving a principal-based public API.

## Scope

- Persist one Agenda Interval configuration per authenticated Professional account.
- Persist account-owned Consultation Types with immutable UUID identity.
- Support create, update, deactivate, reactivate, and atomic Agenda Interval application.
- Connect the existing LiveView to the persisted public context.
- Enforce account isolation, current validation rules, and fail-closed target lookup.
- Keep the route unavailable in production while ownership remains account-based.

## Out of Scope

- Person and Professional Profile persistence.
- Migration to `professional_profile_id` ownership.
- Production route exposure.
- Appointment creation and booking snapshot persistence.
- Regular availability and booking-window behavior.
- GitHub delivery operations unless separately authorized.

## Constraints and Decisions

- Branch: `feat/74-save-consultations`, based on `develop` at `bba0b79` when work started.
- Temporary owner: authenticated `internal_account_id` with active `professional` role.
- The browser never supplies or selects an owner identifier.
- Public API:
  - `Origen.ConsultationTypes.get_own_configuration/1`
  - `Origen.ConsultationTypes.create_type/2`
  - `Origen.ConsultationTypes.update_type/3`
  - `Origen.ConsultationTypes.deactivate_type/2`
  - `Origen.ConsultationTypes.reactivate_type/2`
  - `Origen.ConsultationTypes.apply_agenda_interval/2`
- Agenda Interval: 5–240 minutes inclusive, in increments of 5; default 30.
- Consultation duration: `interval_count * agenda_interval_minutes`, maximum 240 minutes.
- Effective interval count: `1..min(10, floor(240 / agenda_interval_minutes))`.
- Names are trimmed, required, at most 32 graphemes, case-preserving, internal-space-preserving, and may be duplicated.
- Price uses exact `Decimal`, is non-negative, and has at most two decimal places.
- Color uses uppercase `#RRGGBB`.
- Inactive types cannot be edited and retain count plus deactivation-time duration.
- Reactivation never adapts or replaces the preserved count.
- Interval application preserves counts, active IDs, and inactive historical durations; any incompatible active type rejects the whole change.
- No hard delete.
- About 400 authored changed lines per task is an advisory review heuristic, never a reason to omit tests or compress code.

## Authorized Scope

- Local repository source, migrations, tests, configuration, and task-document updates required for Issue #74.
- Local test, format, compile, and database verification commands.
- No push, PR, Issue mutation, deployment, production credentials, or production data without separate explicit authorization.

## TDD Mode

- Enabled by explicit user approval of the public seams.
- Runner: Windows MSVC wrapper followed by the relevant `mix test ...` command.
- Required loop for each behavior: observed RED, minimal GREEN, then review-stage cleanup.
- Tests observe mutations through the public context or authenticated LiveView, not private validators or direct schema assertions.

## Tasks

- [x] **T1 — Persist and read account-owned configuration**
  - Add Agenda settings and Consultation Type persistence with database constraints.
  - Resolve the authenticated active Professional account from the principal.
  - Implement `get_own_configuration/1` with default interval 30 and owner isolation.
  - Prove missing, inactive, wrong-role, and foreign ownership paths fail closed.
  - Rollback boundary: remove the read context and empty new tables; populated tables require preservation.

- [x] **T2 — Create a Consultation Type**
  - Implement `create_type/2` through the public context.
  - Enforce name, exact price, color, count, duration, immutable ID, and ignored/rejected owner input.
  - Prove duplicate names are accepted and failed writes leave no partial state.
  - Rollback boundary: disable creation while retaining already-created rows.

- [x] **T3 — Update an active Consultation Type**
  - Implement `update_type/3` using immutable ID within owner scope.
  - Preserve owner and identity; reject inactive, missing, and foreign targets uniformly.
  - Validate count against the current locked Agenda Interval.
  - Rollback boundary: remove update entry points while retaining persisted rows.

- [x] **T4 — Deactivate without deletion**
  - Implement `deactivate_type/2`.
  - Preserve identity and count; capture exact deactivation-time duration.
  - Reject repeated, missing, and foreign operations without mutation.
  - Rollback boundary: disable deactivation while preserving statuses and history.

- [x] **T5 — Reactivate under the current interval**
  - Implement `reactivate_type/2` without count replacement or adaptation.
  - Clear historical inactive duration only after compatible success.
  - Keep incompatible attempts unchanged.
  - Rollback boundary: disable reactivation while retaining inactive records.

- [x] **T6 — Apply Agenda Interval atomically**
  - Implement `apply_agenda_interval/2` with owner configuration locking.
  - Validate every active type, return all blockers, and reject without partial effects.
  - Preserve every count and all inactive historical durations.
  - Serialize interval changes against create, update, and reactivate operations.
  - Rollback boundary: disable interval mutation while preserving the last committed interval.

- [x] **T7 — Connect `/configuracion/profesional` to persistence**
  - Replace `PRO-DEMO-001`, mock reads, socket-local UUID generation, and local mutation authority.
  - Pass the server-created authenticated principal to the public context.
  - Reload authoritative state after successful commands and map errors into the existing accessible UI.
  - Prove persistence across remount and isolation between two Professional accounts.
  - Keep the production feature flag disabled.
  - Rollback boundary: restore the mock adapter only in non-production; retain persisted data.

- [x] **T8 — Verify database capability and final behavior**
  - Prove runtime cannot change owner/identity, delete/truncate data, perform DDL, or mutate audit history.
  - Ensure all relevant `postgres_security` suites run in CI-compatible commands.
  - Run focused tests, full tests, compile warnings-as-errors, formatter check, and `git diff --check`.
  - Record every failed, skipped, unavailable, or pending check honestly.
  - Rollback boundary: revoke new privileges without dropping populated business or audit data.

## Acceptance Criteria

- An authenticated active Professional can reload the page and retain all supported configuration changes.
- A different Professional, Administrator, Secretary, inactive account, or unauthenticated request cannot read or mutate that configuration.
- All screen rules listed under Constraints and Decisions are enforced by the backend.
- No command accepts ownership from browser-controlled input.
- Mutations are atomic and leave unchanged state after validation or persistence failure.
- The existing presentation and accessibility behavior remain intact.
- The route remains excluded from production until Professional Profile ownership is implemented.

## Applicable Checks

All Mix commands on Windows use:

```text
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 && <command>
```

Focused and final checks:

```text
mix test test/origen/consultation_types_test.exs
mix test test/origen_web/consultation_type_catalog_live_test.exs
mix test --only postgres_security
mix format --check-formatted
mix compile --warnings-as-errors
mix test
git diff --check
```

## Progress

- Current task: completed.
- T1 evidence:
  - RED: after correcting the raw SQL UUID fixture, `get_own_configuration/1` returned Postgrex's 16-byte UUID instead of the canonical UUID string.
  - GREEN: `mix test test/origen/consultation_types_test.exs` passed 5 tests; parent spot-check passed the same 5 tests.
  - `mix compile --warnings-as-errors` passed with the existing Windows LiveView symlink warning.
  - Focused formatting passed for every T1 file; repository-wide `mix format --check-formatted` remains blocked by unrelated baseline files/line endings.
  - `git diff --check` passed; native risk assessment classified the three T1 implementation paths as medium risk.
  - `mix deps.get` restored the already-declared `eqrcode` dependency after explicit authorization.
- T2 evidence:
  - RED 1: `create_type/2` was undefined, producing 7 failures across the new creation behaviors.
  - RED 2: a valid 32-grapheme combining-character name exposed PostgreSQL `varchar(32)` codepoint semantics.
  - GREEN: focused context suite passed 13 tests; parent spot-check passed the same 13 tests.
  - `mix compile --warnings-as-errors`, focused format checks, and `git diff --check` passed; the existing Windows symlink warning and unrelated global formatting baseline remain recorded.
  - Native risk assessment classified the four T1/T2 implementation paths as medium risk.
- T3 evidence:
  - RED: `update_type/3` was undefined, producing 6 failures across owner-scoped update behaviors.
  - GREEN: focused context suite passed 19 tests; parent spot-check passed the same 19 tests.
  - Compile, focused format checks, and `git diff --check` passed; native risk remained medium.
  - Malformed, missing, inactive, and foreign IDs share the public `{:error, :not_found}` result and preserve prior state.
- T4 evidence:
  - RED: `deactivate_type/2` was undefined, producing 4 failures across lifecycle behaviors.
  - GREEN: focused context suite passed 23 tests; parent spot-check passed the same 23 tests.
  - Compile, focused format checks, and `git diff --check` passed; native risk remained medium.
  - Deactivation preserves the row, identity, owner, count, and data while freezing `interval_count * current_interval` independently of later interval values.
- T5 evidence:
  - RED: `reactivate_type/2` was undefined, producing 5 failures across compatible and incompatible reactivation behaviors.
  - GREEN: focused context suite passed 28 tests; parent spot-check passed the same 28 tests.
  - Compile, focused format checks, and `git diff --check` passed; native risk remained medium.
  - Reactivation accepts the exact 240-minute boundary, clears historical duration only on success, and returns safe incompatibility evidence without adaptation or mutation.
- T6 evidence:
  - RED: `apply_agenda_interval/2` was undefined, producing 4 failures across interval behaviors.
  - GREEN: focused context suite passed 33 tests; parent spot-check passed the same 33 tests.
  - Compile, focused format checks, and `git diff --check` passed; native risk remained medium.
  - Compatible application updates only the interval; blocked application returns every deterministic blocker and preserves the complete prior state.
  - A no-sleep PostgreSQL blocking test proved the shared Agenda settings lock serializes creation before interval application.
- T7 evidence:
  - RED: a persisted Consultation Type disappeared after LiveView remount while the screen still used socket-local state.
  - GREEN: context suite passed 33 tests and LiveView suite passed 37 tests; parent spot-check passed the same 37 LiveView tests.
  - Compile, focused format checks, and `git diff --check` passed after one explicitly authorized trailing-whitespace cleanup; native risk remained medium.
  - Mount and every mutation now use the authenticated principal and public context, reload authoritative state, preserve UI/accessibility behavior, and isolate Professional accounts.
  - T7 contains 580 honest changed lines because existing mock-backed tests were converted with remount and isolation coverage; no tests or readability were sacrificed for the advisory heuristic.
- T8 evidence:
  - Migration RED/GREEN: missing rollback guard produced 3 failures; populated rollback refusal, complete empty rollback/re-migration, compatible grapheme rollback, and narrowing refusal now pass against isolated databases.
  - PostgreSQL security RED/GREEN: role provisioning initially left runtime/verifier bootstrap grants incomplete; configured-role provisioning now passes all 8 tagged security tests without weakening append-only audit restrictions.
  - Writer verification passed 33 context, 37 LiveView, 3 migration, 2 focused security, and 8 total tagged security tests; compile, focused format, and `git diff --check` passed.
  - Parent security spot-check was unavailable because its process lacked the three required role URLs; this does not replace the writer's configured security evidence.
  - Independent high-risk verification passed 77 focused tests and validated the one scoped correction: consistent read locking, create/update/reactivate contention coverage, and executable rollback/re-migration behavior.
  - Full suite result: 348/351 passed with 8 excluded; two existing Windows secret-file permission failures and one existing invitation expiry timing failure remain outside Issue #74.
  - Repository-wide format check remains red on unrelated baseline CRLF differences; every Issue #74 file passes focused formatting.
  - CI now discovers all tagged PostgreSQL security suites through `mix test --only postgres_security`; remote CI was not run.
  - Final implementation size is approximately 2,675 changed lines plus this ODD document, exceeding the advisory review heuristic for cohesive behavior and test coverage.
- Engram mirror: `odd/issue-74-save-consultations/tasks`.

## Next Step

Review the complete local candidate, then decide separately whether to commit, push, and open a PR.
