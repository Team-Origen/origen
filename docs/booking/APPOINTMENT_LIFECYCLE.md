# Appointment operational lifecycle

Backend #377 implements expiry, authenticated cancellation, attendance outcomes
and private operational history. Technical verification passed, including the
final 950-test suite; human approval and complete parent integration are separate.
See the verification record below for excluded checks and preserved failures.

## T1 expiry

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

The public `DatabaseCalendar.get_daily_schedule/3` response keeps its existing
`cancellation_policy` map keys (`cutoff_description`, `penalty_percentage`, and
`penalty_description`). Its beta policy says that a patient may cancel strictly
before the appointment starts, reports a zero penalty percentage, and does not
promise an automatic penalty for cancellation or absence. It does not expose a
historical D-1 cutoff or fine warning.

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
| Independently authorized attempt 3 | 62 focused tests, 5 public probes and 2 concurrency probes passed; DB constraints/triggers inspected |
| Public calendar policy correction | RED reproduced D-1/fine response; GREEN one new public regression and 62 existing lifecycle tests passed |
| Initial expanded differential after policy correction | Both probes exit 0, but comparator failed and original payload was incorrect; superseded, not accepted as proof |
| Limited comparator continuation | Exact payloads verified, but probe compilation failed before assertions; failure preserved |
| Explicitly authorized scratch-preparation repair | One of two allowed adjustments used; true `3054fef`/current probes each exit 0 with 1 passed; deterministic comparison passed |
| Independent policy-only recheck | Exit 0, 1 passed; prior D-1/fine finding fixed without repeating the broad review |
| First complete suite after policy adjustment | Exit 2: 948/950 passed, 32 skipped, 8 excluded; two existing agenda fixtures used today's already-due times |
| Final complete `mix test --seed 906340` after fixture correction | Exit 0: 950 passed, 32 skipped, 8 excluded |
| Final changed-code format, whitespace and local Tracking links | Passed |

The eight exclusions follow the existing `postgres_security` test configuration;
they are not claimed as executed. Existing OTP 28 and deprecated legacy helper
warnings remain. No failed test is hidden by the successful full-suite result:
the setup failures and corrected test-fixture failures are recorded in
`odd/tasks/377-appointment-lifecycle-backend.md`.

The third independent attempt covered E1–E14, including exact expiry boundaries,
rejection invariance, scope/privacy, immutable appointments and concurrent
transitions. Its scratch probes initially had incorrect expectations/overlapping
fixtures; those probes were corrected without changing application source, then
passed. The earlier two preparation failures remain recorded with zero probes.
Migration constraints and triggers were inspected; destructive rollback was not
executed. Dropping populated cancellation metadata during an explicit rollback
remains an advisory, not an executed operation or a new feature requirement.

The public calendar policy contradiction was reproduced and corrected, then
independently rechecked through its public regression (1 passed). The initial
expanded differential comparator exhausted its local bound and used an incorrect
original payload; those outputs were rejected as proof. A subsequent explicitly
authorized continuation used correct payloads but failed compilation before
executing assertions. Neither failure was silently retried or counted as a pass.

After a further explicit human decision, the same worker repaired only temporary
syntax and fixtures, using one of the two authorized preparation adjustments.
Separate `git archive` payloads were checked against their commit source blobs:
base `3054fefe3787b9161546db2994a78282bd94dfc9` had no expiry module, while current
contained it and the corrected policy. Copied project build artifacts were
cleaned to avoid loading current code into the baseline process. Both probes
exited 0 and emitted deterministic JSON; the comparison passed.

Unchanged public behavior covered future request acceptance/rejection,
foreign-agenda and invalid-state errors, professional/patient occupancy for
confirmed/reserved/cancelled appointments, approval configuration, valid and
malformed reservation validation, and calendar slots/date/identity/specialty.
Malformed validation contained the same complete errors with ordering differences
only. The only intended differences were due requested appointments expiring
rather than confirming/occupying, and the corrected public cancellation policy.
Generated identifiers were projected to stable tokens; matching OTP warnings and
all subprocess exit codes were retained.

The first complete suite after the policy adjustment exposed two existing agenda
accept/reject fixtures that used today's fixed UTC times. Those fixtures ceased
to be future requests during later executions, so expiry correctly prevented
confirmation/cancellation. Only those two existing test dates and agenda query
dates were changed to tomorrow; production code, scenarios and assertions were
not altered. A first focused recheck found a Date URI encoding error in that test
adjustment; the same dates are now encoded with `Date.to_iso8601/1`.

The final run repeated the original failing seed (`906340`) and passed all 950
active tests. Its preceding location-filtered focused command selected one test
(1 passed, 30 excluded); both corrected C12 scenarios were included in the full
passing suite. Changed-code formatting, whitespace, and local OpenSpec Tracking
links also passed. Previous failures and authorizations remain in the feature
log; later successful evidence does not erase them.

Backend implementation and technical verification for this slice are complete.
No required technical check remains pending. The metadata rollback advisory is
unchanged: do not treat a rollback that removes populated metadata columns as
history-preserving. No such rollback was executed or authorized here.

Human approval of this backend slice is **pending**. The approved #376 contract
is not approval of the implementation. Domain tests do not certify the UI or
complete integration of #285, whose #284 dependency remains separate. No GitHub
publication or issue closure is recorded by this implementation.
