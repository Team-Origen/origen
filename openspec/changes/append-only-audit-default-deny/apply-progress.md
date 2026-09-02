# Apply Progress: Append-only Audit and Default-deny Authorization

## Delivery
- Mode: Strict TDD
- Strategy: `exception-ok`; overall `size:exception` accepted
- Completed: WU1 tasks 1.1, 1.2, and 1.3
- Remaining: WU2 and WU3

## TDD Cycle Evidence
| Task | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|
| 1.1 | Unit | N/A (new) | 8/8 failed; modules absent | N/A | Grant and denial paths added | N/A |
| 1.2 | Unit | N/A (new) | Tests existed first | Harness passed 8/8 | Nine grants plus denial boundaries | Pure predicates |
| 1.3 | Unit | 8/8 | Behavior preserved | Harness passed 8/8 | Multidimensional table | 8/8 after refactor |

## Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `mix test test/origen/authorization_test.exs` was blocked before tests by missing PostgreSQL `:username`; `$env:MIX_ENV='test'; mix run --no-start test/origen/authorization_test.exs` passed 8 tests, 0 failures. |
| Runtime harness | N/A — WU1 is pure and has no runtime integration boundary. |
| Compile/format | Test-environment warning-as-error compilation and focused format check exited 0; LiveView emitted a non-fatal Windows symlink warning. |
| Rollback boundary | Revert WU1, removing its five policy modules, test, and progress marks; WU2/WU3 remain untouched. |

No design deviations. PostgreSQL credentials were not fabricated for the repository Mix test alias.
