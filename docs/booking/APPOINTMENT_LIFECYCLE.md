# Appointment lifecycle: T1 expiry

T1 adds the `expired` operational state for unresolved `requested` appointments.

A requested appointment expires when its `start_time` is reached. Expiry keeps
the appointment row and its immutable snapshots in history, records one
minimized `appointment_expired` audit event, and releases both professional and
patient occupancy. Confirmed appointments are not changed by this mechanism.

Expiry is available through `Origen.Booking.expire_due_requested/1`, is invoked
by overlap and database-calendar availability queries, and runs as a supervised
runtime backstop through `Origen.Booking.ExpiryWorker`. The
`origen.appointments.expire` Mix task provides an operational sweep entrypoint.

The sweep is idempotent. It uses a server-derived UTC clock in production;
deterministic tests may inject `now` through the explicit infrastructure
option. Request resolution locks the appointment row and expires a due request
before confirmation can succeed.

No cancellation, attendance, absence, notification, fine, or direct
rescheduling behavior is introduced by T1.

## T2 authenticated cancellation

T2 adds the authenticated cancellation and operational-history slice of #377.
Expiry remains the separate T1 operation; attendance and no-show outcomes are
not part of this slice.

`Origen.Booking.cancel_appointment/3` accepts a server principal, an appointment
id, and optional cancellation attributes. Attribute maps may provide only
`:reason`; `now` and `fail_at` controls in atom or string map keys are ignored.
Trusted deterministic infrastructure options remain available as atom-key
keyword options (`now:`, `fail_at:`). The default `DateTime.utc_now/0` is read
inside the transaction after the appointment row is locked. Internal principals
must contain the server-created `session_id` and `account_id`; the account and
role are revalidated with `Origen.Sessions.revalidate_principal/2`. Patient
principals use the existing passwordless session context
`patient_email`/`patient_authenticated_at`, which is revalidated through
`Origen.Patients.verify_patient_session/2`. Client-provided role or identity
maps are not authorization evidence.

- Patients may cancel only their own `requested` or `confirmed` appointments
  strictly before `start_time`.
- Professionals may cancel `requested` or `confirmed` appointments in their own
  agenda, including confirmed appointments at or after their start time.
- Secretaries may cancel `requested` or `confirmed` appointments in any agenda.
- Professional and secretary cancellations require a trimmed, nonblank reason.
- Every accepted cancellation stores `cancellation_origin` and
  `cancellation_reason` (patient reasons are `NULL`) and appends one minimized
  `appointment_cancelled` audit event in the same transaction.

Rejected authorization, timing, status, or reason checks do not invoke expiry,
change occupancy, or write appointment metadata or audit rows.

## Operational history

`Origen.Booking.list_appointment_history/2` returns a non-clinical
projection. The actor is
revalidated before the query and the scope is applied in SQL:

- Patient: `patient_profile_id` of the revalidated profile.
- Professional: `professional_account_id` of the revalidated account.
- Secretary: all centre agendas.
- Administrator: denied; administration does not imply appointment access.

The projection retains `requested`, `confirmed`, `expired`, `cancelled`,
`attended`, and `no_show` rows when they are in the actor's scope. Cancellation
origin and reason are visible to an authorized patient history query.

## Immutable reservation identity

Appointment snapshots, patient/professional/type identity, `start_time`, and
`end_time` are protected by the database trigger. A date, time, or consultation
type change is therefore represented by cancelling the original appointment and
creating a new one through an existing authorized reservation function. There is
no reschedule operation.
