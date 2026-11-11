# Historias de usuario

Historias de usuario del sistema de gestión de turnos Origen, agrupadas por módulo. La numeración coincide con la del [diagrama de casos de uso](./casos-de-uso.md).

## Escala de estimación

| Atributo | Rango / Escala | Descripción |
| --- | --- | --- |
| Valor | 1-34 | Secuencia de Fibonacci. 1: Simple, 34: Muy grande |
| Prioridad | 1 - 5 | 1: Postergable, 3: Normal, 5: Inmediato. |
| Estimación | 1h - 48h | Tiempo de desarrollo activo. Si > 48h, se fragmenta. |

## 1. Gestión de Pacientes

### HISTORIA DE USUARIO Núm: 1.1 | Alta paciente

| Historia | Estimación |
| --- | --- |
| **Como** Secretaria,<br>**quiero** registrar un nuevo paciente ingresando sus datos personales,<br>**para** poder incorporarlo al sistema y permitir la gestión de sus turnos. | **Valor:** 8<br>**Prioridad:** 5<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que nombre, apellido, tipo y número de documento, fecha de nacimiento (pasada) y teléfono sean obligatorios, y que el correo de contacto sea opcional.
- Comprobar que el número de documento se normalice (sin puntos, guiones ni espacios) y que un documento ya registrado sea rechazado como duplicado.
- Comprobar que, antes de registrar, la Secretaria deba buscar al paciente por documento (ver 1.4).
- Comprobar que, tras el alta, el perfil quede listo para reservar turnos; el acceso del paciente al portal se habilita al vincular su correo (ver 1.3).
- Comprobar que el Profesional también pueda registrar a un paciente inexistente en el mismo paso en que le asigna un turno (ver 2.2).
- Dado que los datos son válidos y el documento no existe, cuando la Secretaria confirma el alta, entonces el sistema registra al paciente y deja la operación auditada.

**HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Núm: 1.3 | Modificación paciente (correo de acceso)

| Historia | Estimación |
| --- | --- |
| **Como** Secretaria o Profesional,<br>**quiero** vincular un correo de acceso a un paciente después de verificar su identidad fuera del sistema,<br>**para** que pueda ingresar al portal con un enlace enviado a su correo. | **Valor:** 8<br>**Prioridad:** 3<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que solo se pueda vincular un correo a pacientes que todavía no tienen correo de acceso.
- Comprobar que el correo no pueda estar en uso por otro paciente.
- Comprobar que el sistema envíe un enlace que prueba la posesión del correo y que la operación quede auditada.
- Comprobar que la operación no modifique la identidad del paciente ni su historial de turnos.
- Comprobar que el Administrador no pueda realizar esta operación.

**HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Núm: 1.4 | Listar pacientes (búsqueda)

| Historia | Estimación |
| --- | --- |
| **Como** Secretaria/Profesional,<br>**quiero** encontrar a un paciente registrado en el sistema,<br>**para** poder consultar su información y gestionar sus turnos. | **Valor:** 5<br>**Prioridad:** 3<br>**Estimación:** 8 h |

**Validación:**

- Comprobar que la Secretaria pueda buscar a un paciente por tipo y número de documento y que la búsqueda quede auditada.
- Comprobar que el Profesional solo vea a los pacientes con los que ya tiene relación y pueda buscar a otro únicamente por DNI exacto, sin listado global ni búsqueda parcial.
- Comprobar que al Profesional solo se le muestren nombre, apellido y DNI.
- Comprobar que el Administrador no tenga acceso a pacientes.

**HECHO POR:** Lucca Giordana

## 2. Gestión de Turnos

### HISTORIA DE USUARIO Núm: 2.1 | Visualizar Turnos

| Historia | Estimación |
| --- | --- |
| **Como** profesional de la salud,<br>**quiero** visualizar mis turnos por día con su estado, el paciente, el tipo de consulta y el horario,<br>**para** disponer de una visión completa de mi jornada y registrar el resultado de cada atención. | **Valor:** 13<br>**Prioridad:** 5<br>**Estimación:** 24 h |

**Validación:**

- Comprobar que el Profesional vea solo los turnos de su propia agenda, en la zona horaria de la organización, y que cambiar identificadores en la URL no amplíe el alcance.
- Comprobar que se muestren los estados Solicitado, Confirmado, Vencido, Cancelado, Asistió y No asistió.
- Comprobar que el Profesional no vea la actividad de sus pacientes con otros profesionales.
- Comprobar que la Secretaria pueda ver los turnos de todas las agendas del centro agrupados por fecha, y que el Administrador no tenga acceso.
- Dado que un turno está Confirmado, cuando el Profesional (en su agenda) o la Secretaria registran el resultado, entonces el turno pasa a Asistió o No asistió; las solicitudes y los turnos vencidos, cancelados o ya cerrados no admiten este cambio.

**HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Núm: 2.2 | Crear Turno (paciente nuevo)

| Historia | Estimación |
| --- | --- |
| **Como** profesional de la salud,<br>**quiero** registrar a un paciente que no existe en el sistema y asignarle un turno en mi agenda en el mismo paso,<br>**para** atender una primera consulta sin depender de la secretaría. | **Valor:** 8<br>**Prioridad:** 4<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que la opción solo aparezca después de buscar el DNI exacto y no encontrarlo.
- Comprobar que nombre, apellido, DNI, fecha de nacimiento y teléfono sean obligatorios y el correo de contacto opcional.
- Comprobar que el alta, el turno Confirmado, la relación con el Profesional y la auditoría se guarden en una sola operación: si algo falla, no queda nada guardado.
- Comprobar que el horario elegido esté disponible y pertenezca a la agenda del Profesional autenticado.
- Comprobar que, si otro usuario registró ese DNI mientras tanto, el sistema rechace el duplicado.

**HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Núm: 2.4 | Cancelar Turno

| Historia | Estimación |
| --- | --- |
| **Como** profesional de la salud o Secretaria,<br>**quiero** cancelar un turno indicando el motivo,<br>**para** liberar el bloque horario y que el paciente sepa por qué se canceló. | **Valor:** 5<br>**Prioridad:** 3<br>**Estimación:** 16 h |

**Validación:**

- Comprobar que solo se puedan cancelar turnos en estado Solicitado o Confirmado y que el motivo sea obligatorio.
- Comprobar que el Profesional solo cancele turnos de su agenda y la Secretaria, de cualquier agenda.
- Comprobar que el turno no se elimine: pasa a Cancelado y conserva su historial.
- Comprobar que el horario quede libre de inmediato y que el paciente vea quién canceló (Profesional o Secretaría) y el motivo.

**HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Núm: 2.5.1 | Reservar turno (Paciente)

| Historia | Estimación |
| --- | --- |
| **Como** Paciente,<br>**quiero** reservar un turno seleccionando un profesional, tipo de consulta, fecha y horario disponible,<br>**para** asegurar mi atención sin necesidad de asistencia administrativa. | **Valor:** 21<br>**Prioridad:** 5<br>**Estimación:** 24 h |

**Validación:**

- Comprobar que la reserva sea siempre para el propio paciente autenticado.
- Comprobar que solo se ofrezcan profesionales con cuenta activa y perfil completo, y tipos de consulta activos.
- Comprobar que se muestren únicamente horarios disponibles, calculados según la disponibilidad semanal, el intervalo de agenda, la duración, la anticipación mínima, el horizonte de reserva y los turnos ocupados.
- Comprobar que el perfil del paciente deba estar completo para reservar.
- Comprobar que el turno quede Confirmado si el profesional aprueba automáticamente, o Solicitado si aprueba manualmente; en ambos casos el horario queda ocupado.
- Comprobar que una reserva simultánea sobre el mismo horario sea rechazada.

**HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Núm: 2.5.2 | Reservar turno (Secretaria)

| Historia | Estimación |
| --- | --- |
| **Como** Secretaria,<br>**quiero** reservar un turno para un paciente registrado seleccionando el profesional, el tipo de consulta, la fecha y el horario,<br>**para** asistir a los pacientes cuando no puedan reservar por sus propios medios. | **Valor:** 13<br>**Prioridad:** 4<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que la Secretaria pueda elegir cualquier profesional activo con perfil completo, un tipo de consulta activo y un horario disponible.
- Comprobar que el estado inicial dependa de la modalidad de aprobación del profesional (ver 2.7): Confirmado o Solicitado.
- Comprobar que el turno, la relación Profesional–Paciente y la auditoría se guarden en una sola operación.
- Comprobar que la Secretaria pueda reservar aunque el paciente no tenga correo de acceso vinculado.
- Comprobar que no sea posible reservar un horario ya ocupado.

**HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Núm: 2.5.3 | Reservar turno (Profesional)

| Historia | Estimación |
| --- | --- |
| **Como** Profesional de la salud,<br>**quiero** reservar un turno en mi agenda para un paciente con el que ya tengo relación o que encuentro por su DNI exacto,<br>**para** coordinar consultas de seguimiento. | **Valor:** 13<br>**Prioridad:** 4<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que el Profesional solo pueda reservar dentro de su propia agenda.
- Comprobar que pueda elegir entre sus pacientes relacionados o buscar uno por DNI exacto, sin listado global.
- Comprobar que el turno nazca Confirmado aun cuando el profesional usa aprobación manual.
- Comprobar que el horario deba estar disponible y que la reserva cree o reutilice la relación en la misma operación.
- Comprobar que buscar o seleccionar un paciente sin confirmar no cree ninguna relación.

**HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Núm: 2.6 | Desocupar turno (Paciente)

| Historia | Estimación |
| --- | --- |
| **Como** Paciente,<br>**quiero** cancelar un turno o una solicitud propia antes de su inicio,<br>**para** liberar el horario si no voy a poder asistir. | **Valor:** 3<br>**Prioridad:** 3<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que solo se puedan cancelar turnos propios en estado Solicitado o Confirmado y estrictamente antes de su hora de inicio.
- Comprobar que no se exija motivo.
- Comprobar que el horario quede disponible de inmediato para otros pacientes.
- Comprobar que, desde la hora de inicio, el sistema rechace la cancelación aunque se intente fuera de la interfaz.

**HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Núm: 2.7 | Aceptar turno (Profesional)

| Historia | Estimación |
| --- | --- |
| **Como** Profesional de la salud,<br>**quiero** elegir si apruebo las reservas de forma automática o manual, y aceptar o rechazar las solicitudes pendientes,<br>**para** decidir qué turnos entran en mi agenda. | **Valor:** 8<br>**Prioridad:** 4<br>**Estimación:** 8 h |

**Validación:**

- Comprobar que el Profesional pueda configurar la modalidad automática o manual, y en modalidad manual si las reservas de la Secretaria nacen Confirmadas o Solicitadas; el cambio solo afecta reservas nuevas.
- Comprobar que únicamente los turnos en estado Solicitado puedan aceptarse o rechazarse.
- Comprobar que aceptar pase el turno a Confirmado y mantenga ocupado el horario, y que rechazar lo pase a Cancelado y libere el horario.
- Comprobar que solo el Profesional dueño de la agenda resuelva sus solicitudes; Secretaria, Administrador y Paciente no pueden.
- Comprobar que una solicitud no resuelta pase a Vencido al llegar su hora de inicio y libere el horario (ver caso 6).

**HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Núm: 2.9 | Listar Turno del Paciente

| Historia | Estimación |
| --- | --- |
| **Como** paciente,<br>**quiero** visualizar un listado completo de mis turnos, próximos y pasados, con fecha, horario, profesional y estado,<br>**para** llevar un control personal de mis citas sin contactar a la secretaría. | **Valor:** 5<br>**Prioridad:** 2<br>**Estimación:** 24 h |

**Validación:**

- Comprobar que se muestren solo los turnos del paciente autenticado, del más reciente al más antiguo.
- Comprobar que se diferencien los estados Solicitado, Confirmado, Vencido, Cancelado, Asistió y No asistió.
- Comprobar que, si el personal canceló un turno, se muestre quién lo canceló y el motivo.
- Comprobar que no se muestren datos clínicos.

**HECHO POR:** Said Quioto

## 3. Configuración de Agenda

### HISTORIA DE USUARIO Núm: 3.1 | Editar Periodo

| Historia | Estimación |
| --- | --- |
| **Como** profesional de la salud,<br>**quiero** configurar la anticipación mínima y el horizonte con los que los pacientes pueden reservar,<br>**para** evitar reservas con escasa o excesiva anticipación. | **Valor:** 3<br>**Prioridad:** 2<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que el Profesional pueda modificar la anticipación mínima y el horizonte de reserva desde sus ajustes.
- Comprobar que los cambios se apliquen de inmediato a los horarios ofrecidos al paciente y a la secretaría.
- Comprobar que solo el Profesional dueño pueda modificar su configuración.

**HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Núm: 3.2 | Editar Disponibilidad

| Historia | Estimación |
| --- | --- |
| **Como** profesional de la salud,<br>**quiero** configurar mis horarios regulares de atención por día de la semana,<br>**para** que el calendario muestre únicamente mi disponibilidad real. | **Valor:** 21<br>**Prioridad:** 5<br>**Estimación:** 24 h |

**Validación:**

- Comprobar que el Profesional pueda definir sus franjas de atención semanales.
- Comprobar que los pacientes y la secretaría solo vean horarios dentro de esas franjas.
- Comprobar que solo el Profesional dueño pueda modificarlas.

**HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Núm: 3.3 | Definir Tipos de Consulta

| Historia | Estimación |
| --- | --- |
| **Como** Profesional de la salud,<br>**quiero** configurar mi intervalo de agenda y gestionar mis tipos de consulta con nombre, precio, color y duración,<br>**para** ofrecer un catálogo claro y reservar solo horarios compatibles con cada prestación. | **Valor:** 8<br>**Prioridad:** 4<br>**Estimación:** 16 h |

**Validación:**

- Comprobar que el intervalo de agenda vaya de 5 a 240 minutos en pasos de 5, y que cambiarlo pida confirmación y no mueva ni cancele turnos existentes.
- Comprobar que cada tipo tenga nombre de hasta 32 caracteres, precio en ARS mayor o igual a 0, color y una cantidad de intervalos entre 1 y min(10, 240 / intervalo).
- Comprobar que un tipo inactivo no se pueda editar, deje de ofrecerse para reservas nuevas y pueda reactivarse si su duración no supera 240 minutos.
- Comprobar que los turnos ya reservados conserven el nombre, la duración y el precio que tenían al reservarse.
- Comprobar que solo el Profesional dueño modifique su catálogo.

**HECHO POR:** Said Quioto

## 4. Gestión de Profesionales

### HISTORIA DE USUARIO Núm: 4.1 | Listar Profesionales

| Historia | Estimación |
| --- | --- |
| **Como** Administrador,<br>**quiero** visualizar el listado de cuentas de profesionales y secretarias,<br>**para** conocer su estado y administrar su acceso. | **Valor:** 5<br>**Prioridad:** 3<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que el listado muestre correo, rol, estado (pendiente de activación, activa o desactivada) y la cantidad de turnos futuros afectados.
- Comprobar que no se muestren datos de pacientes ni de agendas.
- Comprobar que solo el Administrador acceda a esta pantalla.

**HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.2 | Alta Profesional

| Historia | Estimación |
| --- | --- |
| **Como** Administrador,<br>**quiero** crear cuentas de Profesional o Secretaria y emitir su invitación,<br>**para** incorporar al personal de forma ordenada y segura. | **Valor:** 8<br>**Prioridad:** 5<br>**Estimación:** 16 h |

**Validación:**

- Comprobar que solo se creen cuentas de Profesional o Secretaria.
- Comprobar que el correo sea válido y único sin distinguir mayúsculas.
- Comprobar que la cuenta quede Pendiente de activación y se emita una invitación de un solo uso que vence a las 24 horas.
- Comprobar que el Administrador pueda reemitir la invitación de una cuenta pendiente, invalidando las anteriores.
- Comprobar que el invitado active la cuenta definiendo su contraseña y enrolando TOTP (ver 7).

**HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.3.1 | Modificación Profesional (Administrador)

| Historia | Estimación |
| --- | --- |
| **Como** Administrador,<br>**quiero** corregir el correo de la cuenta de un profesional o una secretaria,<br>**para** mantener actualizado su acceso. | **Valor:** 8<br>**Prioridad:** 3<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que el correo nuevo sea válido y único sin distinguir mayúsculas.
- Comprobar que se conserven la cuenta, sus turnos, relaciones, perfil y ajustes, sin que el Administrador acceda a ellos.
- Comprobar que no se pueda aplicar a cuentas de Administrador.

**HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.3.2 | Modificación Profesional (Profesional)

| Historia | Estimación |
| --- | --- |
| **Como** profesional,<br>**quiero** completar mi perfil con nombre, apellido, especialidad, tipo y número de matrícula,<br>**para** aparecer como opción de reserva ante pacientes y secretaría. | **Valor:** 5<br>**Prioridad:** 3<br>**Estimación:** 12 h |

**Validación:**

- Comprobar que los cinco datos sean obligatorios para ser reservable y que se pueda guardar un perfil parcial.
- Comprobar que al paciente solo se le muestren nombre y especialidad.
- Comprobar que solo el propio Profesional acceda a su perfil; Secretaria y Administrador no.

**HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.4 | Baja Profesional

| Historia | Estimación |
| --- | --- |
| **Como** Administrador,<br>**quiero** desactivar o reactivar la cuenta de un profesional o una secretaria,<br>**para** evitar nuevas reservas y accesos sin perder su historial. | **Valor:** 5<br>**Prioridad:** 3<br>**Estimación:** 8 h |

**Validación:**

- Comprobar que la baja sea lógica: la cuenta pasa a desactivada y no se elimina información.
- Comprobar que se corten las sesiones activas y se revoquen las invitaciones pendientes.
- Comprobar que un profesional desactivado deje de recibir reservas nuevas por todos los canales.
- Comprobar que ningún turno existente se cancele automáticamente: el Administrador solo ve cuántos turnos futuros quedan afectados.
- Comprobar que el Administrador no pueda desactivarse a sí mismo ni operar sobre otros administradores.
- Comprobar que al reactivar la cuenta vuelva a estar activa (o pendiente si nunca se activó) sin restaurar turnos cancelados.

**HECHO POR:** Santiago Casali

## 6. Automatización

### HISTORIA DE USUARIO Núm: 6 | Liberación de turnos automáticamente

| Historia | Estimación |
| --- | --- |
| **Como** sistema,<br>**quiero** marcar como vencidas las solicitudes que llegan a su hora de inicio sin resolverse,<br>**para** liberar el horario sin intervención manual. | **Valor:** —<br>**Prioridad:** —<br>**Estimación:** — |

**Validación:**

- Comprobar que una solicitud que alcanza su hora de inicio en estado Solicitado pase a Vencido y libere el horario.
- Comprobar que el vencimiento no cuente como ausencia del paciente.

**HECHO POR:** Equipo Origen

## 7 y 8. Inicio de sesión

### HISTORIA DE USUARIO Núm: 7 | Iniciar Sesión Interno

| Historia | Estimación |
| --- | --- |
| **Como** Usuario Interno,<br>**quiero** ingresar al sistema con mi correo, contraseña y un código TOTP,<br>**para** acceder de forma segura a las funciones de mi rol. | **Valor:** 21<br>**Prioridad:** 5<br>**Estimación:** 24 h |

**Validación:**

- Comprobar que, antes de ingresar por primera vez, la cuenta deba activarse con una invitación de un solo uso definiendo contraseña y enrolando TOTP.
- Comprobar que el acceso exija contraseña y TOTP válidos, y que las cuentas pendientes de activación o desactivadas sean rechazadas.
- Comprobar que la sesión dure como máximo 12 horas y se bloquee tras 15 minutos de inactividad (valores por defecto).
- Comprobar que cada rol vea solo su navegación: Profesional (Agenda, Solicitudes, Ajustes), Secretaria (Agenda, Pacientes) y Administrador (Cuentas).
- Comprobar que el primer Administrador se incorpore mediante un proceso de despliegue, sin credenciales por defecto.
- Usuario interno = Administrador, Secretaria y Profesional.

**HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 8.2 | Iniciar Sesión con Magic Link

| Historia | Estimación |
| --- | --- |
| **Como** Paciente,<br>**quiero** acceder al sistema a través de un enlace enviado a mi correo electrónico,<br>**para** iniciar sesión de forma rápida y segura sin recordar una contraseña. | **Valor:** 13<br>**Prioridad:** 5<br>**Estimación:** 16 h |

**Validación:**

- Comprobar que el enlace solo se envíe si el correo está vinculado a un paciente (ver 1.3) y que la respuesta en pantalla sea la misma exista o no el correo.
- Comprobar que el enlace venza a los 15 minutos, se use una sola vez y que cada nueva solicitud invalide los anteriores.
- Comprobar que el acceso del paciente sea exclusivamente mediante el enlace enviado a su correo vinculado, sin contraseña.
- Comprobar que, si el personal reemplaza el correo de acceso, las sesiones anteriores del paciente queden invalidadas.
- Comprobar que el paciente pueda cerrar la sesión de su navegador.

**HECHO POR:** Santiago Casali
