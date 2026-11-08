# Appointment operational lifecycle

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
Expiry remains the separate T1 operation; T3 adds attendance and no-show outcomes
as the separate authenticated internal operation described below.

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

## T3 attendance and no-show outcomes

`Origen.Booking.record_attendance/4` records a terminal operational outcome for an
authenticated internal principal. A Professional may act only on the own agenda;
a Secretary may act on any centre agenda. The operation revalidates the active
session, locks the appointment, requires the current status to be `confirmed`,
and stores either `attended` or `no_show`.

There is intentionally no product time window and no terminal correction workflow
in this slice. `requested`, `expired`, `cancelled`, `attended`, and `no_show`
appointments reject the operation without changing state, metadata, occupancy,
history, relationship data, or audit. The status change and one minimized audit
event (`appointment_attended` or `appointment_no_show`) commit atomically. No
fine, notification, or other side effect is produced. Existing occupancy
predicates remain authoritative for `attended` and `no_show`.

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

## Verification record — #377

Observed on the isolated `origen_test_377_lifecycle` database:

| Check | Result |
| --- | --- |
| Baseline request resolution | 13 passed |
| T1 expiry, resolution and overlap | RED observed; GREEN 38 passed |
| T2 cancellation, history and immutable replacement | RED observed; GREEN combined 55 passed |
| T3 attendance plus all lifecycle regressions | RED observed; GREEN combined 62 passed |
| Complete `mix test` suite after T3 | Exit 0: 949 passed, 32 skipped, 8 excluded |
| Changed-file formatting and `git diff --check` | Passed for each implementation unit |
| Independent verification attempt 1 | Setup failed: scratch `mix` shim unresolved; zero tests/probes |
| Independently authorized attempt 2 | Setup failed: credential helper and isolated executable resolution; zero tests/probes |

The eight exclusions follow the existing `postgres_security` test configuration;
they are not claimed as executed. Existing OTP 28 and deprecated legacy helper
warnings remain. No failed test is hidden by the successful full-suite result:
the setup failures and corrected test-fixture failures are recorded in
`odd/tasks/377-appointment-lifecycle-backend.md`.

Independent runtime verification, the baseline/current differential comparison,
and concurrency/migration probes remain **unverified** because verifier setup
failed before execution. The implementation is not ready for approval or delivery
on that evidence alone. A new attempt requires explicit human authorization;
prior failures and correction limits remain recorded.

Human approval of this backend slice is **pending**. The approved #376 contract
is not approval of the implementation. Domain tests do not certify the UI or
complete integration of #285, whose #284 dependency remains separate. No GitHub
publication or issue closure is recorded by this implementation.
