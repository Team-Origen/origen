# Issue 472 — Feature-branch delivery chain
Integration base: `develop` at `61a9f3545d6066ffa62d67d64092142726be5f49`.
Draft tracker only: no production behavior in this commit; no merge authorized.

## Specs
- S1: “TE PERMITO QUE HAGAS LO COMMIT, PONGAS LA ISSUE COMO APROVADA Y HAGAS LOS PRS DE ESTOS CAMBIOS”.
- S2: Publication scope answer: “Ambos: #472 y ajuste de #390”. Reference choice: “Closes: cierre automático al fusionar”.
- S3: Oversized-delivery choice: “Cadena con rama integradora (recomendado)”.
- S4: Preserve the implemented requirements and evidence in `odd/tasks/issue-472.md` and `docs/navigation/ISSUE_472_IMPLEMENTATION.md` once the final slice is integrated. Never invent pending visual/independent proof.

## Tasks
- D1 [S1-S4] done — inline: prepare tracker and six existing work-unit boundaries; original source commits listed below. This tracker commit is its own work unit.
- D2 [S1-S3] pending — inline: apply issue approval and publish draft tracker, ordered children and independent economic-summary PR; final tracker uses Closes #472, children Refs #472.
- D3 [S4] pending — inline: observe required CI per PR and report pending/failing checks without merging.

## Chain boundaries
| Slice | Branch | Original work-unit commit | Scope |
| --- | --- | --- | --- |
| Tracker | `feat/472-delivery-tracker` | This commit | Draft/no-merge integration tracking |
| 1 | `feat/472-01-requests` | `0a88bd7` | Requests query/list, navigation, daily Agenda preservation, tests/docs |
| 2 | `feat/472-02-settings` | `a482ede` | Approval relocated below consultation types, tests/docs |
| 3 | `fix/472-03-agenda-cards` | `2adfbbe` | Professional Agenda card cleanup, tests/docs |
| 4 | `fix/472-04-secretary` | `7ed8c11` | Secretary colors/title/summary, tests/docs |
| 5 | `fix/472-05-patient-history` | `a84bc30` | Patient newest-first presentation, tests/docs |
| 6 | `docs/472-06-evidence` | `de563ab` | Reconciled feature specification and evidence |

The first child targets the tracker; each later child targets its immediate parent.
A tracker-ancestry merge carries only this document through each existing boundary,
retaining original implementation commits. This is local branch preparation, not
GitHub PR integration. Merge child PRs in order only after human authorization;
keep the tracker draft until final integration/review is complete.

## Log
- User publication request and both decisions quoted in S1-S3 authorize GitHub reads, issue approval, pushes and PR creation in Team-Origen/origen using the configured gh session. No PR merge is authorized.
- Repository default branch and actual target verified. #390 is already approved and closed by merged PR #464; it is not reopened. Its new visual-only adjustment is independent from this chain and uses `fix/390-economic-summary-examples` from develop, commit `39afbc8`.
- #472 integrated implementation: 1115 tests passed,32 skipped,8 excluded. Combined candidate with summary adjustment:1116 passed,32 skipped,8 excluded. Assets/format/diff passed. Logs include Sandbox ownership errors without established cause. Independent #390 branch also passes18 focused tests; separate full-suite result is recorded in its PR.
- Review workload: one honest split into six original units. Requests child is801 changed lines (655 additions/146 deletions), largely relocated markup plus query/tests; it cannot be separated further without a broken request flow. No source compression or omitted tests. No repository size exception is inferred or applied.
- Desktop/mobile browser evidence and independent verification remain unavailable from the handoff. Human approval to publish is not a claim that those checks ran. RDD remains off. No credentials or real patient data in artifacts.
