# Agenda Interval Specification

## Purpose

Define a Professional's scheduling granularity and safe changes to it.

## Requirements

### Requirement: Professional Agenda Interval

Each Professional MUST own one Agenda Interval, defaulting to 30 minutes. It MUST be configurable from 5 through 240 minutes inclusive in five-minute steps. Agenda Interval means scheduling granularity and MUST remain distinct from the future-booking Period or window.

#### Scenario: Default interval

- GIVEN a Professional has no prior Agenda Interval setting
- WHEN the Professional's agenda configuration is established
- THEN the Agenda Interval MUST be 30 minutes

#### Scenario: Invalid interval

- GIVEN a proposed value is below 5, above 240, or not divisible by five minutes
- WHEN an Agenda Interval change is requested
- THEN the system MUST reject it without changing the interval or catalog

### Requirement: Effective Consultation Count

For an Agenda Interval of `interval_minutes`, the maximum Consultation Type count MUST equal `min(10, floor(240 / interval_minutes))`. A valid active type MUST use at least one interval and MUST NOT exceed that effective maximum, so its resulting duration is never greater than 240 minutes.

#### Scenario: Maximum is constrained by duration

- GIVEN a Professional's Agenda Interval is 60 minutes
- WHEN a Consultation Type count is validated
- THEN counts from 1 through 4 MUST be accepted by duration bounds
- AND a count of 5 or more MUST be rejected

#### Scenario: Ten-count cap applies

- GIVEN a Professional's Agenda Interval is 5 minutes
- WHEN a Consultation Type count is validated
- THEN the maximum valid count MUST be 10 despite the 240-minute ceiling allowing more

### Requirement: Agenda Interval Application

Selecting a new Agenda Interval MUST warn the Professional that active Consultation Type durations will change. Every active type MUST preserve its interval count, and its duration MUST be recalculated from that count and the proposed interval without replacement or individual adaptation. If any resulting active duration would exceed 240 minutes, application MUST be blocked, the interval and catalog MUST remain unchanged, and every blocking type MUST be identified unambiguously while records and actions remain bound to immutable identities. If no active type would exceed 240 minutes, the Professional MUST explicitly confirm with `Aplicar intervalo`, and the interval plus all recalculated active durations MUST become effective atomically. Inactive historical durations, existing booking durations, and other booking snapshots MUST remain unchanged.

#### Scenario: Active durations are recalculated

- GIVEN every active type's preserved count produces a duration of no more than 240 minutes under a proposed Agenda Interval
- WHEN the owner selects the interval, reviews the warning, and confirms with `Aplicar intervalo`
- THEN the interval and every recalculated active duration MUST become effective atomically
- AND all interval counts, inactive historical durations, and existing booking snapshots MUST remain unchanged

#### Scenario: Active types block application

- GIVEN a proposed Agenda Interval would make one or more active types exceed 240 minutes using their preserved counts
- WHEN the owner attempts to apply the interval
- THEN the interval and every Consultation Type MUST retain their prior values
- AND the system MUST identify every blocking type unambiguously by presentation while binding each record and action to its immutable identity

### Requirement: Inactive Type Reactivation

An inactive Consultation Type MUST preserve both its interval count and the historical duration it had when deactivated. Agenda Interval changes MUST NOT alter that historical duration. Reactivation MUST derive the active duration from the preserved count and the current Agenda Interval without replacement or adaptation. If that duration would exceed 240 minutes, the system MUST reject reactivation unchanged and identify the type unambiguously. Existing booking snapshots MUST remain unchanged.

#### Scenario: Incompatible inactive type is reactivated

- GIVEN an inactive type's preserved count produces a duration of no more than 240 minutes under its owner's current Agenda Interval
- WHEN its owner confirms reactivation
- THEN reactivation MUST succeed with the preserved count and current derived duration before the type becomes selectable
- AND existing booking snapshots MUST remain unchanged

#### Scenario: Inactive type exceeds the current duration maximum

- GIVEN an inactive type's preserved count would produce a duration greater than 240 minutes under its owner's current Agenda Interval
- WHEN its owner requests reactivation
- THEN the type MUST remain inactive with its preserved count and historical duration unchanged
- AND the system MUST identify the rejected type without offering replacement or adaptation
