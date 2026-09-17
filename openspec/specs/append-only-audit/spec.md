# Append-only Audit Specification

## Purpose

Define minimized events, transactions, and deferred reads.

## Requirements

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

### Requirement: Internal Append-only Boundary

Only the backend-internal system path MUST append events. No public or generic audit mutation path MAY exist. Events MUST NOT be updated or deleted; corrections MUST append without changing the original.

#### Scenario: Correction preserves history

- GIVEN a stored event requires correction
- WHEN the internal path records it
- THEN a new event MUST be appended and the original MUST remain unchanged

#### Scenario: External mutation request

- GIVEN an application actor or public caller requests audit mutation
- WHEN the request reaches a protected boundary
- THEN it MUST be denied without changing history

### Requirement: Transaction Outcomes

Audit behavior MUST preserve outcomes and MUST NOT claim an aborted database statement audits itself.

#### Scenario: Allowed write succeeds

- GIVEN policy allows an audited business write
- WHEN the operation succeeds
- THEN the write and sanitized event MUST commit atomically

#### Scenario: Required audit append fails

- GIVEN policy allows an audited business write
- WHEN its event cannot persist
- THEN the write and event MUST both roll back

#### Scenario: Business write fails

- GIVEN a business failure rolls back its transaction
- WHEN rollback completes
- THEN no business effect or in-transaction event MUST remain
- AND a sanitized failure event MUST append in a fresh transaction

#### Scenario: Application policy denies

- GIVEN policy denies an application operation
- WHEN denial is returned
- THEN no business write MUST occur
- AND a sanitized denial event MUST append in a separate transaction

### Requirement: Deferred Sensitive Audit Reads

Sensitive audit reads MUST remain denied in this delivery. They MUST NOT be authorized, and metadata, `scope_kind`, or `scope_ref` MUST NOT be added, until domain relationships and typed scope representation exist.

#### Scenario: Sensitive audit read is requested

- GIVEN a caller requests a sensitive audit read
- WHEN authorization is evaluated in this delivery
- THEN the read MUST be denied and no audit data returned

### Requirement: Separated Database Capabilities

Owner, migrator, and runtime capabilities MUST be separate. Owner MUST be non-login; only migration capability MAY assume it. Roles MUST be provisioned outside application migrations. Runtime MUST NOT own audit objects, administer roles, perform DDL, assume privileged capability, or execute audit `UPDATE`, `DELETE`, or `TRUNCATE`. Runtime MAY append only approved columns and read only as required. Triggers MUST independently reject those mutations.

#### Scenario: PostgreSQL 17 defenses are verified

- GIVEN separately provisioned owner, migrator, runtime, and verification capabilities
- WHEN runtime and an independent verifier attempt audit `UPDATE`, `DELETE`, or `TRUNCATE`
- THEN ACLs MUST reject runtime and triggers MUST reject the verifier
- AND verification MUST prove ownership, grants, separation, and triggers
- AND history MUST remain unchanged

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

### Requirement: Consultation Catalog and Agenda Interval Evidence

Consultation Type creation, modification, deactivation, reactivation, and Agenda Interval change outcomes MUST be auditable as `allowed`, `denied`, `succeeded`, or `failed` under the existing minimized, server-controlled event contract. Evidence MUST identify the actor and affected Professional, Consultation Type, or agenda by stable references without storing names, colors, prices, interval values, booking snapshots, or other mutable catalog data. Successful business changes and their required events MUST commit atomically; denied and rolled-back failed outcomes MUST be appended separately without business effects. Events MUST remain immutable, and corrections MUST append rather than replace history.

#### Scenario: Catalog lifecycle change succeeds

- GIVEN an authorized catalog lifecycle operation passes business validation
- WHEN the operation succeeds
- THEN its change and sanitized `succeeded` event MUST commit atomically
- AND the event MUST contain no mutable catalog values

#### Scenario: Agenda Interval application succeeds

- GIVEN an authorized Agenda Interval change preserves every active interval count and produces no duration over 240 minutes
- WHEN the Professional confirms with `Aplicar intervalo` and the complete change succeeds
- THEN one sanitized outcome MUST evidence the successful atomic operation
- AND no event MUST imply a replacement, individual adaptation, or partial application

#### Scenario: Operation is denied

- GIVEN catalog or Agenda Interval authorization is denied
- WHEN denial is returned
- THEN no business effect MUST occur
- AND a sanitized `denied` event MUST append in a separate transaction

#### Scenario: Business change or required audit fails

- GIVEN an allowed catalog or Agenda Interval change requires an audit event
- WHEN the business change or required append fails
- THEN the business change and in-transaction event MUST both roll back
- AND a sanitized `failed` event MUST append separately after rollback

#### Scenario: Evidence requires correction

- GIVEN a stored catalog or Agenda Interval event requires correction
- WHEN correction is recorded
- THEN a new sanitized event MUST be appended and the original MUST remain unchanged
