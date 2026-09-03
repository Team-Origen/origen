# Append-only Audit Specification

## Purpose

Define minimized events, transactions, and deferred reads.

## Requirements

### Requirement: Minimized Server-controlled Events

Events MUST contain only a PostgreSQL-generated bigint identity, actor kind/reference, event, entity kind/reference, result, and timestamp. Kind/result fields MUST allow at most 32 characters, event 64, and references 128. Actor kind, event, and entity kind MUST be snake_case text governed by internal constructors and allowlists. PostgreSQL MUST constrain result to exactly `allowed`, `denied`, `succeeded`, or `failed`. Timestamp MUST be server-controlled `timestamptz(6)` populated by `clock_timestamp()` on insertion. PostgreSQL constraints MUST enforce valid nullability combinations. Metadata, JSON, `scope_kind`, `scope_ref`, caller timestamps, secrets, and unnecessary sensitive values MUST NOT be stored.

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
