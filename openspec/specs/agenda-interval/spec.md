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

### Requirement: Atomic Interval Adaptation

When an Agenda Interval change would make one or more active Consultation Types incompatible, the Professional MUST explicitly assign a valid replacement count to every affected active type and confirm the interval plus all replacements as one atomic operation. The system MUST NOT infer, clamp, or automatically reduce any count. Compatible counts MUST remain unchanged. If any affected active type lacks a valid explicit replacement, the system MUST reject the whole operation and leave the interval and catalog unchanged. Existing booking durations and other snapshots MUST remain unchanged.

#### Scenario: Active types require adaptation

- GIVEN active types have counts both within and above the proposed effective maximum
- WHEN the owner explicitly assigns a valid replacement to every incompatible type and confirms the complete change
- THEN the interval and all explicit replacements MUST become effective atomically
- AND compatible counts and existing booking snapshots MUST remain unchanged

#### Scenario: Explicit replacement is missing or invalid

- GIVEN a proposed Agenda Interval would make one or more active types incompatible
- WHEN any affected type lacks an explicit replacement or has a replacement outside the new effective range
- THEN the interval and every Consultation Type MUST retain their prior values
- AND the system MUST NOT infer or alter any replacement count

### Requirement: Inactive Type Reactivation

An inactive Consultation Type MAY retain an incompatible count while inactive. To reactivate it, the Professional MUST explicitly assign a valid replacement count and confirm that replacement with reactivation as one atomic operation. The system MUST NOT infer, clamp, or automatically reduce the count. Missing or invalid explicit replacement MUST reject the whole reactivation unchanged. Existing booking snapshots MUST remain unchanged.

#### Scenario: Incompatible inactive type is reactivated

- GIVEN an inactive type's count exceeds its owner's current effective maximum
- WHEN its owner explicitly assigns a valid replacement count and confirms reactivation
- THEN the replacement and reactivation MUST succeed atomically before the type becomes selectable
- AND existing booking snapshots MUST remain unchanged

#### Scenario: Incompatible inactive type lacks a valid replacement

- GIVEN an inactive type's count exceeds its owner's current effective maximum
- WHEN reactivation omits an explicit replacement or provides an invalid one
- THEN the type MUST remain inactive with its prior count unchanged
- AND the system MUST NOT infer or alter a replacement count
