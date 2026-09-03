# Tasks: Append-only Audit and Default-deny Authorization

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 900–1,300 additions+deletions |
| Risk | High; security DDL, transactions, credentials, CI |
| Chained PRs recommended | Yes |
| Suggested split | WU1 → WU2 → WU3; delivery topology pending |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

Apply is blocked until the user selects `stacked-to-main`, `feature-branch-chain`, or an approved `size-exception`.

### Suggested Work Units

| Unit | Goal and expected files | Evidence | Completion / rollback / commit |
|---|---|---|---|
| WU1 | Default-deny policy: `lib/origen/authorization.ex`, `lib/origen/authorization/request.ex`, `lib/origen/authorization/fact.ex`, `lib/origen/authorization/decision.ex`, `lib/origen/authorization/rules.ex`, `test/origen/authorization_test.exs` | Focused: `mix test test/origen/authorization_test.exs`; runtime: N/A—pure boundary | Every matrix-v0.4 case passes; remove listed files; `feat(auth): enforce multidimensional default denial` |
| WU2 | Minimized append and transactions: `priv/repo/migrations/20260902190000_create_audit_events.exs`, `lib/origen/audit/events.ex`, `lib/origen/audit/writer.ex`, `test/origen/audit/events_test.exs`, `test/origen/audit/writer_test.exs`, `test/origen/audit/transaction_test.exs` | Focused: `mix test test/origen/audit`; runtime: `mix test test/origen/audit/transaction_test.exs --trace` | Constraints and outcomes pass; down only when empty, otherwise preserve/export history; `feat(audit): add append-only transactional events` |
| WU3 | Least-privilege proof: `lib/origen/migration_repo.ex`, `config/{config,test,runtime}.exs`, `mix.exs`, `priv/repo/security/provision_roles.sql`, `test/support/postgres_security_case.ex`, `test/origen/audit/postgres_security_test.exs`, `.github/workflows/ci.yml` | Focused: `mix test test/origen/audit/postgres_security_test.exs --include postgres_security`; runtime: provision four roles on PostgreSQL 17, migrate as migrator, test as runtime/verifier | `42501` ACL and `55000` trigger evidence passes; revert harness/config only, never weaken deployed ACLs; `ci(security): prove PostgreSQL audit least privilege` |

## Phase 1: WU1 — Policy (RED → GREEN → REFACTOR)

- [x] 1.1 **RED:** Test explicit allow; unknown/missing/unmet dimensions; unknown operation/subject; absent relationships; A-02 sensitive reads; A-03/admin implicit grants; channel overreach; direct-backend denial/no effects.
- [x] 1.2 **GREEN:** Implement typed complete facts and exact operation/subject rules; only rules accept `:not_applicable`; add no ranks, wildcards, frontend authority, or side effects.
- [x] 1.3 **REFACTOR:** Table-drive matrix cases, keep denial reasons stable, then record focused evidence.

## Phase 2: WU2 — Audit (RED → GREEN → REFACTOR)

- [x] 2.1 **RED:** Test exact columns, bigint identity, bounds, snake_case, allowlists, conditional references, four results, server `clock_timestamp()` bounds, rejected extra/caller-time/scope/JSON fields, correction append, external mutation/read denial.
- [x] 2.2 **RED:** Test atomic success, audit-failure rollback, business rollback plus fresh failure append, denial plus fresh append, and `:audit_unavailable` when required fresh audit fails.
- [x] 2.3 **GREEN:** Add owner-run migration with column grants, row UPDATE/DELETE and statement TRUNCATE triggers; implement opaque constructors and internal decision-gated `append/2`/`append_to_multi/3`; expose no CRUD/read/web path.
- [x] 2.4 **REFACTOR:** Centralize sanitization/allowlists; verify empty down/re-migrate while non-empty down refuses and production remains forward-only.

## Phase 3: WU3 — PostgreSQL 17 Proof (RED → GREEN → REFACTOR)

- [ ] 3.1 **RED:** Add non-sandbox assertions for `current_user`, NOLOGIN owner, NOINHERIT roles, migrator SET-only membership, ownership/grants, approved-column INSERT, trigger events/levels, unchanged rows, runtime `42501`, verifier `55000`.
- [ ] 3.2 **GREEN:** Provision roles outside migrations; separate runtime/migration/security URLs; revoke PUBLIC CONNECT/schema CREATE/object access; migrate via unsupervised `Origen.MigrationRepo`; make CI run `mix test` as runtime.
- [ ] 3.3 **REFACTOR:** Redact secrets and document local `ORIGEN_TEST_DB_USERNAME`, `ORIGEN_TEST_DB_PASSWORD`, `ORIGEN_MIGRATION_DATABASE_URL`, and `ORIGEN_SECURITY_DATABASE_URL` prerequisites in harness output.
- [ ] 3.4 Verify `mix test`, `mix compile --warnings-as-errors`, and `mix format --check-formatted`; inspect diffs for CRLF-only churn and fix line endings without weakening formatter checks.
