# Proposal: Bootstrap the First Administrator

## Intent

Provide a non-production path to create first `Administrator`, preserving Issue #2 guarantees. Santiago completes password and TOTP via a web invitation.

## Outcomes

- `mix origen.bootstrap_admin` is denied unless explicitly enabled outside production.
- A durable invitation expires after 24 hours, is consume-once, and is revoked on reissue.
- TLS-protected web activation completes password and TOTP enrollment.
- Output and audit evidence exclude credential, token, URL, TOTP, QR, session, and key material.

## Scope and Non-goals

### In Scope
- Fail-closed Mix/release gate.
- Invitation persistence, expiry, consumption, reissue, and concurrency protection.
- Web activation, password hashing, TOTP, migrations, tests, and documentation.
- Sanitized audit outcomes.

### Out of Scope
- Production activation or bypasses; credential reuse, password reset, general provisioning, or an Administrator UI.
- Weakening default-deny, audit immutability, sensitive-read denial, or database capability separation.
- Recovery-code policy or infrastructure redaction changes beyond documented assumptions.

## Capabilities

### New Capabilities
- `first-admin-bootstrap`: Non-production command creating the initial Administrator and issuing/reissuing invitations.
- `admin-invitation-activation`: Durable, one-time web password and TOTP activation.

### Modified Capabilities
- `default-deny-authorization`: Explicit bootstrap, reissue, and activation decisions.
- `append-only-audit`: Sanitized lifecycle/failure outcomes without free-form secrets.

## Approach

Add an Origen service behind Mix and OrigenWeb. Use transactional Ecto operations, locked rows, immutable invitation history with only a verifier/digest, and a one-active constraint. Design selects authentication dependencies.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `lib/origen/*`, `lib/origen_web/*`, `mix.exs` | New | Domain, task, web, tests. |
| `priv/repo/migrations/*`, `config/runtime.exs` | New/Modified | State, gate. |
| `lib/origen/authorization/*`, `lib/origen/audit/*` | Modified | Policy, evidence. |

## Security, Migration, and Rollback

Security impact is high: prevent production execution, replay, double activation, and secret emission. Migrations MUST preserve audit history and use forward-compatible constraints. Rollback disables the gate/surface but retains history; destructive removal requires approval.

## Assumptions and Risks

- Missing or malformed configuration denies; environment classification is accurate.
- TLS and upstream logging controls prevent URL/body leakage.
- Digest construction, TOTP protection, and release invocation remain design decisions.

| Risk | Mitigation |
|---|---|
| Gate misclassification | Default false, explicit checks, tests. |
| Reissue/consume race | Locks, transactions, constraint, tests. |
| Secret leakage | Allowlist fields and redaction tests. |

## Success Criteria

- [ ] Tests prove uniqueness, denial, expiry, consume-once use, and reissue revocation.
- [ ] Activation proves password/TOTP enrollment and rejects replay.
- [ ] Audit/output tests prove strict redaction and preserved guarantees.
- [ ] Migration, format, compile, and tests pass.

## Handoff

Specs MUST define Given/When/Then requirements for the capabilities and deltas. Design MUST resolve risks, privileges, token delivery, dependencies, and rollback without reopening confirmed decisions.
