# Issue 77: Implement Own Professional Availability Backend

## Objective

Implement the backend persistence, authorization, validation, normalization, and sanitized audit boundary for a Professional's own regular availability configuration. The future frontend will consume this backend from `/configuracion/profesional`, but no LiveView or UI work belongs to this issue.

## Problem

The application has an owner-bound `agenda_settings` root and an agenda interval, but it does not yet persist regular weekly availability, the booking horizon, or minimum lead time. It also lacks executable authorization operations and a public backend seam for reading and atomically replacing that configuration.

## Why

A canonical backend contract is required before Issue #78 can build the editor. Ownership, temporal validation, complete-save atomicity, and audit behavior must be enforced server-side rather than delegated to the future UI.

## Authorized scope

- Local implementation on `feat/77-professional-availability-backend`.
- Database migrations and PostgreSQL capabilities required by availability persistence.
- Backend context, authorization, validation, normalization, and audit integration.
- Focused automated tests and required functional verification.
- No GitHub Issue body mutations, remote operations, frontend code, LiveView changes, slot generation, appointment occupancy, vacations, holidays, or exception scheduling.

## Confirmed product contract

- The public seam is `Origen.Availability.get_own_configuration(principal)` and `Origen.Availability.replace_own_configuration(principal, attrs)`.
- Callers never provide `owner_account_id`; ownership derives from the revalidated authenticated principal.
- One complete configuration belongs to one Professional and applies to all of that Professional's consultation types.
- The initial weekly schedule is Monday through Friday, 08:00–12:00 and 14:00–18:00.
- Multiple windows per weekday are allowed; overnight and multi-day windows are invalid.
- Boundaries must align to the current agenda interval and each window must span at least one interval.
- True overlaps are rejected. Exactly touching windows are accepted and normalized into one continuous window.
- A completely empty weekly schedule is valid.
- Booking horizon uses whole days, defaults to 30, and accepts 7 through 90 inclusive.
- Minimum lead time defaults to 30 minutes and accepts 0 through 1,440 in five-minute increments.
- Organization-local calculations use deployment configuration with initial IANA value `America/Argentina/Buenos_Aires`.
- The complete replacement is atomic; any validation error preserves the previous configuration.
- Concurrent valid saves use last-write-wins behavior.
- Existing appointments are neither queried nor modified by this issue.
- A successful replacement and its minimized audit event commit atomically.
- Audit evidence contains only actor reference, affected Professional reference, event, result, and server timestamp. It stores no schedule values or JSON snapshots.
- Validation rejection does not append a success event.

## Constraints

- Follow the repository's SQL-first context patterns and default-deny authorization model.
- Retain the existing temporary ownership convention based on `internal_accounts.id` until Professional profiles exist.
- Preserve database capability separation and immutable owner identity.
- Return normalized configuration and actionable validation errors suitable for the future frontend without introducing presentation concerns.
- Keep tests with each behavior work unit and use the approximately 400-authored-line guideline only as a review heuristic, never as a reason to omit tests or compress code.

## TDD configuration

- Mode: strict TDD.
- Source: explicitly selected by the user for Issue #77.
- Loop: observed RED → minimal GREEN for one vertical slice → REFACTOR after green.
- Primary seam: the confirmed `Origen.Availability` public API.
- Supporting seams: migration/rollback behavior, PostgreSQL capabilities, authorization decisions, and agenda-interval compatibility.
- Test runner prefix: `call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 &&` followed by the applicable `mix test` or `mix compile` command.

## Checklist

- [ ] ODD-77-01 — Add canonical owner-bound availability storage, scalar constraints, safe rollback behavior, and focused migration/capability tests.
- [x] ODD-77-02 — Implement own-configuration reads with defaults, revalidated identity, default-deny authorization, and cross-Professional isolation tests.
- [x] ODD-77-03 — Implement complete replacement with accumulated validation, overlap rejection, touching-window normalization, atomic preservation on error, and focused public-seam tests.
- [x] ODD-77-04 — Append the minimized success audit event in the configuration transaction and prove rollback plus absence of success audit on rejection.
- [x] ODD-77-05 — Prevent agenda-interval changes that would misalign persisted availability and prove serialized state preservation.
- [ ] ODD-77-06 — Run focused security/migration/context checks, compile with warnings as errors, run the full suite, and record the backend contract for Issue #78 without modifying frontend code.

## Acceptance criteria

- An active authenticated Professional can read and replace only their own availability configuration through the confirmed public seam.
- Manipulated principals, revoked sessions, inactive accounts, wrong roles, and cross-Professional access are denied without exposing configuration.
- Defaults and all accepted scalar boundaries persist correctly.
- Invalid shapes, strict overlaps, misalignment, or out-of-range values reject the whole replacement and preserve prior state.
- Touching windows persist as one deterministic canonical window.
- Empty weekly availability persists successfully.
- Successful configuration and minimized audit evidence commit or roll back together.
- Availability changes never inspect or mutate appointments.
- Existing availability prevents a future agenda-interval change that would make boundaries invalid.
- No frontend or GitHub Issue body changes are introduced.

## Applicable checks

- Focused RED/GREEN commands for each checklist item.
- `mix test test/origen/availability_test.exs`
- `mix test test/origen/availability_migration_test.exs`
- `mix test test/origen/authorization_test.exs test/origen/consultation_types_test.exs`
- `mix test --only postgres_security`
- `mix compile --warnings-as-errors`
- `mix test`
- `mix format --check-formatted` after all source-mutating formatting is complete.

## Progress and verification evidence

- [x] Issue #77, the Issue #76 ODD handoff, existing persistence, authorization, audit, and test patterns were inspected read-only.
- [x] Strict TDD and the public test seam were explicitly confirmed.
- [x] Overlap, touching-window, audit, and timezone contracts were resolved with the user.
- [x] Interrupted work was reconciled without touching this tracker or unrelated work: restored `test/origen/consultation_types_postgres_security_test.exs` to `HEAD`, deleted the interrupted untracked migration and migration test, then recreated each changed path from a clean baseline.
- [ ] ODD-77-01 migration/storage behavior is GREEN (`3 passed`), including backfill, scalar constraints, empty-week persistence, and guarded rollback. The item remains unchecked because the required PostgreSQL capability test cannot start without the repository's security database and role URLs.
- [x] ODD-77-02 completed after a second bounded correction: unauthorized resolution now returns a value from the locked Availability transaction instead of rolling it back, so canonical future/expiry revocation commits while no availability business effects run. Future-issued, future-activity, absolute-expiry, idle-expiry, revoked, inactive, wrong-role, and altered-principal behavior is GREEN. Concurrency-test resources now have failure-safe cleanup registered before creation.
- [x] ODD-77-03 completed: withheld replacement behavior, observed the public replacement seam reject valid and invalid cases as unauthorized, restored the transactional replacement, fixed the test fixture to send all seven required weekdays, and observed focused normalization/empty-week, accumulated-validation, malformed-window, preservation, and complete availability checks pass.
- [x] ODD-77-04 completed: withheld the audit append while preserving replacement, observed successful replacement produce no required event, restored only the in-transaction append, corrected an order-sensitive test assertion, and observed focused success, forced audit-failure rollback, event-schema, writer, and transaction checks pass.
- [x] ODD-77-05 completed: withheld persisted-availability blocker discovery, observed an incompatible interval succeed incorrectly, restored blocker discovery, corrected the legacy interval-boundary fixture to use an empty schedule where 240 minutes is valid, and observed the complete authorization/consultation suite pass.
- [ ] ODD-77-06 final verification ran after source-mutating formatting. Changed-file format, warnings-as-errors compilation, and all Issue #77 non-security focused tests pass. The item remains unchecked because repository-wide format detects pre-existing unrelated CRLF formatting drift, PostgreSQL security tests lack their required environment URLs, and the full suite has four reproducible unrelated bootstrap failures.
- [x] The user explicitly deferred PostgreSQL capability verification to the WSL environment that hosts the Administrator bootstrap setup. No security credentials or replacement roles will be created or probed in the current Windows environment.

### Attempted RED/GREEN receipts

All commands used this verified Windows prefix:

`cmd /d /s /c 'call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 && mix <command>'`

- ODD-77-01 RED attempt before migration implementation: `mix test test/origen/availability_migration_test.exs` — blocked before compilation/test discovery with `Unchecked dependencies for environment test` and `** (Mix) Can't continue due to errors on dependencies`.
- ODD-77-01 GREEN attempt after implementation: same command — same dependency failure; GREEN not observed.
- ODD-77-02/03/04 RED attempt before public context implementation: `mix test test/origen/availability_test.exs` — same dependency failure; RED behavior was not observed.
- ODD-77-02/03/04 GREEN/focused attempt after implementation: same command — same dependency failure; GREEN not observed.
- ODD-77-02 authorization RED attempt: `mix test test/origen/authorization_test.exs` — same dependency failure; RED behavior was not observed.
- ODD-77-05 RED attempt: `mix test test/origen/consultation_types_test.exs test/origen/authorization_test.exs` — same dependency failure; RED behavior was not observed.
- ODD-77-05 GREEN/focused attempt: `mix test test/origen/authorization_test.exs test/origen/consultation_types_test.exs` — same dependency failure; GREEN not observed.
- Audit focused attempt: `mix test test/origen/audit/events_test.exs test/origen/audit/writer_test.exs test/origen/audit/transaction_test.exs` — same dependency failure.
- PostgreSQL capability attempt: `mix test --only postgres_security` — same dependency failure.
- Source-mutating format attempt: `mix format <changed Elixir files>` — blocked with `Unknown dependency :ecto_sql given to :import_deps in the formatter configuration`.
- Final `mix format --check-formatted` — blocked by the same missing `:ecto_sql` formatter dependency.
- Final `mix compile --warnings-as-errors` — blocked by unfetched development dependencies.
- Final `mix test` — blocked by unfetched test dependencies.
- Supplemental non-Mix syntax parse: `Code.string_to_quoted!/2` parsed every changed `.ex`/`.exs` and config file successfully after correcting two test syntax errors. This is not a substitute for compilation or GREEN.
- `git diff --check` completed without whitespace errors; line-ending conversion warnings were informational.

### Resumed strict-TDD receipts after dependency installation

- ODD-77-01 canonical-default RED: temporarily changed the migration booking-horizon default from 30 to 31, then ran `mix test test/origen/availability_migration_test.exs:46`; observed `0/1 passed` with persisted `31` versus expected `30`.
- ODD-77-01 canonical-default GREEN: restored only the default to 30 and reran the same command; observed `1 passed, 2 excluded`. `mix test test/origen/availability_migration_test.exs` then observed `3 passed`. ODD-77-01 remains unchecked because its required PostgreSQL capability test is environmentally unavailable without `ORIGEN_DATABASE_URL` and security-role URLs.
- ODD-77-02 read RED: temporarily withheld the valid `get_own_configuration/1` behavior and ran `mix test test/origen/availability_test.exs:9`; observed `0/1 passed`, expected `{:ok, configuration}` but received `{:error, :unauthorized}`.
- ODD-77-02 read GREEN: restored only the persisted read transaction and reran the same command; after refreshing the test migration from the intentional ODD-77-01 RED state, observed `1 passed, 6 excluded`.
- ODD-77-02 focused authorization/read check: `mix test test/origen/availability_test.exs:21 test/origen/authorization_test.exs` first exposed an invalid inactive-account fixture (`internal_accounts_state_fields_check`). After clearing activation credentials with the state transition, the same command observed `10 passed, 6 excluded`.
- ODD-77-03 replacement RED: temporarily withheld valid `replace_own_configuration/2` behavior and ran `mix test test/origen/availability_test.exs:47`; observed `0/5 passed`, with every replacement behavior receiving `{:error, :unauthorized}`.
- ODD-77-03 replacement GREEN: restored only the transactional replacement. The first focused run exposed that the valid test supplied only Monday rather than a complete seven-day replacement; after correcting that fixture, `mix test test/origen/availability_test.exs:48` observed `1 passed, 6 excluded`. Focused validation commands at lines 68 and 90 each observed `1 passed, 6 excluded`, and `mix test test/origen/availability_test.exs` observed `7 passed`.
- ODD-77-04 audit RED: temporarily withheld `append_audit!/1` from successful replacement and ran `mix test test/origen/availability_test.exs:109`; observed `0/1 passed`, expected one minimized event but queried `[]`.
- ODD-77-04 audit GREEN: restored only the append and ran the focused availability audit/rollback plus audit suites. The first run exposed an order-sensitive key-list assertion; after comparing both sides in sorted order, `mix test test/origen/availability_test.exs:109 test/origen/availability_test.exs:123 test/origen/audit/events_test.exs test/origen/audit/writer_test.exs test/origen/audit/transaction_test.exs` observed `15 passed, 5 excluded`.
- ODD-77-05 compatibility RED: temporarily replaced persisted availability blocker discovery with an empty blocker list and ran `mix test test/origen/consultation_types_test.exs:753`; observed `0/1 passed`, expected incompatibility for `monday 08:30` but received a successful interval change to 60.
- ODD-77-05 compatibility GREEN: restored blocker discovery and reran the same command; observed `1 passed, 36 excluded`. The full focused authorization/consultation command first exposed a legacy test expecting 240-minute compatibility with the non-aligned default schedule; after arranging an empty schedule through the public seam, `mix test test/origen/authorization_test.exs test/origen/consultation_types_test.exs` observed `46 passed`.
- Post-format focused verification: `mix test test/origen/availability_migration_test.exs` observed `3 passed`; the combined availability, authorization, consultation, and audit command observed `66 passed`.
- PostgreSQL capability verification: `mix test --only postgres_security test/origen/consultation_types_postgres_security_test.exs` observed `0 tests, 2 invalid`; setup requires `ORIGEN_DATABASE_URL`, `ORIGEN_MIGRATION_DATABASE_URL`, and `ORIGEN_SECURITY_DATABASE_URL`.
- Source-mutating formatting: `mix format` ran successfully over every Issue #77 changed artifact before final checks; a second `mix format lib/origen/availability.ex` ran after removing the compiler-reported redundant clause.
- Changed-file format check: `mix format --check-formatted <all Issue #77 changed artifacts>` passed.
- Repository-wide format check: `mix format --check-formatted` failed on unrelated pre-existing files and CRLF drift, including bootstrap, telemetry, support, production config, and frontend/template files. Those files were not modified because they are outside Issue #77 and include explicitly forbidden frontend scope.
- Compilation: `mix compile --warnings-as-errors` succeeded and generated the application. Phoenix LiveView emitted a non-fatal Windows symlink warning (`:eperm`).
- Full suite: `mix test` observed `421/425 passed, 8 excluded, 4 failed`. Reproduction kept two Windows local-secret permission failures in `bootstrap_admin/local/secrets_test.exs` (`3/5 passed`) and two bootstrap expiry failures in `coverage_remediation_test.exs` plus `lifecycle_test.exs` (`21/23 passed`). No Issue #77 focused test failed.
- Dependency follow-up outside Issue #77: the authorized installer reported three `mint 1.9.3` advisories, including one HIGH. Issue #77 did not change dependencies, and no required check showed that this implementation introduced or activated the risk.
- Final `git diff --check` passed with informational CRLF conversion warnings.

### Independent verification correction

- ODD-77-02 was reopened before correction because the new Availability SQL accepted future-dated persisted session timestamps while canonical token validation rejected negative elapsed time.
- Regression RED: added one public-seam test covering both future `issued_at` and future `last_activity_at`, then ran `mix test test/origen/availability_test.exs:47`; observed `0/1 passed`, with `get_own_configuration/1` returning `{:ok, configuration}` instead of `{:error, :unauthorized}`.
- Root fix: extracted canonical persisted-session temporal/state validation inside `Origen.Sessions`, added principal revalidation by persisted session/account identity, and replaced Availability's divergent SQL validity copy with that shared seam.
- Regression GREEN: reran `mix test test/origen/availability_test.exs:47`; observed `1 passed, 7 excluded`.
- Deterministic concurrency proof: added a public-seam test using PostgreSQL advisory locks, a scoped update trigger, `pg_blocking_pids/1`, and separate sandbox connections—without sleeps. It proves the second valid replacement waits behind the first and becomes the complete persisted configuration. `mix test test/origen/availability_test.exs:229` observed `1 passed, 8 excluded`; after formatting, the combined regression/concurrency command observed `3 passed, 6 excluded`.
- Focused Availability/Authorization/Sessions GREEN: `mix test test/origen/availability_test.exs test/origen/authorization_test.exs test/origen/sessions_test.exs` observed `32 passed` both before and after formatting.
- Source-mutating correction format: `mix format lib/origen/sessions.ex lib/origen/availability.ex test/origen/availability_test.exs odd/tasks/issue-77-professional-availability-backend.md` succeeded before final focused verification.
- Changed-file format check passed; `mix compile --warnings-as-errors` succeeded with only the known non-fatal Phoenix LiveView Windows symlink warning.
- Complete Issue #77 non-security focused verification observed `85 passed`.
- `git diff --check` passed with informational CRLF conversion warnings.

### Second bounded correction

- Persisted-revocation RED: extended the public-seam regression to assert both immediate denial and non-null persisted `revoked_at` for future `issued_at`, future `last_activity_at`, absolute expiry, and idle expiry. `mix test test/origen/availability_test.exs:47` observed `0/1 passed`: denial succeeded, but `revoked_at` remained null.
- Transaction-boundary fix: Availability keeps canonical `Sessions.revalidate_principal/3` under the business transaction's row locks, but unauthorized resolution now returns `{:error, :unauthorized}` as the transaction value. Ecto commits canonical revocation and performs no settings/audit work; validation and audit failures still use rollback for business atomicity.
- Persisted-revocation GREEN: rerunning `mix test test/origen/availability_test.exs:47` observed `1 passed, 8 excluded` for all four temporal cases.
- Failure-safe concurrency cleanup: blocker identity is allocated and captured by `on_exit` before function/trigger creation. Cleanup always uses `DROP ... IF EXISTS`, and successful explicit cleanup asserts both `to_regprocedure` and trigger lookup are null. The real advisory-lock plus `pg_blocking_pids/1` ordering proof remains unchanged and uses no sleeps.
- Focused concurrency check before formatting observed `2 passed, 7 excluded`; after source-mutating formatting, the combined temporal-regression/concurrency command observed `3 passed, 6 excluded`.
- Post-format Availability/Sessions/Authorization verification observed `32 passed`; complete Issue #77 non-security focused verification observed `85 passed`.
- `mix compile --warnings-as-errors` succeeded with only the known non-fatal Phoenix LiveView Windows symlink warning.

## Next step

In the explicitly authorized WSL bootstrap environment, provide the existing separated PostgreSQL security-test URLs/roles and rerun the capability check without exposing credentials. Separately resolve the pre-existing repository-wide CRLF formatting drift and four bootstrap baseline failures outside Issue #77; only then rerun repository-wide format and the full suite before checking ODD-77-01 and ODD-77-06.
