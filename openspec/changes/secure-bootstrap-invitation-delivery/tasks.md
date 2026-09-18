# Implementation Tasks: Secure Bootstrap Invitation Delivery

Deliver the approved staging-only invitation email boundary as a feature-branch chain. Each child PR keeps its tests with its implementation, targets its immediate parent, and leaves the tracker draft/no-merge until independent verification and staging-acceptance preparation are complete.

## Review Workload Forecast

| Field | Value |
| ------- | ------- |
| Estimated changed lines | 2,500–3,500 across 5 child PRs (additions + deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 approval/config → PR 2 email/provider → PR 3 lifecycle/orchestration → PR 4 adapters/callback/activation regression → PR 5 operator docs/independent verification/OpenSpec sync |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

**Review budget:** 800 changed lines per child PR. Estimate each child before implementation and make one cohesive re-slicing pass if it is likely to exceed 800; do not compress tests, documentation, or readable code to meet the budget. If a cohesive slice still exceeds 800, stop and request an explicit `size:exception` rather than silently proceeding.

## Chain map and shared boundaries

```text
main
 └── feat/secure-bootstrap-invitation-delivery          (draft/no-merge tracker)
      └── feat/secure-bootstrap-invitation-delivery-01-approval-config
           └── feat/secure-bootstrap-invitation-delivery-02-email-provider
                └── feat/secure-bootstrap-invitation-delivery-03-lifecycle
                     └── feat/secure-bootstrap-invitation-delivery-04-adapters-web
                          └── feat/secure-bootstrap-invitation-delivery-05-acceptance-docs
```

For every child PR:

- Record start state, end state, immediate-parent dependency, follow-up PR, included/excluded scope, changed-line count, and the chain diagram with the current PR marked `📍`.
- Review only the diff against the immediate parent; retarget/rebase polluted diffs. Keep the tracker draft/no-merge until every child is integrated.
- Run the focused tests, `mix format --check-formatted`, `mix compile --warnings-as-errors`, and relevant full-suite checks. Preserve tests and implementation in the same slice.
- Roll back by reverting/withholding that child on the feature chain. Never erase invitation or append-only audit history, and never use destructive migration rollback.
- Do not deploy, use credentials, invoke a real provider, send Samuel→Santiago email, or claim staging acceptance occurred.

## 1. PR 1 — Establish approval, authorization, origin, and fail-closed configuration

**Start:** tracker branch at approved OpenSpec artifacts. **Finish:** pure security inputs reject unsafe requests before repository access or token generation. **Depends on:** none. **Follow-up:** PR 2. **Estimate:** 550–750 lines. **Rollback:** revert this child; no schema or durable state exists.

### 1.1 RED — Specify denial-first contracts

- [x] Add focused tests under `test/origen/bootstrap_admin/approval_verifier_test.exs`, `origin_test.exs`, and `delivery_config_test.exs` for valid signed approval plus bad signature/key ID, expiry/not-yet-valid, self-approval, unauthorized confirmer, destination/environment/operation/account mismatch, production, malformed origin, HTTP/userinfo/query/fragment/path ambiguity, host spoofing, retaining/test adapter, excessive TTL, retries, missing encryption/access-audit evidence, and malformed correlation policy.
- [x] Extend `test/origen/bootstrap_admin/authorization_audit_test.exs` to prove `:approve_bootstrap_invitation` and existing issue/reissue rules default-deny unknown facts and never authorize by role inference.
- [x] Capture RED evidence: run only these tests and record expected assertion/undefined-module failures in the PR verification notes; failures must be behavioral, not setup errors.

### 1.2 GREEN — Implement the minimum pure boundary

- [x] Create `lib/origen/bootstrap_admin/approval.ex`, `approval_verifier.ex`, `origin.ex`, and `delivery_config.ex` with typed safe errors, injected clocks/verifier keys, constant-time comparisons where applicable, exact HTTPS staging-origin validation, explicit adapter allowlisting, and no I/O in origin parsing.
- [x] Update `lib/origen/authorization/rules.ex` with the explicit approval operation and approval-authorized facts required by `DEP-01`/`REI-01`; keep malformed/unknown facts denied.
- [x] Update `config/runtime.exs` and `config/test.exs` so bootstrap delivery defaults disabled/fail-closed, production cannot enable it or load provider credentials, and test doubles are test-only.
- [x] Run the focused tests to GREEN without touching persistence, command adapters, provider network calls, or activation code.

### 1.3 TRIANGULATE — Prove boundaries and call ordering

- [x] Add table/property-style cases showing equivalent encoded hosts, separators, dot segments, control characters, wildcard/suffix hosts, and secret-like references cannot bypass validation or appear in safe errors.
- [x] Add seam-spy assertions proving invalid approval/configuration performs no Repo, token-generation, provider, or bootstrap-specific output action.
- [x] Run focused tests in randomized order and the existing authorization/bootstrap tests to rule out application-environment leakage.

### 1.4 REFACTOR — Stabilize reviewer-facing APIs

- [x] Deduplicate fixtures into concrete test support modules under `test/support/bootstrap_admin/` without exposing production message inspection or arbitrary module selection.
- [x] Format, compile with warnings as errors, run affected tests, and document the no-schema/no-I/O rollback boundary in the PR body.

## 2. PR 2 — Build the fragment-only email and provider-neutral handoff

**Start:** PR 1 branch. **Finish:** one in-memory token-bearing message can be submitted once through a safe provider behaviour and yields only a validated correlation reference. **Depends on:** PR 1. **Follow-up:** PR 3. **Estimate:** 500–750 lines. **Rollback:** revert this child; disable delivery configuration; no invitation lifecycle changes.

### 2.1 RED — Specify the secret boundary

- [x] Add `test/origen/bootstrap_admin/invitation_email_test.exs` for the exact `https://approved-host/admin/activate#invitation_id=<encoded>&token=<encoded>` shape, text/HTML consistency, recipient/from handling, and absence of token/reference from path, query, headers, metadata, inspectable return values, and safe errors.
- [x] Add `test/origen/bootstrap_admin/provider_test.exs` and `delivery_security_test.exs` for exactly-one submission, approved correlation-reference characters/length, malformed/raw provider response rejection, no ambiguous retry, and no token/address/body/full URL in Logger, audit-shaped payloads, telemetry, exceptions, diagnostics, or support fixtures.
- [x] Record focused RED output before production modules exist.

### 2.2 GREEN — Implement email and provider seams

- [x] Create `lib/origen/bootstrap_admin/invitation_email.ex` and `provider.ex`; construct the `Swoosh.Email` only from validated values and normalize results to `{:ok, %{correlation_ref: ref}} | {:error, safe_reason}`.
- [x] Add the smallest concrete transactional Swoosh adapter under `lib/origen/bootstrap_admin/providers/` only after confirming the already-present dependencies support it; resolve credentials inside the adapter immediately before handoff and never expose bodies/raw responses.
- [x] Add guarded test doubles under `test/support/bootstrap_admin/` that permit in-process email assertions only in tests; reject Local/test/mailbox-preview adapters at runtime.
- [x] Run focused tests to GREEN without calling any real provider or using credentials.

### 2.3 TRIANGULATE — Challenge leakage and provider behavior

- [x] Generate token/address/provider-response variants and assert each prohibited sink remains clean while the email body alone contains the fragment link.
- [x] Exercise timeout, transport error, provider rejection, malformed success, and duplicate invocation attempts; prove the application submits once and returns only safe reasons/references.

### 2.4 REFACTOR — Minimize the external boundary

- [x] Remove provider-specific structures from domain-facing APIs, centralize correlation validation/redaction, and keep production adapters unable to inspect messages after handoff.
- [x] Run focused tests, formatter, warning-strict compilation, and existing redaction tests; record that rollback disables the adapter/config and relies on approved provider TTL/purge policy rather than unaudited deletion.

## 3. PR 3 — Orchestrate issue, delivery, compensation, and immutable audit

**Start:** PR 2 branch. **Finish:** authorized issue/reissue delivers once; handoff failure atomically revokes; recovery requires a fresh approval and token. **Depends on:** PR 2. **Follow-up:** PR 4. **Estimate:** 650–800 lines. **Rollback:** disable gate/provider, revoke unresolved invitations transactionally, preserve all account/invitation/audit records.

### 3.1 RED — Specify lifecycle and transaction outcomes

- [x] Add `test/origen/bootstrap_admin/issue_and_deliver_test.exs` for gate/config/approval/authorization/Repo/token/provider ordering; success evidence; handoff failure revocation; no provider call before committed issuance; and exactly one provider call.
- [x] Extend `test/origen/bootstrap_admin/lifecycle_test.exs` for row-locked revocation, audit failure rolling back revocation, already-revoked idempotence, unknown/consumed conflict, consume-versus-failure race, and denial of exchange/activation after revocation.
- [x] Extend `test/origen/bootstrap_admin/authorization_audit_test.exs` for typed confirmation/handoff/failure/revocation events, allowlisted correlation references, append-only correction, and rollback of required business write plus audit append.
- [x] Add a recovery test proving a failed token is never reused/resubmitted and fresh issue/reissue requires a new approval and produces a distinct token. Capture focused RED evidence.

### 3.2 GREEN — Implement orchestration and compensation

- [x] Modify `lib/origen/bootstrap_admin.ex`, `delivery.ex`, and `account.ex` to validate before issuance, commit issuance/audit before network I/O, perform one handoff, and call `revoke_delivery_failure/2` on safe handoff failure.
- [x] Implement locked conditional revocation and required audit append in one `Origen.Repo` transaction; allow a separate best-effort sanitized failure event only after rollback, while keeping the operation failed closed.
- [x] Modify `lib/origen/audit/events.ex` to add typed, allowlisted approval/delivery events without destination, assertion values, token, URL, message, provider body, or credentials.
- [x] Return reference-only success/failure structures that say “fresh invitation” rather than “retry”; add no migration or mutable delivery-status column.

### 3.3 TRIANGULATE — Exercise races and compensation windows

- [x] Run deterministic concurrent tests for consume versus terminal failure, duplicate failure, audit/database outage, and stale invitation state; verify consumed conflicts escalate safely and duplicate revocation creates no duplicate transition.
- [x] Assert SQL telemetry/audit/log/error captures contain no generated token, destination, assertion, full URL, or message body on every success and failure branch.
- [x] Run the entire `test/origen/bootstrap_admin/` suite to detect regressions in 24-hour expiry, single-active invitation, atomic reissue, consume-once, and replay denial.

### 3.4 REFACTOR — Clarify transaction ownership

- [x] Keep Ecto mutation in `Origen`, provider calls outside transactions, and provider-neutral inputs at domain boundaries; extract only helpers that reduce duplicated sanitization/locking logic.
- [x] Run formatter, warning-strict compile, focused/full domain tests, and coverage; document compensation-window escalation and rollback in the PR body.

## 4. PR 4 — Integrate commands and conditional provider callback; preserve activation

**Start:** PR 3 branch. **Finish:** source/release entry points share gate-first orchestration, and required terminal failures enter through an authenticated normalized web boundary without changing activation. **Depends on:** PR 3. **Follow-up:** PR 5. **Estimate:** 600–800 lines. **Rollback:** disable bootstrap/provider/callback routes and revert this adapter slice; retain lifecycle/audit history.

### 4.1 RED — Specify operator and HTTP adapter behavior

- [x] Extend/create tests for `lib/mix/tasks/origen.bootstrap_admin.ex` and `lib/origen/release.ex` proving both call `Origen.BootstrapAdmin.Gate` before parsing, config, Repo, network, token generation, or bootstrap output; production/disabled/malformed enablement performs no later seam call.
- [x] Add command tests rejecting `--email`, verifier keys, approval assertion bodies, tokens, URLs, and other secret argv; require protected approval-input reference handling and assert stdout/stderr snapshots contain references only.
- [x] Determine from the approved staging provider contract whether handoff acceptance is terminal. If it is not, add RED controller tests at the concrete discovery targets `lib/origen_web/router.ex` and `lib/origen_web/controllers/provider_event_controller.ex` for raw-body signature/timestamp validation, replay window, event allowlist, signed invitation correlation, duplicate idempotence, and body/header non-logging. If terminal acceptance is contractually sufficient, record evidence and omit callback code/tests.
- [x] Extend `test/origen_web/controllers/admin_activation_controller_test.exs` and `admin_activation_input_security_test.exs` to preserve fragment removal before POST, nonce/session TTL, clean redirect, TLS/CSRF, consumed/revoked denial, successful activation, and replay denial. Capture RED only for changed contracts; unchanged regression tests must remain green.

### 4.2 GREEN — Wire adapters without broadening authority

- [x] Create/refactor `lib/origen/bootstrap_admin/command.ex`; modify `lib/mix/tasks/origen.bootstrap_admin.ex` and `lib/origen/release.ex` so each directly checks the shared gate first and then delegates once to the command/domain orchestration.
- [x] Accept only reference-safe argv and protected runtime approval input; ensure destination comes from verified data and every fresh issue invokes issuance once.
- [x] If callbacks are required, create `lib/origen_web/controllers/provider_event_controller.ex` and modify `lib/origen_web/router.ex` only for an authenticated terminal-failure endpoint; web code authenticates/normalizes, while `Origen.BootstrapAdmin` owns revocation. Do not add token-bearing routes or log raw callback material.
- [x] Keep the existing activation controller/session flow behavior unchanged and run focused tests to GREEN.

### 4.3 TRIANGULATE — Verify the complete synthetic operator flow

- [x] With only test doubles and synthetic values, verify: disabled/production invocation stops before parsing/I/O; mismatched/self approval creates no token; approved staging issue submits one exact fragment email; handoff/terminal failure revokes; old activation denies; fresh approval creates a distinct invitation/token; successful exchange cleans the URL; activation consumes once; replay denies; final disablement stops both entry points before I/O.
- [x] Exercise source-checkout and packaged-command seams separately, including malformed argv/config and provider/callback failure, and search captured output, logs, telemetry, audit, SQL telemetry, exceptions, and fixtures for canary/token/address/full-link values.
- [x] If callbacks exist, test signature failure, stale timestamp, unknown event, replay, duplicate valid terminal failure, and correlation tampering without using a real callback secret.

### 4.4 REFACTOR — Keep adapters thin

- [x] Remove duplicated parsing/output logic, preserve the `Origen`/`OrigenWeb` boundary, and ensure release dependencies remain compiled without loading production bootstrap credentials.
- [x] Run `mix test`, `mix test --cover`, formatter, and warning-strict compilation. Record exact synthetic operator-flow evidence and the rollback boundary; do not describe it as a real deployment/email acceptance.

## 5. PR 5 — Prepare staging acceptance, documentation, independent verification, and OpenSpec history

**Start:** PR 4 branch. **Finish:** reviewers/operators have a safe, executable acceptance packet and verified versioned artifacts; no real operation has been performed. **Depends on:** PR 4. **Follow-up:** tracker integration only after approval. **Estimate:** 350–650 lines. **Rollback:** revert documentation/checklists while retaining earlier OpenSpec and audit history; keep feature disabled.

### 5.1 RED — Identify documentation and evidence gaps

- [x] Review `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md`, `docs/security/ACTIVATION_DATA_HANDLING.md`, `docs/security/AUTHORIZATION_MATRIX.md`, `docs/CONTEXT.md`, and `.github/workflows/ci.yml` against every proposal acceptance outcome and delta scenario; record missing operator steps, provider prerequisites, evidence owners, stop conditions, and rollback checks.
- [x] Add/extend documentation or acceptance checks (under `test/origen/bootstrap_admin/` where machine-verifiable) that fail when examples contain secret argv, reference-only output is absent, production enablement is suggested, failed-token retry is suggested, or historical OpenSpec files would be overwritten.

### 5.2 GREEN — Write the operator-ready acceptance packet

- [x] Update `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md` with the happy path first: distinct approval, exact staging destination/environment verification, protected input, reference-only command results, provider handoff evidence, activation/replay checks, immediate disablement, and fresh-approval recovery after failure.
- [x] Update `docs/security/ACTIVATION_DATA_HANDLING.md` with provider encryption/TTL/access-audit/preview restrictions, synthetic canary searches across ingress/logs/APM/exceptions/SQL telemetry/provider/support systems, callback controls when applicable, and explicit release blockers.
- [x] Update `docs/security/AUTHORIZATION_MATRIX.md` and `docs/CONTEXT.md` for the distinct approval authority and bounded transactional delivery boundary; clearly label staging acceptance as **prepared/not executed** and state that no Samuel→Santiago email, credentials, deployment, or operational bootstrap is included.
- [x] Include a real-staging acceptance worksheet with fields for approver evidence reference, provider control evidence, synthetic canary results, failure drill, happy path, disablement, reviewer sign-off, timestamps, and rollback decision—without fields that solicit secrets, addresses, full URLs, message bodies, or tokens.

### 5.3 TRIANGULATE — Independent verification

- [ ] Have an independent reviewer (not the implementer and not a child agent) trace proposal outcomes and all delta scenarios to code/tests/docs, inspect each child diff against its immediate parent, and confirm every slice is ≤800 changed lines or has explicit `size:exception` approval.
- [ ] In a credential-free test environment, independently run `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`, `mix test --cover`, the PostgreSQL security test command from `.github/workflows/ci.yml`, and the full synthetic operator-flow checklist; attach sanitized command/results references to the review record.
- [ ] Independently inspect for schema drift (expect no migration), provider-specific leakage, forbidden adapters, raw token/full URL/address/assertion/provider response in prohibited sinks, callback authenticity gaps, mutable audit behavior, and production enablement. Any failure blocks tracker merge and keeps bootstrap disabled.
- [x] Prepare—but do not execute—the real staging acceptance handoff to Samuel/Santiago/security/operations. Explicitly mark provider credentials, deployment authorization, real recipient confirmation, sending, activation, and deployment as human-controlled future actions.

### 5.4 REFACTOR — Sync and preserve versioned OpenSpec history

- [x] Reconcile implementation evidence with `openspec/changes/secure-bootstrap-invitation-delivery/proposal.md`, `design.md`, and all files under `specs/`; record deviations as new review notes or a superseding change rather than rewriting approved historical decisions.
- [ ] After independent verification passes, use the repository-supported OpenSpec validation/sync workflow to merge the approved deltas into canonical specs, then archive `secure-bootstrap-invitation-delivery` as immutable versioned history. Never delete or rewrite prior archived changes.
- [ ] Verify the archive contains proposal, delta specs, design, tasks, and sanitized verification references; ensure repository docs link to canonical/current artifacts rather than claiming a real email or deployment occurred.
- [ ] Re-run format/compile/tests after documentation and OpenSpec sync, keep the tracker draft/no-merge until all child reviews and CI pass, and record residual operational gates: provider approval, credentials, deployment, real dual confirmation, Samuel→Santiago delivery, and staging acceptance remain pending.
