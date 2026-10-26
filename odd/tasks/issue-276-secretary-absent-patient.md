# Task: Issue #276 — Registrar paciente inexistente desde Secretaría

## OpenSpec Traceability

- Change: `health-center-beta-core`
- Path: `openspec/changes/health-center-beta-core/`
- Scope: Implementation slice 01 of 17 (Sprint 3)
- Tracking Issue: https://github.com/Team-Origen/origen/issues/276
- Sub-issues:
  - #293: Contrato — Alta de paciente desde Secretaría (`work:contract`)
  - #294: Backend — Alta de paciente desde Secretaría (`work:backend`)
  - #295: Frontend — Alta de paciente desde Secretaría (`work:frontend`)
  - #296: Integración y verificación — Alta de paciente desde Secretaría (`work:integration`)
- Branch: `feat/276-secretary-absent-patient`

## Description

Secretaría busca un DNI y registra un paciente inexistente para usarlo en la operación asistida.
Garantiza la unicidad de DNI, exige datos mínimos (nombre, apellido, DNI, fecha de nacimiento, teléfono)
dejando el correo opcional y compartible, sin exigir teléfono verificado y sin crear acceso personal (magic link) automático.

## Acceptance Criteria

- [x] Búsqueda previa obligatoria antes de crear, conservando unicidad estricta de DNI.
- [x] Exige nombre, apellido, DNI, fecha de nacimiento y teléfono; correo opcional y compartible.
- [x] No crea acceso personal automático ni exige teléfono verificado.
- [x] Autorización estricta: accesible por Secretaría activa; administrador sin acceso operativo implícito, conforme al diseño beta.
- [x] Suite de pruebas que demuestre alta asistida, rechazo de DNI duplicado, datos faltantes y ausencia de cuenta de usuario automática.

## Planned Steps

1. [x] **Subissue #293 (Contrato)**: Auditar código existente (`Origen.Patients`, `SecretaryPatientLive`, tests) vs `specs/patient-identity-and-access/spec.md`, definir matriz de reutilización/adaptación/creación/reemplazo, precisar contrato formal (entradas, salidas, errores, permisos) y documentarlo en `docs/sprints/contracts/293-alta-paciente-secretaria.md`.
2. [x] **Subissue #294 (Backend)**: Implementar/adaptar en `Origen.Patients` las operaciones de búsqueda y alta asistida conforme al contrato, asegurando unicidad de DNI, campos obligatorios, correo opcional, sin creación de credenciales/cuentas ni verificación forzada de teléfono. Pruebas de contexto en `test/origen/patients/secretary_search_test.exs`.
3. [x] **Subissue #295 (Frontend)**: Adaptar `OrigenWeb.SecretaryPatientLive` para el flujo de Secretaría: búsqueda de DNI, visualización de paciente no encontrado, formulario de alta asistida acorde al contrato y feedback visual. Pruebas de LiveView en `test/origen_web/live/secretary_patient_live_test.exs`.
4. [x] **Subissue #296 (Integración y verificación)**: Recorrido completo real Secretaría -> Búsqueda -> Alta asistida -> Paciente listo para agendar. Pruebas integradas de todos los criterios de #276, resolución de fallas encontradas y registro de evidencia final.

## Implementation Notes

- Resumed: implementation and acceptance review in progress. Existing changes are preserved.
- Route: delegated writer for multi-file behavior/test corrections; independent verifier for CI. Engram unavailable; this file is the continuity record.
- Work units: (1) acceptance corrections with focused tests, (2) full local CI and independent verification, (3) conditional publication and PR.
- Confirmed review targets: server-side binding to unsuccessful search, optional gender, string-key document defaults, and revoked authorization handling.
- Delivery: user authorized PR only after tests and CI pass. No publication with pending or failed checks. Existing diff exceeds 800 authored lines; delivery shape must be resolved before committing.
- RDD is disabled globally. Native review will not be started.
- Unrelated pre-existing sprint documents and mise.toml must not be bundled automatically.

## Validation Evidence

- Acceptance corrections verified by delegated writer: schema default mixed-key bug, optional gender, server-owned unsuccessful-search binding, revoked-role handling.
- Observed RED: Ecto.CastError for string keys; required gender assertion; seven forged/stale registration cases; revoked search CaseClauseError. Each became GREEN after its corresponding fix.
- Final focused check: `mix test test/origen/patients/secretary_search_test.exs test/origen_web/live/secretary_patient_live_test.exs test/origen/patients_test.exs` — 44 tests, 0 failures after formatting.
- `git diff --check` passed. Test database confirmed localhost:5433/origen_test.
- Native read-only risk assessment unavailable due to undeclared untracked files; conservative independent verification required. RDD stays off.
- Full CI and migration safety review are in progress. No commit or publication yet.
