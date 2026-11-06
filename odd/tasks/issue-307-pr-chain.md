# Issue #307 — Incremental frontend delivery
Strategy: `stacked-to-main`; verified default branch: `develop`. Original implementation: `65af7e6`; integration baseline: `b022a14`.
Preserve the original branch. Repackage behavior with its tests and docs; do not remove coverage or compress code to fit the review budget.

## Specs

- S1: “Elijo la opción 2.”
- S2: “Autorizo. Te consulto si respetaste el límite de líneas de código por PR.”
- S3: “Si, autorizo. Ten en cuenta que el CI de Github tarda mucho, así q no te quedes esperando a q termine (y gastando tokens del modelo de forma innecesaria). Cuando esté hecho el PR yo lo mergeo a develop y te aviso cuando lo haya mergeado. No olvides de colocar que Closes # para que la issue se cierre.”
- S4: “Empecemos con la implementación del frontend de la reserva propia del Paciente. Sería completar la subissue #307 junto con sus criterios de aceptación. Para el desarrollo de esta subissue crea una rama y trabaja de forma prolija.”

## Tasks

- T1 [S1,S2,S4] delegated (context backstop): done — contract-safe policy copy, cancellation-policy removal, matching assertions, and observed checks recorded; commit pending.
- T2 [S1,S2,S4] delegated (context backstop): pending — availability and catalog readiness, failure states, supporting doubles, and tests; commit pending.
- T3 [S1,S2,S4] delegated (context backstop): pending — validated selection and navigation with rejection tests; commit pending.
- T4 [S1–S4] delegated (context backstop): pending — booking lifecycle, outcomes, refresh, and final historical evidence; commit pending.

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
