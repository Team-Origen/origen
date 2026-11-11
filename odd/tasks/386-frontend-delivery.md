# #386 — Approved frontend mock delivery

Publish the approved development-only mock as a feature-branch chain. No merge, issue closure, real payment integration or database changes are authorized.

## Specs

- S1: User authorization: “FORND APROFBADO, PUEDE PONER LA ISSUE EN STATUS: APROVED Y HACER EL PR”. Record the approval with the existing `status:approved` label on #386.
- S2: Selected delivery option: “PRs encadenados sobre una rama de la funcionalidad”. Keep the tracker draft/no-merge; first child targets the tracker and second child targets the first child.
- S3: Preserve the minimal production change boundary: shared existing card layout only; the new payment marker, Ver detalle and financial interactions remain a development-only mock. Real integration is separate.

## Tasks

- T1 [S1-S2] route: inline — Done: tracker #467 (draft/no-merge), commit `474fed01334e5d6ef1e5cd0b2f784238a95ba919`.
- T2 [S2-S3] route: inline — Done: shared layout PR #468, commit `a0ae66d85f81e0bf68d548ac9d85f4bd14fe2ba0`; 39 agenda/lifecycle regressions passed.
- T3 [S2-S3] route: inline — Done: PR #469, mock implementation commit `d43cd5208e8c708a14e109c2b65ea0845f2abf9e` (817 added lines); 51 focused tests, formatting and whitespace checks passed immediately before publication.
- T4 [S1-S3] route: inline — Verified: exact bases, tracker draft, one type label each, clean child boundaries; evidence recorded in the delivery-log commit on the final child.

## Log

- L1: “FORND APROFBADO, PUEDE PONER LA ISSUE EN STATUS: APROVED Y HACER EL PR”.
- L2: User selected feature-branch-chain and authorized its commits/publication via the delivery question. Target verified: Team-Origen/origen, default develop, actor ADMIN. #386 status:approved applied and verified.
- L3: Prior checks: 51 focused preview/agenda/lifecycle tests passed; format and whitespace checks passed. Earlier full suite had 102 failures including database cleanup FK/count assertions; no clean-baseline proof. Independent verifier was unavailable. Browser automation unavailable; user explicitly approved the frontend. No claim of full technical or backend acceptance.
- L4: One slicing pass: shared layout is independently reviewable; the mock's LiveView, interaction tests and documentation stay together even above the advisory 400-line budget, because separating them would leave an incomplete behavior slice. No size-exception label requested or applied.
- L5: Shared-layout slice: 55 additions + 14 deletions. Creation with type:refactor failed because that label does not exist; target-scoped inspection confirmed no PR was created. Published #468 with the available type:chore maintenance label, without creating new labels or retrying tests.
- L6: Delivery branches: `feat/386-payments-ui` -> develop (tracker #467, draft); `feat/386-agenda-card-layout` -> tracker (#468); `feat/386-payment-preview` -> layout branch (#469). No automatic merges.
- L7: User frontend approval is recorded in the mock documentation; `Refs #386`/`Refs #287` do not automatically close either issue. CI is reported from observed remote status, never inferred from local test success.
- L8: API verification passed: exact bases and draft state, one type label per PR, clean 69-line layout diff and 817-line mock diff before delivery evidence. Observed CI: #467 all three jobs SUCCESS; #468/#469 branch/issue validation and secret scanning SUCCESS, Build y Tests IN_PROGRESS. Later body/evidence updates may trigger fresh runs; none is inferred green.
- L9: gh pr edit failed due deprecated projectCards support in the installed client. Fresh target-bound reads followed by REST PATCH updated chain links successfully; no PR was recreated. Source branches and issues remain open; no merge or closure was executed.
