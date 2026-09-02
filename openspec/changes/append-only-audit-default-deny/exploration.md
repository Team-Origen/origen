## Exploration: Append-only audit and default-deny authorization

### Current State

- Issue #1 is closed and its scaffold/CI dependency is satisfied. Issue #2 is open and explicitly depends on DA-04, OTP 29, and PostgreSQL 17.
- The application is still a Phoenix/Ecto scaffold: `Origen.Repo` is the only persistence boundary; there are no domain contexts, schemas, migrations, authorization modules, or audit modules.
- `mix test` creates and migrates the test database with the same `Origen.Repo` credentials later used by tests. CI likewise uses one PostgreSQL superuser (`postgres`) for setup and runtime. This cannot prove runtime least privilege.
- The approved authorization matrix is the only permission source. It defines operation IDs, account-state requirements, scoped conditions, and non-role channels; role names do not imply inheritance.
- The matrix permits audit insertion only through the backend-internal `SYS-01` path (A-01), requires scoped read-only audit queries (A-02), and denies audit mutation without exception (A-03). No public audit write/mutation context or endpoint is permitted.
- The table name `audit_events` and the semantic fields actor, event, affected entity, result, and server timestamp are approved. DA-04 leaves their physical names, types, and constraints unresolved.
- The local `mix test` baseline could not run because test database credentials resolved without a username in this environment. CI remains configured for PostgreSQL 17, but existing CI does not exercise separated database roles.

#### Effect of the authorization matrix on the provisional plan

The provisional direction remains sound but needs four corrections:

1. A pure default-deny boundary cannot be only `role × action`. Its input must distinguish matrix operation ID, actor/channel, account state, target/resource facts, and named scope conditions. Unknown operations, unknown roles, missing facts, and unmet conditions must all deny.
2. The minimized audit “API” must mean an internal application boundary. A public insert/update/delete API or generally callable context would violate `SYS-01` and A-03.
3. Audit reads cannot be a single global administrator-only decision. The policy must preserve `AUD-01`, `AUD-02`, and `AUD-03`; however, their domain predicates cannot be fully implemented until accounts, agendas, patient relationships, and sensitive-event classification exist. The foundation must not pre-authorize those absent relationships.
4. The matrix requires each audit query to create an audit event. That introduces an explicit read-then-audit transactional design concern and rules out treating reads as side-effect-free at the application boundary.

### Affected Areas

- `lib/origen/` — future pure policy boundary and internal audit context; neither exists today.
- `lib/origen/repo.ex` — current single Ecto boundary whose configured credentials are used for both migration and runtime.
- `priv/repo/migrations/` — future `audit_events` DDL, append-only trigger, and object privileges; currently empty.
- `config/dev.exs`, `config/test.exs`, `config/runtime.exs` — currently model one database credential path and need a clear runtime-versus-migration contract in later phases.
- `test/support/data_case.ex` and `test/test_helper.exs` — SQL Sandbox supports behavior tests but does not by itself prove real PostgreSQL ACL behavior or independent role credentials.
- `.github/workflows/ci.yml` — PostgreSQL 17 exists, but role provisioning and least-privilege verification are absent.
- `docs/security/AUTHORIZATION_MATRIX.md` — canonical permission source; implementation must reference its operation and scope identifiers without duplicating or broadening it.
- `docs/sprints/SPRINT_00.md` — fixes the table name and immutability/minimization guarantees while keeping DA-04 open.

### Approaches

1. **Pure policy plus internal audit service and PostgreSQL defense in depth** — use a side-effect-free authorization decision boundary, a non-public audit append/query boundary, atomic business-operation auditing, separate database capabilities, ACL denial, and defensive triggers.
   - Pros: Matches backend authority and default deny; keeps policy unit-testable; preserves the approved `SYS-01` channel; provides database-level proof; supports later matrix growth without role hierarchy.
   - Cons: Requires explicit subject/resource facts, a migration/runtime credential split, dedicated PostgreSQL integration tests, and a DA-04 decision before schema implementation.
   - Effort: High

2. **Database-centric authorization with RLS and triggers** — encode end-user matrix scopes primarily in PostgreSQL policies while the application forwards actor context.
   - Pros: Strong protection against accidental unfiltered queries and centralized data enforcement.
   - Cons: Current domain tables and relationships do not exist; session actor propagation and pooled-connection hygiene add risk; non-role channels and account-state rules remain application concerns; premature RLS would invent unresolved domain predicates.
   - Effort: High

3. **Application-only authorization and append-only Ecto conventions** — rely on context visibility, changesets, and absence of update/delete functions.
   - Pros: Smallest initial implementation and easiest SQL Sandbox testing.
   - Cons: Fails issue #2 and Sprint 0 because application credentials would still permit mutation; conventions are not an immutability boundary.
   - Effort: Low

Rejected approaches:

- A role hierarchy or administrator wildcard is rejected because the matrix grants no implicit permissions.
- A public/generic audit CRUD context is rejected by `SYS-01` and A-03.
- Trigger-only protection is rejected because runtime ACL denial is an explicit acceptance criterion and owners can alter/disable their own defenses.
- ACL-only protection is rejected because Sprint 0 requires an additional defensive trigger.
- Auditing a failed PostgreSQL statement in the same transaction is rejected: a trigger exception or privilege error aborts that transaction, so any same-transaction audit insert rolls back.
- A free-form JSONB-only audit envelope is rejected as the default because it weakens physical constraints and makes secret/data minimization difficult to prove.

### Recommendation

Proceed with Approach 1, while keeping DA-04 as a blocking human product/security decision before schema implementation.

#### Policy boundary

Model authorization as a pure decision over an explicit request such as operation ID, actor kind/role, account state, channel, target facts, and scope facts. Return a structured allow/deny decision and reason; default every missing or unknown combination to deny. Keep authorization orchestration separate from `OrigenWeb`, and do not infer permissions from role rank. Initially implement only permissions whose required facts exist; represent later matrix rows without granting them prematurely.

#### Transaction semantics

- For an allowed state-changing operation, perform the business write and required audit insert in one `Ecto.Multi`/database transaction. Either both commit or both roll back.
- For an application-policy denial, perform no business write and append the sanitized denial event in a separate short transaction. This keeps the denied result durable without placing business mutation in that transaction.
- For business failures discovered inside a transaction, roll back business effects first, then append a sanitized failure event in a new transaction. An event written inside the failed transaction would be lost.
- A database ACL/trigger rejection of direct audit mutation cannot guarantee a durable event for the same direct SQL attempt. Application-originated attempts may be logged only after rollback through a fresh authorized append. The proposal/spec must not claim that arbitrary direct PostgreSQL attacks are self-auditing unless a separate out-of-transaction database audit facility is approved.
- For A-02 reads, authorize and execute the scoped read, then append the query event with actor, server time, filters/scope summary, and result. Decide in specification whether audit-write failure must fail the read response; the safer recommendation is fail closed so a query is never reported as successful without its required audit record.

#### Database capability boundary

- `origen_owner` (NOLOGIN) should own application schema objects and trigger functions.
- `origen_migrator` should use separate deployment-only credentials and be able to assume the owner role only during migrations. Runtime must not inherit or `SET ROLE` to either privileged role.
- `origen_runtime` should receive only database connect, schema usage, required business-table privileges, audit insert privileges on an explicit column list, and only the read access required by the application service. It must not receive audit `UPDATE`, `DELETE`, or `TRUNCATE`.
- Revoke relevant access from `PUBLIC`, including schema creation where applicable. Avoid granting runtime ownership, role administration, trigger, or DDL capabilities.
- Provision cluster/database roles outside ordinary Ecto migrations because role creation is infrastructure-scoped and often unavailable on managed PostgreSQL. Migrations should manage object ownership/ACLs only after required roles exist, and fail clearly when prerequisites are absent.
- CI must provision owner/migrator/runtime identities, migrate with migrator capability, run the application test Repo as runtime, and use a separate privileged verification connection only for setup/assertions. The current one-superuser flow cannot be accepted as ACL evidence.

#### Migration and rollback safety

- Keep table, function, trigger, ownership, and grants in dependency order and use restrictive drops rather than broad `CASCADE` rollback.
- Treat rollback after real audit data exists as destructive/security-sensitive. A down migration may be technically reversible in a fresh test database, but production rollback should disable application dependence before preserving/exporting the audit table; it must not silently drop audit history.
- Verify fresh migration, rollback on an empty database, re-migration, object ownership, grants, and trigger presence under PostgreSQL 17.
- Trigger coverage must include row-level `UPDATE`/`DELETE` rejection and statement-level `TRUNCATE` rejection. ACL tests must independently prove all three operations fail for runtime credentials.
- Remember that owner/migrator privileges are intentionally stronger than runtime guarantees; the claim is append-only for the application role plus defense against accidental privileged mutation, not immutability against a database superuser.

#### DA-04 options requiring human approval

1. **Typed relational core (recommended candidate)** — numeric identity or UUID primary key; constrained actor kind plus nullable typed actor reference; constrained event key, entity kind/reference, result; `timestamptz` with a PostgreSQL server default; no unrestricted payload.
   - Tradeoff: Strong constraints and minimization, but new event-specific context may require additive columns or a separately approved sanitized metadata shape. A foreign key to actors cannot be required yet because account tables do not exist.
2. **Opaque text references** — keep actor and entity identifiers as bounded text with kind discriminators.
   - Tradeoff: Supports deployment/system actors and future entity types immediately, but sacrifices referential integrity and makes malformed identifiers easier to persist.
3. **Typed core plus constrained JSONB metadata** — retain mandatory typed columns and add a small metadata object written only through event-specific constructors.
   - Tradeoff: Better extensibility and query context, but PostgreSQL cannot reliably prove that arbitrary metadata contains no secret or sensitive value; stronger application whitelists and minimization tests are required.

Human decisions still required under DA-04:

- Primary-key strategy (`bigint identity` versus UUID) and whether distributed/offline event creation is a real requirement.
- Physical actor representation for user, system, deployment operator, and anonymous/public-channel actors; nullability and future foreign-key policy.
- Entity identifier representation and whether events without a persisted entity are valid.
- Controlled vocabularies and length constraints for event, actor kind, entity kind, and result.
- Timestamp function and precision (`clock_timestamp()` is the recommended insertion-time server clock; transaction-stable `now()` has different semantics).
- Whether any metadata column is allowed and, if so, its exact whitelist, size limit, indexing, and prohibited-data contract.
- Whether A-02 audit reads must fail closed when their own audit append cannot commit.

#### Test strategy and review units

Use strict RED-GREEN-REFACTOR and keep tests with each behavior:

1. Pure policy tests: explicit allow cases; all matrix role/channel boundaries; inactive/missing facts; unknown operation/role; no administrator wildcard.
2. Audit behavior tests: exact minimized fields, server timestamp behavior, internal-only append path, atomic allowed operation, durable application denial/failure behavior, scoped query auditing, and correction-by-new-event.
3. PostgreSQL 17 integration tests: runtime insert/select grants as approved; direct `UPDATE`, `DELETE`, and `TRUNCATE` denial; defensive trigger proof using a controlled privileged connection; ownership and role-membership assertions.
4. Migration/CI tests: role bootstrap, migrate as migrator, run tests as runtime, empty-database rollback/re-migrate, and no secret values in fixtures or output.

This security foundation is likely to approach or exceed the 400-line review budget once migrations, role harness, CI, policy, audit behavior, and tests are included. Under `ask-on-risk`, the tasks phase must estimate authored additions/deletions and ask before apply if risk is high. Candidate review slices are policy boundary; audit schema/service after DA-04; and PostgreSQL role/immutability harness. Each slice must include its own tests and rollback boundary.

### Risks

- DA-04 is unresolved and blocks a correct migration/schema contract.
- A shared runtime role with broad audit `SELECT` relies on application policy for per-user A-02 scopes; compromised direct database credentials are not equivalent to an authenticated user session. RLS would be a later defense-in-depth decision once domain relations exist.
- Durable logging of database-level denied statements is impossible in the same aborted transaction; overpromising this would produce false assurance.
- Current test/CI setup conflates migrator and runtime capabilities and therefore cannot prove least privilege without restructuring.
- Trigger and ACL protections do not constrain object owners or superusers; operational credential separation and independent review remain mandatory.
- Audit query self-logging can recurse if implemented through the same audited read boundary; the internal append path must bypass query authorization without becoming publicly callable.
- General metadata creates a continuing minimization risk, especially for invitation tokens, passwords, TOTP material, phone numbers, and opaque challenge tokens named by the matrix.
- Production rollback that drops `audit_events` would destroy security history and must be treated as a separately approved destructive operation.

### Ready for Proposal

Yes, with constraints. The proposal should preserve this architecture direction, explicitly mark DA-04 and A-02 audit-write failure behavior as human decisions, avoid claiming implementation of domain scopes whose relationships do not exist, and carry the PostgreSQL role/CI split as acceptance-critical rather than optional infrastructure work.
