# Design: Deliver bootstrap invitations through a bounded email boundary

## Decision summary

Keep lifecycle and security decisions in `Origen.BootstrapAdmin`; keep Mix/release and provider callbacks as adapters; leave the activation flow in `OrigenWeb` unchanged. Add no database schema. The existing invitation row already represents every authoritative lifecycle fact needed: issuance, expiry, revocation, and consumption. Approval and provider-delivery details are validated at the boundary and represented in typed, secret-free audit events rather than mutable invitation columns.

The required sequence is:

```text
Mix or packaged command
  -> shared Gate (before parsing or I/O)
  -> validate runtime delivery configuration
  -> verify a distinct confirmer's bounded approval
  -> authorize issue/reissue
  -> issue invitation + issuance audit (transaction 1)
  -> build fragment-only link in memory
  -> provider adapter handoff (outside DB transaction)
       success -> append sanitized handoff evidence
       failure -> revoke + append revocation evidence (transaction 2)

Authenticated provider terminal-failure callback
  -> OrigenWeb verifies transport authenticity and normalizes provider reference
  -> BootstrapAdmin revokes active invitation + appends evidence (one transaction)
```

No raw token crosses back into `OrigenWeb` server-visible URLs. The existing browser-fragment exchange, nonce, clean redirect, activation session, and consume-once transaction remain unchanged.

## Boundaries and responsibilities

| Boundary | Responsibility | Must not do |
| --- | --- | --- |
| `Origen.BootstrapAdmin.Gate` | Deny absent/malformed enablement and every `:prod` build before argument parsing, configuration reads, repository access, token issuance, network access, or bootstrap-specific output. | Inspect recipient, approval, provider, or repository state. |
| Mix task / `Origen.Release` | Invoke the same gate, collect non-secret references and opaque approval input, call the domain orchestrator, print reference-only results. | Build links, call Swoosh directly, authorize by trusting CLI claims, print destination/full URL/token/provider payload. |
| `Origen.BootstrapAdmin` | Orchestrate approval, authorization, issuance, delivery, failure compensation, and sanitized audit. | Depend on Plug/Phoenix or provider-specific response structures. |
| `Origen.BootstrapAdmin.Origin` | Parse and validate the activation origin; construct no message and perform no I/O. | Accept production, HTTP, userinfo, query, fragment, unexpected path, or unapproved host. |
| `Origen.BootstrapAdmin.InvitationEmail` | Build the one token-bearing `Swoosh.Email` in process memory from a validated origin and issued invitation. | Log/inspect/store the email or expose previews. |
| `Origen.BootstrapAdmin.Provider` behaviour | Normalize provider handoff into a small provider-neutral result. | Retry ambiguously, return message content, destination, raw response bodies, or URLs. |
| concrete Swoosh adapter | Submit once through the configured transactional provider and return an approved opaque correlation reference. | Use local/test/retaining adapters outside tests. |
| `OrigenWeb` provider callback | Authenticate provider callbacks, reject replay/unknown event types, and pass only normalized terminal-failure facts to the domain. | Own revocation policy, accept a token, or log callback bodies/headers. |
| existing activation controller | Preserve fragment removal, POST exchange, in-memory nonce, clean redirect, and bounded session. | Receive the fragment in a GET/path/query or change lifecycle policy. |

This preserves the normal Origen/OrigenWeb split: web code authenticates and normalizes HTTP input; Origen decides and mutates lifecycle state.

## Two-person approval and authorization

### Representation

Use a short-lived, single-purpose signed approval assertion rather than duplicate free-form CLI flags. `Origen.BootstrapAdmin.Approval` is an in-memory value with:

- approval ID (non-secret opaque reference);
- requester reference (Samuel);
- confirmer reference;
- exact normalized destination address;
- exact environment identifier (`staging` or an approved non-production identifier);
- issued-at and expires-at;
- operation (`issue` or `reissue`);
- account reference for reissue, absent for first issue;
- cryptographic signature/key ID.

The assertion is created by the deployment approval system after the confirmer approves the exact address and environment. The command receives it from a protected runtime input (prefer a one-shot file descriptor or secret-provider mount; an environment variable is permitted only when the deployment platform proves it is not exposed in process inspection/support tooling). It is never accepted in argv.

`ApprovalVerifier` is a behaviour. Its runtime implementation verifies the signature against a verifier-only key supplied by the runtime secret provider, validates time bounds and approved key ID, then constant-time compares the assertion's normalized destination/environment/operation/account against the request. It rejects missing fields, expired/not-yet-valid assertions, production, unknown environment, Samuel as confirmer, identical requester/confirmer, and any unapproved confirmer identity. Authorization of the confirmer comes from a fail-closed configured allowlist of stable confirmer references and accepted approval signing key IDs. Possession of Administrator role does not grant this authority.

The assertion is consumed logically per attempt: its approval ID is included only as a non-secret actor/entity reference in sanitized audit and must not be reused for a fresh issue. Because no approval table is added, the deployment approval service is authoritative for assertion one-time issuance/replay control; locally, a command permits exactly one issuance call per assertion and never retries issuance. A replacement after failure requires a newly signed assertion. Staging rollout is blocked unless the external approval system can evidence distinct authenticated principals and non-reuse. If durable local replay prevention is later required, that is a separate additive-schema change.

### Authorization matrix

Add explicit operations/rules, not role inference:

- `:approve_bootstrap_invitation`, subject `{:channel, :deployment_approval}`, scope facts `distinct_principals`, `destination_matches`, `environment_matches`, `non_production`, `assertion_valid`, `confirmer_authorized`;
- retain `:bootstrap_first_administrator` (`DEP-01`) and `:reissue_internal_invitation` (`REI-01`), but require `approval_authorized: true` and the approved command/operator facts.

`BootstrapAdmin` constructs all facts from verified values. Unknown/malformed facts default-deny. Approval occurs after the shared gate and before repository access or token generation. Tests must prove self-approval, unapproved confirmer, mismatch, production, expired assertion, bad signature, reuse within one invocation, and fresh reissue without fresh approval all deny before `Verifier.issue/1`.

## Origin and link contract

`Origen.BootstrapAdmin.Origin.validate/2` accepts one configured absolute URI plus an exact host allowlist and returns an opaque validated-origin struct. It requires:

- scheme exactly `https`;
- lowercase canonical host exactly in the allowlist (no suffix/wildcard matching);
- explicit/default port 443 only unless an exact staging port is separately approved;
- no userinfo, query, or fragment;
- path exactly `/admin/activate` after normal URI parsing;
- no encoded separator, dot-segment, control character, or trailing-path ambiguity;
- environment explicitly approved and non-production.

The builder appends only:

```text
#invitation_id=<URI-encoded integer reference>&token=<URI-encoded URL-safe token>
```

It returns a `Swoosh.Email` whose recipient and text/HTML body contain the link. It does not expose a public inspectable link result; redaction tests inspect the email only inside the test process. The origin validator runs before issuance so invalid configuration cannot create a token.

## Provider capability and configuration validation

Runtime configuration is one typed map validated by `Origen.BootstrapAdmin.DeliveryConfig` before repository or network access:

- validated activation origin and exact host allowlist;
- from address;
- concrete non-retaining provider adapter (not `Swoosh.Adapters.Local`, test, mailbox preview, or an arbitrary module from user input);
- provider account/environment identifier fixed to staging;
- queue/retry encryption attestation enabled;
- explicit maximum retention TTL within the security-approved bound;
- retries either disabled for this message or provider-idempotent and bounded so the application submits once;
- access-audit capability enabled and evidence reference configured;
- callback signature key ID/secret-provider reference and replay-window policy;
- approved correlation-reference format/maximum length.

Capability flags are deployment attestations, not proof supplied by the provider at send time. Missing, malformed, contradictory, production, retaining-preview, excessive-TTL, unknown-adapter, or unaudited-access configuration fails closed before issuance. Startup may validate configuration when bootstrap is enabled, but the command revalidates it after the gate to prevent stale runtime assumptions. Credentials are resolved only inside the concrete adapter immediately before handoff and are never returned.

Provider callbacks are optional only when the provider can make handoff acceptance the terminal outcome by contract. Otherwise staging enablement requires an authenticated terminal-event integration: signature and timestamp verification over the raw body, bounded replay protection, event allowlist, and correlation-to-invitation lookup without token or destination logging. Because the current schema has no provider correlation column, the smallest design uses a deterministic non-secret correlation value containing a signed invitation reference, or provider metadata that round-trips that reference; the callback validates it before passing the integer invitation ID to Origen.

## Delivery, revocation, and audit semantics

A provider network call must not occur inside a database transaction. Issuance first commits the invitation and required issuance audit atomically. The adapter then makes exactly one handoff attempt.

### Handoff success

Return `{:ok, %{correlation_ref: ref}}` only after provider acceptance. Validate `ref` against length/character allowlists before appending a typed `invitation_delivery_handoff` success event. Audit contains invitation/account references and, when approved, correlation reference—never destination, body, URL, token, provider response, or approval values.

### Handoff or terminal failure

Call `BootstrapAdmin.revoke_delivery_failure/2`, which:

1. starts a `Repo.transaction`;
2. locks the invitation row;
3. sets `revoked_at = clock_timestamp()` only if unconsumed and unrevoked;
4. appends typed delivery-failure and revocation evidence through `Audit.Writer` in the same transaction;
5. commits both or neither.

Already consumed is a sanitized conflict requiring incident review; already revoked is idempotent success for duplicate authenticated callbacks and appends no duplicate state transition. Unknown invitation denies. Audit append failure rolls back revocation. After rollback, a best-effort separate sanitized `delivery_revocation_failed` event may be attempted, but command/callback still fails closed and raises an operational alert containing references only. The gate remains disabled and no fresh issue is permitted until operators prove revocation or expiry. This is the unavoidable compensation window between external handoff and the local transaction; the provider must cancel/purge where its contract permits, without treating purge as local revocation.

The command error says only that delivery failed, identifies account/invitation references, and instructs: verify revocation, obtain a fresh approval, then issue a fresh invitation. It must not say “retry” for the failed invitation. No code resubmits the same email/token.

## Secret lifetimes and prohibited sinks

| Secret/sensitive value | Allowed lifetime/location | Disposal |
| --- | --- | --- |
| raw invitation token/full link | Issuance process memory; email builder/provider request; provider encrypted queue until bounded TTL; delivered message; browser fragment until removed | Drop references after handoff; provider TTL/purge policy; browser replaces URL before POST. Never persist locally. |
| approval assertion/address values | Protected command input and process memory through validation/handoff | Drop after attempt; audit only approval/requester/confirmer references, never assertion body/signature/address. |
| provider credential/callback secret | Runtime secret provider and adapter/callback verification process memory | Never place in application config dumps, errors, email structs, telemetry, or fixtures. |
| verifier/signing keys | Runtime secret provider and bounded process memory | Never argv, DB, output, SQL bind, audit, or support artifact. |
| activation nonce/session | Existing in-memory/session lifetime only | Existing TTL and clean-session behavior remain authoritative. |

Prohibited sinks are CLI output, audit fields, Logger, exception messages/local-variable capture, telemetry/APM/span attributes, access logs, analytics, SQL binds, database columns, mailbox previews/test-retaining adapters outside tests, provider diagnostics/raw responses, support tickets/chat/screenshots, crash dumps, and configuration inspection endpoints. Redaction occurs before payload/event/error construction; post-hoc log filtering is defense in depth only.

## Mix and release integration

Refactor the current task so both entry points call one command module, for example `Origen.BootstrapAdmin.Command.run/2`. `Mix.Tasks.Origen.BootstrapAdmin.run/1` calls `Gate.check/0` first and only then delegates. `Origen.Release.bootstrap_admin/1` performs the same direct gate check before starting Mix, preserving the current release-overlay script.

After the gate, accepted CLI arguments are reference-only (`--account-id`, `--issued-by-ref`, and a protected approval-input reference if needed). Remove `--email`; destination comes from the verified assertion, with any independently requested value supplied through protected runtime input and compared before issuance. Secret-bearing argv remains invalid. The release keeps `mix: :permanent` because the packaged task uses Mix; no new release application is required. Runtime provider dependencies must be compiled into the release and explicitly configured for staging. Production `runtime.exs` hard-sets bootstrap false and must not load bootstrap provider credentials.

## Schema decision

**No schema change is necessary.** `internal_account_invitations.revoked_at` already makes failure revocation authoritative and immediately denies exchange/activation. Existing account/invitation identifiers and append-only audit events represent lifecycle evidence. Provider correlation, destination, approval values, message content, and token must not become mutable invitation columns; persisting them would enlarge the secret/PII boundary without helping activation correctness.

The design deliberately does not persist a `delivery_status`: provider state is not activation authority, and a mutable status risks disagreement with `revoked_at`. Successful handoff is evidence in append-only audit; failure's authoritative state is `revoked_at`. No migration, grants, or rollback DDL are introduced. If callback correlation cannot be safely round-tripped as signed metadata, or if local approval replay prevention becomes mandatory, implementation must stop and propose a separately reviewed additive, secret-free schema rather than silently adding columns.

## Interfaces and test seams

```elixir
ApprovalVerifier.verify(assertion, request, config)
  :: {:ok, Approval.t()} | {:error, safe_reason}
Origin.validate(uri, config) :: {:ok, Origin.t()} | {:error, safe_reason}
InvitationEmail.build(invitation, Approval.t(), Origin.t(), config)
  :: {:ok, Swoosh.Email.t()} | {:error, safe_reason}
Provider.deliver(email, metadata, config)
  :: {:ok, %{correlation_ref: String.t()}} | {:error, safe_reason}
BootstrapAdmin.issue_and_deliver(request, adapters)
  :: {:ok, references} | {:error, safe_reason, references | nil}
BootstrapAdmin.revoke_delivery_failure(invitation_id, safe_context)
  :: {:ok, :revoked | :already_revoked} | {:error, safe_reason}
```

Inject behaviours explicitly into the orchestrator; do not select arbitrary modules from external strings. Test doubles record call order and safe metadata and expose a guarded callback to inspect the email in-process. They must support deterministic approval clock, provider success/failure, audit failure, and callback duplication. Production adapters must not expose message inspection.

| Test layer | Required evidence |
| --- | --- |
| Unit | origin parser rejection table; approval signature/time/distinctness/match/authority; email exact fragment shape; config capability failures; safe provider-result normalization; redaction/property tests for prohibited values. |
| Domain integration | gate before every seam; authorization before Repo/token/provider; issue + audit atomicity; handoff failure revokes; audit failure rolls back revocation; duplicate terminal callback idempotence; consumed/failure race; fresh issue creates a different token and requires fresh approval. |
| Mix/release | source and packaged entry points share gate; production/disabled invokes no parser/config/Repo/provider seam; argv rejects secrets; output/error snapshots are reference-only. |
| Web regression | existing fragment exchange, fragment removal, nonce/session TTL, clean redirects, TLS, CSRF, activation and replay denial remain unchanged; callback signature/replay/body-log tests if callbacks are required. |
| Security integration | test adapter only in test; runtime rejects retaining adapters; no email/url/token in logs, audit, telemetry, exception payloads, SQL telemetry, or support fixtures. |

## Expected file changes

| Path | Action |
| --- | --- |
| `lib/origen/bootstrap_admin.ex` | Modify: expose orchestration and failure revocation. |
| `lib/origen/bootstrap_admin/{approval,approval_verifier,origin,delivery_config,invitation_email,provider}.ex` | Create: pure validation/types and provider behaviour. |
| `lib/origen/bootstrap_admin/delivery.ex`, `account.ex` | Modify: keep persistence/lifecycle in Origen; add locked revocation and authorization-before-issuance. |
| `lib/mix/tasks/origen.bootstrap_admin.ex`, `lib/origen/release.ex` | Modify: shared gate-first command path and protected approval input. |
| `lib/origen/authorization/rules.ex`, `lib/origen/audit/events.ex` | Modify: explicit approval facts/rules and typed delivery events. |
| `config/runtime.exs`, `config/test.exs` | Modify: fail-closed typed staging delivery configuration and test doubles; production remains disabled. |
| `lib/origen_web/...provider_event_controller.ex`, `router.ex` | Conditional create/modify only if provider terminal callbacks are required. |
| `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md`, `docs/security/ACTIVATION_DATA_HANDLING.md` | Modify: approval, evidence, failure recovery, secret handling, and rollback. |
| focused tests under `test/origen/bootstrap_admin/`, Mix/release tests, existing activation tests | Create/modify as described above. |

No migration file is expected. `mix.exs` changes only if the selected Swoosh provider adapter/API client is not already available; provider selection must not introduce a general delivery framework.

## Staging rollout and operational evidence

Rollout remains blocked until operators retain sanitized evidence for all checks:

1. **Configuration:** production-compiled and disabled commands stop before parsing/I/O; staging origin/host and provider capability validator pass; no production credentials are loaded.
2. **Two-person control:** deployment approval-system record shows distinct authenticated requester/confirmer, exact destination/environment, short expiry, authorized confirmer, and one approval per issuance. Retain only its non-secret reference in Origen evidence.
3. **Provider controls:** reviewed provider documentation/account settings prove encryption at rest/in transit, explicit queue/retry TTL, least-privilege access, access auditing, preview/body-capture restrictions, retry semantics, callback authentication, and purge behavior.
4. **Synthetic canary:** use a non-secret canary marker—not a real token—to search ingress, application logs, APM/traces, exception reports, SQL telemetry, provider diagnostics/previews, analytics, and support tooling. Any hit in a prohibited sink blocks rollout.
5. **Failure drill:** forced handoff failure produces no provider retry, revokes atomically with audit, denies activation, emits references only, and requires a new approval/new token. Exercise duplicate terminal callback and audit/database failure escalation.
6. **Happy path:** approved staging message has the exact fragment-only link; server-visible request/redirect URLs are clean; activation consumes once; replay denies; provider/audit evidence contains only approved references.
7. **Disablement:** after evidence, disable bootstrap and verify both source and packaged commands stop before I/O; retain audit/provider access evidence according to policy.

No real email, credential, deployment, or operational bootstrap is part of implementation verification in this change.

## Rollback

1. Set bootstrap enablement false/remove it and restart every staging instance; verify Mix and packaged commands deny before I/O.
2. Disable provider submission credentials/integration and authenticated callbacks; preserve provider audit evidence and let approved TTL/purge controls handle queued content.
3. Remove/block activation and callback routes at ingress after confirming no activation is in progress.
4. Transactionally revoke every unresolved active invitation whose delivery cannot be trusted; if revocation cannot be proved, keep all surfaces disabled until expiry and incident review.
5. Revert application/configuration changes only after retaining sanitized audit and operational evidence.
6. Preserve `internal_accounts`, `admin_bootstrap_controls`, `internal_account_invitations`, `audit_events`, and keys needed to read retained state. Do not run destructive migration rollback—this design adds none.

## Review checkpoints

- Review `Approval` and authorization rules first: they are the human-control gate before token issuance.
- Review `Origin`, `InvitationEmail`, and prohibited-sink tests second: they define the raw-token boundary.
- Review provider compensation/callback races and audit atomicity third.
- Review runtime/release configuration and staging evidence last.

Implementation must pause if provider capability facts, approval-system authenticity, callback correlation, or compensation behavior cannot satisfy these contracts without a schema or broader architecture change.
