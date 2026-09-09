# Bootstrap Invitation Delivery Specification

## Purpose

Define the secure staging-only boundary for delivering a first-administrator invitation through a transactional provider without exposing its raw token.

## Requirements

### Requirement: Strict Activation Link Validation

Before token issuance or message construction, the system MUST validate that the configured activation location uses HTTPS, matches an explicitly approved staging host, contains no userinfo, query string, or fragment, and produces exactly the approved `/admin/activate` path. Missing, malformed, ambiguous, or unapproved origin, host, path, or provider-security configuration MUST fail closed before delivery and MUST NOT expose a token.

#### Scenario: Approved staging activation location

- GIVEN configuration identifies an approved HTTPS staging host with no userinfo, query, or fragment
- AND the resulting activation path is exactly `/admin/activate`
- WHEN invitation delivery is prepared after gate and confirmation approval
- THEN the system MAY construct the activation link

#### Scenario: Activation location is unsafe or unapproved

- GIVEN the activation location is missing, malformed, non-HTTPS, production, uses an unexpected host or path, or contains userinfo, a query, or a fragment
- WHEN delivery preparation is attempted
- THEN the system MUST reject the operation before token issuance, provider access, or message construction

### Requirement: Fragment-Only Token Link

A delivered activation link MUST have the form `https://approved-host/admin/activate#invitation_id=<reference>&token=<secret>`. The invitation reference and raw token MUST occur only in the URL fragment; the token MUST NOT occur in the origin, host, path, query, redirect target, headers, or other message fields.

#### Scenario: Transactional message is constructed

- GIVEN a valid invitation reference, raw token, and approved activation location
- WHEN the transactional message is constructed
- THEN its activation link MUST place the reference and token only in the fragment
- AND every server-visible portion of the URL MUST remain token-free

#### Scenario: Link construction would expose the token

- GIVEN a candidate message places the raw token outside the activation-link fragment
- WHEN message validation occurs
- THEN provider submission MUST be denied

### Requirement: Transactional Provider Security Contract

The delivery boundary MUST accept only a transactional provider whose queue and retry retention is encrypted, has an explicit finite TTL bounded by approved policy, and restricts message access to least-privilege identities with auditable access. Provider capability validation MUST occur before token issuance. Provider selection, credentials, production approval, and real deployment remain outside this specification.

#### Scenario: Provider contract satisfies required controls

- GIVEN the transactional provider contract declares encrypted queue and retry storage, an approved bounded TTL, least-privilege access, and audited access
- WHEN staging delivery is authorized
- THEN the provider boundary MAY accept the token-bearing message

#### Scenario: Provider contract is incomplete or unbounded

- GIVEN encryption, bounded retention TTL, least-privilege access, or access auditing is absent or invalid
- WHEN invitation delivery is requested
- THEN the system MUST fail closed before token issuance or provider submission

### Requirement: Sanitized Delivery Outcome

Successful provider handoff MUST return and record only allowlisted non-secret evidence sufficient to identify the invitation reference and outcome. Failure evidence MUST be equally sanitized. Delivery evidence MUST NOT contain the raw token, full activation URL, message body, provider-retained preview, credentials, or another activation secret.

#### Scenario: Provider handoff succeeds

- GIVEN the provider accepts a valid transactional message
- WHEN success evidence is emitted
- THEN the evidence MUST contain only approved non-secret references and outcome fields
- AND MUST NOT reproduce the message or activation link

#### Scenario: Provider handoff or terminal delivery fails

- GIVEN provider submission fails or a terminal failure is reported
- WHEN failure evidence is emitted
- THEN the evidence MUST contain only approved non-secret references and outcome fields
- AND the associated invitation MUST be revoked

### Requirement: Raw Token Sink Prohibition

The raw token MUST exist only in transient process memory needed for construction, the approved provider's encrypted TTL-bounded queue, the delivered message, and Santiago's browser fragment. It MUST NOT enter CLI output, audit records, application or access logs, telemetry, APM, exceptions, error reports, analytics, SQL binds, database columns, redirects, mailbox previews, support artifacts, or other unapproved sinks.

#### Scenario: An observability or support payload is built

- GIVEN delivery processing has access to a raw token or full activation link
- WHEN output, audit, logging, telemetry, error, analytics, diagnostic, preview, or support evidence is constructed
- THEN the raw token and full activation link MUST be excluded before the payload reaches the sink

#### Scenario: Durable application state is written

- GIVEN an invitation is issued for delivery
- WHEN invitation or delivery state is persisted
- THEN only the existing verifier and secret-free lifecycle metadata MAY be stored
- AND the raw token MUST NOT be stored or included in SQL binds
