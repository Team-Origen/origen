# #316 — Real professional booking integration

## Scope and prerequisites

Integrates parent [#282](https://github.com/Team-Origen/origen/issues/282) using the
[approved #313 contract](../contracts/313-agenda-profesional-privacidad.md), the
real #314 Booking APIs and the #315 frontend. OpenSpec change:
`health-center-beta-core`, path `openspec/changes/health-center-beta-core/`,
Sprint 3 / parent #282 / integration. The proposal already contains reverse
tracking references.

All explicit blockers (#313, #314, #315, #276, #278) were closed when checked.
The user explicitly approved #315 as the frontend with fixtures/demo in this
conversation, leaving real integration to #316. The historical #315 document's
partial-delivery statement describes that delivery, not an outstanding request
to reopen it. This prerequisite approval is **not** final acceptance of #316 or
#282. No GitHub issues are closed automatically.

## Real journey

Sign in as an active Professional, open **Mi agenda → Crear turno**
(`/profesional/agenda/crear`), and:

1. Select an existing related patient under **Mis pacientes**, or use **Buscar
   por DNI** with a complete, exact document. Only first name, last name and DNI
   are shown. No patient registration or global directory is exposed.
2. Choose a real consultation type from your active catalog.
3. Choose a date and a real available slot. The existing engine applies agenda
   configuration, lead time, horizon, duration and persisted occupancy. Dates and
   times follow the existing UTC booking/agenda convention; no timezone conversion
   or new availability engine is introduced here.
4. Review the selection and click **Confirmar turno**. The server revalidates the
   session, selection and availability. A successful operation creates one
   `confirmed` appointment and creates/reuses the relationship atomically,
   including when approval mode is manual.
5. **Volver a mi agenda** opens the booked date. A rejected confirmation displays
   **No se creó el turno** rather than success. For stale availability, go back
   to date/time to reload slots and choose again.

Searching, selecting, going back, clearing selection and cancelling do not
create appointments or relationships. Confirmation uses server-held selections,
not client-supplied patient, consultation, time or Professional parameters.
Repeated confirmation events after success do not create another appointment in
that LiveView. This is not a new cross-session idempotency contract.

`OrigenWeb.ProfessionalPatientSelector` delegates to the public `Origen.Booking`
operations. It is the default when `:professional_patient_selector` is absent;
explicit `nil` disables the selector. Backend authorization remains authoritative;
the UI is not a permission boundary. No failed real operation falls back to demo
fixtures or synthetic success.

## Explicit development demo

The old synthetic journey is retained for visual exploration only. To opt in,
configure locally in `config/dev.local.exs` (imported by development config):

```elixir
import Config
config :origen, :professional_patient_selector, OrigenWeb.ProfessionalPatientSelectorDemo
```

Restart the application after changing configuration. The demo also requires
`:dev_routes` to be enabled and always displays the fictitious-data banner,
**Simular confirmación**, and a result explicitly stating that no appointment or
relationship was created. Remove the override and restart to return to real
booking. Never use demo success as integration evidence.

## Verification and acceptance

The public LiveView integration suite uses persisted synthetic fixtures, real
sessions, real Booking operations and a transactional SQL sandbox. It covers
related and exact-DNI booking, automatic/manual confirmation, abandonment,
minimum identity, two-Professional isolation, forged selections/client payloads,
revocation between selection and confirmation, stale occupancy and retry.
Existing demo/component and backend security/atomicity tests remain applicable.

Use a dedicated local test partition; do not point this at production data:

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue316 \
  mix test test/origen_web/live/professional_booking_integration_test.exs \
  test/origen_web/live/professional_agenda_live_test.exs \
  test/origen_web/live/professional_patient_selector_demo_test.exs \
  test/origen_web/components/professional_booking_demo_steps_test.exs
```

Observed results and remaining limitations are recorded in
[`odd/tasks/issue-316-professional-agenda-integration.md`](../../../odd/tasks/issue-316-professional-agenda-integration.md).
No final human approval, browser evidence, successful check, or parent completion
is inferred from code or test presence alone. Patient registration, request
approval, a new privacy audit (#202), and access to other Professionals' activity
remain outside this slice.
