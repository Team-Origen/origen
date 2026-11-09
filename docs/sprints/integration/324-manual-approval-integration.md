# #324 — Integración y verificación: resolución de solicitudes con aprobación manual

## Alcance y prerrequisitos

Integra y verifica el alcance completo de la issue padre [#284](https://github.com/Team-Origen/origen/issues/284) utilizando el [contrato aprobado #321](../contracts/321-aprobacion-manual-solicitudes.md), el backend de [#322](https://github.com/Team-Origen/origen/issues/322) y la interfaz de [#323](https://github.com/Team-Origen/origen/issues/323) conectados con las implementaciones reales de los tres canales de reserva ([#280](https://github.com/Team-Origen/origen/issues/280), [#281](https://github.com/Team-Origen/origen/issues/281), [#282](https://github.com/Team-Origen/origen/issues/282) y [#283](https://github.com/Team-Origen/origen/issues/283)).

- **OpenSpec change:** `health-center-beta-core`
- **Ruta:** `openspec/changes/health-center-beta-core/`
- **Alcance:** Sprint 3 / parent #284 / integration (#324)
- **Blockers nativos resueltos:** `#321`, `#322`, `#323`, `#280`, `#281`, `#282` y `#283` (todos cerrados y aprobados en GitHub).
- **Referencia inversa:** `openspec/changes/health-center-beta-core/proposal.md` ya declara `Parent #284: Contract #321; Backend #322; Frontend #323; Integration and verification #324`.

## Recorrido integrado real y navegación desde la navbar

1. **Acceso desde la barra de navegación de cada rol:**
   - **Profesional** (`#role-navigation[data-role="professional"]`): `#nav-agenda` lleva directamente a `/profesional/agenda`, donde se operan el panel de modalidad de aprobación (`#approval-config-panel`), el listado diario con solicitudes pendientes (`#request-actions-*`) y el botón `#create-professional-appointment` hacia `/profesional/agenda/crear`.
   - **Secretaría** (`#role-navigation[data-role="secretary"]`): `#nav-patients` lleva a `/secretaria/pacientes` para la búsqueda por documento y reserva asistida en todas las agendas del centro.
   - **Paciente** (`#role-navigation[data-role="patient"]`): `#nav-book` lleva a `/paciente/turnos/reservar` tras autenticarse por Magic Link.

2. **Matriz normativa de modalidades en los tres canales reales (sin dobles):**
   - **Modo automático (`approval_mode: :automatic`):**
     - Paciente autónomo (`/paciente/turnos/reservar` → `BookingService.reserve/2`): nace `confirmed`.
     - Secretaría asistida (`/secretaria/pacientes` → `AssistedBooking.reserve/4`): nace `confirmed` (incluso si `secretary_approval_mode` permanecía en `requested`).
     - Profesional propio (`/profesional/agenda/crear` → `Booking.reserve_professional_appointment/3` y `Booking.register_and_reserve_professional_appointment/2`): nace siempre `confirmed`.
   - **Modo manual con subconfiguración de Secretaría en confirmación directa (`approval_mode: :manual`, `secretary_approval_mode: :confirmed`):**
     - Paciente autónomo: nace `requested`, ocupa inmediatamente el horario y establece la relación durable `ProfessionalPatientRelationship`.
     - Secretaría asistida: nace `confirmed`.
     - Profesional propio (paciente existente relacionado o por DNI exacto, y paciente inexistente dado de alta en el acto): nace siempre `confirmed`.
   - **Modo manual con subconfiguración de Secretaría en solicitud (`approval_mode: :manual`, `secretary_approval_mode: :requested`):**
     - Paciente autónomo: nace `requested`, ocupa el horario y establece `ProfessionalPatientRelationship`.
     - Secretaría asistida: nace `requested`, ocupa el horario y establece `ProfessionalPatientRelationship`.
     - Profesional propio (paciente existente e inexistente): nace siempre `confirmed`.

3. **Ocupación, resolución exclusiva y liberación de horario:**
   - Toda solicitud `requested` excluye el bloque horario en `DatabaseCalendar.get_daily_schedule/3`, `AssistedBooking.get_daily_schedule/3`, `Booking.get_professional_booking_schedule/4` y `Booking.check_overlaps/2`, rechazando intentos solapados en cualquiera de los tres canales sin efectos parciales.
   - En `/profesional/agenda`, únicamente los turnos en estado `requested` exhiben los controles **Aceptar** (`#accept-request-<id>`) y **Rechazar** (`#reject-request-<id>`).
   - **Aceptar (`Booking.accept_request/2`):** transiciona atómicamente `requested -> confirmed` bajo `FOR UPDATE`, emite el evento append-only `appointment_confirmed`, conserva la ocupación del horario y actualiza reactivamente el badge a `Confirmado`.
   - **Rechazar (`Booking.reject_request/2`):** transiciona atómicamente `requested -> cancelled` bajo `FOR UPDATE`, emite el evento append-only `appointment_cancelled`, actualiza el badge a `Cancelado` y **libera inmediatamente el horario** para que cualquier canal pueda reservar ese mismo slot.
   - Intentos de aceptar o rechazar turnos ya `confirmed` o `cancelled` devuelven `{:error, :invalid_status_transition}` sin alterar datos.

4. **Delimitación de permisos y preservación de pendientes ante cambios de modalidad:**
   - Otros Profesionales (distintos al dueño de la agenda), Secretaría, Administrador, Paciente y sesiones revocadas reciben `{:error, :unauthorized}` al invocar `accept_request`, `reject_request` o `update_approval_configuration`, sin mutar turnos ni configuraciones.
   - Alternar `approval_mode` (`manual <-> automatic`) o `secretary_approval_mode` (`confirmed <-> requested`) afecta exclusivamente a las reservas nuevas; las solicitudes `requested` existentes permanecen intactas y continúan ocupando su horario hasta decisión explícita del profesional dueño.
   - Se mantiene fuera de este slice el vencimiento automático y el resto del ciclo operativo de `#285`.

## Ajustes de integración realizados en #324

Siguiendo la guía de trabajo beta (resolver brechas de conexión en Integración sin reabrir `#322`/`#323`):

- `lib/origen/booking/request_resolution.ex` y `lib/origen_web/live/professional_agenda_live.ex`:
  - `accept_request/3`, `reject_request/3` y `update_approval_configuration/2` aceptan tanto el `account_id` entero como el principal de sesión (`%{session_id: ..., account_id: ...}` / `%InternalSession{}`), revalidando la sesión activa con `Origen.Sessions.revalidate_principal/2` para que una sesión revocada mientras `ProfessionalAgendaLive` permanece abierta falle cerrado con `{:error, :unauthorized}` sin mutar datos.
- `lib/origen_web/live/professional_agenda_live.ex`:
  - Desambigua los identificadores DOM de estado y acciones de acceso personal del paciente (`#patient-access-status-*`, `#btn-open-link-access-*`, `#btn-open-replace-access-*`) cuando un mismo paciente registra más de un turno o solicitud en la misma fecha, preservando intactos los selectores de la primera aparición y evitando colisiones de IDs duplicados en LiveView.

## Verificación ejecutada

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test mix test \
  test/origen_web/live/manual_approval_integration_test.exs \
  test/origen/booking/request_resolution_test.exs \
  test/origen_web/live/professional_agenda_live_test.exs \
  test/origen_web/live/secretary_booking_integration_test.exs \
  test/origen_web/live/professional_booking_integration_test.exs \
  test/origen_web/live/patient_booking_integration_test.exs
```

## Aprobación explícita de integración (#324) y cierre de #284

Verificados los escenarios `C1`–`C12` del contrato `#321` y todos los criterios de aceptación de `#284` con los tres canales reales sin dobles, Lucca Giordana (`ChordanDev`, responsable de `#284` y sus subissues `#321`–`#324`) registra la **aprobación explícita** de `#324`, habilitando el cierre de la issue padre `#284`.
