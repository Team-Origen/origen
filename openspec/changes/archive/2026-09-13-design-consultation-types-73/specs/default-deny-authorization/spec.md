# Delta for Default-deny Authorization

## ADDED Requirements

### Requirement: Consultation Catalog and Agenda Interval Ownership

Only an authenticated Professional with an active account and an explicit authorization grant MAY change that Professional's own Agenda Interval, create a Consultation Type for that Professional's own profile, or modify, deactivate, or reactivate a type owned by that profile. Every decision MUST establish actor, operation, account state, target identity, and ownership. Administrator, Secretary, Patient, unauthenticated, unknown, missing, or mismatched facts MUST be denied without agenda or catalog effects.

#### Scenario: Owner changes own configuration

- GIVEN an active authenticated Professional owns the target profile and the operation is explicitly granted
- WHEN that Professional submits a valid Agenda Interval or catalog change
- THEN authorization MUST allow the operation to proceed to business validation

#### Scenario: Actor targets another Professional's configuration

- GIVEN any actor targets another Professional's Agenda Interval or Consultation Type
- WHEN ownership authorization is evaluated
- THEN the request MUST be denied without revealing or changing the configuration

#### Scenario: Privileged-sounding role lacks grant

- GIVEN an Administrator, Secretary, or Patient requests an Agenda Interval or catalog mutation
- WHEN no explicit operation grants that actor the mutation
- THEN the request MUST be denied without agenda or catalog effects

### Requirement: Consultation Type Selection Eligibility

Every booking operation that selects a Consultation Type MUST be explicitly authorized under its own matrix rule and MUST establish that the selected type is active and owned by the booking's target Professional. Missing or mismatched ownership, inactive state, unknown operation, or absent relationship facts MUST deny selection without booking effects. Catalog ownership MUST NOT itself grant authority to create a booking.

#### Scenario: Authorized operation selects active owned type

- GIVEN a booking operation is explicitly authorized and its target Professional owns the selected active type
- WHEN selection authorization is evaluated
- THEN the operation MAY proceed to booking validation

#### Scenario: Inactive or mismatched type is selected

- GIVEN an otherwise authorized booking request selects an inactive type or a type owned by another Professional
- WHEN selection authorization is evaluated
- THEN the request MUST be denied without creating or changing a booking

#### Scenario: Catalog owner lacks booking grant

- GIVEN a Professional owns the selected active Consultation Type
- WHEN that Professional requests a booking operation not explicitly granted by the matrix
- THEN the request MUST be denied despite catalog ownership
