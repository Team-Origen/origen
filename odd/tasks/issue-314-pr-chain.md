# Issue #314 backend PR chain

Draft/no-merge tracker for the already implemented backend. Refs #314, parent #282, contract #313.
Implementation specification: `docs/sprints/contracts/313-agenda-profesional-privacidad.md`.

## Specs

- **S1:** “has los pr encadenados, puede exdeter del tamaño si es necesario”
- **S2:** “Cadena con tracker — recomendada”
- **S3:** “Sí, agregar status:approved a #314”

## Tasks

- **T1** — S1–S3: establish approved issue and draft tracker; route parent; commit: this tracker seed.
- **T2** — S1–S2: private patient selector; source commit `4ce150c`; child 1 targets tracker.
- **T3** — S1–S2: professional own-agenda orchestration; source commit `147f15a`; child 2 targets child 1.
- **T4** — S1–S2: requested relationship beta rule; source commit `c794dcf`; child 3 targets child 2.
- **T5** — S1–S2: transactional availability/catalog and concurrent confirmation evidence; source commits `a8a9171`, `31a459e`; child 4 targets child 3.

## Delivery boundaries

- Default/integration base verified: `develop`, currently `e455962`.
- Preserve original implementation commits by merging their checkpoints into the chain, rather than rewriting the original feature branch.
- Tracker stays draft/no-merge. Child branches must be reviewed and integrated in dependency order; final feature integration is a separate human decision.
- Each child includes its tests and documentation. Over-budget cohesive units are explicitly allowed by S1; no code compression or removed coverage.
- Nonclosing references only. No issue closure, merge, UI acceptance or integration acceptance is authorized.
- UI #315, integration #316, absent-patient registration and request approval are outside this delivery's scope.

## Prior verification

At original feature tip `31a459e`: full isolated suite 813 passed, 30 skipped, 8 excluded; dedicated Professional race suite 13 passed; independent follow-up 43 and 75 passed. These results are historical and do not establish CI success for the rebased integration context.

## Log

- **L1:** “has los pr encadenados, puede exdeter del tamaño si es necesario”
- **L2:** User selected tracker chain and explicitly authorized `status:approved` on #314. Target viewer permission observed: ADMIN. Default branch observed: develop. Rulesets endpoint returned HTTP 403 (repository plan restriction); do not claim branch-rule verification.
