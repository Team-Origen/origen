# Admin Invitation Activation Specification

## Purpose

Define secure web activation for the invited first Administrator.

## Requirements

### Requirement: Invitation-Bound Web Activation

Activation MUST occur only through a TLS-protected web exchange. The invitation MUST be verified before establishing a short-lived server-side pre-activation session bound to the target account, and the user MUST be redirected to a clean URL before credential forms render. Token verification MAY enforce a bounded maximum age, but durable state remains authoritative for expiry and one-time use.

#### Scenario: Invitation opens activation

- GIVEN a valid invitation is presented over strong transport
- WHEN the activation exchange verifies it
- THEN a bounded invitation-bound session MUST be established and the clean activation page MAY render

#### Scenario: Invalid or leaked-route invitation

- GIVEN the invitation is invalid, expired, revoked, consumed, or cannot be safely exchanged
- WHEN the web endpoint receives it
- THEN activation MUST be rejected without rendering credential enrollment or returning secret material

### Requirement: Password and TOTP Enrollment

The invited user MUST choose a password that is stored only as a password-specific slow hash with a unique salt; plaintext MUST NOT be stored. The system MUST generate a TOTP seed for this enrollment, render its QR payload once, require a valid TOTP code before persisting the factor, and MUST NOT expose the seed, QR payload, OTP code, or recovery codes through audit, logs, errors, or output. Recovery-code policy and seed-at-rest protection remain design constraints, not decisions of this specification.

#### Scenario: Activation completes

- GIVEN a valid invitation-bound session and acceptable password
- WHEN the user submits the password and a valid TOTP code
- THEN the password hash and enrolled TOTP factor MUST be persisted and the account MUST become active

#### Scenario: Invalid TOTP or replay

- GIVEN the code is invalid or the invitation was already consumed
- WHEN enrollment is submitted
- THEN no credentials or factor MUST be persisted and replay MUST be rejected

#### Scenario: Sensitive enrollment data reaches output

- GIVEN a password, seed, QR payload, OTP code, recovery code, session value, or token is present in an operation
- WHEN audit, logging, error reporting, telemetry, or delivery diagnostics are built
- THEN that value MUST be excluded before reaching any sink
