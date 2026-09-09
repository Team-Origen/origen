schema: gentle-ai.sdd-research/v1
revision: 6
change: bootstrap-first-admin
outcome: done
selected_at: 2026-09-06

# Selected Research Request

## Confirmed Product Decisions

- `NON_PROD_ONLY`
- `DURABLE_SINGLE_ACTIVE`
- `WEB_ACTIVATION_LINK`
- `STRICT_FIELD_REDACTION`

These are retained product decisions. They are not source-backed technical claims.

## Requested Questions

1. What safe Mix-task and release environment gate fails closed in production for `NON_PROD_ONLY`?
2. What database-backed invitation lifecycle supports 24-hour expiry, consume-once behavior, and reissue invalidation for `DURABLE_SINGLE_ACTIVE`?
3. What web activation flow supports password setup and TOTP enrollment without logging secrets for `WEB_ACTIVATION_LINK`?
4. What strict audit/evidence field-redaction boundary prevents password, raw invite token, TOTP secret, recovery codes, and equivalent sensitive material from being emitted for `STRICT_FIELD_REDACTION`?

## Recovery Evidence Admission

| Requested source class | Exact declared grant | Admission |
| --- | --- | --- |
| documentation | `[documentation]` | admitted |
| open-web | `[open-web]` | admitted |

Documentation was used first. The admitted open-web class is available for the public OWASP Cheat Sheet Series URLs cited below; no lower-authority sources were required.

## Sources

| ID | Class | Title | Publisher | URL | Accessed at | Relevant evidence |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | documentation | Releases | Phoenix Framework | https://hexdocs.pm/phoenix/deployment.html#releases | 2026-09-06 | `config/runtime.exs` configures releases at runtime; runtime settings and secrets belong there rather than in the image. |
| S2 | documentation | `Phoenix.Token` token verification guidance | Phoenix Framework | https://hexdocs.pm/phoenix/Phoenix.Token.html | 2026-09-06 | `Phoenix.Token.verify/4` accepts a `max_age` option; Phoenix guidance verifies signed tokens before assigning identity. |
| S3 | documentation | `Ecto.Query.lock/3` and `Ecto.Repo` transactions | Ecto | https://hexdocs.pm/ecto/Ecto.Query.html#lock/3 | 2026-09-06 | Ecto supports row-level lock expressions such as `FOR UPDATE`; `Ecto.Multi` operations execute transactionally through the repo. |
| S4 | documentation | `Ecto.Changeset.optimistic_lock/3` and `unique_constraint/3` | Ecto | https://hexdocs.pm/ecto/Ecto.Changeset.html | 2026-09-06 | Ecto supports optimistic-lock stale-write detection and translating database unique-constraint violations into changeset errors. |
| S5 | open-web | Forgot Password Cheat Sheet: General Security Practices | OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html | 2026-09-06 | Reset-like tokens must use a CSPRNG, be sufficiently long, be linked to a user, be securely stored, and be invalidated after use. |
| S6 | open-web | Multifactor Authentication Cheat Sheet: Software OTP Tokens | OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html | 2026-09-06 | TOTP authenticator apps receive their seed by QR scan; software tokens introduce device and backup-seed risks. |
| S7 | open-web | Logging Cheat Sheet: Data to exclude | OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | 2026-09-06 | Passwords, session IDs, access tokens, and encryption keys generally must not be recorded directly; remove, mask, sanitize, hash, or encrypt them instead. |
| S8 | open-web | Email Validation and Verification in Identity Systems Cheat Sheet: Logging and Monitoring | OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/cheatsheets/Email_Validation_and_Verification_Cheat_Sheet.html | 2026-09-06 | Do not log sensitive tokens or full verification URLs; treat addresses in logs as sensitive and restrict access. |
| S9 | open-web | Authentication Cheat Sheet: Transport Layer Security | OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html | 2026-09-06 | Passwords and authenticated pages must be transmitted only over TLS or equivalent strong transport. |
| S10 | open-web | Password Storage Cheat Sheet | OWASP Cheat Sheet Series | https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html | 2026-09-06 | Passwords must not be stored plaintext; use a strong slow password hash such as Argon2id, bcrypt, or PBKDF2 with a unique salt. |

## Validated Claims

1. **Fail-closed Mix/release gate** — Phoenix releases obtain runtime configuration from `config/runtime.exs` (S1). The bootstrap service MUST have one runtime boolean configuration value, defaulting to `false`; `:prod` MUST not set it to `true`. Its public entry point MUST reject unless the value is explicitly `true` **and** the compiled Mix environment is not `:prod` when a Mix task is used. The release invocation path MUST call that same service gate, rather than duplicating an environment check. This gives `NON_PROD_ONLY` two independent denial conditions and remains closed when the setting is absent, malformed, or the release path differs. Applicability: the repository already runs `runtime.exs` in releases and currently has a `:prod` branch there. Limitation: a release does not itself establish the operator's deployment classification; infrastructure must correctly retain the default-disabled value in production. Sources: S1.
2. **Durable 24-hour, one-time invitation** — Reset-like bearer tokens must be CSPRNG-generated, bound to an individual record, securely stored, and invalidated after use (S5). Persist each issue as an immutable invitation row containing only a token verifier/digest, target account reference, `issued_at`, `expires_at = issued_at + 24 hours`, `consumed_at`, `revoked_at`, and non-secret issuer/audit correlation references. Never persist the raw token. The activation transaction MUST lock the invitation row, reject a revoked, expired, or already-consumed row, and set `consumed_at` before creating credentials. Ecto supports transaction composition and database row locks for this serialization (S3). Applicability: PostgreSQL and Ecto are declared project dependencies. Limitation: the exact invitation verifier/digest construction remains a design decision; TOTP seed protection uses the separately approved Candidate Bundle A.
3. **Reissue invalidation under `DURABLE_SINGLE_ACTIVE`** — Reissue MUST run in one database transaction: lock a stable parent row (the pending account), revoke every prior unconsumed invitation for that account, insert the replacement invitation, and append non-secret audit evidence. A database constraint/index MUST enforce at most one unconsumed invitation per target, while the transaction transitions any expired predecessor to revoked before inserting a replacement. Row-level locks and transactions prevent concurrent reissues or consume/reissue races from both succeeding (S3); Ecto can surface database uniqueness failures and stale writes (S4). Applicability: this preserves invitation history instead of overwriting it. Limitation: a time-dependent partial unique index cannot itself decide that `expires_at <= now()` is inactive; expiry remains a transaction-time predicate and requires tests for concurrent timing boundaries.
4. **Invitation-bound web activation and TOTP** — Verify the invitation only on a TLS-protected activation exchange, then establish a short-lived pre-activation server session bound to that invitation/account and redirect to a clean URL before password and TOTP forms render. Phoenix supports bounded token verification through `max_age` (S2), and OWASP requires strong transport for password-bearing pages (S9). Generate the TOTP seed only for this enrollment, render its QR code once, require a valid TOTP code before persisting the factor, and never include the seed or QR payload in audit/log/error data. TOTP authenticator apps are QR-seeded and carry device/backup-seed risks (S6). Hash the chosen password with a password-specific slow hash; do not store plaintext (S10). Applicability: the current browser pipeline already enables CSRF protection and secure browser headers. Limitation: no TOTP/password library is currently present in `mix.exs`; its storage encryption, recovery-code policy, and session implementation require a later technical design.
5. **Strict audit/evidence redaction boundary** — Authentication secrets must be excluded before an audit event, application log, error report, telemetry attribute, or email-delivery diagnostic is constructed. OWASP specifically identifies passwords, session IDs, access tokens, and encryption keys as data that should not be directly logged (S7), and forbids logging verification tokens or full verification URLs (S8). Under `STRICT_FIELD_REDACTION`, allowlist audit fields to event type, result, actor kind/reference, target account identifier, invitation record identifier, and timestamps; reject or replace named sensitive fields (`password`, confirmation, raw token, activation URL, TOTP seed, OTP code, QR payload, recovery code, session/cookie value, digest/key) before any sink. Applicability: the current `Origen.Audit.Events` model has no arbitrary metadata field, so preserve that typed/allowlisted shape and use only non-secret account/invitation identifiers as references. Limitation: application-level redaction cannot protect infrastructure that logs request URLs or bodies before Phoenix; ingress/proxy/APM configuration must apply the same exclusion policy.

## Applicability and Limitations

- The guidance applies to the declared Phoenix 1.8/Ecto/PostgreSQL stack and the existing runtime configuration, browser router, and typed append-only audit boundary.
- `Phoenix.Token` can impose a signed-token maximum age (S2), but it cannot by itself prove one-time use or reissue invalidation. Durable state remains mandatory for the selected decision.
- A token in either a path or query parameter can be recorded by a reverse proxy or APM. Prefer a fragment-delivered token exchanged by `POST`, or prove equivalent ingress redaction before accepting a route-carried bearer token. The fragment approach requires a deliberately designed client bootstrap because the server does not receive URL fragments.
- The current audit schema is favorable because it is structured and lacks a free-form payload, but code must prevent token-like strings from becoming `actor_ref` or `entity_ref`.
- Freshness: sources were accessed on 2026-09-06. No material contradiction was found. OWASP uses reset/verification flows as analogous bearer-token guidance; its token lifecycle requirements apply to invitations, but it is not Phoenix-specific.

## Unresolved Technical Risks

1. Validate the approved dependency set against the resolved graph and the native Make toolchain; neither is proven until `mix deps.get` and compilation succeed.
2. Define the invitation verifier/digest algorithm and its rotation/secret-management lifecycle without retaining raw invitation tokens.
3. Verify production ingress, proxy, APM, mailer, and exception-reporting configurations redact URL paths, request bodies, and headers before the web link is enabled.
4. Specify how a release operator invokes the shared gate without shipping a bypass path, and test production-default denial in the release artifact.

---

# Additional Research Lane: Credential, TOTP, and Seed-Encryption Options

## Selected Intent

Evaluate current, maintained Elixir-compatible options for:

1. Argon2id password hashing with PHC-format storage.
2. RFC 6238 TOTP generation and verification compatible with the declared Phoenix/Elixir runtime.
3. Authenticated encryption for a persisted TOTP seed, including runtime key versioning and rotation.

The lane must compare maintenance, compatibility, API fit, security limitations, licensing, and operational tradeoffs, then identify up to three integrated bundles only where authoritative evidence supports them.

## Evidence Admission

| Requested source class | Runtime grant used for this recovery | Admission |
| --- | --- | --- |
| documentation | `[]` | no runtime collection performed |
| open-web | `[]` | no runtime collection performed |

This bounded recovery imported only the immutable official-source records supplied by the orchestrator and user. It performed no external discovery, browsing, package installation, dependency resolution, or compilation. The supplied records are evaluated below; the empty runtime grants are not treated as source-access grants.

## Sources

| ID | Class | Title | Publisher | URL | Accessed at | Relevant evidence |
| --- | --- | --- | --- | --- | --- | --- |
| S11 | documentation | NimbleTOTP README and API | Dashbit | https://github.com/dashbitco/nimble_totp | 2026-09-06 | Documents `{:nimble_totp, "~> 1.0"}`, CSPRNG secret generation, OTPAuth URI generation, and code validation including a `since` option that rejects prior periods. |
| S12 | documentation | Cloak AES-GCM and Vault documentation | Cloak project | https://github.com/danielberkompas/cloak | 2026-09-06 | Documents authenticated AES-GCM encryption with random IVs and ciphertext authentication, runtime Vault configuration, tagged cipher versions, and default-plus-retired-key rotation. |
| S13 | documentation | Cloak Ecto runtime configuration and key rotation guide | Cloak project | https://github.com/danielberkompas/cloak_ecto | 2026-09-06 | Documents runtime Vault initialization, supervised vault startup, Ecto field integration, and a migration workflow that re-encrypts retired-key ciphertext. |
| S14 | documentation | `argon2_elixir` package record | Hex | https://hex.pm/packages/argon2_elixir | 2026-09-06 (supplied capture) | Version `4.1.3`, updated `2025-04-27`, Apache-2.0, Mix plus Make build, and described as Argon2 password hashing for Elixir. |
| S15 | documentation | `Argon2` API | argon2_elixir HexDocs | https://argon2-elixir.hexdocs.pm/Argon2.html | 2026-09-06 (supplied capture) | Argon2id is the default; `hash_pwd_salt/2` uses a random salt; `verify_pass/2` verifies a PHC hash. |
| S16 | documentation | `nimble_totp` package record | Hex | https://hex.pm/packages/nimble_totp | 2026-09-06 (supplied capture) | Version `1.0.0`, Apache-2.0, Mix build, updated `2023-03-21`. |
| S17 | documentation | `cloak` package record | Hex | https://hex.pm/packages/cloak | 2026-09-06 (supplied capture) | Version `1.1.4`, MIT, Mix build, updated `2024-04-06`. |
| S18 | documentation | `cloak_ecto` package record | Hex | https://hex.pm/packages/cloak_ecto | 2026-09-06 (supplied capture) | Version `1.3.0`, MIT, Mix build, updated `2024-04-06`. |

S14–S18 are supplied evidence imports, not newly collected runtime documentation. S11–S13 retain the previously captured API and operational evidence referenced by this lane.

## Validated Claims

1. **TOTP candidate evidence** — NimbleTOTP provides a documented dependency declaration, cryptographically secure secret generation, OTPAuth provisioning URI generation, and validation. Its documented `since` input can reject an already-used time period; use it only with a persisted last-accepted period and a transaction/lock if replay resistance is required across concurrent requests. Source: S11.
2. **Authenticated seed-encryption candidate evidence** — Cloak documents AES-GCM authenticated encryption, random IV generation, ciphertext authentication, and cipher tags. Its Vault configuration accepts runtime-loaded keys and can retain a retired tagged cipher for decryption while the default tagged cipher encrypts new values. Sources: S12, S13.
3. **Rotation operational evidence** — Cloak Ecto documents an explicit re-encryption migration after introducing a new default cipher and retaining the old cipher for reads. A runtime key version can therefore be represented by the authenticated ciphertext's cipher tag; operations must retain each retired key until every corresponding ciphertext has been re-encrypted and verified. Sources: S12, S13.
4. **Repository fit, limited to local evidence** — The repository currently resolves Phoenix 1.8.13 and Ecto 3.14.0, declares Elixir `~> 1.17`, and its SDD context records CI on Elixir 1.20.3. It has no password-hashing, TOTP, Cloak, or Cloak Ecto direct dependency. This describes the integration surface only; it does not establish any candidate package's compatibility. Local evidence: `mix.exs`, `mix.lock`, and `openspec/config.yaml`.
5. **Argon2id password-hashing candidate evidence** — `argon2_elixir` version `4.1.3` is an Apache-2.0 package, updated `2025-04-27`, with a Mix plus Make build. Its documented default is Argon2id; `hash_pwd_salt/2` uses a random salt, and `verify_pass/2` verifies a PHC hash. This closes the previously missing package identity, release, license, build, and API facts needed to evaluate a candidate. Sources: S14, S15.
6. **Package metadata for the existing TOTP and encryption candidates** — NimbleTOTP `1.0.0` is Apache-2.0; Cloak `1.1.4` and Cloak Ecto `1.3.0` are MIT. The supplied Hex records establish their listed releases, build systems, and update dates, while S11–S13 establish their relevant APIs and rotation workflow. Sources: S11–S13, S16–S18.

## Bundled Options

### Approved Candidate Bundle A — Argon2id, TOTP, and encrypted seed storage

- **Password hashing**: `{:argon2_elixir, "~> 4.1.3"}`. Store only the resulting password-hash representation; use the documented Argon2id default and random-salt `hash_pwd_salt/2`, and use `verify_pass/2` for PHC-hash verification.
- **TOTP**: `{:nimble_totp, "~> 1.0.0"}`. Generate the seed with the documented CSPRNG API, provision through the OTPAuth URI, and persist replay state so the documented `since` control is combined with a transaction/lock for concurrent replay resistance.
- **Persisted seed encryption**: `{:cloak, "~> 1.1.4"}` and `{:cloak_ecto, "~> 1.3.0"}`. Use a runtime-initialized, supervised Vault and authenticated AES-GCM ciphertext with tagged cipher versions.
- **Runtime secret source**: Use a vendor-neutral deployment runtime secret provider. The deployment owner selects the provider; no cloud vendor, vault product, environment-variable format, key encoding, or rotation interval is prescribed.
- **Tagged keyring semantics**: Exactly one active, uniquely tagged key encrypts new seed values. Zero or more uniquely tagged retired keys are decrypt-only and remain available for reads of their existing ciphertext. Startup must fail closed for missing, malformed, duplicate-tag, or unknown-tag key material.
- **Retirement control**: Introduce a new active tag, retain prior tags as retired, run controlled re-encryption for ciphertext under each retired tag, verify that the migration and reads succeed, and only then retire the corresponding deployment secret. A key MUST NOT be retired based only on deployment completion.
- **Fit and limits**: The bundle fits the proposed `Origen.BootstrapAdmin.Credentials` seam and keeps secret material out of audit/log/error sinks. Its compatibility with this repository's resolved dependency graph and native build toolchain remains unproven until the approved dependencies pass `mix deps.get` and compilation.

## Recommendation

**Decision: Candidate Bundle A is explicitly approved.** The approved decision covers the four exact dependency declarations, a vendor-neutral deployment runtime secret provider, the active/retired tagged-keyring semantics, and controlled re-encryption plus read verification before key retirement. Dependency installation, resolution, and compilation remain follow-up implementation work; compatibility and native-build readiness are not proven by this approval.

## Contradictions, Uncertainty, and Freshness

- **Contradictions**: None in the consulted documentation.
- **Uncertainty**: Exact Elixir/Phoenix/Ecto transitive compatibility, native Make-toolchain availability, resolved transitive dependency graph, deployment secret-provider implementation, key encoding, and rotation interval remain unvalidated. The supplied package update dates are package-record metadata, not a maintainer-activity guarantee.
- **Freshness**: S11–S13 were previously captured on 2026-09-06; S14–S18 were supplied for this recovery on 2026-09-06. Revalidate package releases, advisories, and resolved compatibility immediately before dependency lock updates.

## Retained Product Decisions

- `NON_PROD_ONLY`
- `DURABLE_SINGLE_ACTIVE`
- `WEB_ACTIVATION_LINK`
- `STRICT_FIELD_REDACTION`

These confirmed product decisions remain unchanged. They are not source-backed technical dependency or key-management selections.

## Outcome and Recovery

**Outcome**: done.

The supplied Argon2 records cover the prior missing Argon2id package, license, release/update, Mix plus Make build, default algorithm, random-salt, and PHC-verification facts. The selected research lane is therefore evidence-complete. Candidate Bundle A is approved; no dependency was installed, resolved, or compiled by this approval record.

**Required follow-up**: implementation may add the approved declarations and keyring configuration, then validate them with `mix deps.get` and compilation. Compatibility with the resolved dependency graph and native Make toolchain remains unproven until those checks pass. Retire a tagged key only after controlled re-encryption and successful reads verify that no ciphertext still requires it.
