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
- D2 [S1-S3] done — inline: #472 approved and all eight branches/PRs published. Draft tracker #479 uses Closes #472; children #480–#485 use Refs #472. Independent economic-summary PR #486 uses Closes #390 (already approved/closed, not reopened). Publication job exited 0. This evidence update is committed in the final documentation child.
- D3 [S4] in_progress — inline: remote bases, exactly one type label and tracker draft status confirmed. Original CI: #479/#486 passed; #480–#485 failed Dialyzer. Verified bounded fixes are being published, followed by fresh exact-head CI observation; no merge.

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

## Published review order

| Order | PR | Review surface |
| --- | --- | --- |
| Integrator | [#479](https://github.com/Team-Origen/origen/pull/479) | Draft/no-merge, targets develop |
| 1 | [#480](https://github.com/Team-Origen/origen/pull/480) | Requests/navigation, targets tracker |
| 2 | [#481](https://github.com/Team-Origen/origen/pull/481) | Settings, targets #480 branch |
| 3 | [#482](https://github.com/Team-Origen/origen/pull/482) | Professional Agenda cards, targets #481 branch |
| 4 | [#483](https://github.com/Team-Origen/origen/pull/483) | Secretary, targets #482 branch |
| 5 | [#484](https://github.com/Team-Origen/origen/pull/484) | Patient history, targets #483 branch |
| 6 | [#485](https://github.com/Team-Origen/origen/pull/485) | Feature evidence, targets #484 branch |
| Independent | [#486](https://github.com/Team-Origen/origen/pull/486) | Economic-summary examples, targets develop |

## Log
- CI correction: original #480 failed on unreachable request error clauses left in Agenda after request resolution moved; #481–#485 failed on the same clauses copied to Settings. Removed only `invalid_status_transition` and `appointment_not_found` clauses from those no-longer-request-owning views. Request-view messages and all reachable approval errors remain unchanged. Original CI logs retain exit 2; no warning-ignore changes.
- Settings correction `c34ac8f`: 44 focused tests, Dialyzer, format/diff all exit 0. First-slice correction `803a342`: 44 focused tests, Dialyzer, format/diff all exit 0. Both Dialyzer runs report 55 ignored baseline warnings and 3 unnecessary skips; no clean-warning claim. Corrections propagated with ancestry-preserving local merges, no force-push. One expected Agenda deletion conflict was diagnosed and resolved to exactly the Settings branch's existing file; no extra source change. Final integrated corrected #472 suite completed: `MIX_TEST_PARTITION=_issue472 mix test`, 1115 passed, 32 skipped, 8 excluded, exit 0 (job-14). Sandbox ownership messages remain in the log without established cause. Exact published-head CI remains pending.
- The initial worktree test attempt exited 1 before tests because ignored `config/test.local.exs` was absent. User explicitly authorized reusing that local configuration and a fresh verification. Credentials were neither printed nor committed, and the local file remains ignored. Subsequent focused checks above passed.
- #390 independent branch suite completed: 1109 passed,32 skipped,8 excluded,exit0;18 focused tests passed. Sandbox ownership text remains in the log without established cause. This does not replace CI for each published head.
- User publication request and both decisions quoted in S1-S3 authorize GitHub reads, issue approval, pushes and PR creation in Team-Origen/origen using the configured gh session. No PR merge is authorized.
- Repository default branch and actual target verified. #390 is already approved and closed by merged PR #464; it is not reopened. Its new visual-only adjustment is independent from this chain and uses `fix/390-economic-summary-examples` from develop, commit `39afbc8`.
- #472 integrated implementation: 1115 tests passed,32 skipped,8 excluded. Combined candidate with summary adjustment:1116 passed,32 skipped,8 excluded. Assets/format/diff passed. Logs include Sandbox ownership errors without established cause. Independent #390 branch also passes18 focused tests; separate full-suite result is recorded in its PR.
- Review workload: one honest split into six original units. Requests child is801 changed lines (655 additions/146 deletions), largely relocated markup plus query/tests; it cannot be separated further without a broken request flow. No source compression or omitted tests. No repository size exception is inferred or applied.
- Desktop/mobile browser evidence and independent verification remain unavailable from the handoff. Human approval to publish is not a claim that those checks ran. RDD remains off. No credentials or real patient data in artifacts.
