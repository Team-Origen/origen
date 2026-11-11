# Historias de usuario implementadas hasta Sprint 4

Corte: `develop` @ `0c38d8a` (2026-11-11). Método y criterio en el [README](./README.md).

**Convenciones**

- Identificador `HU-<rol>-<n>`. La columna «HU original» indica la historia de `docs/Origen_Documentacion.md` de la que parte, cuando existe.
- «Sprint» es el *milestone* de GitHub de las issues que la entregan.
- Los criterios describen el comportamiento implementado. Lo que el documento original pedía y la beta no incluye está en la [sección 6](#6-pendiente-o-excluido-no-disponible-en-esta-entrega) o en [discrepancias.md](./discrepancias.md).

## Índice

| ID | Historia | Rol | Sprint |
| --- | --- | --- | --- |
| HU-INT-01 | Activar cuenta interna con invitación | Profesional, Secretaría, Administrador | 0, 1 |
| HU-INT-02 | Iniciar y cerrar sesión interna | Profesional, Secretaría, Administrador | 1, 4 |
| HU-PAC-01 | Solicitar enlace de acceso e ingresar | Paciente | 1, 3 |
| HU-PAC-02 | Reservar un turno propio | Paciente | 1, 3, 4 |
| HU-PAC-03 | Consultar «Mis turnos» | Paciente | 4 |
| HU-PAC-04 | Cancelar un turno propio | Paciente | 4 |
| HU-PRO-01 | Completar el perfil profesional | Profesional | 3 |
| HU-PRO-02 | Configurar la agenda y los tipos de consulta | Profesional | 1, 3 |
| HU-PRO-03 | Elegir la modalidad de aprobación | Profesional | 3, 4 |
| HU-PRO-04 | Resolver solicitudes de turno | Profesional | 3, 4 |
| HU-PRO-05 | Consultar la agenda propia | Profesional | 1, 3, 4 |
| HU-PRO-06 | Crear un turno para un paciente registrado | Profesional | 3 |
| HU-PRO-07 | Registrar un paciente nuevo y agendarlo | Profesional | 3 |
| HU-SEC-01 | Buscar un paciente por documento | Secretaría | 1, 3 |
| HU-SEC-02 | Registrar un paciente | Secretaría | 3 |
| HU-SEC-03 | Agendar un turno asistido | Secretaría | 3 |
| HU-SEC-04 | Consultar las agendas del centro | Secretaría | 4 |
| HU-OPE-01 | Cancelar un turno con motivo | Profesional, Secretaría | 4 |
| HU-OPE-02 | Registrar asistencia o ausencia | Profesional, Secretaría | 4 |
| HU-OPE-03 | Vincular el correo de acceso de un paciente | Profesional, Secretaría | 3, 4 |
| HU-ADM-01 | Incorporar al primer Administrador | Administrador (con operador de despliegue) | 0, 1 |
| HU-ADM-02 | Crear cuentas internas e invitar | Administrador | 1 |
| HU-ADM-03 | Reemitir una invitación | Administrador | 1 |
| HU-ADM-04 | Editar el correo de una cuenta interna | Administrador | 4 |
| HU-ADM-05 | Desactivar y reactivar cuentas internas | Administrador | 4 |
| HU-SIS-01 | Vencer solicitudes no resueltas | Sistema | 3, 4 |

## 0. Reglas transversales

Aplican a todas las historias y se consideran parte de sus criterios de aceptación.

1. **Roles.** Hay cuatro roles: Administrador, Profesional y Secretaría (cuentas internas con contraseña y TOTP) y Paciente (acceso sin contraseña por enlace al correo vinculado). Referencia: `lib/origen/authorization/rules.ex:6`.
2. **Denegación por defecto.** Toda operación no autorizada expresamente se deniega, y el Administrador no hereda permisos operativos. La autorización se valida en el servidor; ocultar un botón no es un control de seguridad. Referencias: `openspec/specs/default-deny-authorization/`, `docs/security/AUTHORIZATION_MATRIX.md`.
3. **Privacidad.** El Profesional ve solo su agenda y sus pacientes, sin la actividad de esos pacientes con otros Profesionales. La Secretaría opera todo el centro. El Administrador no accede a pacientes, agendas, turnos ni datos económicos. El Paciente ve solo lo propio. Referencias: contrato #313, contrato #285 §3.
4. **Estados del turno.** `Solicitado` (requested), `Confirmado` (confirmed), `Vencido` (expired), `Cancelado` (cancelled), `Asistió` (attended) y `No asistió` (no_show). Solicitado y Confirmado ocupan el horario. Confirmado significa aprobado, no asistencia. No existe reprogramación directa: cambiar fecha, hora o tipo es cancelar y crear otro turno. Referencias: `docs/sprints/sprint-4/contrato-285-ciclo-operativo-turno.md`, `docs/booking/APPOINTMENT_LIFECYCLE.md`.
5. **Relación Profesional–Paciente.** Se crea en la misma operación que el primer turno Solicitado o Confirmado; buscar o seleccionar sin confirmar no la crea. Referencias: contratos #305, #313, #321.
6. **Datos históricos del turno.** Cada turno guarda copia inmutable del nombre, la duración y el precio de lista del tipo de consulta. Referencia: contrato #305.
7. **Auditoría.** Las operaciones sensibles generan eventos de auditoría de solo agregado y sin secretos. Referencia: `openspec/specs/append-only-audit/`.

## 1. Acceso al sistema

### HU-INT-01 · Activar cuenta interna con invitación

**Como** Profesional, Secretaría o Administrador con una cuenta pendiente de activación, **quiero** definir mi contraseña y enrolar un autenticador TOTP con mi invitación, **para** poder ingresar al sistema de forma segura.

Criterios de aceptación:

- La invitación es de un solo uso, está vinculada a la cuenta y vence a las 24 horas según la hora del servidor.
- La cuenta pasa a Activa solo después de definir la contraseña **y** confirmar un código TOTP válido.
- Una invitación vencida, usada o reemplazada por una reemisión es rechazada.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 4.2, 7 | #55, #56, #121; `openspec/specs/admin-invitation-activation/`; matriz B-02, INV-01 | 0, 1 |

### HU-INT-02 · Iniciar y cerrar sesión interna

**Como** usuario interno con cuenta Activa, **quiero** ingresar con mi correo, contraseña y código TOTP, **para** acceder a las funciones de mi rol.

Criterios de aceptación:

- Se exigen contraseña y TOTP válidos; las cuentas pendientes de activación o desactivadas son rechazadas.
- La sesión dura como máximo 12 horas y se bloquea tras 15 minutos de inactividad (valores por defecto).
- Al ingresar, cada rol ve solo su navegación: Profesional (Agenda, Solicitudes, Ajustes), Secretaría (Agenda, Pacientes) y Administrador (Cuentas).
- El usuario puede cerrar sesión desde el menú de cuenta.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 7 | #52, #53, #54, #368–#371, #409; matriz S1-01, AUTH-01 | 1, 4 |

## 2. Paciente

### HU-PAC-01 · Solicitar enlace de acceso e ingresar

**Como** Paciente con un correo de acceso vinculado por el centro, **quiero** recibir un enlace de acceso en mi correo, **para** ingresar sin contraseña.

Criterios de aceptación:

- La respuesta en pantalla es la misma exista o no el correo, para no revelar qué correos están registrados.
- Solo se envía el enlace si el correo está vinculado a un perfil de Paciente. No hay registro público ni ingreso con Google.
- El enlace vence a los 15 minutos, se usa una sola vez y cada nueva solicitud invalida los enlaces anteriores sin usar.
- Si el personal reemplaza el correo de acceso, las sesiones anteriores del Paciente quedan invalidadas.
- El Paciente puede cerrar la sesión de su navegador.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 8.2 | #85, #86, #277, contrato #297 | 1, 3 |

### HU-PAC-02 · Reservar un turno propio

**Como** Paciente, **quiero** reservar un turno eligiendo profesional, tipo de consulta, fecha y horario disponible, **para** asegurar mi atención sin depender de la secretaría.

Criterios de aceptación:

- La reserva es siempre para el propio Paciente; no se puede reservar para terceros.
- Solo se ofrecen Profesionales con cuenta activa y perfil completo, y tipos de consulta activos.
- Los horarios se calculan en el servidor según la disponibilidad semanal, el intervalo de agenda, la duración del tipo, la anticipación mínima, el horizonte de reserva y los turnos ya ocupados.
- El perfil del Paciente debe estar completo. La verificación del teléfono no es requisito.
- El turno queda Confirmado si el Profesional aprueba automáticamente, o Solicitado si aprueba manualmente. En ambos casos el horario queda ocupado.
- Si otro usuario ocupa el horario en simultáneo, la reserva se rechaza por superposición.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.5.1 | #42, #91–#93, #280, #305–#308, #434; contrato #305 | 1, 3, 4 |

### HU-PAC-03 · Consultar «Mis turnos»

**Como** Paciente, **quiero** ver todos mis turnos, próximos y pasados, con su estado, **para** llevar el control de mis citas.

Criterios de aceptación:

- Se muestran solo los turnos del Paciente autenticado, en cualquiera de los seis estados, del más reciente al más antiguo.
- Si el personal canceló un turno, se ve quién lo canceló (Profesional o Secretaría) y el motivo.
- No se muestran datos clínicos.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.9 | #285, #378, #472; contrato #285 (E6, E13); matriz LIFE-04 | 4 |

### HU-PAC-04 · Cancelar un turno propio

**Como** Paciente, **quiero** cancelar un turno o una solicitud propia antes de su inicio, **para** liberar el horario si no puedo asistir.

Criterios de aceptación:

- Solo se pueden cancelar turnos propios en estado Solicitado o Confirmado y estrictamente antes de su hora de inicio.
- No se exige motivo y no hay multa. El horario queda libre.
- A partir de la hora de inicio, el servidor rechaza la cancelación aunque se intente fuera de la interfaz.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.4 (adaptada) | #377, #378; contrato #285 (E3–E5); matriz LIFE-01 | 4 |

## 3. Profesional

### HU-PRO-01 · Completar el perfil profesional

**Como** Profesional, **quiero** cargar mi nombre, apellido, especialidad, tipo y número de matrícula, **para** aparecer como opción de reserva ante pacientes y secretaría.

Criterios de aceptación:

- Los cinco datos son obligatorios para que el Profesional sea reservable; se puede guardar un perfil parcial y seguir configurando la agenda.
- La matrícula es texto libre, sin catálogo ni verificación.
- Al Paciente solo se le muestran nombre y especialidad.
- Solo el propio Profesional accede a su perfil; Secretaría y Administrador no.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 4.3.2 (adaptada) | #278, #301–#304; contrato #301 | 3 |

### HU-PRO-02 · Configurar la agenda y los tipos de consulta

**Como** Profesional, **quiero** configurar mi intervalo de agenda, mis tipos de consulta, mi disponibilidad semanal, la anticipación mínima y el horizonte de reserva, **para** que solo se ofrezcan horarios reales y compatibles con cada prestación.

Criterios de aceptación:

- El intervalo de agenda va de 5 a 240 minutos en pasos de 5 (30 por defecto); cambiarlo pide confirmación, se aplica de forma atómica y no mueve ni cancela turnos existentes.
- Cada tipo de consulta tiene nombre (hasta 32 caracteres), precio en ARS mayor o igual a 0, color y cantidad de intervalos entre 1 y `min(10, 240 / intervalo)`; la duración no supera 240 minutos.
- Los tipos inactivos no se editan y dejan de ofrecerse solo para reservas nuevas; pueden reactivarse si su duración no supera 240 minutos.
- Los turnos ya creados conservan el nombre, la duración y el precio que tenían al reservarse.
- Solo el Profesional dueño modifica su configuración.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 3.1, 3.2, 3.3 | #39, #40, #73–#78, #303; `openspec/specs/consultation-type-catalog/`, `openspec/specs/agenda-interval/`; matriz S1-09, S1-10 | 1, 3 |

### HU-PRO-03 · Elegir la modalidad de aprobación

**Como** Profesional, **quiero** elegir si apruebo las reservas de forma automática o manual, y cómo nacen las reservas que hace la Secretaría, **para** controlar qué turnos entran a mi agenda.

Criterios de aceptación:

- Estado inicial de cada reserva según la modalidad:

  | Canal | Automática | Manual, Secretaría confirma | Manual, Secretaría solicita |
  | --- | --- | --- | --- |
  | Paciente | Confirmado | Solicitado | Solicitado |
  | Secretaría | Confirmado | Confirmado | Solicitado |
  | Profesional | Confirmado | Confirmado | Confirmado |

- El cambio de modalidad afecta solo a reservas nuevas; las solicitudes pendientes no cambian.
- Solo el Profesional dueño puede cambiarla.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.7 (adaptada) | #284, #321–#324, #472; contrato #321 | 3, 4 |

### HU-PRO-04 · Resolver solicitudes de turno

**Como** Profesional con aprobación manual, **quiero** aceptar o rechazar las solicitudes pendientes, **para** decidir qué turnos atiendo.

Criterios de aceptación:

- Solo el Profesional dueño de la agenda resuelve sus solicitudes; Secretaría, Administrador, Paciente y otros Profesionales no pueden.
- Aceptar pasa la solicitud a Confirmado y mantiene ocupado el horario. Rechazar la pasa a Cancelado y libera el horario.
- Un turno que no está Solicitado no puede aceptarse ni rechazarse.
- Las solicitudes se listan por fecha, sin filtro diario.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.7 | #284, #321–#324, #472; contrato #321 | 3, 4 |

### HU-PRO-05 · Consultar la agenda propia

**Como** Profesional, **quiero** ver mi agenda por día con el estado de cada turno, **para** organizar mi jornada.

Criterios de aceptación:

- Se muestran solo los turnos de la agenda del Profesional autenticado, en los seis estados y en la zona horaria de la organización.
- Cambiar identificadores en la URL o en la petición no amplía el alcance.
- No se muestra la actividad de esos pacientes con otros Profesionales.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.1, 2.8 (adaptadas) | #43, #79–#81, #282, #378; contrato #313; matriz S1-14, AGENDA-01, LIFE-05 | 1, 3, 4 |

### HU-PRO-06 · Crear un turno para un paciente registrado

**Como** Profesional, **quiero** crear un turno en mi agenda para un paciente con el que ya tengo relación o que encuentro por su DNI exacto, **para** coordinar consultas de seguimiento.

Criterios de aceptación:

- El Profesional elige entre sus pacientes relacionados o busca por DNI exacto; no hay listado global ni búsqueda parcial.
- Se muestran solo nombre, apellido y DNI del paciente.
- El turno se crea solo en la agenda propia y nace Confirmado aun con aprobación manual.
- El horario debe estar disponible; la reserva crea o reutiliza la relación en la misma operación.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.2, 2.5.3 | #282, #313–#316; contrato #313 | 3 |

### HU-PRO-07 · Registrar un paciente nuevo y agendarlo

**Como** Profesional, **quiero** registrar a un paciente que no existe en el sistema y darle un turno en el mismo paso, **para** no depender de la secretaría ante una primera consulta.

Criterios de aceptación:

- Solo se ofrece después de buscar el DNI exacto y no encontrarlo.
- Son obligatorios nombre, apellido, DNI, fecha de nacimiento y teléfono; el correo de contacto es opcional.
- El alta, el turno Confirmado, la relación y la auditoría se guardan en una sola operación: si algo falla, no queda nada guardado.
- No se crea cuenta ni se envía enlace de acceso. Si otro usuario registró ese DNI mientras tanto, se rechaza el duplicado.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 1.1, 2.5.3 (adaptadas) | #283, #317–#320; `docs/sprints/sprint-3/contrato-283-alta-y-reserva-profesional.md` | 3 |

## 4. Secretaría

### HU-SEC-01 · Buscar un paciente por documento

**Como** Secretaría, **quiero** buscar a un paciente por tipo y número de documento, **para** saber si ya está registrado antes de darlo de alta o agendarlo.

Criterios de aceptación:

- El número se normaliza (sin puntos, guiones ni espacios) antes de buscar.
- La búsqueda es obligatoria antes de registrar y queda auditada.
- Solo la Secretaría puede usar esta búsqueda; Profesional y Administrador no.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 1.4 (adaptada) | #67, #276, #293–#296; contrato #293 | 1, 3 |

### HU-SEC-02 · Registrar un paciente

**Como** Secretaría, **quiero** registrar a un paciente que no existe en el sistema, **para** poder darle turnos.

Criterios de aceptación:

- Son obligatorios nombre, apellido, tipo y número de documento, fecha de nacimiento (pasada) y teléfono; el correo de contacto es opcional.
- El documento es único: un duplicado se rechaza.
- El alta no crea cuenta de acceso, no envía enlace y no exige teléfono verificado; el perfil queda listo para reservar.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 1.1 | #276, #293–#296; contrato #293 | 3 |

### HU-SEC-03 · Agendar un turno asistido

**Como** Secretaría, **quiero** agendar a un paciente registrado en la agenda de cualquier Profesional, **para** asistir a quien no reserva por sus propios medios.

Criterios de aceptación:

- Se puede elegir cualquier Profesional activo con perfil completo, un tipo de consulta activo y un horario disponible.
- El estado inicial depende de la modalidad de aprobación del Profesional (ver HU-PRO-03).
- El turno, la relación Profesional–Paciente y la auditoría se guardan en una sola operación.
- No se exige teléfono verificado ni correo de acceso del paciente.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.5.2 | #281, #309–#312; contrato #309 | 3 |

### HU-SEC-04 · Consultar las agendas del centro

**Como** Secretaría, **quiero** ver los turnos de todas las agendas del centro agrupados por fecha, **para** dar seguimiento a la operación diaria.

Criterios de aceptación:

- Se muestran los turnos de todos los Profesionales, en los seis estados y en la zona horaria de la organización.
- El Administrador no tiene acceso a esta vista.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.1 (adaptada) | #285, #378; matriz LIFE-06 | 4 |

## 5. Operación compartida y administración

### HU-OPE-01 · Cancelar un turno con motivo

**Como** Profesional o Secretaría, **quiero** cancelar un turno o una solicitud indicando el motivo, **para** liberar el horario y que el paciente sepa por qué.

Criterios de aceptación:

- El Profesional cancela solo turnos de su agenda; la Secretaría, de cualquier agenda.
- Solo se cancelan turnos Solicitados o Confirmados, con un motivo obligatorio.
- El turno queda Cancelado, el horario se libera y el Paciente ve el origen (Profesional o Secretaría) y el motivo.
- No hay multa ni notificación automática. Cancelar no equivale a rechazar una solicitud.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.4 | #377–#379; contrato #285 (E7–E10); matriz LIFE-02, LIFE-03 | 4 |

### HU-OPE-02 · Registrar asistencia o ausencia

**Como** Profesional o Secretaría, **quiero** marcar si el paciente asistió o no a un turno Confirmado, **para** dejar registrado el resultado de la atención.

Criterios de aceptación:

- Solo se aplica a turnos Confirmados: pasan a Asistió o No asistió. Las solicitudes y los turnos vencidos, cancelados o ya cerrados se rechazan sin cambios.
- El Profesional opera sobre su agenda; la Secretaría, sobre cualquiera.
- No hay ventana horaria, corrección posterior ni multas.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 2.1 (cierre del turno, adaptada) | #377–#379; contrato #285; matriz LIFE-07, LIFE-08 | 4 |

### HU-OPE-03 · Vincular el correo de acceso de un paciente

**Como** Profesional o Secretaría, **quiero** vincular un correo de acceso a un paciente después de verificar su identidad fuera del sistema, **para** que pueda ingresar con enlace por correo.

Criterios de aceptación:

- Solo para pacientes sin correo de acceso; el correo no puede estar usado por otro paciente.
- Se envía un enlace que prueba la posesión del correo y la operación queda auditada.
- No modifica la identidad del paciente ni su historial. El Administrador no puede hacerlo.
- El reemplazo de un correo ya vinculado existe en el sistema (con motivo, invalidando enlaces y sesiones previas), pero su botón está oculto desde #472 y su ubicación depende de #471: **no se presenta como disponible en la interfaz**.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 1.3 (adaptada) | #277, #297–#300, #471, #472; contrato #297 | 3, 4 |

### HU-ADM-01 · Incorporar al primer Administrador

**Como** responsable del despliegue, **quiero** dar de alta al primer Administrador mediante un proceso controlado de despliegue, **para** que el sistema tenga un administrador sin credenciales por defecto.

Criterios de aceptación:

- El alta se hace por línea de comandos de despliegue, no desde la aplicación, y requiere un confirmador distinto del operador.
- Solo es posible si no existe ningún Administrador; la cuenta queda pendiente y se activa con HU-INT-01.
- Disponible solo en entornos no productivos; el alta en producción está pendiente (#452).

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 7 | #3, `openspec/specs/first-admin-bootstrap/`, `docs/deployment/FIRST_ADMIN_BOOTSTRAP.md`; matriz B-00, B-01 | 0, 1 |

### HU-ADM-02 · Crear cuentas internas e invitar

**Como** Administrador, **quiero** crear cuentas de Profesional o Secretaría y emitir su invitación, **para** incorporar al personal del centro.

Criterios de aceptación:

- Solo se crean cuentas de Profesional o Secretaría, no de Administrador.
- El correo debe ser válido y único sin distinguir mayúsculas; la cuenta queda pendiente de activación.
- Se emite una invitación de un solo uso con vencimiento a las 24 horas, y la operación queda auditada.
- El sistema no envía la invitación por correo: el Administrador la ve en pantalla y la entrega (mejora pendiente en #473).
- El listado de cuentas muestra correo, rol, estado y cantidad de turnos futuros afectados, sin datos de pacientes.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 4.2 (adaptada) | #37, #44, #55, #58–#60, #279; matriz S1-02, S1-03, INV-01 | 1, 4 |

### HU-ADM-03 · Reemitir una invitación

**Como** Administrador, **quiero** reemitir la invitación de una cuenta pendiente, **para** que pueda activarse si la anterior venció o se perdió.

Criterios de aceptación:

- Solo para cuentas de Profesional o Secretaría pendientes de activación.
- Las invitaciones anteriores quedan inválidas y la nueva vence a las 24 horas; no se duplica la cuenta.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| — | matriz B-03, REI-02 | 1 |

### HU-ADM-04 · Editar el correo de una cuenta interna

**Como** Administrador, **quiero** corregir el correo de una cuenta de Profesional o Secretaría, **para** mantener actualizado su acceso.

Criterios de aceptación:

- El correo debe ser válido y único sin distinguir mayúsculas.
- Se conservan la cuenta, sus turnos, relaciones, perfil y ajustes; el Administrador no accede a esos datos.
- No aplica a cuentas de Administrador.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 4.3.1 (adaptada) | #279, #372–#375; contrato #372 | 4 |

### HU-ADM-05 · Desactivar y reactivar cuentas internas

**Como** Administrador, **quiero** desactivar o reactivar la cuenta de un Profesional o una Secretaría, **para** controlar quién opera en el centro sin perder su historial.

Criterios de aceptación:

- Al desactivar se cortan las sesiones activas y se revocan las invitaciones pendientes; un Profesional desactivado deja de recibir reservas nuevas por los tres canales.
- Ningún turno existente se cancela: el Administrador solo ve **cuántos** turnos futuros quedan afectados, para que la Secretaría los gestione.
- El Administrador no puede desactivarse a sí mismo ni operar sobre otros Administradores.
- Al reactivar, la cuenta vuelve a Activa (o a pendiente si nunca se activó) y no se restauran turnos cancelados.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| 4.4 (adaptada) | #279, #372–#375; contrato #372 | 4 |

### HU-SIS-01 · Vencer solicitudes no resueltas

**Como** sistema, **quiero** marcar como vencidas las solicitudes que llegan a su hora de inicio sin resolverse, **para** liberar el horario sin intervención manual.

Criterios de aceptación:

- Una solicitud que alcanza su hora de inicio en estado Solicitado pasa a Vencido y libera el horario.
- No cuenta como ausencia del paciente ni genera multa.

| HU original | Referencias | Sprint |
| --- | --- | --- |
| — | #284, #285; `docs/booking/APPOINTMENT_LIFECYCLE.md` | 3, 4 |

## 6. Pendiente o excluido: no disponible en esta entrega

### 6.1 Pendiente (planificado, sin implementación completa al corte)

| Capacidad | Rol | Estado al corte | Issues |
| --- | --- | --- | --- |
| Registrar pagos, editar precio final y corregir pagos | Profesional, Secretaría | Contrato aprobado y maqueta solo en desarrollo; sin backend | #287, #384, #385, #386, #387 |
| Ver precio final y estado de pago de los turnos propios | Paciente | Contrato aprobado; sin backend | #287, #384, #385 |
| Resumen económico por fecha de turno | Profesional, Secretaría | Maqueta con **datos ficticios**, accesible desde la navegación; sin backend | #288, #388, #389, #390, #391 |
| Listado y gestión de pacientes; ubicación de vincular y reemplazar correo | Profesional, Secretaría | En curso | #471 |
| Enlace de invitación utilizable y conexión entre pantallas de acceso | Administrador, Visitante | En curso | #473 |
| Alta del primer Administrador en producción | Operador de despliegue | Abierta | #452 |
| Bloqueo de rangos puntuales de agenda | Profesional, Secretaría | Planificado para Sprint 5 | #286, #380–#383 |
| Consulta de auditoría de solo lectura | Administrador | Declarada en la matriz; sin implementación ni issue | — |
| Corrección de identidad del paciente y vista de datos propios | Profesional, Secretaría, Paciente | Prevista en OpenSpec; sin implementación ni issue | — |
| Foto de perfil profesional | Profesional | Última prioridad del contrato #301 | #301 |
| Cambio y recuperación de credenciales internas, dispositivo confiable | Usuarios internos | Especificado en el documento original; sin implementación ni issue | — |

### 6.2 Excluido de la beta

No forman parte de la entrega según `openspec/changes/health-center-beta-core/specs/beta-boundaries/`: WhatsApp y recordatorios, verificación telefónica obligatoria para reservar, regla D-1, multas, reprogramación directa, lista de espera, notas de devolución e historia clínica, comprobantes, pagos parciales, saldos a favor y devoluciones, representación de pacientes y reservas para terceros, ingreso con Google, autoedición del paciente, verificación de matrículas y reportes avanzados.

La pantalla legada de verificación telefónica del Paciente (Sprint 1) sigue en el código, pero no está en la navegación ni es requisito para reservar; no se documenta como historia de esta entrega.
