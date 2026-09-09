# Delta for Default-Deny Authorization

## ADDED Requirements

### Requirement: Explicit Bootstrap Authorization Decisions

Bootstrap creation, invitation reissue, and web activation MUST each be represented as explicit operations and channels in the approved authorization matrix. Deployment and invitation channels MUST be limited to their declared operation; Administrator role membership MUST NOT grant bootstrap or reissue authority implicitly.

#### Scenario: Approved bootstrap or reissue channel

- GIVEN the operation, channel, account state, and target facts match an approved matrix rule
- WHEN authorization is evaluated
- THEN the operation MUST be allowed

#### Scenario: Unrecognized or over-broad request

- GIVEN a caller requests bootstrap, reissue, or activation outside its explicit matrix rule
- WHEN authorization is evaluated
- THEN the request MUST be denied without business effects

#### Scenario: Missing relationship or state fact

- GIVEN required target, account-state, or scope facts cannot be established
- WHEN authorization is evaluated
- THEN the request MUST remain denied
