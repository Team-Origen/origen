# Issue 371 — role-navigation delivery
Objective: deliver the approved implementation without changing its final source or scope.
Base: develop@5284df1; strategy: feature-branch-chain; runner: isolated MIX_TEST_PARTITION mix test.

## Specs

- S1: "SI LA VISTA ESTA APROBADA PREPARA LA ENTEGA, (PRS ENCADENADOS)".
- S2: "Cadena feature/tracker — recomendada".
- S3: "Commits, push y apertura de los PRs".
- S4: "Sí, agregar `status:approved` y seguir".

## Tasks

- T1 [S1-S4] inline; in_progress; prepare tracker and preserve source baseline; commit: pending.
- T2 [S1-S3] inline; pending; slice 1: authenticated role-specific login landings; commit: pending.
- T3 [S1-S3] inline; pending; slice 2: shared navbar and Professional adoption, own identity and tests; commit: pending.
- T4 [S1-S3] inline; pending; slice 3: Secretary own-account identity and Secretary/Administrator adoption; commit: pending.
- T5 [S1-S3] inline; pending; slice 4: Patient navigation, own identity, logout and real magic-link landing; commit: pending.
- T6 [S1-S3] inline plus independent verifier; pending; verify final preservation, publish branches/PRs, observe CI; commit: slice 4 closure.

## Log

- L1: User request verbatim: "SI LA VISTA ESTA APROBADA PREPARA LA ENTEGA, (PRS ENCADENADOS)".
- L2: User selected "Cadena feature/tracker — recomendada" and "Commits, push y apertura de los PRs" for github.com/Team-Origen/origen, using configured GitHub session. No merge or issue closure authorized. Use nonclosing Refs #371 throughout.
- L3: User explicitly selected "Sí, agregar `status:approved` y seguir". Acting session has ADMIN permission; issue #371 now carries status:approved and type:feature. No protected size label authorized.
- L4: Visual approval supplied by the human, not agent browser evidence. Original implementation: 978 tests passed, 32 skipped, 8 excluded; assets, format and diff checks exit 0. Independent 79-test rerun and 4 probes passed; first verifier run had one non-reproduced login 422.
- L5: Original app/source worktree remains on feat/371-role-navigation at 8118444 with uncommitted source. Delivery worktree uses current develop 5284df1; intervening issue #434 changes have no overlapping changed paths. Preserve those upstream changes. RDD mode reads off; do not start native review.
- L6: One bounded slicing pass selected four cohesive slices. Approximate implementation workload: 869 additions+deletions, including untracked component and tests. Slice 2 can exceed advisory 400 because shared component and its first production integration/tests form one review unit. Repository CI has no size gate; do not invent an exception requirement or omit tests.
- L7: Branch order: feat/371-navigation-tracker (draft toward develop) <- feat/371-01-role-landings <- feat/371-02-professional-navbar <- feat/371-03-secretary-navbar <- feat/371-04-patient-navbar. Each child targets its immediate predecessor. Tracker is no-merge until children are reviewed and integrated; final integration is not authorized here.
- L8: Preserve the exact approved final source/docs/tests, stage navigation test blocks incrementally, and verify each slice independently. Splitting completed behavior has no meaningful new RED; implementation RED/GREEN was already observed and recorded. No extra product behavior is authorized.
