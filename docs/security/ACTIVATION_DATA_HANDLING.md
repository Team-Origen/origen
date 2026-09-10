# Keep Administrator activation data out of observability systems

Treat the complete activation request as sensitive. Application parameter filtering is defense in depth; ingress, proxy, APM, exception, mail, and support systems must redact or avoid collecting the data before the activation route is exposed.

## Data that must never reach a sink

Do not record or emit passwords or confirmations, invitation tokens, full activation URLs, TOTP seeds or codes, QR payloads, recovery codes, session or cookie values, verifier digests, encryption/verifier keys, or request bodies containing them. Token-like values must not be repurposed as actor, account, or invitation references.

Allowed lifecycle evidence is limited to the typed event/result, actor kind and non-secret reference, target account ID, invitation record ID, and server timestamp.

## Edge and observability checklist

| Boundary | Required control | Verification evidence |
| --- | --- | --- |
| TLS/ingress | Reject plain HTTP for activation. Do not terminate TLS onto an unprotected network segment. Preserve the application-visible HTTPS scheme only from trusted proxies. | Plain HTTP is rejected; HTTPS reaches the endpoint with the expected scheme. |
| Access logs | Disable query-string and request-body capture for activation paths. Log only method, route template, status, timing, and a non-secret request ID. | A canary activation leaves no token, URL fragment, body, cookie, or authorization value in edge logs. |
| Headers/cookies | Drop or redact `cookie`, `set-cookie`, `authorization`, and forwarded header values before logging or exporting spans. | Searches across ingress/APM/error stores return no canary value. |
| APM/tracing | Disable body capture and raw URL capture. Use the route template, not the full URL. Do not attach controller params, session data, SQL bind values, email bodies, or returned ciphertext as span attributes. | Exported traces contain only allowlisted metadata. |
| Exceptions | Disable local-variable, process-state, request-body, and session capture on this route. Sanitize exception messages before reporting. | Forced invalid/expired submissions report a generic failure without sensitive values. |
| Mail/support | Do not retain raw invitation tokens or activation URLs in mail previews, delivery diagnostics, tickets, chat, screenshots, or analytics. | The current task delivery contains account/invitation references only. A future token channel has separately reviewed retention and access controls. |
| Database telemetry | Do not export SQL bind parameters for bootstrap/activation statements. | Query telemetry contains operation/timing metadata but no values. |

Phoenix's `:filter_parameters` list covers known parameter names inside application logs, but it cannot sanitize copies already captured by an upstream proxy, APM agent, browser analytics SDK, or exception reporter. Verify each deployed component independently.

## Provider storage and callback boundary

A transactional provider is acceptable only after security records non-secret evidence references for encryption in transit and at rest, a finite approved queue/retry TTL, least-privilege identities, audited access, preview/body-capture restrictions, bounded retry semantics, and approved purge behavior. Credentials resolve only inside the adapter at handoff and must never appear in configuration dumps or evidence.

Terminal callbacks are required unless provider acceptance is contractually terminal. Callback ingress must authenticate the raw body and timestamp, allowlist event types, validate signed invitation correlation, avoid body/header logging, and reject replay. Current replay tracking is **node-local** and in-memory with **no time-based pruning**. Staging is blocked until operations supplies **ingress affinity or shared replay** enforcement and an approved retention/pruning policy.

## Synthetic canary search

Use a deliberately non-secret marker, never a real token or address. Security and operations must record search-result references for every system:

- ingress/proxy and application logs;
- APM traces and span attributes;
- exception reports, local-variable capture, and crash diagnostics;
- SQL telemetry/binds and database diagnostics;
- provider queue, diagnostics, previews, access audit, and support console;
- analytics, support tickets/chat, screenshots, and exported artifacts.

Any prohibited-sink hit blocks release. Restrict the affected store, keep bootstrap/provider/callback/activation surfaces disabled, follow incident/rotation procedures, and repeat the full search after remediation.

## Release gate

The packaged `bin/origen_bootstrap_admin` command and source-checkout Mix task call the same fail-closed gate before bootstrap argument parsing or I/O. Production-compiled releases always deny the command. Verifier keys and other secrets must come from the runtime secret provider, never argv; command output is reference-only.

Security approval to expose activation requires retained evidence for every checklist row. Until then:

- keep `ORIGEN_BOOTSTRAP_ADMIN_ENABLED` absent or `false`;
- do not expose the activation route at ingress;
- do not use real identities or operational data; and
- do not claim production readiness.

After a successful non-production activation, repeat the canary search across edge logs, application logs, traces, exception reports, mail diagnostics, and support tools. Any sensitive hit is a release blocker: disable the bootstrap and ingress surface, restrict the affected store, follow the incident/rotation process, and do not resume until independent verification is clean.
