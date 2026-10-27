# Matriz Durable de Escenarios para la Operación de Reserva (PLN-08)

- **Issue GitHub:** [#61 "Definir matriz durable de escenarios para la operación de reserva"](https://github.com/Team-Origen/origen/issues/61)
- **Issue Padre:** [#41 "Operación única y transaccional de reserva" (PLN-08)](https://github.com/Team-Origen/origen/issues/41)
- **Área principal:** Backend
- **Referencias normativas:** `docs/Origen_Documentacion.md` — RF-02, RF-04, RF-05, RF-07, RF-08, RF-10, RF-12, RF-14, RF-16; Issue #33, Issue #74, Issue #76, Issue #77.

---

## Actualización beta (#314)

La especificación aprobada `health-center-beta-core` y el contrato
`docs/sprints/contracts/313-agenda-profesional-privacidad.md` prevalecen sobre
las reglas históricas de esta matriz. En particular:

- Completar una solicitud `requested`, además de un turno `reserved` o
  `confirmed`, crea o reutiliza la relación dentro de la misma transacción.
  Buscar, seleccionar o abandonar no la crea.
- El canal Profesional permite seleccionar relacionados o un paciente registrado
  por DNI exacto, sin navegación global ni actividad de otros Profesionales.
- `Booking.reserve_professional_appointment/3` deriva el dueño desde la sesión
  revalidada y siempre crea `confirmed`, independientemente de D-1 o aprobación.
  Recibe `patient_id`, `consultation_type_id`, `start_time` y, para seleccionar
  por DNI sin relación previa, `patient_document_number`.
- `Booking.list_professional_patients/1` y
  `Booking.find_professional_patient_by_dni/2` devuelven sólo identificador,
  nombre, apellido y DNI; no crean turnos ni relaciones.

Las tablas siguientes conservan el contexto histórico de PLN-08; sus estados
por D-1, restricciones de selección previa y expectativas de relación para
`requested` no constituyen requisitos beta vigentes.

## 1. Propósito y Alcance

Este documento constituye el **artefacto durable de especificación** para el motor unificado y transaccional de reservas compartidas entre los tres actores del sistema: **Paciente autónomo**, **Secretaría asistida** y **Profesional**.

Define exhaustivamente:
1. **Elegibilidad y permisos:** Condiciones previas requeridas para cada actor.
2. **Estados iniciales por actor y fecha:** Determinación determinística del estado del turno (`Solicitado`, `Reservado`, `Confirmado`) según el rol y la antelación temporal respecto al día de la cita (antes de D-1 vs. durante D-1 vs. día D).
3. **Reglas de solapamiento y concurrencia:** Prevención de sobreturnos no autorizados, colisiones de agenda del profesional y acaparamiento simultáneo del paciente.
4. **Reversión transaccional (Rollback ACID):** Garantía de atomicidad todo-o-nada para el turno, sus copias históricas (snapshots), la relación de visibilidad Profesional–Paciente y la auditoría append-only.

Este artefacto no implementa el código del motor ni modifica esquemas de base de datos; desbloquea formalmente las subissues posteriores [#62](https://github.com/Team-Origen/origen/issues/62) (contratos y validación sintáctica) y [#63](https://github.com/Team-Origen/origen/issues/63) (persistencia de turnos con snapshots).

---

## 2. Dimensiones y Reglas de la Operación

### 2.1 Actores y Elegibilidad

| Actor | Alcance y Requisitos de Elegibilidad | Referencia |
|---|---|---|
| **Paciente autónomo** | Requiere perfil propio completo (no `Pendiente de completar`), teléfono primario verificado (`PLN-15`), sin multas pendientes impagas con el profesional (`RF-12`), y solicitud dentro de la ventana de reserva antes del corte de las 23:59 de D-1. Puede reservar con un profesional nuevo sin relación previa. | RF-05, RF-10, RF-12 |
| **Secretaría asistida** | Puede operar en nombre de cualquier paciente registrado o crear un paciente nuevo. Puede reservar para perfiles incompletos (`RF-02`). Puede reservar hasta el inicio mismo del turno (excepción controlada al corte de D-1). | RF-02, RF-05, RF-10 |
| **Profesional** | Solo puede crear o gestionar turnos para pacientes que **ya figuren en su lista permitida** (relación previa establecida por una reserva válida anterior, `RF-05`). No puede navegar el registro global ni reservar para pacientes sin relación previa. Puede operar hasta el inicio del turno. | RF-05, RF-10 |

### 2.2 Estados Iniciales según Actor y Momento (RF-10 / RF-14)

El momento se calcula respecto a la fecha del turno ($D$):
- **Antes de D-1:** Hasta las 23:59 del día $D-2$.
- **Durante D-1:** Desde las 00:00 hasta las 23:59 del día previo al turno.
- **Día D:** Desde las 00:00 hasta el horario pactado de inicio de la consulta.

| Actor | Momento | Modalidad / Condición | Estado Inicial | Efecto en Relación / Auditoría |
|---|---|---|---|---|
| **Paciente** | Antes de D-1 | Aprobación automática (demo) | `Reservado` | Si es primera reserva, crea relación Profesional–Paciente atómicamente. Audita reserva. |
| **Paciente** | Antes de D-1 | Aprobación manual | `Solicitado` | **No** crea relación Profesional–Paciente. No otorga visibilidad al profesional. |
| **Paciente** | Durante D-1 | Dentro del corte (antes de 23:59 D-1) | `Confirmado` | Nace directo en `Confirmado`; no dispara flujo de confirmación WhatsApp. Crea relación. |
| **Paciente** | Día D | — | *Rechazado* | Reserva autónoma cerrada a las 23:59 de D-1 (`:corte_reserva_cerrado`). |
| **Secretaría** | Antes de D-1 | Elección de flujo estándar | `Reservado` | Continúa flujo de confirmación por WhatsApp. Si es primera reserva, crea relación. |
| **Secretaría** | Antes de D-1 | Horario ya acordado con paciente | `Confirmado` | Exige registro de declaración simple de aceptación de horario. Crea relación. |
| **Secretaría** | Durante D-1 / Día D | Hasta inicio de turno | `Confirmado` | Exige registro de declaración simple de aceptación de horario. Crea relación. |
| **Profesional** | Antes de D-1 | Paciente de su lista permitida | `Reservado` | Continúa flujo de confirmación por WhatsApp. |
| **Profesional** | Durante D-1 / Día D | Hasta inicio de turno | `Confirmado` | Nace directo en `Confirmado`; omite confirmación por WhatsApp. |

### 2.3 Reglas de Solapamiento e Interferencia

1. **Agenda del Profesional (RF-07, RF-14):**
   - El horario solicitado debe pertenecer a una franja de disponibilidad regular activa del profesional (`Issue #77`).
   - La duración del tipo de consulta (`duration_minutes`) exige intervalos contiguos libres suficientes.
   - No puede solaparse con ningún turno preexistente en estados `Solicitado`, `Reservado` o `Confirmado` del mismo profesional. Los turnos en `Cancelado` liberan inmediatamente el bloque horario (`RF-18`).
2. **Agenda del Paciente (Control de Masividad / Anti-acaparamiento, RF-12):**
   - Un mismo perfil de paciente no puede poseer dos turnos superpuestos en el mismo intervalo de tiempo, sin importar si son con el mismo u otro profesional.
3. **Tipos de Consulta y Catálogo (RF-08, Issue #74):**
   - El tipo de consulta debe pertenecer al profesional seleccionado y estar en estado **activo**.
   - No se permite reservar con tipos inactivos ni de otros profesionales.

### 2.4 Atomicidad y Reversión Transaccional (ACID Rollback)

La operación de reserva ejecuta bajo una única transacción de base de datos (`Ecto.Multi` / `Repo.transaction`) los siguientes efectos:
1. **Persistencia del Turno:** Inserción del registro con los snapshots inmutables:
   - Nombre normalizado del tipo de consulta (`consultation_type_name`).
   - Duración calculada en minutos (`duration_minutes`).
   - Precio base exacto en ARS (`base_price_amount`, tipo `Decimal`, escala monetaria exacta).
2. **Vinculación de Relación Profesional–Paciente:** Si el paciente no tenía relación previa con el profesional y el turno se persiste en `Reservado` o `Confirmado`, se crea el registro de relación auditable (`RF-05`). Si el turno nace en `Solicitado`, la relación **no** se crea.
3. **Auditoría Append-Only:** Emisión del evento de auditoría minimizado conforme a la especificación de auditoría del sistema.

**Garantía de Reversión:** Si cualquier paso de la transacción falla (error de base de datos, violación de restricción de exclusión/solapamiento, fallo de integridad o error en el registro de auditoría), **la transacción entera se revierte por completo (Rollback)**. No se deja turno huérfano, no se crea relación espuria y no se emite auditoría de éxito parcial.

---

## 3. Matriz de Escenarios

### 3.1 Escenarios Exitosos (Válidos)

| ID | Actor | Momento | Precondiciones | Estado Inicial | Snapshots Históricos | Relación Creada | Resultado Observable |
|---|---|---|---|---|---|---|---|
| **V01** | Paciente (primera reserva) | Antes de D-1 | Perfil completo, teléfono verificado, sin multas. Profesional en modo automático. Slot libre. | `Reservado` | Copia nombre, duración y precio exacto. | Sí (crea relación auditable) | `{:ok, %{appointment: ..., relationship_created?: true}}` |
| **V02** | Paciente (primera reserva) | Antes de D-1 | Perfil completo, teléfono verificado. Profesional en modo manual. Slot libre. | `Solicitado` | Copia nombre, duración y precio exacto. | No (permanece oculta al profesional) | `{:ok, %{appointment: ..., relationship_created?: false}}` |
| **V03** | Paciente (autónomo) | Durante D-1 (≤ 23:59) | Perfil completo, teléfono verificado. Slot libre. | `Confirmado` | Copia nombre, duración y precio exacto. | Sí (si era primera cita) | `{:ok, %{appointment: ..., relationship_created?: ...}}` |
| **V04** | Secretaría (asistida) | Antes de D-1 | Paciente con perfil incompleto. Secretaría elige `Reservado`. | `Reservado` | Copia nombre, duración y precio exacto. | Sí (relación válida establecida) | `{:ok, %{appointment: ..., relationship_created?: true}}` |
| **V05** | Secretaría (asistida) | Antes de D-1 | Horario ya acordado con paciente. Secretaría elige `Confirmado` y registra declaración simple. | `Confirmado` | Copia nombre, duración y precio exacto. | Sí (relación válida establecida) | `{:ok, %{appointment: ..., relationship_created?: true}}` |
| **V06** | Secretaría (asistida) | Durante D-1 / Día D | Horario acordado hasta inicio del turno. Nace directo en `Confirmado` con declaración. | `Confirmado` | Copia nombre, duración y precio exacto. | Sí (relación válida establecida) | `{:ok, %{appointment: ..., relationship_created?: true}}` |
| **V07** | Profesional | Antes de D-1 | Paciente ya en lista permitida (relación previa). Slot libre. | `Reservado` | Copia nombre, duración y precio exacto. | No (ya existía relación) | `{:ok, %{appointment: ..., relationship_created?: false}}` |
| **V08** | Profesional | Durante D-1 / Día D | Paciente ya en lista permitida. Creación hasta inicio del turno. | `Confirmado` | Copia nombre, duración y precio exacto. | No (ya existía relación) | `{:ok, %{appointment: ..., relationship_created?: false}}` |
| **V09** | Profesional (aprobación manual) | — | Solicitud en estado `Solicitado` es aprobada por el profesional. | Pasa a `Reservado` o `Confirmado` | Mantiene snapshots congelados al momento de solicitar. | Sí (crea relación al momento de aprobar primer turno válido) | `{:ok, %{appointment: ..., relationship_created?: true}}` |
| **V10** | Paciente (reserva posterior) | Antes de D-1 | Paciente ya relacionado previamente, perfil completo, teléfono verificado. | `Reservado` (o `Solicitado`) | Copia nombre, duración y precio exacto. | No (relación ya existente) | `{:ok, %{appointment: ..., relationship_created?: false}}` |

---

### 3.2 Escenarios Rechazados (Denegados)

| ID | Actor | Causa de Rechazo | Regla Infringida | Comportamiento del Sistema | Resultado Observable |
|---|---|---|---|---|---|
| **R01** | Paciente | Perfil propio `Pendiente de completar` | RF-05 / RF-02 | Deniega la reserva; no inserta turno ni crea relación. | `{:error, :perfil_incompleto}` |
| **R02** | Paciente | Teléfono del destinatario primario no verificado | RF-05 / PLN-15 | Deniega la reserva; no inserta turno ni crea relación. | `{:error, :telefono_no_verificado}` |
| **R03** | Paciente | Paciente posee una multa pendiente impaga con el profesional | RF-12 | Bloquea nueva reserva autónoma con este profesional; no afecta otros profesionales. | `{:error, :multa_pendiente_bloqueante}` |
| **R04** | Paciente | Intento de reserva autónoma el mismo día D o después de las 23:59 de D-1 | RF-10 | Rechaza por cierre de la ventana de reserva pública/autónoma. | `{:error, :corte_reserva_cerrado}` |
| **R05** | Profesional | Intenta reservar para un paciente que no está en su lista permitida | RF-05 | Deniega por defecto en backend; audita intento de acceso no autorizado; no crea nada. | `{:error, :paciente_no_vinculado}` |
| **R06** | Profesional | Intenta navegar o buscar en el registro global de pacientes | RF-05 | Deniega por defecto en backend; audita intento no autorizado. | `{:error, :acceso_denegado}` |
| **R07** | Cualquiera | Tipo de consulta pertenece a otro profesional | RF-08 / PLN-06 | Rechaza por inconsistencia de propiedad del catálogo. | `{:error, :tipo_consulta_ajeno}` |
| **R08** | Cualquiera | Tipo de consulta está inactivo | RF-08 / PLN-06 | Un tipo inactivo no está disponible para nuevas reservas. | `{:error, :tipo_consulta_inactivo}` |
| **R09** | Cualquiera | Horario solicitado fuera de la disponibilidad regular del profesional o durante una ausencia | RF-07 / PLN-07 | Rechaza por falta de franja de atención activa. | `{:error, :horario_no_disponible}` |
| **R10** | Cualquiera | La duración requerida por el tipo de consulta excede los intervalos contiguos libres | RF-07 / RF-08 | No alcanza el bloque horario continuo para la duración total. | `{:error, :duracion_excede_disponibilidad}` |
| **R11** | Secretaría | Intenta crear turno en `Confirmado` sin registrar la declaración obligatoria | RF-10 | Falla validación de entrada por ausencia de declaración requerida. | `{:error, :declaracion_acuerdo_requerida}` |
| **R12** | Profesional | Rechazo manual de una solicitud en `Solicitado` sin motivo obligatorio | RF-14 | Falla validación: el motivo de cancelación/rechazo es estrictamente obligatorio. | `{:error, :motivo_cancelacion_requerido}` |

---

### 3.3 Escenarios de Solapamiento y Concurrencia

| ID | Escenario | Situación Concurrente / Solapamiento | Comportamiento Esperado | Resultado Observable |
|---|---|---|---|---|
| **C01** | Solapamiento en agenda del profesional | Existe ya un turno `Solicitado`, `Reservado` o `Confirmado` que se superpone con el horario solicitado. | Se rechaza la nueva solicitud. Se preserva el turno existente sin modificaciones. | `{:error, :slot_ya_ocupado}` |
| **C02** | Solapamiento del mismo paciente (RF-12) | El paciente ya tiene un turno reservado/confirmado en ese mismo rango horario (incluso con otro profesional). | Se rechaza la solicitud para evitar acaparamiento simultáneo de turnos. | `{:error, :solapamiento_turnos_paciente}` |
| **C03** | Dos solicitudes simultáneas por el mismo slot (Race condition) | Dos solicitudes concurrentes intentan reservar exactamente el mismo intervalo del mismo profesional. | Nivel de aislamiento transaccional y restricción de exclusión en DB: **solo una tiene éxito**; la otra es rechazada limpiamente por colisión. | Solicitud 1: `{:ok, %{...}}` / Solicitud 2: `{:error, :slot_ya_ocupado}` |
| **C04** | Solicitud simultánea de paciente y secretaría | Secretaría y Paciente confirman en el mismo milisegundo el mismo horario. | Solo la primera transacción en serializarse persiste; la perdedora aborta de forma atómica y reporta conflicto de agenda. | Una obtiene `{:ok, ...}`, la otra `{:error, :slot_ya_ocupado}` |

---

### 3.4 Escenarios de Reversión Transaccional (Rollback Atómico)

| ID | Punto de Falla Simulado | Comportamiento Transaccional Esperado | Estado Residual en Base de Datos |
|---|---|---|---|
| **T01** | Falla la inserción de snapshots históricos del turno (ej. fallo de persistencia o restricción de precio/duración). | Transacción abortada inmediatamente (`Ecto.Multi` revierte). | No se crea el turno. No se crea la relación Profesional–Paciente. No se emite auditoría. |
| **T02** | Falla la inserción de la relación Profesional–Paciente en una primera reserva válida. | Rollback total de la operación. | El turno no queda guardado como huérfano. La agenda permanece libre. |
| **T03** | Falla la inserción del evento de auditoría append-only requerido. | Rollback total de la operación. Ninguna acción de dominio persiste sin su auditoría atómica correspondiente. | Estado idéntico al previo a la solicitud. Error reportado: `{:error, :fallo_auditoria}`. |

---

## 4. Estructura de Datos y Resultados Observables

### 4.1 Entrada esperada (a formalizar en #62)
```elixir
%{
  actor: %{role: :patient | :secretary | :professional, id: integer()},
  patient_id: integer(),
  professional_id: integer(),
  consultation_type_id: uuid(),
  start_time: ~U[2026-10-15 09:00:00Z],
  patient_agreed_schedule: boolean() # obligatorio para confirmación asistida
}
```

### 4.2 Salida esperada en éxito (a persistir en #63)
```elixir
{:ok, %{
  appointment: %{
    id: integer(),
    patient_id: integer(),
    professional_id: integer(),
    consultation_type_id: uuid(),
    start_time: ~U[2026-10-15 09:00:00Z],
    status: :reserved, # o :requested, :confirmed
    # Snapshots históricos inmutables (#63)
    consultation_type_name: "Consulta General",
    duration_minutes: 30,
    base_price_amount: Decimal.new("15000.00")
  },
  relationship_created?: true # true si fue la primera reserva válida, false si ya existía o si nació Solicitado
}}
```

---

## 5. Criterios de Aceptación Cumplidos

- [x] Documenta escenarios de reserva para Paciente autónomo, Secretaría asistida y Profesional.
- [x] Detalla elegibilidad, solapamientos, estados iniciales por actor y fecha, y reversión transaccional.
- [x] Incluye casos exitosos (V01–V10), denegados (R01–R12), concurrentes (C01–C04) y transaccionales (T01–T03) con resultados observables.
- [x] Queda como artefacto durable revisable sin exigir pruebas fallidas en la rama principal.
