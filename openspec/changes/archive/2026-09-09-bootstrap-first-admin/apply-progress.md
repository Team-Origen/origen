# Apply Progress: Bootstrap the First Administrator

## Current Apply Status

- Structured status consumed: change `bootstrap-first-admin`, `applyState: ready`.
- Action context: `repo-local`; workspace and all edited files are within `/Users/luccagiordana/Documents/proyectoOrigen/origen`; no warnings.
- Current implementation-owned task progress: 14/15 complete. Tasks 1.1–4.2 and all earlier remediation tasks remain complete.
- Remaining tasks: task 5.1 is the sole remaining task.
- Remediation status: maintainer-authorized but not started; it remediates failed evidence revision `sha256:83c54ae2a58aa6cca0e9cd71be1d170d7989f94bf3a69f71b226484017011303`.
- Delivery: auto-chain using feature-branch-chain; review budget 800 changed lines.

## Work Unit

- Delivery: auto-chain, stacked-to-main, PR 1 foundation
- Bounded unit: `bootstrap-domain-primitives`
- Scope: gate, verifier, credentials, redaction, tagged Cloak primitive, authorization facts, and typed audit constructors
- Status: partial — later lifecycle, delivery, verification, and documentation tasks remain

## Completed Tasks

- [x] 1.1 Validate the approved dependency declarations with dependency resolution and warnings-as-errors compilation.
- [x] 1.2 RED: add migration and database security tests.
- [x] 1.3 GREEN: create the first-admin bootstrap migration.
- [x] 2.1 RED: add primitive and security-boundary tests.
- [x] 2.2 GREEN: implement domain primitives and fail-closed key validation.
- [x] 2.3 RED then GREEN: add explicit authorization facts and typed audit constructors.
- [x] 3.1 RED: test invitation lifecycle uniqueness, expiry, consumption, reissue, concurrency, and rollback.
- [x] 3.2 GREEN: implement locked invitation lifecycle and atomic credential activation.
- [x] 3.3–4.2 Delivery, web, verification, and documentation tasks were completed by subsequent work units.

## Focused Remediation

- Bounded work unit: `jorge-pr9-security-remediation`
- Scope: string-key redaction compatibility, serialized populated-history rollback inspection, and least-privilege verifier projection.
- Status: implemented; independent verification remains required.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Redaction string-key compatibility | `test/origen/bootstrap_admin/primitives_test.exs` | Unit | ✅ 8 focused tests passed before changes | ✅ Written; failed with `:unapproved_field` | ✅ Focused test passed | ✅ Atom keys, string keys, unknown and sensitive keys covered | ✅ Normalized only for validation; original map returned |
| Serialized rollback guard | `test/origen/bootstrap_admin_test.exs` | Integration/SQL contract | ✅ Existing focused suite passed before changes | ✅ Written; lock assertion failed | ✅ Focused test passed | ✅ Lock covers all three bootstrap tables and uses `ACCESS EXCLUSIVE` | ✅ Lock remains held by migration transaction through drops |
| Verifier least-privilege projection | `test/origen/audit/postgres_security_test.exs` | PostgreSQL security harness | ✅ Harness excluded without role URLs | ✅ Written; unavailable locally without harness | ➖ Pending provisioned-role harness | ✅ Projection column allowlist asserted | ➖ Requires provisioned database |

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin/primitives_test.exs test/origen/bootstrap_admin_test.exs test/origen/audit/postgres_security_test.exs` — passed: 10 tests, 0 failures, 6 excluded. |
| Runtime harness command/scenario and exact result | `mix test --include postgres_security test/origen/audit/postgres_security_test.exs` — 1 migration capability test passed; 5 security tests invalidated because `ORIGEN_DATABASE_URL` was not set. |
| Rollback boundary | Revert the focused changes in `lib/origen/bootstrap_admin/redaction.ex`, `priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs`, and their three regression test files; no lifecycle, web, Mix task, dependency, or unrelated policy changes. |

### Remediation Verification

- `mix format --check-formatted` — passed.
- `mix compile --warnings-as-errors` — passed.
- Full `mix test` — existing audit tests failed because the local `audit_events` database was already populated; no remediation test failed.

## Evidence

### Safety Net

`mix test` — passed before modifying `mix.exs`: 31 passed, 4 excluded.

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin_test.exs` — passed: 3 tests, 0 failures. Full `mix test` — passed: 34 tests, 5 excluded. |
| Runtime harness command/scenario and exact result | `mix test test/origen/audit/postgres_security_test.exs --include postgres_security` — bounded: 1 migration-repo test passed; 4 security tests invalidated because `ORIGEN_DATABASE_URL` was not set. CI harness requires runtime, migration, and verifier URLs plus provisioned roles. |
| Rollback boundary | Revert `priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs`, `test/origen/bootstrap_admin_test.exs`, and the added security assertions in `test/origen/audit/postgres_security_test.exs`; retain prior dependency and audit changes. |

### Domain Primitive Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin/primitives_test.exs test/origen/bootstrap_admin/authorization_audit_test.exs` — passed: 7 tests, 0 failures. |
| Runtime harness command/scenario and exact result | N/A — pure domain primitives and typed constructors have no deployed runtime boundary; lifecycle/runtime harness belongs to later tasks. |
| Rollback boundary | Revert `lib/origen/bootstrap_admin/`, `config/config.exs`, the added primitive tests, and scoped changes in `lib/origen/authorization/rules.ex` and `lib/origen/audit/events.ex`; retain migration and dependency work. |

`mix format --check-formatted` — passed. `mix compile --warnings-as-errors` — passed.

### Dependency Resolution

`mix deps.get` — passed. Resolved and fetched:

- `argon2_elixir 4.1.3`
- `nimble_totp 1.0.0`
- `cloak 1.1.4`
- `cloak_ecto 1.3.0`
- transitive `comeonin 5.5.1`

### Compilation

`mix compile --warnings-as-errors` — passed and generated the Origen application. Upstream dependency warnings were emitted by `nimble_totp`, `cloak`, and `cloak_ecto`; no workaround or substitution was introduced.

## TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1.1 | N/A — dependency declaration only | Structural/toolchain | ✅ 31 passed, 4 excluded | N/A — no executable behavior and tests explicitly out of scope | ✅ `mix compile --warnings-as-errors` passed | ➖ Skipped: purely structural declaration with one dependency graph outcome | ➖ None needed |
| 1.2 | `test/origen/bootstrap_admin_test.exs`, `test/origen/audit/postgres_security_test.exs` | Integration | ✅ 31 passed, 4 excluded | ✅ Written; 0/3 schema tests passed because tables were absent | ✅ 3/3 focused tests passed | ✅ schema, uniqueness, rollback, and grant cases added | ✅ formatted and full suite passed |
| 1.3 | `priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs` | Integration | ✅ 3/3 RED tests | ✅ Existing 1.2 tests preceded migration | ✅ 3/3 focused tests passed; 34/34 full tests passed | ✅ alternate table and populated-history paths exercised | ✅ migration formatted and compile passed |
| 2.1 | `test/origen/bootstrap_admin/primitives_test.exs` | Unit | N/A (new) | ✅ Written; 0/4 passed before modules | ✅ 4/4 primitive behaviors passed | ✅ 5 cases, including malformed keyring and string secret field | ✅ formatted and focused suite passed |
| 2.2 | `test/origen/bootstrap_admin/primitives_test.exs` | Unit | N/A (new) | ✅ 2.1 RED preceded implementation | ✅ 5/5 primitive tests passed | ✅ alternate keyring and production/malformed gate paths exercised | ✅ focused suite and compile passed |
| 2.3 | `test/origen/bootstrap_admin/authorization_audit_test.exs` | Unit | N/A (new) | ✅ Written; typed constructors initially undefined | ✅ 2/2 authorization/audit tests passed | ✅ default-deny unknown fact and secret-like reference paths exercised | ✅ formatted and focused suite passed |

### Test Summary

- Total tests written: 4 focused schema/security assertions plus 9 domain primitive assertions
- Total tests passing: 7 domain primitive tests; prior migration evidence retained above
- Layers used: Unit (domain primitives, authorization, typed audit constructors)
- Approval tests: None
- Pure functions created: 0

## Files Changed

- `mix.exs` — added the four approved direct dependencies.
- `mix.lock` — recorded the four direct packages and `comeonin` transitive dependency.
- `openspec/changes/bootstrap-first-admin/tasks.md` — marked only task 1.1 complete and recorded `stacked-to-main`.
- `config/config.exs` — established the false default bootstrap gate.
- `lib/origen/bootstrap_admin/{gate,verifier,credentials,redaction,vault}.ex` — added fail-closed primitives, CSPRNG/HMAC verifier, Argon2id and Cloak seed operations, redaction boundary, and Vault seam.
- `lib/origen/authorization/rules.ex` and `lib/origen/audit/events.ex` — added explicit bootstrap operation exposure, typed lifecycle constructors, and token-like reference rejection.
- `test/origen/bootstrap_admin/{primitives,authorization_audit}_test.exs` — added strict RED/GREEN unit coverage.
- `priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs` — created durable tables, constraints, partial unique index, role grants, and populated down guard.
- `test/origen/bootstrap_admin_test.exs` — added RED/GREEN schema, uniqueness, and rollback protection tests.
- `test/origen/audit/postgres_security_test.exs` — added runtime least-privilege assertions for bootstrap tables.
- `openspec/changes/bootstrap-first-admin/tasks.md` — marked only tasks 1.1–1.3 complete.

## Deviations and Issues

- No lifecycle/domain modules, Mix task, runtime gate, routes, or authentication workflow were added.
- The security harness could not authenticate without its declared PostgreSQL role URLs; no substitute harness was introduced.

## Remaining Tasks

- [x] 1.2 RED: add migration and database security tests.
- [x] 1.3 GREEN: create the first-admin bootstrap migration.
- [x] 3.1 RED: test invitation lifecycle uniqueness, expiry, consumption, reissue, and rollback.
- [x] 3.2 GREEN: implement locked invitation lifecycle and atomic credential activation.
- [x] 3.3–4.2 Delivery, web, verification, and documentation tasks were completed by subsequent work units.

## Invitation Lifecycle Work Unit

- Delivery: auto-chain, stacked-to-main; current child targets `feat/3-bootstrap-admin`
- Bounded unit: `invitation-lifecycle`
- Scope: first-admin issue, reissue revocation, locked consume/activation, credential persistence ordering, and required audit rollback
- Status: complete; web delivery, Mix delivery boundary, verification, and documentation remain pending

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3.1 | `test/origen/bootstrap_admin/lifecycle_test.exs` | Integration | N/A (new) | ✅ Written; lifecycle API initially undefined | ✅ 7/7 focused tests passed | ✅ issue/repeat, concurrent issue, reissue/replay/expiry, activation/replay, and audit rollback cases | ✅ Formatted and lock/transaction paths retained |
| 3.2 | `test/origen/bootstrap_admin/lifecycle_test.exs` | Integration | ✅ 12 prior focused tests passed | ✅ RED preceded lifecycle implementation | ✅ 7/7 lifecycle tests; 19/19 cumulative focused tests passed | ✅ active-account denial, revoked predecessor, invalid/expired state, and audit failure paths | ✅ `mix format --check-formatted` and warnings-as-errors compile passed |

### Test Summary

- Total tests written: 7 lifecycle integration tests
- Total tests passing: 19 focused tests, 0 failures
- Layers used: Integration (SQL sandbox and PostgreSQL constraints)
- Approval tests: None — new lifecycle behavior
- Pure functions created: 0

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin/lifecycle_test.exs test/origen/bootstrap_admin_test.exs test/origen/bootstrap_admin/primitives_test.exs test/origen/bootstrap_admin/authorization_audit_test.exs` — passed: 19 tests, 0 failures. |
| Runtime harness command/scenario and exact result | Same focused command exercises the SQL sandbox integration boundary, including database locks, concurrent issue serialization, partial uniqueness, credential activation, and audit-trigger rollback — passed: 19 tests, 0 failures. No web/runtime server boundary belongs to this unit. |
| Rollback boundary | Revert `lib/origen/bootstrap_admin.ex`, the `invitation_consumed/2` constructor in `lib/origen/audit/events.ex`, and `test/origen/bootstrap_admin/lifecycle_test.exs`; retain foundation migration, primitives, authorization, and prior audit changes. |

### Changed Files and Review Budget

- `lib/origen/bootstrap_admin.ex` — added transactional account/invitation issue, reissue, consume, and activation operations.
- `lib/origen/audit/events.ex` — added sanitized invitation-consumption event constructor.
- `test/origen/bootstrap_admin/lifecycle_test.exs` — added RED/GREEN integration coverage for lifecycle and rollback guarantees.
- Authored changed lines: 394 additions, 0 deletions; within the 400-line stacked-PR slice budget.

### Deviations

- Corrected in the focused remediation below: lifecycle behavior now resides in the declared `account`, `invitation`, and `delivery` modules, with `BootstrapAdmin` retained as the public facade. Delivery remains limited to lifecycle persistence; mail/task delivery remains reserved for task 3.3.

## Focused Conformance Remediation

- Scope: correct the task 3.2 module-boundary deviation only; later work units remain pending.
- Status: implemented; independent SDD verification remains required.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.2 conformance correction | `test/origen/bootstrap_admin/lifecycle_test.exs` | Integration/structural contract | ✅ 7 lifecycle tests passed before changes | ✅ Boundary test written; declared modules were absent | ✅ Focused lifecycle suite passed: 8/8 | ✅ Existing lifecycle behavior plus all three module exports | ✅ Formatted facade and separated account/invitation/delivery responsibilities |

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin/lifecycle_test.exs test/origen/bootstrap_admin_test.exs test/origen/bootstrap_admin/primitives_test.exs test/origen/bootstrap_admin/authorization_audit_test.exs` — passed: 20 tests, 0 failures. |
| Runtime harness command/scenario and exact result | Same focused SQL-sandbox integration command — passed: 20 tests, 0 failures; no web/runtime server boundary belongs to this slice. |
| Rollback boundary | Revert `lib/origen/bootstrap_admin.ex`, `lib/origen/bootstrap_admin/{account,invitation,delivery}.ex`, and the module-boundary assertion in `test/origen/bootstrap_admin/lifecycle_test.exs`; retain foundation and prior lifecycle behavior only if reverting this correction is intentionally approved. |

### Settlement Evidence

- Source files changed: 4 lifecycle source files; 263 resulting source lines. The relocation necessarily produces 530 source diff lines (263 additions plus 267 deletions) against the prior centralized 267-line module, so the 120-line correction budget is genuinely impossible while satisfying all three required module boundaries without deleting required behavior.
- Cleanup: no external resources acquired; no database or repository cleanup required beyond the existing test sandbox setup.
- Rollback: the exact source/test boundary is the one listed above; OpenSpec artifacts remain untracked.

## Authorized PR #10 Remediation

- Delivery: auto-chain, stacked-to-main; current work unit `invitation-lifecycle-safety-remediation`.
- Scope: verifier-key boundary validation and PostgreSQL reissue/activation lock-order correction only.
- Status: complete; tasks 3.3–4.2 remain pending.

### Completed Tasks

- [x] Reject 31-byte verifier keys in `issue_first/1` and `reissue_first/2` before transaction or persistence, returning `{:error, :invalid_verifier_key}`.
- [x] Standardize activation to lock the account before the invitation, matching reissue; add concurrent no-`40P01` regression coverage.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Verifier-key boundary | `test/origen/bootstrap_admin/lifecycle_test.exs` | Integration | ✅ 8/8 lifecycle tests passed | ✅ 2 tests failed with persistence/return mismatch | ✅ 11/11 lifecycle tests passed | ✅ issue and reissue paths; 31-byte key and valid-key setup | ✅ shared guard boundary; no transaction entered for short keys |
| Lock-order correction | `test/origen/bootstrap_admin/lifecycle_test.exs` | Integration | ✅ 8/8 lifecycle tests passed | ✅ concurrency test added before lock-order change | ✅ 11/11 lifecycle tests passed | ✅ 16 concurrent reissue/activation attempts exercised | ✅ activation now account-then-invitation, matching reissue |

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin/lifecycle_test.exs test/origen/bootstrap_admin_test.exs test/origen/bootstrap_admin/primitives_test.exs test/origen/bootstrap_admin/authorization_audit_test.exs` — passed: 23 tests, 0 failures. |
| Runtime harness command/scenario and exact result | Same SQL-sandbox integration command — passed: 23 tests, 0 failures; the concurrency regression ran 16 simultaneous reissue/activation operations and observed no `40P01` or `deadlock_detected`. |
| Deterministic deadlock harness | Not available: the current SQL Sandbox architecture does not expose independent blocked sessions or an in-transaction synchronization barrier. The added concurrent regression is bounded evidence, not a deterministic interleaving proof. |
| Rollback boundary | Revert `lib/origen/bootstrap_admin/account.ex`, `lib/origen/bootstrap_admin/invitation.ex`, and the added remediation tests/sections in `test/origen/bootstrap_admin/lifecycle_test.exs`, `openspec/changes/bootstrap-first-admin/tasks.md`, and `openspec/changes/bootstrap-first-admin/apply-progress.md`; retain all prior lifecycle work. |

### Evidence

- `mix format --check-formatted` — passed.
- `mix compile --warnings-as-errors` — passed.

## Bootstrap Delivery Work Unit

- Delivery: auto-chain, stacked-to-main; parent branch `feat/3-admin-invitation-lifecycle`
- Bounded unit: `bootstrap-delivery`
- Scope: shared fail-closed Mix/runtime gate, reference-only command output, and local/test invitation mail delivery.
- Status: complete; task 3.4 and Phase 4 remain pending.

### Completed Tasks

- [x] 3.3 RED then GREEN: create the bootstrap Mix task, configure the runtime/test gate and mailbox, and prove gate denial plus sanitized reference/token delivery.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.3 | `test/origen/bootstrap_admin_task_test.exs` | Integration/unit boundary | ✅ Existing schema suite: 4/4 passed | ✅ Task module and delivery API were absent; 0/2 passed | ✅ Focused task suite: 2/2 passed | ✅ Closed-gate task path and non-empty mail/reference path exercised; sensitive-field allowlist assertions included | ✅ Gate checked before parsing/I/O; task supports issue and reissue without exposing credentials or digests |

### Test Summary

- Total tests written: 2
- Total tests passing: 2 focused; 23 cumulative bootstrap tests passing
- Layers used: Unit (email construction), Integration (Mix task and Swoosh test adapter)
- Approval tests: None — no refactoring task
- Pure functions created: 1 (`build_invitation_email/1`)

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin_task_test.exs test/origen/bootstrap_admin/primitives_test.exs test/origen/bootstrap_admin/lifecycle_test.exs test/origen/bootstrap_admin_test.exs` — passed: 23 tests, 0 failures. |
| Runtime harness command/scenario and exact result | `MIX_ENV=test mix origen.bootstrap_admin` with the default false gate — exited successfully and printed only `Bootstrap admin is disabled`; no repository access or secret/config parsing occurred. |
| Rollback boundary | Revert `lib/mix/tasks/origen.bootstrap_admin.ex`, `test/origen/bootstrap_admin_task_test.exs`, and the bootstrap gate/mail settings in `config/runtime.exs` and `config/test.exs`; retain all lifecycle, policy, migration, and primitive work. |

### Evidence and Process

- `mix format --check-formatted` — passed.
- `mix compile --warnings-as-errors` — passed.
- Diagnosis: no implementation or infrastructure failures remained after the RED test; the initial GREEN assertion mismatch was corrected to capture Mix shell stderr and match the formatted email labels.
- Harness disposition: local/test mailbox harness passed; production mail transport and TLS web activation remain task 3.4/Phase 4 scope.
- Cleanup evidence: no external resources acquired; Swoosh test delivery was process-local and the existing SQL sandbox was not mutated by this work unit.
- Process evidence: no commit, push, PR, or review operation was performed.

## Authorized Corrective Rerun: Task 3.3 Delivery Redaction

- Delivery: auto-chain, stacked-to-main; review budget 800.
- Bounded unit: `bootstrap-delivery-token-redaction-correction`.
- Scope: remove raw invitation-token emission from the task email while preserving the shared gate, non-production behavior, reference fields, and opaque token input handling.
- Status: complete; task 3.3 remains complete and task 3.4/Phase 4 remain pending.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.3 corrective rerun | `test/origen/bootstrap_admin_task_test.exs` | Integration/unit boundary | ✅ 2/2 focused tests passed before changes | ✅ Changed token assertion to `refute`; 1/2 passed and 1/2 failed on raw token output | ✅ 2/2 passed after removing URL/token interpolation | ✅ Added alternate references and token-like input; 3/3 passed | ✅ Removed unused activation URL construction; preserved opaque token input as ignored `_token` |

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/bootstrap_admin_task_test.exs` — passed: 3 tests, 0 failures. |
| Runtime harness command/scenario and exact result | `MIX_ENV=test mix origen.bootstrap_admin` with the default false gate — exited successfully and printed only `Bootstrap admin is disabled`; no repository access or secret/config parsing occurred. |
| Rollback boundary | Revert `lib/mix/tasks/origen.bootstrap_admin.ex` and `test/origen/bootstrap_admin_task_test.exs` to the pre-rerun versions; retain all lifecycle, policy, migration, primitive, and unrelated task-3.3 gate/config work. |

### Evidence and Process

- Exact focused result: `mix test test/origen/bootstrap_admin_task_test.exs` — 3 passed, 0 failures.
- Format result: `mix format --check-formatted` — passed.
- Compile result: `mix compile --warnings-as-errors` — passed.
- Diagnosis: the email builder interpolated the raw invitation token into a fragment URL; the correction removes URL construction and token interpolation while retaining reference-only content.
- Harness disposition: local/test mailbox delivery remains available and focused assertions pass; production mail transport and TLS web activation remain task 3.4/Phase 4 scope.
- Cleanup evidence: no external resources acquired; Swoosh test delivery was process-local and no database state was changed.
- Process evidence: no delegation, commit, push, PR, or review operation was performed.

## Admin Activation Web Work Unit

- Delivery: auto-chain, stacked-to-main; parent branch `feat/3-bootstrap-delivery`, head `feat/3-admin-activation`, review budget 800 lines.
- Bounded unit: `admin-activation-web`.
- Scope: TLS-only fragment exchange, CSRF, clean redirect, short server-side session binding, one-time TOTP payload, encrypted factor persistence, and replay denial.
- Status: complete; Phase 4 tasks 4.1 and 4.2 remain pending.

### Completed Tasks

- [x] 3.4 RED then GREEN: add the admin activation controller/HTML/routes and prove TLS, fragment exchange, CSRF, clean redirect, expiry, invalid input/TOTP, valid TOTP, and replay behavior.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.4 | `test/origen_web/controllers/admin_activation_controller_test.exs` | Phoenix/PostgreSQL integration | ✅ Existing lifecycle and page suites passed: 12 tests | ✅ New web module/routes absent: 0/8 passed; malformed TTL and non-binary invitation ID later produced focused RED failures | ✅ Final focused web suite: 9/9 passed | ✅ TLS denial, fragment history cleanup, CSRF denial/acceptance, invalid token/config/input/TOTP, bound session, expiry, valid activation, and replay covered | ✅ Shared activation persistence extracted, formatter passed, and cumulative focused regressions remained 28/28 green |

### Test Summary

- Total tests written: 9 Phoenix controller integration tests.
- Total tests passing: 9 focused web tests; 28 cumulative web/domain tests; 11 lifecycle regressions.
- Layers used: Integration (Phoenix endpoint, Plug session/CSRF, SQL sandbox, PostgreSQL lifecycle).
- Approval tests: None — new web behavior with a bounded lifecycle refactor protected by existing tests.
- Pure functions created: 2 validation helpers (`parse_invitation_id/1` and credential construction).

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen_web/controllers/admin_activation_controller_test.exs` — passed: 9 tests, 0 failures. `mix test test/origen/bootstrap_admin/lifecycle_test.exs` — passed: 11 tests, 0 failures. Cumulative focused command over web, lifecycle, primitives, and authorization/audit tests — passed: 28 tests, 0 failures. |
| Runtime harness command/scenario and exact result | `mix test test/origen_web/controllers/admin_activation_controller_test.exs --only runtime_harness --trace` — passed: 6 tests, 0 failures, 3 excluded. The real Phoenix endpoint/Plug/SQL-sandbox path proved HTTP denial, fragment removal before POST, actual CSRF rejection and acceptance, clean redirect, session binding/one-time rendering, deterministic expiry, valid TOTP activation, encrypted seed/password persistence, and replay denial. |
| Rollback boundary | Revert `config/config.exs`, `lib/origen/application.ex`, `lib/origen/bootstrap_admin.ex`, the task-3.4 additions/refactor in `lib/origen/bootstrap_admin/invitation.ex`, `lib/origen_web/router.ex`, `lib/origen_web/controllers/admin_activation_{controller,html}.ex`, and `test/origen_web/controllers/admin_activation_controller_test.exs`; retain prior lifecycle, delivery, migration, policy, and audit history. |

### Evidence and Process

- `mix format --check-formatted` — passed with no output.
- `mix compile --warnings-as-errors` — passed; compiled 12 files and generated the Origen application.
- `git diff --check` — passed with no output.
- Authored implementation/test changed lines: 800 total (778 additions, 22 deletions), exactly within the 800-line web-slice budget; pre-existing untracked OpenSpec evidence files are outside the intended PR diff.
- Diagnosis: the initial RED established missing routes/modules; GREEN exposed ConnTest HTTPS construction and generated-input requirements, while triangulation found malformed session TTL and invitation-ID crash paths plus an incomplete sensitive-parameter filter. All were corrected fail closed without weakening CSRF or lifecycle transactions.
- Harness disposition: deterministic Phoenix integration harness passed locally; no E2E runner is configured, and external ingress/APM/TLS termination remains Phase 4 deployment verification/documentation scope.
- Cleanup evidence: no external resources were acquired; the supervised in-memory activation session store was cleared by tests and database changes were isolated by the SQL sandbox.
- Process evidence: sole-writer implementation only; no delegation, commit, push, PR creation/edit, or review start occurred.

### Remaining Tasks

- [x] 4.1 Run the full format, compile, test, and coverage verification suite and record final harness evidence.
- [x] 4.2 Update context, sprint, security, and deployment documentation.

## Admin Activation Web Recovery Continuation

- Delivery: auto-chain, stacked-to-main; bounded child slice `feat/3-admin-activation`, review budget 800 lines.
- Scope: validate and recover only task 3.4 (`admin-activation-web`) without discarding or broadly rewriting the existing implementation.
- Status: complete; task 4.1 and task 4.2 remain pending.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.4 recovery validation | `test/origen_web/controllers/admin_activation_controller_test.exs` | Phoenix/PostgreSQL integration | ✅ Focused existing suite passed: 9 tests, 0 failures before any edit | ✅ Prior task-3.4 RED evidence retained; no production change was needed during recovery | ✅ Focused suite passed: 9 tests, 0 failures | ✅ Existing nine cases cover TLS, fragment cleanup, CSRF, session binding/expiry, invalid input/TOTP, valid activation, and replay | ➖ No refactor or production repair was needed; format and warnings-as-errors compile passed |

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen_web/controllers/admin_activation_controller_test.exs` — passed: 9 tests, 0 failures. |
| Runtime harness command/scenario and exact result | `mix test test/origen_web/controllers/admin_activation_controller_test.exs --only runtime_harness --trace` — passed: 6 tests, 0 failures, 3 excluded. The Phoenix endpoint/Plug/SQL-sandbox path exercised non-TLS denial, fragment exchange CSRF rejection and acceptance, clean redirect, one-time enrollment rendering, expiry, valid TOTP activation, encrypted credential persistence, and replay denial. |
| Rollback boundary | Revert the task-3.4 changes in `config/config.exs`, `lib/origen/application.ex`, `lib/origen/bootstrap_admin.ex`, `lib/origen/bootstrap_admin/invitation.ex`, `lib/origen_web/router.ex`, `lib/origen_web/controllers/admin_activation_{controller,html}.ex`, and `test/origen_web/controllers/admin_activation_controller_test.exs`; retain prior lifecycle, delivery, migration, policy, and audit history. |

### Evidence and Process

- `mix format --check-formatted` — passed with exit 0 and no output.
- `mix compile --warnings-as-errors` — passed with exit 0 and no output.
- `git diff --check` — passed with exit 0 and no output.
- Authored implementation/test diff: 778 additions and 22 deletions, 800 changed lines total; within the authorized 800-line slice budget.
- Harness disposition: passed. No E2E runner is configured; external ingress, TLS termination, APM, and deployment documentation remain Phase 4 scope.
- Cleanup evidence: no external resources were acquired; `AdminActivationSessionStore` was cleared by test setup/on-exit and database writes were isolated by the SQL sandbox.
- Process evidence: no production defects were found, no source/test implementation files were changed during recovery, and no delegation, commit, push, PR operation, or review was performed.

## Scaffold and Core Components Coverage Work Unit

- Delivery: auto-chain, stacked-to-main; bounded unit `scaffold-core-components-coverage`.
- Scope: behavioral coverage for Phoenix scaffold integration quotes and the remaining LiveStream branch in `OrigenWeb.CoreComponents`; no product behavior or task 4.2 documentation changes.
- Status: complete; task 4.1 is complete and task 4.2 remains pending.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Scaffold integration quote coverage | `test/origen/scaffold_support_test.exs` | Unit/scaffold contract | ✅ Existing 5 tests passed | ✅ Written before verification; exercised previously uncovered quote-return paths | ✅ Focused suite passed: 13/13 cumulative tests | ✅ Seven quote contracts cover router, channel, controller, LiveView, LiveComponent, HTML, and verified routes | ✅ Reused `Macro.to_string/1`; no production changes |
| Core component LiveStream coverage | `test/origen_web/core_components_test.exs` | Component integration | ✅ Existing 6 component tests passed | ✅ Written before verification; exercised previously uncovered LiveStream branch | ✅ Focused suite passed: 13/13 cumulative tests | ✅ Non-stream and LiveStream tables both assert rendered identifiers, update mode, and values | ✅ Used Phoenix's real `LiveStream.new/4`; no mocks or production changes |

### Work Unit Evidence

| Evidence | Result |
| --- | --- |
| Focused test command and exact result | `mix test test/origen/scaffold_support_test.exs test/origen_web/core_components_test.exs` — passed: 13 tests, 0 failures. |
| Runtime harness command/scenario and exact result | N/A — this unit changes only scaffold/component tests; the real Phoenix runtime harness belongs to the already-completed activation web unit. Full `mix test` still passed: 99 tests, 6 excluded. |
| Rollback boundary | Revert only the added quote assertion in `test/origen/scaffold_support_test.exs`, the streamed-table fixture/test in `test/origen_web/core_components_test.exs`, and this task/progress evidence; preserve all prior working-tree changes and product implementation. |

### Verification Evidence

- `mix format` — passed and normalized source.
- `mix format --check-formatted` — passed with exit 0 and no output.
- `mix compile --warnings-as-errors` — passed with exit 0 and no output.
- `mix test` — passed: 99 tests, 6 excluded.
- `mix test --cover` — passed: 99 tests, 6 excluded; global coverage `90.73%`, above the configured `90.00%` threshold.
- `git diff --check` — passed with exit 0 and no output.

## Task 4.2 Documentation Completion

- Delivery: `auto-chain`, `feature-branch-chain`; final PR slice after PR #15; cumulative review budget 800 lines.
- Bounded work unit: `task-4.2-documentation-completion`.
- Status: complete. No runtime, configuration, test, dependency, or application behavior was changed.

### Completed Task

- [x] 4.2 Document rollback, ingress/APM redaction, supported invocation, and dependency/key assumptions in context, sprint, security, and deployment documentation.

### Documentation-Only TDD Evidence

| Task | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- |
| 4.2 | `mix test` passed: 99 tests, 6 excluded | N/A — authorized documentation-only exception; no artificial failing test was introduced | Documentation consistency, relative-link, formatting, and diff-hygiene checks passed | All four documentation surfaces were checked for rollback, ingress/APM, release/invocation, and dependency/key coverage | Normalized the partial documentation into linked operational boundaries and checklists without changing runtime behavior |

### Evidence and Settlement

- Outcome: passed; task 4.2 is complete and ready for independent SDD verification.
- Diagnosis: the partial worktree already covered context, security controls, and deployment operation; `docs/sprints/SPRINT_00.md` lacked the task 4.2 operational handoff. The completed docs now agree that only source-checkout Mix invocation is approved, packaged-release invocation is absent, external redaction and runtime secret wiring are prerequisites, and rollback preserves history.
- Harness disposition: reused. The already-passing implementation baseline remained green; the documentation-only exception required no new RED test.
- Cleanup evidence: no external resources were acquired; no database state, runtime process, branch, commit, push, merge, or PR was created or changed.
- Process evidence: edited only the six authorized task 4.2 surfaces. Pre-existing secret-pattern findings in `config/test.exs`/`config/dev.exs` and dependency advisories under `deps/` were treated as the explicitly authorized out-of-scope baseline and were not edited or used as blockers. OpenSpec artifacts remain untracked and excluded from the future PR.
- Verification commands:
  - `mix test` — passed: 99 tests, 6 excluded.
  - `mix format --check-formatted` — passed with no output.
  - Documentation consistency and relative-link script — passed.
  - `git diff --check` — passed with no output.
- Cumulative changed lines for the intended documentation PR slice: 142 (138 additions, 4 deletions), within the 800-line budget. OpenSpec task/progress artifacts are excluded from that future PR.
- Exact changed files:
  - `docs/CONTEXT.md`
  - `docs/sprints/SPRINT_00.md`
  - `docs/security/ACTIVATION_DATA_HANDLING.md`
  - `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md`
  - `openspec/changes/bootstrap-first-admin/tasks.md`
  - `openspec/changes/bootstrap-first-admin/apply-progress.md`
- Deviations from design: packaged-release invocation and a secure raw-token delivery channel remain intentionally unimplemented; the docs state these limitations rather than claiming deployment readiness.
- Historical remaining-task status at completion: none before the later final-verification remediation was authorized.
- PR boundary: final documentation-only feature-branch-chain slice after PR #15. No PR operation was performed.

## Authorized Final Verification Remediation

- Task 5.1: packaged-release bootstrap invocation and fully provisioned PostgreSQL runtime/migration/verifier-role security verification through the shared fail-closed pre-I/O gate.
- Status: maintainer-authorized but not started; sole remaining task, remediating failed evidence revision `sha256:83c54ae2a58aa6cca0e9cd71be1d170d7989f94bf3a69f71b226484017011303`.
- Required execution record: strict RED/GREEN evidence, exact commands and results, harness provisioning and invalidation-free results, cleanup, and file/database rollback boundaries.
- Historical completion and evidence above remain unchanged except that prohibited authority metadata and opaque bindings are not persisted in this artifact.

## Task 5.1 Final Verification Remediation

- Status: complete; persisted task 5.1 is checked. Structured status consumed with `applyState: ready`, `repo-local` action context, and no edit-root warnings.
- Work unit / PR boundary: `final-verification-remediation`, `auto-chain`, `feature-branch-chain`; only the assigned slice was implemented. OpenSpec remains untracked and excluded from PRs.
- Outcome: packaged releases now include `bin/origen_bootstrap_admin`, which calls `Origen.Release.bootstrap_admin/1`. The release boundary applies `Origen.BootstrapAdmin.Gate.allowed?/2` using the compile environment before argument parsing or bootstrap repository/network/I/O. Only after allowance does it start Mix and delegate to the existing task. Production builds deny even when the runtime flag is true. Secret-bearing argv remains rejected by the existing parser and is absent from output.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5.1 packaged release | `test/origen/bootstrap_admin_release_test.exs` | Release boundary/integration | ✅ Existing bootstrap task and primitive suites: 16 passed | ✅ New module/script absent: 0/3 passed; three failures | ✅ 3/3 passed after minimum module, overlay, and release configuration | ✅ Added enabled secret-argv rejection path; 4/4 passed | ✅ Removed runtime dependence on unstarted `Mix.State`; 4/4 remained green and actual production artifact denied |

### Commands and Exact Results

1. Safety net: `mix test test/origen/bootstrap_admin_task_test.exs test/origen/bootstrap_admin/primitives_test.exs` — 16 passed.
2. RED: `mix test test/origen/bootstrap_admin_release_test.exs` — 0/3 passed; missing `Origen.Release` and overlay.
3. GREEN/TRIANGULATE/REFACTOR: `mix test test/origen/bootstrap_admin_release_test.exs` — 4 passed.
4. Build: `MIX_ENV=prod mix release --overwrite` — passed; created `_build/prod/rel/origen` with the overlay command.
5. Production denial with enabled flag and rejected secret-shaped argv: `DATABASE_URL=<non-routable> SECRET_KEY_BASE=<redacted-test-value> ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true _build/prod/rel/origen/bin/origen_bootstrap_admin --verifier-key <canary>` — exit 1, `Bootstrap admin is disabled`, canary absent from output.
6. Default production denial: same artifact with `ORIGEN_BOOTSTRAP_ADMIN_ENABLED` absent — exit 1, `Bootstrap admin is disabled`.
7. Non-production packaged parser boundary: `MIX_ENV=test mix release --overwrite`, then `ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true _build/test/rel/origen/bin/origen_bootstrap_admin --verifier-key <canary>` — build passed; invocation exited 1 with `Bootstrap admin received invalid command-line arguments`; canary absent from output.
8. Provision: `createdb -h localhost -p 5433 origen_task_51`, then `psql -X -v ON_ERROR_STOP=1 -d origen_task_51 -f priv/repo/security/provision_roles.sql` with the documented role variables and local credentials supplied only via environment — passed.
9. Migration: `MIX_ENV=test ORIGEN_OWNER_ROLE=origen_owner ORIGEN_MIGRATION_DATABASE_URL=<redacted-local-role-url> mix ecto.security.migrate` — both migrations applied successfully.
10. Post-migration grants: reran `priv/repo/security/provision_roles.sql` — passed.
11. Fully provisioned harness: `mix test test/origen/audit/postgres_security_test.exs --include postgres_security` with runtime, migration, and security role URLs — 6 passed, 0 excluded, 0 invalid.
12. Sequential verification: `mix test test/origen/bootstrap_admin_release_test.exs && mix test && mix test --cover && mix format --check-formatted && mix compile --warnings-as-errors && git diff --check` — 4 focused passed; 103 full passed with only the intentionally default-excluded 6 security-tag tests; coverage 90.66%; format, compile, and diff checks passed.
13. Cleanup: `dropdb -h localhost -p 5433 --force origen_task_51`; database query returned `database_count=0`. The four harness roles pre-existed this work unit, so no temporary role was created or dropped; post-cleanup query returned `preexisting_role_count=4`.

A first concurrent `mix test` / `mix test --cover` invocation caused one shared-database lifecycle collision (102/103) while coverage passed. This was command-level harness contention, not accepted evidence; the required sequential rerun above passed 103/103.

### Files, Rollback, and Deviations

- Files changed for task 5.1: `lib/origen/release.ex`, `rel/overlays/bin/origen_bootstrap_admin`, `test/origen/bootstrap_admin_release_test.exs`, `mix.exs`, `docs/CONTEXT.md`, `docs/sprints/SPRINT_00.md`, `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md`, `docs/security/ACTIVATION_DATA_HANDLING.md`, and the three authorized OpenSpec records.
- File rollback boundary: revert only the release module, overlay command, release application declaration, release test, and task-5.1 documentation amendments. Do not revert prior bootstrap lifecycle, migration, web, delivery, or audit work.
- Database rollback boundary: the disposable `origen_task_51` database was dropped. No application/history database was changed. Pre-existing role objects were reused and retained.
- Generated artifact boundary: `_build/prod/rel/origen` is disposable build output and may be removed without changing source or database history.
- Deviations: none from task 5.1. Secure raw-token delivery, ingress/APM implementation, scanner findings, and unrelated runtime behavior remain out of scope.
- Remaining exact unchecked implementation task lines: none.
