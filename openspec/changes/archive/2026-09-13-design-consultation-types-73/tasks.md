# Tasks: Synchronize the Consultation-Type Product Contract

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 90–160 repository lines; one external issue-body update |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR with two reviewable work units |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

If authored changes approach 400 lines or production files become necessary, stop and ask before continuing.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Align the approved product contract | Single PR | `git diff --check -- docs openspec/changes/design-consultation-types-73` | N/A — passive documentation has no runtime boundary | Revert `docs/Origen_Documentacion.md`, `docs/CONTEXT.md`, and `proposal.md` together |
| 2 | Prove coherence and reciprocal traceability | Same PR | `gentle-ai sdd-status design-consultation-types-73` | N/A — verification is structural/readback only | Revert only GitHub #73 body; leave #74/#75 unchanged |

## Phase 1: Canonical Contract Alignment

- [x] 1.1 Update `openspec/changes/design-consultation-types-73/proposal.md` to require Professional-selected valid replacement counts and explicitly prohibit inference, clamping, or automatic reduction during interval changes and reactivation.
- [x] 1.2 Synchronize the glossary, RF-08, HU 3.3, T1.5.1, and dependent booking text in `docs/Origen_Documentacion.md` with ownership, validation, lifecycle, exact ARS pricing, interval-derived duration, atomic adaptation, snapshots, accessibility, availability, authorization, and audit rules. Use neutral professional Spanish; do not add implementation design.
- [x] 1.3 Add implementation-free definitions for `Tipo de consulta`, `Intervalo de agenda`, and reservation-ahead `Período` to `docs/CONTEXT.md`, keeping the concepts unambiguous and distinct.

## Phase 2: Coherence and Traceability

- [x] 2.1 Cross-check all requirements and scenarios in `specs/{consultation-type-catalog,agenda-interval,default-deny-authorization,append-only-audit}/spec.md` against the synchronized prose; correct only genuine contradictions, preserving explicit replacement, atomic rejection, current color, minimized audit, and immutable booking snapshots.
- [x] 2.2 Update GitHub #73 only if readback still lacks the `design-consultation-types-73` change name, repository-relative path, documentation-only scope, acceptance contract, and #74/#75 downstream boundaries. Preserve its title and do not re-edit #74/#75.
- [x] 2.3 Read back #73 with `gh issue view 73 --json title,body,url` and confirm reciprocal references with `proposal.md`.

## Phase 3: Verification and Archive Readiness

- [x] 3.1 Run `rg -n "infer|clamp|automatically reduce|floating.point|snapshot.*color|Period" openspec/changes/design-consultation-types-73 docs`, review every hit for contradictions, then run `git diff --check` and `git diff --name-only` to confirm documentation-only scope.
- [x] 3.2 Run `gentle-ai sdd-status design-consultation-types-73`; require all tasks complete and `nextRecommended: verify`, then hand off the four verified deltas for proportional verification and later archive-time merge into `openspec/specs/`.
