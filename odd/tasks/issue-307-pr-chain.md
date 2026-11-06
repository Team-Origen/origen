# Issue #307 — Incremental frontend delivery
Strategy: `stacked-to-main`; verified default branch: `develop`. Original implementation: `65af7e6`; integration baseline: `b022a14`.
Preserve the original branch. Repackage behavior with its tests and docs; do not remove coverage or compress code to fit the review budget.

## Specs

- S1: “Elijo la opción 2.”
- S2: “Autorizo. Te consulto si respetaste el límite de líneas de código por PR.”
- S3: “Si, autorizo. Ten en cuenta que el CI de Github tarda mucho, así q no te quedes esperando a q termine (y gastando tokens del modelo de forma innecesaria). Cuando esté hecho el PR yo lo mergeo a develop y te aviso cuando lo haya mergeado. No olvides de colocar que Closes # para que la issue se cierre.”
- S4: “Empecemos con la implementación del frontend de la reserva propia del Paciente. Sería completar la subissue #307 junto con sus criterios de aceptación. Para el desarrollo de esta subissue crea una rama y trabaja de forma prolija.”
- S5: “Dejo en cola este mensaje por si ocurre algo. Si ya terminaste de crear los PRs y los pusheaste, haz el merge de los PRs a develop sin preguntarme. Realiza los merges de como de forma ordenada y correcta. No te olvides de colocar en el summary "Closes #" para que la issue se cierre de forma correcta. Necesito que lo hagas solo por no voy a estar pendiente de la computadora.”

## Tasks

- T1 [S1,S2,S4] delegated (context backstop): done — contract-safe policy copy, cancellation-policy removal, matching assertions, and observed checks recorded; commit `bfacc29` (106 changed lines).
- T2 [S1,S2,S4] delegated (context backstop): done — availability/catalog readiness, safe failure and empty states, supporting doubles, and regression tests; commit `1db5584` (191 changed lines).
- T3 [S1,S2,S4] delegated (context backstop): done — validated professional/type/date/slot selection and navigation with rejection tests; commit `0b668ee` (156 changed lines).
- T4 [S1,S2,S4] delegated (context backstop): done — validated booking submission, duplicate/in-progress guards, stale-slot conflict handling, and sanitized failures with matching tests; commit `5632e24` (291 changed lines).
- T5 [S1–S5] delegated (context backstop): done — truthful booking outcomes, refreshed new-booking availability, frozen historical surfaces, and final evidence; commit pending.

## Log

- L1 User delivery choice: “Elijo la opción 2.”
- L2 User budget question: “Autorizo. Te consulto si respetaste el límite de líneas de código por PR.”
- L3 User publication boundary: “Si, autorizo. Ten en cuenta que el CI de Github tarda mucho, así q no te quedes esperando a q termine (y gastando tokens del modelo de forma innecesaria). Cuando esté hecho el PR yo lo mergeo a develop y te aviso cuando lo haya mergeado. No olvides de colocar que Closes # para que la issue se cierre.”
- L4 The approved source has 872 changed lines (704 additions, 168 deletions): 794 code/test lines and 78 documentation lines. The issue has `status:approved`; no PR or source branch has been pushed yet.
- L5 One read-only slicing pass identified four behavioral units. Estimates are not verified counts; the lifecycle unit may exceed 400 lines. Measure each actual slice, keep behavior/tests/docs together, and report any unavoidable overage without code golf or repeated repartitioning.
- L6 The original implementation remains on `feat/307-patient-booking-frontend` at `65af7e6`. The five delivery surfaces are unchanged between its merge base `3d0a5e7` and current `origin/develop` at `b022a14`, so repackaging must preserve their final content exactly.
- L7 The user confirmed the manual frontend walkthrough. The latest related automated run passed 49 tests; historical full-suite evidence records 894 passed, 32 skipped and 8 excluded. These results do not attest intermediate slices; each slice needs its own focused checks.
- L8 RDD is off only for this clone by the user's explicit exception. The original native review remains escalated, not approved; no reset, recovery or replacement review is authorized. The standalone timezone failure was missing `tzdata` startup in a transient helper, not a production calendar bug.
- L9 Publish the first PR against `develop` and subsequent PRs against their immediate predecessor. Use `Refs #307` in partial PRs and `Closes #307` only in the final PR. Do not wait for or monitor GitHub CI, merge, enable auto-merge, or close the issue manually; the user owns merges.
- L10 T1 RED: the authorized baseline-check command exited 2 with 8/10 passing and only the two new policy-copy assertions failing (cancellation policy still rendered; incomplete-profile copy still requested phone verification).
- L11 T1 GREEN: the same authorized test command exited 0 with 10/10 passing after applying only the final-source copy changes; no booking, readiness, selection, loading or error-flow behavior was repackaged.
- L12 T1 format/whitespace: the authorized format check exited 0 and `git diff --check` exited 0; no normalization was needed.
- L13 T1 measured review load: source/test diff is 27 additions plus 46 deletions (73 changed lines); this tracking document is 33 lines after this log, for 106 counted lines including the new document. T2–T4 remain pending.
- L14 Parent re-ran the T1 focused command: 10 passed, exit 0. T1 was committed as `bfacc29` (60 additions, 46 deletions); the next local branch is `feat/307-02-availability`. No remote branch or PR has been created.
- L15 T2 RED: the authorized focused command exited 2 with 13/14 passing; the only failure was the expected professional-list adapter error still crashing mount with a `MatchError`.
- L16 T2 GREEN: the same authorized focused command exited 0 with 14/14 passing after adding safe professional-list state, schedule error handling, and the six final-source fixture modules/tests; T1 copy/policy behavior remained intact.
- L17 T2 format/whitespace: the authorized format check exited 0 and `git diff --check` exited 0; no normalization was needed.
- L18 T2 measured review load: current diff is 25 source additions/deletions, 69 test additions/deletions, 88 fixture lines, and 9 tracking-document changed lines, for 191 counted changed lines including the new fixture. T3–T4 remain pending.
- L19 Parent T2 spot-check: 14 passed, exit 0; read-only assess: medium, 4 paths/191 lines, RDD off. Committed as `1db5584`; T3 branch is `feat/307-03-selection`.
- L20 User: “No gastes tanto tiempo en hacer todo el proceso de crear los PRs. Sólo hazlos sin gastar tanto tiempo. Voy a dejar la PC corriendote, no me preguntes nada. Termina de crear los PRs y pushealos sin mi permiso así yo puedo mergearlos desde otro dispositivo en el repositorio remoto de github.” Complete the authorized chain without further routine questions; do not wait for GitHub CI or merge.
- L21 T3 RED: the authorized focused command exited 2 with 14/15 passing; the expected failure was malformed navigation crashing on `String.to_integer("not-a-number")`.
- L22 T3 GREEN: the same authorized focused command exited 0 with 15/15 passing after final-source selection identity, date parsing, navigation-step validation, and safe slot selection were added; T1/T2 behavior remained intact.
- L23 T3 format/whitespace: the authorized format check exited 0 and `git diff --check` exited 0; no normalization was needed.
- L24 T3 measured review load: current diff is 123 view additions/deletions, 23 test additions, and 10 tracking-document changed lines, for 156 counted changed lines. T4 remains pending.
- L25 Parent T3 spot-check: 15 passed, exit 0; read-only assess: medium, 3 paths/156 lines, RDD off. Committed as `0b668ee`.
- L26 User: “Dejo en cola este mensaje por si ocurre algo. Si ya terminaste de crear los PRs y los pusheaste, haz el merge de los PRs a develop sin preguntarme. Realiza los merges de como de forma ordenada y correcta. No te olvides de colocar en el summary "Closes #" para que la issue se cierre de forma correcta. Necesito que lo hagas solo por no voy a estar pendiente de la computadora.” This supersedes earlier user-owned merge instructions: integrate in order only after required checks pass, using external background waits rather than model polling.
- L27 During the single construction pass, the remaining source/tests/historical docs measured 495 changed lines before tracking updates. The final lifecycle boundary therefore separates submission safety (T4) from truthful outcomes/refresh (T5), each with its own tests; no code compression, coverage deletion or file-type-only slice is permitted.
- L28 T4 RED: the authorized focused command exited 2 with 14/18 passing; the four expected failures covered missing-selection validation, duplicate confirmation, stale-slot conflict handling, and sanitized booking failures.
- L29 T4 GREEN: the same authorized focused command exited 0 with 18/18 passing after adding validated booking selection, duplicate/in-progress guards, stale-slot refresh, and generic failure messaging while retaining the existing confirmed/result template.
- L30 T4 format/whitespace: the authorized format check exited 0 and `git diff --check` exited 0; no normalization was needed.
- L31 T4 measured review load: current diff is 133 view additions/deletions, 145 test additions/deletions, and 13 tracking-document changed lines, for 291 counted changed lines. T5 remains pending.
- L32 Parent T4 spot-check: 18 passed, exit 0; read-only assess: medium, 3 paths/291 lines, RDD off. Committed as `5632e24`; final branch is `feat/307-05-results`. Remaining original delivery surfaces: 259 changed lines before tracking updates.
- L33 T5 RED: the first authorized focused run exited 2 with 12/19 passing because the copied working test still used the invalid `phx-value_slot_id` selector spelling; this was a test-shape failure, not valid behavioral RED evidence. The test was reconciled to the frozen final blob before the passing run.
- L34 T5 GREEN: the reconciled frozen final source/test pair passed the authorized focused command with exit 0 and 19/19 tests; this preserves T1–T4 coverage and adds truthful outcomes, result snapshots/status, and refreshed new-booking availability.
- L35 T5 format/whitespace/equality: the authorized format check exited 0 and `git diff --check` exited 0. Blob hashes for all five required surfaces match `65af7e6` exactly: view `57de0769`, test `5c3b21c0`, fixture `ea7438f8`, evidence `4e176f0f`, and historical task `0a84f248`.
- L36 T5 measured review load: source/test/task tracking changes are 122 + 59 + 5 changed lines, and the two frozen historical documents add 78 lines, for 264 changed lines before this final log update. T5 is complete; commit, publication and merge remain parent-owned.
- L37 Parent retrospective behavioral RED: the exact final 19-test file against the complete T4 LiveView loaded only in an isolated test process passed 17/19 and exited 2. The only failures were the expected confirmed/pending outcome headings; this corrects the invalid initial RED evidence without changing source files or beams.
- L38 Parent final GREEN: 51 booking seam tests passed, exit 0, seed 307, including calendar, patient self-booking/concurrency, assisted booking and all 19 LiveView tests. Parent independently verified all five frozen blobs match `65af7e6`; no full-suite rerun or agent browser run is claimed.
- L39 GitHub merge policy readback: develop requires one independent approval, last-push approval and resolved review threads; auto-merge is disabled. The user's merge authorization does not waive these protections. Publish the full chain, then merge only if GitHub requirements are satisfied; never self-approve or use an administrative bypass.
