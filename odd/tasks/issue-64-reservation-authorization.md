# Issue 64: Implementar autorización por actor para la operación de reserva

## Outcome

Implement backend actor authorization rules for appointment booking in Origen, differentiating permissions, required states, and validations for Patient, Secretary, and Professional actors.

## Problem

Anyone attempting to book an appointment must be validated according to who they are and who they are booking for:
- Autonomous Patients must only book for themselves, have a completed profile, and a verified primary phone.
- Assisted Secretaries can book within RF-02 limits with explicit schedule agreement.
- Professionals can only book for patients in their permitted list (prior established relationship).

## Why

Centralizing and enforcing actor authorization prevents unauthorized appointment creation, ensures patient contactability for reminders, and respects professional patient boundaries.

## Authorized scope

- Actor authorization logic in `lib/origen/booking/authorization.ex` and `lib/origen/booking.ex`.
- Integration and unit test suite in `test/origen/booking/authorization_test.exs`.
- Local branch: `feature/64-reservation-authorization`.
- Pull Request: [PR #167](https://github.com/Team-Origen/origen/pull/167).

## Checklist

- [x] ODD-64-01 — Enforce Patient rules: own identity (`actor.id == patient_id`), completed profile (`state == "completed"` / `:perfil_incompleto`), and verified phone (`phone_verified == true` / `:telefono_no_verificado`).
- [x] ODD-64-02 — Enforce Secretary rules: active internal account with role `secretary` and schedule agreement (`patient_agreed_schedule == true` / `:acuerdo_horario_requerido`).
- [x] ODD-64-03 — Enforce Professional rules: active internal account with role `professional`, own agenda, and patient in permitted list (`RF-05` / `:paciente_no_permitido`).
- [x] ODD-64-04 — Implement default-deny authorization on unrecognized roles or invalid payloads (`:unauthorized`).
- [x] ODD-64-05 — Unit and integration test coverage with 20 tests.

## Acceptance criteria

- [x] Applies backend rules corresponding to Patient, Secretary, and Professional.
- [x] Requires own completed profile and verified phone for autonomous Patient booking.
- [x] Allows assisted Secretary route within RF-02 boundaries.
- [x] Restricts Professional to patients in their permitted list.

## Applicable checks

- `mix test test/origen/booking/authorization_test.exs` (20 passed).
- `mix test` (517 passed, 29 skipped, 8 excluded).
- `mix format --check-formatted` (clean).

## Progress and evidence

- Commit: `09b76d1` (`Closes #64`).
- Pull Request: [PR #167](https://github.com/Team-Origen/origen/pull/167).
- Verified by `gentle-ai-verify` subagent.
