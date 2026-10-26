# Contrato #297: acceso de paciente por magic link y mantenimiento de correo

**Estado: formalizado y aprobado para preparación de backend e interfaz por Samuel Olmos (`samuel-olmos`).**
Este documento formaliza el contrato, reglas de negocio y escenarios para [#277](https://github.com/Team-Origen/origen/issues/277) y prepara [#298 (Backend)](https://github.com/Team-Origen/origen/issues/298), [#299 (Frontend)](https://github.com/Team-Origen/origen/issues/299) y [#300 (Integración y verificación)](https://github.com/Team-Origen/origen/issues/300). No implementa código de aplicación ni acredita el cierre definitivo de [#277](https://github.com/Team-Origen/origen/issues/277) o [#300](https://github.com/Team-Origen/origen/issues/300).

---

## 1. Alcance y Fuentes

- **Contrato:** [#297](https://github.com/Team-Origen/origen/issues/297), Sprint 3, issue padre [#277 — [Plan]: Vincular acceso de paciente por magic link](https://github.com/Team-Origen/origen/issues/277).
- **OpenSpec Change:** `health-center-beta-core`
- **Ruta OpenSpec:** `openspec/changes/health-center-beta-core/`
- **Alcance OpenSpec:** Sprint 3 / parent #277 / contract (Slice 02 de 17).
- **Sección canónica:** `specs/patient-identity-and-access/spec.md`:
  - Requisito: *Personal access and email maintenance*.
  - Requisito: *Assisted identity and unique patient*.
  - Requisito: *Identity corrections*.
- **Fronteras y exclusiones:** `specs/beta-boundaries/spec.md`:
  - Sin WhatsApp ni SMS.
  - Sin verificación obligatoria de teléfono para reservar.
  - Sin autoedición de datos o correo por parte del Paciente.
  - Sin notas clínicas ni historias clínicas.
- **Propuesta y Diseño:** `proposal.md` y `design.md`.
- **Guía de trabajo:** `docs/sprints/GUIA_TRABAJO_BETA.md` (distinción entre código, pruebas leídas, pruebas ejecutadas y desacoplamiento de subissues).

---

## 2. Estado de Verificación Actual del Repositorio

En cumplimiento con la `docs/sprints/GUIA_TRABAJO_BETA.md`, se distingue explícitamente entre código encontrado, pruebas leídas y pruebas ejecutadas:

### 2.1 Código Encontrado
* `lib/origen/patient_access.ex`:
  * Módulo de dominio para autenticación sin contraseña mediante Magic Link.
  * `request_magic_link/2`: Emisión de tokens criptográficamente seguros de 32 bytes en formato Base64 URL-safe, almacenamiento de su hash SHA-256 (`token_digest`), TTL por defecto de 900 segundos (15 minutos), invalidación atómica de tokens previos no consumidos para el mismo correo, entrega mediante `Origen.Mailer` (Swoosh) y auditoría sanitizada (`magic_link_issued`). Retorna siempre `{:ok, :delivered}` garantizando respuesta no enumeradora.
  * `consume_magic_link/2`: Bloqueo atómico con `FOR UPDATE`, validación de un solo uso (`consumed_at == nil`) y vigencia temporal (`now < expires_at`). Marca el token como consumido, audita `magic_link_consumed` (éxito) o `magic_link_failed` (fallo) y retorna `{:ok, %{email: email}}` o `{:error, :invalid_or_expired}`.
* `lib/origen/patient_access/magic_link.ex`:
  * Schema `patient_magic_links`: campos `email`, `token_digest`, `expires_at`, `consumed_at`, `created_at`.
* `lib/origen/patient_access/email.ex`:
  * Generación del correo con enlace `/access/verify?token=...` en HTML y texto plano.
* `lib/origen_web/live/patient_access_live.ex`:
  * LiveView montado en la ruta pública `/access`. Formulario con validación reactiva de formato de correo (`validate_format`) y respuesta opaca idéntica tras el envío que oculta si el correo existe o no en la base de datos.
* `lib/origen_web/controllers/patient_access_controller.ex`:
  * Endpoint `GET /access/verify?token=...`. Consume el enlace y, en caso de éxito, inicializa la sesión HTTP asignando `patient_email` en la cookie de sesión cifrada, redirigiendo con mensaje flash amigable. En caso de error o expiración, redirige a `/access` con flash de error genérico.
* `lib/origen/patients/patient_profile.ex`:
  * Schema `patient_profiles`: campo `email` que actúa como cuenta personal única (`unique_constraint(:email)`). En el diseño de alta asistida de #276 / PR #329 se incorpora además `contact_email` (opcional y compartible) y `email: nil` para pacientes sin cuenta personal.
* `lib/origen/patients/persona.ex`:
  * Schema `personas`: identidad civil única por `(document_type, document_number)`.
* `lib/origen/authorization/rules.ex`:
  * Matriz de autorización fail-closed con evaluación por reglas y hechos auditables.

### 2.2 Pruebas Leídas
* `test/origen/patient_access_test.exs`:
  * Cobertura de entrega segura, almacenamiento exclusivo de hash SHA-256 (nunca token en claro), invalidación de enlaces anteriores ante nueva emisión, respuesta no enumeradora para cualquier entrada, ausencia de secretos en la tabla de auditoría, consumo atómico exitoso, rechazo de reuso (un solo uso) y rechazo de tokens vencidos o corruptos.
* `test/origen_web/controllers/patient_access_controller_test.exs`:
  * Cobertura de verificación web: inicio de sesión en cookie `conn`, redirección a ruta de destino, rechazo de reuso y rechazo de tokens inválidos.
* `test/origen_web/live/patient_access_live_test.exs`:
  * Cobertura de interfaz: renderizado accesible, validaciones en tiempo real y mensaje de confirmación neutral.
* `test/origen/patients_test.exs`:
  * Cobertura de creación y asociación de paciente y perfil.

### 2.3 Ejecución Observada
* **Comando ejecutado:**
  ```sh
  ORIGEN_TEST_DB_USERNAME=postgres ORIGEN_TEST_DB_PASSWORD=12345 ORIGEN_TEST_DB_PORT=5432 \
    mix test test/origen/patient_access_test.exs \
             test/origen_web/controllers/patient_access_controller_test.exs \
             test/origen_web/live/patient_access_live_test.exs \
             test/origen/patients_test.exs
  ```
* **Resultado:**
  * **24 pruebas aprobadas**, 0 fallas.
  * Tiempo de ejecución: 0.8 s en `patient_access` + 0.5 s en `patients`.
  * Semilla ExUnit: `200482` / `485229`.
  * Etiquetas excluidas: `[postgres_security: true]`.
* **Diagnóstico:** Los módulos base de emisión, consumo, interfaz de `/access` y verificación web funcionan correctamente y verifican los supuestos de seguridad base (#193 y #85). Sin embargo, **no existen aún las operaciones de dominio de vinculación y reemplazo de correo por staff, ni la invalidación cruzada de sesiones anteriores ante cambio de correo**.

---

## 3. Matriz de Análisis frente a la Beta (`health-center-beta-core`)

| Aspecto | Estado Actual del Código | Requisito Canónico Beta | Acción Requerida |
| :--- | :--- | :--- | :--- |
| **Emisión y consumo de Magic Link** | `Origen.PatientAccess` implementa tokens seguros de 32 bytes con digest SHA-256 y TTL 15 min. | Acceso sin contraseña exclusivamente por enlace enviado al correo vinculado. | **Reutilizar** (`Origen.PatientAccess` es sólido y cumple el estándar). |
| **Distinción entre contacto y acceso** | Históricamente `email` mezclaba datos de contacto con cuenta. PR #329 agrega `contact_email`. | `contact_email` es libre, opcional y compartible (p. ej. familia). `email` es la cuenta de acceso personal única y no compartible. | **Adaptar / Clarificar** (definir que la vinculación de acceso opera sobre `email` de `patient_profiles`). |
| **Alta asistida sin acceso automático** | El alta de secretaría (#276) registra paciente con `email: nil`. | El alta asistida **NO** otorga acceso web ni emite enlace automáticamente. | **Reutilizado** (garantizado por el contrato de #293 y la implementación de #276). |
| **Vinculación de correo personal** | No existe función para que Secretaría o Profesional agreguen correo de acceso a un paciente asistido. | Personal autorizado (Secretaría o Profesional) puede vincular correo tras comprobación operativa externa. | **Crear** (`Origen.Patients.link_patient_access_email/3`). |
| **Comprobación de posesión del correo** | El envío de magic link existía sólo por solicitud autónoma en `/access`. | Al vincular o reemplazar un correo, el nuevo correo **debe** probar posesión completando el flujo de magic link. | **Adaptar / Crear** (el enlace emitido comprueba posesión y activa el acceso). |
| **Reemplazo de correo de acceso** | No existe flujo controlado de cambio de correo. | Reemplazar correo debe: 1) rechazar correos en uso por otro paciente; 2) preservar historial y `Persona`; 3) invalidar magic links pendientes; 4) invalidar sesiones activas previas; 5) auditar actor y fecha. | **Crear** (`Origen.Patients.replace_patient_access_email/4`). |
| **Invalidación de sesiones previas** | No había mecanismo de revocación de sesiones de paciente en base de datos. | Al reemplazar el correo, las sesiones anteriores del paciente deben quedar invalidadas. | **Crear** (mecanismo de epoch/timestamp de revocación en perfil o invalidación en controlador). |
| **Respuesta pública no enumeradora** | `/access` responde idéntico para cualquier correo. | La interacción pública no debe revelar existencia de DNI ni datos del paciente. | **Reutilizar / Sostener**. |
| **Autoedición del paciente** | Existía borrador de LiveView de perfil donde el paciente podía editar datos. | **Prohibido en Beta:** el Paciente puede consultar sus datos e historial, pero **NO** puede auto-editar su correo ni su identidad. | **Exclusión respetada** (la edición es potestad exclusiva de staff autorizado). |

---

## 4. Reglas de Negocio y Flujo Operativo

### 4.1 Comprobación Operativa Fuera del Sistema
1. El sistema no automatiza validación biométrica ni llamadas externas de identidad para el alta de credenciales.
2. La Secretaría o el Profesional deben realizar la **comprobación operativa de identidad fuera del sistema** (verificación presencial del DNI físico o canal telefónico verificado previamente) antes de registrar o cambiar el correo de acceso personal de un paciente.
3. El sistema asume que la invocación de las funciones de vinculación y reemplazo proviene de un operador que ya realizó dicha comprobación.

### 4.2 Vinculación Inicial de Correo de Acceso Personal
1. Aplica sobre pacientes existentes registrados previamente de forma asistida (con `email: nil`).
2. La Secretaría o el Profesional ingresan el correo de acceso personal del paciente.
3. El sistema valida:
   - Que el paciente exista.
   - Que el paciente no tenga ya un correo de acceso vinculado (en tal caso corresponde reemplazo).
   - Que el formato del correo sea válido.
   - Que el correo no pertenezca ya a otra cuenta de paciente (unicidad estricta en `patient_profiles.email`).
4. Al asociar el correo:
   - Se mantiene intacta la `Persona` y su historial de turnos y relaciones.
   - Se emite automáticamente un Magic Link al nuevo correo para que el paciente confirme posesión.
   - Se audita el evento con actor, paciente, correo y timestamp.

### 4.3 Reemplazo de Correo de Acceso Personal
1. Aplica sobre pacientes que ya poseían un correo de acceso personal vinculado.
2. La Secretaría o el Profesional ingresan el nuevo correo y el motivo del cambio.
3. El sistema valida:
   - Que el nuevo correo sea diferente del actual.
   - Que no esté utilizado por otro paciente en el sistema.
4. Al concretar el reemplazo en una transacción atómica:
   - Se actualiza el campo `email` del perfil.
   - Se invalidan de inmediato todos los Magic Links pendientes no consumidos emitidos para el correo anterior.
   - Se actualiza un marcador de invalidación de sesiones (`sessions_invalidated_at` o epoch de sesión) para que cualquier sesión web activa iniciada con el correo anterior sea rechazada en su próxima petición.
   - Se preserva íntegramente la `Persona`, sus perfiles, sus turnos históricos y sus pagos asociados.
   - Se emite un Magic Link al nuevo correo para probar posesión.
   - Se registra evento de auditoría `patient_access_email_replaced` con actor responsable, paciente, motivo y fecha.

### 4.4 Acceso Autónomo del Paciente
1. El paciente accede a `/access`, ingresa su correo y solicita enlace.
2. Si el correo está vinculado a un paciente activo, el sistema despacha el Magic Link por correo (vía Swoosh local en dev/test).
3. Si el correo no existe, el sistema finge el envío y responde exactamente la misma pantalla de confirmación.
4. El paciente abre el enlace `/access/verify?token=...` en su navegador.
5. El servidor valida y consume el token atómicamente, inicializa la sesión de paciente y redirige a la vista permitida (calendario de reservas o mis turnos).
6. El paciente autenticado tiene visibilidad **exclusiva de sus propios turnos y datos en modo lectura**. No puede ver agendas ajenas ni turnos de otros pacientes.

---

## 5. Contrato Formal de Dominio y Operaciones (para #298)

### 5.1 Vinculación de Correo de Acceso
```elixir
@spec link_patient_access_email(patient_id :: integer(), email :: String.t(), actor_account_id :: integer()) ::
        {:ok, %{patient_profile: PatientProfile.t(), outcome: :linked}} |
        {:error, :already_has_access_email} |
        {:error, :email_already_in_use} |
        {:error, :invalid_email} |
        {:error, :unauthorized} |
        {:error, Ecto.Changeset.t()}
```
* **Precondición:** `actor_account_id` pertenece a cuenta interna activa con rol `:secretary` o `:professional`. El `email` no existe en ningún otro `PatientProfile`. El `PatientProfile` objetivo tiene `email == nil`.
* **Postcondición:** `patient_profile.email` queda persistido. Se despacha Magic Link de verificación de posesión. Se audita evento `patient_access_email_linked`.
* **Garantía:** No altera `persona_id`, DNI, nombre, ni turnos históricos.

### 5.2 Reemplazo de Correo de Acceso
```elixir
@spec replace_patient_access_email(
        patient_id :: integer(),
        new_email :: String.t(),
        actor_account_id :: integer(),
        reason :: String.t()
      ) ::
        {:ok, %{patient_profile: PatientProfile.t(), outcome: :replaced}} |
        {:error, :same_email} |
        {:error, :email_already_in_use} |
        {:error, :invalid_email} |
        {:error, :reason_required} |
        {:error, :unauthorized} |
        {:error, Ecto.Changeset.t()}
```
* **Precondición:** `actor_account_id` activo con rol `:secretary` o `:professional`. `reason` no vacío. `new_email` válido y no ocupado por otro paciente.
* **Postcondición:** Transacción atómica que actualiza `email`, actualiza `sessions_invalidated_at = now()`, marca `consumed_at = now()` en todos los magic links pendientes del correo anterior, emite magic link al nuevo correo y audita `patient_access_email_replaced`.

### 5.3 Verificación de Sesión Web del Paciente
* El plug o comprobación de sesión de paciente (`authenticate_patient_session`) debe contrastar el `authenticated_at` de la sesión contra `patient_profile.sessions_invalidated_at`. Si la sesión fue emitida antes de una invalidación, se destruye la sesión y se redirige a `/access` solicitando nuevo enlace.

---

## 6. Matriz de Permisos del Slice

| Actor / Rol | Vincular Correo (`link`) | Reemplazar Correo (`replace`) | Solicitar Magic Link (`/access`) | Consumir Magic Link (`/verify`) | Consultar Turnos Propios | Autoeditar Correo/Datos |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Secretaría activa** | **Permitido** | **Permitido** | Permitido (como usuario web) | No aplica | No aplica | Denegado |
| **Profesional activo** | **Permitido** | **Permitido** | Permitido (como usuario web) | No aplica | No aplica | Denegado |
| **Administrador** | **Denegado** | **Denegado** | Permitido (como usuario web) | No aplica | No aplica | Denegado |
| **Paciente autenticado** | Denegado | Denegado | Permitido | Permitido | **Permitido** | **Denegado** (solo lectura) |
| **Usuario público / Anónimo** | Denegado | Denegado | **Permitido** (opaco) | **Permitido** (con token válido) | Denegado | Denegado |

*Regla arquitectural de autorización:* El Administrador no tiene facultades operativas sobre pacientes ni agendas; sus permisos quedan limitados a cuentas de staff (`design.md`).

---

## 7. Escenarios Formales Acordados (Criterios Verificables para #298, #299 y #300)

### C1: Vinculación exitosa de correo a paciente asistido
- **GIVEN** un paciente registrado de forma asistida con DNI `"30.111.222"` y sin correo de acceso (`email: nil`)
- **WHEN** una secretaria autenticada vincula el correo `"paciente.nuevo@example.test"`
- **THEN** el correo queda asociado al perfil del paciente
- **AND** la `Persona`, su DNI y sus datos permanecen inalterados
- **AND** se envía automáticamente un Magic Link de comprobación al nuevo correo
- **AND** se audita el evento `patient_access_email_linked` con el ID de la secretaria.

### C2: Reemplazo exitoso de correo preservando historia
- **GIVEN** un paciente con correo vinculado `"viejo@example.test"` que ya posee 3 turnos históricos registrados
- **WHEN** un profesional autorizado reemplaza el correo por `"nuevo@example.test"` indicando motivo `"Actualización solicitada en consultorio"`
- **THEN** el perfil se actualiza con `"nuevo@example.test"`
- **AND** los 3 turnos históricos continúan asociados al mismo paciente sin pérdida de datos
- **AND** se envía un Magic Link al nuevo correo
- **AND** se audita la operación registrando actor, paciente y motivo.

### C3: Rechazo de vinculación o reemplazo por correo en uso
- **GIVEN** un paciente A con correo `"titular@example.test"`
- **AND** un paciente B registrado de forma asistida
- **WHEN** staff intenta vincular o reemplazar el correo de B por `"titular@example.test"`
- **THEN** la operación es rechazada con error de unicidad (`:email_already_in_use`)
- **AND** no se altera el perfil ni de A ni de B.

### C4: Invalidación de enlaces y sesiones previas tras reemplazo
- **GIVEN** un paciente con correo `"activo@example.test"` que tiene un Magic Link sin consumir emitido hace 2 minutos y una sesión web iniciada
- **WHEN** la secretaría reemplaza el correo por `"renovado@example.test"`
- **THEN** el Magic Link previo para `"activo@example.test"` queda marcado como consumido/inválido
- **AND** la sesión web existente queda invalidada para peticiones posteriores
- **AND** el paciente solo puede autenticarse a través del nuevo correo.

### C5: Consumo de Magic Link y acceso estricto a información propia
- **GIVEN** un paciente recibe un Magic Link válido dirigido a su correo vinculado
- **WHEN** abre el enlace en su navegador
- **THEN** el token se consume de forma atómica (un solo uso)
- **AND** el sistema establece la sesión web del paciente
- **AND** el paciente sólo puede consultar o reservar turnos asociados a su propio perfil.

### C6: Denegación de operaciones de mantenimiento a Administrador
- **GIVEN** un usuario autenticado con rol Administrador
- **WHEN** intenta ejecutar `link_patient_access_email/3` o `replace_patient_access_email/4`
- **THEN** el sistema deniega la operación con `{:error, :unauthorized}`
- **AND** no se realiza ninguna modificación en la base de datos.

### C7: Respuesta pública opaca no enumeradora en `/access`
- **GIVEN** un visitante público en la pantalla `/access`
- **WHEN** ingresa `"correo_inexistente@example.test"` y envía el formulario
- **THEN** la pantalla muestra el mensaje de confirmación idéntico al de un correo registrado
- **AND** no se despacha ningún correo
- **AND** no se revela si el correo o paciente existen.

### C8: Colisión pública por DNI sin divulgación de datos
- **GIVEN** un paciente registrado en el sistema con DNI `"28.444.555"`
- **WHEN** una petición pública o intento de registro utiliza ese DNI
- **THEN** la respuesta no revela la existencia del paciente, ni su nombre, ni sus datos de contacto
- **AND** no se vincula la sesión pública a la identidad preexistente.

### C9: Prohibición de autoedición de identidad por el paciente
- **GIVEN** un paciente autenticado mediante Magic Link
- **WHEN** intenta enviar una modificación sobre su propio correo, DNI, nombre o teléfono
- **THEN** el sistema rechaza la operación por no estar habilitada en la beta
- **AND** los datos del paciente permanecen idénticos a los validados por staff.

### C10: Convivencia y separación entre correo de contacto y correo de acceso
- **GIVEN** un paciente asistido con `contact_email: "familia_lopez@example.test"` (compartido con su cónyuge)
- **WHEN** el paciente solicita su propio acceso personal y staff le vincula `"juan.lopez@example.test"`
- **THEN** `contact_email` conserva `"familia_lopez@example.test"`
- **AND** `email` registra `"juan.lopez@example.test"` con carácter de credencial única personal
- **AND** ambos correos conviven sin conflicto de esquema.

---

## 8. Fronteras y Exclusiones (Out of Scope)

* **Reserva de turnos autónoma:** La selección de profesional, horario y reserva autónoma corresponde a [#280](https://github.com/Team-Origen/origen/issues/280).
* **Canal WhatsApp / SMS:** Excluidos taxativamente por la especificación beta.
* **Autoedición o recuperación autónoma de correo:** El paciente no puede modificar sus credenciales sin intervención de staff.
* **Verificación obligatoria de teléfono:** No se exige OTP telefónico para emitir o consumir el Magic Link de acceso.
* **Proveedor de correo externo:** En desarrollo y test se utiliza `Swoosh.Adapters.Local`; la configuración de entrega de producción permanece fuera de este contrato.

---

## 9. Registro de Aprobación y Próximos Pasos

* **Aprobado por:** Samuel Olmos (`samuel-olmos`), responsable de la funcionalidad #277.
* **Trazabilidad:** Da cumplimiento íntegro a los criterios de aceptación de [#297](https://github.com/Team-Origen/origen/issues/297).
* **Desbloqueo de tareas hijas:**
  * **#298 (Backend):** Implementar las operaciones `link_patient_access_email/3` y `replace_patient_access_email/4`, migración para `sessions_invalidated_at` en `patient_profiles` si aplica, e invalidación atómica de tokens.
  * **#299 (Frontend):** Adaptar la interfaz de Secretaría y Profesional para permitir la vinculación/reemplazo de correo en la ficha del paciente.
  * **#300 (Integración):** Verificación integral del recorrido, suite de pruebas end-to-end de vinculación, reemplazo, no enumeración y cierre formal de #277.
