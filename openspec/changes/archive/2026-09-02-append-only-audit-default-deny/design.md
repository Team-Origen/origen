# Design: Append-only Audit and Default-deny Authorization

## Technical Approach

Keep policy and audit inside `Origen`; `OrigenWeb` calls domain operations but has no audit mutation API. Policy grants only fact-complete matrix-v0.4 rules; an internal writer, PostgreSQL ACLs, and triggers protect history.

## Boundaries and Contracts

| Module | Contract |
|---|---|
| `Origen.Authorization` | Public `decide(Request.t()) :: Decision.t()`; pure and side-effect free. |
| `Origen.Authorization.{Request,Fact,Decision,Rules}` | `Request` contains operation, actor/channel, account state, target facts, and scope facts. Every dimension is `{:known, value}`, `:unknown`, or `:not_applicable`; only a rule may require `:not_applicable`. `Decision` is `{:allow, rule_id}` or `{:deny, reason}`. `Rules` contains exact operation/subject predicates, never ranks or wildcards. |
| `Origen.Audit.Events` | Internal, named constructors own event/actor/entity allowlists and return an opaque event; no arbitrary attribute constructor. |
| `Origen.Audit.Writer` | Internal `append/2` and `append_to_multi/3`; accepts only a constructor-produced event plus an A-01/SYS-01 allow decision. No public CRUD context, schema changeset, read API, or `OrigenWeb` route exists. |

Unknown operations/subjects, `:unknown`, missing keys, unmet predicates, and future matrix rows without implemented facts return denial. A-02 rules are absent in this slice, so sensitive reads return no rows. A-03 has no allow rule.

## Physical Schema

`public.audit_events` is exactly:

```sql
id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
actor_kind varchar(32) NOT NULL,
actor_ref varchar(128),
event varchar(64) NOT NULL,
entity_kind varchar(32),
entity_ref varchar(128),
result varchar(32) NOT NULL,
recorded_at timestamptz(6) NOT NULL DEFAULT clock_timestamp()
```

Checks require `actor_kind`, `event`, and non-null `entity_kind` to match `^[a-z][a-z0-9]*(_[a-z0-9]+)*$`; non-null references must be non-blank. `result IN ('allowed','denied','succeeded','failed')`. `actor_ref` may be null only when `actor_kind IN ('system','anonymous')`. `entity_kind` and `entity_ref` are either both null or both valid. Constructor allowlists are narrower than these physical checks. There are no foreign keys yet and no metadata, JSON, scope, caller-time, correlation, correction, or other artificial identifiers.

## Database Security

Infrastructure provisions `origen_owner NOLOGIN`, `origen_migrator LOGIN NOINHERIT`, and `origen_runtime LOGIN NOINHERIT`; CI alone also provisions `origen_verifier LOGIN NOINHERIT`. Only migrator receives owner membership with `INHERIT FALSE, SET TRUE`. Runtime receives neither membership nor DDL/role administration. Provisioning owns the database/schema, revokes database `CONNECT` and schema `CREATE` from `PUBLIC`, then grants explicit connect/usage. Secrets come only from environment/secret storage.

Migrations run after `SET ROLE origen_owner`, create owner-owned table/function/triggers, revoke all table/function access from `PUBLIC`, and grant runtime only `INSERT (actor_kind, actor_ref, event, entity_kind, entity_ref, result)`; no audit `SELECT`, `UPDATE`, `DELETE`, or `TRUNCATE` is granted. A `BEFORE UPDATE OR DELETE FOR EACH ROW` trigger raises SQLSTATE `55000`; a separate `BEFORE TRUNCATE FOR EACH STATEMENT` trigger is mandatory because PostgreSQL permits TRUNCATE triggers only at statement level. The owner and superusers remain outside the runtime immutability claim.

## Transaction Flows

```text
allow -> Ecto.Multi[business write, audit append] -> commit both | rollback both
deny  -> no business write -> fresh audit transaction -> return denial
business error -> rollback -> fresh failure-audit transaction -> return error
sensitive read -> policy denial -> no query/data -> fresh denial audit
```

If a required fresh append fails, return `:audit_unavailable`, never a false audited outcome. ACL/trigger-rejected SQL aborts its transaction and is not claimed to self-audit; only application handling after rollback may append anew.

## Strict TDD and Evidence

Strict RED-GREEN-REFACTOR keeps tests with behavior: pure policy tables; runtime `Origen.Repo` constraint/transaction tests; and non-sandbox PostgreSQL-17 security tests. CI bootstraps four identities, migrates through unsupervised `Origen.MigrationRepo`, and runs `mix test` as runtime. ACL tests expect `42501`; the verifier temporarily receives mutation grants and must hit trigger `55000`. Evidence compares rows and asserts `current_user`, ownership, memberships, column grants, trigger level/events, and server timestamp bounds; logs redact secrets.

## Migration, Work Units, and Rollback

1. Policy types/rules/tests: removable independently.
2. Schema, constructors, writer, transaction tests: fresh migrate; down refuses non-empty `audit_events`, otherwise drops grants, triggers, function, then table; re-migrate must pass.
3. Role/config/CI proof: runtime and migration URLs stay separate; rollback restores harness/config without weakening deployed ACLs.

Production is forward-only: remove application dependence and preserve/export history before separately approved destructive rollback. Tasks must forecast the 400-line budget and ask before apply if risk is high.

## Planned File Changes

Create authorization/audit modules and tests under `lib/origen/` and `test/origen/`; add one migration, security support, and separated credential wiring under `priv/repo/`, `test/support/`, `config/`, `mix.exs`, and CI. No `OrigenWeb` changes.

## Architecture Decision and Alternatives

| Option | Tradeoff | Decision |
|---|---|---|
| Pure policy + ACL + triggers | More setup; satisfies every required layer | Choose |
| Application-only | No database enforcement | Reject |
| ACL-only / trigger-only | Each omits an independent defense | Reject |
| RLS-first | Invents absent relationships | Reject |
| Role hierarchy | Violates the matrix | Reject |
| Free JSON metadata | Defeats minimization | Reject |

No routing, shell, subprocess, VCS, executable-classification, or process-integration boundary is introduced, so the threat matrix is N/A.

## Open Questions

None.
