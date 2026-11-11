# #386 — Existing agenda row layout

## Scope

This first review slice extracts the existing `ProfessionalAgendaLive` row wrappers into `AgendaAppointmentCard.card/1`. The `appointment` and `patient` slots retain the original order, CSS layout, content, IDs, forms and event handlers. Additional `data-section` attributes identify the two columns for presentation tests.

This is not a redesign. The real agenda receives no fake payment data, new financial controls or payment-state defaults. The shared wrapper allows the next slice's development-only mock to use the same responsive row rather than invent a separate card grid.

## Verification

The existing professional agenda and lifecycle tests exercise the original controls, request handling, patient access and cancellation/attendance flows. They passed alongside the mock tests before slicing (51 combined tests). The delivery process also runs them on this slice. This is regression evidence, not backend payment verification or visual approval.

## Chain and traceability

- Issue: Team-Origen/origen#386; parent #287.
- OpenSpec: `health-center-beta-core`, `openspec/changes/health-center-beta-core/`, implementation slice 12 of 17 / frontend.
- Target: `feat/386-payments-ui`, the draft tracker branch; following slice `feat/386-payment-preview` targets this slice's branch.
- Rollback: revert the wrapper extraction and inline the unchanged slot content; no persisted data is affected.
