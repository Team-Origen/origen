# Delta for Default-deny Authorization

## ADDED Requirements

### Requirement: Explicit Local-Development Bootstrap Authorization

The backend MUST represent initial local first-Administrator issue as `bootstrap_local_first_administrator` and local recovery as the separate `reissue_local_first_administrator` operation for the approved source-checkout command channel. Both allow decisions MUST require every common fact to be known and satisfied: the compiled environment is exactly `:dev`; the existing bootstrap gate and independent local-profile gate are each exactly `true`; trusted configuration selects the local profile; complete readiness has succeeded; the destination is the exact single canonical workstation value in `example.test`; and the target database is isolated. Initial issue MUST additionally require that no pending or active Administrator exists and MUST grant only creation of the sole pending Administrator and its first invitation. Recovery MUST instead require exactly one existing Administrator in `pending_activation`, no active Administrator, a positive non-secret account reference that matches that sole pending Administrator, a prior local mailbox handoff state of `revoked_or_uncertain`, and an empty or cleared local mailbox. Recovery MUST grant only reissue for that existing target and MUST NOT grant creation of another account. Missing, unknown, conflicting, user-selected, staging-shaped, deployment-approved, release-facing, additional, or over-broad facts MUST deny without business effects.

#### Scenario: Complete local command facts allow first issue

- GIVEN the operation is `bootstrap_local_first_administrator` through the approved source-checkout command channel
- AND every common local authorization fact is known and satisfied
- AND no pending or active Administrator exists in the isolated target database
- WHEN the backend evaluates authorization
- THEN it MAY allow initial issuance for only the exact configured synthetic destination and sole first-Administrator target

#### Scenario: Complete recovery facts allow reissue

- GIVEN the operation is `reissue_local_first_administrator` through the approved source-checkout command channel
- AND every common local authorization fact is known and satisfied
- AND the isolated database contains exactly one Administrator in `pending_activation` and no active Administrator
- AND a positive non-secret account reference matches that sole pending Administrator
- AND the prior local mailbox handoff is `revoked_or_uncertain`
- AND the local mailbox is empty or cleared
- WHEN the backend evaluates authorization
- THEN it MAY allow reissue only for that existing pending Administrator and exact configured synthetic destination
- AND it MUST NOT allow creation of another account

#### Scenario: Required local fact is absent or unmet

- GIVEN any required environment, gate, profile, readiness, destination, database, target-state, mailbox-state, operation, channel, or account-reference fact is missing, unknown, conflicting, additional, or unmet
- WHEN the backend evaluates authorization
- THEN it MUST deny without creating an account, invitation, token, or delivery effect

#### Scenario: Ineligible target or mailbox state requests recovery

- GIVEN recovery targets no pending Administrator, a pending state other than exactly one Administrator in `pending_activation` with every required recovery fact, multiple Administrators, any active Administrator, a non-matching or non-positive account reference, a consumed predecessor, a handoff state other than `revoked_or_uncertain`, or a mailbox that still retains a message
- WHEN authorization is evaluated
- THEN it MUST deny without reissuing an invitation or creating an account

#### Scenario: Request exceeds either narrow local grant

- GIVEN the local command channel requests another operation, a caller-supplied or second destination, a second Administrator, a shared-database target, or authority outside the selected initial-issue or recovery-reissue operation
- WHEN authorization is evaluated
- THEN it MUST deny the request despite any satisfied local facts

### Requirement: No Staging Impersonation or Fallback

Local-development authorization MUST be independent of staging delivery authorization. It MUST NOT construct, accept, translate, or rely on a staging confirmer assertion, deployment-approved fact, staging environment fact, or staging delivery channel to authorize local execution. Conversely, local gates, readiness, destination, environment, and command-channel facts MUST NOT authorize any staging or real-delivery operation. No denial on either path MAY fall back to the other path.

#### Scenario: Local request presents staging authority

- GIVEN a local-bootstrap request includes a staging confirmation, deployment-approved fact, staging environment, or staging delivery channel
- WHEN local authorization is evaluated
- THEN the request MUST be denied
- AND the staging fact MUST NOT be translated into a local allow

#### Scenario: Staging request presents local authority

- GIVEN a staging or real-delivery request includes local-profile gates, local readiness, a synthetic local destination, or the local command channel
- WHEN staging authorization is evaluated
- THEN the request MUST remain denied unless it independently satisfies the unchanged staging rule
- AND local facts MUST NOT widen the staging grant

#### Scenario: Either authorization path denies

- GIVEN the selected local or staging authorization rule denies the request
- WHEN dispatch completes
- THEN the system MUST return that denial without attempting the other profile or producing business effects
