# Issue 78: Build the Professional Availability Interface

## Objective

Build the Professional-facing availability editor at `/configuracion/profesional` using the merged `Origen.Availability` backend contract.

## Problem

Professionals can configure their agenda interval and consultation types, but they cannot yet manage regular weekly availability, the future booking horizon, or the minimum booking lead time through the UI. The existing route is also restricted to the non-production consultation-catalog demo.

## Why

Issue #78 completes the Professional configuration flow defined by Issue #76 and backed by Issue #77. The interface must preserve the backend's ownership, complete-replacement, validation, and normalization guarantees rather than reimplementing conflicting business rules in the browser.

## Authorized scope

- Local implementation on `feature/78-professional-availability-ui`.
- Professional availability UI at `/configuracion/profesional`.
- Real integration with `Origen.Availability.get_own_configuration/1` and `replace_own_configuration/2`.
- Focused LiveView tests and applicable functional verification.
- No backend behavior changes, database changes, or GitHub Issue mutations.
- The user authorized one commit and one push only to the current `feature/78-professional-availability-ui` branch, with no pull request. This bounded writer must leave both operations to the parent after verification.

## Confirmed contract

- True overlapping windows are rejected and displayed clearly.
- Exactly touching windows are accepted and returned as one normalized window.
- The editor submits all seven weekdays, the booking horizon, and the minimum lead time as one complete replacement.
- Booking horizon accepts 7 through 90 whole days and defaults to 30.
- Minimum lead time accepts 0 through 1,440 minutes in five-minute increments and defaults to 30.
- Window boundaries use the returned agenda interval, and each window spans at least one complete interval.
- Empty weekly availability is valid.
- The canonical screen always presents each weekday independently.
- A testable bulk action may copy one day's complete windows to selected weekdays; the weekday checklist exists only inside that copy action and never becomes a persisted recurring group.
- Availability uses progressive disclosure: the default state shows the persisted weekly and booking summary, and an explicit `Edit availability` button expands the complete editor.
- Cancelling discards the draft and collapses the editor; a successful save adopts the normalized backend response and collapses it; validation failure preserves the draft and keeps the editor open.
- The previous separate-block visual decision is superseded: the weekly schedule, booking horizon, minimum lead time, and editing footer belong to one unified `Weekly availability` section because they are submitted as one atomic replacement. Organization timezone information remains in its own block.
- Manually typed window boundaries remain supported. The UI validates each boundary against the current agenda interval and local window rules, marks only the affected input invalid with a red border and associated warning, and prevents confirmation while any local error remains. Native `step` behavior is guidance only; backend validation remains authoritative.
- The existing agenda-interval section remains the single place that displays and edits the agenda interval; the new availability blocks may reference its value only when guidance is required and must not duplicate that editor.
- Backend-normalized data replaces the local draft after a successful save.
- Rejected saves preserve the local draft and present one consolidated validation notice.
- Existing appointments, exceptions, holidays, slot generation, and audit-history presentation are outside this issue.

## Constraints

- Preserve the existing owner-only HTTP and LiveView authentication boundaries.
- Use the merged Issue #77 backend as the authoritative executable contract.
- Keep keyboard operation and narrow-screen usability as acceptance requirements.
- Follow the existing Petal Components and Tailwind conventions; do not introduce a parallel design system.
- Keep tests with each implementation work unit.
- Treat approximately 400 authored changed lines per work unit as an advisory review heuristic, not a reason to omit tests or compress code.

## TDD configuration

- Mode: strict TDD.
- Source: explicitly selected by the user for Issue #78.
- Loop: observed RED → minimal GREEN for one vertical slice → REFACTOR after green.
- Confirmed public test seams: externally observable authenticated behavior at `/configuracion/profesional` and integration through the public `Origen.Availability` context. Test-only doubles may cover unavailable or rejected presentation states but never replace the real success-path integration.
- Test runner: focused `mix test` commands through the repository's verified Mix environment.
- Environment boundary: the real interactive Professional runtime and credentials are available in WSL, not in the current Windows environment. Windows can run database-backed LiveView tests only when its PostgreSQL test configuration is available.
- Selected workflow: hybrid. Build against the real backend contract from the first vertical slice, use test-only doubles solely for exceptional presentation states, run automated RED/GREEN checks on Windows when its test database is available, and perform browser-level Professional verification in WSL at coherent milestones rather than after every edit.
- The public test seams and screen inventory are confirmed; implementation may begin through strict vertical RED/GREEN/REFACTOR slices.

## Checklist

- [x] ODD-78-01 — Expose the authenticated Professional configuration route outside the demo gate and load availability through the real owner-bound backend seam.
- [x] ODD-78-02 — Build the weekly draft editor with seven weekdays, multiple interval-aware windows, and keyboard-operable add, remove, and clear actions.
- [x] ODD-78-03 — Add booking-horizon and minimum-lead-time controls with the confirmed ranges, defaults, increments, and organization-timezone guidance.
- [x] ODD-78-04 — Submit one complete replacement, preserve drafts on rejection, consolidate backend validation errors, and adopt normalized backend data on success.
- [ ] ODD-78-05 — Verify semantic accessibility, keyboard workflows, and narrow-screen reflow without relying on color or pointer-only controls.
- [ ] ODD-78-06 — Run focused integration checks, compilation/format checks, the applicable full suite, and record honest final evidence.
- [x] ODD-78-07 — Correct the availability palette using established Professional configuration/catalog tokens, unify weekly and booking controls in one visual section, and place Save/Cancel in that section's form footer.
- [x] ODD-78-08 — Prevent confirmation for manually typed off-interval or otherwise locally invalid boundaries, with field-specific red invalid styling, accessible associated warnings, and recovery when corrected.

## Acceptance criteria

- Only an authenticated active Professional can view and operate the availability editor.
- Initial persisted defaults render for all seven weekdays and both booking controls.
- A Professional can add, remove, clear, and save weekly windows using a keyboard.
- The editor cannot submit UI-only row identifiers or omit required weekdays.
- True overlaps, invalid ranges, misalignment, and malformed values produce one clear consolidated error notice without partial success.
- Touching windows and other normalized results replace the draft after a successful save.
- Empty weekly availability saves successfully.
- The interface remains usable at a narrow viewport and exposes associated labels, status feedback, and invalid-state semantics.
- Completion uses the real Issue #77 backend rather than fixtures.
- The editor presents weekly windows, booking horizon, minimum lead time, and Save/Cancel inside one visually coherent `Weekly availability` section using the established Origen palette.
- A manually typed boundary that is not aligned to the current agenda interval marks that specific input with `aria-invalid`, red-border semantics, and a clearly associated warning; Save is disabled and submission is prevented until all boundaries are aligned and otherwise locally valid.
- Correcting the affected boundary clears its field-level invalid state and re-enables confirmation when no other local error remains.
- UI prevention does not alter backend rejection of true overlap, backend merging of touching windows, complete atomic replacement, editable booking controls, authorization, preview safety, or carousel behavior.

## Applicable checks

- Focused LiveView tests for route authorization, loading, editing, saving, errors, and normalization.
- Existing `test/origen/availability_test.exs` contract tests remain green.
- `mix compile --warnings-as-errors`.
- Changed-file `mix format --check-formatted` after source-mutating formatting.
- Full `mix test` when environmentally available.
- Browser-level keyboard and narrow-viewport verification unless equivalent browser automation is introduced.
- `git diff --check`.
- Focused LiveView assertions for the unified section/footer and palette contract through stable public semantics/classes.
- Focused LiveView assertions that an off-interval typed boundary receives field-specific invalid semantics and warning, disables Save, performs no replacement/persistence, and recovers after correction when practical.

## Progress and verification evidence

- [x] Created the branch from current `origin/develop` at `47d6bface5d8a4abf5d0a77f7b3283954f418116`.
- [x] Read Issues #76 and #78 without modifying them.
- [x] Inspected the Issue #76 handoff, merged Issue #77 contract, backend implementation, route, existing Professional configuration LiveView, and tests.
- [x] Confirmed Issue #77 is merged, closed as completed, and in Project status `Done`.
- [x] Resolved the overlap drift: Issue #78 follows the implemented backend by rejecting true overlaps and normalizing only touching windows.
- [x] Resolved the Issue #78 TDD mode as strict TDD.
- [x] Selected the hybrid Windows/WSL implementation and screen-verification workflow.
- [x] Confirmed the public test seams and screen inventory before the first source change.
- [x] ODD-78-01 RED observed: `mix test test/origen_web/professional_availability_live_test.exs` compiled successfully and failed 1/1 because `#weekly-availability-heading` was absent (seed 659068). The Windows-only LiveView colocated-assets symlink warning was non-fatal.
- [x] ODD-78-01 GREEN observed: the same focused command passed 1/1 (seed 154547) after exposing the owner-authenticated route unconditionally and rendering the real `Origen.Availability.get_own_configuration/1` result in separate weekly, booking-rule, and timezone summaries.
- [x] ODD-78-02/03 editor RED observed: the focused command passed the summary slice and failed the editor slice (1/2 passed, seed 146478) because the public `edit_availability` event was not implemented.
- [x] ODD-78-02/03 editor GREEN observed: the focused command passed 2/2 (seed 759920); the explicit Edit action now reveals all seven day groups, interval-derived time input steps, booking bounds, timezone guidance, and keyboard-operable form actions.
- [x] ODD-78-02 draft-actions RED observed: the focused command passed 2/3 (seed 835768) and the new public-behavior test failed when `add_availability_window` reached the component without a matching event handler.
- [x] ODD-78-02 draft-actions GREEN observed: the focused command passed 3/3 (seed 998112); add, indexed remove, clear, and cancel now mutate only the draft, and reopening restores persisted windows.
- [x] ODD-78-04 replacement RED observed: the focused command passed 3/4 (seed 828798) and the success-path form submission failed because the public `save_availability` event was not implemented.
- [x] ODD-78-04 replacement GREEN observed: the focused command passed 4/4 (seed 391870); submission now calls the real public replacement API, sends all seven weekdays and both booking controls, collapses on success, and renders the backend-normalized touching window after remount.
- [x] ODD-78-04 rejection RED observed: the focused command passed 4/5 (seed 478043); the real backend rejected overlap, horizon, and lead-time errors while preserving the editor, but the required consolidated accessible notice was absent.
- [x] ODD-78-04 rejection GREEN observed: the focused command passed 5/5 (seed 549747); one role-alert now consolidates backend errors, marks associated controls invalid, preserves submitted values, and Cancel restores the persisted configuration.
- [x] ODD-78-02 copy-action RED observed: the focused command passed 5/6 (seed 564144); the editor did not yet expose the temporary copy action at `#availability-copy-action`.
- [x] ODD-78-02 copy-action GREEN observed: the focused command passed 6/6 (seed 16112); the temporary source-and-destination action copies complete draft windows while emitting no persisted weekday-group field.
- [x] ODD-78-04 empty-week integration observed: the focused command passed 7/7 (seed 684944); clearing all seven days and submitting remains valid through the real backend and renders seven explicit empty states.
- [x] ODD-78-04 unavailable-state RED observed: the focused command passed 7/8 (seed 739406); the test-only presentation double was configured, but initial loading still called the concrete context directly, so the bounded error state did not render.
- [x] ODD-78-04 unavailable-state GREEN observed: the focused command passed 8/8 (seed 899817); the test-only context seam now affects only exceptional presentation tests while the production default remains `Origen.Availability`.
- [x] Draft-locality check observed GREEN on first run: the focused command passed 9/9 (seed 415512); an unrelated consultation-catalog interaction leaves the open availability draft and its cleared-day state intact.
- [x] ODD-78-04 unavailable-save RED observed: the focused command passed 9/10 (seed 649737); the test-only rejection double preserved the draft, but no accessible save-failure notice was rendered.
- [x] ODD-78-04 unavailable-save GREEN observed: the focused command passed 10/10 (seed 327452); the draft remains open with one accessible temporary-failure notice. Post-format rerun also passed 10/10 (seed 736043).
- [x] Existing integration checks passed: `mix test test/origen_web/consultation_type_catalog_live_test.exs test/origen/availability_test.exs` completed 46/46 (seed 89208).
- [x] `mix compile --warnings-as-errors` exited successfully. Phoenix LiveView emitted the known non-fatal Windows `node_modules` colocated-assets symlink warning (`:eperm`).
- [x] Source-mutating `mix format` was run on every changed `.ex`/`.exs` file. The exact changed-file check exposed pre-existing trailing whitespace throughout `consultation_type_catalog_live.ex`; unrelated whitespace churn was reverted. `mix format --check-formatted` passed for the other three changed source files, while the catalog file remains baseline-unformatted.
- [x] `git diff --check` passed. Git emitted only line-ending conversion warnings for the two tracked source files.
- [ ] Full `mix test` reached 442/445 passed with 8 excluded (seed 794936). Three unrelated bootstrap tests failed and reproduced in isolation: two local secret-file reads returned `{:error, :secrets_unavailable}`, and one expired invitation was accepted instead of returning `:invalid_invitation`.
- [ ] Browser-level keyboard and narrow-viewport verification remains pending in WSL; no WSL command was run.
- [x] Corrective verification reopened ODD-78-04: consolidated errors lacked backend-reason specificity and Cancel retained stale unavailable feedback. ODD-78-05 remains pending and now also requires an operational narrow-screen carousel contract.
- [x] Corrective ODD-78-04 RED observed: focused tests passed 8/10 (seed 991550); the real overlap rejection still rendered generic weekday guidance, and Cancel left `#availability-save-error` visible.
- [x] Corrective ODD-78-04 GREEN observed: focused tests passed 10/10 (seed 12072); the consolidated alert now translates concrete weekday reasons (including overlap, invalid time/window, overnight/empty, misalignment, and minimum duration), while Cancel clears stale unavailable and validation feedback before restoring persisted summaries.
- [x] Corrective ODD-78-05 RED observed: focused tests passed 10/11 (seed 278680); progressive disclosure lacked `aria-expanded`/`aria-controls`, and no operational mobile carousel binding existed.
- [x] Corrective ODD-78-05 automated GREEN observed: focused tests passed 11/11 (seed 433844); summary and editor now share seven-day responsive carousel markup with touch scrolling, snap points, labeled previous/next controls, and a colocated hook that scrolls to the adjacent day. Edit disclosure controls a stable region with synchronized `aria-expanded`. ODD-78-05 remains pending for real WSL browser verification.
- [x] Focused authorization characterization passed on its first run: focused tests passed 12/12 (seed 803476); anonymous access returns 401 and Administrator/Secretary access returns 403. No authentication implementation change was necessary or manufactured.
- [x] Development-preview RED observed: focused tests passed 12/13 (seed 646489); `OrigenWeb.ProfessionalAvailabilityPreviewLive` did not exist.
- [x] Development-preview GREEN observed: focused tests passed 13/13 (seed 737894), and the semantic-native refactor remained green at 13/13 (seed 942646). The isolated preview injects a stateless adapter into the same component, visibly states that changes are not persisted, and leaves the production default on `Origen.Availability`.
- [x] Development route verification: `mix phx.routes` in the Windows development environment listed `GET /dev/professional-availability`; the route remains inside the existing compile-time `dev_routes` block and is absent from production configuration.
- [x] Corrective final focused check passed 13/13 (seed 252836).
- [x] Corrective existing integration check passed 46/46 (seed 735683): `mix test test/origen_web/consultation_type_catalog_live_test.exs test/origen/availability_test.exs`.
- [x] Corrective `mix compile --warnings-as-errors` exited successfully with only the known non-fatal Windows colocated-assets symlink warning.
- [x] Source-mutating formatting and exact check-only formatting passed for `router.ex`, `professional_availability_component.ex`, `professional_availability_preview_live.ex`, and `professional_availability_live_test.exs`; documented baseline catalog drift was preserved.
- [x] `mix assets.build` passed, validating the colocated carousel hook through Tailwind and esbuild. The command automatically downloaded missing Tailwind/esbuild executables before building; no generated workspace file remained modified.
- [ ] The full suite was intentionally not rerun because this corrective batch does not plausibly affect the three previously reproduced bootstrap failures; the prior 442/445 result remains the honest repository-wide receipt.
- [x] Corrective `git diff --check` passed; Git emitted only the documented line-ending conversion warnings for tracked source files.
- [x] Local-only corrective rerun passed 13/13 focused LiveView tests (seed 771955) and 46/46 existing catalog/backend integration tests (seed 303835).
- [x] The same local-only rerun passed `mix compile --warnings-as-errors`, exact check-only formatting for the four intentionally formatted files, `mix assets.build`, `mix phx.routes`, and `git diff --check`. No WSL, remote command, commit, push, or GitHub mutation was performed.
- [x] ODD-78-07 RED observed: `mix test test/origen_web/professional_availability_live_test.exs` passed 13/14 (seed 937321); the editor lacked the unified `#availability-section` card and therefore could not contain the booking controls or form footer under the established Origen palette contract.
- [x] ODD-78-07 GREEN observed: the focused command passed 14/14 (seed 746820); weekly windows and editable booking controls now share one basic card using Origen semantic surface/border/text tokens, with Save/Cancel in its card footer.
- [x] ODD-78-08 RED observed: after correcting a test-only selector delimiter, the focused command passed 14/15 (seed 450168); changing the Monday start to `08:10` did not add field-specific invalid semantics, warning association, red-border styling, or disabled confirmation.
- [x] ODD-78-08 GREEN observed: the focused command passed 15/15 (seed 674312); an off-interval boundary now receives field-specific `aria-invalid`, a red danger border, and an associated Spanish warning, while Save is disabled and a direct submit does not call replacement. Correcting the value clears the error and re-enables Save.
- [x] Final focused LiveView verification passed 15/15 (seed 878057): `mix test test/origen_web/professional_availability_live_test.exs`.
- [x] Final existing catalog/backend verification passed 46/46 (seed 590360): `mix test test/origen_web/consultation_type_catalog_live_test.exs test/origen/availability_test.exs`.
- [x] `mix compile --warnings-as-errors` passed with only the known non-fatal Windows colocated-assets symlink warning (`:eperm`).
- [x] Source-mutating `mix format` and exact `mix format --check-formatted` passed for `professional_availability_component.ex` and `professional_availability_live_test.exs`; the known catalog whitespace baseline was untouched.
- [x] `mix assets.build` passed (Tailwind v4.3.0 and esbuild completed successfully).
- [x] `mix phx.routes` passed and listed both `GET /configuracion/profesional` and the dev-only `GET /dev/professional-availability` route.
- [x] `git diff --check` passed with only line-ending conversion warnings for the three intentionally changed tracked files.
- [x] No backend domain file, migration, schema, unrelated source, commit, push, pull request, GitHub artifact, WSL, or remote operation was changed or performed.

## Pending WSL manual checklist

ODD-78-05 remains pending. When WSL browser authorization is available in a future session, verify all of the following against the real authenticated Professional route:

- [ ] Use only the keyboard to open and close the availability editor.
- [ ] Add, remove, clear, copy, cancel, and save availability without pointer input.
- [ ] At a narrow viewport, confirm all seven summary days and editor days remain reachable.
- [ ] Confirm the previous/next controls move to the adjacent day and stop at the first and last days.
- [ ] Confirm touch or trackpad horizontal scrolling and snap alignment remain usable.
- [ ] Confirm focus remains visible and follows a logical order after LiveView updates.
- [ ] Confirm a screen reader announces disclosure state, validation alerts, save status, and invalid-field associations.
- [ ] Confirm the production route uses persisted backend data and never displays development-preview messaging.

## Next step

Use `/dev/professional-availability` for safe Windows visual iteration, then run the real authenticated WSL keyboard/narrow-viewport milestone. Keep ODD-78-05 and ODD-78-06 pending until those checks and the known full-suite blockers are resolved.
