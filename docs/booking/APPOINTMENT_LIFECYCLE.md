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
