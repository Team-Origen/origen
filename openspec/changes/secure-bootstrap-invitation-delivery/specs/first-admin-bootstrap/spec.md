# Delta for First Admin Bootstrap

## MODIFIED Requirements

### Requirement: Fail-Closed Non-Production Gate

Every source-checkout and packaged bootstrap entry point MUST invoke the same shared gate before argument parsing, repository access, network access, token issuance, or any other bootstrap-specific I/O. The gate MUST require one runtime boolean explicitly set to `true`, MUST default to `false`, and MUST reject when the compiled Mix environment is `:prod`. Missing or malformed configuration MUST reject. Production configuration MUST NOT enable bootstrap. Infrastructure remains responsible for accurate deployment classification.
(Previously: The shared gate denied disabled, malformed, and production invocation before account or invitation creation, without requiring it to precede all parsing and I/O.)

#### Scenario: Bootstrap is explicitly enabled outside production

- GIVEN the runtime flag is exactly `true` and the Mix environment is not `:prod`
- WHEN a source-checkout or packaged bootstrap command is invoked
- THEN the shared gate MAY permit the command to continue to parsing, authorization, confirmation, and account checks

#### Scenario: Gate is absent, malformed, or production

- GIVEN the flag is absent, malformed, false, or the environment is `:prod`
- WHEN a source-checkout or packaged bootstrap command is invoked
- THEN the shared gate MUST deny the operation before argument parsing, repository access, network access, token issuance, or bootstrap-specific I/O

## ADDED Requirements

### Requirement: Two-Person Invitation Confirmation

Samuel MUST request issuance for Santiago, and a distinct authorized confirmer MUST approve both Santiago's exact destination address and the staging/non-production target environment before token issuance. The system MUST fail closed when either approval value is absent, differs from the requested value, targets production, or is supplied by Samuel. Confirmation MUST apply independently to every fresh issuance or reissue.

#### Scenario: Distinct confirmer approves matching values

- GIVEN Samuel requests an invitation for Santiago's destination in staging
- AND a distinct authorized confirmer approves that exact destination and environment
- WHEN issuance is attempted after the shared gate permits the operation
- THEN the system MAY issue one invitation token

#### Scenario: Confirmation is absent, mismatched, self-approved, or production

- GIVEN confirmation is missing, differs from Santiago's requested destination or environment, is supplied by Samuel, or names production
- WHEN issuance is attempted
- THEN the system MUST deny issuance without creating an invitation or raw token

#### Scenario: Fresh issue follows delivery failure

- GIVEN a prior invitation was revoked after delivery failure
- WHEN Samuel requests a replacement
- THEN a distinct authorized confirmer MUST newly approve Santiago's destination and the staging environment before a new token is issued

### Requirement: Delivery-Failure Invitation Lifecycle

A failed provider handoff or terminal delivery outcome MUST revoke the affected invitation. The failed raw token MUST NOT be reused, resubmitted, or restored. Recovery MUST require a newly issued invitation with a new token while preserving the existing 24-hour expiry, consume-once, single-active, atomic reissue, and replay-denial guarantees.

#### Scenario: Provider handoff or delivery fails

- GIVEN an active invitation has been submitted for transactional delivery
- WHEN provider handoff fails or a terminal delivery failure is reported
- THEN the invitation MUST be revoked
- AND later activation with that invitation MUST be denied

#### Scenario: Operator recovers from delivery failure

- GIVEN the failed invitation is revoked
- WHEN Samuel repeats the authorized issuance flow after new confirmation
- THEN the system MUST create a new invitation with a new token
- AND MUST NOT reuse or retry the failed token
