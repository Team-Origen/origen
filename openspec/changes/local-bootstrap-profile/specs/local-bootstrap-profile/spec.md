# Local Bootstrap Profile Specification

## Purpose

Define a default-off development-only profile that lets one student issue and activate one fictitious first Administrator in an isolated workstation database without weakening staging delivery, activation, authorization, or audit controls.

## Requirements

### Requirement: Exact Development Eligibility and Double Gate

The local bootstrap profile MUST be selected only by trusted application configuration, MUST default to disabled, and MUST be valid only when the compiled environment is exactly `:dev`. The existing bootstrap gate and the independent local-profile gate MUST each have the runtime value exactly `true`. The approved channel MUST be the source-checkout local bootstrap command; `:test`, staging conventions, `:prod`, CI runtime, release-facing entry points, and packaged releases MUST NOT expose or authorize the profile. Every entry point MUST establish these conditions before argument parsing, repository or mailbox access, protected-value access, token issuance, or bootstrap-specific output. Missing, false, malformed, or conflicting eligibility facts MUST fail closed without falling back to staging or another profile.

#### Scenario: Eligible source-checkout development command

- GIVEN the compiled environment is exactly `:dev`
- AND trusted configuration selects the local profile
- AND the existing bootstrap gate and local-profile gate are each exactly `true`
- AND the request uses the approved source-checkout local bootstrap command
- WHEN local bootstrap eligibility is evaluated
- THEN the command MAY continue to readiness validation

#### Scenario: Either gate is not exactly true

- GIVEN either the existing bootstrap gate or local-profile gate is missing, false, or malformed
- WHEN any local bootstrap entry point is invoked
- THEN the operation MUST be denied before argument parsing, repository or mailbox access, protected-value access, token issuance, or bootstrap-specific output

#### Scenario: Environment or channel is ineligible

- GIVEN the environment is `:test`, staging, `:prod`, CI runtime, or any value other than compiled `:dev`
- OR the invocation uses a release-facing entry point or packaged release
- WHEN local bootstrap is requested
- THEN the operation MUST be denied before local bootstrap effects
- AND it MUST NOT fall back to or impersonate staging delivery

### Requirement: Complete Sanitized Readiness

After eligibility succeeds and before repository access, protected-value retrieval, invitation issuance, message construction, or mailbox access, the system MUST validate the complete local profile. Readiness MUST cover trusted profile selection, the approved command channel, exact HTTPS loopback origin and endpoint, loopback binding, local mailbox adapter and bounded retention contract, exactly one canonical configured synthetic destination, and configured references for the verifier and TOTP encryption keys. The readiness result MUST aggregate all detected non-secret findings in one sanitized result. It MUST report only allowlisted finding codes or descriptions and MUST NOT contain configuration values, destinations, keys, credentials, tokens, URLs, message content, or other protected values. Readiness MUST establish protected-source availability without retrieving protected contents; protected values MUST NOT be accessed until the complete readiness result succeeds.

#### Scenario: Multiple readiness requirements are unmet

- GIVEN eligibility has succeeded
- AND multiple non-secret local profile requirements are missing, malformed, or conflicting
- WHEN readiness is evaluated
- THEN one sanitized result MUST report every detected non-secret unmet requirement
- AND no repository access, protected-value retrieval, invitation issuance, message construction, or mailbox access MUST occur

#### Scenario: Readiness is complete

- GIVEN eligibility has succeeded
- AND every required local profile condition and protected-source reference is valid
- WHEN readiness is evaluated
- THEN readiness MUST succeed without exposing any protected value
- AND only then MAY protected values be retrieved for the authorized lifecycle

#### Scenario: A protected source cannot be proven available without retrieval

- GIVEN readiness cannot establish that a required verifier or TOTP encryption source is configured and available without reading its contents
- WHEN readiness is evaluated
- THEN readiness MUST fail with a sanitized non-secret finding
- AND the protected source MUST NOT be read

### Requirement: One Canonical Synthetic Destination

Each workstation MUST configure exactly one canonical synthetic destination as trusted local-profile configuration. The destination MUST be an unambiguous lowercase ASCII address in the reserved `example.test` namespace and MUST match the single configured canonical value exactly. The system MUST reject absent or multiple destinations, caller-supplied destinations, real domains, suffix or pattern matches, non-canonical case, Unicode or lookalike characters, control characters, whitespace ambiguity, newlines, header injection, and malformed addresses. A destination, token, verifier key, TOTP value, or activation URL MUST NOT be accepted through command arguments.

#### Scenario: Configured synthetic destination is exact

- GIVEN trusted workstation configuration contains exactly one canonical lowercase ASCII destination in `example.test`
- AND no destination is supplied by the caller
- WHEN destination readiness is evaluated
- THEN that exact configured destination MUST be the only eligible message destination

#### Scenario: Destination is ambiguous or unapproved

- GIVEN the destination is absent, duplicated, caller-supplied, non-canonical, outside `example.test`, matched only by suffix, contains Unicode, whitespace, a control character, a newline, or header content
- WHEN destination readiness is evaluated
- THEN readiness MUST deny issuance with a sanitized finding
- AND it MUST NOT construct or deliver a message

#### Scenario: Caller supplies protected delivery input

- GIVEN command arguments contain a destination, token, verifier key, TOTP material, or activation URL
- WHEN the command validates its input
- THEN the command MUST reject the request
- AND no supplied value MUST enter authorization, delivery, output, or observability payloads

### Requirement: Loopback-Only HTTPS Mailbox Delivery

The local profile MUST deliver only through the approved development mailbox adapter. The token-bearing message MUST be available only from an endpoint bound to the exact configured IPv4 loopback address and served from the exact configured origin `https://127.0.0.1:<port>`. The activation location MUST use that exact origin and the path `/admin/activate`, with no userinfo, query, or pre-existing fragment. Wildcard, unspecified, hostname-resolved, private-network, public, HTTP, alternate-port, and alternate-path exposure MUST be denied before token issuance. Mailbox retention MUST be bounded and transient under an explicitly validated cleanup contract; indefinite or unverifiable retention MUST fail readiness.

#### Scenario: Approved local mailbox and activation origin

- GIVEN the approved local adapter has bounded transient retention
- AND the mailbox endpoint is bound only to the configured IPv4 loopback address
- AND the configured activation origin is exactly `https://127.0.0.1:<port>` with the approved port and `/admin/activate` path
- WHEN the authorized local profile prepares delivery
- THEN it MAY hand the invitation message to the local mailbox

#### Scenario: Endpoint or origin is not exact

- GIVEN the endpoint is HTTP, binds beyond IPv4 loopback, uses a hostname or a different address or port, or the activation location contains an alternate path, userinfo, query, or pre-existing fragment
- WHEN readiness is evaluated
- THEN readiness MUST deny issuance before token or message creation

#### Scenario: Mailbox retention is not bounded

- GIVEN mailbox retention or cleanup behavior is missing, indefinite, or cannot be validated
- WHEN readiness is evaluated
- THEN readiness MUST fail before mailbox access or invitation issuance

### Requirement: Explicit Default-Deny Local Authorization

Local bootstrap MUST obtain an explicit backend allow decision after readiness succeeds and before any business effect. Initial issue MUST use `bootstrap_local_first_administrator`; recovery MUST use the separate `reissue_local_first_administrator` operation. Both decisions MUST evaluate the approved source-checkout command channel, exact compiled `:dev` environment, both exact-boolean gate facts, trusted local-profile selection, complete readiness, exact configured synthetic destination, and isolated target database. Initial issue MUST require no pending or active Administrator. Recovery MUST instead require exactly one existing Administrator in `pending_activation`, no active Administrator, a positive non-secret account reference matching that sole pending Administrator, a prior local mailbox handoff of `revoked_or_uncertain`, and an empty or cleared local mailbox. Missing, unknown, conflicting, additional, staging-shaped, deployment-approved, user-selected, or over-broad facts MUST deny without business effects. The local profile MUST NOT create, reuse, stage, or forge a staging approval, confirmer assertion, deployment-approved fact, or staging delivery authorization.

#### Scenario: Complete initial-issue facts are allowed

- GIVEN every declared common local authorization fact is known and satisfied
- AND the target isolated database has no pending or active Administrator
- WHEN the backend evaluates `bootstrap_local_first_administrator` for the approved command channel
- THEN the operation MAY be allowed to create the sole pending Administrator and issue its first invitation

#### Scenario: Complete recovery facts are allowed

- GIVEN every declared common local authorization fact is known and satisfied
- AND the isolated database contains exactly one Administrator in `pending_activation` and no active Administrator
- AND a positive non-secret account reference matches that sole pending Administrator
- AND the prior local mailbox handoff is `revoked_or_uncertain`
- AND the local mailbox is empty or cleared
- WHEN the backend evaluates `reissue_local_first_administrator` for the approved command channel
- THEN the operation MAY be allowed to reissue only for that existing pending Administrator
- AND it MUST NOT authorize creation of an account

#### Scenario: A local authorization fact is missing or over-broad

- GIVEN any required local fact is missing, unknown, conflicting, additional, or exceeds the selected operation and exact target
- WHEN authorization is evaluated
- THEN authorization MUST deny without account, invitation, delivery, or audit-business effects

#### Scenario: Recovery target or mailbox state is ineligible

- GIVEN recovery targets no pending Administrator, a pending state other than exactly one Administrator in `pending_activation` with every required recovery fact, multiple Administrators, any active Administrator, a mismatched or non-positive account reference, a consumed predecessor, a prior handoff other than `revoked_or_uncertain`, or a mailbox that still retains a message
- WHEN `reissue_local_first_administrator` authorization is evaluated
- THEN authorization MUST deny without account, invitation, token, or delivery effects

#### Scenario: Local execution presents staging authority

- GIVEN a local initial-issue or recovery request presents a staging approval, deployment-approved fact, staging confirmer assertion, or staging delivery channel
- WHEN local authorization is evaluated
- THEN authorization MUST deny the request
- AND the system MUST NOT translate that authority into a local allow

### Requirement: Isolated First-Administrator Lifecycle

The local profile MUST reuse the authoritative first-Administrator and invitation lifecycle only after readiness and authorization succeed. Each student workstation MUST use an isolated local database, and each such database MUST contain at most one pending or active Administrator. Initial issue MUST serialize concurrent attempts and MUST deny if any pending or active Administrator exists. A successful initial issue MUST create exactly one pending fictitious Administrator and one active invitation. A qualifying `reissue_local_first_administrator` recovery MUST operate only on the sole existing pending Administrator and MUST invoke the existing atomic reissue semantics, which revoke every prior unconsumed invitation before creating one fresh invitation and fresh token. Both paths MUST preserve 24-hour expiry, verifier-only persistence, consume-once behavior, single-active invitation, revocation, and replay denial. The profile MUST NOT create a second account, support four Administrators in a shared database, change the first-admin schema or invariant, or stage or forge approvals.

#### Scenario: One student bootstraps an isolated database

- GIVEN complete local readiness and authorization
- AND the student's isolated local database contains no pending or active Administrator
- WHEN `bootstrap_local_first_administrator` succeeds
- THEN exactly one pending fictitious Administrator and one active invitation MUST exist in that database

#### Scenario: Qualifying recovery reissues for the same account

- GIVEN exact `:dev` eligibility, both gates, trusted local-profile selection, complete readiness, and `reissue_local_first_administrator` authorization succeed
- AND the exact sole pending Administrator satisfies every recovery target and mailbox condition
- WHEN the existing atomic reissue lifecycle executes
- THEN every prior unconsumed invitation MUST be revoked before one fresh invitation and fresh token are created for that same account
- AND no second account or staged approval MUST be created

#### Scenario: Four students use isolated databases

- GIVEN each of four students uses a separate workstation database
- WHEN each student completes an authorized local bootstrap independently
- THEN each database MAY contain its own sole fictitious Administrator
- AND no database MAY contain multiple Administrators through this profile

#### Scenario: Repeated or concurrent initial issue targets one database

- GIVEN an isolated database already has a pending or active Administrator or receives concurrent initial-issue attempts
- WHEN `bootstrap_local_first_administrator` is attempted
- THEN the lifecycle MUST serialize the attempts and deny every initial-issue outcome beyond the sole first Administrator

#### Scenario: Reissue state is not the sole eligible pending target

- GIVEN recovery encounters no pending Administrator, a pending state other than exactly one Administrator in `pending_activation` with every required recovery fact, multiple Administrators, any active Administrator, a mismatched or non-positive account reference, a consumed predecessor, a prior handoff other than `revoked_or_uncertain`, or a mailbox that still retains a message
- WHEN `reissue_local_first_administrator` is attempted
- THEN the lifecycle MUST deny without creating an account, invitation, token, or delivery effect

### Requirement: Fragment-Only Secret Boundary and Prohibited Sinks

The raw invitation token and full activation URL MUST exist only in transient issuance memory, the approved local mailbox message, and the student's browser fragment. The link MUST preserve the existing fragment-only invitation reference and token contract. No raw token, full activation URL, destination, mailbox body, password, TOTP seed or code, QR payload, recovery code, nonce, session or cookie value, digest, verifier key, encryption key, or protected configuration value MAY enter Logger, access logs, audit rows, telemetry, APM, analytics, exceptions, error reports, CLI output, SQL binds or telemetry, redirects, diagnostics, screenshots, tickets, chat, or support artifacts. Success, denial, readiness, and failure evidence MUST be reference-only and sanitized before construction.

#### Scenario: Local mailbox message is delivered

- GIVEN an authorized invitation has been issued
- WHEN the local message is constructed and handed off
- THEN the invitation reference and token MUST appear only in the activation URL fragment within the approved mailbox message
- AND persisted invitation state MUST contain only the verifier and secret-free lifecycle metadata

#### Scenario: Output or observability evidence is built

- GIVEN local bootstrap processing has access to sensitive or protected values
- WHEN CLI, audit, logging, telemetry, error, SQL, diagnostic, or support evidence is constructed
- THEN every prohibited value MUST be excluded before the payload reaches the sink
- AND only allowlisted non-secret references and outcomes MAY remain

#### Scenario: Activation follows the mailbox link

- GIVEN the student opens the mailbox link over the approved loopback HTTPS endpoint
- WHEN the unchanged activation exchange processes the fragment
- THEN it MUST remove the fragment, establish only the bounded invitation-bound state, and reach a clean token-free URL before credential enrollment renders

### Requirement: Handoff Failure Revocation and Recovery

A failed or uncertain local mailbox handoff MUST trigger revocation of the affected invitation and MUST be represented for recovery as `revoked_or_uncertain`; no successful recovery handoff MAY leave the prior token usable. The system MUST NOT retry, restore, reuse, or ambiguously redeliver the prior token. Recovery MUST be a separate `reissue_local_first_administrator` authorization operation, not another initial issue. It MUST require the exact sole Administrator in `pending_activation`, no active Administrator, a positive matching non-secret account reference, an isolated database, an empty or cleared mailbox, and the prior `revoked_or_uncertain` local handoff. It MUST repeat exact compiled `:dev` eligibility, both exact-`true` gates, trusted local-profile selection, complete readiness, and local authorization. An allowed recovery MUST invoke existing reissue semantics to revoke every prior unconsumed invitation before creating one fresh invitation with a fresh token. It MUST NOT create a second account, change schema, or stage or forge approvals. Failure and revocation evidence MUST remain sanitized and reference-only.

#### Scenario: Local mailbox handoff fails

- GIVEN an invitation has been issued for the local mailbox
- WHEN handoff fails or its success cannot be established
- THEN the system MUST attempt revocation and MUST classify the prior local handoff as `revoked_or_uncertain`
- AND sanitized failure evidence MUST NOT contain message or secret content

#### Scenario: Student performs exact recovery after handoff failure

- GIVEN the isolated database contains the sole Administrator in `pending_activation` and no active Administrator
- AND a positive non-secret account reference matches that Administrator
- AND the prior local handoff is `revoked_or_uncertain`
- AND the local mailbox is empty or cleared
- WHEN exact `:dev` eligibility, both gates, trusted local-profile selection, complete readiness, and `reissue_local_first_administrator` authorization succeed
- THEN existing reissue semantics MUST revoke every prior unconsumed invitation before creating a fresh invitation with a fresh token for the same account
- AND only that fresh token MAY be handed to the local mailbox

#### Scenario: Student requests recovery from any other state

- GIVEN recovery encounters no pending Administrator, a pending state other than exactly one Administrator in `pending_activation` with every required recovery fact, multiple Administrators, any active Administrator, a mismatched or non-positive account reference, a consumed predecessor, a prior handoff other than `revoked_or_uncertain`, or a mailbox that still retains a message
- WHEN `reissue_local_first_administrator` is requested
- THEN the request MUST be denied without account, invitation, token, or delivery effects

### Requirement: Staging, Activation, and Audit Regression Isolation

The local profile MUST use separate local validation, authorization, message, and delivery boundaries and MUST NOT add local or test exceptions to staging `DeliveryConfig`, staging `Provider`, staging approval verification, or staging activation-origin policy. Staging validators MUST continue to reject `Swoosh.Adapters.Local`, `Swoosh.Adapters.Test`, mailbox preview mechanisms, non-staging approvals, and unapproved origins. Existing activation TLS, fragment exchange, clean redirect, expiry, one-use, password hashing, encrypted TOTP persistence, and replay denial requirements MUST remain unchanged. Existing append-only, minimized, sanitized audit behavior MUST remain unchanged; the local mailbox MUST NOT become an audit, preview, diagnostic, or support sink.

#### Scenario: Local adapter reaches a staging validator

- GIVEN staging delivery is configured with `Swoosh.Adapters.Local`, `Swoosh.Adapters.Test`, or a mailbox preview mechanism
- WHEN the existing staging delivery validators evaluate it
- THEN they MUST reject it exactly as they did before the local profile existed

#### Scenario: Local request reaches staging approval or origin policy

- GIVEN a local environment, local authorization fact, loopback origin, or local mailbox is presented to a staging approval, provider, or origin boundary
- WHEN that boundary evaluates the request
- THEN it MUST reject the request without a local exception or fallback

#### Scenario: Existing activation and audit guarantees are exercised locally

- GIVEN an invitation was delivered through the authorized local profile
- WHEN activation and lifecycle evidence execute
- THEN activation MUST retain its existing TLS, fragment, one-use, password, TOTP, and replay protections
- AND audit MUST retain its existing minimized, append-only, sanitized fields and immutability protections

### Requirement: Non-Destructive Disablement and Rollback

Rollback MUST be disablement-first and MUST NOT require a schema migration. Removing or setting either gate to a value other than exactly `true` and restarting MUST deny local bootstrap before parsing, repository or mailbox access, protected-value access, issuance, or bootstrap-specific output. Rollback MUST stop the loopback mailbox surface, apply the approved bounded mailbox cleanup only when no activation is in progress, and revoke any unresolved invitation whose handoff state is uncertain or leave the profile disabled through expiry. Existing account, invitation, credential, bootstrap-control, and append-only audit history MUST be preserved. Rollback MUST NOT erase a database automatically or weaken staging controls.

#### Scenario: Local profile is disabled

- GIVEN either local bootstrap gate is removed or no longer exactly `true`
- WHEN the restarted application receives a local bootstrap invocation
- THEN it MUST deny before local bootstrap effects or protected-value access

#### Scenario: Rollback encounters existing history

- GIVEN local account, invitation, credential, bootstrap-control, or audit records exist
- WHEN local profile code or configuration is rolled back
- THEN those records MUST remain intact
- AND staging delivery and authorization controls MUST remain unchanged

#### Scenario: Handoff state is uncertain during rollback

- GIVEN an unresolved local invitation has uncertain mailbox handoff state
- WHEN rollback begins
- THEN the invitation MUST be revoked or the profile MUST remain disabled through its normal expiry
- AND automatic database erasure MUST NOT occur
