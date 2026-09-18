# Delta for First Admin Bootstrap

## ADDED Requirements

### Requirement: Local Mailbox Handoff Failure Lifecycle

For the local-bootstrap profile, a failed or uncertain mailbox handoff MUST revoke the affected invitation when revocation can be established and MUST make the prior token unusable before a successful recovery handoff. The prior token MUST NOT be retried, restored, or reused. Recovery MUST use the separate `reissue_local_first_administrator` authorization operation and MUST be eligible only when the isolated database contains exactly one existing Administrator in `pending_activation`, no active Administrator exists, a positive non-secret account reference matches that sole pending Administrator, the prior local mailbox handoff is `revoked_or_uncertain`, and the local mailbox is empty or cleared. Recovery MUST repeat exact compiled `:dev` eligibility, both exact-`true` gates, trusted local-profile selection, complete readiness, and local authorization. An allowed recovery MUST invoke the existing atomic reissue lifecycle for the existing account, revoke every prior unconsumed invitation, and create one fresh invitation with a fresh token while preserving the existing 24-hour expiry, consume-once, single-active, and replay-denial guarantees. It MUST NOT stage or forge an approval, create a second account, or require a schema change.

#### Scenario: Local mailbox handoff fails

- GIVEN an active first-Administrator invitation was issued for the approved local mailbox
- WHEN mailbox handoff fails or its success cannot be established
- THEN the system MUST attempt to revoke the invitation and MUST treat the prior handoff as `revoked_or_uncertain`
- AND later activation with any confirmed-revoked invitation MUST be denied
- AND the local mailbox MUST be empty or cleared before recovery may be authorized

#### Scenario: Qualifying local recovery follows handoff failure

- GIVEN the isolated database contains exactly one Administrator in `pending_activation` and no active Administrator
- AND a positive non-secret account reference matches that sole pending Administrator
- AND the prior local mailbox handoff is `revoked_or_uncertain`
- AND the local mailbox is empty or cleared
- WHEN `reissue_local_first_administrator` repeats exact `:dev` eligibility, both gates, trusted local-profile selection, complete readiness, and local authorization successfully
- THEN the existing reissue lifecycle MUST revoke every prior unconsumed invitation and create one fresh invitation with a fresh token for the existing account
- AND the system MUST NOT reuse the prior token, create another account, or stage or forge an approval

#### Scenario: Local recovery state is not exact

- GIVEN the target state has no pending Administrator, a pending state other than exactly one Administrator in `pending_activation` with every required recovery fact, multiple Administrators, any active Administrator, a mismatched or non-positive account reference, a consumed predecessor, a prior handoff state other than `revoked_or_uncertain`, or a mailbox that still retains a message
- WHEN `reissue_local_first_administrator` authorization is requested
- THEN it MUST deny without creating an account, invitation, token, or delivery effect

## MODIFIED Requirements

### Requirement: Fail-Closed Non-Production Gate

Every source-checkout and packaged bootstrap entry point MUST invoke the shared bootstrap gate before argument parsing, repository access, mailbox or network access, protected-value access, token issuance, or any other bootstrap-specific I/O. The shared gate MUST require one runtime boolean explicitly set to `true`, MUST default to `false`, and MUST reject when the compiled Mix environment is `:prod`. Missing or malformed configuration MUST reject, and production configuration MUST NOT enable bootstrap. A local-profile request MUST additionally require an independent local-profile boolean exactly `true`, trusted local-profile selection, the compiled environment exactly `:dev`, and the approved source-checkout command channel. The local profile MUST reject `:test`, staging conventions, `:prod`, release-facing invocation, and packaged-release exposure before local bootstrap effects. Infrastructure remains responsible for accurate deployment classification.
(Previously: The bootstrap entry point required one default-off runtime gate and rejected compiled `:prod`, but did not define the local profile's second gate, exact `:dev` classification, source-checkout-only channel, or protected-value and mailbox ordering.)

#### Scenario: Bootstrap is explicitly enabled outside production

- GIVEN the shared runtime flag is exactly `true` and the Mix environment is not `:prod`
- WHEN a non-local bootstrap command is invoked
- THEN the shared gate MAY permit the command to continue to its authorization and account checks

#### Scenario: Shared gate is absent, malformed, or production

- GIVEN the shared flag is absent, malformed, false, or the environment is `:prod`
- WHEN a source-checkout or packaged bootstrap entry point is invoked
- THEN it MUST fail before argument parsing, repository access, mailbox or network access, protected-value access, token issuance, or bootstrap-specific I/O

#### Scenario: Local profile satisfies the narrower gate

- GIVEN the shared and local-profile flags are each exactly `true`
- AND trusted configuration selects the local profile
- AND the compiled environment is exactly `:dev`
- AND the request uses the approved source-checkout local bootstrap command
- WHEN local bootstrap is invoked
- THEN the command MAY continue to complete local readiness validation

#### Scenario: Local profile gate, environment, or channel is invalid

- GIVEN either flag is not exactly `true`, trusted configuration does not select the local profile, the environment is not exactly compiled `:dev`, or the channel is release-facing or packaged
- WHEN local bootstrap is invoked
- THEN the request MUST be denied before argument parsing, repository or mailbox access, protected-value access, token issuance, or bootstrap-specific output

### Requirement: Unique First Administrator

The system MUST allow initial creation only when no pending or active Administrator exists and MUST enforce first-admin uniqueness under concurrent attempts. A pending first-admin account MUST NOT permit initial issue or creation of a second first-admin account. The separate `reissue_local_first_administrator` operation MAY replace invitations only for the exact sole existing pending Administrator under the Local Mailbox Handoff Failure Lifecycle; that recovery MUST NOT create another account or weaken uniqueness. Local bootstrap MUST preserve this invariant independently in each student's isolated workstation database; it MUST NOT support multiple Administrators in one shared database or change the first-admin schema or serialization boundary.
(Previously: First-admin uniqueness covered pending accounts and concurrent attempts but did not distinguish initial local issue from recovery reissue for the sole existing pending account or state the local-profile topology of one Administrator per isolated workstation database.)

#### Scenario: First bootstrap succeeds

- GIVEN initial bootstrap is allowed and no pending or active Administrator exists
- WHEN the command creates the first pending Administrator
- THEN exactly one pending first-admin account and one invitation MUST be created

#### Scenario: Concurrent or repeated initial bootstrap

- GIVEN a pending or active Administrator already exists
- WHEN another initial bootstrap attempt runs or initial attempts race in the same database
- THEN the attempts MUST serialize
- AND every initial-issue outcome beyond the sole first Administrator MUST be denied without creating an account or invitation

#### Scenario: Recovery preserves the sole account

- GIVEN the exact sole pending Administrator qualifies for `reissue_local_first_administrator`
- WHEN the existing reissue lifecycle creates a replacement invitation
- THEN the same pending Administrator MUST remain the only Administrator
- AND no second account MUST be created

#### Scenario: Students use isolated workstation databases

- GIVEN each student uses a separate local development database
- WHEN each student performs an otherwise authorized local bootstrap
- THEN each isolated database MAY contain its own sole fictitious Administrator
- AND this MUST NOT authorize four Administrators in any shared database
