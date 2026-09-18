```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:eb64b2594cc0438273e92fbd52cd60ebcbfc125db5862ae6617bbd390fffaaf8
verdict: pass
blockers: 0
critical_findings: 0
requirements: 9/9
scenarios: 18/18
test_command: mix test
test_exit_code: 0
test_output_hash: sha256:2e77454703945110a6d271b99ed78d2e2f2377b32ecd9fba487bf25a03e60cd3
build_command: mix compile --warnings-as-errors
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: `append-only-audit-default-deny`  
**Version**: Authorization matrix v0.4  
**Mode**: Strict TDD  
**Candidate commit**: `fbb78de1da6d5127ed8c32659afd960f4c91852f`  
**Authority owner**: Parent-held `final-sdd-reverification`; verification did not acquire, settle, reset, or advance native authority.

### Executive Summary

Fresh independent verification passes the remediated candidate. All 9 requirements and 18 scenarios have passing runtime coverage, including authoritative fresh denial and post-rollback failure auditing through `Origen.ProtectedOperation`, narrow non-role channel scope, and database-observable direct-backend no-effects behavior. Compilation, focused suites, the ordinary suite, PostgreSQL 17.11 least-privilege tests, rollback checks, and focused formatting all passed; every disposable database and role was removed with zero residue.

### Evidence Lineage

| Evidence | Revision | Disposition |
|---|---|---|
| Previous final verification | `sha256:f9fb011e993e3e4028e9dba6ff5f9b8fa69fb26b22591049cc9037a1640b855c` | Failed with three critical behavioral gaps. |
| Bounded remediation | `sha256:5c926e44cbcc8dc4c14db428089ca05692ce045923078dacb001a72fb0d3fbf3` | Added the protected production seam and missing behavioral coverage. |
| Fresh final verification | `sha256:eb64b2594cc0438273e92fbd52cd60ebcbfc125db5862ae6617bbd390fffaaf8` | Passes the remediated candidate. |

### Completeness

| Metric | Value |
|---|---:|
| Requirements total | 9 |
| Requirements compliant | 9 |
| Scenarios total | 18 |
| Scenarios compliant | 18 |
| Scenarios partial/untested/failing | 0 |
| Tasks checked in `tasks.md` | 15/15 |
| TDD evidence rows in `apply-progress.md` | 15/15 |

### Commit Inspection

| Commit | Inspection result |
|---|---|
| `eef8b96afee9fe3496cb55f9ec699c968e488943` | WU1 adds pure multidimensional default-deny authorization and focused policy tests. |
| `71ec82769c97329ffd79497929c7ec33ec715856` | Planning commit adds the proposal, two delta specs, design, exploration, and OpenSpec configuration. |
| `51df9674858824e554fbe1a81c2a0dcb61e2db8c` | WU2 adds minimized event constructors, internal writer, migration, transaction semantics, and audit tests. |
| `b4d8cc714e6f277fcac1d615290be021271873d4` | WU3 adds separated migration/runtime/security configuration, external role provisioning, PostgreSQL security tests, and CI wiring. |
| `fbb78de1da6d5127ed8c32659afd960f4c91852f` | Remediation adds the protected operation production seam, six integration tests, four-channel overreach coverage, and the `config/test.exs` formatter correction. |

The exact linear chain is `eef8b96 -> 71ec827 -> 51df967 -> b4d8cc7 -> fbb78de` from baseline `88b8ebf`. The complete candidate contains 2,113 additions and 15 deletions across 34 files. The remediation commit contains 292 additions and 31 deletions across six files. Verification did not modify application code.

### Build and Test Execution

| Command | Exit | Outcome | Exact captured-output hash |
|---|---:|---|---|
| `mix compile --warnings-as-errors` | 0 | Passed; empty output | `sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `mix test test/origen/protected_operation_test.exs test/origen/authorization_test.exs test/origen/audit/transaction_test.exs` | 0 | 19 passed | `sha256:afbe3032e3e13fc759347ee408c9ab4ce9f823ca21141bfdbf5d65c615883264` |
| `mix test test/origen/authorization_test.exs` | 0 | 8 passed | `sha256:b021272dea43dea14bda5d880f846818168c56d9567386aed2816b350bfac469` |
| `mix test test/origen/protected_operation_test.exs` | 0 | 6 passed | `sha256:eb3023bce879d216086ba80759698ec52c4d6f2cf065aeab1d8e936cceb617fb` |
| `mix test test/origen/audit` | 0 | 12 passed, 4 PostgreSQL-security tests excluded | `sha256:5ce1c549a41cd0d346d997c9ddec2e716d07eee4c2f8a17aba1cddecc55401f1` |
| `mix test test/origen/audit/transaction_test.exs --trace` | 0 | 5 passed | `sha256:d91feb009565fabc63a8040e0484f025b07787fe47badf1578656b824eeab1e0` |
| `mix test` | 0 | 31 passed, 4 PostgreSQL-security tests excluded by project configuration | `sha256:2e77454703945110a6d271b99ed78d2e2f2377b32ecd9fba487bf25a03e60cd3` |
| Disposable provisioning, migration, empty rollback, re-migration, and re-provisioning | 0 | Passed against PostgreSQL 17.11 | Recorded in the bounded runtime transcript |
| `mix test test/origen/audit/postgres_security_test.exs --include postgres_security` | 0 | 4 passed on disposable identities | `sha256:1106914e8a3805fcf13596840ed063878d3af646cc6b991e3cc7fb9a4ea2b021` |
| Populated `mix ecto.rollback -r Origen.MigrationRepo -n 1` | 1, expected | Rejected with SQLSTATE `55000`; table and 2 rows remained | `sha256:23732375fb5791978c25c92201b514c2203116e03b828e9b1b7efdbf5b76fc2b` |
| Focused `mix format --check-formatted` on all changed Elixir files | 0 | Passed, including `config/test.exs` | `sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

PostgreSQL credentials were imported from Windows User environment variables only inside each child process. Credential values were never printed or persisted.

### PostgreSQL Runtime and Rollback Evidence

The disposable PostgreSQL 17.11 sequence independently proved:

- provisioning before migration and idempotent provisioning after migration;
- a NOLOGIN owner and LOGIN/NOINHERIT migrator, runtime, and verifier roles;
- migrator-only SET membership in the owner role;
- owner ownership of the database schema, table, sequence, trigger function, and triggers;
- runtime INSERT access only to the six approved columns plus sequence usage;
- runtime SQLSTATE `42501` for reads, historical mutation, DDL, role creation, owner assumption, and caller-supplied `recorded_at`;
- verifier SQLSTATE `55000` for UPDATE, DELETE, and TRUNCATE through independent row-level and statement-level triggers;
- unchanged history after every rejected mutation;
- successful empty rollback and re-migration;
- populated rollback refusal with SQLSTATE `55000`, preserving the table and two rows.

### Cleanup Evidence

| Check | Result |
|---|---|
| Disposable database drop | Exit 0 |
| Four disposable role drops | Exit 0 |
| Exact disposable database residue | 0 |
| Exact disposable role residue | 0 |
| Global `origen_verify_%` database residue | 0 |
| Global verification-role residue | 0 |
| Generated `cover/` directory | Removed; residue 0 |
| `.atl` files | Pre-existing modifications preserved and not edited by verification |

### Spec Compliance Matrix

| Capability / Requirement | Scenario | Passing runtime covering evidence | Result |
|---|---|---|---|
| Append-only Audit / Minimized Server-controlled Events | Invalid value or field | `events_test.exs` verifies exact schema, bounds, vocabulary, malformed rows, and unavailable arbitrary constructor | COMPLIANT |
| Append-only Audit / Minimized Server-controlled Events | Reference is conditionally absent | `events_test.exs` constructor and PostgreSQL constraint cases accept only valid nullability combinations | COMPLIANT |
| Append-only Audit / Internal Append-only Boundary | Correction preserves history | `events_test.exs` appends distinct outcomes, verifies unique identities and preserved row count; trigger tests reject mutation | COMPLIANT |
| Append-only Audit / Internal Append-only Boundary | External mutation request | `authorization_test.exs`, `writer_test.exs`, and PostgreSQL ACL/trigger suites deny public/generic mutation and preserve history | COMPLIANT |
| Append-only Audit / Transaction Outcomes | Allowed write succeeds | `protected_operation_test.exs` observes one business row and one success event committed through the production seam | COMPLIANT |
| Append-only Audit / Transaction Outcomes | Required audit append fails | `protected_operation_test.exs` injects database audit rejection and observes business rollback plus `:audit_unavailable` | COMPLIANT |
| Append-only Audit / Transaction Outcomes | Business write fails | `protected_operation_test.exs` observes rolled-back business state and exactly one fresh sanitized failure event | COMPLIANT |
| Append-only Audit / Transaction Outcomes | Application policy denies | `protected_operation_test.exs` observes no callback business/caller-audit effects and exactly one fresh sanitized denial event | COMPLIANT |
| Append-only Audit / Deferred Sensitive Audit Reads | Sensitive audit read is requested | `authorization_test.exs` denies `:read_audit_log`; no read boundary exists | COMPLIANT |
| Append-only Audit / Separated Database Capabilities | PostgreSQL 17 defenses are verified | Disposable PostgreSQL 17.11 suite proves identity, ownership, grants, ACL `42501`, trigger `55000`, and unchanged rows | COMPLIANT |
| Default-deny Authorization / Complete Policy Input | Explicitly authorized operation | `authorization_test.exs` table-drives all matrix-v0.4 explicit grants with complete facts | COMPLIANT |
| Default-deny Authorization / Complete Policy Input | Missing or unmet policy fact | `authorization_test.exs` denies unknown, missing, unmet, and invalid not-applicable facts; the protected seam does not execute callbacks after denial | COMPLIANT |
| Default-deny Authorization / Canonical Default Denial | Unknown operation or actor | `authorization_test.exs` verifies stable denial for unknown operations and subjects | COMPLIANT |
| Default-deny Authorization / Canonical Default Denial | Relationship is not implemented | `authorization_test.exs` verifies absent target/scope relationships deny | COMPLIANT |
| Default-deny Authorization / Canonical Default Denial | Sensitive audit read lacks typed scope support | `authorization_test.exs` denies the read and no audit read API exists | COMPLIANT |
| Default-deny Authorization / No Implicit Grants | Administrator lacks an explicit grant | `authorization_test.exs` proves role names do not create hierarchy or inherited grants | COMPLIANT |
| Default-deny Authorization / No Implicit Grants | Non-role channel is narrowly scoped | `authorization_test.exs` makes each of deployment, invitation, system, and public-possession channels deny another operation and an exceeded declared scope | COMPLIANT |
| Default-deny Authorization / Backend Enforcement | Direct backend request | `protected_operation_test.exs` invokes the production seam directly, observes zero protected business rows, and proves the denied callback cannot append its caller-controlled audit event | COMPLIANT |

**Compliance summary**: 18/18 scenarios compliant and 9/9 requirements fully compliant.

### Correctness: Static Evidence

| Requirement area | Status | Notes |
|---|---|---|
| Complete explicit facts and canonical default denial | Implemented | Pure policy validates every dimension and matches exact predicates without ranks or wildcards. |
| Backend enforcement | Implemented | `Origen.ProtectedOperation.execute/4` obtains the authoritative decision before invoking the business callback. |
| Fresh denial/failure audits | Implemented | Denial and post-rollback failure append through fresh `Writer.append/2` transactions; failure returns `:audit_unavailable`. |
| Atomic success | Implemented | Business callback and required success event share one `Ecto.Multi` transaction. |
| Minimized internal append | Implemented | Exact eight-column schema, named opaque constructors, approved-column insert, and no generic CRUD/read/web boundary. |
| Database append-only and least privilege | Implemented | ACL and trigger defenses pass independently on PostgreSQL 17.11. |
| Forward-only populated rollback | Implemented | Down migration rejects non-empty history with SQLSTATE `55000`. |

### Design Coherence

| Decision | Followed? | Notes |
|---|---|---|
| Domain code remains under `Origen` with no `OrigenWeb` audit API | Yes | The protected seam is `Origen.ProtectedOperation`; no web files were added by remediation. |
| Pure exact-rule authorization | Yes | Unknown, missing, unmet, and unimplemented facts fail closed. |
| Opaque named constructors and internal writer | Yes | No arbitrary event constructor or generic audit context exists. |
| Atomic success and required-audit rollback | Yes | The production seam composes business and audit steps in one `Ecto.Multi`. |
| Fresh denial and business-failure transactions | Yes | Fresh append occurs outside the denied or rolled-back business transaction. |
| ACL plus independent triggers | Yes | Runtime and verifier paths produce distinct expected SQLSTATE values. |
| Separate owner/migrator/runtime/verifier capabilities | Yes | Runtime execution proves role flags, membership, ownership, grants, and denied operations. |

### TDD Compliance

| Check | Result | Details |
|---|---|---|
| TDD evidence reported | Yes | `apply-progress.md` contains 15 task rows with test files, layers, safety nets, RED, GREEN, triangulation, and refactor evidence. |
| All behavior tasks have tests | Yes | Six change-related test files exist and pass. |
| RED confirmed | Yes, artifact-based | Reported initial failures are specific and corresponding tests exist; commit history alone cannot independently prove within-commit ordering. |
| GREEN confirmed | Yes | All 30 change-related tests pass across ordinary and PostgreSQL-security execution. |
| Triangulation adequate | Yes | Outcome variance includes allow, denial, business failure, audit failure, four distinct channels, other operations, and exceeded scopes. |
| Safety net for modified files | Yes | Existing WU baselines and remediation safety-net runs are recorded; new files correctly report N/A. |

**TDD compliance**: 15/15 task rows are present and current runtime GREEN is confirmed. The evidence text overstates the focused authorization suite as 9/9 in one row even though the file contains 8 ExUnit tests; this is a non-blocking documentation warning because all declared behaviors are covered and pass.

### Test Layer Distribution

| Layer | Tests | Files | Tool |
|---|---:|---:|---|
| Unit | 8 | 1 | ExUnit |
| Integration/database | 18 | 4 | ExUnit + Ecto SQL Sandbox + PostgreSQL |
| PostgreSQL runtime security | 4 | 1 | ExUnit + Postgrex + disposable roles/database |
| E2E | 0 | 0 | Not available |
| **Total change-related** | **30** | **6** | |

The ordinary run includes 26 change-related tests and 5 pre-existing application tests; the 4 PostgreSQL-security tests run separately.

### Changed File Coverage

`mix test --cover` passed all 31 ordinary tests but exited 3 because repository-wide coverage is 45.21%, below the configured 90% threshold. Strict TDD treats coverage as informational rather than blocking. Output hash: `sha256:1f5a1b13758baa7258de29db27f715d20e92b19aced6913126c312530e9eda5a`.

| Changed module | Line coverage | Rating |
|---|---:|---|
| `Origen.ProtectedOperation` | 100.00% | Excellent |
| `Origen.Audit.Writer` | 100.00% | Excellent |
| `Origen.Authorization.Decision` | 100.00% | Excellent |
| `Origen.Authorization.Request` | 100.00% | Excellent |
| `Origen.Authorization.Rules` | 100.00% | Excellent |
| `Origen.Authorization` | 76.92% | Low |
| `Origen.Audit.Events` | 77.78% | Low |
| `Origen.Authorization.Fact` | 60.00% | Low |
| `Origen.MigrationRepo` | 0.00% in ordinary coverage | Executed separately by the PostgreSQL-security suite |
| `Origen.PostgresSecurityCase` | 3.70% in ordinary coverage | Most paths execute in the separately run security suite |

Branch coverage and uncovered line ranges are not emitted by the built-in Mix coverage reporter.

### Assertion Quality

**Assertion quality**: All assertions verify observable behavior. No tautological literals, orphan empty-only checks, ghost loops, smoke-only checks, implementation-detail coupling, or mock-heavy tests were found. Fixed loops iterate explicit non-empty case collections. The former process-dictionary sentinel is absent; direct-backend enforcement now observes database state through the production seam.

### Quality Metrics and Formatting

**Compiler**: Passed with warnings as errors.  
**Linter**: Not available.  
**Type checker**: Not available.  
**Focused formatter**: Passed for every changed Elixir file, including the remediated `config/test.exs`.  
**Repository-wide formatter**: Exit 1, output hash `sha256:f6128d018798633f1507e84f5fc5edad20caae5a9d7f7bdff151e8fe9421340a`; failures are broad pre-existing CRLF normalization churn outside the candidate-focused check.

### Remote CI

`gh run list --branch feat/2-append-only-audit-default-deny --json databaseId,status,conclusion,workflowName,headSha` returned `[]`. No remote GitHub Actions run exists for this branch. This is a warning, not a candidate defect; local PostgreSQL 17.11 execution covers the required runtime behavior.

### Issues Found

**CRITICAL**: None.  
**WARNING**:

1. Remote GitHub Actions has not run for this branch.
2. Repository-wide coverage is 45.21%, below the configured 90% threshold; changed security modules are exercised across ordinary and separately executed PostgreSQL suites.
3. Repository-wide formatting remains blocked by pre-existing CRLF churn, while the candidate-focused formatting check passes and the prior `config/test.exs` defect is resolved.
4. One `apply-progress.md` row says the authorization suite passed 9/9, while fresh execution reports 8 ExUnit tests; this is documentation-count drift, not missing behavioral coverage.

**SUGGESTION**: None.

### Canonical Verification Evidence Preimage

The evidence revision is the SHA-256 digest of the exact 492 UTF-8 bytes inside the following code block, excluding fences and line terminators:

```json
{"build":{"command":"mix compile --warnings-as-errors","exit_code":0,"output_hash":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},"change":"append-only-audit-default-deny","cleanup":{"database_residue":0,"role_residue":0},"commit":"fbb78de1da6d5127ed8c32659afd960f4c91852f","requirements":"9/9","scenarios":"18/18","test":{"command":"mix test","exit_code":0,"output_hash":"sha256:2e77454703945110a6d271b99ed78d2e2f2377b32ecd9fba487bf25a03e60cd3"},"verdict":"pass"}
```

### Verdict

**PASS**

The remediated candidate satisfies all 9 requirements and 18 scenarios with passing runtime evidence and zero disposable PostgreSQL residue. It is ready for native settlement by the parent and then archival, subject only to the recorded non-blocking warnings.
