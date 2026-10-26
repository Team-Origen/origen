# Issue #317 — Professional assisted booking contract

## Objective
Define a reviewable beta contract for registering an absent patient inside a Professional's own booking flow. This is the contract child of #283, not an implementation of #318, #319, or #320.

## Problem and rationale
The Secretary registration from #276 commits identity independently, while #317 must define the Professional booking boundary without granting Secretary permissions to Professionals. Backend and interface children need the same agreed inputs, authorization, failure behavior, and acceptance cases.

## Scope and constraints
- Base: fresh `origin/develop` at `dfde7390accd15c7569c099a3542a62c2aaf77b0` on `docs/317-professional-booking-contract`.
- Issue: https://github.com/Team-Origen/origen/issues/317; parent #283; OpenSpec `openspec/changes/health-center-beta-core/`.
- Source of truth: approved beta proposal/design/specs and `docs/sprints/GUIA_TRABAJO_BETA.md`; current code/tests are evidence, not normative authority.
- Documentation-only: no application, migrations, or fabricated test or approval evidence. Explicit agreement remains pending until recorded by a human.
- Delivery: first independent child PR to `develop`, then #318/#319 in child-scoped branches/PRs after this contract is agreed; integration #320 waits for siblings and #282. Stacked-to-develop chain, no parent-issue branch or tracker PR. Target authored diff below 400 lines.
- PR policy: #317 currently lacks `status:approved`; do not publish a PR that violates the branch-pr skill. Project status cannot be mutated with current token (`read:project` absent).

## Tasks
- [ ] **T1 — Author and verify the child contract.** Route: delegated `gentle-ai-worker` (fresh develop mapping and multi-file potential); write `docs/sprints/sprint-3/contrato-283-alta-y-reserva-profesional.md`, with a guide link only if useful. Map current-develop implementation and tests; specify inputs, output, actor/privacy rules, transaction boundary, reuse/adaptation, conflict scenarios, and pending approvals without guessing undecided details. Verify relative links, requirement traceability, and an explicit no-executed-tests statement; inspect diff, then create one Conventional Commit. Evidence/commit: pending.
- [ ] **T2 — Prepare the reviewable #317 PR and chain handoff.** Confirm recorded contract agreement and issue `status:approved` before publishing, validate PR scope/labels/CI and target `develop`, and document how future child issues branch from the accepted contract. If approval is unavailable, leave this task pending and report the exact blocker. Evidence/commit: pending (delivery metadata may need a work-unit documentation commit).

## Acceptance
- A scoped, readable artifact cites beta requirements and differentiates current-develop code evidence from unrun checks.
- No identity, relationship, or appointment is persisted on search, abandonment, or failed booking; a successful Professional booking is confirmed and creates the required relationship while preserving document uniqueness, availability, and privacy.
- Agreement and unresolved decisions are recorded honestly, not asserted; no application implementation or false test evidence.
- #317 alone is linked to its child PR; later #318/#319/#320 are separate review slices.

## Current progress
Branch isolated from the stale local #276 worktree. T1 draft now exists in `docs/sprints/sprint-3/contrato-283-alta-y-reserva-profesional.md` (176 lines) with a guide link (2 lines). The delegated writer and independent verifier both observed `git diff --check` and `test -s docs/sprints/sprint-3/contrato-283-alta-y-reserva-profesional.md` passing, and independently checked relative links and trailing whitespace. No application tests were run (passive documentation; no meaningful RED). Native `assess` failed closed to unassessable because untracked files require explicit declaration; this was covered by the independent verifier. Agreement remains pending. Next: parent spot check, stage the exact three files, create T1 work-unit commit, then confirm agreement and issue approval before PR publication.
