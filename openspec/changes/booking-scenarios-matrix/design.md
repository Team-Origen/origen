# Booking Scenarios Matrix — Technical Design

## Overview

This design translates the [specification](spec.md) into concrete implementation for the `Origen.Bookings` context. It covers database schema, context API, authorization rules, state machine, snapshot logic, and concurrency control.

## Database Schema

### Appointments Table (`appointments`)

```elixir
# appointments table
- id: bigserial PRIMARY KEY
- professional_id: bigint NOT NULL REFERENCES internal_accounts(id) ON DELETE RESTRICT
- patient_id: bigint NOT NULL REFERENCES patients(id) ON DELETE RESTRICT
- consultation_type_id: uuid NOT NULL REFERENCES consultation_types(id) ON DELETE RESTRICT
- consultation_type_snapshot: jsonb NOT NULL
  # {name: string, duration_minutes: integer, price_ars: decimal(12,2)}
- agenda_interval_minutes: integer NOT NULL
- starts_at: timestamptz(6) NOT NULL
- ends_at: timestamptz(6) NOT NULL
- state: varchar(32) NOT NULL DEFAULT 'solicitado'
  # CHECK (state IN ('solicitado', 'reservado', 'confirmado', 'asistio', 'cancelado', 'no_asistio'))
- booked_by_actor: varchar(16) NOT NULL
  # CHECK (booked_by_actor IN ('patient', 'secretary', 'professional'))
- booked_by_account_id: bigint NOT NULL REFERENCES internal_accounts(id) ON DELETE RESTRICT
- confirmed_at: timestamptz(6)
- cancelled_at: timestamptz(6)
- cancellation_reason: text
- created_at: timestamptz(6) NOT NULL DEFAULT clock_timestamp()
- updated_at: timestamptz(6) NOT NULL DEFAULT clock_timestamp()
```

**Indexes:**
- `idx_appointments_professional_starts_at` ON (professional_id, starts_at) — overlap queries
- `idx_appointments_patient_starts_at` ON (patient_id, starts_at) — patient overlap queries
- `idx_appointments_consultation_type_id` ON (consultation_type_id) — catalog queries
- `idx_appointments_state` ON (state) — state filtering

**Constraints:**
- `appointments_professional_time_overlap_excl` — EXCLUDE USING gist (professional_id WITH =, tsrange(starts_at, ends_at) WITH &&) — prevents professional double-booking
- `appointments_patient_time_overlap_excl` — EXCLUDE USING gist (patient_id WITH =, tsrange(starts_at, ends_at) WITH &&) — prevents patient double-booking
- `appointments_duration_check` — CHECK (ends_at > starts_at)

### Professional-Patient Relationships Table (`professional_patient_relationships`)

```elixir
# professional_patient_relationships table
- id: bigserial PRIMARY KEY
- professional_id: bigint NOT NULL REFERENCES internal_accounts(id) ON DELETE RESTRICT
- patient_id: bigint NOT NULL REFERENCES patients(id) ON DELETE RESTRICT
- first_booking_id: bigint NOT NULL REFERENCES appointments(id) ON DELETE RESTRICT
- created_at: timestamptz(6) NOT NULL DEFAULT clock_timestamp()
```

**Indexes:**
- `idx_ppr_professional_patient` UNIQUE ON (professional_id, patient_id) — one relationship per pair
- `idx_ppr_first_booking_id` ON (first_booking_id) — relationship origin

**Note on Patient Identity:**
Patients are authenticated via Google OAuth or Magic Link (PAT-01). Their internal representation uses a `patients` table with a reference to the OAuth/Magic Link subject. The `patient_id` FK targets this table.

## Context Structure

```
lib/origen/bookings/
├── appointment.ex              # Ecto schema + changesets
├── booking.ex                  # Public API: create_booking/2, transition_state/3
├── eligibility.ex              # Actor eligibility checks (BOOK-01/02/03)
├── availability.ex             # Slot validation, overlap detection
├── state_machine.ex            # State transitions + D-1 window logic
├── snapshots.ex                # Snapshot capture from consultation type
├── relationship.ex             # Professional-Patient relationship
├── validators.ex               # Composed validators for create_booking
└── errors.ex                   # Error types for booking operations
```

## Core API

### `Origen.Bookings.create_booking(actor, params)`

**Actor:**
```elixir
%{
  type: :patient | :secretary | :professional,
  account_id: integer(),
  # For patient: profile_id, phone_verified
  # For secretary: center_scope_id
  # For professional: allowed_patient_ids (or query)
}
```

**Params:**
```elixir
%{
  professional_id: integer(),        # Target professional (internal_accounts.id)
  patient_id: integer(),             # Target patient (patients.id)
  consultation_type_id: binary(),    # UUID of consultation type
  starts_at: DateTime.t(),           # Appointment start (UTC)
  # Optional for secretary/professional:
  initial_state: :solicitado | :reservado | :confirmado,
  agreement_declaration: boolean()   # Required when initial_state == :confirmado outside D-1
}
```

**Returns:**
```elixir
{:ok, %Appointment{}} | {:error, %BookingError{}}
```

**Flow:**
1. Authorization check via `Origen.Authorization.Rules.decide/1` with BOOK-01/02/03
2. Eligibility validation per actor (`Eligibility.validate/2`)
3. Consultation type validation (ownership, active, snapshot)
4. Availability & overlap validation (`Availability.validate/2`)
5. D-1 window & initial state assignment (`StateMachine.initial_state/3`)
6. Atomic transaction:
   - Insert appointment
   - Insert professional-patient relationship (if first booking)
   - Write audit event
7. Return appointment

### `Origen.Bookings.transition_state(appointment, new_state, actor)`

Validates and executes state transitions per the state machine. Only allows valid transitions from current state.

## Authorization Rules (BOOK-01, BOOK-02, BOOK-03)

Added to `Origen.Authorization.Rules` as new rule entries:

```elixir
# BOOK-01: Paciente autónomo - S1-11
{:book_01, :create_booking, {:role, :patient}, :active,
 %{profile_complete: true, phone_verified: true, own_profile: true},
 %{consultation_type: :active_owned, availability: :valid, overlap: :none, d1_window: :valid}},

# BOOK-02: Secretaría asistida - S1-12
{:book_02, :create_booking, {:role, :secretary}, :active,
 %{center_scope: :valid, minimum_identity: :complete},
 %{consultation_type: :active_owned, availability: :valid, overlap: :none, d1_window: :valid, state: :valid}},

# BOOK-03: Profesional sobre paciente relacionado - S1-13
{:book_03, :create_booking, {:role, :professional}, :active,
 %{patient_related: true, patient_in_allowed_list: true},
 %{consultation_type: :active_owned, availability: :valid, overlap: :none, d1_window: :valid, state: :valid}},
```

**Request Structure for Booking:**
```elixir
%Origen.Authorization.Request{
  operation: {:known, :create_booking},
  subject: {:role, :patient | :secretary | :professional},
  account_state: :active | :pending_activation,
  target: %{
    professional_id: integer(),
    patient_id: integer(),
    consultation_type_id: binary(),
    starts_at: DateTime.t()
  },
  scope: %{
    # Actor-specific scope facts
    profile_complete: boolean(),
    phone_verified: boolean(),
    own_profile: boolean(),
    center_scope: :valid | :invalid,
    minimum_identity: :complete | :incomplete,
    patient_related: boolean(),
    patient_in_allowed_list: boolean(),
    consultation_type: :active_owned | :inactive | :foreign,
    availability: :valid | :invalid,
    overlap: :none | :professional | :patient,
    d1_window: :valid | :invalid,
    state: :valid | :invalid
  }
}
```

## Eligibility Validation

### Paciente Autónomo (BOOK-01)
- Authenticated via PAT-01 (Google OAuth / Magic Link)
- Own profile selected (`own_profile: true`)
- Profile complete (all mandatory fields)
- Primary notification phone verified (`phone_verified: true`)
- No prior relationship with professional required

### Secretaría Asistida (BOOK-02)
- Internal account `Activa`
- Patient within center's operational scope (`center_scope: :valid`)
- Can create/reuse Persona with minimum identity:
  - Nombres, apellidos
  - Tipo de documento controlado
  - Número normalizado
  - Fecha de nacimiento
- Other fields may remain pending

### Profesional (BOOK-03)
- Internal account `Activa`
- Patient already in allowed list (previous successful booking created relationship)
- Cannot access global registry or use manipulated identifiers

## Availability & Overlap Validation (RF-12)

### Contiguous Intervals Check
- Get professional's `agenda_interval_minutes` from consultation type catalog
- Calculate required intervals: `ceil(duration_minutes / agenda_interval_minutes)`
- Query professional's availability for the time range
- Verify enough contiguous intervals exist

### Overlap Detection
- Professional overlap: EXCLUDE constraint on `(professional_id, tsrange(starts_at, ends_at))`
- Patient overlap: EXCLUDE constraint on `(patient_id, tsrange(starts_at, ends_at))`
- Advisory lock on `professional_id` during validation + insert for extra safety

## D-1 Window & Initial State Assignment (RF-10)

**Organization Clock:** Uses configured timezone (default: America/Argentina/Buenos_Aires). D-1 = calendar day before appointment date in org timezone. Cutoff = 23:59 D-1 org time.

| Actor | Timing | Modality | Initial State | Notes |
|-------|--------|----------|---------------|-------|
| Patient | Before D-1 | Manual | `solicitado` | Awaits professional approval |
| Patient | Before D-1 | Automatic | `reservado` | Follows WhatsApp flow |
| Patient | D-1 (until 23:59) | Any | `confirmado` | Direct, no intermediate |
| Patient | Día D | — | **Denied** | Only waitlist/direct assignment |
| Secretary | Before D-1 | — | `reservado` or `confirmado` | Never `solicitado`; `confirmado` needs agreement |
| Secretary | D-1 | — | `confirmado` | Agreement required |
| Secretary | Día D | Direct | `confirmado` | Until slot start; waitlist exit if applicable |
| Professional | Before D-1 | — | `reservado` | Follows WhatsApp flow |
| Professional | D-1 | — | `confirmado` | No WhatsApp |
| Professional | Día D | Direct | `confirmado` | Until slot start |

**Validation:** Invalid state for actor/timing → reject entire operation.

## Atomic Transaction

All persistence happens in a single `Repo.transaction/2`:

```elixir
Repo.transaction(fn ->
  appointment = Repo.insert!(appointment_changeset)
  relationship = maybe_create_relationship(appointment)
  Audit.Writer.append(booking_audit_event(appointment, relationship), {:allow, :sys_01})
  {:ok, appointment}
end)
```

**Rollback Guarantees:**
- Any failure (appointment, relationship, audit) → full rollback
- No partial state persists
- No professional-patient relationship from failed attempt

## Snapshot Logic

On booking creation, capture from consultation type:
```elixir
%{
  name: type.name,
  duration_minutes: type.interval_count * professional.agenda_interval_minutes,
  price_ars: type.exact_price_ars
}
```

Store as JSONB in `consultation_type_snapshot`. Also store `agenda_interval_minutes` at booking time.

**Color:** Resolved at display time from current consultation type, never snapshotted.

## Concurrency Control

1. **Database-level:** EXCLUDE constraints prevent double-booking at commit time
2. **Application-level:** Advisory lock on `professional_id` during validation + insert
   ```elixir
   Repo.query("SELECT pg_advisory_xact_lock($1)", [professional_id])
   ```
3. **Test scenarios:** Concurrent requests for same slot must result in exactly one persisted appointment

## State Machine

Valid states: `solicitado`, `reservado`, `confirmado`, `asistio`, `cancelado`, `no_asistio`

Valid transitions (initial → next):
- `solicitado` → `reservado` (professional approves), `cancelado` (rejected)
- `reservado` → `confirmado` (patient confirms / WhatsApp), `cancelado`
- `confirmado` → `asistio`, `no_asistio`, `cancelado`
- `asistio`, `no_asistio`, `cancelado` → (terminal)

## Error Types

```elixir
defmodule Origen.Bookings.Errors do
  @type t ::
    {:eligibility_failed, reason :: atom()}
    | {:authorization_denied, reason :: atom()}
    | {:consultation_type_invalid, reason :: atom()}
    | {:availability_failed, reason :: atom()}
    | {:overlap_detected, target :: :professional | :patient}
    | {:d1_window_violation, reason :: atom()}
    | {:invalid_initial_state, reason :: atom()}
    | {:pending_fine_block}
    | {:transaction_failed, reason :: atom()}
    | {:concurrency_conflict}
    | {:state_transition_invalid, from :: atom(), to :: atom()}
end
```

## Migration Strategy

1. Create `appointments` table with all columns, constraints, indexes
2. Create `professional_patient_relationships` table
3. Create EXCLUDE constraints using `btree_gist` extension
4. Add `btree_gist` extension if not present

## Test Strategy

- Unit tests for each validator module
- Integration tests for `create_booking` with all 3 actors
- Concurrency tests using `Task.async` + `Task.await`
- Authorization tests per matrix (S1-11, S1-12, S1-13)
- D-1 window tests with time travel
- Rollback tests with forced failures
- Snapshot persistence tests

## Dependencies

- `btree_gist` PostgreSQL extension for EXCLUDE constraints
- `consultation_type_catalog_adapter` configured for snapshot capture
- Organization timezone configuration for D-1 calculations
- Audit writer configured (`:sys_01` channel)

## Open Questions

1. **Patient table schema** — Need to confirm `patients` table structure from PAT-01 implementation
2. **Organization timezone** — Config location for D-1 calculations
3. **Consultation type catalog adapter** — Production implementation needed for snapshot capture
4. **Fine tracking** — Where pending fines are stored/queried for BOOK-01 block

---

**Status**: Draft — ready for Tasks phase
**Version**: 0.1-draft
**Date**: 2026-09-21
**Author**: @Saidqr (orchestrator-assisted)