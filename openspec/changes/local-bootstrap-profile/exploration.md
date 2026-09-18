# Exploration: Local Bootstrap Profile

## Goal

Add a separate, secure local-development delivery profile so each of the four students can create and activate one fictitious Administrator in an isolated local database. The profile must be development-only, disabled by default, bounded to synthetic destinations, and must not weaken the staging/real-delivery path.

## Current State

- `mix origen.bootstrap_admin` and `Origen.Release.bootstrap_admin/1` call `Origen.BootstrapAdmin.Gate.check/0` before parsing arguments or performing protected input, repository, token, provider, or output work. The gate requires the runtime value to be exactly `true` and rejects `Mix.env() == :prod`.
- Runtime delivery is intentionally unavailable: `config/runtime.exs` sets `:bootstrap_admin_delivery` to `%{enabled: false}` and hard-disables bootstrap and delivery in production.
- The command has no normal protected-input resolver configured. It requires an opaque `--approval-input-ref`, then expects staging-specific approval, destination, environment, verifier key, and delivery configuration from the resolver. Consequently, enabling the gate alone does not create an operational local path.
- `DeliveryConfig` is a staging/real-delivery validator. It requires environment `staging`, an approved HTTPS host/path, encrypted bounded provider retention, least-privilege audited access, and disabled retries. It explicitly rejects `Swoosh.Adapters.Local` and `Swoosh.Adapters.Test`.
- `Provider` separately rejects `Swoosh.Adapters.Local`, `Swoosh.Adapters.Test`, and `Plug.Swoosh.MailboxPreview`. These protections are covered by tests and must remain unchanged.
- `ApprovalVerifier` accepts only exact `staging` assertions from a distinct authorized confirmer. `BootstrapAdmin.issue_and_deliver/2` also constructs staging deployment-approval authorization facts. A local flow cannot truthfully pass this boundary by fabricating a staging approval.
- Development already configures `Origen.Mailer` with `Swoosh.Adapters.Local`, enables `/dev/mailbox`, and binds the endpoint to IPv4 loopback. However, the endpoint is HTTP by default. Activation rejects every non-HTTPS request, and the existing `Origin` accepts only an exact approved staging HTTPS origin on port 443.
- Invitation and activation primitives are reusable: raw tokens are generated in memory while only keyed HMAC verifiers are persisted; invitations expire after 24 hours and are one-use; browser activation exchanges fragment data for a short-lived in-memory nonce; credentials use password hashing and encrypted TOTP persistence; output and lifecycle evidence are sanitized.
- First-Administrator issuance serializes on `admin_bootstrap_controls` and refuses issuance once any Administrator exists. This supports one student per isolated local database, not four Administrators in one shared database.
- The current student guide is established as accurate that no local operational path exists and is outside this change's edit surface. It must not be modified during this change.

## Exact Gap

The repository contains both a secure staging delivery path and Phoenix's ordinary local mailbox tooling, but no approved bridge between local bootstrap issuance and a local activation message. The staging validators correctly prevent using the local adapter/mailbox, while the local endpoint is not configured for the activation flow's mandatory HTTPS transport.

A local solution therefore needs an independently named and validated profile; changing `DeliveryConfig`, `Provider`, `ApprovalVerifier`, or `Origin` to accept local/test values would mix trust models and weaken real-delivery controls.

## Recommended Shape

Introduce a narrow local-bootstrap profile that composes the existing account/invitation/activation lifecycle but owns separate local policy and delivery adapters.

1. **Independent gate and configuration**
   - Require the existing bootstrap gate and an additional local-profile boolean that is exactly `true`.
   - Default the local profile to disabled.
   - Require the compiled environment to be exactly `:dev`; explicitly deny `:test`, staging conventions, and `:prod` at runtime. Test seams may inject dependencies without making the runtime profile valid in `:test`.
   - Select the profile from trusted application configuration, not a user-supplied module name or a flag that can turn staging delivery into local delivery.

2. **Separate local validation/delivery boundary**
   - Add a local-specific validator/provider rather than adding exceptions to `DeliveryConfig` or `Provider`.
   - Permit only the expected local adapter and dev mailbox delivery mechanism.
   - Require an exact HTTPS loopback activation origin and an explicitly configured local HTTPS endpoint/port. Do not relax the activation controller's TLS check.
   - Keep the fragment-only link contract and existing activation exchange unchanged.

3. **Synthetic destination boundary**
   - Accept only canonical synthetic addresses from an exact configured allowlist, preferably under the reserved `example.test` domain; reject arbitrary suffix matching, Unicode/lookalike ambiguity, newline/header injection, and real domains.
   - Do not accept a destination, token, verifier key, TOTP value, or URL through argv.
   - Treat the local mailbox as the deliberately approved, loopback-only delivery surface for the synthetic message. The raw token/full URL may exist there and in the student's browser fragment, but must not be copied into Logger, telemetry, errors, CLI output, audit, SQL binds, support artifacts, or other sinks.

4. **Local authorization without staging impersonation**
   - Do not forge a staging approval or mark local execution as deployment-approved.
   - Add a distinct default-deny local-development authorization fact/rule or an equally explicit local policy boundary whose allow decision requires the dev-only gate, exact synthetic destination, isolated local profile, and approved command channel.
   - Reuse existing issuance, invitation persistence, failure revocation, activation, password, and TOTP primitives after local policy succeeds.

5. **One Administrator per workstation database**
   - Preserve first-Administrator uniqueness and the existing schema.
   - Document/specify the four-student outcome as one fictitious Administrator in each student's isolated local database. Supporting four Administrators in a shared database would alter the first-admin domain invariant and require separate product, schema, and authorization work.

6. **Local secret/configuration setup**
   - Use ignored `config/dev.local.exs` or another local-only protected source for per-workstation verifier and TOTP encryption keys and for explicit enablement. Do not commit shared operational keys or print generated values.
   - Provide fail-closed validation before issuance so missing HTTPS, keys, synthetic destination, or mailbox constraints cannot create an invitation.

## Approaches Considered

### A. Separate local profile reusing lifecycle primitives — recommended

Create local-only policy/configuration and mailbox handoff modules, while reusing invitation persistence and web activation.

- **Pros:** preserves real-delivery rejection tests; smallest trust-boundary change; retains one-use, expiry, HTTPS, password, and TOTP protections; no schema change expected.
- **Cons:** requires explicit profile dispatch and local HTTPS setup; the local mailbox becomes a narrowly approved transient secret-bearing surface that needs tests and operating guidance.
- **Effort:** Medium.

### B. Relax existing staging delivery validators — reject

Allow Local/Test adapters, localhost, or `local` approvals inside `DeliveryConfig`, `Provider`, `Origin`, and `ApprovalVerifier`.

- **Pros:** superficially fewer modules.
- **Cons:** directly weakens the real/staging trust boundary, increases configuration-confusion risk, and contradicts existing specifications and regression tests.
- **Effort:** Medium with unacceptable security risk.

### C. Print or write the token/link for local use — reject

Emit the activation secret from the Mix task or a local file.

- **Pros:** easy onboarding.
- **Cons:** violates reference-only output and prohibited-sink requirements; shell history, terminals, transcripts, and files become secret stores.
- **Effort:** Low with unacceptable leakage risk.

### D. Seed active Administrator credentials directly — reject

Bypass invitation and TOTP enrollment with a seed script.

- **Pros:** avoids delivery setup.
- **Cons:** bypasses the approved activation lifecycle, creates password/TOTP handling risks, and fails to exercise the student-facing security flow.
- **Effort:** Low but out of scope.

## Likely Future Edit Surfaces

Exploration makes no application edits. A proposal/design will likely cover:

- `config/config.exs`, `config/dev.exs`, `config/dev.local.example.exs`, and `config/runtime.exs` for default-off, dev-only profile and local HTTPS/key validation;
- `lib/mix/tasks/origen.bootstrap_admin.ex`, `lib/origen/release.ex`, or a dedicated local command adapter while preserving gate-first execution;
- new local-only modules under `lib/origen/bootstrap_admin/` for profile validation, authorization input, message construction, and mailbox handoff;
- `lib/origen/bootstrap_admin.ex` only for explicit orchestration/profile dispatch, without relaxing `DeliveryConfig`, `Provider`, `ApprovalVerifier`, or staging `Origin`;
- focused gate/config/provider/output tests, existing staging rejection regressions, and HTTPS activation lifecycle tests;
- later documentation updates other than the current untracked student guide, which is explicitly excluded from this change.

## Security Impact

Security impact is high at the profile boundary because the change intentionally makes the invitation token visible in a local delivery surface. The principal risk is not a real external send, but configuration confusion that lets a retaining local adapter enter staging/production or allows a real destination into the local mailbox.

Required controls for the next phases:

- exact `:dev` and explicit double-gate checks before config reads, issuance, mailbox writes, or output;
- strict separation from `DeliveryConfig`/`Provider` and regression tests proving they still reject Local/Test/mailbox adapters;
- exact synthetic-address allowlisting and loopback-only HTTPS origin/endpoint validation;
- token/full URL limited to transient issuance memory, the approved local mailbox, and browser fragment;
- no raw token, full URL, password, TOTP seed/code, QR payload, cookie/session, verifier/encryption key, destination, or message body in logs, audit, telemetry, exceptions, CLI, SQL telemetry, or support output;
- reference-only success/failure responses and revocation on local handoff failure;
- mailbox access confined to the student's loopback development process, with clearing/restart guidance and no screenshots/copying into tickets or chat.

The ordinary `/dev/mailbox` route and development dashboard deserve explicit review: loopback binding is currently protective, but a developer can alter endpoint binding. The local profile should fail closed if its expected loopback/TLS assumptions are not met rather than relying only on documentation.

## Migration Risk

Expected database migration risk is **low**: no schema change is needed if each student uses an isolated local database and existing first-admin uniqueness remains intact. Invitation/account/audit rows can use the existing lifecycle and constraints.

Migration risk becomes **high and out of scope** if “four students” is interpreted as four Administrators in one database. That would conflict with `Account.issue_first/1`, the serialized first-admin control, and the first-admin specification. The proposal should explicitly preserve the isolated-database interpretation.

Configuration migration risk is **medium**. Local HTTPS certificates, endpoint port, verifier key, TOTP keyring, exact synthetic destination, and two explicit enablement values must agree. Invalid or partial setup must fail before token issuance and should not silently fall back to staging delivery.

## Rollback

Rollback is disablement-first and requires no destructive migration:

1. Set/remove the local-profile enablement and existing bootstrap enablement in each workstation's ignored local configuration; restart the local application.
2. Verify the local command denies before parsing, repository access, invitation issuance, mailbox handoff, or output.
3. Stop the local HTTPS endpoint/mailbox exposure and clear only ephemeral local mailbox state after confirming no activation is in progress.
4. Revoke unresolved local invitations when their delivery state is uncertain, or keep the profile disabled through expiry.
5. Revert local profile code/configuration while preserving existing account, invitation, and append-only audit history. Do not weaken or delete staging delivery controls.

Because data is fictitious and workstation-local, a student may separately reset an explicitly disposable local database under existing development procedures, but rollback code must not automatically erase lifecycle/audit history.

## Risks and Proposal Checkpoints

- **Environment/profile confusion:** strongest mitigation is independent types/modules and an exact `:dev` gate, not branches inside the staging validators.
- **Mailbox retention:** confirm the chosen local adapter's in-memory persistence/clearing semantics and specify bounded cleanup without logging message content.
- **HTTPS usability:** the proposal must define a workable local certificate and exact loopback origin while keeping controller TLS enforcement.
- **Shared database ambiguity:** proposal must state one Administrator per isolated student database; shared multi-Admin provisioning is excluded.
- **Local key onboarding:** setup must be usable without committing, echoing, or logging verifier/TOTP keys.
- **Release surface:** a packaged staging/production release must not expose or enable the local profile, even if environment variables are copied incorrectly.
- **Regression burden:** existing staging adapter/origin/approval rejection, one-use invitation, clean redirect, encrypted TOTP, and prohibited-sink tests remain mandatory.

## Outcome

Exploration is complete. The approved direction is feasible without schema changes by adding a separately gated local profile and reusing only the secure lifecycle primitives. The staging `DeliveryConfig`/`Provider` boundary must remain unchanged. The next phase should propose the exact dev-only gate, synthetic allowlist, local HTTPS/mailbox contract, local authorization rule, and one-student-per-isolated-database assumption.

next_recommended: proposal
