# Tasks: Bootstrap the First Administrator

## Review Workload Forecast

| Field | Value |
| --- | --- |
| Estimated changed lines | 900–1,200 lines |
| 800-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 foundation → PR 2 lifecycle → PR 3 web |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
| --- | --- | --- | --- | --- | --- |
| 1 | Record approved Argon2id/PHC, RFC 6238, seed encryption, and tagged-keyring selection; implement adapters afterward. | PR 1 | `mix test test/origen/bootstrap_admin/credentials_test.exs test/origen/bootstrap_admin/verifier_test.exs` | N/A: pure adapters have no deployed boundary. | `mix.exs` and crypto adapters; no schema/routes.
| 2 | Add schema, migration, grants, and security regressions. | PR 1 | `mix test test/origen/bootstrap_admin_test.exs test/origen/audit/postgres_security_test.exs` | `mix ecto.migrate` via `Origen.MigrationRepo`, then sandbox tests. | Migration/tables/grants; down refuses populated destruction.
| 3 | Deliver gate, policy facts, redaction, and command boundary. | PR 1 | `mix test test/origen/bootstrap_admin/gate_test.exs test/origen/audit/events_test.exs` | `MIX_ENV=prod mix origen.bootstrap_admin` denies before I/O. | Gate/task/policy/audit files.
| 4 | Deliver locked lifecycle and rollback. | PR 2 | `mix test test/origen/bootstrap_admin_test.exs` | Enabled non-prod task with test mailbox; assert sanitized output. | Lifecycle modules/tests.
| 5 | Deliver fragment exchange, clean redirect, session binding, password/TOTP, replay denial. | PR 3 | `mix test test/origen_web/controllers/admin_activation_controller_test.exs` | `mix phx.server` with test TLS/mailbox harness. | Router/controller/session; history retained.

## Phase 1: Foundation

- [x] 1.1 Validate the approved `argon2_elixir ~> 4.1.3`, `nimble_totp ~> 1.0.0`, `cloak ~> 1.1.4`, and `cloak_ecto ~> 1.3.0` declarations with `mix deps.get` and `mix compile --warnings-as-errors`; retain vendor-neutral runtime-provider and tagged-keyring semantics for later implementation.
- [x] 1.2 RED: add failing schema, grant, and populated-rollback tests for `priv/repo/migrations/*_create_first_admin_bootstrap.exs` and `test/origen/audit/postgres_security_test.exs`.
- [x] 1.3 GREEN: create `priv/repo/migrations/*_create_first_admin_bootstrap.exs` with locks, FKs/checks, one-active index, owner path, least-privilege grants, safe down.

## Phase 2: Domain Primitives

- [x] 2.1 RED: test `lib/origen/bootstrap_admin/{gate,verifier,credentials,redaction}.ex` for denial, CSPRNG token + versioned keyed-HMAC digest, slow hash, encrypted seed, and secret rejection.
- [x] 2.2 GREEN: implement those modules; default runtime config false, deny `Mix.env() == :prod`, never persist raw tokens, and construct no sensitive sink payloads.
- [x] 2.3 RED then GREEN: extend `lib/origen/authorization/rules.ex` and `lib/origen/audit/events.ex` with explicit bootstrap/reissue/activation facts and allowlisted typed constructors; test default-deny and append-only semantics.

## Phase 3: Lifecycle/Delivery

- [x] 3.1 RED: test unique pending admin, 24-hour expiry, consume-once, reissue revocation, concurrent races, and credential/required-audit rollback.
- [x] 3.2 GREEN: implement `lib/origen/bootstrap_admin.ex` and `{account,invitation,delivery}.ex` as lifecycle module boundaries; lock control/account, set `consumed_at` before credentials, and audit atomically.
- [x] 3.3 RED then GREEN: create `lib/mix/tasks/origen.bootstrap_admin.ex`, modify `config/runtime.exs`/`config/test.exs`, and prove shared gate denial plus reference-only test mail delivery.
- [x] 3.4 RED then GREEN: add `lib/origen_web/controllers/admin_activation_{controller,html}.ex` and routes; test TLS, fragment POST/CSRF, clean redirect, session expiry, invalid input, valid TOTP, and replay.

## Phase 4: Verification and Documentation

- [x] 4.1 Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`, and `mix test --cover`; record harness evidence.
- [x] 4.2 Update `docs/CONTEXT.md`, `docs/sprints/SPRINT_00.md`, and security/deployment docs with rollback, ingress/APM redaction, release invocation, and dependency/key assumptions.

## Authorized PR #10 Remediation

- [x] Reject verifier keys shorter than 32 bytes before transaction or persistence in `issue_first/1` and `reissue_first/2`, with regression coverage for 31-byte keys and unchanged database state.
- [x] Standardize reissue and activation account/invitation lock order, with concurrent regression coverage asserting no PostgreSQL `40P01` deadlock.

## Authorized Final Verification Remediation

- [x] 5.1 Strict RED/GREEN: add a failing packaged-release bootstrap invocation test, then implement and test that invocation through the existing shared fail-closed gate before any configuration parsing, repository access, network access, or other I/O; provision and run the PostgreSQL runtime, migration, and verifier-role security harness without exclusions or invalidation; record the exact build, invocation, migration, harness, and verification commands and results, plus resource cleanup and file/database rollback boundaries, to remediate failed evidence revision `sha256:83c54ae2a58aa6cca0e9cd71be1d170d7989f94bf3a69f71b226484017011303`.
