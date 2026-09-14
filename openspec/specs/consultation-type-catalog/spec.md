# Consultation Type Catalog Specification

## Purpose

Define each Professional's consultation catalog, booking snapshots, and downstream use.

## Requirements

### Requirement: Professional-owned Catalog Entries

Each Consultation Type MUST have an immutable identity and exactly one owning Professional. Its mutable fields MUST include an active state, a required normalized name of at most 32 characters, an exact non-negative ARS base price with no more than two decimal places, a `#RRGGBB` color, and an agenda-interval count. Name normalization MUST NOT impose uniqueness; duplicate normalized names MAY coexist for one Professional. An active type's interval count MUST be from 1 through the effective maximum defined by the owner's Agenda Interval; an inactive type MAY retain a count above the current effective maximum but MUST receive an explicit valid replacement as part of atomic reactivation. No business maximum MAY be imposed on an otherwise exactly representable valid price.

#### Scenario: Valid duplicate name

- GIVEN a Professional owns an active type with a normalized name
- WHEN the Professional creates another valid type with the same normalized name
- THEN the system MUST retain both under distinct immutable identities
- AND selection MUST distinguish them by duration and price

#### Scenario: Invalid catalog fields

- GIVEN a name is empty after normalization or exceeds 32 characters, a price is negative or has more than two decimals, a color is not `#RRGGBB`, or an interval count is outside its effective range
- WHEN catalog creation or modification is requested
- THEN the system MUST reject the request without changing the catalog

### Requirement: Derived Duration and Booking Snapshots

A Consultation Type's current duration MUST equal its interval count multiplied by its owner's current Agenda Interval and MUST be at most 240 minutes. A new booking MUST snapshot the selected type's current normalized name, resulting duration in minutes, and exact ARS base price. Bookings MUST store and display duration as minutes, never as an interval count. Later catalog or Agenda Interval changes MUST NOT alter any existing snapshot.

#### Scenario: Booking captures current values

- GIVEN an active type has a valid name, resulting duration, and ARS price
- WHEN a new booking selects it
- THEN the booking MUST retain exact snapshots of those three values
- AND its duration MUST be represented in minutes

#### Scenario: Catalog values change later

- GIVEN an existing booking contains snapshots from a Consultation Type
- WHEN that type or its owner's Agenda Interval is later changed
- THEN every existing booking snapshot MUST remain unchanged

### Requirement: Lifecycle and Current Color

A Consultation Type MAY be deactivated without deleting its identity or historical references. An inactive type MUST NOT be selected for a new booking. Edits and deactivation MUST affect only future selection. Every booking that references the type MUST use its current color, including after color edits or deactivation; color MUST NOT be snapshotted.

#### Scenario: Type with history is deactivated

- GIVEN a Consultation Type is referenced by existing bookings
- WHEN its owner deactivates it
- THEN those bookings and their snapshots MUST remain available
- AND the type MUST be unavailable for new bookings

#### Scenario: Current color changes

- GIVEN existing bookings reference a Consultation Type
- WHEN its color is changed to another valid value
- THEN those bookings MUST use the new current color without changing their snapshots

### Requirement: Accessible and Unambiguous Selection

Any presentation of a Consultation Type MUST preserve applicable WCAG AA contrast and MUST provide a non-color cue. Selectors MUST show name, duration in minutes, and price so duplicate names remain distinguishable.

#### Scenario: Color cannot be perceived

- GIVEN a person cannot distinguish the displayed type by color
- WHEN consultation types or bookings are presented
- THEN text or another non-color cue MUST identify the type and state

### Requirement: Availability and Waiting-list Compatibility

Availability and waiting-list matching MUST use the selected active Consultation Type's immutable identity, owner, and current resulting duration. A candidate time MUST contain enough contiguous owner Agenda Intervals for that duration. Another type with the same name MUST NOT be treated as equivalent.

#### Scenario: Candidate time is evaluated

- GIVEN an active type requires a known number of its owner's Agenda Intervals
- WHEN availability or a waiting-list opportunity is evaluated
- THEN only a contiguous candidate fitting that exact type and duration MUST qualify

#### Scenario: Same name identifies another type

- GIVEN two types share a normalized name but differ by identity, duration, or price
- WHEN a waiting-list request targets one type
- THEN the other type MUST NOT satisfy the request
