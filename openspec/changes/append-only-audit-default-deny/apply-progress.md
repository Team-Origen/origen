# Apply Progress: Append-only Audit and Default-deny Authorization

## Delivery
- Mode: Strict TDD
- Strategy: `exception-ok`; overall `size:exception` accepted
- Completed: WU1 tasks 1.1–1.3 and WU2 tasks 2.1–2.4
- Remaining: WU3

## TDD Cycle Evidence
| Task | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|
| 1.1 | Unit | N/A (new) | 8/8 failed; modules absent | N/A | Grant and denial paths added | N/A |
| 1.2 | Unit | N/A (new) | Tests existed first | Harness passed 8/8 | Nine grants plus denial boundaries | Pure predicates |
| 1.3 | Unit | 8/8 | Behavior preserved | Harness passed 8/8 | Multidimensional table | 8/8 after refactor |
| 2.1 | Integration | N/A (new) | Focused run failed 10/12 with schema/modules absent | Focused run passed 12/12 | Valid/invalid constructors, constraints, four outcomes, three mutation paths | Shared constructor validation; 12/12 |
| 2.2 | Integration | N/A (new) | Transaction outcomes referenced absent writer | Runtime trace passed 5/5 | Commit, rollback, denial, failure, and unavailable paths | Shared failure mapping; 5/5 |
| 2.3 | Integration | N/A (new) | Tests existed before migration/modules | Focused run passed 12/12 | Row and statement trigger levels exercised | Separate append and multi boundaries |
| 2.4 | PostgreSQL runtime | N/A (new) | Rollback requirements encoded before migration | Empty rollback/re-migrate passed | Populated rollback returned SQLSTATE 55000 in disposable database | All fixture cleanup used database drop |

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

No design deviations. Database credentials were imported from user-scoped environment variables per command and were never printed or persisted.
