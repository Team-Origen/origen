# Issue 87: Implementar completado del perfil propio del Paciente

## Outcome

Flujo completo de backend e interfaz para que el paciente autenticado mediante Magic Link complete su identidad documental (nombres, apellidos, documento controlado y fecha de nacimiento), garantizando la unicidad de Personas, la derivación de colisiones documentales a Secretaría sin vinculación automática y la preparación del perfil sin marcar el teléfono como verificado.

## Contexto y Alcance Autorizado

- Subissue ejecutable de #38 (PLN-05). Responsable: `@samuel-olmos`.
- Revisor: `@ChordanDev` (Lucca).
- Dominio: Paciente, Personas, Perfiles, Identidad, Seguridad.
- Límite de revisión: **Stacked PRs de ≤ 400 líneas** para asegurar legibilidad y control de carga de revisión.
- Estrategia de Stack:
  - **PR 1 (Backend Core):** Migraciones, modelos de Persona y Perfil de Paciente, lógica de negocio de unicidad y colisiones, y tests de dominio.
  - **PR 2 (Frontend LiveView):** Pantalla de completado con PetalComponents, manejo de estados (éxito y derivación) y tests de interfaz.

## Criterios de Aceptación

- [ ] Permite completar nombres, apellidos, documento controlado y fecha de nacimiento.
- [ ] Valida la unicidad documental sin vincular automáticamente coincidencias.
- [ ] Deriva colisiones documentales a revisión de Secretaría.
- [ ] Registra los datos obligatorios como completos sin marcar el teléfono como verificado; la habilitación final para reservar se resuelve en #90.

## Plan de Trabajo y Slices Encadenadas

### Stack PR 1: Backend Core e Identidad Documental
- **Ruta/Rama:** `feature/87-patient-profile-core` (Base: `develop`).
- **Objetivo:** Persistencia y reglas de negocio puras de identidad y perfiles de paciente.
- **Tareas:**
  - 1.1 Migración `create_personas_and_patient_profiles`: tablas `personas` (nombres, apellidos, tipo de documento controlado, número normalizado, fecha de nacimiento) y `patient_profiles` (cuenta de acceso, estado del perfil, `phone_verified: false`).
  - 1.2 Esquemas Ecto `Origen.Patients.Persona` y `Origen.Patients.PatientProfile`.
  - 1.3 Contexto `Origen.Patients`:
    - `complete_profile(patient_email, attrs, opts \\ [])`:
      - Normalización de documento y validación de tipos controlados (`dni`, `passport`, `identity_card`, `other`).
      - Si el documento no existe en ninguna Persona: crea o actualiza la Persona y asocia el perfil como `completed`.
      - Si el documento ya existe (colisión): **NO duplica la Persona** y **NO vincula automáticamente** la cuenta; marca el perfil como `pending_secretary_review` y registra la derivación a Secretaría.
      - Garantiza que `phone_verified` permanezca estrictamente en `false`.
  - 1.4 Constructores de auditoría en `Origen.Audit.Events`.
  - 1.5 Suite de pruebas en `test/origen/patients_test.exs` cubriendo todos los casos de unicidad, colisión y auditoría.
- **Presupuesto:** ≤ 400 líneas.

### Stack PR 2: Frontend LiveView con Petal Components
- **Ruta/Rama:** `feature/87-patient-profile-liveview` (Base: `feature/87-patient-profile-core`).
- **Objetivo:** Interfaz de usuario interactiva y responsiva para el paciente.
- **Tareas:**
  - 2.1 LiveView `OrigenWeb.PatientProfileCompletionLive` en `/patient/profile/complete`.
  - 2.2 Formulario reactivo (`phx-change` y `phx-submit`) con PetalComponents y paleta Origen (#0A3847, #35545A, #DDE6DB, #AFBAB4, #F6F6F4).
  - 2.3 Estado de confirmación de datos guardados y estado informativo de derivación a Secretaría ante colisión.
  - 2.4 Integración con la sesión establecida en #86 y redirección fluida.
  - 2.5 Tests de LiveView en `test/origen_web/live/patient_profile_completion_live_test.exs`.
- **Presupuesto:** ≤ 400 líneas.
