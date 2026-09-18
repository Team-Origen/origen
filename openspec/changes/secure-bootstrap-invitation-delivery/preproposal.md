# Pre-Proposal Decisions: Secure Bootstrap Invitation Delivery

## Confirmed Product Decisions

- Delivery channel: transactional email carrying the one-time activation link.
- Provider retention: encrypted, bounded queue/retry retention with an explicit TTL and audited access.
- Recipient authority: dual confirmation of Santiago's destination address and target environment before issuance.
- Delivery failure: revoke the failed invitation and require Samuel to issue a new invitation; never retry the same raw token ambiguously.
- Environment: the acceptance journey remains staging/non-production because the shared gate denies production.
- Research lane: unselected; the proposal will use existing project evidence and confirmed decisions.

## Confirmed Security Boundary

The raw token may exist transiently in process memory, the approved provider's bounded encrypted delivery queue, the delivered message, and Santiago's browser fragment. It must not enter CLI output, audit, errors, path/query parameters, redirects, database storage, telemetry, APM, access logs, analytics, or support artifacts.

## Proposal Readiness

Product decisions are confirmed, research is unselected, and the OpenSpec store is ready. Proposal may proceed without additional interviewing.
