# Resumen para el equipo — beta de la semana 16

> **Apunte informal para los cuatro estudiantes.** No es una especificación, un handoff para agentes ni documentación oficial. No reemplaza el mapa de Wayfinder ni sus decisiones. Describe lo que buscamos entregar, no lo que ya está implementado o comprobado.
>
> Fuente oficial: [Mapa Wayfinder: alcance y prioridades de la beta de turnos](https://github.com/Team-Origen/origen/issues/266), junto con las resoluciones de sus tickets enlazados.

## Qué queremos presentar

Un sistema de gestión de turnos configurable para un único centro de salud, con nombre e identidad propios, sin depender de una institución específica y reutilizando el desarrollo de ORIGEN.

La beta de la **semana 16** debe permitir trabajar con los cuatro roles: paciente, profesional, secretaría y administrador. Buscamos que funcionen tanto la reserva del paciente como la atención asistida por el personal.

La **presentación final será dos semanas después de la beta**, para estabilizar el producto y corregir los errores detectados.

La entrega también contempla:

- Sistema accesible desde un entorno en la nube; no alcanza con mostrarlo únicamente en una computadora local.
- Manual de usuario acorde con las funciones disponibles.
- Datos de prueba guardados y cargados usando el propio sistema. Pueden representar personas inventadas, pero los recorridos deben ser reales, no pantallas simuladas ni resultados preparados por fuera de las funciones del producto.
- Comprobaciones funcionales y de permisos. No haremos pruebas de rendimiento.
- La participación y el informe exigidos por la cátedra, con los docentes como clientes. Las condiciones particulares se terminarán de aclarar con ellos.

## Qué podrá hacer cada rol

### Paciente

- Ingresar mediante un enlace enviado a su correo, sin contraseña.
- Completar nombre, apellido, DNI, fecha de nacimiento y teléfono. La verificación del teléfono no será obligatoria para reservar.
- Elegir profesional, tipo de consulta, fecha y hora disponibles, según la configuración de ese profesional.
- Reservar únicamente para sí mismo.
- Ver si su solicitud espera aprobación o si el turno está confirmado.
- Cancelar una solicitud pendiente o un turno confirmado antes de su hora de inicio, sin multas.
- Consultar sus turnos con los distintos profesionales, incluidos los anteriores, cancelados, asistidos y ausencias.
- Ver el precio final y si el turno está pendiente de pago o pagado, sin modificar esos datos ni pagar desde el sistema.
- Consultar sus datos personales. Para corregirlos o cambiar el correo, pedirá la modificación al personal por fuera del sistema.

### Profesional

- Completar y mantener nombre, apellido, especialidad, tipo y número de matrícula. Debe completar esos datos antes de aparecer disponible para reservas del paciente; puede ingresar y preparar su configuración previamente.
- Informar el tipo de matrícula como texto libre, sin un listado precargado. El sistema mostrará datos declarados, sin verificar credenciales médicas.
- Configurar tipos de consulta, duración, precios, intervalo de agenda, horarios habituales, anticipación y cantidad de días habilitados para reservar.
- Consultar su agenda y administrar sus propios turnos.
- Al crear un turno, elegir un paciente de su listado o buscar por DNI a uno ya registrado. Si no existe, realizar el alta asistida.
- Tener en su listado a quienes alguna vez le hayan solicitado o creado un turno. Buscar a alguien no lo agrega al listado: la relación se establece al crear el turno.
- Ver únicamente los turnos que cada paciente tiene o tuvo con él, nunca su actividad con otros profesionales.
- Elegir la modalidad de aprobación y resolver las solicitudes pendientes de su agenda.
- Cancelar turnos con motivo visible para el paciente y registrar presencia o ausencia.
- Bloquear y desbloquear horarios puntuales, después de cancelar por separado los turnos afectados.
- Corregir datos de pacientes y agregar o cambiar su correo de acceso, dentro de sus permisos.
- Ajustar el precio final de sus turnos antes del pago, registrar pagos y corregir una marca de pagado incorrecta.
- Consultar su propio resumen económico básico.

### Secretaría

- Consultar el listado de pacientes del centro y trabajar con las agendas de todos los profesionales.
- Buscar, registrar pacientes y crearles turnos sin exigir que tengan cuenta o correo.
- Corregir datos del paciente y agregar o reemplazar su correo de acceso.
- Cancelar turnos con motivo visible para el paciente y registrar presencia o ausencia.
- Bloquear y desbloquear rangos puntuales desde la agenda, después de cancelar los turnos afectados.
- Registrar pagos, corregir una marca de pagado y ajustar precios antes del pago.
- Consultar el resumen económico de un profesional a la vez.

Secretaría **no accede a Ajustes ni modifica el perfil del profesional**: no cambia tipos de consulta, horarios habituales, intervalos ni ventanas de reserva. Tampoco puede aceptar o rechazar solicitudes pendientes de aprobación profesional.

### Administrador

- Dar de alta cuentas de profesionales y secretaría.
- Editar datos de cuenta, incluido el correo, y desactivar o reactivar el acceso.
- Conservar el historial y los turnos asociados: desactivar no significa borrar.

El administrador no gestiona pacientes, turnos, pagos ni ajustes profesionales.

Al desactivar un profesional, se corta su acceso y deja de recibir nuevas reservas. Los turnos existentes se conservan y se advierte cuántos futuros están afectados para que secretaría los revise, sin cancelarlos automáticamente. Reactivar no restaura turnos cancelados.

## Reglas compartidas importantes

### Registro asistido y acceso posterior

- Antes de crear un paciente, el personal busca si ya existe para no duplicarlo.
- El alta asistida requiere nombre, apellido, DNI, fecha de nacimiento y teléfono. El correo es opcional y el teléfono puede ser compartido.
- Registrar un paciente para agendarlo no le habilita automáticamente una cuenta personal.
- Si luego quiere acceder, profesional o secretaría agregan su correo al registro existente y el paciente recibe el enlace de acceso. Así conserva sus turnos anteriores.
- El mismo procedimiento permite cambiar el correo. La comprobación de identidad corresponde al personal por fuera del sistema, con una advertencia sencilla recordando esa responsabilidad.
- No se permite usar el correo de otra cuenta ni vincularse a un paciente solo por declarar su DNI. El registro público no debe revelar sus datos.
- Al cambiar el correo, el acceso anterior deja de servir para ese paciente. Queda constancia de quién realizó el cambio.
- Las correcciones no pueden asignar un DNI ya utilizado por otro paciente.

### Aprobación de turnos

| Modalidad del profesional | Reserva del paciente | Reserva de secretaría |
| --- | --- | --- |
| Automática | Confirmada directamente. | Confirmada directamente. |
| Manual, con aceptación directa para secretaría | Pendiente de aprobación. | Confirmada directamente. |
| Manual, con revisión de reservas de secretaría | Pendiente de aprobación. | Pendiente de aprobación. |

- Los turnos creados por el propio profesional quedan confirmados directamente.
- Una solicitud pendiente ocupa el horario. Solo el profesional puede aceptarla o rechazarla; al rechazarla, el horario se libera.
- Cambiar la modalidad afecta únicamente a las nuevas reservas, no resuelve las que ya estaban pendientes.
- Si llega la hora de inicio y la solicitud sigue sin resolverse, queda como vencida sin resolver y se conserva en el historial. No cuenta como ausencia.

### Cancelación, asistencia y bloqueos

- La cancelación del paciente se distingue de la realizada por el centro.
- Cuando cancela profesional o secretaría, queda un motivo visible para el paciente. Eso no implica enviar automáticamente una notificación.
- Cancelar libera el horario y conserva el registro en el historial; no genera multas ni se marca como ausencia.
- Profesional y secretaría registran si el paciente asistió o no.
- Para cambiar fecha, hora o tipo de consulta, se cancela el turno y se crea otro nuevo.
- No se puede bloquear un rango que todavía tenga turnos activos o solicitudes ocupándolo: primero se cancelan por separado.

### Pagos básicos

- Cada turno admite un único pago total, por efectivo o transferencia. La transferencia se comprueba fuera del sistema.
- El pago no es una condición para reservar. Una solicitud todavía sin aprobar no puede marcarse como pagada.
- Profesional y secretaría registran el pago recibido, con método, quién lo registró y cuándo.
- Antes del pago pueden cambiar el precio final de ese turno, sin cambiar el precio general de la consulta. Una vez pagado, el precio no se edita.
- Si se marcó pagado por error, pueden deshacerlo con una confirmación breve, sin explicación escrita. Se conserva quién corrigió y cuándo, el turno vuelve a pendiente y se puede editar nuevamente su precio.
- Cancelar no borra un pago. Si hay que devolver dinero o resolver un pago de un turno cancelado, se hace fuera del sistema.

### Resumen económico básico

Se calcula según la **fecha del turno**, no según cuándo se registró el pago.

| Importe | Qué incluye |
| --- | --- |
| Pagado | Todos los turnos pagados del período, incluso cancelados y ausencias. |
| Pendiente | Turnos confirmados o asistidos que todavía no están pagados. |
| Total considerado | Pagado más pendiente. |

Las solicitudes pendientes, rechazadas o vencidas sin pago, los cancelados sin pago y las ausencias sin pago quedan fuera del cálculo. Una ausencia impaga conserva su precio en el historial; excluirla no significa perdonar ese importe. Si luego se registra el pago, entra como pagada.

El resumen no representa la deuda completa del paciente, el dinero cobrado durante el mes ni un ingreso neto: no descuenta devoluciones externas. Un pago registrado después puede actualizar el total de un período anterior.

## Identidad visual, opciones y prioridades

- El sistema tendrá marca propia, no el nombre de un centro de salud.
- Se busca una identidad básica con nombre, logo sencillo, colores y tipografía, aplicada temprano. La revisión final de coherencia entre pantallas es un trabajo distinto.
- La **foto del profesional es opcional y de menor prioridad**. No bloquea el acceso ni las reservas si falta.
- Se priorizan acceso y configuración; creación de turnos por los tres canales; ciclo completo del turno; mantenimiento de pacientes, agendas y cuentas; pagos y resumen; y terminación de pantallas y presentación.
- El despliegue, las comprobaciones, los datos de prueba y el manual acompañan el avance, no se dejan todos para el final.
- Prioridad menor no equivale a exclusión: todo lo incluido se busca para la beta. Este resumen no garantiza que esté terminado ni evalúa el esfuerzo necesario.

## Qué queda fuera o para otra versión

- WhatsApp y verificación telefónica obligatoria para reservar.
- Historia clínica, resultados, notas profesionales y devoluciones clínicas de consulta.
- Multas, sus advertencias y bloqueos por multas impagas.
- Reprogramación directa y cambio del tipo de consulta de un turno existente.
- Carga, consulta y revisión de comprobantes de pago.
- Pagos parciales, saldo a favor o cuenta corriente del paciente y traslado automático de pagos entre turnos.
- Registro o ejecución de devoluciones de dinero y la operación individual «No se cobra».
- Reservas para familiares o personas a cargo desde una cuenta de paciente.
- Lista de espera, reportes avanzados, resumen global del centro y comparaciones entre profesionales.
- Edición autónoma de datos o correo por el paciente y formularios internos para solicitar esos cambios.
- Verificación de matrículas médicas y catálogo precargado de tipos de matrícula.
- Personalización de la marca por centro.
- Casos de alta sin DNI o sin teléfono.
- Pruebas de rendimiento.

## Qué sigue pendiente de decidir

- **Identidad visual concreta:** nombre, logo, colores y tipografía. [Decisión pendiente](https://github.com/Team-Origen/origen/issues/274).
- **Condiciones de despliegue:** hablar con docentes y decidir hosting y presupuesto. La nube es obligatoria; mínimo o gratuito es una preferencia provisional, no una decisión definitiva. [Consulta pendiente](https://github.com/Team-Origen/origen/issues/275).

Estos pendientes no se consideran resueltos ni frenan la preparación de la especificación de las partes independientes. Las decisiones y cambios de alcance se siguen en el mapa oficial, no en este apunte.
