# #315 — Professional booking visual demo (partial delivery)

## Scope

This delivery adds **Crear turno** to the existing professional agenda and opens
`/profesional/agenda/crear` as a separate patient-selection view. Both routes
require the existing professional session guards.

The view has **Mis pacientes** and **Buscar por DNI** tabs, minimum patient
identity (first name, last name and DNI), local selection, clear selection and
cancel/back navigation. Exact search reuses `Persona.normalize_number/1`;
semantic validation and exact matching belong to the backend contract.

The development demo now includes four steps: **Paciente → Consulta → Fecha y
horario → Confirmación**. A persistent progress indicator highlights the current
step and marks completed steps. The indicator is a non-interactive ordered list:
numbered circles connected by thin lines, neutral grayscale colors and no button
or tab styling. Step labels and numbers use explicit black text; the current
step uses heavier text and a stronger number outline;
completed steps use checkmarks. All four labels remain in one row on small
screens, with wrapping text and a separate `Paso N de 4` status. Navigation uses
only the content's **Volver / Continuar** controls. Future steps cannot be entered
until the required selections are made.

Consultation types, durations, ARS amounts, assigned colors and available times
are examples supplied by the stub. Each consultation option shows its name in
a tag with its assigned color, its duration and its amount formatted like the
type catalog (`ARS 25.000,00`, for example). Text remains black for readability;
color is conveyed by a swatch, not by colored text. The confirmation summary
also preserves the selected amount. Demo options use the catalog's
`exact_price_ars` (Decimal) and `color` fields; these are not loaded from a real
Professional's catalog. Going back preserves valid selections; changing the patient clears the
consultation and time, changing the consultation clears the time, and changing
the date reloads the example times and clears the previous time. Only today or
a future date is accepted in this demonstration.

The last button says **Simular confirmación**. The result is explicitly labeled
as a simulation: no appointment or professional-patient relationship is created,
and the existing agenda is not populated with a fake appointment. No real
availability engine, booking submission or registration is implemented. Outside
the demo, the patient step still cannot advance without the real integration.

## Backend boundary and limitations

The server-side `:professional_patient_selector` port has no real backend
adapter yet. `config/dev.exs` selects `OrigenWeb.ProfessionalPatientSelectorDemo`,
a development-only stub returning two related sample patients and an additional
search-only sample patient without database access.
The view displays an explicit demonstration banner. Fixtures belong to the data
adapter, not to the visual components. Without an adapter, the view still reports
that the service is unavailable. Test configuration does not enable the demo by
default, and the demo refuses requests when `:dev_routes` is disabled.

To inspect it, restart `iex -S mix phx.server` after the development configuration
change, sign in as a Professional and open `/profesional/agenda/crear`. Search
DNI `30111222` (Ana Ejemplo) or `32444555` (Martín Demostración). The additional
user-specified sample identity is discoverable only by its exact DNI, never
through Mis pacientes. A valid nonmatching DNI returns no result. Demo format
validation is illustrative, not a new backend DNI policy. These patients are
never inserted or related to any real account, even after simulated confirmation.
After selecting either patient, continue through the sample consultation types
and times to inspect the confirmation summary and simulated result.

The adapter accepts `execute({:related, session})` and
`execute({:search, session, normalized_exact_document})`, returning
`{:ok, patients}`, `{:ok, patient_or_nil}` or `{:error, reason}`, respectively.
Each patient contains `id`, `first_name`, `last_name`, `document_number`; the
view projects away all other fields. The future adapter must revalidate the
session, enforce contextual exact search and restrict the related list to the
actor. The UI is not an authorization boundary.

The same development-only adapter also accepts `{:consultations, session}`,
`{:slots, session, consultation_id, date}` and
`{:simulate_confirmation, session, selection}`. These demo requests return
in-memory fixtures or a result tagged `simulated: true`; they do not define or
replace the real #314 booking API. Visual components have no fixture data or
database access. The LiveView only invokes these additional operations when
the demonstration adapter is active and development routes remain enabled.

## Verification

- RED: five new tests failed before implementation; 17 existing tests passed.
- Initial GREEN: `mix test test/origen_web/live/professional_agenda_live_test.exs`:
  22 passed, exit 0.
- Demo RED: 2 new tests failed before the adapter existed; 22 passed.
- Demo GREEN: same focused command, 24 passed, exit 0. Covers both sample
  patients, exact search, invalid/not-found results and demo refusal when
  development routes are disabled.
- Four-step demo RED: 4 failures, 23 passed (3 new tests plus the updated demo
  progression expectation), exit 2.
- Four-step demo GREEN: same focused command, 27 passed, exit 0 (seed 142339).
  Covers sequential progress, guarded future steps, summary, simulated result,
  back navigation, invalidation after selection changes, forged selections and
  invalid date feedback.
- Initial `mix test`: 781 passed, 29 skipped, 8 excluded, exit 0.
- After the demo adapter: `mix test` returned 783 passed, 29 skipped,
  8 excluded, exit 0 (seed 160749). `postgres_security` remains excluded.
  This does not establish real backend integration.
- After the four-step demo: `mix test` returned 786 passed, 29 skipped,
  8 excluded, exit 0 (seed 529140); `postgres_security` remains excluded.
- Step-indicator refinement RED: 2 failures / 25 passed, exit 2. GREEN:
  27 passed, exit 0 (seed 356078). Tests assert that progress contains no buttons
  or click handlers and that backward navigation still works through footers.
- After the step-indicator refinement: `mix test` returned 786 passed,
  29 skipped, 8 excluded, exit 0 (seed 913814). Formatting and diff checks passed.
- Search-only sample RED: 1 failure / 27 passed, exit 2; GREEN: 28 passed,
  exit 0. The public UI test covers exact vs partial match, simulated booking
  and continued absence from the related list after reopening the view.
- Patient-step Continue is aligned right. Labels, headings and form input text
  use explicit black text; white button text is retained on dark backgrounds.
  Focused regression after the text-color adjustment: 28 passed, exit 0.
- Amount/color RED: 1 failure / 28 passed, exit 2. GREEN: 29 passed, exit 0
  (seed 750264). Tests cover both amounts, durations, assigned colors, retained
  selection and amount consistency in the final summary.
- After the amount/color refinement: `mix test` returned 788 passed,
  29 skipped, 8 excluded, exit 0 (seed 211717). Formatting and diff checks passed;
  `postgres_security` remains excluded.
- Interactive browser verification was unavailable: Tidewave reported that no
  browser was connected. Appearance and responsive layout still require visual
  confirmation.

Sources: [approved contract #313](../contracts/313-agenda-profesional-privacidad.md),
GitHub [#315](https://github.com/Team-Origen/origen/issues/315) and parent
[#282](https://github.com/Team-Origen/origen/issues/282).
This partial delivery does not complete #315, #314, #316 or parent #282.
