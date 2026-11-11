# #315 — Patient selection (slice 2 of 4)

The existing professional agenda now links to `/profesional/agenda/crear`.
The route uses the existing professional session and role guards. It shows a
separate patient-selection screen, not approval configuration or other agendas.

**Mis pacientes** lists related identities; **Buscar por DNI** makes an exact,
normalized lookup through the configured port. The screen projects only ID,
first name, last name and DNI, excluding contacts and other-professional activity.
Selecting, clearing, switching tabs and canceling never creates a relationship
or appointment. A manipulated selection outside the returned list is rejected.

Development uses the explicitly labeled demo from slice 1. No adapter means an
honest service-unavailable state rather than fabricated patients. **Continuar**
is intentionally disabled in this slice: later slices add visual components and
wire the four-step simulation. It remains right-aligned; text labels are black.

Verification: `mix test test/origen_web/live/professional_agenda_live_test.exs
 test/origen_web/live/professional_patient_selector_demo_test.exs` returned
27 passed, exit 0 (seed 627383). The patient-only regression tests are retained
with this behavior; later-step tests belong to the connected-demo slice.

This is independent frontend preparation, not #314 or real #316 integration.
References: [#315](https://github.com/Team-Origen/origen/issues/315),
[approved contract](../contracts/313-agenda-profesional-privacidad.md),
[demo port](315-demo-port.md).
