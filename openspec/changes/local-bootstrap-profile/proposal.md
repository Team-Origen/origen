# Proposal: Secure Local Bootstrap Profile

## Intent

Define a separate, secure local-development bootstrap delivery profile for GitHub #49 so each student can create and activate one fictitious Administrator in that student's isolated local database. The profile will reuse the existing invitation and activation lifecycle while keeping the staging/real-delivery trust boundary unchanged.

This change is planning and design only. GitHub #49 will produce approved OpenSpec proposal, specification, design, and task artifacts; GitHub #50 will implement the approved plan.

## Confirmed Product Decisions

| Topic | Decision |
| --- | --- |
| Availability | The local profile is disabled by default and valid only when the compiled environment is exactly `:dev`. |
| Enablement | Execution requires both the existing bootstrap gate and a separate local-profile gate, each exactly `true`. |
| Delivery | The only local delivery surface is the bounded, transient development mailbox reached through a loopback-only HTTPS endpoint. |
| Destination | Each workstation configures exactly one canonical synthetic destination from the approved reserved namespace; real or user-supplied destinations are rejected. |
| Lifecycle | Existing invitation expiry, one-time consumption, fragment exchange, password enrollment, TOTP enrollment, revocation, and first-Administrator uniqueness remain authoritative. |
| Student topology | Each of the four students uses an isolated local database containing at most one fictitious Administrator; shared multi-Administrator provisioning is excluded. |
| Readiness failures | Validation reports all non-secret unmet requirements in one sanitized readiness result before invitation issuance or protected-value access. |
| Issue handoff | #49 ends after proposal/spec/design/tasks approval. Application implementation begins in #50. |
| Existing guide | The currently untracked student guide is not modified by #49. |
| Research | Unselected; this proposal relies on the completed exploration and confirmed product decisions. |

## Scope

### In scope for #49 planning and design

- Specify a separately named local-bootstrap profile selected only from trusted application configuration.
- Require the existing bootstrap enablement and an independent local-profile enablement, both exactly `true`, before argument parsing, repository work, protected configuration access, token issuance, delivery, or bootstrap output.
- Require the compiled environment to be exactly `:dev`; reject `:test`, staging conventions, and `:prod`, including packaged-release exposure.
- Specify aggregate, sanitized readiness validation for local HTTPS, exact loopback origin and endpoint, mailbox adapter, keys, gates, and the single configured synthetic destination.
- Define a local-only configuration, policy, authorization, message, and delivery boundary without adding local branches or exceptions to staging/real-delivery validators.
- Permit exactly one canonical synthetic address per workstation, using an exact configured allowlist value in a reserved namespace such as `example.test`; reject suffix matching, case/Unicode ambiguity after canonicalization, control characters, header injection, and real domains.
- Deliver the invitation link only to the bounded, transient local development mailbox through an exact loopback HTTPS activation origin.
- Keep the raw token/full activation URL only in transient issuance memory, the approved local mailbox message, and the browser fragment. Preserve reference-only CLI, audit, telemetry, error, and support output.
- Add a distinct default-deny local-development command authorization rule or equivalent explicit policy fact; do not fabricate staging approval.
- Reuse existing account creation, first-admin serialization, invitation persistence, failure revocation, activation, password hashing, encrypted TOTP persistence, and sanitized evidence primitives after local policy succeeds.
- Plan regression evidence proving staging/real delivery continues to reject local/test adapters and mailbox preview mechanisms.
- Define implementation tasks and approval checkpoints for #50.

### First product slice

The first slice is complete when a correctly configured student workstation can deliberately enable the two gates, pass full readiness validation, create the sole pending fictitious Administrator in its isolated development database, receive a one-use invitation in the loopback-only local mailbox, and complete the unchanged HTTPS activation lifecycle.

Mailbox retention must be bounded and transient. The design will select and verify cleanup mechanics; this proposal does not promise clearing on restart or prescribe a manual-clear workflow.

### Affected areas for future implementation in #50

| Area | Expected impact |
| --- | --- |
| Trusted development configuration | Default-off local profile, exact `:dev` checks, local-only ignored secrets/configuration, one synthetic address, HTTPS loopback endpoint, and fail-closed readiness validation. |
| Bootstrap Mix/release entry points | Preserve gate-first behavior and dispatch explicitly to the local profile only after both gates permit it. |
| Local profile modules | Add independent validation, authorization facts, message construction, and mailbox handoff boundaries. |
| Bootstrap orchestration | Reuse lifecycle primitives after local readiness and authorization succeed; revoke on mailbox handoff failure. |
| Local Phoenix endpoint/mailbox | Use an exact loopback HTTPS origin and approved development mailbox without weakening activation TLS enforcement. |
| Authorization and audit | Add an explicit narrow local command rule and retain allowlisted, reference-only evidence. |
| Tests and later documentation | Add focused security/regression tests and approved setup guidance, excluding the current untracked student guide from #49. |

## Non-goals

- Application code, configuration, migration, test, or documentation implementation in GitHub #49.
- Any edit to the currently untracked student guide.
- Production, staging, `:test`, CI-runtime, or packaged-release enablement of the local profile.
- Relaxing, extending, or adding local exceptions to staging/real `DeliveryConfig`, `Provider`, `ApprovalVerifier`, or activation-origin/TLS behavior.
- Treating local execution as staging, forging deployment approval, or silently falling back between local and staging profiles.
- Sending to a real address, accepting a destination from argv, supporting arbitrary synthetic domains, suffix allowlisting, or allowing more than the one configured canonical synthetic destination per workstation.
- Printing, writing, logging, auditing, tracing, persisting, or returning the raw token, full activation URL, password, TOTP material, mailbox body, verifier/encryption keys, or other protected values outside the expressly approved local secret boundary.
- Directly seeding an active Administrator, bypassing invitation activation, changing invitation expiry or one-use semantics, or weakening password/TOTP enrollment.
- Supporting four Administrators in one database, shared classroom provisioning, general account administration, or changing the first-admin invariant.
- Schema changes or destructive data cleanup. If later design discovers a need for persistence changes, that requires explicit re-scoping before #50 implementation.
- Selecting production infrastructure or generalizing local mailbox delivery into a reusable real-delivery path.

## Affected OpenSpec Specifications

| Specification | Planned delta or relationship |
| --- | --- |
| `local-bootstrap-profile` (new) | Define exact-dev availability, double gating, aggregate readiness validation, one canonical synthetic destination, loopback HTTPS/mailbox constraints, transient retention, local authorization facts, secret boundaries, and failure behavior. |
| `first-admin-bootstrap` (modified) | Add the narrower local-profile preconditions while preserving the existing bootstrap gate, unique first Administrator, durable single-active invitation lifecycle, and non-destructive rollback. Clarify one Administrator per isolated local database. |
| `default-deny-authorization` (modified) | Add one explicit local-development command/channel rule with complete profile, environment, destination, readiness, target, and command facts. Unknown, missing, staging-impersonating, or over-broad requests remain denied. |
| `admin-invitation-activation` (reused unchanged) | The new local-profile spec owns exact loopback HTTPS eligibility. Fragment exchange, clean URL, session binding, one-use consumption, password/TOTP controls, and the existing activation TLS/origin behavior remain unchanged and require regression evidence. |
| `append-only-audit` (reused unchanged) | Existing sanitized, reference-only lifecycle evidence remains authoritative. The new local-profile spec identifies the mailbox as its sole approved token-bearing delivery surface—not an audit, log, telemetry, error, CLI, SQL, or support sink. |
| `bootstrap-invitation-delivery` (related active change, unchanged) | Preserve its staging/real-delivery provider, approval, origin, retention, and destination requirements. The local profile must not add exceptions to that capability or its implementations. |

The specification phase should express these as Given/When/Then requirements and retain explicit regression scenarios for every unchanged security boundary.

## Product and Operational Impact

- Students gain a reproducible local path that exercises the real invitation/activation lifecycle instead of seeding credentials or exposing tokens in a terminal.
- Every workstation must maintain isolated development data, local-only protected keys, a trusted certificate/HTTPS endpoint, and exactly one configured synthetic address.
- Setup errors become actionable without exposing secrets: one readiness report lists all non-secret unmet requirements, while issuance and protected-value access remain untouched.
- The local mailbox becomes a deliberate transient secret-bearing surface. It must remain loopback-only, bounded in retention, excluded from diagnostics/support artifacts, and unusable outside the profile.
- Security and reviewers gain regression evidence that local convenience has not entered staging/real delivery or weakened activation transport.
- Supporting a shared classroom database would require separate product, schema, first-admin, and authorization work and is intentionally not implied by this proposal.

## Security Impact

Security impact is **high at the new local profile boundary** and intentionally **none as a relaxation of the staging/real path**. The local profile makes a raw invitation token visible in a local mailbox, but only for a fictitious account, exact synthetic destination, isolated `:dev` database, and loopback HTTPS process.

| Risk | Required control |
| --- | --- |
| Environment/profile confusion | Independent local modules and configuration; exact compiled `:dev`; two exact-boolean gates; no runtime fallback or user-selected module/profile. |
| Local adapter entering real delivery | Do not modify `DeliveryConfig` or `Provider`; retain regression tests that reject Local/Test/mailbox adapters. |
| Staging authorization impersonation | Add an explicit local command fact/rule; do not modify or forge `ApprovalVerifier` assertions or deployment-approved facts. |
| Real or ambiguous destination | Exactly one canonical configured synthetic address per workstation; reserved namespace; exact comparison; control-character, Unicode/lookalike, newline, and header-injection rejection. |
| HTTP or non-loopback activation | Validate exact local HTTPS origin/port and endpoint binding before issuance; retain controller TLS rejection and staging origin behavior unchanged. |
| Partial setup issuing a secret | Aggregate only non-secret readiness findings and fail before repository access, protected-value access, token issuance, mailbox write, or success output. |
| Token leakage | Allow token/full URL only in transient process memory, approved mailbox content, and browser fragment; enforce prohibited-sink and reference-only-output tests. |
| Mailbox retention/exposure | Require bounded transient retention and loopback-only access; design must select verifiable cleanup semantics without broadening the delivery surface. |
| Handoff failure | Revoke the unresolved invitation, emit sanitized reference-only evidence, and require a fresh issue; never ambiguously retry or reuse the token. |
| First-admin invariant erosion | Preserve serialized issuance and deny when any pending or active Administrator already exists in the isolated database. |
| Copied local secrets in a release | Keep enablement and secrets in ignored local-only configuration; ensure packaged staging/production releases cannot expose or enable the profile even when values are copied. |

No raw token, full URL, destination, mailbox body, password, TOTP seed/code, QR payload, recovery code, nonce/session/cookie value, digest, verifier key, encryption key, or protected configuration value may enter Logger, telemetry, APM, exception reports, CLI output, audit rows, SQL telemetry/binds, analytics, screenshots, tickets, chat, or support artifacts.

## Migration Risk

### Database migration risk: low

No schema change is expected. Existing account, bootstrap-control, invitation, credential, and append-only audit structures support the isolated-workstation outcome. The first-admin invariant and historical records remain unchanged.

Risk becomes high and out of scope if the four-student requirement is reinterpreted as four Administrators in one database. #49 and #50 must retain the confirmed one-student-per-isolated-database model.

### Configuration migration risk: medium

Local HTTPS certificates, exact loopback host/port, mailbox adapter, verifier/TOTP protection, one synthetic destination, and both gates must agree. Missing, malformed, partial, or conflicting configuration must produce only the sanitized aggregate readiness report and must not issue an invitation, access protected values, or fall back to staging delivery.

Because configuration and secrets are workstation-local and ignored, no shared operational key or enablement file may be committed. The design must define a safe setup contract without printing generated secret values.

## Rollback

Rollback is disablement-first and non-destructive:

1. Set or remove the separate local-profile enablement and the existing bootstrap enablement in each workstation's ignored local configuration, then restart the local application.
2. Verify the local command denies before argument parsing, repository access, protected-value access, invitation issuance, mailbox handoff, or output.
3. Stop the local loopback HTTPS/mailbox surface and apply the design-approved bounded cleanup mechanism after confirming no activation is in progress.
4. Revoke any unresolved local invitation whose handoff state is uncertain, or keep the profile disabled through its normal expiry.
5. Revert local-profile code/configuration while preserving existing account, invitation, bootstrap-control, credential, and append-only audit history.

Rollback must not weaken or delete staging delivery controls. Automatic database erasure is excluded; a student may separately reset an explicitly disposable local database under established development procedures.

## Success Criteria

GitHub #49 succeeds when reviewers approve proposal, specification, design, and tasks that establish all of the following for #50:

- [ ] A separately named profile is default-off, requires both gates exactly `true`, and is valid only in compiled `:dev`.
- [ ] Mix and release-facing entry points deny before argument parsing, repository work, protected-value access, issuance, mailbox access, or output when either gate or exact-dev classification fails.
- [ ] Full local readiness is checked before issuance, and all non-secret unmet requirements are returned together in a sanitized report.
- [ ] Each workstation accepts exactly one canonical configured synthetic destination and rejects real, ambiguous, malformed, injected, or caller-supplied destinations.
- [ ] Delivery is restricted to the approved transient local mailbox and exact loopback HTTPS origin/endpoint.
- [ ] Existing staging/real `DeliveryConfig`, `Provider`, `ApprovalVerifier`, and activation-origin/TLS behavior receive no local exception and retain rejection regressions.
- [ ] Local authorization is explicit and default-deny; it neither impersonates staging approval nor grants broader bootstrap authority.
- [ ] Existing first-admin uniqueness, invitation expiry/one-use/reissue/revocation, browser-fragment exchange, clean redirect, password hashing, encrypted TOTP, and replay denial remain intact.
- [ ] The raw token/full URL can appear only in transient issuance memory, the approved local mailbox, and the browser fragment; every other output and observability sink stays secret-free.
- [ ] Mailbox handoff failure revokes the invitation and permits only fresh issuance after readiness and authorization are repeated.
- [ ] No schema migration is required, rollback is disablement-first and history-preserving, and shared multi-Administrator provisioning remains excluded.
- [ ] The currently untracked student guide remains unchanged throughout #49.

## GitHub #49 to #50 Handoff

GitHub #49 owns planning approval only:

1. approve this proposal;
2. add and approve the OpenSpec requirement deltas and regression scenarios listed above;
3. approve a design that resolves module boundaries, aggregate readiness ordering, exact origin/address canonicalization, local secret loading, mailbox retention/cleanup semantics, release exclusion, failure revocation, and test seams; and
4. approve implementation tasks with explicit security regression checkpoints.

After those artifacts are approved, #49 is complete. GitHub #50 then implements only the approved application/configuration/tests and any separately approved documentation surfaces. #50 must not reopen the confirmed security boundaries implicitly; any need to alter staging/real validators, activation TLS/origin behavior, schema, first-admin uniqueness, destination cardinality, or the excluded guide requires an explicit new planning decision.

## Proposal Question Round Outcome

The proposal question round confirmed that mailbox retention is bounded and transient while cleanup mechanics remain a design decision; each workstation configures exactly one canonical synthetic address; readiness returns one sanitized aggregate of all non-secret setup failures before issuance or protected-value access; and #49 finishes at approved proposal/spec/design/tasks with no application code or student-guide edit. No second question round was requested.
