# #312 — Integración y verificación: agenda de paciente existente desde Secretaría

## Alcance y prerrequisitos

Integra y verifica el alcance completo de la issue padre [#281](https://github.com/Team-Origen/origen/issues/281) utilizando el [contrato aprobado #309](../contracts/309-agenda-paciente-existente-secretaria.md), el backend de [#310](https://github.com/Team-Origen/origen/issues/310) y la interfaz de [#311](https://github.com/Team-Origen/origen/issues/311).

- **OpenSpec change:** `health-center-beta-core`
- **Ruta:** `openspec/changes/health-center-beta-core/`
- **Alcance:** Sprint 3 / parent #281 / integration (#312)
- **Blockers nativos resueltos:** `#309`, `#310`, `#311`, `#276` y `#278` (todos cerrados y aprobados).

## Recorrido integrado real

Desde una sesión interna activa con rol **Secretaría** (`:secretary`), en `/secretaria/pacientes`:

1. **Búsqueda de paciente existente:**
   - Secretaría busca por tipo y número de documento (`#persona-search-form`).
   - Al localizar una persona registrada con `PatientProfile`, se despliega `#patient-summary-section` con sus datos identificatorios y estado de perfil.
   - No se exige teléfono verificado ni correo de acceso personal para agendar un turno asistido.
   - El alta de paciente inexistente se mantiene separada bajo el alcance de `#276`.
2. **Selección de agenda del centro y consulta:**
   - Al accionar **Iniciar Reserva Asistida** (`#start-assisted-booking`), se listan todos los profesionales activos del centro con perfil completo (`DatabaseCalendar.list_professionals/0`).
   - Secretaría puede alternar entre cualquier profesional del centro, sus tipos de consulta activos (`AssistedBooking.list_consultation_types/1`) y la fecha deseada.
3. **Disponibilidad real y ocupación:**
   - `AssistedBooking.get_daily_schedule/3` consulta las ventanas semanales reales, intervalo de agenda, anticipación mínima (`minimum_lead_minutes`), horizonte (`booking_horizon_days`) y **excluye los turnos activos persistidos** (`status NOT IN ('cancelled', 'rejected')`).
   - `AssistedBooking.reserve/4` valida en servidor que el horario solicitado pertenezca efectivamente a la disponibilidad real del profesional antes de delegar en la transacción atómica `Origen.Booking.reserve_appointment/2`.
   - Se retira la exigencia histórica de `patient_agreed_schedule`.
4. **Contrato de modalidad de aprobación y relación Profesional–Paciente:**
   - La modalidad se determina exclusivamente desde `agenda_settings` en el servidor (ignorando parámetros del cliente):
     - `approval_mode: :automatic` → el turno nace `confirmed`.
     - `approval_mode: :manual` con `secretary_approval_mode: :confirmed` → el turno nace `confirmed`.
     - `approval_mode: :manual` con `secretary_approval_mode: :requested` → el turno nace `requested`.
   - Tanto `confirmed` como `requested` ocupan inmediatamente el horario, refrescan la grilla de slots disponibles y crean la relación durable `ProfessionalPatientRelationship` junto con el evento de auditoría append-only.
5. **Delimitación de permisos:**
   - Secretaría **no** puede aceptar ni rechazar solicitudes pendientes (`AssistedBooking.approve_request/2`, `AssistedBooking.reject_request/2` y `Origen.Booking.RequestResolution` devuelven `{:error, :unauthorized}`, y la interfaz no expone controles de resolución).
   - Administrador y Profesional tienen denegado tanto el montaje de `/secretaria/pacientes` como la ejecución de `AssistedBooking.reserve/4`.

## Ajustes de integración realizados en #312

Siguiendo la guía de trabajo beta (resolver defectos de conexión en Integración sin reabrir `#310`/`#311`):

- `lib/origen/appointments/assisted_booking.ex`:
  - `get_daily_schedule/3` ahora inyecta las ocupaciones activas persistidas (`Appointment` en estados activos para ese profesional y fecha) al consultar el adaptador de calendario, evitando que horarios ya tomados sigan mostrándose como disponibles.
  - `reserve/4` valida que el `start_time` pertenezca a un slot real disponible según ventanas semanales, duración, anticipación mínima y horizonte del profesional (`validate_slot_availability/5`), devolviendo `:slot_already_booked`, `:patient_schedule_conflict` o `:slot_unavailable` sin efectos parciales.
  - Agrega `get_secretary_effective_approval_mode/1` para reflejar la combinación real de `approval_mode` y `secretary_approval_mode`.
- `lib/origen_web/live/secretary_patient_live.ex`:
  - Refresca la grilla de horarios disponibles inmediatamente después de confirmar o ante una colisión concurrente.
  - Muestra el badge de modalidad de aprobación efectivo para el canal de Secretaría y mantiene una guarda defensiva de rol `:secretary`.

## Verificación ejecutada

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test mix test \
  test/origen_web/live/secretary_booking_integration_test.exs \
  test/origen_web/live/secretary_patient_live_test.exs \
  test/origen/appointments/assisted_booking_test.exs \
  test/origen/booking/request_resolution_test.exs
```
