# Archive Report: Append-only Audit and Default-deny Authorization

## Archive Summary

- Change: `append-only-audit-default-deny`
- Archived on: 2026-09-02
- Final status: PASS
- Artifact store: OpenSpec
- Delivery strategy: `exception-ok`
- Review budget: 400 changed lines
- Implementation exception: Explicit maintainer `size:exception`
- Bounded remediation: 323 changed lines (292 additions, 31 deletions), within the 400-line budget
- Tasks: 15/15 complete
- Requirements: 9/9 compliant
- Scenarios: 18/18 compliant
- Blockers: 0

The completed change establishes multidimensional backend default denial, an internal minimized append-only audit boundary, atomic protected operations, durable fresh denial and post-rollback failure auditing, and independently verified PostgreSQL 17 least privilege and immutability defenses.

## Final Implementation Lineage

| Commit | Purpose |
|---|---|
| `eef8b96` | Implemented multidimensional default-deny authorization and focused policy tests. |
| `71ec827` | Added the OpenSpec proposal, delta specs, design, exploration, and configuration. |
| `51df967` | Added minimized audit events, append-only persistence, transaction semantics, migration, and tests. |
| `b4d8cc7` | Added separated database capabilities, PostgreSQL security verification, and CI wiring. |
| `fbb78de1da6d5127ed8c32659afd960f4c91852f` | Added the protected operation seam and bounded verification remediation. |

The exact implementation chain is `eef8b96 -> 71ec827 -> 51df967 -> b4d8cc7 -> fbb78de` from baseline `88b8ebf`.

## Verification Evidence Lineage

| Stage | Evidence revision | Result |
|---|---|---|
| Initial final verification | `sha256:f9fb011e993e3e4028e9dba6ff5f9b8fa69fb26b22591049cc9037a1640b855c` | Failed with three critical behavioral gaps. |
| Maintainer-authorized bounded remediation | `sha256:5c926e44cbcc8dc4c14db428089ca05692ce045923078dacb001a72fb0d3fbf3` | Added authoritative protected-operation auditing and missing channel/direct-backend coverage in commit `fbb78de`. |
| Fresh final verification | `sha256:eb64b2594cc0438273e92fbd52cd60ebcbfc125db5862ae6617bbd390fffaaf8` | PASS with 9/9 requirements, 18/18 scenarios, and zero blockers. |

The archived `verify-report.md` preserves the canonical final evidence preimage, command output hashes, compliance matrix, cleanup proof, and complete failure-to-remediation lineage.

## Final Runtime Evidence

| Check | Final result |
|---|---|
| Compilation with warnings as errors | Passed |
| Focused remediation suite | 19/19 passed |
| Authorization suite | 8/8 passed |
| Protected operation suite | 6/6 passed |
| Audit suite | 12/12 passed |
| Transaction suite | 5/5 passed |
| Ordinary suite | 31/31 passed; 4 tagged PostgreSQL security tests excluded by project configuration |
| PostgreSQL 17.11 security suite | 4/4 passed |
| Empty rollback, re-migration, and populated rollback controls | Passed |
| Candidate-focused formatting | Passed |
| Disposable database residue | 0 |
| Disposable role residue | 0 |

`apply-progress.md` contains an intermediate 9/9 authorization test count. Fresh final verification establishes the accurate count as 8/8 ExUnit tests; declared authorization behavior remains fully covered.

## OpenSpec Synchronization

The active delta specs represented new capabilities and no main specs previously existed. They were copied byte-for-byte into the source-of-truth tree before the change was moved:

| Domain | Action | Source of truth |
|---|---|---|
| `append-only-audit` | Created from the complete delta spec | `openspec/specs/append-only-audit/spec.md` |
| `default-deny-authorization` | Created from the complete delta spec | `openspec/specs/default-deny-authorization/spec.md` |

Mechanical readback used recursive `diff -r`. Both spec copy comparisons and the pre-move archive tree comparison produced empty output and exited with status 0. The archive report is additive and was created after the archive-tree comparison.

## Review Authority

Receipt-driven review is disabled or unmanaged for this candidate, and no review was started. Native status contained no `reviewGate` and reported archive ready. No transaction, ledger, receipt, approval, or review artifact is claimed or synthesized.

## Informational Residuals

- No remote GitHub Actions run exists for the branch.
- Repository-wide coverage is 45.21%; this is informational because the configured OpenSpec coverage threshold is 0 and the security behavior passed focused runtime suites.
- Repository-wide formatting detects pre-existing CRLF normalization churn; candidate-focused formatting passed.
- Pre-existing local changes in `.atl/.skill-registry.cache.json` and `.atl/skill-registry.md` were preserved and excluded from the archive commit.
- Accidental `.gitignore` drift was restored before final verification.

## Archive Validation

- Main specifications were synchronized before archival.
- The active change directory was removed.
- The archive contains proposal, exploration, two specifications, design, tasks, apply progress, final verification, and this report.
- Archived `tasks.md` contains no unchecked implementation tasks.
- Native pre-archive status reported proposal, specs, design, tasks, apply, and verify complete; archive ready; 15/15 tasks; and no blocked reasons.
