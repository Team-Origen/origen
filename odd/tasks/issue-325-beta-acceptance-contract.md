# Issue #325 — Beta acceptance evidence contract

## Objective
Define a separate, reviewable acceptance artifact for the approved academic beta scope (#290, #266) without claiming that delivery, deployment, or final acceptance has occurred.

## Scope and constraints
- Assigned to Saidqr, open and unblocked at the 2026-10-29 GitHub readback; #326 is downstream documentary verification. Read the parent #290, OpenSpec proposal/design/beta-boundaries, the Sprint 3 guide, and current repository evidence.
- Define verifiable criteria and sanitized evidence for a user manual, fictitious persistent data created through real product flows, functional/permission checks, cloud access, teaching conditions, and a two-week stabilization period. Distinguish contract approval from final delivery approval.
- Reuse historical runbooks only as structure. They contain pre-beta phone-verification and appointment-state assumptions; they cannot prove current beta acceptance. Record code found, tests read, and tests actually executed separately.
- Do not select branding, cloud vendor, budget, or teaching conditions; #274 and #275 remain open. Do not claim a deployment, execute #326, close #290, or merge/publish a documentation-only PR without a fresh decision.
- The user previously restricted GitHub publication until local checks pass because Actions quota is exhausted. This new work stays local until verification and explicit contract approval.
- Feature branch `docs/325-beta-acceptance-contract` is isolated from an unrelated divergent main worktree. Forecast: approximately 220–320 authored lines, one reviewable contract/doc work unit, delivery strategy `ask-on-risk` if the branch exceeds ~400 authored lines.

## Tasks
- [x] **T1 — Write the evidence contract.** Delegated writer; mapping/preparation exceeded the parent evidence budget. `docs/qa/ACEPTACION_ENTREGA_BETA.md` defines six outcome groups, observable pass conditions, sanitized evidence receipts, historical reuse/incompatibility inventory, and pending decisions. Passive documentation: no meaningful RED; writer observed whitespace checks and all 15 repository-relative links resolving, six initial no-execution states, and pending #274/#275 and approval. Native ASSESS passive/RDD off projected structural readback, performed by parent. Work-unit commit: pending below.
- [ ] **T2 — Verify and request explicit agreement.** Independent structural/source-link review and parent spot check, check GitHub acceptance line by line, record observed checks and limitations; show the draft to Saidqr for explicit contract approval before claiming #325 complete. Do not fabricate approval or close the issue pending its decision. Work-unit commit if additional verified corrections are made.
- [ ] **T3 — Deliver only after approval and applicable gates.** On explicit contract approval and a suitable code-bearing delivery strategy (user preference against docs-only beta implementation PRs), ensure the artifact is available in an authorized PR/branch, local checks pass, record approval and evidence in #325, and only then determine issue closure. Do not push or change draft PRs #348–#350 merely for task bookkeeping.

## Acceptance checks
- Each of the six beta delivery outcomes has observable criteria, expected evidence, and an honest not-executed placeholder.
- #266 and OpenSpec are cited; #274/#275 decisions remain open without guessed answers. Historic artifacts and tests are not represented as current beta success.
- #325 agreement and any publication/closure are recorded only after human approval and actual verification.

## Current progress
2026-10-29: Live #325 is open, assigned to Saidqr with no native blockers and zero comments; #290 is open and unblocked, #274/#275 remain open. An exploratory agent mapped approved beta sources and historical incompatibilities. T1 draft contract written and structurally read back; no functional tests executed, no issue approval, deployment, push or PR. T2 verification and explicit human approval pending. #318 remains blocked by real #286 blocks under the user's separate decision.
