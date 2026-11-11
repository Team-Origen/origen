# Operator CLI for the first Administrator invitation

Objective: let an operator create the first pending Administrator in the Render `prod` instance and get its one-time activation link, without email delivery or two-person approval (simplified alternative to #452, accepted by the team).
Branch: `feat/admin-invitation-cli` (base `develop`). Delivery: single PR. Test runner: `mix test`.

## Specs

- S1 — User request (option 2): "Un comando que cree el admin `Pendiente de activación` y te muestre el link de activación", reusing the existing invitation logic; the holder opens the link, sets a password and enrolls TOTP; it stays in the audit log. No two-person approval or signed assertion.
- S2 — Disabled by default: the command refuses before reading arguments unless `ORIGEN_OPERATOR_INVITATION_ENABLED=true` is set for that invocation. The web service never sets it.
- S3 — First issue only creates an Administrator when none exists (existing `admin_bootstrap_controls` lock + `administrator_exists?`). `--account-id N` reissues for a still-pending account and revokes its previous invitation; an active account is refused.
- S4 — Output: account reference (login identifier), invitation expiry and the activation link `https://<host>/administrador/activar#invitation_id=..&token=..`. Errors print only a safe reason, never the token or key.
- S5 — A handoff audit event is appended; if it cannot be written, the invitation is revoked.
- S6 — Runnable from the release image (`bin/issue_admin_invitation`) against the Render database over TLS (`DATABASE_SSL=true`).
- Assumption: the activation page and login already work in `:prod` with `ORIGEN_VERIFIER_KEY` and `ORIGEN_TOTP_KEY`.

## Tasks

| ID | Specs | Route | Status | Commit |
| --- | --- | --- | --- | --- |
| T1 | S1–S5 | inline | in progress | — |
| T2 | S6 | inline | pending | — |

## Log

- L1 (2026-11-11, user): "Mira, la verdad que es bastante lío, quizas simplemente podriamos hacer un script que sirva para crear admins." Then: "sí, dale con la opción 2."
- L2: Login accepts email or numeric account id; the bootstrap account has no email, so the account id is the login identifier.
