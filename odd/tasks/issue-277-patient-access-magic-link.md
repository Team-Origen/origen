# Task: Issue #277 — Vincular acceso de paciente por magic link

## OpenSpec Traceability

- Change: `health-center-beta-core`
- Path: `openspec/changes/health-center-beta-core/`
- Scope: Implementation slice 02 of 17 (Sprint 3)
- Tracking Issue: https://github.com/Team-Origen/origen/issues/277
- Sub-issues:
  - #297: Contrato — Acceso de paciente por magic link (`work:contract`) — MERGED / CLOSED
  - #298: Backend — Acceso de paciente por magic link (`work:backend`) — MERGED / CLOSED
  - #299: Frontend — Acceso de paciente por magic link (`work:frontend`) — IN PROGRESS
  - #300: Integración y verificación — Acceso de paciente por magic link (`work:integration`) — PENDING
- Branch: `feat/299-patient-access-frontend`

## Description

El personal autorizado (Secretaría o Profesional) vincula o reemplaza el correo de acceso personal
de un paciente tras comprobación operativa de identidad fuera del sistema.
Garantiza unicidad de correo de acceso (`email` en `patient_profiles`), despacho de magic link
para prueba de posesión sin contraseña, invalidación atómica de enlaces anteriores y revocación
de sesiones activas ante reemplazos, preservando la identidad civil (`Persona`), turnos históricos
y privacidad estricta.

## Specs

- S1: El personal autorizado (`:secretary` o `:professional` activo) puede vincular un correo de acceso personal (`email`) a un paciente que tenga `email: nil`.
- S2: El rol Administrador tiene denegada la vinculación o reemplazo (`{:error, :unauthorized}`).
- S3: Si el correo ya está en uso por otro perfil de paciente, la vinculación o reemplazo se rechaza con `{:error, :email_already_in_use}`.
- S4: Si el paciente ya posee un correo vinculado, `link_patient_access_email/3` se rechaza con `{:error, :already_has_access_email}`.
- S5: El reemplazo de correo requiere motivo obligatorio no vacío (`reason`), de lo contrario se rechaza con `{:error, :reason_required}`.
- S6: El reemplazo por el mismo correo actual se rechaza con `{:error, :same_email}`.
- S7: El reemplazo invalida atómicamente todos los magic links pendientes no consumidos del correo anterior.
- S8: El reemplazo actualiza `sessions_invalidated_at` en el perfil del paciente para revocar sesiones web previas.
- S9: Tanto la vinculación como el reemplazo despachan automáticamente un Magic Link al nuevo correo para probar posesión.
- S10: Tanto la vinculación como el reemplazo registran eventos de auditoría sanitizados sin secretos (`patient_access_email_linked` y `patient_access_email_replaced`).
- S11: El reemplazo preserva íntegramente la identidad (`Persona`), sus datos civiles y sus turnos históricos.
- S12: La función `verify_patient_session/2` rechaza sesiones autenticadas antes de `sessions_invalidated_at`.

## Tasks

- [x] T1 (S8): Crear migración para agregar `sessions_invalidated_at` a `patient_profiles` y actualizar el schema `PatientProfile`.
- [x] T2 (S1, S2, S3, S4, S9, S10): Implementar `link_patient_access_email/3` en `Origen.Patients` con validación de staff, unicidad, envío de magic link y auditoría.
- [x] T3 (S1, S2, S3, S5, S6, S7, S8, S9, S10, S11): Implementar `replace_patient_access_email/4` en `Origen.Patients` con transacción atómica, invalidación de tokens previos, actualización de `sessions_invalidated_at`, despacho de magic link y auditoría.
- [x] T4 (S8, S12): Implementar `verify_patient_session/2` en `Origen.Patients`.
- [x] T5 (S1-S12): Escribir suite de pruebas completa en `test/origen/patients/patient_access_maintenance_test.exs` cubriendo escenarios C1 a C6 y C10 del contrato.
- [x] T6 (S1-S12): Ejecutar pruebas locales, validar formato con `mix format` y verificar sanidad de git diff.

## Validation Evidence

- Migración `20261022100000_add_sessions_invalidated_at_to_patient_profiles.exs` ejecutada exitosamente.
- Backend: `test/origen/patients/patient_access_maintenance_test.exs`: 16 pruebas aprobadas (0 fallas, exit 0, 0.7s).
- Frontend: `test/origen_web/live/secretary_patient_access_maintenance_test.exs`: 9 pruebas aprobadas (0 fallas, exit 0, 0.9s).
- Suite completa del repositorio: 840 pruebas aprobadas, 0 fallas, 30 skipped, 8 excluded (exit 0).
- `mix format --check-formatted`: verificado sin advertencias ni diferencias pendientes.
- `git diff --check`: comprobado sin espacios en blanco ni errores de formato.

## Log

- L1: Se inicia la subtarea #298 (Backend de #277) tras el cierre y mergeo del contrato #297 (PR #344).
- L2: Implementadas operaciones de backend y suite de pruebas conforme al contrato formal #297.
- L3: Backend #298 mergeado a develop mediante PR #362. Se inicia la subtarea #299 (Frontend).
- L4: Implementada interfaz de vinculación/reemplazo en SecretaryPatientLive y 9 pruebas de LiveView aprobadas.

