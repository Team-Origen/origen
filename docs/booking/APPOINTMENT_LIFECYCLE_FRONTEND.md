# Interfaz del ciclo de vida de turnos — Paciente

Esta pantalla implementa el alcance Paciente de #378 sobre las operaciones reales
entregadas por #377. No agrega reglas de autorización: la sesión de Paciente se
valida con `PatientSessionAuthLive` y el servidor vuelve a validar identidad,
alcance, estado y límite temporal en cada operación.

## Recorrido

- `/paciente/turnos` carga el historial persistente con
  `Origen.Booking.list_appointment_history/2` cada vez que se ingresa a la
  pantalla. Incluye `requested`, `confirmed`, `expired`, `cancelled`,
  `attended` y `no_show`.
- La navegación de Paciente usa la navbar compartida de `RoleNavigation` y
  permite pasar entre `/paciente/turnos` y `/paciente/turnos/reservar`. La
  identidad cargada por `PatientSessionAuthLive` conserva el nombre de cuenta,
  correo y el cierre de sesión de Paciente (`POST /paciente/cerrar-sesion`)
  tanto en el historial como en la reserva.
- Un Paciente puede cancelar sus solicitudes y turnos confirmados sólo si el
  inicio todavía no llegó. La interfaz oculta la acción fuera de esa frontera,
  pero la garantía efectiva es `Origen.Booking.cancel_appointment/3`.
- Las cancelaciones realizadas por Profesional o Secretaría muestran origen y
  motivo cuando el historial los contiene. El nombre del Profesional se toma
  del listado seguro existente; si no está disponible, se muestra una etiqueta
  genérica y no un identificador de cuenta. Las fechas y horas se presentan en
  la zona horaria de la organización. No se envían notificaciones desde esta
  pantalla.

La pantalla no permite asistencia, ausencia, pagos ni reprogramación directa.
Cambiar fecha, hora o tipo requiere el flujo existente de cancelar y reservar
nuevamente.

## Verificación

Las pruebas LiveView usan `test/support/appointment_lifecycle_fixtures.ex` con
PostgreSQL real y operaciones públicas del dominio; no usan mocks para la
persistencia del historial o la cancelación. Cubren reingreso e historial
privado, estados vencido/cancelado, origen y motivo, cancelación propia de
solicitudes y confirmados antes del inicio, rechazo de identificadores ajenos,
eventos de asistencia desconocidos sin mutación y rechazo de la frontera al
inicio o después.

La prueba de integración existente conserva el recorrido real de reserva de
Paciente contra `DatabaseCalendar` y `DatabaseCatalog`. La verificación final
depende de una base de pruebas aislada disponible según `config/test.exs`.
