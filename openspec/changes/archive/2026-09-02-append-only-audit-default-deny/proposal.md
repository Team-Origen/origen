# Proposal: Append-only Audit and Default-deny Authorization

## Intent

Deliver issue #2's security foundation: default denial, audit evidence, and provable database least privilege.

## Scope

### In Scope
- A backend policy evaluates operation, actor/channel, state, target, and scope; unknown, missing, or unmet dimensions deny.
- An internal boundary stores minimized `audit_events`: identity, kinds, bounded references, event, result, and server time; no metadata/JSON.
- Allowed writes and audit append commit atomically. Denials and rolled-back failures append sanitized events separately.
- Sensitive audit reads remain default-denied until domain relationships and typed scopes exist.
- Separate owner, migrator, and runtime capabilities; ACLs and triggers reject audit `UPDATE`, `DELETE`, and `TRUNCATE`, proven on PostgreSQL 17.

### Out of Scope
- Public audit mutation, frontend authority, role inheritance, correction by mutation, or duplication of the [authorization matrix](../../../docs/security/AUTHORIZATION_MATRIX.md).
- Permissions requiring absent relationships; they remain denied.
- Sensitive audit reads, typed scopes, foreign keys, or metadata—including `scope_kind` and `scope_ref`.
- Claims that arbitrary database-denied SQL self-audits; aborted statements cannot commit their events.

## Capabilities

### New Capabilities
- `default-deny-authorization`: Multidimensional backend decisions governed by the canonical matrix.
- `append-only-audit`: Internal minimized append, transaction guarantees, deferred sensitive reads, and database immutability defenses.

### Modified Capabilities
None.

## Approach

Implement policy and audit under `Origen`, not `OrigenWeb`. Provision roles externally; migrations manage objects and grants. Runtime appends approved columns but cannot mutate history. Sensitive reads stay denied without invented scope fields; later implementation must fail closed if required audit cannot commit. Protect against runtime credentials, not owners or superusers. Use strict TDD with `mix test` and independent PostgreSQL 17 privilege tests.

## Affected Areas

| Area | Impact |
|---|---|
| `lib/origen/` | New policy and internal audit boundaries |
| `priv/repo/migrations/` | New table, ACL, ownership, and trigger DDL |
| `config/`, `test/`, `.github/workflows/ci.yml` | Separated credentials and PostgreSQL evidence |

## Dependencies and Risks

- Depends on issue #1, OTP 29, PostgreSQL 17, Sprint 00, and matrix v0.4.
- Shared or privileged credentials weaken role-separation evidence.
- Premature authorization could invent unsafe scopes; keep sensitive reads denied until relationships and typed scopes exist.
- Delivery may exceed the 400-line review budget; `sdd-tasks` must forecast risk before any PR-splitting decision.

## Rollout and Rollback

Provision roles, migrate as migrator, then run as runtime. Validate migration, empty rollback/re-migration, grants, ownership, and triggers. Before rollback, remove application dependence and preserve/export history; never silently drop populated events.

## Success Criteria

- [ ] Matrix-backed policy tests prove explicit allows and default denial without invented scopes.
- [ ] Audit tests prove minimization, internal append, atomic success, durable application denial/failure, and default-denied sensitive reads.
- [ ] PostgreSQL 17 independently proves runtime ACL and trigger rejection with owner/migrator/runtime separation.
