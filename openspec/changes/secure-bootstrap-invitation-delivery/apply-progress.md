# Apply Progress: secure-bootstrap-invitation-delivery

## PR 1 — approval, origin, and fail-closed configuration

- Status: complete; feature-branch-chain work unit `pr1-approval-origin-config`
- Immediate parent: local tracker branch at the OpenSpec stack tip
- Scope: tasks 1.1–1.4 only; all 12 matching checkboxes are marked `[x]` in `tasks.md`.
- Excluded: persistence, token/email/provider implementation, commands, activation, deployment, credentials, and PR 2+.
- Action context: repo-local; edits stayed within the supplied allowlist; no warnings.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1.1 | approval/origin/config and authorization tests | Unit | 8 passed | 1/6 passed; 5 behavioral failures (undefined APIs and policy assertions) | 6 passed | denial tables added | fixtures extracted |
| 1.2 | same focused set | Unit | covered above | covered above | 12 passed | safe alternatives exercised | pure typed APIs formatted |
| 1.3 | same focused set | Unit | covered above | covered above | 12 passed | seeds 17, 8421, 314159 passed | no I/O boundaries retained |
| 1.4 | bootstrap domain suite | Unit/integration | 8 passed | N/A (fixture refactor) | 37 passed | randomized seed 271828 | formatter/compiler passed |

### Verification evidence

- RED: `mix test ...approval_verifier_test.exs ...origin_test.exs ...delivery_config_test.exs ...authorization_audit_test.exs --seed 0` → 1/6 passed, 5 behavioral failures.
- Focused randomized: seeds `17`, `8421`, and `314159` → 12/12 passed each.
- Regression: `mix test test/origen/bootstrap_admin --seed 271828` → 37/37 passed.
- Quality: `mix format --check-formatted`; `mix compile --warnings-as-errors`; `git diff --check` → passed.
- Runtime harness: N/A; this slice intentionally contains only pure validation/policy boundaries and no runtime I/O adapter.

### Boundary and rollback

No schema, Repo access, token generation, provider/network call, bootstrap output, command, or activation behavior was added. Roll back by reverting/withholding this child branch; runtime delivery remains disabled and no durable state needs reversal.

### Deviations and remaining work

No design deviation. PR 2 and all later tasks remain unchecked. Production delivery, credentials, deployment, real email, and staging acceptance remain prohibited/pending.

## PR 2 — fragment-only email and provider-neutral handoff

- Status: complete; feature-branch-chain work unit `pr2-email-provider-recovery`
- Branch: `feat/secure-bootstrap-invitation-delivery-02-email-provider`
- Immediate parent: PR #21 / `feat/secure-bootstrap-invitation-delivery-01-approval-config`
- Scope: tasks 2.1–2.4 only; all 11 matching checkboxes are marked `[x]` in `tasks.md`.
- Excluded: lifecycle/orchestration, command/release adapters, activation behavior, deployment, credentials, real provider calls, and PR 3+.
- Action context: repo-local; edits stayed within the supplied allowlist; no warnings.
- Review boundary: 382 exact changed lines across 8 PR 2 code/test files (211 preserved-test lines plus 171 successor lines), below the 800-line child-PR limit.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.1 | `invitation_email_test.exs` | Unit | N/A (preserved new test) | 0/7 focused tests passed; undefined email/provider APIs | 2 email tests passed in focused 9/9 | encoded token/reference and malformed values | exact body/link construction retained behind one API |
| 2.2 | `provider_test.exs` | Unit/integration seam | N/A (new modules) | initial 0/7 plus adapter-specific 3/5 passed, 2 undefined-adapter failures | focused 9/9 passed | success, unsafe/malformed results, credential failure, retaining adapters | provider-specific `%{id: ref}` mapping confined to Resend adapter |
| 2.3 | `delivery_security_test.exs` | Unit/integration seam | N/A (preserved new test) | included in truthful 0/7 RED | focused 9/9 passed | timeout, transport, rejection, malformed success, exception, token/address/body/URL variants | one constant safe failure and centralized correlation validation |
| 2.4 | all three focused files | Unit/integration seam | focused GREEN | covered above | 9/9 after refactor | existing redaction/security set 14/14 | formatter, warning-strict compiler, and diff check passed |

### Verification evidence

- Truthful RED: `mix test test/origen/bootstrap_admin/invitation_email_test.exs test/origen/bootstrap_admin/provider_test.exs test/origen/bootstrap_admin/delivery_security_test.exs --seed 0` → 0/7 passed; seven behavioral undefined-module/API failures.
- Adapter RED: `mix test test/origen/bootstrap_admin/provider_test.exs --seed 0` → 3/5 passed; two undefined `Providers.Resend.deliver/3` failures.
- GREEN/refactor: focused three-file command with seed `314159` → 9/9 passed.
- Existing redaction/config security: `primitives_test.exs`, `approval_verifier_test.exs`, and `delivery_config_test.exs` with seed `271828` → 14/14 passed.
- Quality: targeted `mix format`; `mix format --check-formatted`; `mix compile --warnings-as-errors`; `git diff --check` → passed.
- Harness disposition: synthetic in-process doubles only; no real provider/network call, credential, email send, telemetry emission, deployment, commit, push, or PR action.

### Diagnosis, cleanup, and rollback

The interrupted work had preserved behavioral tests but no production email/provider modules or recording double. The tests were normalized only where Swoosh's actual public address tuple is `{\"\", address}` and where the intended raised exception needed an executable tuple rather than keyword data. The existing Swoosh + Req dependencies support the concrete `Swoosh.Adapters.Resend` handoff; its provider-specific response mapping stays inside `Providers.Resend`, credentials resolve immediately before exactly one adapter call, and runtime code exposes no message-inspection seam. Test inspection doubles remain under `test/support` and the injectable Swoosh adapter exists only in test compilation.

Rollback is to withhold/revert this child and disable delivery adapter/configuration. No schema or lifecycle state changed. Any accepted provider content must expire through the approved encrypted TTL/purge policy; do not perform unaudited deletion.

### Remaining work

All PR 3 and later checkbox lines remain unchecked. This slice does not claim real provider acceptance or staging acceptance.

## PR 3 — lifecycle orchestration and compensation

- Status: complete; work unit `pr3-lifecycle-compensation`
- Branch: `feat/secure-bootstrap-invitation-delivery-03-lifecycle`
- Immediate parent: PR #23 / commit `a533666`
- Scope: tasks 3.1–3.4 only; all 13 matching checkboxes are marked `[x]` in `tasks.md`.
- Excluded: command/release adapters, UI/web callbacks, staging acceptance, network calls, credentials, deployment, and real email.
- Action context: repo-local; edits stayed within supplied allowed roots; no warnings.
- Review boundary: 737 changed implementation/test lines across 9 files (731 additions, 6 deletions), below the 800-line child-PR limit after one cohesive re-slicing pass. OpenSpec progress/checklist artifacts are harness-owned evidence and not counted as product diff.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3.1 | `issue_and_deliver_test.exs`, lifecycle/audit/recovery tests | Domain integration | 21 passed | `issue_and_deliver_test.exs`: 0/3, undefined public API | focused 26 passed | ordering denials, committed issuance, exactly-one call, fresh-token recovery | orchestration helpers retained in `Origen` |
| 3.2 | same focused set | Domain integration | covered above | handoff failure required absent revocation API | focused 26 passed | active/revoked/consumed/unknown and audit outage | row lock and required appends centralized in `Delivery` |
| 3.3 | lifecycle and prohibited-sink tests | Integration/concurrency | focused GREEN | changed race/failure contracts added before generalization | 26 passed | consume/revoke race, duplicate revocation, stale ID, audit outage, SQL telemetry/log/audit/error inspection | provider remains outside transactions |
| 3.4 | full bootstrap domain suite | Integration | 21 passed | N/A (boundary refactor) | 60 passed | randomized seeds 17, 271828, 314159 | formatter/compiler/diff check passed |

### Verification evidence

- Truthful RED: `mix test test/origen/bootstrap_admin/issue_and_deliver_test.exs --seed 0` → 0/3 passed; three behavioral `UndefinedFunctionError` failures for `issue_and_deliver/2`.
- Focused GREEN/refactor: four PR3 test files, seeds `8421` and `314159` → 26/26 passed.
- Full domain regression: `mix test test/origen/bootstrap_admin/`, seeds `17`, `271828`, and `314159` → 60/60 passed.
- Quality: `mix format --check-formatted`; `mix compile --warnings-as-errors`; `git diff --check` → passed.
- Coverage: `mix test --cover` completed at 90.10%, but reported 135/136 passing because parent commit `a533666` already has a stale `DEP-01` matrix expectation without `approval_authorized: true`; focused reproduction is 7/8. This test is outside PR3's allowed edit surfaces.
- No migration or delivery-status column was added. No real network/provider call, credential, email, deployment, command/release adapter, UI, callback, commit, push, or PR action occurred.

### Diagnosis, disposition, cleanup, and rollback

Issuance and its required lifecycle/approval audit append commit before the single provider handoff. Provider success appends a typed reference-only handoff event. Safe handoff/audit failure enters a second transaction, locks the invitation, conditionally revokes only an active row, and appends required failure plus revocation evidence atomically. A consumed row conflicts safely; duplicate revocation is idempotent and creates no duplicate transition; required audit failure rolls back revocation and attempts only a separate sanitized failure event. Recovery never resubmits the failed message and requires a fresh approval assertion and distinct token.

The compensation window remains between external handoff and local revocation. Failure to prove revocation keeps the operation failed closed and requires operator escalation; rollback is to withhold/revert PR3, disable gate/provider, transactionally revoke unresolved invitations, and preserve account/invitation/audit history.

### Remaining exact unchecked tasks

All remaining unchecked lines are PR4/PR5 work and remain verbatim in `tasks.md`; PR3 has none. They begin with command/release gate tests and end with post-sync reruns/residual operational gates. They were intentionally not modified because this execution was restricted to tasks 3.1–3.4.

## PR 4 — command adapters, provider callback, and activation regression

- Status: implementation complete; work unit `pr4-adapters-web`
- Branch/base: `feat/secure-bootstrap-invitation-delivery-04-adapters-web` / `01cd974`
- Scope: tasks 4.1–4.4 only; all 13 matching checkboxes are marked `[x]` in `tasks.md`.
- Action context: repo-local and supplied PR4 allowlist; unrelated `.gitignore`, `.pi/**`, and OpenSpec state were not overwritten.
- Review boundary: 796 changed product/test lines against `01cd974` (483 additions, 313 deletions), excluding `.gitignore`, `.pi/**`, and OpenSpec evidence; within approved 800-line exception.

### TDD Cycle Evidence

| Slice | RED | GREEN / triangulation | Refactor |
| --- | --- | --- | --- |
| 4.1–4.2 command adapters | Prior timed-out cycle captured behavioral RED before `Command`/adapter wiring; preserved tests prove disabled/malformed gates precede protected-input/parser/orchestrator seams and forbidden argv is sanitized. | Focused PR4 set: 24 passed at seed 314159. | Mix and release retain direct gate checks; parsing/protected-input/domain delegation is centralized in `Command`. |
| 4.1–4.2 callbacks | Prior timed-out cycle established callback discovery targets and RED before controller/route existed. Swoosh/Resend contract requires terminal callbacks. | Signed raw-body/timestamp authentication, event allowlist, signed invitation correlation, duplicate idempotence, and non-logging tests pass. | Web authenticates/normalizes; `BootstrapAdmin.revoke_delivery_failure/2` owns mutation; no schema change. |
| 4.3 callback failure retry | `mix test test/origen_web/controllers/provider_event_controller_test.exs --seed 0` → 2/3 passed; transient domain failure incorrectly returned 202 and consumed replay identity. | Same command → 3/3 passed after releasing replay claim on failed-closed domain result. | Replay claim remains retained only after successful/idempotent revocation. |
| 4.3–4.4 activation/regression | Existing activation contracts were unchanged, so no artificial RED was introduced. | Activation controller/input regression files pass in focused set; full suite passed 136 tests, 6 excluded. | Activation controller/session flow unchanged. |

### Verification evidence

- `mix format --check-formatted` → pass.
- `mix compile --warnings-as-errors` → pass.
- Focused PR4 command → 24 passed.
- `mix test` → 136 passed, 6 excluded.
- `mix test --cover` → tests passed (133, 6 excluded), generated 89.39%, command failed because repository threshold is 90.00%.
- `git diff --check` → pass.
- Synthetic doubles/values only; no provider network, credentials, real email, deployment, commit, push, or PR.

### Boundary, deviations, and residual risk

No migration or activation-flow production change. Callback replay state is node-local ETS and therefore requires ingress affinity/shared replay enforcement for multi-node staging; rollout remains blocked pending PR5 operational evidence. Rollback: disable bootstrap/provider/callback ingress and revert/withhold PR4 while preserving lifecycle and append-only audit history.

### PR 4 coverage-threshold follow-up

- RED: the prior full-suite `mix test --cover` result was 89.39% against the unchanged 90.00% threshold. The first behavior-valued protected-input case also exposed an invalid test-double return shape (`:invalid`) and failed 132/133; it was corrected to exercise the public adapter contract `{:ok, non_map}` and the fail-closed `:invalid_protected_input` branch without production changes.
- GREEN/TRIANGULATE: consolidated changed callback-test lines to preserve the review boundary, then covered invalid issued-by/account references, malformed protected input, missing raw callback body, and malformed callback configuration through public command/HTTP entry points.
- Focused PR4 command: `mix test test/origen/bootstrap_admin_task_test.exs test/origen/bootstrap_admin_release_test.exs test/origen_web/controllers/provider_event_controller_test.exs test/origen_web/controllers/admin_activation_controller_test.exs test/origen_web/controllers/admin_activation_input_security_test.exs --seed 314159` → 24 passed.
- Full coverage: `mix test --cover` → 133 passed, 6 excluded, **90.04%** total; unchanged 90.00% threshold passed.
- Final quality: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test` (133 passed, 6 excluded), and `git diff --check` all passed.
- Final review boundary: exactly **800 changed product/test lines** against `01cd974` (excluding `.gitignore`, `.pi/**`, and `openspec/**`), calculated from tracked numstat plus allowed untracked file line counts. No schema, deployment, credentials, network/provider call, email, commit, push, or PR action occurred.
- Persisted tasks: PR4 tasks remain visibly `[x]`; PR5's 14 exact tasks remain unchecked. This follow-up completes only PR4 verification evidence and does not claim independent verification or staging acceptance.

### Independent PR4 defect correction evidence (same attempt)

- Boundary consolidation: restored the pre-existing Mix-task module documentation and removed redundant adapter/test lines before adding regressions. Exact final product/test diff against `01cd974`: **799 changed lines** (154 tracked additions, 308 tracked deletions, 337 lines in allowed untracked files), excluding `.gitignore`, `.pi/**`, and `openspec/**`.
- Command RED (new uncovered ambiguity): `mix test test/origen/bootstrap_admin_task_test.exs:40 --seed 0` → **0/1 passed**, failure at `approval_reader` (`protected input read`) because duplicate `--approval-input-ref` switches were collapsed and accepted. GREEN: same exact command → **1 passed, 2 excluded** after duplicate-switch rejection was added in `Command.parse/1`.
- Callback RED (new uncovered raw-body behavior): `mix test test/origen_web/controllers/provider_event_controller_test.exs:63 --seed 0` → **0/1 passed, 3 excluded**; assertion showed `conn.assigns.raw_body` was only `"allback-b"` while expected accumulated chunks were `"chunked-callback-b"`. GREEN: `mix test test/origen_web/controllers/provider_event_controller_test.exs:57 --seed 0` → **1 passed, 3 excluded** after accumulation was implemented. (The line moved when the test was formatted.)
- Callback safety RED/GREEN retained from the preceding same-attempt cycle: `mix test test/origen_web/controllers/provider_event_controller_test.exs --seed 0` had **2/3 passed** because transient domain failure returned 202 and consumed replay identity; after releasing only failed claims it was **3/3 passed**. The expanded final file now has **4/4 passed** and covers rejected signature, stale timestamp, unknown event, malformed callback config, correlation tampering, wrong key ID, and chunked bodies.
- Activation regressions were added directly to both task-4.1-required files: `admin_activation_controller_test.exs` now executes denial → terminal revocation/old-token denial → fresh invitation/token → activation → replay denial → final disablement; `admin_activation_input_security_test.exs` proves a rejected submission does not render the invitation token. These preserve production activation code unchanged.
- Independently observed pre-correction focused result: `mix test test/origen_web/controllers/admin_activation_controller_test.exs test/origen_web/controllers/admin_activation_input_security_test.exs test/origen_web/controllers/provider_event_controller_test.exs test/origen/bootstrap_admin_task_test.exs test/origen/bootstrap_admin_release_test.exs --seed 314159` → **25 passed** (not 26).
- Independently observed pre-correction synthetic result: the prior synthetic command (which omitted `test/origen/bootstrap_admin_release_test.exs`) → **17 passed** (not 18). That command was incomplete and is superseded below.
- Final safety nets: `mix test` → **134 passed, 6 excluded**; `mix test --cover` → **134 passed, 6 excluded, 90.32%**; `mix format --check-formatted`, `mix compile --warnings-as-errors`, and `git diff --check` → pass.
- One earlier `mix test` was mistakenly launched concurrently with `mix test --cover`; shared-database interference produced 133/135 with two lifecycle isolation failures. It is not claimed as product evidence. The subsequent final runs above passed.
- Raw-body chunk accumulation is fixed. Callback replay remains node-local ETS with no time-based pruning; multi-node replay enforcement/affinity and pruning are **not** claimed and remain explicit staging blockers unless separately specified and implemented.

### Latest PR4 callback replay-identity correction

- Consolidation before correction: merged the raw-body chunk regression into the malformed-callback security test and removed redundant synthetic gate setup before adding behavior. The final review boundary remains **799 changed product/test lines** against `01cd974` (459 tracked additions/deletions plus 340 lines in allowed untracked files), excluding `.gitignore`, `.pi/**`, and `openspec/**`.
- RED: `mix test test/origen_web/controllers/provider_event_controller_test.exs --seed 0` → **2/3 passed**; a reused `event_id` carrying a different otherwise-valid signed invitation correlation incorrectly returned 202 instead of 401.
- GREEN: the replay claim now stores the authenticated normalized identity (`event_id`, invitation reference, and signed correlation). An exact duplicate remains idempotently accepted; the same `event_id` with a different signed correlation is rejected before domain revocation. `mix test test/origen_web/controllers/provider_event_controller_test.exs --seed 0` → **3 passed**.
- Post-correction focused command: `mix test test/origen/bootstrap_admin_task_test.exs test/origen/bootstrap_admin_release_test.exs test/origen_web/controllers/provider_event_controller_test.exs test/origen_web/controllers/admin_activation_controller_test.exs test/origen_web/controllers/admin_activation_input_security_test.exs --seed 314159` → **24 passed**.
- Corrected synthetic operator-flow verification: the credential-free test suite passed **20 tests**, and the sanitized prohibited-sink scan found no matches. No synthetic secret, address, callback credential, or token-bearing URL is reproduced in this record.
- Post-correction full/quality results: `mix test` → **133 passed, 6 excluded**; `mix test --cover` → **133 passed, 6 excluded, 90.33%**; `mix format --check-formatted`, `mix compile --warnings-as-errors`, and `git diff --check` → pass.
- No commit, push, PR, deploy, credentials, provider network call, or email occurred. Prior fail-closed, activation, secret-sink, and rollback controls remain in force.

## PR 5 — acceptance documentation and blocked OpenSpec lifecycle

- Status: documentation/test/reconciliation portion complete; independent verification, sync, and archive blocked.
- Branch/base: `feat/secure-bootstrap-invitation-delivery-05-acceptance-openspec` / PR4 tip `ce4df1f`.
- Scope: PR5 tasks 5.1–5.4 only. Tasks 5.1, 5.2, staging-handoff preparation, and implementer reconciliation in 5.4 are checked; independent-human and prerequisite-dependent tasks remain unchecked.
- Action context: repo-local; edits stayed within allowed roots. Existing `.gitignore` and `.pi/**` changes were not touched. `origin/develop:docs/Origen_Documentacion.md` (`c778b5e`) was inspected read-only and not included.
- Review boundary: approved `size:exception` up to 650 changed lines for PR5. The PR5-authored docs, test, and evidence remain within that exception; pre-existing untracked OpenSpec artifacts are not attributed as newly authored PR5 lines.

### TDD Cycle Evidence

| Task | RED | GREEN | TRIANGULATE | REFACTOR |
| --- | --- | --- | --- | --- |
| 5.1 documentation acceptance | `operator_documentation_test.exs` → 0/5 passed with behavioral content gaps | same command → 5 passed | full suite, coverage, and synthetic flow passed | formatted test and consolidated one worksheet |
| 5.2 operator packet | covered by content-test RED | docs satisfied all five checks | prohibited worksheet fields and unsafe examples checked | stale address/environment invocation removed |
| 5.3 verification preparation | N/A: independent human review cannot be fabricated | executor commands passed | canary grep had no hit; PostgreSQL intentionally not run | sanitized `verify-report.md` records owners/blockers |
| 5.4 history safety | content test required immutable-history instruction | history guard passed | no supported OpenSpec CLI found; sync/archive correctly blocked | separate blocked sync/archive records added |

### Verification evidence

- `mix format --check-formatted` — pass.
- `mix compile --warnings-as-errors` — pass.
- `mix test` — 138 passed, 6 excluded.
- `mix test --cover` — 138 passed, 6 excluded, 90.03%.
- Synthetic operator flow — 20 passed; prohibited canary grep found no match.
- PostgreSQL security command was not run. It requires isolated PostgreSQL 17, provisioned owner/migrator/runtime/verifier roles, and CI database URLs/credentials exactly as documented in `.github/workflows/ci.yml`; CI or an authorized human must run `mix test test/origen/audit/postgres_security_test.exs --include postgres_security`.
- Final focused documentation test — 5 passed; formatter/compiler/diff check passed.

### Deviations and lifecycle disposition

No product behavior or schema changed. No credential, deploy, network/provider call, real email, activation, commit, push, or PR action occurred. No OpenSpec validation/sync/archive command was available, and independent verification is incomplete, so canonical specs and history were not modified. `sync-report.md` and `archive-readiness.md` truthfully record blocked/not-executed state. Issue #3 remains open pending a separately authorized real staging Samuel→Santiago journey.

### Remaining exact unchecked tasks

- [ ] Have an independent reviewer (not the implementer and not a child agent) trace proposal outcomes and all delta scenarios to code/tests/docs, inspect each child diff against its immediate parent, and confirm every slice is ≤800 changed lines or has explicit `size:exception` approval.
- [ ] In a credential-free test environment, independently run `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`, `mix test --cover`, the PostgreSQL security test command from `.github/workflows/ci.yml`, and the full synthetic operator-flow checklist; attach sanitized command/results references to the review record.
- [ ] Independently inspect for schema drift (expect no migration), provider-specific leakage, forbidden adapters, raw token/full URL/address/assertion/provider response in prohibited sinks, callback authenticity gaps, mutable audit behavior, and production enablement. Any failure blocks tracker merge and keeps bootstrap disabled.
- [ ] After independent verification passes, use the repository-supported OpenSpec validation/sync workflow to merge the approved deltas into canonical specs, then archive `secure-bootstrap-invitation-delivery` as immutable versioned history. Never delete or rewrite prior archived changes.
- [ ] Verify the archive contains proposal, delta specs, design, tasks, and sanitized verification references; ensure repository docs link to canonical/current artifacts rather than claiming a real email or deployment occurred.
- [ ] Re-run format/compile/tests after documentation and OpenSpec sync, keep the tracker draft/no-merge until all child reviews and CI pass, and record residual operational gates: provider approval, credentials, deployment, real dual confirmation, Samuel→Santiago delivery, and staging acceptance remain pending.

Residual staging blockers: node-local/in-memory callback replay storage; no time-based pruning; required ingress affinity/shared replay plus retention policy; provider controls and credentials; human approvals; full-stack integration and canary evidence; deployment and real recipient confirmation; real delivery/activation/disablement acceptance.
