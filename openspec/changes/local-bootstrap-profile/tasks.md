# Implementation Tasks: Local Bootstrap Profile (GitHub #50)

Implement only GitHub #50 after its delivery/base ordering is approved. This artifact does not implement GitHub #49, modify `secure-bootstrap-invitation-delivery`, or modify the student guide.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 2,400–3,200 additions + deletions across configuration, local modules, entry points, and tests |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 eligibility/config → PR 2 readiness/destination/origin → PR 3 authorization/target/secrets → PR 4 mailbox/lifecycle → PR 5 entry points/activation → PR 6 integration/regression |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

**Required pre-apply decision:** select the chain strategy and integration base with the active `secure-bootstrap-invitation-delivery` delta. This change depends on its `Command`, `Account`, `Delivery`, authorization, activation, and staging-regression contracts, but MUST NOT edit, retarget, sync, or archive that delta. Do not start a local slice until the selected base contains the required active-delta implementation or the owner provides an equivalent stable base. Re-estimate each child against its immediate parent; split again or request an explicit size exception before exceeding 400 changed lines.

## Shared implementation boundaries

- All product edits for #50 remain limited to the paths identified below; no migration, dependency change, canonical-spec sync/archive, or documentation outside the local configuration example is included. Do not modify the untracked student guide.
- Preserve byte-for-byte behavior and existing tests for `lib/origen/bootstrap_admin/{delivery_config,provider,approval_verifier,origin}.ex`, staging provider implementations, and activation TLS enforcement. Local modules live under `lib/origen/bootstrap_admin/local/`.
- Every slice follows **RED → GREEN → TRIANGULATE → REFACTOR**, retains its tests with its implementation, records focused `mix test` evidence, and finishes with `mix format --check-formatted`, `mix compile --warnings-as-errors`, and the relevant regression suite. Never print canary destination/token/URL/key/message values in test failure text or task output.
- Roll back a slice by withholding/reverting that slice and disabling both gates; preserve account, invitation, credential, bootstrap-control, and append-only audit history. No automatic database cleanup.

## 1. PR 1 — Trusted dispatch, gates, and default-off development configuration

**Start:** approved integration base containing the required active delivery delta. **Finish:** local selection is trusted, default-off, source-only, exact-dev, and denied before parsing/I/O. **Depends on:** integration-base decision. **Estimate:** 300–400 lines. **Rollback:** revert this slice; local profile remains disabled.

### 1.1 RED — Entry-point and configuration denial contracts

- [ ] Add focused tests at `test/origen/bootstrap_admin_task_test.exs`, `test/origen/bootstrap_admin_release_test.exs`, and a new `test/origen/bootstrap_admin/local/eligibility_test.exs` for shared-gate-first ordering; local gate/profile malformed or false; compiled `:dev`/`:test`/`:prod`; unknown profile; local-looking release configuration; forbidden/duplicate local argv; and no parser, Repo, endpoint, mailbox, secret, token, or output seam after denial.
- [ ] Capture behavioral RED failures with the focused `mix test` command; use spies/canaries that prove secret-bearing arguments never reach a sink.

### 1.2 GREEN — Add trusted local dispatch and defaults

- [ ] Update `config/config.exs`, `config/dev.exs`, `config/runtime.exs`, and `config/dev.local.example.exs` with a default staging selector, `false` local gate/map, ignored placeholder-only development contract, and production hard-disablement; include no secret values or guide edits.
- [ ] Update `lib/origen/bootstrap_admin/command.ex`, `lib/mix/tasks/origen.bootstrap_admin.ex`, and `lib/origen/release.ex`; add `lib/origen/bootstrap_admin/local/eligibility.ex` so the shared gate precedes selector read, local eligibility precedes argv parsing, source checkout is internal-only, and release dispatch always denies local.
- [ ] Keep staging branch behavior unchanged and do not add `--profile`, destination, origin, adapter, key, token, or URL arguments.

### 1.3 TRIANGULATE / REFACTOR — Prove no fallback or release exposure

- [ ] Add table cases for exact booleans, copied local config in release/test, conflicting selectors, and extra/secret argv; assert selected-path denial never tries staging and safe results contain references/fixed atoms only.
- [ ] Run the focused tests plus existing staging task/release regressions; format/compile. Security evidence: local policy remains unreachable in packaged releases and before protected access.

## 2. PR 2 — Aggregate readiness and typed local inputs

**Start:** PR 1. **Finish:** pre-I/O readiness returns deterministic sanitized findings or typed redacted destination/origin/ready values. **Depends on:** PR 1. **Estimate:** 350–400 lines. **Rollback:** revert pure validators; no durable state.

### 2.1 RED — Readiness, destination, and origin contracts

- [ ] Create `test/origen/bootstrap_admin/local/{readiness,destination,origin}_test.exs` for aggregate sorted/deduplicated finding codes, metadata-only key probes, redacted inspection, exact lowercase ASCII `example.test` address, and literal `https://127.0.0.1:<port>/admin/activate` validation.
- [ ] Cover case/Unicode, multiple addresses/`@`, suffix/real domain, controls/header syntax, unsafe endpoint binds, HTTP/second listener, alternate port/path/query/fragment/userinfo, invalid certificate metadata, retention outside 1..900, and incorrect adapter/preview identities.
- [ ] Record RED evidence that invalid readiness performs no Repo, secret-content fetch, application start, mailbox access, message construction, token generation, or output.

### 2.2 GREEN — Isolated pure validators

- [ ] Add `lib/origen/bootstrap_admin/local/{readiness,destination,origin}.ex` and typed/redacted structs; add only metadata probing for certificate/key sources and fixed sanitized finding atoms.
- [ ] Validate one scalar configured destination, exact endpoint/origin tuple, reviewed local mailbox stack, TTL/max-message contract, isolated database declaration/name syntax, and protected-source availability without reading contents.

### 2.3 TRIANGULATE / REFACTOR — Preserve the staging trust boundary

- [ ] Inject probe dependencies below runtime eligibility and test exception normalization plus TOCTOU-ready metadata changes; verify no configured value appears in errors or `Inspect`.
- [ ] Run local validator tests and existing `delivery_config_test.exs`, `provider_test.exs`, `approval_verifier_test.exs`, and `origin_test.exs` unchanged. Security evidence: staging still rejects Local/Test/mailbox adapters and loopback origins.

## 3. PR 3 — Exact local authorization, target facts, and deferred secret access

**Start:** PR 2. **Finish:** only exact initial/recovery local facts authorize, and protected content is fetched only after authorization. **Depends on:** PR 2 and active-delta authorization/account interfaces. **Estimate:** 350–400 lines. **Rollback:** revert local rules/seams; no new schema or privilege.

### 3.1 RED — Initial/recovery default-deny contracts

- [ ] Add `test/origen/bootstrap_admin/local/{authorization,target,secrets}_test.exs` and extend `test/origen/bootstrap_admin/authorization_audit_test.exs` for `:bootstrap_local_first_administrator` and `:reissue_local_first_administrator` exact-map matching.
- [ ] Exercise each missing, additional, staging-shaped, deployment-approved, wrong channel/environment/gate/profile/readiness/destination/database fact; shared database; active/multiple/wrong pending account; non-positive/mismatched account id; retained mailbox; and handoff state other than `:revoked_or_uncertain`.
- [ ] Capture RED evidence that denial causes no target mutation, account/invitation write, audit-business effect, or secret file-content read.

### 3.2 GREEN — Local facts, read-only target inspection, and cache

- [ ] Update `lib/origen/authorization/rules.ex` only to add narrow local operations and exact-map matching for those operations; add `lib/origen/bootstrap_admin/local/{authorization,target,secrets}.ex` and the smallest shared `BootstrapSecrets` accessor only if activation needs it.
- [ ] Establish database isolation from exact configuration plus read-only `current_database()`/local-connection and account-state facts; allow initial absent target or the sole qualifying recovery target only.
- [ ] Implement post-authorization, bounded, no-symlink recheck/read/decode/cache of verifier/TOTP files, generic safe failures, and cache disposal hooks; never return/inspect/log key contents.

### 3.3 TRIANGULATE / REFACTOR — Challenge authority and secret timing

- [ ] Test TOCTOU replacement, malformed key material, cache cleanup, and authorization fact permutations; prove the recovery rule invokes no account creation authority and staging authorization remains unchanged.
- [ ] Run local authorization/secret tests plus existing authorization, account, and staging approval regressions; format/compile. Security evidence: no staged approval is fabricated and protected values remain unavailable before allow.

## 4. PR 4 — Same-VM bounded mailbox, local lifecycle, and compensation

**Start:** PR 3. **Finish:** one transient local message is handed off once, bounded/cleared, and every failure/uncertainty revokes before recovery. **Depends on:** PR 3 and active `Account`/`Delivery` compensation APIs. **Estimate:** 350–400 lines. **Rollback:** disable profile, stop coordinator, clear in-memory state, revoke uncertain invitations or remain disabled through expiry.

### 4.1 RED — Retention and compensation behavior

- [ ] Create `test/origen/bootstrap_admin/local/{mailbox,command,lifecycle}_test.exs` with fake clock/store for one submission, one message, TTL ≤900 seconds, initialization/restart/shutdown clear, expiry removal before revocation, crash between store/ack, handoff/audit/builder exceptions, and no retry.
- [ ] Cover initial issue serialization, handoff failure/uncertainty revocation, revoked-token activation denial, and recovery that repeats eligibility/readiness/authorization and uses `Account.reissue_first/2` for the same account/new token.
- [ ] Capture RED evidence that email/message/token/body/destination are never returned, logged, audited, or asserted in output; only safe correlation/account/invitation references may cross the boundary.

### 4.2 GREEN — Local coordinator and orchestration

- [ ] Add `lib/origen/bootstrap_admin/local/{mailbox,mailbox_store,invitation_email,command}.ex` and, only as necessary, local supervision in `lib/origen/application.ex` for a dedicated in-memory coordinator and secret cache.
- [ ] Verify locked Swoosh Local APIs behind `MailboxStore`; if they cannot identify/clear bounded messages atomically, implement the reviewed bounded in-memory store instead of accepting unbounded storage. Keep it local-only and same-VM.
- [ ] Reuse `Account.issue_first/1`, `Account.reissue_first/2`, and `Delivery.revoke_delivery_failure/2`; append only existing safe handoff/failure evidence and fail closed if revocation/audit cannot be proved. Do not alter staging provider/configuration modules.

### 4.3 TRIANGULATE / REFACTOR — Race and retention proof

- [ ] Test consume-versus-expiry/revocation races, retained-message recovery denial, coordinator restart, audit failure, and safe cleanup after activation/operator termination; prove at most one token-bearing message and no fresh same-session issue after uncertain revocation.
- [ ] Run local lifecycle tests plus existing `issue_and_deliver_test.exs`, `delivery_recovery_test.exs`, `lifecycle_test.exs`, and staging provider regressions; format/compile. Security evidence: token is fragment-only in the approved mailbox and old tokens never revive.

## 5. PR 5 — HTTPS local endpoint/activation secret accessor and source command lifetime

**Start:** PR 4. **Finish:** the source task hosts the exact TLS loopback endpoint/mailbox until terminal cleanup; activation remains unchanged except safe local secret access if necessary. **Depends on:** PR 4. **Estimate:** 300–400 lines. **Rollback:** disable gates and revert endpoint/task changes; retain lifecycle history.

### 5.1 RED — Endpoint and activation invariants

- [ ] Extend `test/origen_web/controllers/admin_activation_controller_test.exs` and `admin_activation_input_security_test.exs`; add `test/origen/bootstrap_admin/local/endpoint_test.exs` for literal TLS loopback-only startup, no HTTP listener, source-task lifetime/cleanup, release exclusion, clean fragment exchange, consumed/revoked denial, password/TOTP enrollment, and replay denial.
- [ ] Add canary-based prohibited-sink checks across Mix output, Logger, telemetry, exceptions, audit-shaped events, SQL telemetry, and inspected local structs; do not reproduce canaries in committed output.
- [ ] Capture RED evidence that HTTP/alternate origin rejects and that local key access cannot weaken `require_tls/1`, session/nonce behavior, redirects, or CSRF.

### 5.2 GREEN — Wire only reviewed local runtime seams

- [ ] Update `config/dev.exs`/`config/runtime.exs`, `lib/mix/tasks/origen.bootstrap_admin.ex`, and `lib/origen/application.ex` as needed to start only the exact HTTPS `127.0.0.1` endpoint while local profile is eligible and keep the command VM alive through activation/expiry/termination cleanup.
- [ ] Update `lib/origen_web/controllers/admin_activation_controller.ex` only if needed to retrieve already-authorized local cached secrets through the common accessor; preserve `require_tls/1` and all activation flow behavior byte-for-byte.
- [ ] Do not add routes or modify staging `Origen.BootstrapAdmin.Origin`; rely on the existing dev mailbox route only after readiness has verified its reviewed identity.

### 5.3 TRIANGULATE / REFACTOR — Cross-profile transport proof

- [ ] Exercise startup failure, copied local values in test/release, endpoint stop/cleanup, and local activation happy/failure/replay paths. Run controller tests plus task/release and local endpoint tests.
- [ ] Re-run unchanged staging origin/provider/approval and activation TLS tests; format/compile. Security evidence: no HTTP, DNS/IPv6/alternate interface, release path, or TLS relaxation is introduced.

## 6. PR 6 — End-to-end local regression matrix and delivery readiness review

**Start:** PR 5. **Finish:** #50 implementation has reproducible synthetic evidence and no unresolved security regression. **Depends on:** PRs 1–5 and the selected active-delta base. **Estimate:** 250–350 lines (tests/refactoring only; split if test additions exceed budget). **Rollback:** withhold this verification slice and keep both gates disabled.

### 6.1 RED — End-to-end security matrix

- [ ] Add/extend focused integration tests under `test/origen/bootstrap_admin/local/` and `test/origen_web/controllers/` for the complete initial issue → one mailbox handoff → HTTPS fragment exchange → clean URL → credential/TOTP → cleanup flow, plus each terminal failure/recovery path.
- [ ] Include concurrency, all readiness findings, authorization denial, retention expiry, handoff uncertainty, stale token, recovery fresh-token distinction, active-account denial, and four isolated database fixtures (never multiple Administrators in one database).
- [ ] Capture behavioral RED output for newly added contracts and a sanitized prohibited-sink scan; use synthetic values only.

### 6.2 GREEN / TRIANGULATE — Prove composition and unchanged boundaries

- [ ] Make the minimum fixes within prior #50 surfaces; do not broaden scope to staging, schema, docs, dependencies, or the active delivery delta.
- [ ] Run randomized focused local tests and full `mix test`; run `mix test --cover`; prove staging `DeliveryConfig`, `Provider`, `ApprovalVerifier`, `Origin`, audit immutability, and activation TLS/one-use/password/TOTP regressions remain green.

### 6.3 REFACTOR — Final review and handoff evidence

- [ ] Remove duplicated test seams while retaining deterministic fake clock/store and redaction assertions; run `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`, `mix test --cover`, and `git diff --check`.
- [ ] Record per-slice changed-line counts, immediate-parent/base, rollback boundary, and the active-delta compatibility revision. Stop for a new decision if the active delta changes a relied-on interface, any slice exceeds 400 lines, Swoosh cannot satisfy bounded storage, a migration/TLS/staging exception is needed, or secrets appear in a sink.
