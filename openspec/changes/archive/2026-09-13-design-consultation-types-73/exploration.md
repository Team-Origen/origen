## Exploration: Design consultation types (#73)

### Current State
Issue #73 is the product-design slice of parent issue #39 (`PLN-06`): define a Professional-owned consultation type with a name, estimated duration, and base price. RF-08 requires duration and base price and requires appointments to retain name, duration, and price snapshots; the plan additionally rules out imprecise decimal money. The current application has only first-administrator persistence and authorization rules; it has no Professional profile, consultation-type schema, `S1-09` authorization rule, or appointment schema. Issue #73 directly blocks backend issue #74, while its parent depends on open issues #36 and #37.

### Affected Areas
- `docs/Origen_Documentacion.md` — RF-08 and user story 3.3 establish the required fields and future snapshot behavior.
- `docs/security/AUTHORIZATION_MATRIX.md` — `S1-09` / `OWN-01` define Professional-only ownership and default denial.
- `docs/sprints/PLAN_TENTATIVO_11_SPRINTS.md` — maps #73 as the product-design predecessor of #74 and #75.
- `lib/origen/authorization/rules.ex` — lacks the declared `S1-09` operation; this belongs to a later implementation slice.
- `priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs` — confirms no Professional or consultation-type persistence exists yet.

### Approaches
1. **Define the field contract before persistence** — Agree on the canonical name rules, duration units and permitted values, and exact-money representation before #74 adds validation and storage.
   - Pros: Keeps #73 within its product scope; gives #74 and #75 one reviewable contract; prevents money or duration semantics from being guessed independently.
   - Cons: Requires explicit product decisions not present in the issue or current specifications.
   - Effort: Low

2. **Combine design with backend storage** — Define fields while creating schema, validation, and authorization support.
   - Pros: Produces an executable vertical slice sooner.
   - Cons: Collapses #73 into #74, violates the published dependency split, and risks encoding unapproved validation and money choices.
   - Effort: Medium

### Recommendation
Use approach 1. Confirm the missing field contract first: name normalization and bounds, allowed positive duration values in minutes, and currency plus exact monetary representation. Then create a proposal for #73 that records only those decisions and its handoff to #74/#75; do not introduce persistence or authorization changes in this slice.

### Risks
- Neither #73 nor RF-08 specifies name limits/normalization, duration bounds or increments, currency, or the exact storage representation for money; choosing them during implementation would invent requirements.
- The parent prerequisites (#36 authentication/authorization and #37 internal accounts) remain open, and the current code has no Professional domain model to attach ownership to.
- The authorization matrix is explicitly a draft pending independent review; `S1-09` is evidence of intended scope, not proof of an implemented grant.

### Ready for Proposal
No — obtain the field-contract decisions above first. After they are confirmed, `sdd-propose` can create a narrow proposal for issue #73 and track #74 and #75 as downstream implementation slices.
