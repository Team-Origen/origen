# Appointment lifecycle publication — #377
Publish the approved backend using the selected feature-branch-chain strategy in `github.com/Team-Origen/origen`; no merge or issue closure is authorized.
Approved source: `feat/377-appointment-lifecycle` at `95a9cc285e049d34e3d341728edfd818f6569136`. Integration base: `develop` at `5d71f0b08b7afb7f6b9fca32309c8e48c5f2f48e`.

## Specs

S1. Human authorization: «Autorizo el push y la creación de los PRs.» Applies to the previously selected feature-branch-chain: a draft/no-merge tracker and four functional review slices.
S2. Human authorization: «Autorizo lo que me pediste.» Accepts the immediately preceding request to apply `status:approved` to #377 and continue the already authorized publication, without merge or issue closure.
S3. Human decision: «Apruebo el backend». Applies to `95a9cc2`, with the reviewed exclusions and limitations; it does not approve full #285/UI integration or rollback execution.

## Tasks

T1 | S1,S2 | route: parent, target-bound GitHub operations | done | Confirm target/default/policy and apply issue approval; #377 remains open with `status:approved`; commit: publication tracker record.
T2 | S1,S3 | route: parent, sequential branch preparation | done | All four unit diffs byte-identical to the approved diffs; final tree equals approved source plus nine unrelated current-default paths and this record. Approved branch unchanged; commits: tracker bootstrap `11c43ff`, expiry `8ecf73d`, cancellation/history `4119060`, attendance `a9d1baf`, final `332abfa`.
T3 | S1,S2,S3 | route: parent, explicit HTTPS push and GitHub PR creation | in_progress | Publish branches and open linked tracker/child PRs with exactly one `type:feature` label; commit: remote branch heads, pending.
T4 | S1,S3 | route: parent, GitHub checks and structural verification | pending | Verify PR bases, diffs, links, labels and CI; report all failed/pending/skipped checks without merge; commit: final publication record, pending.

## Log

L1. Publication request verbatim: «Autorizo el push y la creación de los PRs.»
L2. Backend approval verbatim: «Apruebo el backend». Subsequent exact label authorization: «Autorizo lo que me pediste.» The preceding question named `status:approved` on #377 and explicitly excluded merge and issue closure.
L3. Verified target `github.com/Team-Origen/origen`, default `develop`, session permission ADMIN. #376 is closed and its contract was merged in PR #424. #377 is open and now carries `status:approved`, `type:feature`, and `work:backend`. No duplicate #377 PRs were open at discovery.
L4. Approved backend evidence: independent static review against E1–E14/LIFE-01–08 found no blocking defects; fresh focused run 63 passed; full seed 906340 run 950 passed, 32 skipped, 8 excluded (`postgres_security`). Whitespace passed; source branch clean. Existing OTP 28 regex and deprecated helper warnings remain. These results do not certify UI/parent integration or the checks not executed.
L5. Source boundaries: expiry `3054fef..ef26091` (834 changed lines), cancellation/history `ef26091..d375326` (969), attendance `d375326..52ffc22` (413), policy/regressions/evidence `52ffc22..95a9cc2` (295). Keep these cohesive units and disclose advisory 400-line overruns; do not compress or omit tests/docs and do not apply `size:exception` without a corresponding policy/authorization.
L6. Tracker preparation: start from the verified current default and add only this publication record, allowing a nonempty draft tracker PR before child integration. Reapply approved work-unit commits sequentially onto that tracker; preserve the original approved branch and commit. The final code, tests, migrations, and implementation documentation must match the approved source, while retaining unrelated current-default changes and this publication record. No behavior changes, remote merges, force pushes, branch deletion, or issue closure are part of publication.
L7. Branch preparation passed: original approved ref remains `95a9cc2`; all four old/new unit diffs are byte-identical (834/969/413/295 changed lines). The final reconstructed tree retains all 28 approved changed paths and nine unrelated default updates exactly; this publication document is the only additional path. Delivery heads: `feat/377-01-expiry` = `8ecf73d`, `feat/377-02-cancellation-history` = `4119060`, `feat/377-03-attendance` = `a9d1baf`, `feat/377-04-policy-regressions` = `332abfa`. The tracker holds the evolving publication record; child branches retain its initial ancestral snapshot until future integration. No integration or merge has occurred.
