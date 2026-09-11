# Design: Secure Local Bootstrap Profile

## Decision summary

Implement the local path as a separately named profile behind the existing source-checkout Mix command. The command continues to perform the shared gate first, then dispatches from trusted application configuration to either the unchanged staging command path or a new local command path. A caller cannot select the profile in argv. The packaged-release entry point passes an explicit `:packaged_release` channel and can never enter the local path.

The local path has its own eligibility, readiness, destination, origin, authorization, message, and mailbox-handoff modules. It reuses `Account.issue_first/1`, `Account.reissue_first/2`, verifier-only invitation persistence, `Delivery.revoke_delivery_failure/2`, activation, credentials, and typed audit primitives. It does not call or modify staging `DeliveryConfig`, `Provider`, `ApprovalVerifier`, or `Origin`. The activation controller's `require_tls/1` behavior remains byte-for-byte unchanged; only its verifier/TOTP secret lookup may be delegated to a common secret accessor.

No schema or migration is added. One workstation process hosts the local HTTPS endpoint, mailbox, command, and activation flow so a Swoosh in-memory message cannot disappear into a short-lived command VM or become a disk artifact.

```text
source-checkout Mix task
  -> existing Gate.check/0                         (before argv/config beyond the gate)
  -> trusted profile dispatch
       staging -> existing Command behavior
       local
         -> LocalEligibility                       (exact compiled :dev, second exact gate,
                                                    trusted :local profile, source channel)
         -> parse local reference-only argv
         -> LocalReadiness.inspect                  (aggregate safe findings; no Repo/mailbox/
                                                    verifier or TOTP secret fetch)
         -> start the same local OTP application/HTTPS endpoint
         -> inspect isolated DB and recovery target (reads only)
         -> LocalAuthorization                      (exact facts; default deny)
         -> LocalSecrets.fetch_and_cache            (first protected-content access)
         -> Account.issue_first or reissue_first    (existing serialized transaction)
         -> LocalInvitationEmail                    (fragment link in memory)
         -> LocalMailbox.handoff                    (one bounded in-memory message)
              success -> typed reference-only handoff audit; await activation/TTL
              failure/uncertainty -> existing transactional revocation; return safe refs
```

## Architecture and module boundaries

| Boundary | Responsibility | Explicit exclusions |
| --- | --- | --- |
| `Mix.Tasks.Origen.BootstrapAdmin` | Invoke `Gate.check/0` before inspecting argv, mark invocation as `:source_checkout`, print only existing safe references, and keep the local VM alive while its mailbox is usable. | Does not select a profile from argv, inspect local configuration before the shared gate, build a message, or retrieve secrets. |
| `Origen.Release` | Continue invoking the shared gate and command with channel `:packaged_release`. | Never starts, dispatches to, or waits for a local mailbox, even when copied configuration says `:local` and both booleans are true. |
| `Origen.BootstrapAdmin.Command` | Dispatch on the atom in trusted application configuration after the shared gate. Preserve current staging parsing/orchestration as its staging branch. | No `--profile`, module name, adapter, destination, origin, key, token, TOTP, or URL switch; no fallback after either branch denies. |
| `Origen.BootstrapAdmin.LocalEligibility` | Recheck the shared gate defensively and require `@compiled_env == :dev`, local gate `=== true`, trusted profile `=== :local`, and channel `=== :source_checkout`. | No injected environment/channel in a runtime entry point and no Repo, mailbox, endpoint start, parser, or secret access. |
| `Origen.BootstrapAdmin.LocalReadiness` | Purely validate all ordinary configuration and make non-content metadata probes for protected files; return a typed ready value or all safe finding atoms. | Does not short-circuit, read secret file contents, start the application, query Repo, inspect mailbox messages, issue a token, or return offending values. |
| `LocalDestination` | Validate and canonicalize the one trusted synthetic address once, returning an opaque struct used by authorization and email construction. | No suffix/pattern allow, IDNA conversion, Unicode normalization, silent lowercasing, or caller value. |
| `LocalOrigin` | Validate the exact local activation URI against the exact HTTPS endpoint tuple and return an opaque struct. | Does not call or relax staging `Origin`; no hostname lookup, wildcard, HTTP, IPv6, alternate port/path, query, userinfo, or fragment. |
| `LocalTarget` | After readiness and application startup, establish safe database-isolation and first-admin/recovery facts with read-only queries. | Does not mutate an account/invitation or infer isolation merely from a user argument. |
| `LocalAuthorization` plus `Authorization.Rules` | Construct and evaluate exact local facts for initial issue or narrowly bounded recovery reissue. | No staging confirmer, approval assertion, deployment channel, deployment-approved fact, or cross-profile fallback. |
| `LocalSecrets` / `BootstrapSecrets` | Probe file metadata without content access, then fetch/decode/cache verifier and TOTP keys only after authorization; serve the same values to activation. | No keys in application dumps, argv, result tuples, logs, audit, telemetry, SQL, or exception messages. |
| `LocalInvitationEmail` | Build the local-specific `Swoosh.Email` from only typed destination/origin and transient invitation data. | Does not reuse staging wording or require an `Approval`; never logs or returns a standalone full URL. |
| `LocalMailbox` | Serialize Swoosh Local handoff, enforce one token-bearing message, arrange deletion before acknowledging success, clear on restart, and revoke when retention expires or handoff is uncertain. | Does not pass through staging `Provider`, persist a body, retry, expose a remote interface, or return email/destination/URL content. |
| existing lifecycle modules | `Account` serializes issue/reissue; `Delivery` persists only the verifier and handles audited revocation; activation remains consume-once with password/TOTP controls. | No local schema branch and no second Administrator. |

`Local*` above means modules under `Origen.BootstrapAdmin.Local`, for example `Origen.BootstrapAdmin.Local.Readiness`. Names should remain local-specific rather than adding `environment == "local"` cases to staging modules.

## Trusted configuration and dispatch

Add ordinary defaults in `config/config.exs`:

```elixir
config :origen,
  bootstrap_admin_profile: :staging,
  bootstrap_admin_local_enabled: false,
  bootstrap_admin_local: %{enabled: false}
```

The local profile is configured only by ignored `config/dev.local.exs`. It contains fixed atoms/modules and non-secret references, not executable module names from environment variables. The shared gate may retain its existing explicit runtime enablement, while the independent local gate and `:local` selector come from the ignored development configuration. Production runtime configuration hard-sets the local gate false and profile away from local in addition to the current staging disablement. Unknown selectors deny; they do not default to staging.

The trusted local map contains exactly these classes of data:

- `enabled: true` matching the separate gate;
- `destination: <one binary>`;
- `activation_origin: "https://127.0.0.1:<port>/admin/activate"`;
- `endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: <same port>, http: false}`;
- exact mailer/adapter/storage/preview modules fixed to the reviewed Swoosh Local stack;
- `retention_ttl_seconds` and `max_messages: 1`;
- local certificate/key paths and verifier/TOTP key-file references;
- a non-secret TOTP key tag;
- `database_name` plus `database_scope: :isolated_workstation`.

The runtime does not accept a local enablement, profile, module, destination, origin, or key path from command argv. Environment variables cannot name a module. The only local argv shape is no options for initial issue or one positive `--account-id` for recovery reissue. Every existing and future secret-bearing or delivery-bearing switch remains invalid. `--account-id` is a non-secret target reference and is checked against the sole pending Administrator; it grants nothing by itself.

### Entry-point ordering

1. Mix and release entry points call the existing `Gate.check/0` directly.
2. Only after it succeeds does `Command` read the trusted profile selector.
3. For `:local`, `LocalEligibility.check/1` requires the second exact boolean, compiled `:dev`, trusted local selector, and source-checkout channel before parsing argv.
4. For `:staging`, the current parser, protected approval reader, and orchestrator remain the branch behavior.
5. A denial returns from the selected branch. It never tries the other profile.

Use a module attribute derived from `Mix.env()` for the compiled environment. The actual `check/1` does not accept an injected environment. A separate pure `evaluate/1` supports table tests, while the runtime entry point always supplies its compile-time value and its internally assigned channel.

## Complete aggregate readiness

`LocalReadiness.inspect/2` evaluates every check and accumulates a deterministic, sorted, duplicate-free list of atoms. It returns `{:ok, %Ready{...}}` only when the list is empty, otherwise `{:error, {:local_not_ready, findings}}`. `%Ready{}` contains typed destination/origin values and non-secret references; implement a redacted `Inspect` protocol so accidental inspection cannot reveal destination, paths, or endpoint values.

Allowed finding codes are fixed at compile time, for example:

```text
:profile_invalid                 :command_channel_invalid
:endpoint_https_invalid          :endpoint_http_enabled
:endpoint_not_ipv4_loopback      :endpoint_port_mismatch
:activation_origin_invalid       :certificate_source_unavailable
:mailbox_adapter_invalid         :mailbox_preview_unavailable
:mailbox_retention_invalid       :destination_invalid
:verifier_source_unavailable     :totp_source_unavailable
:database_isolation_unconfigured
```

No finding includes a configured value, destination, path, URL, exception, key, or message. Probe exceptions normalize to the relevant code before an error tuple is constructed.

Readiness uses independent validators rather than a `with` chain. It validates:

- the already-established trusted selector/channel facts again as defense in depth;
- exact endpoint HTTPS tuple, absence/disablement of HTTP, exact IPv4 loopback binding, and a single shared port;
- exact local origin and activation path;
- certificate/key references as regular non-symlink files with owner-only permissions and bounded non-zero size;
- exact reviewed `Origen.Mailer`, `Swoosh.Adapters.Local`, in-memory storage, mailbox preview, and retention-owner module identities;
- retention TTL as an integer from 1 through the compiled maximum of 900 seconds and `max_messages === 1`;
- exactly one destination binary, represented by one scalar rather than a list;
- verifier/TOTP source metadata and TOTP tag shape;
- a syntactically safe expected development database name and exact `:isolated_workstation` declaration.

### Protected-source availability without value access

Local key configuration points to owner-only files; it does not embed keys in `dev.local.exs`. `LocalSecrets.probe/1` uses `lstat` only. A source is available only when it is a regular file, is not a symlink, is owned by the current user, has no group/world permission bits, and has a bounded non-zero size. This proves an eligible source exists without reading its bytes. A source type that cannot provide this metadata contract is not accepted.

After readiness, runtime startup, target inspection, and authorization, `LocalSecrets.fetch_and_cache/1` opens the same path without following a replacement symlink, rechecks metadata, reads bounded content once, decodes it, validates the verifier key and TOTP keyring through existing primitive validators, and stores them only in the local VM's supervised in-memory cache. Any time-of-check/time-of-use change or malformed content returns one generic safe configuration failure before issuance. The activation secret accessor uses that cache while profile `:local` is active; staging retains its current application-environment lookup semantics. Cache contents are removed on activation completion, retention expiry, command shutdown, or process restart.

## Exact destination canonicalization

`LocalDestination.parse/1` is the sole canonicalization point. The input must:

- be valid UTF-8 but contain ASCII bytes only;
- already equal its lowercase form and trimmed form (the validator never repairs it);
- contain no whitespace, control byte, CR/LF, quote, angle bracket, backslash, colon, comma, or display-name/header syntax;
- split into exactly one local part and the exact domain `example.test`;
- have a local part of 1–64 bytes matching a deliberately narrow grammar such as `\A[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?\z`, with no empty/consecutive dot segment;
- remain within normal address length limits.

The result is `%LocalDestination{address: address}` with a redacted `Inspect`. Authorization receives only an internally computed boolean that the typed destination is the configured destination; message construction receives the struct itself. Neither reparses or normalizes it. There is no suffix comparison, IDNA conversion, Unicode normalization, list membership supplied by a caller, or second destination.

## Exact HTTPS loopback and mailbox contract

`LocalOrigin.validate/2` constructs the only expected raw string from the validated endpoint port:

```text
https://127.0.0.1:<decimal-port>/admin/activate
```

The configured value must equal that string byte-for-byte and also parse to scheme `https`, host `127.0.0.1`, the explicit same port, and path `/admin/activate`, with nil userinfo/query/fragment. The validator rejects default/omitted ports, `localhost`, IPv6 loopback, DNS names, wildcard/unspecified/private/public addresses, percent encoding, backslashes, controls, trailing slash, and extra path. Endpoint configuration must have HTTP absent/false and HTTPS bound to exactly `{127, 0, 0, 1}` on the same port. Phoenix/Bandit startup failure is normalized and occurs before target mutation or token issuance.

The existing `/dev/mailbox` route remains the reviewed mailbox UI. Because the endpoint has no HTTP listener and only the exact loopback HTTPS listener, the token-bearing mailbox cannot be reached through an alternate interface. `dev_routes` and the preview route remain compile-time development facilities; production builds do not compile the route. Readiness requires their exact expected values and does not perform a DNS lookup.

### Bounded retention implementation

`LocalMailbox` is a supervised coordinator around the reviewed Swoosh Local in-memory storage, not a staging provider. It owns all bootstrap mailbox operations while the profile command is active:

1. On initialization/restart it clears the in-memory mailbox before accepting a handoff. BEAM termination also destroys the storage.
2. Before issue authorization it purges expired entries and requires no non-expired token-bearing entry. A retained entry blocks another issue rather than being overwritten.
3. Handoff executes in one serialized call: clear stale storage, submit exactly once through `Origen.Mailer` configured with `Swoosh.Adapters.Local`, confirm the stored message identifier, install its expiry timer, and only then return `{:ok, %{correlation_ref: safe_ref}}`.
4. The store is dedicated to this local bootstrap session and contains at most one message. The compiled TTL ceiling is 900 seconds; configured TTL may be shorter but never longer.
5. Timer expiry first makes the message unavailable, then invokes the existing audited revocation primitive for an unresolved invitation. Consumption wins safely under the existing row lock. If revocation cannot be proved, the command reports only references, keeps fresh issue disabled for that running session, and exits fail-closed.
6. If the coordinator crashes after storage but before acknowledgement, supervisor restart clears storage. The caller treats the lost acknowledgement as uncertain and revokes. No code retries the email/token.
7. On successful activation, explicit rollback, or command shutdown, the coordinator clears storage and the secret cache. A new command VM begins from an empty memory store.

Implementation must pin the Swoosh storage calls behind a small internal `MailboxStore` behaviour and verify the APIs provided by the locked Swoosh version. The runtime adapter is a fixed module, while tests inject an in-memory fake clock/store. If the locked Swoosh API cannot atomically identify and delete the submitted message or clear on coordinator restart, implementation must provide a dedicated bounded in-memory store compatible with the mailbox preview before enabling the profile; falling back to unbounded built-in storage is not allowed.

The command and endpoint must live in the same BEAM. After a successful handoff, the Mix task prints only account/invitation/mailbox correlation references and waits while the endpoint/mailbox is active. It exits after activation, revocation/retention expiry, or operator termination, applying cleanup. Running a short-lived mail-producing Mix VM alongside a separate `phx.server` is explicitly unsupported because their in-memory mailboxes are different.

## Local authorization facts

Add exact local subjects and operations; do not reuse deployment subjects:

- initial rule `:loc_01`: operation `:bootstrap_local_first_administrator`, subject `{:channel, :local_source_checkout}`;
- recovery rule `:loc_02`: operation `:reissue_local_first_administrator`, same subject, only for the sole pending account after a revoked or uncertain local mailbox handoff.

Initial target facts are exact:

```elixir
%{
  role: :administrator,
  state: :absent,
  administrator_exists: false,
  isolated_database: true
}
```

Recovery target facts are exact:

```elixir
%{
  role: :administrator,
  state: :pending_activation,
  sole_administrator: true,
  account_matches: true,
  prior_handoff: :revoked_or_uncertain,
  active_administrator_exists: false,
  isolated_database: true
}
```

Both rules require an exact scope map with compiled environment `:dev`, both exact gates, trusted profile `:local`, complete readiness, exact typed destination, source-checkout channel, and the requested operation/target. Initial mode calls `Account.issue_first/1`. Recovery requires a positive account reference matching the sole pending Administrator and calls `Account.reissue_first/2`; that existing transaction revokes every predecessor before creating one fresh verifier/token. An active account, multiple/mismatched account, consumed predecessor, still-retained mailbox message, shared/unverified database, or any other pending state denies.

`Authorization.Rules` currently compares required map keys with `Map.take/2`, which can allow extra facts. Preserve existing rule behavior, but add an exact-map match form for the two local rules so missing and additional/over-broad facts both deny. The local request builder is internal and always fills all five authorization dimensions.

Database isolation is established after readiness from both trusted local configuration and read-only database facts: the configured database scope must be exact, `current_database()` must equal the configured safe development database name, the database connection must be local (IPv4 loopback or the explicitly accepted local Unix socket), and target queries must prove the account state. These checks are operational evidence of workstation isolation, not a schema-level tenancy claim. Four students therefore use four independent databases; no rule permits four accounts in one database.

No local request contains an `Approval`, confirmer, staging environment, deployment-approved boolean, `{:channel, :deployment}`, or staging destination. Conversely, existing staging authorization never sees local facts. A denial terminates its selected path.

## Lifecycle reuse, handoff, and revocation

After authorization and key fetch:

- initial issue delegates to `Account.issue_first/1` and retains its control-row serialization, 24-hour expiry, verifier-only persistence, and atomic issuance audit;
- recovery delegates to `Account.reissue_first/2`, retaining account locking and revoke-before-replace behavior;
- local email construction uses the newly returned token only in process memory and builds the existing fragment shape `#invitation_id=<encoded-ref>&token=<encoded-token>`;
- handoff occurs outside the database transaction and exactly once;
- success appends the existing typed `invitation_delivery_handoff` event with only a bounded local correlation reference;
- every failure after issue—including builder failure, mailbox failure, unknown handoff result, success-audit failure, or exception—calls `Delivery.revoke_delivery_failure/2` before returning;
- if revocation/audit cannot be proved, the result is failed-closed and no same-process fresh issue is allowed. A later recovery command must repeat eligibility, readiness, target checks, authorization, and key retrieval; `Account.reissue_first/2` atomically invalidates an uncertain predecessor before producing a fresh token.

No automatic retry or reuse exists. Existing invitation exchange, 24-hour durable expiry, one-use consumption, clean redirect, password hash, encrypted TOTP persistence, and replay denial remain unchanged.

## Secret and redaction analysis

| Value | Allowed location/lifetime | Disposal and prohibited behavior |
| --- | --- | --- |
| raw token/full activation URL | transient issue/email construction memory; one bounded local mailbox message; browser fragment until existing exchange removes it | Drop local references after handoff; purge mailbox by 900 seconds maximum; never log, audit, emit, persist, inspect in an error, or place in SQL. |
| synthetic destination/message body | trusted config/typed redacted value and transient Swoosh email/mailbox | Never CLI/audit/log/telemetry/APM/error/SQL/support output. Mailbox UI is the sole intentional body surface. |
| verifier/TOTP keys | owner-only files and supervised local memory after authorization | No argv/env interpolation, config dump, audit, telemetry, exception, support artifact, or committed example value; clear at session end/restart. |
| certificate private key | owner-only file consumed by the exact local HTTPS endpoint | Readiness sees metadata/path only and emits only a finding code. |
| correlation/account/invitation refs | typed command/audit outcomes | Enforce existing bounded safe-reference grammar; never derive them from message content. |

Construct safe error/result payloads before calling Logger, telemetry, Mix shell, or audit. Catch/rescue clauses discard raw exceptions and return fixed atoms. `%Ready{}`, destination/origin wrappers, secret-cache state, and mailbox state need redacted `Inspect` implementations. No telemetry event carries the Swoosh email or configuration. SQL receives only existing account/invitation/key-digest values required by lifecycle; destination, URL, email, and raw token never become SQL binds.

The mailbox is not a diagnostic/support/audit preview outside its exact loopback development route. Operational guidance forbids screenshots or copying message content into chat/tickets. This is a procedural backstop, not a substitute for the runtime boundary.

## Test seams and matrix

Production entry points do not accept injected environment, channel, profile, modules, or clocks. Pure validators and the local orchestrator accept explicit dependencies only through internal function parameters. The existing `if Mix.env() == :test` command-options pattern may expose test doubles, but the actual local task remains ineligible in compiled `:test`; success-path tests call the post-eligibility orchestration boundary directly.

| Layer | Required evidence |
| --- | --- |
| Eligibility/dispatch | Shared gate is first for source and release; malformed booleans deny; exact `:dev`/`:test`/`:prod` matrix; unknown profile denies; local selection never falls back; release channel with copied local gates never parses/starts/fetches. |
| Readiness | Multiple failures return every expected code in stable order; probes record no secret `fetch`, Repo, mailbox, endpoint-start, token, or output call; unsafe probe exceptions are reduced to codes; ready result inspection is redacted. |
| Destination | Exact accepted value; tables for case, Unicode/lookalikes, multiple `@`, suffixes, real domain, whitespace, CR/LF/header syntax, invalid bytes, consecutive dot, list/multiple values, and secret-bearing argv. Prove downstream modules use the one typed value. |
| Origin/endpoint | Exact `https://127.0.0.1:<port>/admin/activate`; reject HTTP, omitted/alternate port, localhost/DNS/IPv6/wildcard/private/public binds, second HTTP listener, userinfo/query/fragment/path variants, encodings, and malformed cert metadata. |
| Authorization | Exact initial and recovery fact maps allow only their operations; each missing, unknown, conflicting, staging-shaped, extra, shared-database, active-account, and wrong-account variant denies before lifecycle writes. Existing staging requests remain unchanged. |
| Mailbox retention | Fake clock/store proves one submission, max one entry, delete at/before TTL, clear on init/restart/shutdown, no retry, crash-between-store-and-ack cleanup, preview loopback contract, and expiry revocation. No test assertion prints the email. |
| Domain integration | Initial issue creates one account/invitation; concurrency yields one; handoff failure revokes and token exchange denies; recovery repeats all gates/readiness/auth, calls existing reissue, and creates a different token; active account and retained-message recovery deny. |
| Activation | Existing TLS controller test remains; local HTTPS happy path reaches clean URL, consumes once, hashes password, encrypts TOTP, denies replay, and clears mailbox/cache. HTTP remains 404. |
| Prohibited sinks | Canary destination/token/URL/body/key/TOTP values are absent from Mix output, logs, telemetry, exceptions, audit, SQL telemetry/binds, support summaries, and inspected safe structs on success and every failure edge. |
| Staging regressions | Existing `DeliveryConfig`, `Provider`, `ApprovalVerifier`, and `Origin` tests remain untouched and continue rejecting Local/Test/mailbox adapters, local approvals/environment/origin, and malformed configuration. |
| Build/release exclusion | `MIX_ENV=test` actual task denies before parser; production compile/release has local gate false and no dev mailbox route; `Origen.Release.bootstrap_admin/1` with local-looking configuration denies before local seams; release overlay has no local command. |

Test-only Local mailbox fakes are injected below eligibility; configuring `Swoosh.Adapters.Test` never makes the runtime local profile ready.

## Explicit likely file surfaces for implementation (#50)

| Path | Expected change |
| --- | --- |
| `config/config.exs` | Add default staging selector, false local gate, and disabled local map. |
| `config/dev.exs` | Define development-only structural defaults; retain ignored local import. |
| `config/dev.local.example.exs` | Document placeholders for one synthetic address, exact HTTPS loopback port/cert refs, local secret-file refs, TTL, and isolated DB name; no key values. |
| `config/runtime.exs` | Hard-disable local selector/gate in production and avoid an HTTP listener when an eligible dev local endpoint is configured. Preserve staging delivery config. |
| `lib/mix/tasks/origen.bootstrap_admin.ex` | Pass the trusted source channel, keep both gates before local parsing, print references only, and keep the same VM alive for local activation. |
| `lib/origen/release.ex` | Pass `:packaged_release` explicitly and prove no local dispatch. |
| `lib/origen/bootstrap_admin/command.ex` | Add trusted atom dispatch while preserving the current staging branch. |
| `lib/origen/bootstrap_admin/local/{eligibility,readiness,destination,origin,target,authorization,secrets,invitation_email,mailbox,command}.ex` | New isolated local policy and adapters described above. |
| `lib/origen/application.ex` | Supervise empty local mailbox/secret-cache processes only in the reviewed development configuration; processes do not inspect content before command readiness. |
| `lib/origen/authorization/rules.ex` | Add exact local channel/operations/rules and exact-map matching for those rules only. |
| `lib/origen/bootstrap_admin.ex` and/or a small shared delivery helper | Expose only reusable safe handoff-audit/compensation calls needed by local orchestration; leave staging behavior intact. |
| `lib/origen_web/controllers/admin_activation_controller.ex` | If required, route verifier/TOTP lookup through `BootstrapSecrets`; do not change `require_tls/1`, fragment exchange, redirects, session, forms, or activation policy. |
| focused tests under `test/origen/bootstrap_admin/local/`, task/release tests, authorization tests, and existing activation tests | Add the matrix above. |
| approved deployment/security documentation other than the excluded guide | Add setup, bounded mailbox operation, cleanup, and rollback only if #50 explicitly includes those docs. |

The following files/modules are explicit non-edit boundaries for behavior: `delivery_config.ex`, `provider.ex`, `approval_verifier.ex`, staging `origin.ex`, controller TLS logic, staging provider implementations, migrations, and the untracked student guide. No `mix.exs` dependency change is expected.

## Alternatives rejected

1. **Relax staging validators.** Rejected because adding Local/Test/loopback branches to `DeliveryConfig`, `Provider`, `ApprovalVerifier`, or `Origin` mixes trust models and defeats existing rejection tests.
2. **User-selectable `--profile` or adapter module.** Rejected because argv is untrusted and would create configuration-confusion/fallback paths.
3. **A separate short-lived Mix process plus an already-running server.** Rejected because Swoosh Local storage is VM-local; the message would not be visible to the browser server after the command exits.
4. **Print/write the activation URL or token.** Rejected because terminal history and files become durable secret stores.
5. **Direct credential seeding.** Rejected because it bypasses invitation exchange, one-use consumption, password hashing, and TOTP enrollment.
6. **Persist mailbox content or a delivery-status column.** Rejected because bounded memory plus `revoked_at` is authoritative and no schema is needed; persistence enlarges the secret boundary.
7. **Use `Swoosh.Adapters.Test` in runtime.** Rejected because test compilation/runtime is expressly ineligible and test retention is not the approved student mailbox.
8. **Trust `localhost`, DNS resolution, suffix email matching, or automatic case/Unicode normalization.** Rejected because each introduces ambiguity absent from literal IPv4/exact ASCII comparisons.
9. **Treat local recovery as staging reissue.** Rejected because deployment approval and channel facts are false locally. Recovery receives its own exact local rule.

## Security analysis

The principal threats are cross-profile confusion, real-address delivery, alternate-interface mailbox exposure, indefinite token retention, and leakage through diagnostics. Independent modules plus trusted dispatch prevent local values from entering staging policy. Exact ASCII destination and literal IPv4 origin remove suffix, DNS, IDNA, and header ambiguity. Removing HTTP and binding the only endpoint to `127.0.0.1` keeps both mailbox and activation on TLS loopback. One-message memory storage, a 900-second compiled ceiling, restart clearing, and revocation on expiry/failure bound token availability.

The compensation interval begins after invitation commit and ends at mailbox acknowledgement. It cannot be removed without putting external/in-memory handoff inside the database transaction. The coordinator narrows it: one synchronous submission, timer installation before success, clear-on-crash, and audited revocation for every uncertain outcome. Existing locked revocation/consume behavior selects one terminal winner.

A local database cannot cryptographically prove that no student has shared it. Exact local connection/database checks and an explicit workstation-isolation declaration make the authorization fact reviewable, while operating instructions and the existing first-admin constraint limit damage. A true shared-classroom topology would require a separately designed tenant/authorization model.

## Specification correction required before implementation

The approved deltas currently say every local allow requires “no pending or active Administrator exists” and also say any pending Administrator denies issuance. That contradicts the required fresh invitation after handoff failure, because failure revokes the invitation but intentionally leaves the sole account pending.

Per the design decision, the specs/tasks must distinguish:

- initial issue: no pending or active Administrator;
- recovery reissue: the exact sole Administrator is pending, no active Administrator exists, the prior local handoff is revoked or uncertain, all eligibility/readiness/local authorization repeats, and existing `Account.reissue_first/2` revokes predecessors before one fresh token;
- every other pending state and every active account: deny.

The `default-deny-authorization` delta must therefore add the exact recovery operation/rule (or explicitly model these two mutually exclusive modes) rather than requiring the no-Administrator fact for recovery. The local-profile and first-admin deltas must replace the blanket “deny if any pending Administrator exists” wording where it applies to recovery. This is a correction of an internal contradiction, not a scope expansion, schema change, or permission for a second account.

## Migration and rollout assumptions

- No database migration, grant, table, column, index, or dependency is added.
- Each student has a separate local PostgreSQL database and OS account/configuration. The database may contain only that workstation's fictitious Administrator lifecycle.
- Existing invitation/audit data remains authoritative and compatible. Local delivery provenance is not persisted as message content or mutable status.
- The endpoint certificate covers literal `127.0.0.1` and is trusted by that student's browser. HTTP is disabled while this profile is active.
- The locked Swoosh Local storage API supports the coordinator contract; implementation verifies this before enabling. If not, the bounded storage seam is implemented rather than accepting indefinite retention.
- The profile is a source-checkout tool. It is neither an application feature nor a release command.

### Operational setup

1. Create a dedicated local database for the workstation and migrate it normally; do not point it at a shared/staging database.
2. Generate a local certificate with literal IPv4 `127.0.0.1` in its SAN and store its private key owner-only. Trust only the local development certificate as required by the browser.
3. Generate verifier and TOTP encryption keys into separate owner-only ignored files without echoing their values. Put only paths and the non-secret key tag in `config/dev.local.exs`.
4. Configure exactly one lowercase ASCII address under `example.test`, exact HTTPS loopback origin/port, HTTP disabled, TTL at most 900 seconds, max one message, and isolated database identity.
5. Deliberately set the trusted profile/local gate in the ignored file and set the existing bootstrap gate exactly true for the command invocation.
6. Run the source-checkout command as the process that hosts HTTPS/mailbox. Review only sanitized readiness codes if setup is incomplete. Do not run a separate mailbox server VM.
7. Open the known local mailbox over its configured HTTPS loopback route, activate, and allow the command to clear message/key memory and exit. Do not copy the message into support media.
8. Turn both gates back off after the exercise.

No setup command prints generated keys, destination, token, or URLs. Example configuration contains placeholders only.

## Rollback

1. Remove/set the local gate and shared gate to values other than exact `true`; set the trusted selector away from `:local`; restart. Verify denial precedes parser, application start, Repo, secret fetch, and mailbox.
2. Stop the local command/endpoint. The in-memory mailbox and secret cache clear on shutdown; if it is still running, use the bounded coordinator cleanup only after confirming activation is not in progress.
3. Revoke an unresolved invitation whose handoff cannot be trusted, or keep all bootstrap surfaces disabled through durable expiry. Never reuse its token.
4. Revert local modules/configuration and restore the ordinary development endpoint configuration. Preserve account, invitation, credential, bootstrap-control, and append-only audit history.
5. Do not run down migrations or erase a database automatically. A student may separately reset an explicitly disposable workstation database under existing development procedures.
6. Leave staging `DeliveryConfig`, `Provider`, `ApprovalVerifier`, `Origin`, activation TLS, staging configuration, and provider behavior unchanged.

## Review checkpoints

1. Review trusted dispatch, exact-dev/channel derivation, and gate/parser/start ordering.
2. Review aggregate readiness and prove metadata probes never fetch protected contents.
3. Review destination/origin exactness and endpoint removal of HTTP.
4. Review local exact authorization, including the required recovery spec correction.
5. Review Swoosh storage APIs, one-message/900-second retention, same-VM operation, crash cleanup, and revocation races.
6. Review prohibited-sink tests and unchanged staging/activation regressions.
7. Review production/test/release exclusion and disablement-first rollback.

Implementation must pause if it requires a local exception in a staging validator, a controller TLS relaxation, a schema change, an unbounded mailbox, secret-bearing output, or a release-facing local entry point.
