# Issue #315 — stacked frontend demo delivery
Branch root: `cd26f1c`; strategy: `stacked-to-main`, verified default `develop`.
Checks: focused ExUnit per slice, full suite at closure, formatting and diff checks; no automatic merge.

## Specs

- S1: «has la opcion 2, remplaza el el ejemplo del mock del dni y has lo PRs»
- S2: «si» — explicit answer authorizing `status:approved` on #315.

## Tasks

- T1 [S1,S2] inline — done — synthetic demo port, 3 direct contract tests passed; commit: `0f6c9b9`.
- T2 [S1] inline — done — patient-only route/UI, 27 focused checks passed with demo-port tests; commit: `3ab8c1c`.
- T3 [S1] inline — done — reusable visual progress/consultation/schedule/summary components with render tests; commit: `94658b8`.
- T4 [S1] inline — in_progress — wire the four-step demo, regression tests and final delivery evidence; commit: pending.

## Log

- L1: «has la opcion 2, remplaza el el ejemplo del mock del dni y has lo PRs»
- L2: «si» — authorization to add `status:approved` to #315; applied after confirming admin/maintain permissions.
- L3: Target github.com/Team-Origen/origen; default branch verified as develop. Nonclosing `Refs #315`; parent #282 and backend #314 remain outside delivery closure.
- L4: User-supplied identity replaced by Lucía Ejemplo / synthetic DNI 99000123 before any commit. Focused suite: 29 passed, exit 0, seed 470464. Prior full suite: 788 passed, 29 skipped, 8 excluded. User approved visual behavior in Tidewave; agent-driven browser proof was unavailable.
- L5: One bounded slicing pass: four cohesive units, forecast about 1,650 authored lines including dedicated slice tests and this evidence. The 400-line review budget is advisory; no repository size gate was found in CI. Preserve full source and tests rather than shrinking formatting. No size-exception label requested or applied.
- L7: T1 checked with 3 passing contract tests (exit 0, seed 708644), formatting and diff checks passed. RDD off. These are additional regression checks during delivery slicing, not invented new RED/GREEN.
- L6: Preserve final approved uncommitted sources in `.git/local-backups/issue-315-stacked-delivery/` before reconstructing each incremental commit in the existing worktree. Existing stashes remain untouched. RDD was off at prior checks; check again before delivery.
- L8: T2 reconstruction initially failed on a Python delimiter before writing the LiveView (two attempts); an intervening 20-test baseline run is not T2 evidence. Diagnosed the formatted multiline marker, reconstructed successfully, then observed 27 passing focused tests, exit 0, seed 627383.
- L9: User invoked the handoff skill before the T2 commit. Corrected a prematurely advanced task status: T2 is tested but uncommitted, T3 has not started. Pause delivery and resume T2 from the current diff; preserve all backup files. No branches have been pushed and no #315 PRs have been created.
- L10: Resumed T2. Its focused suite passed again: 27 passed, exit 0, seed 561749; `mix format --check-formatted` and `git diff --check` passed.
- L11: T3 component tests passed: 3 passed, exit 0, seed 308438; `mix format --check-formatted` and `git diff --check` passed.
