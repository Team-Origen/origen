# Contrato #309: agenda de paciente existente desde Secretaría

**Estado: borrador de contrato para #309, preparado por Lucca Giordana (`ChordanDev`).**
Este documento prepara [#310 (Backend)](https://github.com/Team-Origen/origen/issues/310) y [#311 (Frontend)](https://github.com/Team-Origen/origen/issues/311). No implementa código de aplicación ni acredita el cierre de [#281](https://github.com/Team-Origen/origen/issues/281) o [#312 (Integración)](https://github.com/Team-Origen/origen/issues/312).

---

## Alcance y fuentes

- **Contrato:** [#309](https://github.com/Team-Origen/origen/issues/309), Sprint 3, issue padre [#281](https://github.com/Team-Origen/origen/issues/281).
- **OpenSpec:** cambio `health-center-beta-core`, ruta `openspec/changes/health-center-beta-core/`, alcance Sprint 3 / parent #281 / contract.
- [Propuesta beta](../../../openspec/changes/health-center-beta-core/proposal.md) y [diseño](../../../openspec/changes/health-center-beta-core/design.md).
- [Reserva de turnos y ciclo de vida](../../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md):
  - Canal Secretaría con visibilidad de todas las agendas del centro y lista completa de pacientes.
  - Creación de relación Profesional–Paciente al completar la reserva o solicitud.
  - Reglas de modalidad de aprobación (automática vs. manual) y ocupación de slots.
  - Prohibición expresa de aceptación/rechazo de solicitudes por parte de Secretaría.
- [Identidad y acceso de pacientes](../../../openspec/changes/health-center-beta-core/specs/patient-identity-and-access/spec.md):
  - Búsqueda obligatoria de paciente existente por documento antes de cualquier acción.
- [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md):
  - Sin catálogo de matrículas ni verificación externa de credenciales.
  - Sin reprogramación directa (cambio de turno es cancelación + nueva reserva).
- [Guía de trabajo beta](../GUIA_TRABAJO_BETA.md):
  - Distinguir código encontrado, pruebas leídas y pruebas ejecutadas.
  - Desbloqueo de backend e interfaz contra el contrato sin requerir la implementación completa del otro.
  - Retiro explícito de exigencias históricas incompatibles (p. ej. `patient_agreed_schedule`).

---

## Reglas de negocio y flujo operativo

### 1. Búsqueda y selección del paciente existente
1. Secretaría localiza al paciente mediante búsqueda controlada por documento (`document_type` y `document_number`) en la pantalla de Secretaría (`/secretaria/pacientes`).
2. Si el paciente existe (`Persona` vinculada a `PatientProfile`), se muestra el resumen del paciente (`#patient-summary-section`).
3. La acción **"Iniciar Reserva Asistida"** (`#start-assisted-booking`) inicia el flujo de agendamiento para ese paciente específico.
4. Si el paciente no existe, el flujo pertenece a la issue #276 (alta de inexistente asistida); **#281 opera exclusivamente sobre pacientes ya existentes**.

### 2. Selección de agenda del centro y disponibilidad real
1. Secretaría puede seleccionar **cualquier Profesional activo del centro** que cuente con perfil y agenda configurada.
2. Secretaría selecciona el **tipo de consulta** ofrecido por ese profesional (con su duración y precio vigentes).
3. La consulta de horarios disponibles (slots) se calcula contra el motor de disponibilidad real (`Availability.calculate_slots/4` / `DatabaseCalendar`):
   - Respeta las ventanas de disponibilidad semanal del profesional.
   - Respeta la duración de la consulta y el intervalo configurado de la agenda.
   - Respeta la anticipación mínima (`min_lead_time_minutes`) y el horizonte de reserva (`booking_horizon_days`).
   - Excluye turnos previamente ocupados (`appointments` activos en estados `reserved`, `confirmed`, `requested`).
4. **Retiro de exigencia histórica:** Se retira la obligatoriedad de la bandera `patient_agreed_schedule == true` que existía en `Origen.Booking.Authorization` (Issue #64). En la beta, la acción asistida de Secretaría ya constituye el acto operativo acordado con el paciente presente o en línea; no se exige marcar un checkbox artificial de acuerdo de horario.

### 3. Modalidad de aprobación y estado resultante
Conforme a la especificación beta (`specs/appointment-booking-and-lifecycle/spec.md`):
- **Aprobación automática del profesional:**
  - El turno creado por Secretaría nace en estado **`confirmed`**.
- **Aprobación manual del profesional:**
  - Por subconfiguración del centro/profesional, las reservas de Secretaría pueden nacer directamente como **`confirmed`** (modo asistido preferente) o como **`requested`** (si el profesional requiere validar manualmente todo turno agendado). Por defecto en la beta, si no hay subconfiguración que fuerce confirmación directa en modo manual, nace como **`confirmed`** cuando Secretaría opera de forma asistida directa o **`requested`** si el profesional tiene aprobación manual estricta.
  - En ambos casos (`confirmed` o `requested`), el slot queda **inmediatamente ocupado** impidiendo solapamientos.
  - En ambos casos se establece la relación durable `ProfessionalPatientRelationship` entre el profesional seleccionado y el paciente.

### 4. Delimitación y exclusiones estrictas de Secretaría
| Acción | Secretaría | Profesional |
| --- | --- | --- |
| Buscar pacientes por documento | **Permitido** | Permitido sólo en creación de turno (DNI exacto) |
| Ver todas las agendas del centro | **Permitido** | Denegado (sólo ve su agenda propia) |
| Agendar turno para paciente existente | **Permitido** | Permitido sólo en su propia agenda |
| Aceptar o rechazar solicitudes pendientes | **Denegado** (exclusivo de #284) | **Permitido** (sólo de su agenda propia) |
| Leer o modificar perfil/ajustes profesionales | **Denegado** (exclusivo del profesional) | **Permitido** (sólo propios) |
| Ver historial clínico o turnos con otros profesionales | **Denegado** | **Denegado** |

Secretaría **nunca** aprueba ni rechaza solicitudes pendientes. Si un turno queda en estado `requested`, la resolución de dicha solicitud queda bajo el alcance de la issue [#284](https://github.com/Team-Origen/origen/issues/284).

---

## Matriz de permisos y autorización

| Actor | Sesión requerida | Operación | Resultado esperado |
| --- | --- | --- | --- |
| Secretaría activa | `role: "secretary"`, `state: "active"` | Crear turno asistido para paciente existente | Autorizado (`{:ok, appointment}`) |
| Administrador activo | `role: "administrator"`, `state: "active"` | Crear turno asistido para paciente existente | Autorizado (co-operación de soporte administrativo) |
| Profesional | `role: "professional"` | Crear turno en agenda ajena | Denegado (`{:error, :unauthorized}`) |
| Paciente | `role: "patient"` | Crear turno en nombre de otro paciente | Denegado (`{:error, :unauthorized}`) |
| Anónimo / Sesión inválida | Sin sesión o inactiva | Cualquier operación de agenda | Denegado (`{:error, :unauthenticated}`) |
| Secretaría | `role: "secretary"` | Aceptar/Rechazar solicitud pendiente | Denegado (`{:error, :unauthorized}`) |
| Secretaría | `role: "secretary"` | Modificar disponibilidad o catálogo profesional | Denegado (`{:error, :unauthorized}`) |

---

## Mapa de reutilización, adaptación y componentes faltantes

| Clasificación | Componente / Archivo | Detalle |
| --- | --- | --- |
| **Reutilizar** | `lib/origen/patients.ex` (`search_persona_by_document/3`) | Búsqueda auditada de paciente existente por tipo y número de documento. |
| **Reutilizar** | `lib/origen/booking.ex` (`persist_appointment/2`, `determine_initial_status/3`) | Persistencia atómica con snapshots inmutables de consulta (nombre, duración, precio). |
| **Reutilizar** | `lib/origen/booking/overlap.ex` | Validación de conflictos de agenda para evitar dobles reservas. |
| **Reutilizar** | `lib/origen/appointments/database_calendar.ex` | Consulta de profesionales activos y cálculo de slots con `Availability`. |
| **Adaptar** | `lib/origen/booking/authorization.ex` | Retirar la condición obligatoria `ensure_schedule_agreement` para el rol `:secretary` conforme a la especificación beta. |
| **Adaptar** | `lib/origen_web/live/secretary_patient_live.ex` | Reemplazar el aviso temporal `#assisted-booking-notice` ("disponible próximamente") por el flujo interactivo de selección de profesional, fecha y horario. |
| **Crear (#310)** | `lib/origen/appointments/assisted_booking.ex` (o función de contexto en `Booking`) | Módulo/función de backend para coordinar la reserva asistida de secretaría con validaciones completas, creación de relación y auditoría. |
| **Crear (#311)** | Componentes LiveView / Modal de reserva asistida | Selección de profesional del centro, selección de consulta, grilla de horarios disponibles y confirmación observable. |

---

## Escenarios verificables para Backend (#310) y Frontend (#311)

Son criterios de prueba contractuales, **no resultados de pruebas aún ejecutadas**:

| ID | Escenario / Acción | Resultado esperado |
| --- | --- | --- |
| **C1** | Secretaría selecciona paciente existente, profesional activo y horario libre dentro de disponibilidad. | El turno se persiste atómicamente con snapshot de consulta, el slot queda ocupado y se crea la relación Profesional–Paciente. |
| **C2** | Profesional con aprobación automática. Secretaría confirma reserva. | El turno nace en estado `"confirmed"`. |
| **C3** | Profesional con aprobación manual estricta. Secretaría envía reserva asistida. | El turno nace en estado `"requested"`, ocupa el slot y no puede ser resuelto (aprobado/rechazado) por Secretaría. |
| **C4** | Intento de reserva en un horario fuera de la disponibilidad semanal o ya ocupado por otro turno. | La reserva es rechazada (`:slot_already_booked` o slot no ofertado), sin mutación de turnos ni relaciones espurias. |
| **C5** | Intento de reserva violando la antelación mínima o el horizonte de reserva del profesional. | El horario no aparece disponible o la reserva es rechazada por límites temporales. |
| **C6** | Intento de reserva por Secretaría sin enviar `patient_agreed_schedule`. | Se acepta exitosamente (requisito histórico retirado conforme a la beta). |
| **C7** | Secretaría intenta ejecutar aprobación o rechazo de una solicitud (`approve_request` / `reject_request`). | Operación denegada (`{:error, :unauthorized}`); Secretaría no tiene facultad de resolver solicitudes. |
| **C8** | Actor con sesión de Profesional intenta reservar asistido en la agenda de otro profesional. | Operación denegada (`{:error, :unauthorized}`); el profesional sólo opera su propia agenda. |
| **C9** | Sesión expirada o anónima intenta agendar asistido. | Denegado inmediatamente con redirección o `{:error, :unauthorized}`. |
| **C10** | Error concurrente de inserción (dos secretarias reservan el mismo slot simultáneamente). | Uno tiene éxito; el segundo falla con `{:error, :slot_already_booked}` sin dejar registros corruptos. |
| **C11** | Interfaz LiveView (#311) con paciente seleccionado renderiza catálogo de profesionales y tipos de consulta. | Muestra nombres y especialidades declaradas de los profesionales y sus consultas disponibles. |
| **C12** | Interfaz LiveView (#311) al seleccionar fecha calcula y presenta los slots libres reales. | Presenta los horarios válidos; ante clic en un horario libre, solicita confirmación y muestra feedback visual del turno creado. |

---

## Evidencia de verificación

### Código encontrado y pruebas leídas
- Búsqueda de paciente y vista base: `lib/origen_web/live/secretary_patient_live.ex:50-250`.
- Pruebas existentes de búsqueda y aviso de reserva: `test/origen_web/live/secretary_patient_live_test.exs:1-275`.
- Autorización de reservas: `lib/origen/booking/authorization.ex:94-102`.
- Persistencia de turnos y snapshots: `lib/origen/booking.ex:70-220`.
- Pruebas del motor de reservas: `test/origen/booking/authorization_test.exs`, `test/origen/booking/persistence_test.exs`, `test/origen/booking/overlap_test.exs`.

### Ejecución observada
Ejecución local en suite de pruebas de referencia:
```sh
mix test test/origen_web/live/secretary_patient_live_test.exs test/origen/booking/
```
**Resultado:** Código de salida **0**, **116 pruebas aprobadas**, 29 excluidas/saltadas, duración **0.9 segundos**. Esto confirma que la base actual está sana antes de iniciar cambios.

---

## Próximos pasos

1. **Aprobación del contrato #309:** Registro de la aprobación formal en el ticket.
2. **Implementación de Backend [#310](https://github.com/Team-Origen/origen/issues/310):**
   - Adaptar `Origen.Booking.Authorization` (retiro de `patient_agreed_schedule`).
   - Implementar la función de reserva asistida por secretaría con soporte de modalidad de aprobación.
   - Escribir pruebas unitarias y de integración de backend para C1–C10.
3. **Implementación de Frontend [#311](https://github.com/Team-Origen/origen/issues/311):**
   - Implementar componentes/modal en `SecretaryPatientLive` para el agendamiento asistido.
   - Escribir pruebas de LiveView para C11–C12 con fixtures acordes al contrato.
4. **Integración y verificación [#312](https://github.com/Team-Origen/origen/issues/312):**
   - Conectar las partes reales y comprobar los criterios de aceptación completos de la padre #281 una vez concluidas las hermanas.
