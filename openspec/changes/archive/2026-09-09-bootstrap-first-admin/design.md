# Design: Bootstrap the First Administrator

## Technical Approach

`Origen.BootstrapAdmin` owns durable pending-account and invitation lifecycle state. Mix and `OrigenWeb` are delivery boundaries; existing authorization, typed audit, `Repo`, and `MigrationRepo` remain the policy, evidence, runtime-data, and migration-capability boundaries.

## Architecture Decisions

| Decision | Options / trade-off | Decision and rationale |
|---|---|---|
| Gate | Task-only checks drift. | `BootstrapAdmin.Gate` reads one runtime boolean, default false for absent/malformed input, and denies `Mix.env() == :prod`. Mix and release callers invoke it before any I/O; `runtime.exs` never enables production. |
| Data | Ephemeral tokens cannot prove revocation; a permanent one-admin index overreaches. | Create `internal_accounts`, singleton `admin_bootstrap_controls`, and immutable `internal_account_invitations`. The control row serializes first creation without fixing future multi-admin policy. |
| Invitation | Indexes cannot time-evaluate expiry. | Persist only versioned keyed-HMAC verifier, account reference, server issue/expiry time, consumption, and revocation. A partial unique index allows one unconsumed/unrevoked row; reissue revokes predecessors in its transaction. |
| Delivery | Route tokens leak. | Use local/test mailbox only; CLI emits account/invitation reference, never token/URL. A CSPRNG token in the link fragment is CSRF-POST exchanged for a short pre-activation session, then clean-URL redirected. |
| Credentials and keyring | Ad hoc crypto or an unversioned key prevents verified rotation. | Use approved `argon2_elixir ~> 4.1.3`, `nimble_totp ~> 1.0.0`, `cloak ~> 1.1.4`, and `cloak_ecto ~> 1.3.0`. A vendor-neutral runtime provider supplies exactly one active encrypting tag and retained decrypt-only tags; absent, malformed, duplicate, or unknown tags fail closed. Re-encrypt and verify reads before retiring a key. Compatibility and the native Make toolchain remain unproven until `mix deps.get` and compilation pass. |
| Audit/policy | Free-form metadata leaks. | Build exact `DEP-01`, `REI-01`, and `INV-01` facts; controller grants nothing. Typed constructors allow only account/invitation IDs and reject password, token, URL, TOTP, QR, session, digest, and key fields before every sink. |

## Data Flow

    Mix/release -> Gate -> Authorization -> BootstrapAdmin -> Repo transaction -> Audit
                                      |                         |
                                      +--> local/test Mailer <---+ raw token (memory only)

    fragment link -> POST exchange -> locked invitation -> pre-activation session
    form -> transaction: lock -> validate -> consume -> credentials -> activate -> audit

Issue locks control, atomically creates pending Administrator/invitation and audit. Reissue locks control/account; denies active Administrator, revokes predecessors, inserts replacement, audits atomically. Consume is one `Repo.transaction(Ecto.Multi)`: lock/validate invitation (verifier, binding, expiry, revocation, unused), set `consumed_at`, persist password/TOTP, activate account, append success audit. No password/TOTP credential, account activation, authenticated session, or credential state is persisted/issued before `consumed_at`. Required write/audit failure rolls back transaction and `consumed_at`; sanitized failure/denial audit may follow.

## File Changes

| File | Action | Description |
|---|---|---|
| `config/runtime.exs`, `config/test.exs` | Modify | Fail-closed gate and test key fixtures; no production enablement. |
| `mix.exs` | Modify | Add approved password, TOTP, and encrypted-seed dependencies; validate resolution and compilation during implementation. |
| `priv/repo/migrations/*_create_first_admin_bootstrap.exs` | Create | FK, role/state checks, one-active constraint, ownership, grants. |
| `lib/origen/bootstrap_admin.ex`, `lib/origen/bootstrap_admin/{gate,account,invitation,verifier,credentials,delivery,redaction}.ex` | Create | Lifecycle boundary and adapters. |
| `lib/mix/tasks/origen.bootstrap_admin.ex` | Create | Narrow deployment command; no token output. |
| `lib/origen/authorization/rules.ex`, `lib/origen/audit/events.ex` | Modify | Exact policy facts and typed event constructors. |
| `lib/origen_web/router.ex`, `lib/origen_web/controllers/admin_activation_{controller,html}.ex` | Modify/Create | Fragment exchange and clean session-bound forms. |
| `test/origen/bootstrap_admin_test.exs`, `test/origen_web/controllers/admin_activation_controller_test.exs`, `test/origen/audit/{events,postgres_security}_test.exs` | Create/Modify | Lifecycle, web, redaction, privilege regression tests. |

## Interfaces / Contracts

`issue_first/1`, `reissue_first/1`, `exchange/1`, and `activate/2` return tagged results. Raw tokens live only until mail delivery. Do not trust caller time, state, actor, or audit data. The activation session holds opaque invitation/account IDs, expiry, and nonce—not credentials or bearer token.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit (RED first) | gate, policy facts, redactor, verifier, credential/keyring adapters | ExUnit tables; missing/malformed/duplicate/unknown key tags and secret-like fields deny; rotation requires re-encryption and verified reads before retirement. |
| Integration (RED first) | constraints, expiry, races, consume-first rollback, grants | `DataCase`, locked transactions, `PostgresSecurityCase`; runtime cannot mutate audit or own/DDL bootstrap tables. |
| Web | fragment exchange, CSRF, redirect, session expiry, replay | `ConnCase` test mailer; invalid input changes no state. |
| E2E | N/A | No E2E runner is configured. |

## Threat Matrix

| Boundary | Applicability | Design response / RED tests |
|---|---|---|
| Documentation-like paths | N/A — no executable classification | None. |
| Git repository selection | N/A — no VCS integration | None. |
| Commit state | N/A — no commit automation | None. |
| Push state | N/A — no push automation | None. |
| PR commands | N/A — no PR automation | None. |

## Migration / Rollout

Run migration through `Origen.MigrationRepo` as owner; revoke `PUBLIC` and grant runtime only needed table/sequence operations, retaining audit grants. Enable only non-production with local/test mailbox and reviewed keys. Rollback disables gate and removes route/task deployment; it never deletes data/history. Down refuses populated-table destruction.

## Open Questions

- [ ] Validate the approved dependencies with `mix deps.get` and compilation; compatibility and the native Make toolchain remain unproven until then.
- [ ] Verify ingress, APM, mailer, and exception reporting redact request bodies/headers before web enablement.
- [ ] Prove release invocation uses the shared gate with production-default denial.
