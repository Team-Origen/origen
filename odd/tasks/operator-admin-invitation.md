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
| T1 | S1–S5 | inline | done | 6c089ab, 39cd7ea |
| T2 | S6 | inline | done | 6c089ab (script, DATABASE_SSL), docs commit |
| T3 | S1 (activation in prod) | inline | done | ed4c24d |

## Log

- L1 (2026-11-11, user): "Mira, la verdad que es bastante lío, quizas simplemente podriamos hacer un script que sirva para crear admins." Then: "sí, dale con la opción 2."
- L2: Login accepts email or numeric account id; the bootstrap account has no email, so the account id is the login identifier.
- L3: HTTP end-to-end against the release image (prod config, postgres:17): link exchange 302, TOTP enrollment shown, password+TOTP 302, account active, login with account id 302 to /administrador/cuentas, replayed link 404; audit bootstrap_admin, invitation_delivery_handoff, account_activation, internal_login.
- L4: Found pre-existing bug: in :prod AdminActivationController read only :bootstrap_admin_totp_keyring while runtime.exs sets :totp_keyring, so activation always returned 422. Fixed to resolve like Origen.Accounts (T3, RED observed first).
- L5: Checks: mix test 1206 passed (one unrelated flaky failure in a first run, not reproduced in two reruns); format and compile --warnings-as-errors clean.
