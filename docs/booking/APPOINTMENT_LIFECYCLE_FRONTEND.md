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

## Recorrido del Profesional

La Agenda del Profesional conserva la ruta `/profesional/agenda` y el filtro
existente `?date=AAAA-MM-DD`. Cada ingreso reutiliza la sesión interna vigente y
carga la agenda propia mediante `Origen.Booking.get_professional_agenda/2`; el
historial operativo se consulta por separado con
`Origen.Booking.list_appointment_history/2`, que vuelve a validar la sesión y
aplica el alcance de la agenda en el servidor.

- Las solicitudes `requested` y los turnos `confirmed` de la agenda muestran
  cancelación con motivo obligatorio. El motivo se valida en el formulario y
  nuevamente en `Origen.Booking.cancel_appointment/3`; una denegación conserva
  estado, ocupación e historial.
- Sólo los turnos `confirmed` muestran controles para marcar `attended` o
  `no_show`. La operación real es `Origen.Booking.record_attendance/4`, por lo
  que un intento forjado sobre una solicitud, un vencido o una agenda ajena no
  cambia datos ni revela historia.
- El historial propio permanece visible después de cancelar o registrar un
  resultado. Expone estado, fecha, tipo, origen y motivo de cancelación cuando
  corresponden, sin notas clínicas, notificaciones automáticas, multas ni
  reprogramación directa.
- `expired` se presenta como vencido y no como ausencia. Cambiar fecha, hora o
  tipo exige cancelar el original y crear otro turno por el flujo autorizado.
- La interfaz mantiene acciones con botones y formularios navegables por
  teclado, foco visible, etiquetas asociadas, mensajes `role="alert"`/`status`
  y composición adaptable a pantallas angostas. No se agrega una ruta ni un
  filtro nuevo para estas acciones.

## Verificación del alcance Profesional

Las pruebas LiveView de `test/origen_web/live/professional_agenda_lifecycle_live_test.exs`
usan PostgreSQL real y `AppointmentLifecycleFixtures`; no usan mocks para
historial, cancelación ni asistencia. Cubren historial persistente al
reingresar, motivo obligatorio sin mutación, cancelación de solicitudes y
confirmados, ambos resultados de asistencia, rechazo de estados no confirmados
o vencidos y rechazo de un identificador de otra agenda sin fuga de historial.
Las pruebas existentes de `professional_agenda_live_test.exs` conservan
aceptación/rechazo #284 y el parámetro de fecha. La prueba de dominio
`request_resolution_test.exs` permanece incluida como regresión del recorrido
anterior.

La evidencia de este slice es funcional sobre la base desechable indicada por
la tarea; no certifica la suite completa ni la verificación independiente de
privacidad/seguridad, que pertenecen al T4.

## Recorrido de Secretaría

La ruta canónica `/secretaria/agenda` ofrece a Secretaría la operación de todas
las agendas del centro. Reutiliza la sesión interna revalidada y consulta
`Booking.list_appointment_history/1`; la lista segura de profesionales sólo
identifica la agenda en la presentación.

- Presenta `requested`, `confirmed`, `expired`, `cancelled`, `attended` y
  `no_show`, junto con fecha, tipo, origen y motivo cuando corresponden.
- Permite cancelar solicitudes y confirmados con motivo obligatorio mediante
  `Booking.cancel_appointment/3`, y registrar asistencia o ausencia únicamente
  sobre confirmados mediante `Booking.record_attendance/3`.
- No ofrece aceptar/rechazar solicitudes, reprogramación, notificaciones,
  multas ni otras operaciones fuera del contrato. Los identificadores inválidos,
  sesiones vencidas y denegaciones del servidor se manejan sin mutar la vista.

La navegación de Secretaría usa la navbar compartida de `RoleNavigation`: conserva
el enlace funcional a `/secretaria/pacientes`, marca como activa la agenda actual y
habilita la entrada a `/secretaria/agenda`, de acuerdo con
`docs/navigation/URL_CONVENTIONS.md`. El menú de cuenta conserva el cierre de sesión
interno y muestra la identidad de Secretaría obtenida por
`Origen.Accounts.get_own_navigation_identity/1`, sin cambiar autorización. La prueba
`test/origen_web/live/secretary_agenda_live_test.exs` usa PostgreSQL real y
fixtures persistentes para verificar autorización, los seis estados, cancelación
en múltiples agendas, motivo en blanco sin mutación, asistencia/ausencia,
identificadores forjados y visibilidad del origen Secretaría en la historia
pública del Paciente. Es evidencia de LiveView y dominio real, no una prueba de
navegador, despliegue o integración final de #285; la verificación independiente
queda a cargo de T4.
