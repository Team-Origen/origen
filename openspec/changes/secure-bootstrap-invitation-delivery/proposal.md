# Proposal: Deliver Bootstrap Invitations Without Exposing the Token

## Intent

Complete the staging-only Samuel-to-Santiago first-administrator journey by sending the existing one-time activation link through an approved transactional email provider. Delivery must preserve the current browser-fragment exchange, the shared fail-closed bootstrap gate, reference-only operator output, and sanitized audit history.

This proposal closes one specific gap: invitation issuance already creates a raw token, but the current reference-only email discards it before Santiago can activate the account.

## Confirmed Decisions

| Topic | Decision |
| --- | --- |
| Delivery channel | Transactional email carrying the one-time activation link. |
| Provider retention | Encrypted, bounded queue/retry retention with an explicit TTL and audited access. |
| Issuance authority | Samuel must complete dual confirmation of Santiago's destination address and the target environment before issuance. |
| Delivery failure | Revoke the failed invitation and require a fresh issue; the failed raw token is never reused or ambiguously retried. |
| Environment | Staging/non-production only; the shared gate continues to deny production. |
| Research | Unselected; this proposal relies on persisted project evidence and confirmed preproposal decisions. |

## Scope

### In scope

- Build the token-bearing activation link only after the existing shared gate permits the operation and the required destination/environment confirmations succeed.
- Validate the configured activation origin as an approved HTTPS staging origin, rejecting unexpected hosts, userinfo, query strings, and pre-existing fragments.
- Send the one-time link through a transactional provider whose queue/retry storage is encrypted, TTL-bounded, and access-audited.
- Keep the existing link and fragment-exchange contract:

  ```text
  https://approved-host/admin/activate#invitation_id=<reference>&token=<secret>
  ```

- Preserve fragment removal before POST, exchange for a short-lived in-memory nonce, clean redirects, consume-once behavior, expiry, and replay denial.
- Treat a failed provider handoff or terminal delivery outcome as an invitation failure: revoke that invitation, record only sanitized evidence, and require Samuel to issue a new invitation.
- Extend configuration validation, delivery integration, security regression coverage, and operator/security documentation for this delivery boundary.

### Affected areas

| Area | Expected impact |
| --- | --- |
| Bootstrap Mix task and packaged command | Add confirmation and delivery orchestration behind the existing shared gate. |
| Bootstrap delivery/email boundary | Construct and submit the token-bearing transactional message without exposing the token elsewhere. |
| Runtime configuration | Define and validate staging activation origin, approved host, provider behavior, and bounded retention requirements. |
| Invitation lifecycle and audit | Revoke on delivery failure and emit reference-only, allowlisted outcomes. |
| Activation web flow | Preserve the existing fragment exchange; add regression evidence rather than redesign it. |
| Deployment and security runbooks | Document provider controls, confirmation procedure, failure recovery, evidence checks, and rollback. |

## Non-goals

- Production bootstrap, production email delivery, or any bypass/relaxation of `Origen.BootstrapAdmin.Gate`.
- Redesigning the invitation lifecycle, activation UI, password/TOTP enrollment, fragment exchange, or shared authorization/audit foundations.
- Putting the token in CLI output, audit records, exceptions, URL paths or queries, redirects, database columns, telemetry, APM, access logs, analytics, SQL binds, mailbox previews, or support artifacts.
- General-purpose invitation email, password reset, account provisioning, provider selection research, or production infrastructure approval.
- Automatic reissue, reuse of a failed token, indefinite provider retention, retaining development adapters, or ambiguous retries after failure.
- Sending a real email, using credentials, deploying, or performing an operational bootstrap as part of this change.

## First-slice Boundaries

The first product slice is complete only when the existing non-production bootstrap can hand one invitation to the approved transactional delivery boundary and safely handle success or failure.

It includes:

1. strict staging activation-origin validation;
2. explicit dual confirmation of recipient destination and environment before token issuance;
3. token-bearing email construction using the unchanged fragment format;
4. provider handoff constrained by encrypted, TTL-bounded queue/retry retention and audited access;
5. revocation plus fresh-issue recovery after delivery failure; and
6. tests and runbook evidence proving the token stays within the approved boundary.

Later work may select or approve production infrastructure, generalize delivery, or refine provider operations. Those concerns must not expand this slice or weaken its fail-closed behavior.

## Acceptance Outcomes

- [ ] Both source-checkout and packaged bootstrap entry points invoke the same shared gate before argument parsing, repository access, network access, token issuance, or bootstrap-specific I/O; production remains denied even when enablement is requested.
- [ ] Issuance does not proceed until Santiago's destination and the staging/non-production environment receive the required dual confirmation.
- [ ] A valid message contains the invitation reference and raw token only in the URL fragment, using an approved HTTPS staging origin.
- [ ] Invalid, missing, or unapproved origin/provider configuration fails closed before delivery and does not expose the token.
- [ ] Provider queue/retry retention is encrypted, has an explicit bounded TTL, and permits auditable access under least privilege.
- [ ] Successful delivery lets Santiago enter the unchanged fragment-exchange activation journey; redirects and server-visible URLs remain token-free.
- [ ] Failed delivery revokes the invitation, produces only sanitized reference/outcome evidence, and requires a newly issued invitation with a new token.
- [ ] CLI output, audit, logs, telemetry, APM, errors, database state, analytics, and support evidence remain free of the raw token and other activation secrets.
- [ ] Existing expiry, consume-once, clean-redirect, CSRF, TLS, nonce TTL, activation, and replay-denial guarantees continue to pass.
- [ ] Documentation gives operators a verifiable confirmation, delivery, failure-recovery, evidence, and rollback path without including credentials or secrets.

## Security Impact

Security impact is high because the change intentionally introduces the raw token into an external delivery boundary. The allowed secret locations are narrowly limited to process memory, the approved provider's encrypted bounded queue, the delivered message, and Santiago's browser fragment.

Primary risks and controls:

| Risk | Required control |
| --- | --- |
| Wrong recipient or environment | Dual confirmation before issuance; fail closed on mismatch or absence. |
| Production execution | Preserve the shared gate and production-default denial across Mix and packaged commands. |
| Token leakage through URLs or observability | Fragment-only link; strict origin validation; allowlisted logs/audit; no body, session, local-variable, email-body, or raw-URL capture. |
| Provider persistence or unauthorized access | Encryption, explicit queue/retry TTL, least-privilege access, and audited provider access. |
| Ambiguous retry or delayed duplicate delivery | Revoke on failed delivery and require a fresh issue rather than reusing the token. |
| Secret retention in application state | Persist only the existing keyed verifier and lifecycle metadata; never persist the raw token. |

Provider capability and ingress/APM evidence are operational prerequisites, not permission to broaden the secret boundary.

## Migration and Rollback Risk

No destructive data migration is intended. Delivery should use the existing invitation state and immutable lifecycle/audit history. If implementation later proves that additional status metadata is necessary, it must be additive, secret-free, forward-compatible, and separately justified in design; raw tokens remain prohibited from persistence.

Rollback means disabling access, not erasing history:

1. disable bootstrap enablement and stop the transactional delivery integration;
2. remove or block the activation route at ingress after confirming no activation is in progress;
3. revoke any unresolved invitation whose delivery state cannot be trusted;
4. preserve account, invitation, control, and audit records plus keys needed to read retained data; and
5. revert application/configuration changes only after sanitized evidence is retained.

Dropping populated tables, constraints, or audit history is destructive and remains outside this proposal. Provider queue purge behavior must follow the approved TTL and retention policy rather than an unaudited ad hoc deletion.

## Operational Implications

- Samuel gains a deliberate confirmation step and must verify both Santiago's destination and the non-production environment before every issue or fresh issue.
- Operators must configure an approved staging HTTPS origin and a transactional provider that satisfies encryption, TTL, retry, access-audit, and non-retaining-preview requirements.
- Delivery failures create operational work: confirm revocation, retain sanitized evidence, diagnose without exposing message content, and issue a new invitation.
- Security/operations must verify ingress, APM, exception reporting, mail-provider access, and support tooling with canary evidence that contains no real secret.
- Support personnel receive references and outcome codes only; they must not request, copy, or attach activation links or tokens.
- OpenSpec and audit artifacts remain versioned history. Superseding decisions must be recorded in later artifacts rather than rewriting the confirmed exploration or preproposal record.

## Success Criteria

The change succeeds when Santiago can receive and use one staging bootstrap invitation through transactional email while every existing fail-closed and fragment-exchange guarantee remains intact. Failure must leave no usable invitation behind, expose no secret outside the approved boundary, and give Samuel one clear recovery action: issue a fresh invitation after repeating confirmation.
