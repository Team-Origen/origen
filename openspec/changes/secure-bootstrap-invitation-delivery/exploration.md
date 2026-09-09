# Exploration: Secure Bootstrap Invitation Delivery

## Goal

Complete the real Samuel-to-Santiago first-administrator acceptance journey by delivering the activation token through an approved boundary without leaking it to CLI output, audit, logs, URL paths/queries, APM, or persistent application storage.

## Existing Capabilities

- Invitation creation returns a 256-bit URL-safe token and persists only a keyed HMAC verifier.
- Mix and packaged-release commands read the verifier key from the environment, reject secret-bearing argv, and print only account/invitation references.
- Swoosh delivery exists, but the current email deliberately contains references only.
- Activation accepts `#invitation_id=…&token=…`, removes the fragment before POST, exchanges it for a short-lived in-memory nonce, and redirects to a clean URL.
- TLS checks, CSRF, `no-store`, `no-referrer`, bounded session TTL, encrypted TOTP persistence, password hashing, replay denial, and parameter filtering already exist.
- Tests cover token-free output, invalid delivery recovery, fragment exchange, clean redirects, TLS, CSRF, activation, replay, and input redaction.

## Exact Gap

Samuel's command creates the raw invitation token, but no approved delivery boundary sends it to Santiago. The token is discarded after reference-only email construction, so Santiago cannot begin activation.

`config/test.exs` defines `:bootstrap_admin_activation_url`, but runtime configuration and email construction do not use it.

## Likely Edit Surfaces

- `lib/mix/tasks/origen.bootstrap_admin.ex`
- A dedicated invitation email/link builder or delivery adapter under `lib/origen/bootstrap_admin/`
- `config/runtime.exs`
- `config/test.exs`
- Bootstrap task, release, and activation integration tests
- `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md`
- `docs/security/ACTIVATION_DATA_HANDLING.md`

## Security Boundary

The raw token may exist transiently only in process memory, the approved delivery channel, and Santiago's browser fragment. It must not enter CLI output, audit events, exceptions, URL path/query, redirects, database columns, telemetry, APM, access logs, analytics, SQL binds, or support artifacts.

The activation link should retain this shape:

```text
https://approved-host/admin/activate#invitation_id=<reference>&token=<secret>
```

The activation origin must be HTTPS and reject unexpected hosts, userinfo, query strings, and pre-existing fragments. Development mailbox previews and retaining adapters are not acceptable for a real-token acceptance journey.

## Unresolved Decisions

1. Approved delivery channel: reviewed token-bearing transactional email or a separate one-time secret channel.
2. Acceptable provider-side queue/retry retention.
3. How Samuel verifies Santiago's destination address before issuance.
4. Authoritative staging activation origin and host allowlist.
5. Failure semantics: revoke immediately, retain for explicit reissue, or bounded retry of the same token.
6. Confirmation that the acceptance journey remains non-production.
7. Required ingress/APM/mail-provider evidence for operational approval.

## Review Workload

Risk is medium-high. The change crosses URL validation, delivery, runtime configuration, failure semantics, security tests, and runbooks. Under the 800-line budget and feature-branch-chain strategy, likely slices are:

1. URL/config validation and token-bearing email construction.
2. Command/release delivery and failure semantics.
3. Runtime/provider integration, security regression tests, and operational evidence.

## Outcome

Exploration is complete. Product and security decisions above must be confirmed before proposal. Research remains unselected.
