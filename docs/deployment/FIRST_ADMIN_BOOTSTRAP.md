# Operate the first Administrator bootstrap safely

> Staging acceptance is **prepared/not executed**. This packet has not used provider credentials, deployed code, sent a Samuel→Santiago email, activated an account, or completed an operational bootstrap. Issue #3 must remain open until a separately authorized real-staging journey is recorded.

This is a staging-only, disabled-by-default capability. A production-compiled release always denies it. The happy path below is a future human-controlled procedure, not evidence that it happened.

## Happy path (future authorized staging window)

### 1. Stop unless prerequisites are evidenced

The operator owns environment/destination checks and disablement. The distinct authorized confirmer owns approval. Security owns provider and canary evidence. Operations owns ingress, callback, rollback, and timestamps. An independent reviewer owns final sign-off.

Before enablement, record references—not copied evidence—to prove:

- deployment authorization identifies the exact staging destination and environment;
- Samuel requested issuance and a **distinct authorized confirmer** approved that exact destination and environment in the deployment approval system;
- the approval is short-lived, single-purpose, bound to issue/reissue and account (when present), and has not been used;
- the exact HTTPS origin and host are approved for staging; production is not selected;
- TLS, secret-provider wiring, migration/runtime roles, activation ingress, and callback ingress are ready;
- provider queue/retry storage is encrypted, TTL-bounded, least-privilege, access-audited, and has no retaining preview/body capture;
- callback signing, timestamp window, event allowlist, and correlation validation are approved;
- multi-node callback replay is prevented by ingress affinity or shared replay storage, with a retention/pruning policy.

**Stop condition:** any missing/mismatched evidence, self-approval, production value, unknown provider behavior, or unavailable rollback owner keeps bootstrap disabled.

### 2. Verify exact staging values without exposing them

Two authorized people compare the destination and environment in the protected approval system. Do not copy addresses, assertion bodies, signatures, credentials, tokens, message bodies, or full URLs into terminals, worksheets, tickets, or chat. Record only the approval evidence reference and the result `matched` or `not matched`.

### 3. Supply approval through protected input

The approved entry points are the source-checkout Mix task and packaged `bin/origen_bootstrap_admin`. Both check the shared gate before parsing or I/O. Use a one-shot file descriptor or an access-controlled secret-provider mount. The protected reader resolves the opaque reference at runtime.

```bash
# Illustrative staging shape: placeholders are references, never secret values.
MIX_ENV=dev ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true \
  mix origen.bootstrap_admin \
  --approval-input-ref APPROVAL_INPUT_REFERENCE \
  --issued-by-ref REQUESTER_REFERENCE

# Reissue only a pending account, after a new distinct approval.
MIX_ENV=dev ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true \
  mix origen.bootstrap_admin \
  --account-id ACCOUNT_REFERENCE \
  --approval-input-ref FRESH_APPROVAL_INPUT_REFERENCE \
  --issued-by-ref REQUESTER_REFERENCE
```

Do not put a destination, verifier key, approval assertion, token, URL, provider credential, or callback secret in argv or shell-expanded environment examples. Disable shell tracing/history around the authorized window.

**Reference-only result:** success or failure output may contain only approved account, invitation, approval, and provider-correlation references plus a safe outcome. Stop and treat any destination, assertion value, token, full URL, body, credential, or raw provider response as a release-blocking leak.

### 4. Prove provider handoff and activation

Using evidence references only, verify one provider submission and one accepted handoff. In the recipient-controlled browser, verify the invitation reference/token occur only in the fragment, the fragment is removed before POST, the redirect is clean, activation consumes once, and replay is denied. Never paste the link or token into evidence.

### 5. Disable immediately

Set `ORIGEN_BOOTSTRAP_ADMIN_ENABLED=false` (or remove it), restart every staging instance, and verify both entry points deny before parsing/I/O. Disable provider submission and callback/activation ingress when no activation is in progress. Preserve append-only audit and provider access evidence.

## Safe failure and fresh-approval recovery

A handoff or terminal-delivery failure must revoke the invitation atomically with sanitized audit evidence. Confirm revocation and old-token activation denial by references only. **Do not retry or resubmit the failed invitation.** Keep all surfaces disabled if revocation cannot be proved.

Recovery requires a **fresh approval** by a distinct authorized confirmer and a **fresh invitation** with a different token. Re-run exact destination/environment checks. A consumed/failure race, audit/database failure, or unknown provider state requires security incident review before any new attempt.

## Callback and replay limitation

Current callback replay storage is **node-local** and in-memory, with **no time-based pruning**. Real staging remains blocked until operations provides ingress affinity or shared replay enforcement plus a bounded retention/pruning policy. This limitation must be resolved together with full-stack ingress/APM/provider integration; restarting or scaling nodes must not reopen the replay window.

## Rollback

1. Disable bootstrap on every instance and prove gate-first denial.
2. Disable provider submission and authenticated callback ingress; preserve provider audit evidence and follow approved TTL/purge policy.
3. Remove activation ingress only after confirming no activation is in progress.
4. Transactionally revoke unresolved invitations whose delivery cannot be trusted; otherwise remain disabled through expiry and incident review.
5. Revert the delivery slice only after retaining sanitized evidence. Preserve accounts, invitations, controls, audit records, and readable key history. No migration was added.

Never overwrite, delete, or rewrite archived OpenSpec history. Validation/sync/archive must use repository-supported tooling after independent verification; superseding decisions belong in a new change.

## Sanitized real-staging acceptance worksheet

Do not add addresses, tokens, full URLs, message bodies, credentials, assertion bodies/signatures, provider payloads, or screenshots. Use immutable non-secret references and pass/fail/blocked decisions only.

| Field | Sanitized entry |
| --- | --- |
| Change / Issue | Change reference; Issue #3 remains open |
| Started-at timestamp | Pending |
| Completed-at timestamp | Pending |
| Deployment authorization reference | Pending human action |
| Approver evidence reference | Pending human action |
| Distinct-principal and exact-match result | Pending human action |
| Provider-control evidence reference | Pending security/provider action |
| Synthetic-canary result reference | Pending full-stack execution |
| Failure-drill result reference | Pending full-stack execution |
| Happy-path result reference | Pending separately authorized real-staging journey |
| Disablement result reference | Pending operations action |
| Reviewer sign-off reference | Pending independent reviewer |
| Rollback decision | Keep disabled / rollback / proceed (select one) |

## Credential-gated PostgreSQL prerequisite

Do not run the PostgreSQL security test without its isolated CI database and role credentials. The exact CI command is:

```text
mix test test/origen/audit/postgres_security_test.exs --include postgres_security
```

It requires PostgreSQL 17 plus provisioned owner, migrator, runtime, and verifier roles and the database URLs/environment shown in `.github/workflows/ci.yml`. CI or an authorized human owns this evidence; a skipped local command is not a pass.
