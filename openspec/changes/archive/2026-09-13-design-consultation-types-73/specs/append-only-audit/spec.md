# Delta for Append-only Audit

## ADDED Requirements

### Requirement: Consultation Catalog and Agenda Interval Evidence

Consultation Type creation, modification, deactivation, reactivation, and Agenda Interval change outcomes MUST be auditable as `allowed`, `denied`, `succeeded`, or `failed` under the existing minimized, server-controlled event contract. Evidence MUST identify the actor and affected Professional, Consultation Type, or agenda by stable references without storing names, colors, prices, interval values, booking snapshots, or other mutable catalog data. Successful business changes and their required events MUST commit atomically; denied and rolled-back failed outcomes MUST be appended separately without business effects. Events MUST remain immutable, and corrections MUST append rather than replace history.

#### Scenario: Catalog lifecycle change succeeds

- GIVEN an authorized catalog lifecycle operation passes business validation
- WHEN the operation succeeds
- THEN its change and sanitized `succeeded` event MUST commit atomically
- AND the event MUST contain no mutable catalog values

#### Scenario: Agenda adaptation succeeds

- GIVEN an authorized Agenda Interval change includes every required explicit active-type replacement
- WHEN the complete change succeeds
- THEN one sanitized outcome MUST evidence the successful atomic operation
- AND no event MUST imply an inferred replacement or partial adaptation

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
