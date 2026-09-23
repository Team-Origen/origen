# Issue 60: Verificar permisos y errores de administración interna

## Outcome
Verify and enforce that other roles (Secretary, Professional, Patient, anonymous, or non-active accounts) cannot create internal accounts, strictly upholding the authorization matrix and boundaries defined in #44 (PLN-11 / Father Issue #44) and demonstrating failure recovery, helpful errors, and accessible UI behavior without production data.

## Scope & Constraints
- Subissue: #60 (Father Issue: #44).
- Boundary: Domain authorization verification and UI access protection ensuring only active administrators can create internal accounts.
- Budget: Strictly <= 400 lines per PR (split into 2 stacked PRs: PR 1 Domain Matrix & Authorization, PR 2 UI Permissions & Error UX).

## Stacked PR Plan
1. **PR 1/2 (`feature/60-admin-permissions-matrix` -> `develop`):**
   - Formal authorization engine tests covering Default-Deny for all unauthorized roles on `:create_professional_account` and `:create_secretary_account`.
   - Comprehensive domain verification in `Origen.Accounts` proving that Secretary, Professional, and inactive administrators are rejected with `{:error, :unauthorized}` without side effects.
2. **PR 2/2 (`feature/60-admin-ui-permissions-errors` -> `feature/60-admin-permissions-matrix`):**
   - Web-layer protection and LiveView event denial for non-administrators.
   - Verification of useful error messages, focus preservation, and accessible keyboard navigation under failure scenarios.
   - Sanitized evidence and PR linkage (`Closes #60`).

## Tasks
- [x] 1. Branch setup: create `feature/60-admin-permissions-matrix` from `develop`.
- [x] 2. Authorization matrix tests: add exhaustive negative test cases in `test/origen/authorization_test.exs` proving default-deny for non-administrators and non-active states.
- [x] 3. Domain verification tests: create `test/origen/accounts/admin_permissions_verification_test.exs` validating transactional boundaries, zero side-effects, and opaque denials for unauthorized roles.
- [x] 4. PR 1/2: open stacked PR 1/2 against `develop` (<= 400 lines) and verify CI checks.
- [x] 5. Branch setup 2: create `feature/60-admin-ui-permissions-errors` from PR 1 branch.
- [x] 6. LiveView protection & tests: verify UI rejection, redirects, focus preservation, and accessibility.
- [x] 7. PR 2/2: open stacked PR 2/2 against PR 1 branch (<= 400 lines), provide evidence, and verify CI checks.

## Verification Evidence
- **Domain Authorization Matrix:** `mix test test/origen/authorization_test.exs test/origen/accounts/admin_permissions_verification_test.exs` (15 passed, 0 failures).
- **Accounts Context:** `mix test test/origen/accounts_test.exs` (27 passed, 0 failures).
- **LiveView UI & Access Control:** `mix test test/origen_web/live/admin_internal_live_test.exs` (26 passed, 0 failures).
- **Sanitized Scenarios Verified:**
  - `Secretary` attempting to create `Professional` -> Form select excludes Professional; raw event payload rejected with validation error / unauthorized.
  - `Secretary` attempting to create `Secretary` -> Denied by domain and LiveView with `"No tiene permiso para realizar esta acción"`. Zero database modifications.
  - `Professional` attempting direct mount of `/admin/internal` -> Redirected immediately to `/`.
  - `Patient` attempting direct mount of `/admin/internal` -> Redirected immediately to `/`.
  - `Unauthenticated` visitor attempting direct mount of `/admin/internal` -> Redirected immediately to `/`.
  - `Duplicate Email` -> Rejected with `"Ya existe una cuenta con este correo electrónico"`. Input values preserved.
  - `Accessibility` -> `role="status"` for success feedback, `role="alert"` for error feedback. Input IDs and focus preserved.

