# #386 — Approved frontend mock delivery

Publish the approved development-only mock as a feature-branch chain. No merge, issue closure, real payment integration or database changes are authorized.

## Specs

- S1: User authorization: “FORND APROFBADO, PUEDE PONER LA ISSUE EN STATUS: APROVED Y HACER EL PR”. Record the approval with the existing `status:approved` label on #386.
- S2: Selected delivery option: “PRs encadenados sobre una rama de la funcionalidad”. Keep the tracker draft/no-merge; first child targets the tracker and second child targets the first child.
- S3: Preserve the minimal production change boundary: shared existing card layout only; the new payment marker, Ver detalle and financial interactions remain a development-only mock. Real integration is separate.

## Tasks

- T1 [S1-S2] route: inline — Create tracker and delivery plan; commit pending.
- T2 [S2-S3] route: inline — Publish shared existing row layout with regression evidence; commit pending.
- T3 [S2-S3] route: inline — Publish cohesive mock, tests and documentation; commit pending.
- T4 [S1-S3] route: inline — Verify PR boundaries, labels and initial CI; evidence commit pending.

## Log

- L1: “FORND APROFBADO, PUEDE PONER LA ISSUE EN STATUS: APROVED Y HACER EL PR”.
- L2: User selected feature-branch-chain and authorized its commits/publication via the delivery question. Target verified: Team-Origen/origen, default develop, actor ADMIN. #386 status:approved applied and verified.
- L3: Prior checks: 51 focused preview/agenda/lifecycle tests passed; format and whitespace checks passed. Earlier full suite had 102 failures including database cleanup FK/count assertions; no clean-baseline proof. Independent verifier was unavailable. Browser automation unavailable; user explicitly approved the frontend. No claim of full technical or backend acceptance.
- L4: One slicing pass: shared layout is independently reviewable; the mock's LiveView, interaction tests and documentation stay together even above the advisory 400-line budget, because separating them would leave an incomplete behavior slice. No size-exception label requested or applied.
