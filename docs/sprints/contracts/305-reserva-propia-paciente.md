# Contrato #305: reserva propia del Paciente con disponibilidad real

**Estado: formalizado y aprobado para preparación de backend e interfaz por Samuel Olmos (`samuel-olmos`).**
Este documento formaliza el contrato, reglas de negocio y escenarios para [#280](https://github.com/Team-Origen/origen/issues/280) y prepara [#306 (Backend)](https://github.com/Team-Origen/origen/issues/306), [#307 (Frontend)](https://github.com/Team-Origen/origen/issues/307) y [#308 (Integración y verificación)](https://github.com/Team-Origen/origen/issues/308). No implementa código de aplicación ni acredita el cierre definitivo de [#280](https://github.com/Team-Origen/origen/issues/280) o [#308](https://github.com/Team-Origen/origen/issues/308).

---

## 1. Alcance y Fuentes

- **Contrato:** [#305](https://github.com/Team-Origen/origen/issues/305), Sprint 3, issue padre [#280 — [Plan]: Reservar turno propio como Paciente](https://github.com/Team-Origen/origen/issues/280).
- **OpenSpec Change:** `health-center-beta-core`
- **Ruta OpenSpec:** `openspec/changes/health-center-beta-core/`
- **Alcance OpenSpec:** Sprint 3 / parent #280 / contract (Slice 05 de 17).
- **Sección canónica:** `specs/appointment-booking-and-lifecycle/spec.md`:
  - Requisito: *Three booking channels and privacy* (Canal Paciente autónomo, reserva exclusivamente para sí, privacidad estricta entre profesionales).
  - Requisito: *Approval and occupancy* (Aprobación automática $\rightarrow$ `confirmed`; Aprobación manual $\rightarrow$ `requested`; ocupación efectiva del slot en ambos casos).
  - Requisito: *Expiry, cancellation, attendance, and history* (Cancelación libera el slot; no reprogramación directa).
- **Sección complementaria:** `specs/patient-identity-and-access/spec.md` (Identidad y acceso de paciente autenticado).
- **Sección complementaria:** `specs/staff-accounts-and-professional-settings/spec.md` (Profesional reservable: cuenta activa y perfil completo según contrato #301 / backend #302).
- **Fronteras y exclusiones:** `specs/beta-boundaries/spec.md`:
  - Sin WhatsApp ni SMS.
  - Sin verificación obligatoria de teléfono para reservar.
  - Sin reserva para terceros o familiares (sólo perfil propio).
  - Sin notas clínicas ni pagos en este slice.
- **Coordinación de contratos aprobados:**
  - **#301 / #302 (Perfil Profesional):** `docs/sprints/contracts/301-perfil-profesional.md`. La proyección consultada por el paciente filtra profesionales con cuenta activa y perfil completo de 5 campos.
  - **#321 (Resolución de Solicitudes):** `docs/sprints/contracts/321-aprobacion-manual-solicitudes.md`. Regla unificada de modalidad: automático $\rightarrow$ `confirmed`, manual $\rightarrow$ `requested`.
  - **#297 (Acceso por Magic Link):** `docs/sprints/contracts/297-acceso-paciente-magic-link.md`. Identidad autenticada del paciente provista por sesión web cifrada.
- **Guía de trabajo:** `docs/sprints/GUIA_TRABAJO_BETA.md`.

---

## 2. Estado de Verificación Actual del Repositorio

En cumplimiento con la `docs/sprints/GUIA_TRABAJO_BETA.md`, se distingue explícitamente entre código encontrado, pruebas leídas y pruebas ejecutadas:

### 2.1 Código Encontrado
* `lib/origen/appointments/booking_service.ex`:
  * Servicio de aplicación para reserva autónoma del paciente.
  * Valida cuenta profesional activa y perfil completo mediante bloqueo transaccional `lock_eligible_professional!/1` con `SELECT ... FOR SHARE OF a, p`.
  * Persistencia atómica delegada a `Origen.Booking.persist_appointment/2` con snapshots históricos obligatorios (`consultation_type_name`, `duration_minutes`, `exact_price_ars`).
  * Creación de relación `ProfessionalPatientRelationship` atómica con manejo de concurrencia y restricción única en `(professional_account_id, patient_profile_id)`.
  * **Puertas históricas incompatibles identificadas:**
    1. *Exigencia de teléfono verificado:* `reserve/2` invoca `Patients.ready_for_booking?/1`, el cual exige `phone_verified: true`, bloqueando a pacientes sin OTP telefónico.
    2. *Regla histórica D-1:* `determine_initial_status/2` bifurca por proximidad de fecha (`<= 1` día $\rightarrow$ `confirmed`, `> 1` día $\rightarrow `reserved`), contradiciendo la máquina de estados de la beta donde el estado nace de `approval_mode` (`confirmed` o `requested`).
* `lib/origen/appointments/calendar.ex` y `lib/origen/appointments/database_calendar.ex`:
  * Puerto y adaptador de calendario real.
  * `get_bookable_professionals/1`: Proyección de profesionales elegibles (integrado con #302).
  * `get_available_slots/4`: Cálculo de slots libres evaluando duración del tipo de consulta, intervalo de agenda, horarios semanales, restricciones temporales (anticipación y horizonte) y exclusión de solapamientos existentes.
* `lib/origen/booking/overlap.ex`:
  * Módulo de dominio para verificación de solapamientos en memoria y BD. Trata turnos activos (`requested`, `confirmed`, `reserved`) como ocupantes del slot; `cancelled` y `rejected` liberan el horario.
* `priv/repo/migrations/20260927100000_add_appointment_overlap_exclusion_constraints.exs`:
  * Restricción de exclusión GiST en PostgreSQL (`tstzrange`) para evitar colisiones a nivel de base de datos (`status NOT IN ('cancelled', 'rejected')`).
* `lib/origen_web/live/patient_booking_calendar_live.ex`:
  * LiveView del calendario del paciente. Maneja selección interactiva de profesional, consulta, fecha y slot, confirmación de política y envío del formulario.

### 2.2 Pruebas Leídas
* `test/origen/appointments/booking_service_test.exs`:
  * Pruebas de elegibilidad profesional (#302), snapshots históricos, concurrencia, creación de relación, rechazo de llamadas no autenticadas.
  * Pruebas que afirman las reglas históricas a retirar: `test "refutes booking when patient phone is not verified"` y `test "determines 'confirmed' status when booked on D-1 or D per RF-10"`.
* `test/origen/appointments/database_calendar_test.exs`:
  * Pruebas de cálculo de disponibilidad real, anticipación mínima, horizonte y exclusión de profesionales incompletos.
* `test/origen/booking/atomic_reservation_test.exs`:
  * Pruebas de rollback completo ante fallas transaccionales y consistencia de snapshots.
* `test/origen/booking/overlap_test.exs`:
  * Pruebas de concurrencia y prevención estricta de doble ocupación en el mismo intervalo.
* `test/origen_web/live/patient_booking_calendar_live_test.exs`:
  * Pruebas de navegación en LiveView, selección de fechas y visualización de slots.

### 2.3 Ejecución Observada
* **Comando ejecutado:**
  ```sh
  ORIGEN_TEST_DB_USERNAME=postgres ORIGEN_TEST_DB_PASSWORD=12345 ORIGEN_TEST_DB_PORT=5432 \
    mix test test/origen/appointments/booking_service_test.exs \
             test/origen/appointments/database_calendar_test.exs \
             test/origen/booking/atomic_reservation_test.exs \
             test/origen/booking/overlap_test.exs \
             test/origen_web/live/patient_booking_calendar_live_test.exs
  ```
* **Resultado:**
  * **52 pruebas aprobadas**, 0 fallas.
  * Tiempo de ejecución: 2.3 s.
  * Semilla ExUnit: `31337`.
  * Etiquetas excluidas: `[postgres_security: true]`.
* **Diagnóstico:** La infraestructura transaccional, el motor de solapamiento y la consulta de calendarios están probados y son plenamente funcionales. La adaptación para la beta consiste en retirar las dos barreras históricas (teléfono verificado y D-1) y alinear la resolución inicial de estados con la modalidad de aprobación (#321).

---

## 3. Matriz de Análisis frente a la Beta (`health-center-beta-core`)

| Aspecto | Estado Actual del Repositorio | Requisito Canónico Beta | Acción Requerida |
| :--- | :--- | :--- | :--- |
| **Canal de reserva autónoma** | Paciente autenticado reserva desde `PatientBookingCalendarLive` a través de `BookingService`. | Paciente elige Profesional elegible, consulta y horario disponible **sólo para sí mismo**. | **Reutilizar** |
| **Profesional elegible** | #302 exige cuenta activa y perfil completo de 5 campos obligatorios. | Profesional debe tener cuenta activa y perfil completo para aparecer y ser reservado. | **Reutilizar** (integración ya presente en develop). |
| **Disponibilidad real** | Calcula slots según horarios semanales, intervalo, duración de consulta y exclusión de turnos previos. | La reserva debe usar disponibilidad real calculada en el servidor. | **Reutilizar** |
| **Verificación telefónica obligatoria** | `ready_for_booking?/1` exige `phone_verified: true`. | **Prohibido:** la beta excluye taxativamente la verificación obligatoria de teléfono para reservar. | **Retirar / Adaptar** (`phone_verified: false` no debe impedir la reserva). |
| **Regla histórica D-1** | Antes de D-1 nacía `reserved`; en D-1 o día D nacía `confirmed`. | **Retirar:** la máquina de estados de la beta no usa `reserved` como estado final observable. Se rige por la modalidad de aprobación. | **Reemplazar** (alinear con #321). |
| **Modalidad de aprobación** | Parcialmente contemplado en #321 para solicitudes manuales. | - Si Profesional tiene aprobación **automática**: nace `confirmed`.<br>- Si Profesional tiene aprobación **manual**: nace `requested`. | **Adaptar** (`BookingService` resuelve según `approval_mode`). |
| **Ocupación del slot** | El turno ocupa slot mediante exclusión en BD. | Tanto `confirmed` como `requested` ocupan el slot impidiendo reservas solapadas. | **Reutilizar** |
| **Relación Profesional-Paciente** | Se inserta `ProfessionalPatientRelationship` en la misma transacción. | Completar una solicitud o un turno confirmado crea la relación durable. | **Reutilizar** |
| **Snapshots históricos** | Guarda copias inmutables de nombre de consulta, duración y precio exacto. | Copias históricas obligatorias e inmutables ante cambios posteriores del catálogo. | **Reutilizar** |
| **Privacidad entre profesionales** | Paciente ve sólo sus citas; Profesional ve sólo citas de su agenda. | Los profesionales **no deben ver** actividad, historial ni citas del paciente con otros profesionales. | **Reutilizar / Afirmar** |
| **Reserva para familiares** | No implementada. | **Exclusión Beta:** no se admite reserva para terceros o dependientes. | **Exclusión respetada** |

---

## 4. Reglas de Negocio y Flujo Operativo

### 4.1 Identidad del Paciente y Criterio de Preparación
1. El paciente debe estar autenticado en la sesión web (vía Magic Link, según contrato #297).
2. El paciente debe contar con un `PatientProfile` asociado con datos personales básicos (`state: "completed"`).
3. **Regla de oro de la Beta:** El valor de `phone_verified` (`true` o `false`) **NO BLOQUEA** la reserva. Un paciente con teléfono no verificado puede reservar normalmente.

### 4.2 Selección de Profesional y Consulta
1. El paciente visualiza únicamente profesionales que cumplan con la condición de elegibilidad: **cuenta interna activa** y **perfil profesional completo** (nombre, apellido, especialidad, tipo y número de matrícula persistidos, según contrato #301).
2. El paciente selecciona un **tipo de consulta activo** configurado por ese profesional.
3. El servidor calcula los slots disponibles a partir de la agenda regular, el intervalo, la duración de la consulta seleccionada y las citas/solicitudes preexistentes.

### 4.3 Resolución de Estado de la Reserva (Coordinación con #321)
Al momento de confirmar la reserva en el servidor:
1. Si el profesional configuró su agenda con **aprobación automática** (`approval_mode: :automatic`):
   - La reserva nace directamente en estado **`confirmed`**.
   - El slot queda ocupado.
   - El paciente recibe confirmación inmediata de turno reservado.
2. Si el profesional configuró su agenda con **aprobación manual** (`approval_mode: :manual`):
   - La reserva nace en estado **`requested`** (solicitud pendiente).
   - El slot queda **igualmente ocupado** (ningún otro paciente o secretaría puede tomar ese horario mientras esté pendiente).
   - El paciente recibe confirmación de solicitud enviada pendiente de aprobación.
3. **Eliminación de la regla D-1:** La fecha del turno respecto de la fecha actual no altera el estado. No se asigna el estado histórico `reserved`.

### 4.4 Garantías Transaccionales y de Privacidad
1. **Atomicidad:** En una única transacción de base de datos se realiza:
   - Verificación y bloqueo de elegibilidad del profesional (`FOR SHARE`).
   - Persistencia de la cita con snapshots inmutables del catálogo (`consultation_type_name`, `duration_minutes`, `exact_price_ars`).
   - Persistencia de la relación `ProfessionalPatientRelationship` vinculando al profesional con el paciente.
   - Verificación de no colisión mediante la restricción GiST de PostgreSQL.
2. **Privacidad estricta:**
   - El paciente sólo puede reservar asociando su propio `patient_profile_id`. Si se envía un ID de paciente distinto en los parámetros, el servidor lo rechaza o lo sobrescribe con la identidad de la sesión autenticada.
   - El profesional dueño de la agenda puede ver al paciente y su turno en su agenda diaria, pero el sistema le prohíbe consultar las citas o el historial de ese mismo paciente con otros profesionales del centro.

---

## 5. Contrato Formal de Dominio y Operaciones (para #306)

### 5.1 Función de Reserva Autónoma
```elixir
@spec reserve(
        patient_profile :: PatientProfile.t() | nil,
        params :: %{
          required(:professional_id) => integer() | String.t(),
          required(:consultation_type_id) => String.t(),
          required(:date) => Date.t(),
          required(:slot) => map(),
          optional(:now) => DateTime.t()
        }
      ) ::
        {:ok, reservation_result()} |
        {:error, :unauthenticated} |
        {:error, :patient_not_ready_for_booking} |
        {:error, :professional_not_eligible} |
        {:error, :overlap_detected} |
        {:error, :invalid_slot_time} |
        {:error, term()}
```

#### Tipos de Retorno
```elixir
@type reservation_result :: %{
        appointment: Appointment.t(),
        appointment_id: integer(),
        status: String.t(), # "confirmed" | "requested"
        consultation_type_name: String.t(),
        duration_minutes: integer(),
        exact_price_ars: Decimal.t(),
        start_time: DateTime.t(),
        end_time: DateTime.t()
      }
```

#### Precondiciones
1. `patient_profile` no es `nil` y posee `state == "completed"` (sin exigir `phone_verified: true`).
2. `professional_id` corresponde a un profesional activo con perfil completo.
3. El slot horario no se solapa con ninguna cita o solicitud activa (`status NOT IN ('cancelled', 'rejected', 'expired')`).
4. El tipo de consulta está activo y pertenece al profesional.

#### Postcondiciones
1. Se persiste el registro `appointments` con estado `"confirmed"` (si modo automático) o `"requested"` (si modo manual).
2. Se capturan los snapshots históricos inmutables de nombre, duración y precio en pesos argentinos (`Decimal`).
3. Se inserta o asegura la existencia de `ProfessionalPatientRelationship`.
4. El horario queda bloqueado para cualquier intento concurrente posterior.

---

## 6. Matriz de Permisos del Slice

| Actor / Rol | Consultar Calendario Público/Paciente | Ejecutar Reserva Autónoma | Reservar para Otro Paciente | Aprobar/Rechazar Solicitud | Consultar Citas Ajenas |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Paciente autenticado** | **Permitido** | **Permitido** (sólo para sí) | **Denegado** | Denegado | **Denegado** |
| **Secretaría activa** | No aplica en este LiveView | No aplica (usa canal asistido #281) | No aplica aquí | Denegado (sólo Profesional) | N/A |
| **Profesional activo** | No aplica en este LiveView | No aplica (usa canal propio #282) | No aplica aquí | **Permitido** (sólo sus turnos) | **Denegado** (citas de otros) |
| **Administrador** | No aplica | Denegado | Denegado | Denegado | Denegado |
| **Anónimo / No autenticado** | Consulta básica | **Denegado** (`:unauthenticated`) | Denegado | Denegado | Denegado |

---

## 7. Escenarios Formales Acordados (Criterios Verificables para #306, #307 y #308)

### C1: Reserva autónoma exitosa en modo automático (nace confirmada)
- **GIVEN** un paciente autenticado con perfil completo y teléfono no verificado (`phone_verified: false`)
- **AND** un profesional elegible configurado con aprobación automática (`approval_mode: :automatic`)
- **WHEN** el paciente selecciona una consulta y un horario disponible para dentro de 5 días
- **THEN** la reserva se concreta exitosamente
- **AND** el turno nace directamente con estado `"confirmed"` (sin aplicar regla D-1)
- **AND** el slot queda ocupado en la agenda.

### C2: Reserva autónoma exitosa en modo manual (nace solicitada)
- **GIVEN** un paciente autenticado con teléfono no verificado
- **AND** un profesional elegible configurado con aprobación manual (`approval_mode: :manual`)
- **WHEN** el paciente selecciona una consulta y un horario disponible
- **THEN** la reserva se concreta exitosamente
- **AND** el turno nace con estado `"requested"`
- **AND** el slot queda efectivamente ocupado, impidiendo reservas solapadas.

### C3: Creación durable de la relación Profesional-Paciente
- **GIVEN** un paciente que nunca se atendió previamente con el profesional P
- **WHEN** el paciente completa una reserva autónoma (sea `confirmed` o `requested`)
- **THEN** se crea el registro en `ProfessionalPatientRelationship` asociando a ambos
- **AND** la relación queda persistida en la misma transacción que el turno.

### C4: Preservación de snapshots históricos
- **GIVEN** un tipo de consulta "Consulta Dermatológica" con duración 30 min y precio $15.000
- **WHEN** el paciente reserva un turno con ese tipo
- **THEN** el turno almacena `snapshot_consultation_type_name: "Consulta Dermatológica"`, `snapshot_duration_minutes: 30` y `snapshot_exact_price_ars: 15000.00`
- **AND** modificaciones posteriores de precio o nombre en el catálogo del profesional no alteran los datos del turno ya reservado.

### C5: Prevención de doble ocupación concurrente
- **GIVEN** un horario disponible el viernes a las 10:00
- **WHEN** dos pacientes intentan reservar exactamente el mismo slot en simultáneo
- **THEN** exactamente una de las transacciones tiene éxito
- **AND** la otra transacción es rechazada por solapamiento (`{:error, :overlap_detected}`)
- **AND** no se generan duplicados en la base de datos.

### C6: Paciente con teléfono no verificado puede reservar
- **GIVEN** un paciente autenticado cuyo perfil tiene `phone_verified: false` y teléfono cargado
- **WHEN** solicita una reserva con datos válidos
- **THEN** el sistema **no** rechaza la operación por falta de verificación telefónica
- **AND** la reserva se procesa y persiste con total normalidad.

### C7: Rechazo ante profesional no elegible (incompleto o inactivo)
- **GIVEN** una cuenta profesional activa pero con perfil incompleto (falta matrícula o especialidad)
- **WHEN** el paciente intenta reservar contra ese ID profesional
- **THEN** el servidor rechaza la operación con `{:error, :professional_not_eligible}`
- **AND** no se inserta ningún registro de turno ni relación.

### C8: Denegación de reserva para llamadas no autenticadas
- **GIVEN** una petición de reserva donde el paciente es `nil` o la sesión no es válida
- **WHEN** se ejecuta el servicio de reserva
- **THEN** retorna `{:error, :unauthenticated}` sin mutaciones.

### C9: Rechazo de reserva sobre horario solapado con una solicitud previa
- **GIVEN** un horario que ya está ocupado por un turno en estado `"requested"`
- **WHEN** otro paciente intenta reservar ese mismo horario
- **THEN** la operación es rechazada por solapamiento
- **AND** el slot permanece reservado exclusivamente para la solicitud original.

### C10: Privacidad estricta entre profesionales
- **GIVEN** el paciente Juan posee un turno reservado con la Dra. Pérez y otro con el Dr. Gómez
- **WHEN** el Dr. Gómez consulta su agenda diaria o los detalles del paciente Juan
- **THEN** el Dr. Gómez sólo visualiza el turno perteneciente a su propia agenda
- **AND** no tiene visibilidad alguna sobre el turno o la relación de Juan con la Dra. Pérez.

### C11: El paciente reserva únicamente para sí mismo
- **GIVEN** el paciente autenticado A (ID 10)
- **WHEN** se envía una solicitud forjada intentando asignar la cita al paciente B (ID 20)
- **THEN** el servidor fuerza el `patient_profile_id` de la identidad autenticada de A
- **AND** la cita y la relación quedan asociadas exclusivamente a A.

### C12: Liberación inmediata del slot ante cancelación
- **GIVEN** una cita en estado `requested` o `confirmed`
- **WHEN** la cita es cancelada (por el paciente o por rechazo del profesional según #321)
- **THEN** el estado pasa a `cancelled`
- **AND** el horario vuelve a estar inmediatamente disponible en el cálculo de disponibilidad para nuevas reservas.

---

## 8. Fronteras y Exclusiones (Out of Scope)

* **Reserva de familiares o dependientes:** Excluida taxativamente de la beta (sólo reserva personal).
* **Aprobación manual y rechazo en LiveView del Profesional:** La interfaz para que el profesional acepte o rechace solicitudes pertenece a [#284](https://github.com/Team-Origen/origen/issues/284) / [#323](https://github.com/Team-Origen/origen/issues/323).
* **Pagos y comprobantes:** La captura y corrección de pagos corresponde a [#287](https://github.com/Team-Origen/origen/issues/287).
* **Canal WhatsApp / SMS:** Excluidos taxativamente.
* **Reprogramación directa:** Toda modificación de fecha o consulta es cancelación y nueva reserva.

---

## 9. Registro de Aprobación y Próximos Pasos

* **Aprobado por:** Samuel Olmos (`samuel-olmos`), responsable de la funcionalidad #280.
* **Trazabilidad:** Da cumplimiento íntegro a los criterios de aceptación de [#305](https://github.com/Team-Origen/origen/issues/305).
* **Desbloqueo de tareas hijas:**
  * **#306 (Backend):** Adaptar `ready_for_booking?/1` para no bloquear por `phone_verified`, retirar la regla D-1 en `determine_initial_status/2` vinculando la resolución al `approval_mode` del profesional, y actualizar la suite de tests en `booking_service_test.exs`.
  * **#307 (Frontend):** Actualizar `PatientBookingCalendarLive` para reflejar el estado resultante (`confirmed` o `requested`) y remover advertencias obsoletas de verificación telefónica.
  * **#308 (Integración y verificación):** Verificación integral del recorrido de reserva del paciente con disponibilidad real, concurrencia y cierre definitivo de #280.
