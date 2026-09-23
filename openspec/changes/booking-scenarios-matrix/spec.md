# Booking Scenarios Matrix Specification

## Purpose

Define the complete booking operation for three authorized pathways — Paciente autónomo (BOOK-01), Secretaría asistida (BOOK-02), and Profesional sobre Paciente relacionado (BOOK-03) — with atomic persistence, explicit authorization, eligibility validation, overlap detection, D-1 window enforcement, and durable scenario coverage.

## Scope

This specification covers the **booking creation operation only**. Subsequent appointment management (approval, confirmation, cancellation, attendance, waitlist, payments, reports) is out of scope.

## Definitions

| Term | Definition |
|------|------------|
| **D-1** | Calendar day immediately preceding the appointment date, evaluated on organization clock |
| **Día D** | Calendar day of the appointment itself |
| **Corte público/autónomo** | 23:59 D-1 (organization timezone) — autonomous booking closes; Secretaría/Profesional direct assignment allowed until slot start |
| **Atómico** | Appointment + Profesional–Paciente relationship + snapshots + audit event persist or rollback as one unit; no partial subset persists |
| **Snapshot** | Name, duration_minutes, price_ARS copied from Consultation Type at booking time; color resolves from current type; agenda interval count NOT conserved |
| **Actor** | Authenticated principal: Paciente (via PAT-01), Secretaría (internal Activa), Profesional (internal Activa) |

## Requirements

### Requirement: Booking Operation Existence

The system MUST provide a booking creation operation for each authorized actor-pathway combination declared in the Authorization Matrix v0.6-draft.

#### Scenario: Three authorized pathways exist
- GIVEN the Authorization Matrix declares S1-11/BOOK-01, S1-12/BOOK-02, S1-13/BOOK-03
- WHEN the backend evaluates a booking request
- THEN exactly these three pathways MAY be allowed; all other role–operation combinations MUST be denied

#### Scenario: Default deny for undeclared pathways
- GIVEN any role–operation combination not in {S1-11, S1-12, S1-13}
- WHEN authorization is evaluated
- THEN the decision MUST deny without business effects

---

### Requirement: Actor Eligibility (Preconditions)

Each pathway MUST enforce its specific eligibility preconditions before any availability or state validation.

#### Scenario: Paciente autónomo eligibility (BOOK-01)
- GIVEN a Paciente authenticated via PAT-01 (Google OAuth or Magic Link) with own profile selected
- AND the profile is complete (all mandatory fields)
- AND the primary notification recipient phone is verified
- WHEN the Paciente requests a booking
- THEN eligibility MUST be satisfied

#### Scenario: Paciente autónomo denied — incomplete profile
- GIVEN a Paciente with incomplete own profile
- WHEN attempting autonomous booking
- THEN the system MUST deny without creating appointment, relationship, or business audit (only denied attempt logged without sensitive data)

#### Scenario: Paciente autónomo denied — phone not verified
- GIVEN a Paciente with complete profile but unverified primary notification phone
- WHEN attempting autonomous booking
- THEN the system MUST deny without creating appointment or relationship

#### Scenario: Paciente autónomo denied — foreign or represented profile
- GIVEN a Paciente session operating on a non-selected or represented profile
- WHEN requesting a booking
- THEN the system MUST deny — not the selected own profile under PAT-01

#### Scenario: Secretaría asistida eligibility (BOOK-02)
- GIVEN Secretaría with internal Activa account
- AND a Persona/Patient within the center's operational scope (existing or newly created with minimum identity: names, surnames, controlled document type, normalized number, date of birth)
- WHEN Secretaría requests assisted booking
- THEN eligibility MUST be satisfied even if other profile fields remain pending

#### Scenario: Secretaría denied — duplicate document
- GIVEN document type and number match an existing Persona
- WHEN Secretaría attempts to create a new Persona with that identity
- THEN the system MUST reject duplicate creation without merging or overwriting history
- AND MUST guide to reuse the existing Persona

#### Scenario: Secretaría denied — patient outside center scope
- GIVEN a Persona/profile not within the Secretaría's center operational scope
- WHEN attempting assisted booking
- THEN the system MUST deny the operation

#### Scenario: Secretaría denied — incomplete minimum identity before first booking
- GIVEN one or more minimum identity fields missing (names, surnames, document type/number, date of birth)
- WHEN Secretaría attempts to confirm first booking
- THEN the system MUST reject until those fields are complete, without blocking other non-minimum pending data

#### Scenario: Profesional eligibility (BOOK-03)
- GIVEN Profesional with internal Activa account
- AND the Patient already belongs to the Profesional's allowed list (established by a previous successful first booking)
- WHEN Profesional creates a new appointment for that Patient
- THEN eligibility MUST be satisfied

#### Scenario: Profesional denied — patient not related
- GIVEN a Patient not in the Profesional's allowed list
- WHEN Profesional attempts to create an appointment for that Patient
- THEN the system MUST deny and audit the out-of-scope attempt

#### Scenario: Profesional denied — global registry access or manipulated identifier
- GIVEN Profesional attempts to list, search, or query Patients outside allowed list, even via manipulated identifier
- WHEN executing the request
- THEN the system MUST deny in backend and audit the attempt without exposing global registry

---

### Requirement: Consultation Type Validation

Every booking MUST validate the selected Consultation Type against ownership, active state, and identity.

#### Scenario: Valid active owned type
- GIVEN an active Consultation Type owned by the target Professional, identified by immutable identity
- WHEN any authorized actor selects it for booking
- THEN validation MUST pass

#### Scenario: Rejected — inactive, non-existent, or foreign type
- GIVEN an inactive, non-existent, or another Professional's Consultation Type
- WHEN selected for booking
- THEN the system MUST reject without creating appointment or relationship

---

### Requirement: Slot Availability and Overlap Detection (RF-12)

A candidate slot MUST provide enough contiguous agenda intervals for the type's current duration. Overlaps with same Professional or same Patient MUST be rejected.

#### Scenario: Insufficient contiguous intervals
- GIVEN a time slot without enough contiguous agenda intervals for the type's current duration
- WHEN booking is requested for that slot
- THEN the system MUST reject the booking

#### Scenario: Overlap with same Professional's existing appointment
- GIVEN the target Professional already has an appointment overlapping the requested slot
- WHEN a new booking is requested for that slot
- THEN the system MUST reject the new booking and preserve the existing appointment unchanged

#### Scenario: Overlap with Patient's own existing appointment (any Professional)
- GIVEN the Patient already has an appointment (own or via representative) overlapping the requested slot with any Professional
- WHEN a new booking is requested
- THEN the system MUST reject the new booking and preserve the existing appointment unchanged

---

### Requirement: D-1 Window and Initial State Assignment (RF-10)

The initial appointment state MUST be determined by actor, approval modality, and timing relative to D-1.

#### Scenario: Paciente autónomo — before D-1, Manual modality
- GIVEN Paciente autónomo books before D-1 with Professional using Manual approval
- WHEN booking succeeds
- THEN initial state MUST be `Solicitado` (awaits Professional approval)

#### Scenario: Paciente autónomo — before D-1, Automatic modality
- GIVEN Paciente autónomo books before D-1 with Professional using Automatic approval
- WHEN booking succeeds
- THEN initial state MUST be `Reservado` (follows WhatsApp confirmation flow)

#### Scenario: Paciente autónomo — during D-1 (until 23:59), any modality
- GIVEN Paciente autónomo books during D-1 (before 23:59 cutoff)
- WHEN booking succeeds
- THEN initial state MUST be `Confirmado` directly (no Solicitado/Reservado intermediate)

#### Scenario: Paciente autónomo — Día D denied
- GIVEN the requested date is Día D (past 23:59 D-1 cutoff)
- WHEN Paciente attempts autonomous booking for Día D
- THEN the system MUST deny via public/autonomous channel
- AND the only valid pathway for that slot on Día D MUST be waitlist (Manual) or direct assignment by Secretaría/Profesional

#### Scenario: Secretaría — before D-1, explicit state choice
- GIVEN Secretaría books before D-1
- WHEN choosing initial state
- THEN `Reservado` or `Confirmado` allowed (never `Solicitado`)
- AND if `Confirmado` chosen, simple agreement declaration with Patient MUST be recorded

#### Scenario: Secretaría — during D-1
- GIVEN Secretaría books during D-1
- WHEN booking succeeds
- THEN initial state MUST be `Confirmado` (only option)
- AND simple agreement declaration MUST be recorded

#### Scenario: Secretaría — Día D direct assignment
- GIVEN a slot becomes available or is assigned directly on Día D
- WHEN Secretaría executes direct assignment before slot start
- THEN system MUST accept as `Confirmado` with simple declaration
- AND MUST record waitlist exit with reason "Cubierto por asignación directa" if Patient was waitlisted, without altering other waitlist entries

#### Scenario: Profesional — before D-1
- GIVEN Profesional books before D-1
- WHEN booking succeeds
- THEN initial state MUST be `Reservado` (follows WhatsApp confirmation per RF-10, RF-17)

#### Scenario: Profesional — during D-1
- GIVEN Profesional books during D-1
- WHEN booking succeeds
- THEN initial state MUST be `Confirmado` (no WhatsApp confirmation)

#### Scenario: Profesional — Día D direct assignment
- GIVEN a slot becomes available or is assigned directly on Día D
- WHEN Profesional executes direct assignment before slot start
- THEN system MUST accept as `Confirmado` with simple declaration, no WhatsApp

#### Scenario: Invalid state for actor/timing combination
- GIVEN an actor attempts to set a state not permitted for their timing/modality per the initial state table
- WHEN request is submitted
- THEN the system MUST reject the complete operation and require the valid state per the table
- AND if `Confirmado` chosen outside D-1/Día D by Secretaría, MUST require simple agreement declaration before accepting

---

### Requirement: Pending Fine Block (Autonomous Only)

A Patient with a pending fine against a specific Professional MUST be blocked only for autonomous bookings with that Professional.

#### Scenario: Pending fine with same Professional
- GIVEN Patient has a pending fine associated with the chosen Professional
- WHEN Patient attempts autonomous booking with that Professional
- THEN the system MUST block ONLY autonomous bookings with that Professional
- AND MUST allow unchanged: bookings with other Professionals and existing appointments

---

### Requirement: Atomic Persistence and Transactional Rollback

Appointment creation, Profesional–Paciente relationship (if first booking), snapshots, and audit event MUST persist atomically or rollback completely.

#### Scenario: Successful atomic persistence
- GIVEN all validations pass (type, availability, overlap, eligibility, state)
- WHEN persistence is attempted
- THEN the system MUST atomically persist:
  - Appointment record with all fields
  - Profesional–Paciente relationship (if first booking for that pair)
  - Snapshots: consultation type name, duration_minutes, price_ARS
  - Audit event
- AND the relationship MUST be immediately available for subsequent Professional bookings of that Patient

#### Scenario: Transactional rollback on persistence failure
- GIVEN all validations pass
- WHEN persistence of appointment, relationship, snapshots, or audit event fails
- THEN the system MUST rollback the complete operation
- AND NO Profesional–Paciente relationship MUST remain created from a failed attempt

#### Scenario: No partial persistence on any failure
- GIVEN any validation or persistence step fails
- WHEN operation terminates
- THEN NO partial subset (appointment only, relationship only, snapshots only, audit only) MUST persist

---

### Requirement: Concurrent Booking Conflict Resolution

Concurrent requests for the same Professional's overlapping slot MUST result in exactly one persisted appointment.

#### Scenario: Concurrent Paciente autónomo requests
- GIVEN two simultaneous autonomous requests from different Patients for the same Professional's overlapping slot
- WHEN both process in parallel
- THEN exactly ONE valid appointment MUST persist
- AND the losing request MUST receive an observable agenda conflict rejection without partial appointment/relationship/snapshot

#### Scenario: Concurrent Secretaría vs other pathway
- GIVEN Secretaría and (Paciente autónomo OR Profesional) simultaneously request the same Professional's overlapping slot
- WHEN both process nearly simultaneously
- THEN exactly ONE valid appointment MUST persist
- AND the losing request MUST observe an agenda conflict rejection without partial data

#### Scenario: Concurrent Profesional vs other pathway
- GIVEN two simultaneous requests (e.g., Profesional and Secretaría) for the same Professional's available slot
- WHEN both process in parallel
- THEN exactly ONE valid appointment MUST persist
- AND the losing request MUST observe an agenda conflict rejection

---

### Requirement: Profesional–Paciente Relationship

The relationship is created atomically on first successful booking and reused for subsequent Professional bookings.

#### Scenario: First booking creates relationship
- GIVEN first successful booking for a Professional–Patient pair (any authorized pathway)
- WHEN atomic persistence succeeds
- THEN the relationship MUST be created and immediately available for Professional's subsequent bookings

#### Scenario: Subsequent Professional booking does not modify relationship
- GIVEN Profesional books for an already-related Patient
- WHEN booking succeeds
- THEN the operation MUST NOT create or modify the relationship (already exists)

#### Scenario: Relationship persists independently of appointment state
- GIVEN a relationship exists from a previous booking
- WHEN that appointment is cancelled, marked no-show, etc.
- THEN the relationship MUST remain for future Professional bookings

---

### Requirement: Snapshot Integrity

Booking snapshots capture consultation type name, duration, and price at booking time; color resolves from current type; interval count not conserved.

#### Scenario: Snapshot captures current values
- GIVEN an active Consultation Type with valid name, duration, price
- WHEN a new booking selects it
- THEN the booking MUST retain exact snapshots of name, duration_minutes, price_ARS
- AND duration MUST be represented in minutes

#### Scenario: Later catalog/interval changes do not affect existing snapshots
- GIVEN an existing booking with snapshots
- WHEN the Consultation Type or its owner's Agenda Interval is later changed
- THEN every existing booking snapshot MUST remain unchanged

#### Scenario: Color resolves from current type
- GIVEN existing bookings reference a Consultation Type
- WHEN its color is changed
- THEN those bookings MUST use the new current color without changing their snapshots

---

### Requirement: Authorization Enforcement (Default-Deny)

All booking operations MUST be evaluated by the Authorization Rules engine with explicit BOOK-01/02/03 conditions.

#### Scenario: Explicit allow for authorized pathway
- GIVEN a known booking operation and actor matching BOOK-01, BOOK-02, or BOOK-03
- AND all required account-state, target, and scope facts are known and satisfied
- WHEN backend evaluates the request
- THEN the decision MUST allow the operation to proceed to business validation

#### Scenario: Deny for missing/unmet policy fact
- GIVEN any required policy dimension (operation, actor, account state, target ownership, scope) is unknown, missing, or unmet
- WHEN backend evaluates
- THEN decision MUST deny without business effects

#### Scenario: Deny for unknown operation or actor
- GIVEN operation or actor not recognized by approved matrix
- WHEN authorization evaluated
- THEN decision MUST deny

#### Scenario: Deny for missing relationship facts
- GIVEN a matrix rule requires Professional–Patient relationship fact
- AND system cannot establish it
- WHEN authorization evaluated
- THEN decision MUST deny

#### Scenario: No implicit grants — Administrator lacks booking grant
- GIVEN Administrator requests a booking operation not explicitly allowed
- WHEN authorization evaluated
- THEN decision MUST deny despite role name

#### Scenario: Catalog ownership does not grant booking authority
- GIVEN Professional owns the selected active Consultation Type
- WHEN that Professional requests a booking operation not explicitly granted by matrix
- THEN request MUST be denied despite catalog ownership

---

### Requirement: Appointment State Machine

Appointments transition through defined states; invalid transitions are rejected.

#### States
| State | Description |
|-------|-------------|
| `Solicitado` | Initial for Paciente autónomo before D-1 with Manual approval; awaits Professional approval |
| `Reservado` | Approved or created with pending confirmation; active reservation |
| `Confirmado` | Attendance confirmed (by Patient or direct assignment) |
| `Asistió` | Appointment completed/attended |
| `Cancelado` | Cancelled, no longer active reservation |
| `No asistió` | Patient did not attend |

#### Scenario: Valid initial state assignment
- GIVEN a successful booking creation
- WHEN initial state is assigned per actor/timing/modality table
- THEN state MUST be one of the valid initial states for that combination

#### Scenario: Invalid transition rejected
- GIVEN an attempt to transition to a state not permitted from current state
- WHEN transition is requested
- THEN the system MUST reject without changing state

---

## Unresolved Normative Gaps

None — all scenarios trace to Authorization Matrix v0.6-draft, RF-02, RF-02 ter, RF-05, RF-06, RF-07, RF-08, RF-10, RF-10 bis, RF-12, RF-14, RF-23, and existing OpenSpec specs.

## Traceability

| Block | Source |
|-------|--------|
| Operations & scope conditions | `docs/security/AUTHORIZATION_MATRIX.md` (S1-11, S1-12, S1-13, BOOK-01, BOOK-02, BOOK-03) |
| Functional rules | RF-02, RF-02 ter, RF-05, RF-06, RF-07, RF-08, RF-10, RF-10 bis, RF-12, RF-14, RF-23 (`docs/Origen_Documentacion.md`) |
| Duration & intervals | `openspec/specs/agenda-interval/spec.md`, `openspec/specs/consultation-type-catalog/spec.md` |
| Default-deny authorization | `openspec/specs/default-deny-authorization/spec.md` |
| Implementation tasks | T1.6 (first booking shared), T1.7 (Profesional subsequent), T1.9 (Sprint 1 automation) |

---

**Status**: Draft — pending independent review alongside `AUTHORIZATION_MATRIX.md` v0.6-draft
**Version**: 0.1-draft
**Date**: 2026-09-18
**Author**: @Saidqr (orchestrator-assisted)