# Delta for Append-only Audit

## MODIFIED Requirements

### Requirement: Sanitized Bootstrap Lifecycle Evidence

Bootstrap, confirmation, issuance, provider handoff, delivery, reissue, activation, expiry, consumption, revocation, denial, and failure outcomes MUST append and print only allowlisted fields: event type, result, actor kind/reference, target account identifier, invitation record identifier, provider correlation reference when approved, and server timestamp. Success and failure evidence MUST be sanitized before construction and MUST NOT include passwords, confirmation values, destination addresses unless separately approved, raw tokens, full activation URLs, message bodies or previews, provider credentials, TOTP seeds, OTP codes, QR payloads, recovery codes, session/cookie values, digests, or keys. These sensitive values MUST NOT reach audit events, command output, application or access logs, exceptions, error reports, telemetry, APM, analytics, SQL binds, delivery diagnostics, mailbox previews, or support artifacts. Token-like strings MUST NOT be placed in actor, entity, or provider references.
(Previously: Bootstrap lifecycle evidence was allowlisted and secret-free, but provider delivery outcomes, correlation references, and delivery-specific prohibited sinks were not explicit.)

#### Scenario: Lifecycle or delivery outcome is recorded

- GIVEN a bootstrap, confirmation, invitation, provider, delivery, or activation operation completes or fails
- WHEN evidence is appended or emitted
- THEN the result MUST be represented with only allowlisted non-secret references and fields

#### Scenario: Sensitive field is supplied

- GIVEN an output, audit, provider, observability, preview, or support payload contains a named secret or equivalent sensitive value
- WHEN the payload is constructed
- THEN the value MUST be removed or replaced before any prohibited sink receives it

#### Scenario: Provider handoff succeeds

- GIVEN a provider accepts a token-bearing invitation message
- WHEN success evidence is recorded
- THEN only the allowlisted invitation reference, approved provider correlation reference, result, actor information, and server timestamp MAY be emitted
- AND the raw token, full activation URL, message body, and destination address MUST NOT be emitted

#### Scenario: Audit append or business operation fails

- GIVEN an allowed lifecycle write requires an audit append
- WHEN either the business write or required append fails
- THEN both MUST roll back
- AND a sanitized failure outcome MAY be appended separately after rollback

#### Scenario: Audit history is corrected

- GIVEN a lifecycle or delivery event requires correction
- WHEN correction is recorded
- THEN a new sanitized event MUST be appended and the original MUST remain unchanged
