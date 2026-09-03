# Default-deny Authorization Specification

## Purpose

Define backend authorization as an explicit, multidimensional, default-deny decision governed only by the approved authorization matrix.

## Requirements

### Requirement: Complete Policy Input

Every authorization decision MUST evaluate the operation, actor or non-role channel, account state, target facts, and scope facts. A dimension that is not applicable under an explicit matrix rule MUST be represented as such; it MUST NOT be treated as omitted.

#### Scenario: Explicitly authorized operation

- GIVEN a known operation and actor or channel explicitly allowed by the matrix
- AND every required account-state, target, and scope fact is known and satisfied
- WHEN the backend evaluates the request
- THEN the decision MUST allow the operation

#### Scenario: Missing or unmet policy fact

- GIVEN any required policy dimension is unknown, missing, or unmet
- WHEN the backend evaluates the request
- THEN the decision MUST deny the operation without business effects

### Requirement: Canonical Default Denial

The backend MUST deny every operation or actor/channel combination not explicitly authorized by the approved matrix. Frontend visibility MUST NOT affect the decision, and absent domain relationships MUST remain denied until their facts and matrix rules exist.

#### Scenario: Unknown operation or actor

- GIVEN the operation or actor/channel is not recognized by the approved matrix
- WHEN authorization is evaluated
- THEN the decision MUST deny the request

#### Scenario: Relationship is not implemented

- GIVEN a matrix rule requires account, agenda, patient, sensitive-event, or other relationship facts
- AND the system cannot establish those facts
- WHEN authorization is evaluated
- THEN the decision MUST deny the request

#### Scenario: Sensitive audit read lacks typed scope support

- GIVEN a sensitive audit read requires domain relationships and typed scope representation
- AND either capability is unavailable in this delivery
- WHEN authorization is evaluated
- THEN the decision MUST deny the request without returning audit data

### Requirement: No Implicit Grants

Roles MUST NOT inherit permissions, imply rank, or receive wildcard grants. Each allow MUST match one operation and its declared actor/channel and conditions.

#### Scenario: Administrator lacks an explicit grant

- GIVEN an Administrator requests an operation not explicitly allowed for that role
- WHEN authorization is evaluated
- THEN the decision MUST deny the request despite the role name

#### Scenario: Non-role channel is narrowly scoped

- GIVEN a deployment, system, invitation, or possession-based channel satisfies one declared scope
- WHEN it requests another operation or exceeds that scope
- THEN the decision MUST deny the request

### Requirement: Backend Enforcement

Every protected application boundary MUST obtain an allow decision before performing business or audit access. A denial MUST be authoritative even when a client invokes the backend directly.

#### Scenario: Direct backend request

- GIVEN a client bypasses or manipulates the user interface
- WHEN the protected backend boundary returns a denial
- THEN no protected business or audit access MUST occur

## Unresolved Normative Gaps

None for authorization matrix version 0.4. Operations and relationships absent from that matrix remain denied rather than inferred.
