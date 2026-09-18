# Delta for Append-only Audit

## ADDED Requirements

### Requirement: Sanitized Bootstrap Lifecycle Evidence

Bootstrap, reissue, activation, expiry, consumption, denial, and failure outcomes MUST append and print only allowlisted fields: event type, result, actor kind/reference, target account identifier, invitation record identifier, and server timestamp. Sensitive fields MUST be rejected or replaced before any audit event, command output, application log, error report, telemetry attribute, or delivery diagnostic is constructed, including passwords, confirmations, raw tokens, full activation URLs, TOTP seeds, OTP codes, QR payloads, recovery codes, session/cookie values, digests, and keys. Token-like strings MUST NOT be placed in actor or entity references.

#### Scenario: Lifecycle outcome is recorded

- GIVEN a bootstrap or invitation lifecycle operation completes or fails
- WHEN evidence is appended
- THEN the result MUST be represented with only allowlisted non-secret references and fields

#### Scenario: Sensitive field is supplied

- GIVEN an output or audit payload contains a named secret or equivalent sensitive value
- WHEN the payload is constructed
- THEN the value MUST be removed or replaced before any sink receives it

#### Scenario: Audit append or business operation fails

- GIVEN an allowed lifecycle write requires an audit append
- WHEN either the business write or required append fails
- THEN both MUST roll back; a sanitized failure outcome MAY be appended separately after rollback

#### Scenario: Audit history is corrected

- GIVEN a lifecycle event requires correction
- WHEN correction is recorded
- THEN a new sanitized event MUST be appended and the original MUST remain unchanged

## MODIFIED Requirements

### Requirement: Minimized Server-controlled Events

Events MUST contain only a PostgreSQL-generated bigint identity, actor kind/reference, event, entity kind/reference, result, and timestamp. Kind/result fields MUST allow at most 32 characters, event 64, and references 128. Actor kind, event, and entity kind MUST be snake_case text governed by internal constructors and allowlists. PostgreSQL MUST constrain result to exactly `allowed`, `denied`, `succeeded`, or `failed`. Timestamp MUST be server-controlled `timestamptz(6)` populated by `clock_timestamp()` on insertion. PostgreSQL constraints MUST enforce valid nullability combinations. Metadata, JSON, `scope_kind`, `scope_ref`, caller timestamps, secrets, and unnecessary sensitive values MUST NOT be stored; bootstrap lifecycle evidence MUST use only the approved sanitized references.
(Previously: Events were minimized and secret-free, but bootstrap lifecycle output had no explicit allowlisted redaction contract.)

#### Scenario: Invalid value or field

- GIVEN a value violates its vocabulary, format, or bound, or an unapproved field is supplied
- WHEN append is attempted
- THEN persistence MUST reject the event

#### Scenario: Reference is conditionally absent

- GIVEN a `system` or `anonymous` actor has no stable ID, or the operation has no persisted entity
- WHEN its corresponding reference is absent
- THEN persistence MUST accept the combination
- AND otherwise actor reference, or both entity kind and reference, MUST be present and valid
