# Operate the first Administrator bootstrap safely

Use this runbook only in an explicitly enabled, non-production environment with synthetic data. The bootstrap remains disabled by default and is always denied when compiled with `MIX_ENV=prod`.

## Preconditions

Do not enable the surface until every item is true:

- The deployment is classified as non-production.
- `Origen.MigrationRepo` has applied the bootstrap migration with the owner role; the runtime role has only the grants defined by that migration.
- TLS is enforced at the public edge and between the edge and application where the platform does not provide an equivalent protected channel.
- The ingress, proxy, APM agent, exception reporter, mail adapter, and support tooling satisfy [Activation data handling](../security/ACTIVATION_DATA_HANDLING.md).
- A secret manager provides a verifier key of at least 32 bytes and an encryption keyring that satisfies the assumptions below.
- A reviewed, one-time token delivery integration exists. The current Mix task email and terminal output contain references only; they deliberately do not deliver the raw invitation token or an activation URL.

## Dependency and key assumptions

| Item | Required assumption |
| --- | --- |
| Password hashing | `argon2_elixir ~> 4.1.3` is resolved and its native build toolchain is available. Stored values are Argon2 PHC strings; no plaintext password is retained. |
| TOTP | `nimble_totp ~> 1.0.0` is resolved. Enrollment uses server-generated seeds and validates a code before activation. Recovery-code policy is not part of this bootstrap. |
| Seed encryption | `cloak ~> 1.1.4` and `cloak_ecto ~> 1.3.0` are resolved. Each AES-GCM key is exactly 32 bytes. |
| Keyring | Exactly one unique tag is active for encryption. Retired tags are decrypt-only and remain available until all values are re-encrypted and verified readable with the active key. Missing, malformed, duplicate, or unknown tags fail closed. |
| Invitation verification | `ORIGEN_BOOTSTRAP_VERIFIER_KEY` is at least 32 bytes, comes from a secret manager, and is identical at issuance and exchange. Do not log, print, persist, or reuse it as an encryption key. |
| Runtime web configuration | The application-side `:bootstrap_admin_verifier_key` and encryption keyring must be supplied through reviewed runtime-provider wiring before activation is enabled. Environment-variable names alone do not establish that wiring. |

Before changing a key, retain the previous decrypt-only tag, re-encrypt existing seeds, verify reads, and only then retire the old key. Key loss makes enrolled TOTP seeds unrecoverable; backup and restore procedures must include the external key provider without placing keys in database backups.

## Approved invocation boundaries

Use either the source-checkout Mix task or the packaged command `bin/origen_bootstrap_admin`. Both call the shared `Origen.BootstrapAdmin.Gate` before argument parsing, repository access, network access, or bootstrap-specific I/O. The packaged command is part of the release overlay; do not substitute `bin/origen eval`, a remote console, or direct context/database calls.

```bash
# Source checkout
MIX_ENV=dev \
ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true \
ORIGEN_BOOTSTRAP_ADMIN_EMAIL='operator-approved@example.test' \
ORIGEN_BOOTSTRAP_VERIFIER_KEY="$(secret-tool-read bootstrap-verifier)" \
mix origen.bootstrap_admin --issued-by-ref deployment-operator

# Packaged non-production release
ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true \
ORIGEN_BOOTSTRAP_ADMIN_EMAIL='operator-approved@example.test' \
ORIGEN_BOOTSTRAP_VERIFIER_KEY="$(secret-tool-read bootstrap-verifier)" \
bin/origen_bootstrap_admin --issued-by-ref deployment-operator
```

The verifier key is accepted only through the environment/runtime secret provider. `--verifier-key` and other secret-bearing arguments are rejected. A production-compiled release denies the command even when `ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true`.

The `secret-tool-read` token is a placeholder for the deployment's secret-manager command. Avoid shell tracing and shell history. Expected output contains only account and invitation references. It must not contain a token, URL, password, TOTP value, QR payload, digest, session value, or key.

To reissue for the same pending account:

```bash
MIX_ENV=dev \
ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true \
ORIGEN_BOOTSTRAP_ADMIN_EMAIL='operator-approved@example.test' \
ORIGEN_BOOTSTRAP_VERIFIER_KEY="$(secret-tool-read bootstrap-verifier)" \
mix origen.bootstrap_admin --account-id ACCOUNT_REFERENCE --issued-by-ref deployment-operator
```

Reissue revokes every prior unconsumed invitation. It must not create another Administrator.

## Verify and disable

1. Confirm the task emitted references only and appended sanitized audit evidence.
2. Complete activation through the reviewed TLS/token-delivery path; confirm the account becomes active and replay is denied.
3. Set `ORIGEN_BOOTSTRAP_ADMIN_ENABLED=false` or remove it, restart the deployment, and verify the command reports `Bootstrap admin is disabled` before repository access.
4. Remove route exposure at ingress after activation if the environment no longer needs it. Keep history and keys required to read retained records.

## Rollback

Rollback means disabling access, not deleting history.

1. Disable `ORIGEN_BOOTSTRAP_ADMIN_ENABLED` and restart all instances.
2. Remove the activation route from ingress and stop any approved token-delivery integration.
3. Preserve `internal_accounts`, `admin_bootstrap_controls`, `internal_account_invitations`, and `audit_events`.
4. Preserve verifier/encryption keys needed to validate or decrypt retained records; restrict them through the secret manager.
5. Revert application routing/task deployment only after confirming no activation is in progress.

The migration down path refuses populated bootstrap tables. Dropping populated tables, constraints, or audit history is destructive and requires explicit maintainer and security approval plus a separately reviewed retention/migration plan.
