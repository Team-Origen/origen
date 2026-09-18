## Exploration: Bootstrap first admin

### Current State

- Sprint 0 already approves the first-admin bootstrap as a non-production, deployment-only flow: Samuel operates it, Santiago completes password + TOTP enrollment, the invitation expires in 24 hours, and all evidence must be sanitized.
- The approved authorization matrix already has `B-01`, `B-03`, `DEP-01`, and `REI-01`/`REI-02`, so the policy seam exists conceptually; the backend remains default-deny and the admin role still has no implicit power.
- The codebase currently has the policy/audit foundation only: `Origen.Authorization`, `Origen.Audit.Events`, `Origen.Audit.Writer`, `Origen.ProtectedOperation`, and the `audit_events` migration are present, but there is no Mix task, no account/invitation context, and no activation flow implementation yet.
- `mix.exs` has no `mix origen.bootstrap_admin` task, `lib/origen/application.ex` only starts the app, and `lib/origen_web/router.ex` exposes no bootstrap surface.
- Open questions before proposal: what exact non-production gate should block execution, where invitation state should live, what the reissue command shape should be, and how sanitized audit evidence should be emitted without leaking token/password/TOTP material.
- Research lanes worth offering before proposal: Mix-task gating patterns for releases/environments, DB-backed one-time invitation invalidation/expiry, and redaction-friendly audit evidence formats.

### Affected Areas

- `docs/sprints/SPRINT_00.md` — canonical sprint-level bootstrap constraints, roles, and out-of-scope boundaries.
- `docs/security/AUTHORIZATION_MATRIX.md` — the approved backend permission source for `B-01`, `B-03`, `DEP-01`, `REI-01`, and `REI-02`.
- `docs/CONTEXT.md` — domain language for `Pendiente de activación` and `Activa` internal accounts.
- `lib/origen/authorization/*` — existing default-deny seam that must keep bootstrap/reissue decisions explicit.
- `lib/origen/audit/*` and `priv/repo/migrations/20260902190000_create_audit_events.exs` — sanitized append-only evidence path and immutability boundary.
- `mix.exs` — current command surface; likely place for the new `mix origen.bootstrap_admin` task.
- `config/runtime.exs` and `lib/origen/migration_repo.ex` — separate runtime/migration capability plumbing relevant to a safe non-production gate.
- `test/support/postgres_security_case.ex` and `test/origen/audit/*` — evidence style for least-privilege and sanitized audit assertions.

### Approaches

1. **Persisted bootstrap/invitation service behind a Mix task** — add a dedicated domain/service layer plus `mix origen.bootstrap_admin`; store invitation state durably so expiry, invalidation, and reissue are observable.
   - Pros: fits the approved deployment-only channel, supports 24h expiry and reissue cleanly, and makes sanitized audit evidence reproducible.
   - Cons: requires new schema/context work and at least one additional activation path for Santiago.
   - Effort: High

2. **Command-only ephemeral flow** — keep the flow mostly inside the Mix task and avoid durable invitation state beyond the minimal audit trail.
   - Pros: smaller surface and fewer tables.
   - Cons: weak fit for one-time token invalidation/reissue, harder to prove expiry, and more likely to leak secrets or become unrecoverable.
   - Effort: Medium

### Pending product decisions

1. **Non-production execution gate for the Mix task**
   - Context: Sprint 0 frames this as a deployment-only bootstrap flow, so the task needs a hard production blocker before any invitation or activation work runs.
   - Options (choose one):
     - `NON_PROD_ONLY` — allow execution only when the runtime is explicitly non-production. Consequence: simplest and strongest default guard; depends on correct environment classification.
     - `NON_PROD_CONFIRMATION_REQUIRED` — allow only when non-production plus an explicit confirmation flag is present. Consequence: adds a second safety rail; slightly more operational friction.
     - `NO_GATE` — let the task run anywhere. Consequence: unacceptable production blast-radius risk.
   - Recommended: `NON_PROD_ONLY`.
   - Closed answer tokens: `NON_PROD_ONLY`, `NON_PROD_CONFIRMATION_REQUIRED`, `NO_GATE`.

2. **Durable invitation persistence and reissue invalidation behavior**
   - Context: The invitation must expire after 24 hours and support one-time use, which requires observable state for expiry, invalidation, and reissue.
   - Options (choose one):
     - `DURABLE_SINGLE_ACTIVE` — persist invitation state and revoke the prior invitation on reissue. Consequence: best supports expiry, invalidation, and auditability.
     - `EPHEMERAL_TOKEN_ONLY` — keep only transient token state plus logs. Consequence: weaker proof of expiry and weaker invalidation guarantees.
     - `REISSUE_IN_PLACE` — overwrite the existing invitation record on reissue. Consequence: simpler storage, but weaker historical clarity and replay traceability.
   - Recommended: `DURABLE_SINGLE_ACTIVE`.
   - Closed answer tokens: `DURABLE_SINGLE_ACTIVE`, `EPHEMERAL_TOKEN_ONLY`, `REISSUE_IN_PLACE`.

3. **Santiago activation surface/channel after receiving the invitation**
   - Context: Santiago still needs to complete password creation plus TOTP enrollment after the invitation arrives, but the current evidence does not yet pin the user-facing channel.
   - Options (choose one):
     - `WEB_ACTIVATION_LINK` — a browser-based activation surface reached from the invitation. Consequence: aligns with the existing `OrigenWeb` boundary but needs a surface to be added.
     - `CLI_ONLY` — activation happens only through the Mix task. Consequence: keeps everything in the command channel, but is poor for a human enrollment journey.
     - `OPERATIONS_HANDOFF` — a human/operator performs activation through an internal process. Consequence: weakest fit for a self-service bootstrap flow and hardest to audit end-to-end.
   - Recommended: no source-backed recommendation yet.
   - Closed answer tokens: `WEB_ACTIVATION_LINK`, `CLI_ONLY`, `OPERATIONS_HANDOFF`.

4. **Sanitized audit-evidence output/redaction contract**
   - Context: The approved evidence requirement says all audit output must be sanitized, so the redaction boundary must be explicit before proposal.
   - Options (choose one):
     - `STRICT_FIELD_REDACTION` — redact named sensitive fields before any audit payload is emitted. Consequence: preserves useful structure while preventing password/token/TOTP leakage.
     - `HASH_ONLY` — emit hashes or references instead of raw sensitive values. Consequence: strongest leakage protection, but least human-readable.
     - `RAW_INTERNAL_ONLY` — keep raw values internally and redact only at presentation time. Consequence: highest leakage risk and weakest fit for the approval language.
   - Recommended: `STRICT_FIELD_REDACTION`.
   - Closed answer tokens: `STRICT_FIELD_REDACTION`, `HASH_ONLY`, `RAW_INTERNAL_ONLY`.

### Recommendation

Choose the persisted bootstrap/invitation service behind a Mix task. The current architecture already separates policy from audit, so the missing piece should be a real domain seam for bootstrap and invitation lifecycle rather than an ad hoc script.

### Risks

- A weak non-production gate could let the command run in production by accident.
- Reissue semantics are easy to get wrong; if old invitations are not invalidated immediately, the one-time contract breaks.
- Sanitized evidence can still leak secrets if the redaction rules are left implicit.
- Rollback must not silently erase populated bootstrap/invitation history if new tables are introduced.

### Ready for Proposal

No — proposal is blocked until the non-production gate, invitation persistence/reissue behavior, Santiago activation surface, and audit-redaction contract are confirmed.

next_recommended: resolve-decisions
