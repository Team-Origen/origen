# Appointment booking and lifecycle

## Requirements

### Requirement: Three booking channels and privacy

Patient MAY choose a bookable Professional, consultation type, and real available date/time only for themself. Secretary MAY operate every agenda and the full patient list. Professional MAY operate only their agenda; in appointment creation, they MAY select an already related patient or exact-DNI search a registered patient, and MAY use assisted registration when absent. Searching or abandoning MUST NOT create a relationship. Completing either an appointment request or appointment MUST create the Professional–Patient relationship. Professionals MUST NOT view a patient’s appointments, history, or activity with other Professionals. Patient sees all own appointments; Secretary sees centre agendas; Administrator sees none.

#### Scenario: Request creates professional relationship

- GIVEN a Patient has no relationship with a Professional
- WHEN a manual-approval booking completes as `requested`
- THEN the request occupies its slot
- AND the Professional–Patient relationship is created
- AND the Professional cannot see the patient’s activity with another Professional

### Requirement: Approval and occupancy

A Professional MUST choose automatic or manual approval. Automatic mode MUST directly confirm new Patient and Secretary bookings. In manual mode, Patient bookings MUST be requested; a single subconfiguration MUST make Secretary bookings either confirmed directly or requested. Professional-created bookings MUST be confirmed directly. Only the owning Professional MAY accept or reject a pending request. Acceptance confirms and rejection frees the slot. Changing mode affects only new bookings and MUST NOT resolve existing requests.

#### Scenario: Changing mode preserves pending request

- GIVEN a request is pending under manual approval
- WHEN its Professional changes approval mode
- THEN the existing request remains pending and occupies the slot
- AND only an explicit professional decision or expiry changes it

### Requirement: Expiry, cancellation, attendance, and history

An unresolved request MUST become `expired` when its start time arrives; it MUST remain in history and MUST NOT confirm, count as absence, or create a fine. Patient MAY cancel requested or confirmed appointments before start time without fine, freeing the slot. Professional over their agenda and Secretary over every agenda MAY cancel with a patient-visible reason and distinct origin; visibility MUST NOT imply automatic notification. Professional and Secretary MAY mark attended or no-show. A change of date, time, or consultation type MUST be cancellation plus a new appointment, never direct rescheduling.

### Requirement: One-off agenda blocks

Professional and Secretary MAY block or unblock a specific agenda range. They MUST first separately resolve every active appointment or request occupying that range. Blocking MUST NOT cancel appointments or requests automatically.

#### Scenario: Block conflicts with pending request

- GIVEN a pending request occupies part of a requested block range
- WHEN a Professional or Secretary tries to block that range
- THEN blocking is rejected
- AND the request remains unchanged until separately resolved
