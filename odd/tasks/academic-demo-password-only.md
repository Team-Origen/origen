# Academic demo: password-only internal sign-in

Objective: let professors sign in as internal staff with email and password only, behind an opt-in flag that only the Render instance enables.
Branch: `feat/academic-demo-password-only` (base `develop`). Delivery: single draft PR, `Refs #292`. Test runner: `mix test`.

## Specs

- S1. Flag `ORIGEN_ACADEMIC_DEMO_PASSWORD_ONLY=true`, off by default, read in `config/runtime.exs`. Any other value keeps it off.
- S2. With the flag on, internal login (`Origen.Accounts.authenticate_internal_account/4`, `InternalSessionController`, its template) neither requires nor shows the TOTP code. The password stays mandatory; audit and the existing account checks (active state, allowed role) stay.
- S3. With the flag on, internal invitation activation (`InternalActivationController`) and first-administrator activation (`AdminActivationController`) do not require TOTP enrollment. The TOTP secret is still generated and stored encrypted (the `internal_accounts_state_fields_check` constraint requires it for active accounts), without asking for the code or showing the QR.
- S4. With the flag off, everything behaves exactly as today: one test per new rule and one regression test per touched flow (login and both activations).
- S5. `render.yaml` sets the flag (`value: "true"`); `docs/deployment/RENDER.md` documents it as a deliberate security gap for fictitious data only, and how professor accounts are created (first admin via `bin/issue_admin_invitation`, then invitations from `/administrador/cuentas`).
- Out of scope: patients and magic link (handled by SantiCasali).

## Tasks

- T1 (S1-S4) inline: flag, login and both activations, tests. Status: done (af002af). RED observed: 9 new demo tests and 2 runtime.exs tests failed before the change.
- T2 (S5) inline: render.yaml and Render docs. Status: done (this commit).

## Log

- L1 (2026-11-12, user, verbatim): "Les vamos a dar usuarios a mis profes para que los puedan usar, la cuestión, para eliminar todo tipo de fricción, vamos a sacar magic link (...) y el autenticador, así simplemente les damos gmail y contraseña y listo. Osea la idea es desactivarlo solo para estas pruebas." Then: "solo como personal interno".
- L2: Verified `internal_accounts_state_fields_check` requires `totp_secret` for active accounts, so activation keeps generating and storing the encrypted seed. Internal login has no lockout logic beyond active state and role checks; audit is kept. Invitations are not mailed: `/administrador/cuentas` shows the activation link on screen to copy and share.
- L3: Checks: `mix test` 1223 passed, 0 failed; format, `compile --warnings-as-errors`, sobelow and dialyzer pass. Risk: item 2 (security).
