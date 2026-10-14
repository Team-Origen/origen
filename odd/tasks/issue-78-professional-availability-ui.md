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
- The prior one-commit/one-push authorization was consumed by commit `bac38ca`. This corrective batch authorizes local implementation only: no commit, push, pull request, GitHub mutation, WSL, or remote operation.
- The 2026-10-04 continuation supersedes only the prior WSL restriction: WSL is now the primary local environment, and local environment setup, command execution, testing, and source corrections required to run this branch are authorized. Commit, push, pull request, and GitHub mutation remain unauthorized unless requested separately.
- The 2026-10-04 develop-sync continuation authorizes `git fetch origin` through the current HTTPS session and a local no-commit merge of `origin/develop` into this feature branch. It does not authorize a merge commit, push, pull request, direct mutation of `develop`, or any other GitHub mutation.
- The 2026-10-05 interval-workflow continuation authorizes local domain, UI, documentation, and test changes required to implement a guided agenda-interval change. Commit, push, pull request, GitHub mutation, and destructive appointment mutation remain unauthorized.

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
- Existing appointments, exceptions, holidays, slot generation, and audit-history presentation were outside the original Issue 78 scope.
- The agenda interval remains a global grid invariant; interval and weekly-availability boundaries are not silently decoupled.
- Before interval review begins, the Professional is warned that the change can affect consultation-type durations and weekly availability and that nothing changes before final confirmation.
- An interval proposal preflights consultation-type duration changes, incompatible weekly boundaries, and future-appointment conflicts without persisting partial state.
- Incompatible availability is never silently reset or rounded. The Professional explicitly reviews and adjusts the complete resulting week before confirmation.
- Final confirmation applies the interval, consultation-type duration effects, reviewed availability, and audit evidence atomically. Validation, persistence, audit, or stale-preview failure rolls back every effect.
- Existing appointments are never moved, resized, or cancelled automatically; a detected conflict blocks confirmation with actionable evidence.
- Booking-calendar integration passes agenda interval and consultation duration as distinct concepts and honors the persisted agenda interval.
- During interval review, every boundary that does not align with the proposed grid is visibly and accessibly invalid. Boundary controls offer only grid-aligned selectable times, while preserving the incompatible current value as a disabled corrective prompt until the Professional chooses a valid replacement.
- The canonical weekly-availability editor uses the same current-grid selectors and corrective invalid-state semantics as interval review; free-form time entry is not used in either workflow.
- The complete interval-change workflow runs inside one accessible modal. While it is open, the settings page behind it is inert to pointer and keyboard interaction and focus remains in the modal.
- An interval-change modal cannot open while the weekly-availability editor has unsaved changes. The Professional must save or cancel that draft first; the application never discards it silently.
- During interval review, every active Consultation Type whose proposed duration exceeds 240 minutes is visibly and accessibly marked as a danger and keeps final confirmation disabled.
- During interval review, a closing boundary that is not later than its opening boundary is visibly and accessibly marked as invalid, explains the ordering problem, and keeps final confirmation disabled until corrected.
- During interval review, every window participating in a true overlap is identified with visible and accessible danger feedback; exactly touching windows remain valid and normalize according to the backend contract.
- The interval-review modal offers a temporary copy action that copies one source day's complete reviewed windows to explicitly selected destination days without persisting anything before final confirmation.

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
- Environment boundary: WSL is now the primary development, database, test, Phoenix, and browser-verification environment.
- Selected workflow: native WSL. Preserve strict RED/GREEN/REFACTOR for any new source correction, use test-only doubles solely for exceptional presentation states, and run both automated and browser-level verification from WSL.
- The public test seams and screen inventory are confirmed; implementation may begin through strict vertical RED/GREEN/REFACTOR slices.

## Checklist

- [x] ODD-78-01 — Expose the authenticated Professional configuration route outside the demo gate and load availability through the real owner-bound backend seam.
- [x] ODD-78-02 — Build the weekly draft editor with seven weekdays, multiple interval-aware windows, and keyboard-operable add, remove, and clear actions.
- [x] ODD-78-03 — Add booking-horizon and minimum-lead-time controls with the confirmed ranges, defaults, increments, and organization-timezone guidance.
- [x] ODD-78-04 — Submit one complete replacement, preserve drafts on rejection, consolidate backend validation errors, and adopt normalized backend data on success.
- [ ] ODD-78-05 — Verify semantic accessibility, keyboard workflows, and narrow-screen reflow without relying on color or pointer-only controls.
- [x] ODD-78-06 — Run focused integration checks, compilation/format checks, the applicable full suite, and record honest final evidence.
- [x] ODD-78-07 — Correct the availability palette using established Professional configuration/catalog tokens, unify weekly and booking controls in one visual section, and place Save/Cancel in that section's form footer.
- [x] ODD-78-08 — Prevent confirmation for manually typed off-interval or otherwise locally invalid boundaries, with field-specific red invalid styling, accessible associated warnings, and recovery when corrected.
- [x] ODD-78-09 — Characterize the public dynamic agenda-interval contract and ensure Desde/Hasta guidance, HTML step, and misalignment feedback visibly use the configured interval without changing the five-minute minimum-lead rule.
- [x] ODD-78-10 — Add the top Professional settings navbar with a disabled Back-to-Agenda visual action, then audit and correct this screen to use institutional semantic color tokens legibly in light and dark mode.
- [x] ODD-78-11 — Restore native WSL runtime readiness, execute the focused and applicable repository checks, boot Phoenix, and correct only observed branch-caused failures.
- [x] ODD-78-12 — Synchronize current `origin/develop` into the Issue 78 branch without publishing, resolve integration drift, and revalidate the complete Issue 78 contract.
- [x] ODD-78-13 — Replace the false configuration-load failure with a targeted interval-incompatibility result that preserves the loaded settings and explains that nothing changed.
- [x] ODD-78-14 — Add the pre-change warning and an accessible review flow covering consultation-type duration changes, incompatible weekly boundaries, and explicit availability adjustments.
- [x] ODD-78-15 — Apply the confirmed interval, reviewed availability, consultation-type effects, and audit event in one stale-safe transaction with complete rollback on failure.
- [x] ODD-78-16 — Make patient-calendar slot generation consume the persisted agenda interval independently from consultation duration and cover a non-default interval end to end.
- [x] ODD-78-17 — Mark proposed-grid boundary violations in red and replace free-form interval-review time entry with accessible selectors containing only valid grid-aligned choices.
- [x] ODD-78-18 — Replace weekly-availability free-form time entry with the same current-grid selectors, danger semantics, and end-only `24:00` behavior.
- [x] ODD-78-19 — Move the entire interval-change review into an accessible modal, make the background inert, and block modal opening while weekly availability has an unsaved draft.
- [x] ODD-78-20 — Mark every Consultation Type whose proposed duration exceeds 240 minutes as an accessible danger inside the interval-review modal while preserving the existing confirmation block.
- [x] ODD-78-21 — Mark interval-review closing selectors red when they are not later than their opening selector, associate an accessible explanation, and prevent confirmation until corrected.
- [x] ODD-78-22 — Mark every interval-review window involved in a true overlap with accessible danger semantics while preserving touching-window normalization and blocking confirmation until corrected.
- [x] ODD-78-23 — Add a keyboard-operable interval-review copy action that copies a source day's complete draft windows to selected destination days without early persistence.
- [x] ODD-78-24 — Reject malformed or incomplete interval-review change payloads without crashing the LiveView or mutating the current review draft.
- [x] ODD-78-25 — Render the Professional settings route inside an explicit light-theme boundary so its page, surfaces, controls, and modal remain legible when the global preference is dark.
- [ ] ODD-78-26 — Replace the non-autonomous draft PR chain with complete CI-valid work units, correct Issue-link metadata, and make the final Issue #78 tree pass the repository formatter and Dialyzer gates.

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
- A non-five-minute configured agenda interval is displayed in schedule-window guidance, drives the Desde/Hasta HTML `step`, and appears in the field-specific misalignment warning; the minimum-lead input keeps its independent five-minute step.
- The Professional settings content begins with a horizontal navbar/header containing `Ajustes` on the left and a visually button-like `Volver a Agenda` action with back-arrow semantics on the right.
- `Volver a Agenda` is honestly non-navigating: it renders as a disabled `type="button"` control with disabled and `aria-disabled` semantics, not as a link or dead clickable control.
- This screen uses the project's institutional semantic surface, border, text, action, and danger tokens in both light and dark schemes, with no new hard-coded institutional colors or unconditional light-only surfaces.
- Opening an interval change first presents an impact warning with `Review changes` and `Cancel`; no mutation occurs by opening or dismissing it.
- The review names every affected active consultation type and incompatible availability boundary, permits explicit complete-week adjustment, and exposes a final before/after summary.
- No interval, consultation type, availability window, appointment, or audit entry changes before final confirmation.
- One final confirmation commits every approved effect atomically; any validation, stale-state, persistence, or audit failure leaves the prior configuration intact.
- Availability is never silently reset or rounded, and existing appointments are never automatically moved, resized, or cancelled.
- A rejected interval change keeps the settings screen usable and reports the specific blocker rather than claiming that configuration loading failed.
- Patient booking uses the persisted agenda interval as the slot grid while consultation duration remains the required contiguous-slot length.
- Each incompatible interval-review boundary has `aria-invalid`, an associated explanation, and visible danger styling; selecting a corrected value clears that field's invalid state.
- Start selectors list only valid times before midnight. End selectors list only valid times plus `24:00`; a preserved incompatible current value appears only as a disabled selected corrective prompt and cannot be submitted as valid.
- Weekly-availability selectors follow the persisted interval and preserve all existing draft behavior, including add/remove/copy/cancel/save, local validation, normalization, and complete replacement.
- The interval modal owns warning, impact review, availability adjustment, conflict evidence, summary, cancellation, and final confirmation; no interval-review form remains operable in the background page.
- Modal focus is trapped, Escape/Cancel closes without mutation, and the obscured settings controls cannot receive pointer or keyboard interaction.
- If weekly availability is dirty, opening the interval modal is refused with actionable feedback asking the Professional to save or cancel first. The draft remains unchanged.
- Repeated interval-review selectors expose unique accessible names containing the weekday, one-based window ordinal, and boundary role.
- An incompatible Consultation Type effect over 240 minutes uses danger styling plus non-color explanatory text and remains part of the existing blocking calculation.
- A reviewed weekly window with `end <= start` marks its closing selector with `aria-invalid`, danger styling, and an associated ordering message; correcting the order clears that state without discarding other reviewed values.
- Every reviewed window participating in a true overlap is identifiable without relying on color, and confirmation remains disabled; exactly touching windows are not marked invalid and continue through backend normalization.
- Copying reviewed hours requires an explicit source and at least one explicit destination, replaces only the selected destination drafts, preserves every other reviewed day and blocker, and does not persist before final confirmation.
- Malformed or incomplete interval-review change payloads leave the current review draft unchanged and do not terminate the LiveView process.
- The Professional settings route uses the established light page, surface, text, border, and action palette even when the document-level theme is dark; other routes retain their existing theme behavior.
- Every replacement child PR is syntactically complete and passes the repository's applicable format, compile, static-analysis, and focused test gates against its immediate parent; superseded draft PRs remain traceable but are not merged.

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
- Public rendered characterization with a non-five-minute agenda interval covering visible interval copy, Desde/Hasta `step`, dynamic misalignment feedback, and the unchanged five-minute minimum-lead step.
- Focused rendered assertions for the top-level settings header, `Ajustes`, and disabled non-navigating `Volver a Agenda` button with back-arrow semantics.
- Stable screen-local assertions for semantic design tokens and the absence of newly introduced hard-coded institutional colors or unconditional light-only surfaces; avoid duplicating complete class lists.
- Domain and LiveView RED/GREEN coverage for warning dismissal, no-mutation preflight, combined type/availability blockers, reviewed availability adjustments, final atomic success, rollback, stale review, and audit failure.
- Calendar integration coverage proving that a non-default persisted agenda interval is not replaced by consultation duration.
- Focused LiveView coverage for a 40-minute proposal proving incompatible boundaries render in danger state, selectors expose only aligned choices, `24:00` is end-only, and choosing valid boundaries removes the blockers.
- Focused availability-component coverage proving current-grid option domains, red invalid state, end-only `24:00`, and preservation of add/remove/copy/cancel/save behavior.
- Focused modal coverage for complete workflow containment, focus/dialog semantics, inert background, Escape/Cancel no-mutation behavior, and refusal to open over a dirty availability draft.
- Focused LiveView RED/GREEN coverage for danger presentation of proposed Consultation Type durations above 240 minutes.
- Focused LiveView RED/GREEN coverage for an interval-review closing selector at or before opening, disabled confirmation, associated accessible feedback, and recovery after correction.
- Focused LiveView RED/GREEN coverage for identifying all windows in a true overlap, accepting touching windows, disabling confirmation, and recovering without unrelated draft loss.
- Focused LiveView RED/GREEN coverage for source/destination copy semantics, keyboard-operable controls, no early persistence, and preservation of unselected days.
- Focused LiveView RED/GREEN coverage for missing or malformed interval-review and copy payloads without process termination or draft mutation.
- Focused rendered coverage for the explicit light-theme boundary and established semantic page/text tokens, plus an asset build proving the nested light boundary compiles.
- Per-branch CI-equivalent checks for every replacement child, including full formatting, warnings-as-errors compilation, Sobelow, Dialyzer, focused tests, and issue-link validation before publication.

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
- [x] Historical Windows full-suite result was 442/445 with 8 excluded (seed 794936); its three environment-sensitive bootstrap failures were superseded by the native WSL full-suite pass recorded below.
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
- [x] ODD-78-09 characterization passed on its first run: the focused LiveView command passed 16/16 (seed 628219). With the existing 30-minute configuration, public rendered behavior displayed `30 minutos`, rendered Desde/Hasta with `step="1800"`, produced the dynamic 30-minute misalignment warning, and preserved `step="5"` for minimum lead time. No fabricated RED or implementation change was needed.
- [x] ODD-78-10 navbar RED observed after correcting a test-only selector delimiter: focused tests passed 16/17 (seed 138724) because the settings content had no top `#professional-settings-header` with `Ajustes` and the disabled agenda action.
- [x] ODD-78-10 navbar GREEN observed: focused tests passed 17/17 (seed 114929). The first settings-content child is now a horizontal header with `Ajustes` and a Petal outline button carrying the back-arrow icon, `type="button"`, `disabled`, and `aria-disabled="true"`, with no link or click behavior.
- [x] ODD-78-10 semantic-color RED observed: focused tests passed 16/17 (seed 948988) because the screen root still used unconditional `text-gray-900` and did not expose dark-scheme page semantics.
- [x] ODD-78-10 semantic-color GREEN observed: focused tests passed 17/17 (seed 337340). The authenticated page, preview harness, schedule cards, window surfaces, copy panel, carousel controls, danger messages, duration preview, and color-swatch border now retain the established semantic roles with explicit dark-mode counterparts. No global token or palette change was made.
- [x] Final focused verification passed 17/17 (seed 253396): `mix test test/origen_web/professional_availability_live_test.exs`.
- [x] The first catalog/backend verification run passed 45/46 (seed 738331); the sole failure was the superseded heading expectation `Configuración`. After updating that existing public-copy assertion to `Ajustes`, the exact command passed 46/46 (seed 925198).
- [x] `mix compile --warnings-as-errors` passed with no output on the final run.
- [x] Source-mutating `mix format` and exact `mix format --check-formatted` passed for `professional_availability_component.ex`, `professional_availability_preview_live.ex`, `professional_availability_live_test.exs`, and `consultation_type_catalog_live_test.exs`. The known baseline formatting drift in `consultation_type_catalog_live.ex` was preserved.
- [x] `mix assets.build` passed (Tailwind v4.3.0 and esbuild completed successfully).
- [x] `mix phx.routes` passed and listed both `GET /configuracion/profesional` and the dev-only preview route.
- [x] `git diff --check` passed with only expected LF-to-CRLF working-copy warnings.
- [x] This corrective batch performed no full-suite run, WSL/manual browser check, commit, push, pull request, GitHub mutation, remote operation, backend behavior change, database change, or global style change.
- [x] WSL continuation resumed on `feature/78-professional-availability-ui` at `6049568`, synchronized with `origin`; PostgreSQL 16 cluster `main` exists on port 5433 but was observed down, and Phoenix was not listening on port 4000.
- [x] PostgreSQL 16 `main` was started on port 5433; `mix setup` completed with the database already created and migrated, and assets built successfully. Missing `inotify-tools` remains an optional live-reload limitation.
- [x] WSL test-runtime RED observed before ExUnit: Postgrex SCRAM authentication failed with `KeyError: key :password not found` because test configuration had no local password.
- [x] WSL test-runtime GREEN observed after adding ignored `config/test.local.exs` support with mode 600: focused availability passed 17/17 (writer seed 867728; parent spot-check seed 79172), catalog/backend passed 46/46 (seed 656043), check-only formatting and `git diff --check` passed. Native risk assessment classified the 14-line current candidate as medium.
- [x] Full native WSL suite passed 453/453 with 8 PostgreSQL-security tests excluded by the configured default tag (seed 544258); compilation, assets, routes, and changed-file formatting checks also passed.
- [x] Phoenix started persistently in WSL as PID 16576: `/dev/professional-availability` returned HTTP 200, anonymous `/configuracion/profesional` returned the expected HTTP 401, and Context7, Engram, Petal, and Tidewave all reported connected.
- [x] Fetched `origin` through the explicitly authorized HTTPS session and prepared a local no-commit merge of `origin/develop` at `e8a39fc`; `develop` itself was not mutated and no push or PR occurred. The sole router conflict was resolved by preserving both the Issue 78 authenticated/preview routes and develop's agenda/CSP routes.
- [x] Post-merge verification passed: focused availability 17/17 (writer seed 56412; independent seed 768823; parent spot-check seed 847055), catalog/backend 46/46 (seed 814578), and full suite 651/651 with 29 skipped and 8 excluded (seed 984054). Compilation, changed-file formatting, assets, routes, migrations, and unstaged whitespace checks passed.
- [x] Independent verification confirmed the Issue 78 owner-only route and dev-only preview contract. Staged whitespace warnings are inherited unchanged from `origin/develop` in two documentation files plus one EOF blank line; no Issue 78 source is affected.
- [x] The merged runtime started as PID 28279: preview returned HTTP 200, anonymous Professional settings and agenda routes returned HTTP 401, and all four MCP servers including Tidewave connected.
- [x] ODD-78-13 RED observed: `mix test test/origen_web/consultation_type_catalog_live_test.exs` passed 37/38 (seed 152257); an availability-only interval incompatibility rendered the global configuration-load failure instead of `#interval-apply-error`.
- [x] ODD-78-13 GREEN observed: the same focused command passed 38/38 (seed 184387); the loaded settings remained visible for an availability-only incompatibility. The completed guided-flow refactor now presents the boundary evidence inside the read-only review and disables final confirmation without exposing the global configuration-load failure.
- [x] ODD-78-14 RED observed: `mix test test/origen/consultation_types_test.exs test/origen_web/consultation_type_catalog_live_test.exs` passed 75/77 (seed 38368); the read-only preview API was undefined and the accessible pre-change warning/review flow was absent.
- [x] ODD-78-14 evidence correction RED observed: the prior focused GREEN (2/2, seed 903649) proved the populated-settings path only and overstated read-only behavior. The new absent-row regressions failed 0/2 (seed 972656) because `preview_agenda_interval/3` persisted one default `agenda_settings` row.
- [x] ODD-78-14 evidence correction GREEN observed: the same absent-row slices passed 2/2 (seed 971554) after preview switched to deterministic non-persisted defaults and the stale token began distinguishing absent state. Confirmation creates the row only inside its authorized transaction, while a concurrently materialized row is rejected as stale without audit persistence.
- [x] ODD-78-14 correction verification passed: consultation workflow 87/87 (seed 934193), the prior 134-test combined command now 136/136 with the two regressions (seed 696634), and the full suite 666/666 with 29 skipped and 8 PostgreSQL-security tests excluded (seed 54598). Compilation with warnings as errors, exact changed-file formatting, assets, and unstaged whitespace checks passed.
- [x] ODD-78-15 RED observed: `mix test test/origen/consultation_types_test.exs:857 test/origen/consultation_types_test.exs:890 test/origen/consultation_types_test.exs:920 test/origen/consultation_types_test.exs:945 test/origen_web/consultation_type_catalog_live_test.exs:283` failed 5/5 with 77 excluded (seed 581276); the confirmed command was undefined and the final review action remained disabled.
- [x] ODD-78-15 GREEN observed: the same five-slice command passed 5/5 with 77 excluded (seed 351149); final confirmation now re-locks and revalidates state, rejects stale previews and privacy-minimized future conflicts, and atomically persists the interval, reviewed complete-week availability, derived type effects, and `agenda_interval_changed` audit event with rollback on audit failure.
- [x] ODD-78-15 refactor verification passed 84/84 (seed 406461): `mix test test/origen/consultation_types_test.exs test/origen_web/consultation_type_catalog_live_test.exs`; compatible, stale, and unavailable final-confirmation presentations keep loaded settings visible and never fall back to the configuration-load failure.
- [x] ODD-78-15 bypass closure passed 84/84 (seed 911563): the legacy two-argument apply API now returns a read-only `confirmation_required` preview and cannot mutate interval state; only the stale-token confirmed command persists the reviewed transaction.
- [x] ODD-78-15 midnight-boundary RED/GREEN observed: `mix test test/origen/consultation_types_test.exs:848` first failed 0/1 (seed 162569) because 23:00–24:00 was falsely reported as a conflict, then passed 1/1 (seed 219132) after mapping next-day midnight to minute 1440 for the starting weekday.
- [x] ODD-78-16 RED observed: `mix test test/origen/appointments/database_calendar_test.exs:91 test/origen_web/live/patient_booking_calendar_live_test.exs:121` failed 2/2 with 8 excluded (seed 362582); `DatabaseCalendar` accepted a duration-derived interval override (45-minute starts) and the LiveView still rendered the 20-minute persisted-grid consultation as 45 minutes.
- [x] ODD-78-16 GREEN observed: the same focused command passed 2/2 with 8 excluded (seed 875378); `DatabaseCalendar` now owns the persisted slot-grid interval, while the patient LiveView derives contiguous consultation duration from the catalog interval and passes only that duration, producing 20-minute starts for a 60-minute consultation end to end.
- [x] ODD-78-16 adapter refactor verification passed 16/16 (seed 130180): the database-backed and mock calendars both own their configured slot grids independently from consultation duration, and the patient calendar remains green.
- [x] Pre-correction implementation verification passed: consultation workflow 85/85 (seed 49930), availability integration 26/26 (seed 278113), calendar integration 17/17 (seed 835112), and combined focused coverage 134/134 (seed 213354). The superseding final results are recorded in the ODD-78-14 correction evidence above.
- [x] Final `mix compile --warnings-as-errors`, safe exact changed-file `mix format --check-formatted`, `mix assets.build`, and `git diff --check` passed. The known baseline formatting drift in `consultation_type_catalog_live.ex` was preserved.
- [x] Pre-correction full suite passed 664/664 with 29 skipped and 8 PostgreSQL-security tests excluded by the configured default tag (seed 323537); the superseding final suite passed 666/666 as recorded above.
- [x] The active no-commit merge remains intact at `MERGE_HEAD=e8a39fc18a93fda3514f1c19c9f6cc75ecdd4e9f`; no staging, unstaging, commit, reset, checkout, abort, fetch, pull, push, PR, GitHub mutation, or remote credential/session access occurred.
- [x] The implementation through ODD-78-19 is 3,062 authored changed lines across 18 files, including the new shared `OrigenWeb.TimeGrid` module. The review-budget overage is retained honestly because domain transaction safety, accessible UI, tests, and policy documentation are cohesive; suggested review slices are listed in the implementation report.
- [x] ODD-78-17 RED observed: `mix test test/origen_web/consultation_type_catalog_live_test.exs:298` failed 0/1 with 42 excluded (seed 832306) because the interval review still rendered unrestricted `type="time"` inputs without field-level danger semantics or a preserved disabled incompatible option.
- [x] ODD-78-17 GREEN observed: the same focused slice passed 1/1 with 42 excluded (seed 642958). A 40-minute proposal now exposes only the midnight-anchored grid in native selectors, excludes `24:00` from starts, includes valid `24:00` in ends, preserves `08:30` as disabled selected corrective context, blocks confirmation, and clears the associated danger state immediately after selecting `08:00` through the existing LiveView change event.
- [x] ODD-78-17 payload-preservation refactor RED/GREEN observed: the focused slice failed 0/1 (seed 58640) when changing one selector silently replaced another disabled incompatible `08:30` with an empty value, then passed 1/1 (seed 437686) after missing disabled values fell back to the current reviewed window. Final verification passed focused 1/1 (seed 991928), catalog/domain 88/88 (seed 811102), combined interval/availability/calendar 137/137 (seed 337656), and full suite 667/667 with 29 skipped and 8 PostgreSQL-security tests excluded (seed 667943). Compilation with warnings as errors, safe test-file formatting, assets, and `git diff --check` passed; known catalog-source formatting drift was preserved.
- [x] ODD-78-17 accessible-name correction RED/GREEN observed: `mix test test/origen_web/consultation_type_catalog_live_test.exs:390` failed 0/1 with 43 excluded (seed 174365) because both Monday windows exposed only `Desde`/`Hasta`, then passed 1/1 with 43 excluded (seed 322349) after each selector received a stable Spanish accessible name shaped as weekday, one-based window ordinal, and boundary role. Final correction verification passed both ODD-78-17 slices 2/2 (seed 247207), catalog/domain 89/89 (seed 465089), the existing combined command now 138/138 (seed 101960), and the full suite 668/668 with 29 skipped and 8 PostgreSQL-security tests excluded (seed 447445). Compilation with warnings as errors, safe test-file formatting, assets, and `git diff --check` passed.
- [x] ODD-78-18 RED observed: `mix test test/origen_web/professional_availability_live_test.exs:167` failed 0/1 with 17 excluded (seed 236294) because the weekly editor still rendered free-form `type="time"` inputs.
- [x] ODD-78-18 GREEN observed: the same focused slice passed 1/1 with 17 excluded (seed 446265). Weekly controls now share one pure current-grid option convention with interval review, preserve incompatible values as disabled selected corrective options, expose field-level danger/ARIA feedback and unique weekday/ordinal/role names, keep `24:00` end-only when aligned, and preserve unresolved disabled values across partial change payloads. Refactor verification passed the ODD-78-18 slice plus both ODD-78-17 slices 3/3 (seed 764999), and the complete availability LiveView file passed 18/18 (seed 746277), preserving add/remove/clear/copy/cancel/save and error-seam workflows.
- [x] ODD-78-19 RED observed: the four focused modal/concurrency slices failed 0/4 (seed 330714) because no `#open-interval-change-modal` trigger or unified modal workflow existed.
- [x] ODD-78-19 GREEN observed: the same four slices passed 4/4 with 44 excluded (seed 339487). Warning and review now remain inside one Petal modal outside an inert settings subtree; one cancel event covers explicit cancel, Escape, and click-away. Dirty weekly drafts block opening with actionable feedback and remain unchanged, clean open editors survive cancellation, and successful confirmation collapses and reloads the editor from the new grid. Refactor verification passed the complete catalog LiveView file 48/48 (seed 120488), availability LiveView file 18/18 (seed 723173), the combined domain/LiveView command 143/143 (seed 793490), and the full suite 673/673 with 29 skipped and 8 PostgreSQL-security tests excluded (seed 66849). Compilation with warnings as errors, safe exact formatting checks, assets, `git diff --check`, and the preserved `MERGE_HEAD=e8a39fc18a93fda3514f1c19c9f6cc75ecdd4e9f` all passed.
- [x] ODD-78-19 modal-error containment correction RED/GREEN observed: the stale-confirmation slice failed 0/1 with 47 excluded (seed 89646) because its actionable error remained in the inert background, then passed 1/1 with 47 excluded (seed 154104) after stale, validation, conflict, incompatibility, and unavailable confirmation feedback moved into the modal review step. Final verification passed catalog LiveView 48/48 (seed 476055), the combined command 143/143 (seed 100426), and the full suite 673/673 with 29 skipped and 8 excluded (seed 720933); compilation with warnings as errors, safe formatting, and assets also passed.
- [x] ODD-78-20/21 RED observed: `mix test test/origen_web/consultation_type_catalog_live_test.exs:403 test/origen_web/consultation_type_catalog_live_test.exs:441` failed 2/2 with 48 excluded (seed 941467). The rendered review exposed neither stable compatible/danger effect selectors nor closing-selector ordering danger, ARIA association, or explanatory feedback.
- [x] ODD-78-20/21 GREEN observed: the same focused command passed 2/2 with 48 excluded (seed 202228) after incompatible effects gained stable danger semantics and explicit blocking text, while `end <= start` gained end-only danger/ARIA feedback, local blocking, value-preserving recovery, and unchanged grid/`24:00` option behavior. The first implementation rerun passed 1/2 (seed 204354); its sole failure was a test-only CSS selector typo, corrected without production changes. Post-format focused verification passed 2/2 with 48 excluded (seed 777501).
- [x] ODD-78-20/21 regression verification passed: catalog LiveView 50/50 (seed 174772); the requested consultation/availability/calendar command 123/123 (seed 973174); `mix compile --warnings-as-errors`; test-file formatting and check-only formatting; `git diff --check`; and `MERGE_HEAD=e8a39fc18a93fda3514f1c19c9f6cc75ecdd4e9f`. The historically sensitive catalog source was not whole-file formatted, and the full suite was intentionally not run because focused and combined evidence exposed no broader need.
- [x] ODD-78-22/23 RED observed: after correcting a test-only sigil delimiter, `mix test test/origen_web/consultation_type_catalog_live_test.exs:497 test/origen_web/consultation_type_catalog_live_test.exs:562` failed 0/2 with 50 excluded (seed 840885). Overlapping windows had no stable danger/ARIA semantics, and the interval review had no explicit source/destination copy controls.
- [x] ODD-78-22/23 GREEN observed: the focused slices passed 2/2 with 50 excluded (seed 398746), and the post-refactor command at current lines 497/569 passed 2/2 with 50 excluded (seed 682907). True overlap marks every participating window and selector, disables confirmation, and clears for touching windows that normalize on final confirmation without losing unrelated values. The temporary copy action replaces only selected destination drafts, supports an empty source, and performs no persistence before final confirmation.
- [x] ODD-78-22/23 regression verification passed: catalog LiveView 52/52 (seed 770774); the requested consultation/catalog/availability command 115/115 (seed 966096); `mix compile --warnings-as-errors`; exact test-file formatting; `mix assets.build`; and `git diff --check`. The catalog source check-only formatter still reports its documented baseline drift, so no whole-file formatting churn was introduced. The full suite was intentionally not run because focused and combined evidence exposed no broader risk.
- [x] ODD-78-24 RED observed: `mix test test/origen_web/consultation_type_catalog_live_test.exs:644` failed 0/1 with 52 excluded (seed 786988) because a change event missing `interval_review` raised `FunctionClauseError` and terminated the LiveView.
- [x] ODD-78-24 GREEN observed: the same focused command passed 1/1 with 52 excluded after the minimal correction (seed 198398), and the post-refactor rerun passed 1/1 with 52 excluded (seed 860261). Missing or non-map `interval_review` and non-map `interval_review_copy` payloads now return the unchanged socket, preserving the rendered review and copy draft while the LiveView remains alive.
- [x] ODD-78-24 verification passed: the requested lines 497/569/644 command passed 3/3 with 50 excluded (seed 256057), and the complete catalog LiveView file passed 53/53 (seed 754489). `mix compile --warnings-as-errors`, exact test-file `mix format --check-formatted`, and `git diff --check` also passed with no output; the historically drifting catalog source was not whole-file formatted.
- [x] Independent ODD-78-22/23 verification passed focused 2/2 with 50 excluded (seed 40501), catalog LiveView 52/52 (seed 25557), compilation, and diff checks before identifying the ODD-78-24 malformed-payload crash. Parent ODD-78-24 spot-check passed 1/1 with 52 excluded (seed 798092) after the correction.
- [x] The corrected Phoenix runtime started at `127.0.0.1:4000`: `/login` and `/dev/professional-availability` returned HTTP 200, while anonymous `/configuracion/profesional` returned the expected HTTP 401. Missing `inotify-tools` affected only optional development live reload.
- [x] ODD-78-25 RED observed: `mix test test/origen_web/professional_availability_live_test.exs:249` failed 0/1 with 17 excluded (seed 816582) because the route root did not render `main[data-theme="light"]` with the established `bg-page` and `text-text` tokens.
- [x] ODD-78-25 GREEN observed: the same focused command passed 1/1 with 17 excluded (seed 540713) after adding the route-local light-theme boundary, removing its root dark overrides, and making the Tailwind v4 `dark` custom variant exclude nested light boundaries.
- [x] ODD-78-25 verification passed: Professional availability LiveView 18/18 (seed 750103); consultation catalog LiveView 53/53 (seed 389683); `mix compile --warnings-as-errors`; `mix assets.build` with Tailwind v4.3.0 and esbuild; exact test-file `mix format --check-formatted`; and `git diff --check`. No catalog test change or whole-file catalog source formatting was needed.
- [x] Parent structural readback confirmed the explicit light root and compiled nested-boundary selector; the parent `mix assets.build` spot-check passed. Phoenix restarted with rebuilt assets at `127.0.0.1:4000`: `/login` and `/dev/professional-availability` returned HTTP 200, while anonymous `/configuracion/profesional` returned the expected HTTP 401.
- [ ] ODD-78-25 authenticated dark-preference browser verification remains for the parent after restarting Phoenix so the rebuilt CSS and updated LiveView are loaded. Verify that `/configuracion/profesional`, including its modal and Petal controls, remains light while another route still follows the document dark theme.
- [x] Final integration regression against Issues #70–72 passed without modifying their artifacts: `mix test test/origen/integration/` passed 24/24 (seed 751334), both reproducible journey scripts completed successfully, `mix compile --warnings-as-errors` passed, and `git diff --check` remained clean.
- [x] ODD-78-26 final-tree RED was reproduced locally: `mix format --check-formatted` rejected `lib/origen_web/live/consultation_type_catalog_live.ex`, and `mix dialyzer --format short` exited 2 with `lib/origen/consultation_types.ex:808:41:call_without_opaque` at `Writer.append(event, @audit_decision)`.
- [x] ODD-78-26 final-tree corrections are GREEN: the repository formatter normalized the complete reported catalog LiveView source, and the precise `Events.agenda_interval_changed/2` constructor spec now exposes `Origen.Audit.Events.t()` without changing runtime behavior or adding a Dialyzer ignore.
- [x] ODD-78-26 final-tree static gates passed: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix sobelow --skip --threshold medium --exit`, and `mix dialyzer --format short`. Sobelow exited successfully while still reporting the existing ignored local-only database passwords in `config/dev.local.exs` and `config/test.local.exs`; neither file is part of the tracked candidate.
- [x] ODD-78-26 final-tree regression checks passed: the combined consultation-type, availability, catalog LiveView, Professional availability LiveView, booking-calendar, and integration command passed 159/159 (seed 111720); `mix test` passed 678/678 with 29 skipped and 8 PostgreSQL-security tests excluded (seed 252348); `mix assets.build` passed with Tailwind v4.3.0 and esbuild; and `git diff --check` passed with no output.
- [ ] ODD-78-26 remains open because replacement-chain construction and per-child autonomy have not been completed; this correction records final-tree evidence only.

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

Construct and verify the autonomous replacement chain for ODD-78-26, then complete the pending ODD-78-05 authenticated browser verification. Keep merges as a separate decision.
