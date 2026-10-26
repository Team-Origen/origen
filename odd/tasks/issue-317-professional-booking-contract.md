# Issue #317 — Professional assisted booking contract

## Objective
Define a reviewable beta contract for registering an absent patient inside a Professional's own booking flow. This is the contract child of #283, not an implementation of #318, #319, or #320.

## Problem and rationale
The Secretary registration from #276 commits identity independently, while #317 must define the Professional booking boundary without granting Secretary permissions to Professionals. Backend and interface children need the same agreed inputs, authorization, failure behavior, and acceptance cases.

## Scope and constraints
- Base: fresh `origin/develop` at `dfde7390accd15c7569c099a3542a62c2aaf77b0` on `docs/317-professional-booking-contract`.
- Issue: https://github.com/Team-Origen/origen/issues/317; parent #283; OpenSpec `openspec/changes/health-center-beta-core/`.
- Source of truth: approved beta proposal/design/specs and `docs/sprints/GUIA_TRABAJO_BETA.md`; current code/tests are evidence, not normative authority.
- Documentation-only: no application, migrations, or fabricated test evidence. Contract agreement recorded by Saidqr on #317; application integration and its approval remain pending.
- Delivery: first independent child PR to `develop`, then #318/#319 in child-scoped branches/PRs after this contract is agreed; integration #320 waits for siblings and #282. Stacked-to-develop chain, no parent-issue branch or tracker PR. Target authored diff below 400 lines.
- PR policy: user-approved contract in https://github.com/Team-Origen/origen/issues/317#issuecomment-6425202986; `status:approved` now present. Project status cannot be mutated with current token (`read:project` absent).

## Tasks
- [x] **T1 — Author and verify the child contract.** Route: delegated `gentle-ai-worker` (fresh develop mapping and multi-file potential). Created the contract and guide link; verified 17 contract and 2 guide relative links, no trailing whitespace, `git diff --check`, `test -s docs/sprints/sprint-3/contrato-283-alta-y-reserva-profesional.md`, and staged diff. Independent verifier found no material contradiction with beta specs. No application tests (passive documentation). Work-unit commit: `a64b930cb1fc1c5343c407dade997b30ca907f3e` (`docs(beta): define professional assisted booking contract`), 206 authored lines including ODD task evidence. Rollback: contract file, guide link, and this task tracker only.
- [ ] **T2 — Prepare the reviewable #317 PR and chain handoff.** User approved contract in https://github.com/Team-Origen/origen/issues/317#issuecomment-6425202986 and authorized `status:approved`, now present. Update approval evidence in artifact/guide, verify and commit, then open child-scoped PR to `develop` and check type label, diff and CI. Future #318/#319/#320 remain separate units. Evidence/commit: pending.

## Acceptance
- A scoped, readable artifact cites beta requirements and differentiates current-develop code evidence from unrun checks.
- No identity, relationship, or appointment is persisted on search, abandonment, or failed booking; a successful Professional booking is confirmed and creates the required relationship while preserving document uniqueness, availability, and privacy.
- Agreement and unresolved decisions are recorded honestly, not asserted; no application implementation or false test evidence.
- #317 alone is linked to its child PR; later #318/#319/#320 are separate review slices.

## Current progress
T1 contract draft and guide link committed at `a64b930cb1fc1c5343c407dade997b30ca907f3e`; this addendum records its observed evidence. Writer, independent verifier and parent spot check passed structural checks. No application tests were run (passive documentation; no meaningful RED). Native `assess` failed closed to unassessable because untracked files require explicit declaration, so an independent verifier was run. RDD global switch is off; no native review START is due. T2 in progress: human agreement recorded on #317 and label applied; approval evidence is being committed before PR publication. Project status edit is unavailable with this token; user should move #317 to In Progress manually.
