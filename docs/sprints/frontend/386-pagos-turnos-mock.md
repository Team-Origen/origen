# #386 — Appointment payment UI mock

## Scope and access

This is an interactive design preview, not a payment implementation. With the development server running, open `/dev/pagos-turnos`. The route is inside the existing `dev_routes` compile-time gate and is not added to production navigation. No new product routes, real agenda operations, database writes or external calls are introduced.

The preview reuses the existing Mi agenda appointment row through `AgendaAppointmentCard`, rather than a separate two-column card grid. The real agenda supplies its original content and controls unchanged; the preview supplies fictitious data in the same time/type/duration and right-hand patient/contact structure. The approved card revision shows the payment marker alongside the operational state, then an inline action row: **Cancelar con motivo** (red), **Marcar asistencia** (green), **Marcar ausencia** (orange) and **Ver detalle** (blue border/text, white background). All buttons use the existing small bordered button dimensions. **Pagado** is a green badge like the confirmed state. Lifecycle actions appear only where applicable; Patient remains read-only. **Ver detalle** opens the existing preview detail (it replaces the previous **Pago** label because the dialog covers more than payment); inline lifecycle actions open its confirmation for the selected example. Its content, sections and interactions are retained, with black text and light action backgrounds for contrast. No expandable payment history is included.

## Examples and interactions

- Nine fictitious appointments cover confirmed, attended, requested, expired, cancelled and absent states, paid/unpaid marks, zero price and a second professional.
- The detail retains its structure and behavior. It shows the operational state with the card's badge colors, start/end times and total duration, colored lifecycle actions (green attendance, orange absence, red cancellation), and blue outlined Editar precio/Registrar pago buttons. Final price explicitly identifies pesos argentinos (ARS).
- The demo role selector changes the example projection: Professional sees their appointments; Secretary sees all examples; Patient sees Ana Pérez's examples and only the final price/payment state in the payment section. This selector is a design aid, not authentication or authorization evidence.
- Edit a pending final price, including zero; register a full payment by cash or transfer; cancel or confirm correction of a paid mark.
- Paid prices are read-only. New payments are available only for confirmed/attended examples. Existing paid marks survive mock absence/cancellation.
- At the user's explicit request, cancelled examples are fully read-only in this preview, and attended examples cannot be cancelled. These guards apply both to visible controls and manually submitted mock events. Operational state is a single value: an example is never both attended and cancelled. Payment is a separate dimension, so a cancelled example may still show a prior paid mark.
- These are mock interaction constraints, **not business-rule changes**: the approved #384 contract still allows correction of a preserved paid mark on a cancelled appointment. This preview does not exercise that contractual case and must not serve as its acceptance evidence. Backend and production rules remain unchanged.
- Attendance, absence and cancellation confirmations only change these examples, not real appointments. They do not certify the operational lifecycle integration.
- Reset or reload restores all examples. Each browser LiveView process has its own in-memory data. The demo notice remains visible.

## Evidence and limitations

`test/origen_web/live/appointment_payment_preview_live_test.exs` exercises the preview through LiveView events without a database (`skip_db`). The test fixtures and in-memory action evidence do not prove persistence, backend authorization, financial audit or integration with #385/#287.

### Observed checks

- RED: four new preview tests failed with the preview module missing (exit 2).
- GREEN: all four preview interaction tests passed (exit 0).
- `mix format --check-formatted`, `git diff --check` and a structural check of the development route gate/no Booking or Repo calls passed (exit 0).
- Layout correction RED: the new Mi agenda row/columns/contact and black-detail-text assertion failed against the former grid (4/5 passed, exit 2).
- Layout correction GREEN: preview and existing professional agenda/lifecycle regression tests passed together (44 tests, exit 0).
- Inline action revision RED: updated placement/color assertions and direct card-action test failed against the previous version (3/6 passed, exit 2).
- Inline action revision GREEN: preview and existing professional agenda/lifecycle tests passed (45 tests, exit 0), followed by format and whitespace checks (exit 0). Server remains stopped at the user's request; no new visual signoff is claimed.
- Detail presentation/ARS revision: after removing an unavailable Floki dependency from the new assertions, RED showed four missing presentation rules (6/10 preview tests passed, exit 2). GREEN passed 49 preview/agenda/lifecycle tests, formatting and whitespace checks (exit 0). Event handlers and state transitions were not changed by this revision. The shared row component retains the real agenda's original content, IDs and event handlers; it does not attach mock payment states to real records.
- Full `mix test` failed (exit 2): reported 990/1092 passed, 32 skipped, 8 excluded and 102 failures. Observed failures include existing database cleanup hitting `agenda_settings_owner_account_id_fkey` and a count assertion expecting zero agenda settings but finding two. No clean-baseline comparison was run; this does not establish that every failure is pre-existing or certify the suite.
- Real-browser visual verification was unavailable: the Tidewave browser tool could not connect because no application was listening on localhost:4000. LiveView tests do not replace visual approval. No database cleanup or destructive reset was attempted.

The real agendas, their filters and actions, patient projections and payment backend are unchanged. Integration requires the backend's real final price, payment state, operations and authorization. Do not use a historical catalog snapshot as an editable final price.

Contract: [#384](../contracts/384-pagos-simples-correccion.md). OpenSpec: `health-center-beta-core`, implementation slice 12 of 17 / frontend. The user explicitly approved the frontend in this conversation and authorized the `status:approved` issue label and a feature-branch PR chain. This is human frontend approval, not proof of real payment integration. This mock does not automatically close #386 or #287.
