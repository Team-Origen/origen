# Simple payments publication preparation — #385
Preparation-only tracking for `Team-Origen/origen`; this unit performs no push, PR, issue edit, label, merge, YAML, source, or test changes.
Backend publication follows the existing feature-branch chain; #385 remains open until verified delivery reaches `develop`, and parent #287 remains open.

## Specs

- S1: Human instruction: «reabrí la subissue del backend, creá los PRs correspondientes, pushealos, agregalos a la subissue del backend y cuando mergees los PRs a develop ahí recién se debería cerrar la subissue del backend»

## Tasks

- T1 [S1] route: parent readback plus local tracker preparation; done after observing #385 OPEN, with reopening already completed by `parentghjob5exit0` and no duplicate reopen or comment; commit: pending publication tracking commit, to be recorded in the T2 publication update without a self-hash loop.
- T2 [S1] route: separate parent publication continuation; in_progress — publish the tracker and four child PRs, link every PR with non-closing `Refs #384` (approved contract) and `Refs #385` (backend issue); commit: pending publication refs and PRs.
- T3 [S1] route: parent post-publication verification; pending — verify exact PR heads and bases, required CI, and the conditional closure gate; commit: none in this preparation unit. #385 remains open until all four child PRs merge to `develop` and actual delivery is verified; #287 remains open.

### Exact next five-PR publication plan

| PR | Role | Base | Head | Required linkage and policy |
| --- | --- | --- | --- | --- |
| 1 | Tracker | `develop` at remote `61a9f3545d6066ffa62d67d64092142726be5f49` | `feat/385-simple-payments-backend` at the new tracking commit (currently `0f92d3773762a08c88eb5ba5864f45ad41720267`) | `Refs #384` and `Refs #385`; exactly existing `type:feature`; no protected labels |
| 2 | Pricing slice | `feat/385-simple-payments-backend` at the tracker publication head | `feat/385-payment-pricing` at `7b92183893a62d47b79183fff47a31d5eda4863d` | `Refs #384` and `Refs #385`; exactly existing `type:feature`; no protected labels |
| 3 | Registration slice | `feat/385-payment-pricing` at `7b92183893a62d47b79183fff47a31d5eda4863d` | `feat/385-payment-registration` at `f7fdb038f0c33a167e28d5c5bbcbd2b09a4df9c0` | `Refs #384` and `Refs #385`; exactly existing `type:feature`; no protected labels |
| 4 | Correction slice | `feat/385-payment-registration` at `f7fdb038f0c33a167e28d5c5bbcbd2b09a4df9c0` | `feat/385-payment-correction` at `af5b36139e060980142178f3e7927fb0ba9d9823` | `Refs #384` and `Refs #385`; exactly existing `type:feature`; no protected labels |
| 5 | Compatibility and evidence slice | `feat/385-payment-correction` at `af5b36139e060980142178f3e7927fb0ba9d9823` | `feat/385-payment-compatibility` at `3bfffc70ce751cad0e0257b8e4d1dcadabe1c4f7` | `Refs #384` and `Refs #385`; exactly existing `type:feature`; no protected labels |

## Log

- L1: User instruction verbatim: «reabrí la subissue del backend, creá los PRs correspondientes, pushealos, agregalos a la subissue del backend y cuando mergees los PRs a develop ahí recién se debería cerrar la subissue del backend»
- L2: Actual reopen evidence: `parentghjob5exit0` reopened #385; `GHreadjob6confirmedOPEN` confirmed it remains OPEN. The previous premature closure was corrected; this unit does not reopen, comment, edit, label, or close the issue.
- L3: Technical evidence: stable backend source is unchanged at `feat/385-payment-compatibility` `3bfffc70ce751cad0e0257b8e4d1dcadabe1c4f7`, with verified source `7d7fae72c929a2c90024d6ee3461f9f3971b9996` and final evidence `5ef7e161a32c626dc6808bc741d1fafb730fc02e`; the chain starts from `0f92d3773762a08c88eb5ba5864f45ad41720267` and the remote `develop` topology is `61a9f3545d6066ffa62d67d64092142726be5f49`. #384 is CLOSED with `status:approved`, `type:feature`, and `work:contract`; #385 is OPEN with `type:feature` and `work:backend`, and is not labeled `status:approved`. Repository CI requires branch/reference validation, secret scanning, format, warnings-as-errors compilation, Sobelow, Dialyzer, PostgreSQL role provisioning/migration/grants, application tests, and the `postgres_security` proof. No backend-specific label gate beyond the observed labels and CI reference check was found; this is not an approval or merge claim.
