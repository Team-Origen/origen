# #315 — Booking visual components (slice 3 of 4)

This slice supplies `OrigenWeb.ProfessionalBookingDemoSteps`, reusable presentational
components for the development-only professional-booking demonstration. It adds:

- a non-interactive, accessible four-step progress indicator;
- consultation options that render catalog name, assigned color, exact ARS amount,
  and duration;
- date/slot selection layout with guarded Continue actions; and
- a confirmation summary explicitly marking the result as simulated and free of
  database writes.

The module receives every value through component assigns. It has no fixture, adapter,
database, network, appointment, relationship, or authorization access. The next slice
wires it to the existing patient-selection LiveView only when the development adapter
is active. Therefore this slice neither implements #314 nor creates real appointments.

Verification: `mix test test/origen_web/components/professional_booking_demo_steps_test.exs`
returned 3 passed, exit 0 (seed 62213). The component tests prove progress is not
interactive, consultation presentation preserves price/color data, and a completed
summary remains explicitly simulated. Journey integration tests remain with slice 4.

References: [#315](https://github.com/Team-Origen/origen/issues/315),
[approved #313 contract](../contracts/313-agenda-profesional-privacidad.md), and
[patient selection slice](315-patient-selection-slice.md).
