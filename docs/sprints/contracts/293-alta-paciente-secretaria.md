# Contrato y Reglas: Alta de paciente inexistente desde Secretaría (#276 / #293)

**Estado: Aprobado para implementación (#293).** Este documento formaliza el contrato, reglas de negocio y escenarios para [#276](https://github.com/Team-Origen/origen/issues/276) y prepara [#294 (Backend)](https://github.com/Team-Origen/origen/issues/294), [#295 (Frontend)](https://github.com/Team-Origen/origen/issues/295) y [#296 (Integración)](https://github.com/Team-Origen/origen/issues/296).

---

## 1. Identificación y Trazabilidad

- **OpenSpec Change:** `health-center-beta-core`
- **Ruta OpenSpec:** `openspec/changes/health-center-beta-core/`
- **Sección canónica:** `specs/patient-identity-and-access/spec.md` (Requisito: *Assisted identity and unique patient*)
- **Fronteras y exclusiones:** `specs/beta-boundaries/spec.md`
- **Issue Padre:** [#276 — [Plan]: Registrar paciente inexistente desde Secretaría](https://github.com/Team-Origen/origen/issues/276)
- **Subissue activa:** [#293 — [Plan]: #276 · Contrato — Alta de paciente desde Secretaría](https://github.com/Team-Origen/origen/issues/293) (`work:contract`)
- **Responsable:** Saidqr (Said Quioto)
- **Rama Git:** `feat/276-secretary-absent-patient`

---

## 2. Estado de Verificación Actual del Repositorio

En cumplimiento con la `docs/sprints/GUIA_TRABAJO_BETA.md`, se distingue explícitamente entre código encontrado, pruebas leídas y pruebas ejecutadas:

### 2.1 Código Encontrado
* `lib/origen/patients.ex`:
  * `search_persona_by_document/3`: Busca personas por tipo y documento normalizado, recupera el perfil enlazado y audita el evento con actor secretaría activa. Deniega acceso si el actor no es secretaría activa.
  * `register_absent_patient/2`: Inserta `Persona` y genera un `PatientProfile` asociado sin exigir email ni crear cuenta de acceso personal (`email: nil`), guardando correo de contacto opcional en `contact_email` y auditando la operación.
* `lib/origen/patients/persona.ex`:
  * Schema `personas`: `first_name`, `last_name`, `document_type`, `document_number`, `birthdate`, `gender`. `assisted_changeset/2` valida obligatoriedad de nombre, apellido, documento, fecha en pasado y teléfono no vacío. Restricción única en `(document_type, document_number)`.
* `lib/origen/patients/patient_profile.ex`:
  * Schema `patient_profiles`: `email` (nullable, índice único parcial donde `email IS NOT NULL`), `contact_email`, `phone`, `phone_verified` (false), `state` (`completed`), `persona_id`.
* `lib/origen_web/live/secretary_patient_live.ex`:
  * Montaje restringido a rol `:secretary` (denegación/redirección para otros roles o administradores conforme a `design.md`). Búsqueda previa obligatoria antes de habilitar el alta asistida (`registration_matches_search?`).
* `priv/repo/migrations/20260930100000_allow_nullable_email_and_shared_contact.exs`:
  * Migración reversible que permite `email` nulo en perfiles de pacientes creados de forma asistida y agrega columna `contact_email`.

### 2.2 Pruebas Leídas y Ejecutadas con Resultado Observado
* **Comando ejecutado:**
  `mix test test/origen/patients/secretary_search_test.exs test/origen_web/live/secretary_patient_live_test.exs test/origen/patients_test.exs`
* **Resultado:**
  `44 passed, 0 failures` (38 pruebas en el flujo de búsqueda/alta de secretaría + 6 en el contexto general de pacientes).
* **Diagnóstico:** El comportamiento observable verifica todos los criterios de la especificación beta core: búsqueda previa obligatoria, unicidad estricta de DNI, teléfono obligatorio, correo opcional y compartible, sin credenciales de acceso ni verificación telefónica forzada.

---

## 3. Matriz de Análisis frente a la Beta (`health-center-beta-core`)

| Aspecto | Estado Actual (Código histórico) | Requisito Beta Aprobado | Acción requerida |
| :--- | :--- | :--- | :--- |
| **Búsqueda previa** | Existía búsqueda por documento sin atar el formulario. | Obligatoria antes de registrar; garantiza no duplicación. | **Adaptado** (LiveView ata el formulario a búsqueda no encontrada previa; validación en backend contra DNI único). |
| **Normalización de DNI** | Quita puntos, espacios y guiones (`normalize_number/1`). | DNI normalizado y único. | **Reutilizado** |
| **Campos obligatorios** | Validaba `first_name`, `last_name`, `birthdate` en Persona. | Nombre, apellido, DNI, fecha de nacimiento y teléfono obligatorios en la operación de alta. | **Adaptado** (`Persona.assisted_changeset/2` exige y valida teléfono en el backend). |
| **Correo de contacto** | Exigía correo único en `PatientProfile`; si faltaba, autogeneraba `@origen.local`. | Correo es opcional, de contacto y **compartible** (no cuenta de acceso). | **Adaptado** (columna `contact_email`, `email` en `nil` para alta asistida, índice único parcial). |
| **Acceso personal** | El alta generaba perfil que simulaba cuenta con `pending_completion`. | El alta asistida **NO** crea acceso personal (sin magic link, sin cuenta). El acceso personal se vincula en #277. | **Reemplazado** (perfil queda en `completed` para uso asistido sin cuenta). |
| **Verificación telefónica** | Flag `phone_verified: false` en perfil; antes existían bloqueos por verificación. | **Prohibido** exigir teléfono verificado para operar o registrar. | **Reutilizado** (`phone_verified` permanece en false sin bloquear nada). |
| **Autorización** | Permitía `:secretary` y `:administrator` sólo en LiveView. | `design.md` excluye acceso operativo implícito de Administrador; sólo Secretaría en este recorrido. | **Adaptado** (autorización tanto en servidor como en LiveView; rechazo con `{:error, :unauthorized}`). |
| **Feedback en UI** | Mostraba estado "Pendiente de completar". | Mostrar paciente registrado listo para la atención/reserva, sin transmitir que está incompleto por falta de cuenta web. | **Adaptado** |

---

## 4. Contrato Formal de Dominio y Operaciones

### 4.1 Operación de Búsqueda
* **Función:** `Origen.Patients.search_persona_by_document(document_type, document_number, actor_account_id)`
* **Entradas:**
  * `document_type`: string, típicamente `"dni"`.
  * `document_number`: string con el DNI ingresado (se normaliza eliminando espacios, puntos y guiones).
  * `actor_account_id`: identificador de cuenta interna activa con rol Secretaría (deniega cualquier otro rol).
* **Salidas:**
  * Si existe: `{:ok, %{persona: %Persona{}, profile: %PatientProfile{} | nil}}`
  * Si no existe: `{:ok, nil}`
  * No autorizado: `{:error, :unauthorized}`
* **Auditoría:** Registra evento `persona_searched` con actor Secretaría y entidad `"dni:<numero_normalizado>"`.

### 4.2 Operación de Alta Asistida
* **Función:** `Origen.Patients.register_absent_patient(attrs, actor_account_id)`
* **Entradas obligatorias en `attrs`:**
  * `first_name`: string no vacío (trim).
  * `last_name`: string no vacío (trim).
  * `document_type`: `"dni"`.
  * `document_number`: string de 1 a 32 caracteres alfanuméricos.
  * `birthdate`: date (`Date.t()`) en el pasado.
  * `phone`: string no vacío con el teléfono de contacto (puede ser compartido).
* **Entradas opcionales en `attrs`:**
  * `email`: string opcional con correo de contacto (puede ser compartido, no valida unicidad de cuenta de acceso).
  * `gender`: string opcional (del catálogo permitido).
* **Salidas:**
  * Éxito creación: `{:ok, %{persona: %Persona{}, profile: %PatientProfile{}, outcome: :created}}`
  * DNI duplicado: `{:error, changeset}` con error en `:document_number` (`"ya ha sido registrado"`).
  * Validación fallida: `{:error, changeset}` indicando los campos faltantes o inválidos.
  * No autorizado: `{:error, :unauthorized}` si el actor no es una cuenta activa de Secretaría.
* **Garantías de la operación:**
  * Transacción atómica: si falla la inserción de persona o perfil, se hace rollback completo sin efectos secundarios.
  * No genera tokens de magic link ni sesiones personales.

---

## 5. Escenarios Formales Acordados

### Escenario 1: Búsqueda exitosa de paciente existente
- **GIVEN** una secretaria autenticada busca el DNI `"35.987.654"`
- **AND** ya existe un paciente registrado con DNI `"35987654"`
- **WHEN** se ejecuta la búsqueda
- **THEN** el sistema devuelve los datos del paciente encontrado
- **AND** no permite registrar una nueva persona con ese DNI.

### Escenario 2: Alta asistida de paciente inexistente con datos mínimos
- **GIVEN** una secretaria busca el DNI `"40.123.456"` y el sistema confirma que no existe
- **WHEN** la secretaria completa:
  - Nombre: `"Lucía"`
  - Apellido: `"Gómez"`
  - DNI: `"40.123.456"`
  - Fecha de nacimiento: `"1995-04-12"`
  - Teléfono: `"+5491133221100"`
  - Correo: *(en blanco / omitido)*
- **THEN** el sistema registra al paciente de forma persistente y atómica
- **AND** conserva `phone_verified: false` sin bloquear su uso
- **AND** no crea credenciales ni enlaces de acceso personal
- **AND** el paciente queda disponible para ser utilizado en el flujo asistido.

### Escenario 3: Alta asistida con correo y teléfono compartidos
- **GIVEN** ya existe un paciente con teléfono `"+5491133221100"` y correo de contacto `"familia@example.com"`
- **WHEN** la secretaria registra a otro paciente con diferente DNI pero mismo teléfono y correo
- **THEN** el registro se completa exitosamente
- **AND** no se produce colisión de unicidad por correo o teléfono.

### Escenario 4: Rechazo por DNI duplicado
- **GIVEN** existe un paciente con DNI `"35987654"`
- **WHEN** se intenta registrar un alta asistida enviando el DNI `"35.987.654"`
- **THEN** la operación es rechazada por documento duplicado
- **AND** no se crean perfiles ni personas duplicadas.

### Escenario 5: Rechazo por datos incompletos
- **GIVEN** una secretaria envía el formulario de alta omitiendo el teléfono o la fecha de nacimiento
- **WHEN** se procesa la solicitud
- **THEN** la operación retorna un changeset inválido con mensajes legibles por campo
- **AND** no se persiste ningún registro parcial.

---

## 6. Fronteras y Exclusiones (Out of Scope)

* **Reserva de turnos:** Este contrato no crea reservas ni slots (corresponde a #281).
* **Acceso personal y Magic Links:** No se gestiona autenticación de pacientes ni envío de enlaces mágicos (corresponde a #277).
* **Canal WhatsApp o SMS:** Excluidos explícitamente por la especificación beta.
* **Verificación obligatoria de teléfono:** No se exige OTP ni confirmación de número para el alta.

---

## 7. Registro de Aprobación

* **Estado:** Aprobado para implementación y verificación.
* **Evidencia reproducible:** 44 pruebas ejecutadas y aprobadas exitosamente (`test/origen/patients/secretary_search_test.exs`, `test/origen_web/live/secretary_patient_live_test.exs` y `test/origen/patients_test.exs`).
* **Trazabilidad:** Resuelve el contrato de #293 y sienta las bases de validación para #294, #295 y #296.
