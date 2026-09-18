# First Admin Bootstrap Specification

## Purpose

Define the deployment-only, non-production flow for creating exactly one initial Administrator and issuing durable invitations.

## Requirements

### Requirement: Fail-Closed Non-Production Gate

The bootstrap entry point MUST require one runtime boolean explicitly set to `true`, MUST default to `false`, and MUST reject when the compiled Mix environment is `:prod`. Missing or malformed configuration MUST reject. Release invocation MUST use this same gate, and production configuration MUST NOT enable it. Infrastructure remains responsible for accurate deployment classification.

#### Scenario: Bootstrap is explicitly enabled outside production

- GIVEN the runtime flag is exactly `true` and the Mix environment is not `:prod`
- WHEN the bootstrap command is invoked
- THEN the command MAY continue to authorization and account checks

#### Scenario: Gate is absent, malformed, or production

- GIVEN the flag is absent, malformed, false, or the environment is `:prod`
- WHEN the command or release entry point is invoked
- THEN it MUST fail before creating an account or invitation

### Requirement: Unique First Administrator

The system MUST allow creation only when no Administrator exists and MUST enforce first-admin uniqueness under concurrent attempts. A pending first-admin account MUST NOT permit a second first-admin account.

#### Scenario: First bootstrap succeeds

- GIVEN bootstrap is allowed and no Administrator exists
- WHEN the command creates the first pending Administrator
- THEN exactly one pending first-admin account and one invitation MUST be created

#### Scenario: Concurrent or repeated bootstrap

- GIVEN an Administrator or pending first-admin account already exists
- WHEN another bootstrap attempt runs
- THEN it MUST be denied without creating an account or invitation

### Requirement: Durable Single-Active Invitation Lifecycle

Each issue MUST create immutable state containing only a verifier/digest, target reference, timestamps, consumption/revocation state, and non-secret correlation references. The raw token MUST NOT be persisted or emitted. Invitations MUST expire 24 hours after issuance, be consume-once, and support atomic reissue: reissue MUST revoke every prior unconsumed invitation before creating one replacement. At most one unconsumed invitation per target MUST be active.

#### Scenario: Valid invitation is consumed

- GIVEN an unrevoked invitation is within 24 hours and unused
- WHEN activation consumes it
- THEN the invitation MUST be marked consumed before credentials are created

#### Scenario: Expired, consumed, or revoked invitation

- GIVEN an invitation is expired, consumed, or revoked
- WHEN activation attempts to use it
- THEN activation MUST be rejected without credential changes

#### Scenario: Reissue races with consume or reissue

- GIVEN concurrent lifecycle operations target the same pending account
- WHEN they execute
- THEN transactions MUST serialize the parent state so only the valid single-active outcome succeeds

### Requirement: Migration Safety and Rollback

Migrations MUST be forward-compatible, preserve existing audit and bootstrap/invitation history, and MUST NOT silently remove populated records. Rollback MUST disable the bootstrap surface while retaining history; destructive removal MUST require explicit approval.

#### Scenario: Migration rollback with populated history

- GIVEN bootstrap or invitation records exist
- WHEN the change is rolled back
- THEN the command and activation surface MUST be disabled and records MUST remain available

#### Scenario: Destructive rollback requested

- GIVEN rollback would remove populated history or constraints
- WHEN rollback is evaluated
- THEN it MUST require explicit approval rather than execute silently
