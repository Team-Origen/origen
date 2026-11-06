# #315 — Development booking demo port (slice 1 of 4)

`config/dev.exs` selects `OrigenWeb.ProfessionalPatientSelectorDemo` as the
`:professional_patient_selector` adapter. No configuration changes are made for
test or production. The adapter rejects every request when `:dev_routes` is off.

The public `execute/1` boundary supports related patients, exact normalized DNI
search, consultation types, sample time slots and simulated confirmation. It
returns only in-memory examples; it has no database or network access and never
creates an appointment or a professional-patient relationship.

Two sample patients are related. Lucía Ejemplo (synthetic DNI `99000123`) is
searchable only by exact DNI, not included in the related list. Simulating a
confirmation does not change that list. Catalog fixtures preserve the existing
`exact_price_ars` (Decimal) and `color` fields plus duration in minutes.

This slice delivers the demo data contract, not a user-facing screen or #314.
The next slices add patient selection, visual steps and the connected demo.

Verification: `mix test test/origen_web/live/professional_patient_selector_demo_test.exs`.
These are regression tests around already implemented behavior; no new behavior
or meaningful new RED is claimed. Prior implementation RED/GREEN is retained in
the final delivery document. Source identity has been sanitized before commits.

References: [#315](https://github.com/Team-Origen/origen/issues/315),
[approved #313 contract](../contracts/313-agenda-profesional-privacidad.md).
