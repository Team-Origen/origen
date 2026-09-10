# Delta for Admin Invitation Activation

## MODIFIED Requirements

### Requirement: Invitation-Bound Web Activation

Activation MUST begin from an HTTPS link whose invitation reference and raw token occur only in the browser fragment. Client-side exchange MUST remove the fragment before POST, exchange the invitation for a short-lived in-memory nonce, and redirect to a clean token-free URL before credential forms render. The invitation MUST be verified before establishing the bounded invitation-bound session. Durable state MUST remain authoritative for expiry, revocation, consume-once behavior, and replay denial; token verification MAY additionally enforce a bounded maximum age.
(Previously: Activation required TLS, invitation verification, a short-lived session, and a clean redirect, but did not fully state the preserved fragment-only exchange and in-memory nonce contract.)

#### Scenario: Invitation opens activation

- GIVEN a valid unexpired invitation is present only in an HTTPS URL fragment
- WHEN the browser removes the fragment, exchanges the invitation, and the server verifies it
- THEN a short-lived in-memory nonce and bounded invitation-bound session MUST be established
- AND the browser MUST reach a clean token-free URL before credential enrollment renders

#### Scenario: Invalid or leaked-route invitation

- GIVEN the invitation is invalid, expired, revoked, consumed, replayed, appears in a server-visible URL component, or cannot be safely exchanged
- WHEN the web endpoint receives or evaluates it
- THEN activation MUST be rejected without rendering credential enrollment, returning secret material, or changing credentials

#### Scenario: Successful activation consumes once

- GIVEN a valid invitation-bound session was established through fragment exchange
- WHEN Santiago completes activation
- THEN the invitation MUST be consumed exactly once before credentials become active
- AND every later replay MUST be denied
