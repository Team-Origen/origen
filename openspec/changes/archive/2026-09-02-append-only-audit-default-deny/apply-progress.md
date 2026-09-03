# Apply Progress: Append-only Audit and Default-deny Authorization

## Delivery
- Mode: Strict TDD
- Strategy: `exception-ok`; overall `size:exception` accepted
- Completed: WU1 tasks 1.1–1.3, WU2 tasks 2.1–2.4, WU3 tasks 3.1–3.4, and bounded remediation tasks 4.1–4.4
- Remaining: None

## TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 1.1 | `test/origen/authorization_test.exs` | Unit | N/A (new) | 8/8 failed; modules absent | N/A | Grant and denial paths added | N/A |
| 1.2 | `test/origen/authorization_test.exs` | Unit | N/A (new) | Tests existed first | Harness passed 8/8 | Nine grants plus denial boundaries | Pure predicates |
| 1.3 | `test/origen/authorization_test.exs` | Unit | 8/8 | Behavior preserved | Harness passed 8/8 | Multidimensional table | 8/8 after refactor |
| 2.1 | `test/origen/audit/{events,writer}_test.exs` | Integration | N/A (new) | Focused run failed 10/12 with schema/modules absent | Focused run passed 12/12 | Valid/invalid constructors, constraints, four outcomes, three mutation paths | Shared constructor validation; 12/12 |
| 2.2 | `test/origen/audit/transaction_test.exs` | Integration | N/A (new) | Transaction outcomes referenced absent writer | Runtime trace passed 5/5 | Commit, rollback, denial, failure, and unavailable paths | Shared failure mapping; 5/5 |
| 2.3 | `test/origen/audit/{writer,transaction}_test.exs` | Integration | N/A (new) | Tests existed before migration/modules | Focused run passed 12/12 | Row and statement trigger levels exercised | Separate append and multi boundaries |
| 2.4 | `test/origen/audit/transaction_test.exs` | PostgreSQL runtime | N/A (new) | Rollback requirements encoded before migration | Empty rollback/re-migrate passed | Populated rollback returned SQLSTATE 55000 in disposable database | All fixture cleanup used database drop |
| 3.1 | `test/origen/audit/postgres_security_test.exs` | PostgreSQL runtime | WU2 audit baseline passed 12/12 | Initial focused run failed 1 test with 3 invalid before repository/provisioning existed | Disposable PostgreSQL 17.11 run passed 4/4 | Runtime ACL, verifier trigger, ownership, membership, grants, and trigger metadata paths | Catalog checks use role-aware privilege functions and `pg_trigger` event bits; 4/4 |
| 3.2 | `test/origen/audit/postgres_security_test.exs` | PostgreSQL runtime | N/A (new repository and provisioning) | Security assertions existed before role/config/CI implementation | Two-pass provisioning and migration as migrator passed | Provision-before-migrate and idempotent grant-after-migrate paths | Migration repository remains unsupervised and validates the owner identifier |
| 3.3 | `test/origen/audit/postgres_security_test.exs` | Integration | Focused security run passed 4/4 | Missing-configuration path initially failed without URLs | Harness reports variable names only and never credential values | Runtime, migration, verifier, and admin prerequisites remain separate | Connection cleanup tolerates already-stopped processes; 4/4 |
| 3.4 | Change-related suite | Verification | 25/25 ordinary tests | Verification commands were specified before execution | Full tests, warnings-as-errors compile, and focused format checks exited 0 | Triangulation skipped: this task executes structural quality gates | Repository-wide format failure isolated to pre-existing CRLF churn; no unrelated normalization |
| 4.1 | `test/origen/protected_operation_test.exs` | Integration | N/A (new test/module) | Failed 0/1 because `Origen.ProtectedOperation` was absent | Minimal authoritative denial path passed 1/1 | Direct denial proves no business or caller-controlled audit effect and exactly one sanitized denial | Test observes database effects through the production seam |
| 4.2 | `test/origen/protected_operation_test.exs` | Integration | Protected denial passed 1/1 | Business rollback case failed with the intentionally unsupported allow path | Denial and rollback cases passed 2/2 | Six cases cover atomic success, required-audit rollback, fresh failure, denial, and fresh-audit unavailability | Shared outcome finishing keeps fresh appends outside the rolled-back transaction; 6/6 passed |
| 4.3 | `test/origen/authorization_test.exs` | Unit | Authorization baseline passed 8/8 | Coverage-first characterization passed against unchanged policy code | No production policy change was required | Four allowed channels each deny another operation and one exceeded scope, adding eight behavioral assertions | Removed the unrelated process-dictionary sentinel; focused authorization suite passed 9/9 |
| 4.4 | `config/test.exs` | Structural/verification | Focused format check failed as previously reported | Formatter-required shape and line endings were applied only to the candidate-caused file | Focused format check exited 0 | Triangulation skipped: formatter correction is structural | Full suite passed 31 tests with 4 security tests excluded; warnings-as-errors compile exited 0 |

## Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `mix test test/origen/authorization_test.exs` was blocked before tests by missing PostgreSQL `:username`; `$env:MIX_ENV='test'; mix run --no-start test/origen/authorization_test.exs` passed 8 tests, 0 failures. |
| Runtime harness | N/A — WU1 is pure and has no runtime integration boundary. |
| Compile/format | Test-environment warning-as-error compilation and focused format check exited 0; LiveView emitted a non-fatal Windows symlink warning. |
| Rollback boundary | Revert WU1, removing its five policy modules, test, and progress marks; WU2/WU3 remain untouched. |

### WU2 Evidence
| Evidence | Result |
|---|---|
| Focused test | `mix test test/origen/audit` passed 12 tests, 0 failures against PostgreSQL 17.11 on port 5433. |
| Runtime harness | `mix test test/origen/audit/transaction_test.exs --trace` passed 5 tests, 0 failures; real SQL proved atomic success, rollback, fresh outcome appends, and `:audit_unavailable`. |
| Migration runtime | `MIX_ENV=test mix ecto.rollback -n 1` then `mix ecto.migrate` passed on empty `origen_test`; a disposable partition database rejected populated rollback with PostgreSQL SQLSTATE 55000 and was dropped afterward. |
| Compile/format | Focused `mix format --check-formatted` and `MIX_ENV=test mix compile --warnings-as-errors` exited 0. Repository-wide format check remains blocked by pre-existing CRLF churn outside WU2. |
| Rollback boundary | Revert only the WU2 migration, two audit modules, three audit test files, and WU2 progress marks. Database down is safe only while `audit_events` is empty; populated history requires preserve/export and separately approved destructive handling. |

### WU3 Evidence
| Evidence | Result |
|---|---|
| Focused test | Disposable PostgreSQL 17.11 provisioning plus `mix test test/origen/audit/postgres_security_test.exs --include postgres_security` passed 4 tests, 0 failures. Assertions independently proved `current_user`, role flags, SET-only owner membership, ownership, exact grants, PUBLIC revocations, runtime SQLSTATE 42501, verifier SQLSTATE 55000, trigger levels/events, and unchanged rows. |
| Runtime harness | Roles were provisioned before migration and provisioned again after migration without errors; `mix ecto.security.migrate` ran through unsupervised `Origen.MigrationRepo` as migrator after `SET ROLE` to the NOLOGIN owner. The disposable database and all four disposable roles were dropped; follow-up catalog queries returned 0 residual databases and 0 residual roles. |
| Full verification | `mix test` passed 25 tests, 0 failures, 4 PostgreSQL-security tests excluded by default. `mix compile --warnings-as-errors` exited 0 with the known non-fatal Windows LiveView symlink warning. Focused `mix format --check-formatted` for WU3 Elixir files exited 0. Repository-wide `mix format --check-formatted` remains blocked by pre-existing CRLF files, including unrelated files; none were normalized. |
| CI boundary | CI provisions owner/migrator/runtime/verifier identities from service-scoped environment credentials, migrates separately, runs the ordinary suite, then runs the PostgreSQL security suite with `Origen.Repo` authenticated as runtime and an independent verifier connection. |
| Rollback boundary | Revert only the WU3 migration repository, separated configuration and alias, role provisioning SQL, PostgreSQL security harness/tests, CI steps, test tag exclusion, and WU3 progress marks. Do not revoke deployed audit ACLs or triggers; external role deprovisioning requires a separately approved operational rollback. |

### Bounded Remediation Evidence
| Evidence | Result |
|---|---|
| Focused tests | `mix test test/origen/protected_operation_test.exs test/origen/authorization_test.exs test/origen/audit/transaction_test.exs` passed 19 tests, 0 failures. |
| Runtime harness | `mix test test/origen/audit/postgres_security_test.exs --include postgres_security` passed 4 tests, 0 failures on a disposable PostgreSQL 17.11 database with four disposable roles. |
| Full verification | `mix test` passed 31 tests, 0 failures, with 4 PostgreSQL-security tests excluded. `mix compile --warnings-as-errors` and focused `mix format --check-formatted` exited 0; the known Windows LiveView symlink warning remained non-fatal. |
| Cleanup | The disposable PostgreSQL database and all four roles were dropped in a `finally` boundary; exact follow-up catalog counts were `database_residue=0 role_residue=0`. `.gitignore` was restored exactly to `HEAD`; `.atl` files and the failed `verify-report.md` evidence were not modified by remediation. |
| Rollback boundary | Revert the single remediation commit: `Origen.ProtectedOperation`, its integration tests, authorization coverage, the `config/test.exs` formatter correction, and Phase 4 progress/task marks. Existing WU1–WU3 behavior and failed verification evidence remain intact. |

No design deviations. The remediation implements the design's transaction flow at a production boundary. Delivery remains `exception-ok`; this correction is independently bounded below the 400-line native limit. Database credentials were imported from user-scoped environment variables per command and were never printed or persisted.
