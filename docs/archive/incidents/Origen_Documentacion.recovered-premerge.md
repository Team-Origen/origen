# ORIGEN - CENTRO DE SALUD

## INFORME DE DECISIONES DE ARQUITECTURA DE SOFTWARE
### SISTEMA DE GESTIÓN DE TURNOS

**HECHO POR:** CASALI | GIORDANA | OLMOS | QUIOTO

---

## 1. Introducción
### 1.1. Propósito
El propósito de este documento es definir los requisitos funcionales y no funcionales para el sistema de gestión de turnos "Origen". Está dirigido a los desarrolladores, al equipo de pruebas y a los interesados del centro de salud.

### 1.2. Ámbito del sistema
El sistema, denominado "Origen", es una plataforma web diseñada para la gestión operativa y administrativa de turnos, comunicación con pacientes vía WhatsApp y administración financiera básica.
* **Lo que hará:** Permitir la reserva de turnos, gestión de agendas profesionales, envío de notificaciones automáticas, registro de auditoría y consulta de historial operativo de turnos.
* **Lo que no hará:** No almacenará ni mostrará historia clínica, seguimiento clínico, indicaciones clínicas, diagnósticos, observaciones profesionales ni notas clínicas.

### 1.3. Definiciones, acrónimos, abreviaturas
* **Passwordless:** Método de autenticación que no requiere una contraseña almacenada.
* **ERS:** Especificación de Requisitos de Software.
* **Log:** Registro cronológico de operaciones del sistema.
* **Sobreturno:** Turno asignado fuera de la disponibilidad regular ante situaciones excepcionales o necesidades operativas.

### 1.4. Referencias
* IEEE Std 830-1998: Recommended Practice for Software Requirements Specifications.
* Documentación oficial de la API de WhatsApp Business Platform.
* Documentación oficial de autenticación OAuth 2.0 de Google.

### 1.5. Visión general del documento
El documento se divide en: Descripción general del contexto (Sección 2) y Requisitos específicos detallados (Sección 3), incluyendo funciones por rol y atributos de calidad.

---

## 2. Descripción general
### 2.1. Perspectiva del producto
El sistema constituye una solución de software independiente orientada a la gestión de turnos en centros de salud. Si bien opera de manera autónoma respecto de otros sistemas institucionales, requiere integración con servicios externos de autenticación y mensajería, tales como Google OAuth para validación de identidad y WhatsApp para el envío automatizado de notificaciones a pacientes.

### 2.2. Funciones del producto
El sistema cumplirá con las siguientes funciones principales:
* **Gestión de accesos:** Autenticación passwordless y control de roles (Admin, Profesional, Secretaria, Paciente).
* **Control de Agenda:** Configuración de horarios, ausencias y tipos de consulta con costos variables.
* **Portal de Reservas:** Interfaz interactiva para que el paciente seleccione y gestione sus turnos.
* **Automatización:** Notificaciones por WhatsApp y máquina de estados para el ciclo de vida del turno.
* **Administración:** Gestión de lista de espera por profesional con modo automático o manual, trazabilidad de ofertas y respuestas, y módulo de validación de pagos.

### 2.3. Características de los usuarios
* **Administrador:** Usuario con conocimientos técnicos para gestionar cuentas y recuperar accesos.
* **Profesional:** Usuario responsable de gestionar su agenda, disponibilidad y atención administrativa asociada a los turnos.
* **Secretaría:** Usuario encargado de asistir en la administración operativa del sistema, incluyendo gestión de turnos, validaciones.
* **Paciente:** Usuarios externos con niveles variables de alfabetización digital.

### 2.4. Restricciones
* Los pacientes podrán cancelar turnos voluntariamente hasta el límite de cancelación configurado por el perfil profesional. La configuración predeterminada habilita la cancelación hasta las 23:59 del día D-1.
* El sistema deberá garantizar la privacidad de los datos personales de pacientes y profesionales.
* El sistema deberá implementar mecanismos de seguridad y control de acceso acordes a cada rol de usuario, contemplando la posibilidad de incorporar módulos futuros con información sensible cifrada.

### 2.5. Suposiciones y dependencias
Se asume que los usuarios finales disponen de una conexión a internet estable y una cuenta activa de WhatsApp para recibir notificaciones. El sistema depende de la disponibilidad operativa de la API de WhatsApp y de los servicios de Google Auth.

### 2.6. Requisitos futuros
Como evolución funcional futura, se contempla la incorporación de un módulo de registro de notas profesionales cifradas, destinado al almacenamiento privado de observaciones individuales realizadas por cada profesional. Esta funcionalidad no forma parte del alcance de la versión actual del sistema, pero ha sido acordada como una extensión posterior con el cliente.

---

## 3. Requisitos Específicos
### 3.1. Interfaces externas
* **RIE-01:** Interfaz con API de WhatsApp para envío de recordatorios.
* **RIE-02:** Interfaz de autenticación con Google (Gmail).

### 3.2. Funciones

#### 3.2.1 Gestión de Usuarios y Roles
* **RF-01: Autenticación Mixta y Control de Acceso:** El sistema deberá implementar un mecanismo de acceso diferenciado por rol. Para el rol Paciente, soportará un inicio de sesión Passwordless (Google OAuth y Magic Link). En el flujo de Google OAuth, la autenticación verificará la identidad y el correo del Paciente; si no existe una cuenta con ese correo, el sistema creará una cuenta en estado **Pendiente de completar**, permitirá el acceso y bloqueará la reserva de turnos hasta que el Paciente complete y valide los datos obligatorios de RF-02. Si ya existe una cuenta de Paciente con ese correo, el sistema no deberá crear un duplicado y deberá iniciar la vinculación de Google con esa ficha existente; para completar esa vinculación, el Paciente deberá validar además su DNI y fecha de nacimiento contra la ficha existente. Si la comprobación no coincide, no deberá producirse la vinculación ni la creación de un duplicado. Para los Usuarios Internos, el sistema exigirá credenciales tradicionales (correo y contraseña) más un Segundo Factor de Autenticación (2FA) válido para los roles Administrador, Profesional y Secretaría. El flujo Magic Link no deberá modificarse.
* **RF-02: Registro:** El sistema deberá requerir, de manera obligatoria durante el proceso de registro, la captura y validación de los siguientes campos según el rol: para Paciente, Nombres, Apellidos, Documento Nacional de Identidad, Fecha de Nacimiento, Número de Teléfono Celular y Correo Electrónico; para Profesional, Nombres, Apellidos, Documento Nacional de Identidad y Correo Electrónico. El género será opcional en ambos casos. El DNI y el correo electrónico deberán ser únicos en ambos roles. Para las cuentas de Paciente creadas por Google OAuth en estado **Pendiente de completar**, la activación a estado **Activa** deberá producirse únicamente cuando dichos datos obligatorios queden completos y validados.
* **RF-03: Recuperación:** El sistema deberá permitir al rol Administrador iniciar la modificación de las direcciones de correo electrónico de los usuarios mediante un flujo de verificación previo. El nuevo correo no deberá quedar activo hasta que sea verificado; mientras tanto, el correo anterior seguirá siendo la identidad principal. El sistema deberá notificar el intento a los canales anteriores disponibles y auditar el inicio, la verificación, la activación y cualquier fallo del proceso.
* **RF-04: Roles:** El sistema deberá implementar un control de acceso basado en roles, definiendo y segmentando jerárquicamente los siguientes niveles de acceso: Administrador, Profesional, Secretaría y Paciente.
* **RF-05: Aislamiento de datos:** El sistema deberá restringir la visualización de la información a nivel de base de datos e interfaz, garantizando que el rol Profesional únicamente pueda ver pacientes que tengan o hayan tenido al menos un turno con ese Profesional, y que solo acceda a los registros operativos de turnos vinculados a su propia relación con cada Paciente. El Profesional no deberá poder navegar, listar ni consultar la base global de Pacientes ni ver información de relaciones con otros Profesionales.
* **RF-06: Privacidad Secretaría:** El sistema deberá permitir al rol Secretaría el acceso de lectura y escritura a los datos generales y de contacto de los pacientes, incluyendo la posibilidad de iniciar cambios de correo de Pacientes, pero deberá denegar el acceso a información sensible no relacionada con la gestión de turnos y no otorgar permisos para modificar correos de Profesional, Administrador u otra Secretaría. La Secretaría sí podrá listar y buscar a todos los Pacientes del centro para gestión operativa.

#### 3.2.2 Configuración de Agenda
* **RF-07: Disponibilidad:** El sistema deberá proporcionar un módulo de configuración que permita establecer y modificar horarios de atención regulares, registrar ausencias, bloquear días feriados y definir la ventana de tiempo (rango de meses o días) disponible para la reserva futura de turnos. Cuando una modificación de disponibilidad, una ausencia o un bloqueo afecte turnos futuros activos, el sistema deberá detectar y mostrar todos los turnos alcanzados por el conflicto, impedir el guardado mientras existan conflictos y mantener sin cambios esos turnos hasta que cada uno sea reprogramado o cancelado individualmente por los flujos ya definidos. El sistema no deberá mover, cancelar ni modificar automáticamente ningún turno afectado.
* **RF-08: Consultas:** El sistema deberá permitir la creación de distintos tipos de consulta, exigiendo para el registro de cada una la definición de un tiempo de duración estimado y un valor monetario base. Al crear un turno, el sistema deberá conservar como valores propios de ese turno el nombre del tipo de consulta, su duración y su precio base vigentes en ese momento.
* **RF-09: Edición de Precios y Multa Asociada:** El sistema deberá otorgar la capacidad de modificar de manera individual el valor monetario de un turno específico, permitiendo la aplicación de excepciones o descuentos sobre el precio estándar de la consulta. Para un turno existente no Pagado, una reducción o descuento podrá aplicarse directamente, deberá notificarse al Paciente y quedará auditada. Para ese mismo estado financiero, un aumento deberá tratarse como una propuesta que requiere aceptación expresa del Paciente; mientras no acepte, seguirá vigente el precio anterior. Si el Paciente rechaza el aumento, se conservará el precio anterior y el turno no se cancelará automáticamente. Si el Profesional decide no mantener el precio anterior, podrá cancelar manualmente el turno con motivo auditado, sin multa para el Paciente. Una vez que el estado financiero sea Pagado, el precio no podrá editarse. La multa por cancelación tardía deberá permanecer desactivada por defecto para cada Profesional. Si el Profesional la activa, deberá configurar un porcentaje entero entre 1 % y 100 % sobre el precio efectivo del turno. Cuando exista una multa por cancelación tardía, su importe deberá calcularse a partir del precio efectivo del turno y del porcentaje de multa vigente configurado por el Profesional. Un cambio posterior de configuración deberá afectar únicamente a las cancelaciones futuras y no recalcular ni modificar multas ya determinadas. La edición posterior de un tipo de consulta no deberá alterar retroactivamente los turnos ya creados; solo deberá afectar a los turnos nuevos.
* **RF-10: Aprobación:** El sistema deberá proveer una opción de configuración a nivel de perfil profesional que permita definir la modalidad de aprobación de los turnos solicitados, alternando entre un flujo de aprobación manual y un flujo de aprobación automática. En el flujo manual, la solicitud del paciente inicia en estado Solicitado; en el flujo automático, inicia en estado Reservado. Para reservas creadas durante el día D-1, la aprobación manual lleva la solicitud directamente a Confirmado y la aprobación automática genera Confirmado desde el inicio. En turnos creados por Profesional, si la creación ocurre antes de D-1 el turno nace en estado Reservado y continúa el flujo de confirmación por WhatsApp; si ocurre durante D-1, el turno nace directamente en estado Confirmado y no usa confirmación por WhatsApp. Esta regla no amplía la selección de Pacientes ni modifica los permisos del Profesional. Cualquier actor habilitado (Paciente, Secretaría o Profesional) solo podrá crear o reservar turnos para una cita del día D hasta las 23:59 horas del día D-1. La única excepción al corte general de reserva D-1 será la lista de espera operada en modo Manual para un cupo liberado el mismo día D, sin exposición pública ni habilitación de reserva autónoma. La asignación directa de un cupo liberado el mismo día D por Secretaría o Profesional no habilita reserva pública autónoma ni altera este corte.
* **RF-10 bis: Cancelación voluntaria del paciente:** El sistema deberá permitir configurar por perfil profesional el plazo de cancelación voluntaria del paciente. La configuración predeterminada deberá habilitar la cancelación hasta las 23:59 del día D-1. La configuración personalizada deberá permitir definir un entero entre 1 y 72 horas antes del horario del turno, pudiendo habilitar cancelaciones dentro del mismo día de la cita. Antes de confirmar la reserva, el sistema deberá mostrar al paciente el límite de cancelación aplicable según el perfil profesional. Este límite solo determina hasta cuándo el Paciente puede cancelar por su cuenta; no define por sí mismo si una cancelación es tardía ni si corresponde una multa. La política de multa y el porcentaje vigente también deberán mostrarse al Paciente antes de confirmar la reserva.

#### 3.2.3 Portal del Paciente y Turnos
* **RF-11: Calendario:** El sistema deberá renderizar una interfaz gráfica de usuario en forma de calendario interactivo para el paciente, en la cual se deberán reflejar exclusivamente las franjas horarias con disponibilidad de atención.
* **RF-12: Control de Masividad:** El sistema deberá ejecutar reglas de validación que impidan a un mismo usuario la reserva simultánea de múltiples turnos que se superpongan en horario, previniendo el acaparamiento de la agenda. Si un Paciente registra una multa pendiente asociada a un Profesional, el sistema deberá bloquear únicamente sus nuevas reservas autónomas con ese Profesional, sin afectar reservas con otros Profesionales ni turnos ya existentes.
* **RF-13: Historial operativo de turnos:** El sistema deberá permitir al paciente acceder a un listado histórico de sus turnos pasados (completados o cancelados), incluyendo únicamente información operativa y administrativa del turno, como fecha, horario, Profesional, tipo de consulta, estado operativo, estado administrativo y estado financiero. No deberá mostrar historia clínica, seguimiento clínico, indicaciones clínicas, diagnósticos, observaciones profesionales ni notas clínicas.
* **RF-14: Máquina de Estados:** El sistema deberá gestionar el ciclo de vida de cada turno mediante una máquina de estados finitos, registrando las transiciones obligatorias entre los estados operativos: Solicitado, Reservado, Confirmado, Asistió, Cancelado y No asistió, y el estado administrativo: Abierto o Cerrado. El estado inicial dependerá del rol que crea o reserva el turno y de la fecha de la cita según RF-10. Sobreturno no deberá utilizarse como estado del ciclo de vida, sino como tipo o modalidad de turno compatible con esos estados. El cierre administrativo deberá mantenerse Abierto mientras exista alguna acción operativa o financiera pendiente, y solo deberá pasar a Cerrado cuando el turno alcance un resultado operativo terminal y no queden obligaciones financieras ni decisiones de multa pendientes. La cancelación automática de un turno Reservado por falta de confirmación únicamente deberá liberar la agenda; no deberá considerarse, por sí misma, una cancelación tardía sancionable. La cancelación manual de un turno deberá unificarse bajo la operación de dominio Cancelar turno, cambiar el estado operativo a Cancelado, liberar de inmediato el horario y conservar de forma auditada el actor, la fecha, la hora, el motivo obligatorio y el estado anterior. Cuando un turno Confirmado sea modificado por Profesional en fecha u horario, el sistema deberá registrar explícitamente una de dos decisiones: "Acordado con el paciente", dejando el turno Confirmado y limitándose WhatsApp a informar el nuevo horario, o "Requiere confirmación", pasando el turno a Reservado y solicitando nueva confirmación por WhatsApp. "Requiere confirmación" solo deberá estar disponible si faltan al menos 24 horas para el nuevo horario; si faltan menos de 24 horas, deberá elegirse "Acordado con el paciente" y, si no hubo acuerdo, corresponderá cancelar el turno en lugar de reprogramarlo unilateralmente. La decisión elegida, el actor, la fecha y hora de la modificación, y los valores anteriores y nuevos deberán quedar auditados. Después de finalizar el horario previsto del turno, el Profesional o la Secretaría deberán poder registrar el resultado operativo como "Asistió" o "No asistió"; la interfaz deberá presentar "Asistió" preseleccionado como opción predeterminada, pero dicha preselección solo deberá representar una elección de interfaz y requerirá confirmación humana expresa para concretar el cierre. El registro de "No asistió" solo deberá habilitarse una vez finalizado el horario previsto del turno (hora de inicio más duración aplicable) y deberá dejar constancia del actor, la fecha y la hora de la operación. Si posteriormente se corrige un cierre entre "Asistió" y "No asistió", el sistema deberá conservar el cierre original y agregar un evento de corrección auditado con actor, fecha, hora, estado anterior, estado nuevo y motivo obligatorio.
* **RF-15: Sobreturnos:** El sistema deberá habilitar a los roles con privilegios administrativos (Secretaría o Profesional) la creación manual de turnos denominados "sobreturnos", permitiendo su inserción en la agenda en horarios atípicos o por fuera de los bloques regulares de disponibilidad.

#### 3.2.4 Automatizaciones y Notificaciones
* **RF-16: Confirmación y Cancelación:** El sistema deberá gestionar la confirmación por WhatsApp para los turnos sujetos a ese flujo y, si un turno en estado Reservado no recibe confirmación antes de las 18:00 horas del día anterior a la cita, deberá cambiar automáticamente a Cancelado, liberando de inmediato el bloque horario. Esta cancelación automática por falta de confirmación no deberá habilitar ni generar multa.
* **RF-16 bis: Cancelación tardía y multa aplicada:** El sistema deberá distinguir entre cancelación tardía y multa aplicada. Solo podrá considerarse multa cuando el Paciente cancele desde las 18:00 horas del día D-1 un turno que estaba Confirmado, o cuando el turno se registre como No asistió. En ambos casos elegibles, el Profesional deberá decidir expresamente si aplica o perdona la multa configurada para su perfil; no deberá ingresar un monto manual. Si decide aplicarla, el sistema deberá calcular el importe a partir del porcentaje vigente configurado sobre el precio efectivo del turno. Si la configuración de multa cambia luego de determinada una cancelación, no deberán recalcularse ni alterarse las multas ya determinadas. El registro de "No asistió" no deberá generar multa automática: solo deberá habilitar la decisión posterior del Profesional sobre su aplicación o perdón. Si un cierre de "No asistió" se corrige a "Asistió" y existiera una multa pendiente, el sistema deberá anularla de inmediato y restaurar la reserva autónoma con ese Profesional. Cuando el Paciente rechace una propuesta de aumento en un turno no Pagado, el sistema deberá conservar el precio anterior; si el Profesional decide no mantener ese precio anterior, podrá iniciar una cancelación manual del turno con motivo auditado y sin multa para el Paciente.
* **RF-17: Recordatorios:** El sistema deberá integrarse con la API de WhatsApp para enviar de manera automatizada dos mensajes de recordatorio y solicitud de confirmación a cada paciente: el primero a las 08:00 horas del día D-2 y el segundo a las 08:00 horas del día D-1, advirtiendo explícitamente que la falta de respuesta causará la cancelación del turno. Los turnos creados o aprobados durante D-1 omiten este flujo de WhatsApp. Los turnos creados por Profesional antes de D-1 sí deben atravesar este flujo; los creados durante D-1 no. Este calendario regular es independiente del disparador inmediato que debe enviarse cuando un turno Confirmado es modificado en fecha u horario por Profesional. En esa modificación, WhatsApp deberá reflejar la decisión explícita elegida entre "Acordado con el paciente" o "Requiere confirmación", según corresponda al umbral de 24 horas.
* **RF-18: Liberación de Agenda:** El sistema deberá liberar el bloque horario en la base de datos de manera inmediata tras la cancelación de un turno, reflejando la disponibilidad instantánea en el calendario interactivo. Esta liberación deberá ser inmediata tanto en cancelaciones automáticas como manuales.

#### 3.2.5 Lista de Espera y Facturación
* **RF-19: Lista de Espera:** El sistema deberá mantener, por cada Profesional, una única cola de espera ordenada por fecha y hora de inscripción. Ante la liberación de un cupo, el sistema deberá ofrecerlo a una sola persona por vez, comenzando por el primer Paciente elegible de la cola. Al enviar una oferta de lista de espera, el cupo deberá quedar retenido exclusivamente durante 30 minutos; mientras dure la retención no deberá aparecer disponible para otras reservas ni podrá ofrecerse a otra persona. La retención no deberá crear un turno ni modificar el historial o el estado del Paciente. Si el Paciente acepta dentro del plazo, la retención deberá convertirse en turno según el flujo aplicable. Si rechaza o vence el plazo, el sistema deberá liberar la retención y ofrecer el cupo al siguiente Paciente elegible con una nueva retención de 30 minutos. Cada Profesional deberá configurar la modalidad de operación en Automático o Manual. En modo Automático, el sistema deberá enviar la oferta al primer Paciente elegible cuando se libere un cupo. En modo Manual, el sistema deberá notificar al Profesional y a Secretaría sin contactar a Pacientes; luego cualquiera de esos roles podrá autorizar el envío al primer Paciente de la cola. La Secretaría solo podrá alterar el orden de la cola por motivo obligatorio y con registro de auditoría. La creación, aceptación, rechazo, vencimiento, liberación y conversión de la retención deberán quedar auditadas. Todas las ofertas, respuestas, vencimientos, cambios de orden y autorizaciones deberán quedar auditados. Si el cupo liberado corresponde al mismo día D, la oferta solo podrá gestionarse como excepción mediante lista de espera en modo Manual, con notificación a Profesional y Secretaría y autorización de uno de esos roles antes del envío al primer Paciente elegible. Esa excepción solo podrá iniciarse o continuarse mientras falten al menos 2 horas para el horario del turno; cuando falten menos de 2 horas, no deberán enviarse nuevas ofertas.
  Al inscribirse en la lista de espera, el Paciente deberá declarar el tipo de consulta requerido, los días aceptables y las franjas horarias aceptables, o indicar «Cualquier horario». Solo deberán ofrecerse cupos compatibles con esas preferencias. Si el primer Paciente por antigüedad no coincide con un cupo, el sistema deberá saltearlo temporalmente para esa oferta, sin eliminarlo de la cola, cambiar su fecha de inscripción ni modificar su posición relativa para futuras ofertas, y deberá seleccionar al Paciente elegible más antiguo.

  La inscripción y edición de la preferencia deberán estar permitidas según el rol: el Paciente podrá crear y editar su propia inscripción; Secretaría podrá crear y editar la inscripción de cualquier Paciente registrado; Profesional podrá crear y editar solo inscripciones de Pacientes que tengan o hayan tenido al menos un turno con ese Profesional. Cuando actúen Secretaría o Profesional, deberán registrar una declaración simple de que actúan a pedido del Paciente, sin almacenar evidencia del pedido. El alta o edición, el actor, el Paciente, el Profesional, las preferencias anteriores y nuevas, la fecha/hora y la declaración deberán quedar auditados. Pendiente de definición: el efecto de editar preferencias sobre la antigüedad o posición en la cola.

  La asignación directa de un cupo liberado por Secretaría o Profesional deberá respetar el mismo corte temporal que la reserva de un turno del día D: solo podrá ejecutarse hasta el inicio del turno, nunca después. Esa asignación no deberá depender de la cola de espera ni alterar el orden relativo o la prioridad de los Pacientes que permanecen en ella. Si el Paciente destinatario estaba inscripto en la lista de espera de ese Profesional, el sistema deberá eliminar únicamente su inscripción al crearse el turno y registrar la salida con el motivo «Cubierto por asignación directa». Para realizarla, el actor deberá marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario». El acuerdo podrá ser verbal o producirse fuera del sistema; el sistema no deberá solicitar ni almacenar evidencia, grabación, comprobante o canal de dicho acuerdo.
* **RF-20: Pagos:** El sistema deberá requerir el registro del estado financiero de cada consulta, categorizando la transacción como Pendiente, En revisión, Pagado o Rechazado y documentando el método de pago empleado. Un pago directo en efectivo registrado por el Profesional o la Secretaría deberá pasar a Pagado sin comprobante. La carga de un comprobante deberá pasar a En revisión; su validación, a Pagado; y su rechazo, a Rechazado. Estas transiciones no deberán alterar el estado operativo del turno. El cierre administrativo deberá permanecer Abierto cuando exista pago pendiente, multa pendiente o decisión de multa pendiente, y solo deberá pasar a Cerrado cuando no quede ninguna obligación pendiente. La multa por cancelación tardía no deberá confundirse con el estado financiero de la consulta: su decisión de aplicación/perdón y su eventual cálculo deberán registrarse por separado. La cancelación automática por falta de confirmación no deberá generar ni activar multa. Cuando la multa sea pagada o perdonada, y no quede otra obligación pendiente, el cierre administrativo deberá poder pasar a Cerrado. Si una multa que nació de un cierre de "No asistió" corregido a "Asistió" ya estaba "Pendiente", el sistema deberá anularla; si ya estaba "Pagado", el sistema deberá conservar el registro y, al invalidarse la multa por la corrección, deberá generar automáticamente un saldo a favor del Paciente con ese Profesional por el importe pagado. Secretaría deberá poder visualizar ese saldo a favor y registrar una devolución realizada fuera del sistema si el Paciente la solicita; dicho registro deberá consumir el saldo a favor correspondiente. El sistema no deberá borrar ni alterar el pago, la multa ni la corrección originales.
* **RF-21: Comprobantes:** El sistema deberá contar con un módulo de gestión documental que permita la carga, almacenamiento en el servidor y posterior validación o rechazo de archivos de imagen o PDF correspondientes a comprobantes de pago. La carga o validación del comprobante no deberá modificar por sí misma el estado operativo del turno; únicamente deberá afectar el estado financiero asociado.
* **RF-22: Reportes:** El sistema deberá procesar únicamente los importes con estado financiero Pagado para generar informes tabulares o gráficos que resuman los ingresos percibidos por el profesional, filtrables por periodos mensuales y anuales.

### 3.3 Requisitos de Rendimiento
* **Rend-01:** El sistema deberá soportar una carga operativa de hasta 50 sesiones de usuario concurrentes manteniendo la estabilidad del servicio.
* **Rend-02:** El sistema deberá garantizar que el tiempo de respuesta y de renderizado del front-end no exceda los 2 segundos bajo condiciones de red estándar.
* **Rend-03:** El sistema deberá procesar las peticiones a la API de mensajería (WhatsApp) y encolar los envíos en un lapso no superior a 5 minutos desde la activación del evento disparador.

### 3.4 Restricciones de Diseño
* **RD-01 Diseño Responsivo:** El sistema deberá desarrollarse utilizando patrones de diseño web adaptativo (Responsive Design), garantizando que los componentes de la interfaz de usuario se autoajusten dinámicamente a las resoluciones de monitores de escritorio, tabletas y teléfonos móviles.
* **RD-02 Navegación:** El sistema deberá garantizar su completa funcionalidad y correcta visualización sobre los motores de renderizado de las versiones estables más recientes de los navegadores Google Chrome, Mozilla Firefox, Apple Safari y Microsoft Edge.

### 3.5 Atributos del Sistema 
#### 3.5.1 Seguridad
* **RNF-01 Privacidad de Datos Bancarios:** El sistema deberá aplicar medidas de ofuscación o restricción de vista de la información financiera, asegurando que los datos sensibles como el Alias y el CBU sean expuestos en la interfaz de usuario únicamente dentro de la ventana de carga de comprobantes del paciente.
* **RNF-02 Integridad:** El sistema deberá asegurar, mediante reglas del backend, que exclusivamente los usuarios autenticados bajo el rol de Administrador posean los permisos necesarios para ejecutar operaciones de modificación sobre credenciales de acceso y correos electrónicos de terceros.

#### 3.5.2 Disponibilidad
* **RNF-03 Operatividad:** El sistema deberá estar desplegado en una infraestructura que garantice un tiempo de actividad (Uptime) del 99.9%, asegurando la operatividad continua (24/7) de los módulos orientados al paciente.

### 3.6 Otros Requisitos
* **RF-23 Registro de Auditoría:** El sistema deberá registrar de forma automática, silenciosa e inmutable en una tabla de auditoría (log) cada transacción realizada, persistiendo obligatoriamente el identificador del usuario que ejecutó la acción, el tipo de operación, la fecha y la hora del evento del lado del servidor. Las operaciones vinculadas a la lista de espera —alta, edición, oferta enviada, aceptación de la oferta, rechazo de la oferta, vencimiento de la oferta, liberación de la retención, conversión de la retención en turno, cambio de orden, autorización de envío, salto temporal de un Paciente no elegible y fin del proceso por alcanzar el límite temporal de la lista de espera— deberán quedar auditadas de forma diferenciada. La evaluación de elegibilidad, las preferencias vigentes que la determinan y cualquier salto temporal de un Paciente no elegible también deberán quedar registradas. Las cancelaciones de turno, el registro de "No asistió", el cierre manual de un turno como "Asistió" o "No asistió", la decisión del Profesional de aplicar o perdonar la multa, el registro de pagos en efectivo o por transferencia y la eventual multa aplicada deberán quedar diferenciadas como operaciones distintas en la auditoría. La cancelación automática por falta de confirmación también deberá registrarse como operación de liberación de agenda, sin etiquetarse como cancelación tardía sancionable. El inicio, la verificación, la activación y cualquier fallo de cambios de correo iniciados por el Administrador o por Secretaría en correos de Pacientes deberán quedar auditados como eventos separados. La creación excepcional de un turno pese a una multa pendiente también deberá quedar auditada indicando el actor que ejerció la excepción. La asignación directa de un cupo liberado por Secretaría o Profesional deberá quedar auditada con actor, Paciente, Profesional, cupo, fecha/hora y motivo. La alta o edición de inscripción en lista de espera, el actor, el Paciente, el Profesional, las preferencias anteriores y nuevas, la fecha/hora y la declaración simple de actuación a pedido del Paciente deberán quedar auditadas. La modificación posterior de la configuración de multa no deberá alterar los registros históricos ya auditados. Cualquier corrección entre "Asistió" y "No asistió" deberá quedar registrada como evento de corrección auditado con actor, fecha, hora, estado anterior, estado nuevo y motivo obligatorio, sin sob...

---

## 4. Apéndices
* **A.1:** Diagrama de estados del turno (Solicitado -> Reservado -> Confirmado -> Asistió; Reservado -> Cancelado; Reservado -> No asistió; casos D-1 que llegan directo a Confirmado; Sobreturno como tipo/modalidad compatible).
* **A.2:** Mockups de la interfaz del calendario interactivo.
* //Diagramas de caso de uso (referencia a imagen)
* //Imagen del diagrama entidad-relación final (referencia a imagen)

---

## Cambio en la sección de inicio de sección 

| Atributo | Rango / Escala | Descripción |
|---|---|---|
| Valor | 1-34 | Secuencia de Fibonacci. 1: Simple, 34: Muy grande |
| Prioridad | 1 - 5 | 1: Postergable, 3: Normal, 5: Inmediato. |
| Estimación | 1h - 48h | Tiempo de desarrollo activo. Si > 48h, se fragmenta. |

---

## Historias de Usuario

### HISTORIA DE USUARIO Núm: 4.1 | Listar Profesionales
**Como** Administrador, **quiero** visualizar un listado de profesionales activos con opciones de búsqueda y filtrado, **para poder** encontrar rápidamente la información necesaria y ahorra tiempo.
* **Valor:** 5 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que el sistema muestra únicamente profesionales con fecha de cierre nula. 
  * Comprobar que el sistema permite buscar profesionales por nombre y apellido. 
  * Comprobar que el sistema permite aplicar filtros mínimos obligatorios para acotar los resultados. 
  * Demostrar que el listado se actualiza correctamente al aplicar filtros o realizar una búsqueda sin necesidad de recargar manualmente la página. 
  * Verificar que cuando Administrador hace una búsqueda o aplica filtros sobre el listado consigue visualizar únicamente los profesionales que cumplen con los criterios ingresados. 
  * Verificar que cuando Administrador hace acceso al módulo de gestión de profesionales consigue visualizar el listado completo de profesionales activos disponibles en el sistema. 
  * Dado que existen profesionales registrados con fecha de cierre nula y adicionalmente el Administrador cuenta con permisos de acceso al módulo cuando accede a la funcionalidad de listado entonces el sistema muestra el listado de profesionales activos actualizado en un tiempo menor a 2 segundos.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.2 | Alta Profesional
**Como** Administrador, **quiero** registrar un nuevo profesional ingresando sus datos personales, **para poder** asegurar una incorporación ordenada y validada, minimizando errores administrativos dentro del sistema.
* **Valor:** 8 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
   * Comprobar que los campos nombre, apellido, DNI y email sean obligatorios para registrar un profesional. 
   * Comprobar que el género y la fecha de nacimiento no sean obligatorios para registrar un profesional. 
   * Comprobar que el DNI y el email sean únicos dentro del sistema, evitando registros duplicados. 
   * Comprobar que el campo teléfono sea opcional y no bloquee el alta si no se completa. 
  * Demostrar que, al registrar un profesional, la cuenta queda en estado pendiente de validación hasta que se complete el proceso de verificación. 
  * Verificar que cuando Administrador hace el registro de un nuevo profesional consigue que el sistema genere la cuenta en estado pendiente y envíe una invitación de validación por email o teléfono. 
  * Verificar que cuando Administrador hace el ingreso de datos duplicados en DNI o email consigue que el sistema rechace la operación e informe el error correspondiente. 
  * Dado que los datos ingresados son válidos y no se encuentran previamente registrados y adicionalmente el Administrador confirma la operación cuando realiza el alta entonces el sistema registra al profesional con fecha de creación y estado pendiente de validación, enviando la invitación correspondiente.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.3.1 | Modificación Profesional (Administrador)
**Como** administrador **quiero** poder modificar los datos de un profesional en particular **para poder** garantizar información confiable y actualizada, reduciendo inconsistencias administrativas y asegurando la correcta operación del sistema.
* **Valor:** 8 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que el sistema permita editar todos los datos habilitados del profesional, exceptuando la fecha de creación del registro.
  * Comprobar que los campos modificados mantengan las restricciones de validación definidas, incluyendo unicidad de DNI y correo electrónico.
  * Demostrar que el sistema persiste correctamente los cambios realizados en la base de datos una vez confirmada la modificación.
  * Demostrar que cuando se modifica el correo electrónico, el sistema exige la validación previa del nuevo dato antes de activar el cambio.
  * Verificar que cuando el Administrador hace una modificación sobre los datos de un profesional consigue que la información quede actualizada correctamente dentro del sistema.
  * Verificar que cuando el Administrador hace una modificación válida del correo electrónico consigue que el sistema inicie automáticamente el proceso de verificación correspondiente sin reemplazar la identidad principal anterior.
  * Dado que el Administrador ha iniciado una modificación de correo de un profesional y adicionalmente la información ingresada cumple con las reglas de validación cuando presiona el botón “Guardar”, entonces el sistema registra la solicitud, mantiene activo el correo anterior hasta verificar el nuevo y confirma la operación.
  * Comprobar que si el profesional ya existe en estado inactivo, el sistema permita reactivar su registro en lugar de crear uno nuevo.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.3.2 | Modificación Profesional (Profesional)
**Como** profesional, **quiero** actualizar determinados datos personales autorizados, **para poder** mantener mi información operativa vigente sin depender de intervención administrativa.
* **Valor:** 5 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
   * Comprobar que el profesional solo pueda editar los datos autorizados: alias bancario, teléfono, foto de perfil y datos de contacto visibles.
   * Comprobar que el sistema mantenga no habilitada la edición del correo electrónico propio del Profesional en este flujo.
   * Comprobar que el sistema bloquee la edición de datos restringidos como DNI, nombre legal, fecha de alta, estado de cuenta, credenciales principales y rol asignado.
  * Demostrar que el sistema valida automáticamente los permisos del rol profesional antes de aplicar cualquier modificación.
  * Demostrar que el sistema rechaza cualquier intento de edición sobre campos no autorizados mostrando la restricción correspondiente.
  * Verificar que cuando el Profesional hace una modificación sobre sus datos habilitados consigue que la información quede actualizada correctamente dentro del sistema.
  * Verificar que cuando el Profesional hace un intento de modificación sobre un dato restringido consigue que el sistema deniegue la operación.
  * Dado que el Profesional ha modificado correctamente sus datos autorizados y adicionalmente la información ingresada cumple con las reglas de validación cuando presiona el botón “Guardar” entonces el sistema actualiza únicamente los cambios permitidos y confirma la operación.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.4 | Baja Profesional 
**Como** Administrador, **quiero** dar de baja a un profesional en específico, **para poder** evitar nuevas reservas sobre profesionales no disponibles, asegurando consistencia operativa dentro del sistema.
* **Valor:** 5 | **Prioridad:** 3 | **Estimación:** 8 h
* **Validación:**
  * Comprobar que la baja de un profesional se realice mediante la asignación de una fecha de cierre, sin eliminar su información histórica del sistema.
  * Comprobar que el sistema impida la baja cuando el profesional posea turnos futuros asignados que no se encuentren cancelados.
  * Comprobar que la fecha de cierre registrada sea menor o igual a la fecha actual del sistema.
  * Comprobar que el sistema solicite una confirmación explícita antes de ejecutar la baja de un profesional.
  * Demostrar que, una vez dada de baja la cuenta, el profesional deja de estar disponible para nuevas reservas de turnos.
  * Demostrar que el profesional dado de baja deja de visualizarse en los listados de profesionales activos.
  * Verificar que cuando el Administrador hace la solicitud de baja de un profesional consigue visualizar una ventana de confirmación previa a la ejecución definitiva.
  * Verificar que cuando el Administrador hace un intento de baja sobre un profesional con turnos futuros activos consigue que el sistema rechace la operación e informe la restricción correspondiente.
  * Dado que el Administrador seleccionó un profesional activo y adicionalmente confirmó la acción en la ventana de validación cuando presiona “Confirmar baja” entonces el sistema registra la fecha de cierre, inhabilita la cuenta y bloquea nuevas solicitudes de turno asociadas.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Num: 2.1 | Visualizar Turnos
**Como** profesional de la salud, **quiero** visualizar en una vista unificada todos mis turnos del día, incluyendo el estado actual, el nombre del paciente, el tipo de consulta y el horario de cada cita **para** disponer de una visión completa e inmediata de mi jornada laboral, reducir el riesgo de omitir atenciones y gestionar proactivamente los turnos pendientes de confirmación sin depender de consultas manuales a terceros. Al finalizar el horario previsto de un turno, el profesional podrá cerrarlo expresamente como "Asistió" o "No asistió"; la interfaz deberá mostrar "Asistió" como opción preseleccionada, sin que ello implique aplicación automática del estado ni dispensa de confirmación humana. Cuando el profesional corrija un cierre entre "Asistió" y "No asistió", el sistema deberá exigir un motivo obligatorio y registrar la corrección como un evento auditado sin borrar el cierre original.
* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 24 h
* **Validación:**
  * Dado que el profesional accede a la vista de sala/área de trabajo y adicionalmente existe un turno en estado "Solicitado" para el día actual, cuando el profesional ingresa al módulo, entonces el sistema resalta visualmente dicho turno como pendiente de aprobación.
  * Demostrar que cada bloque de turno visualizado incluye: horario, nombre del paciente, tipo de consulta y estado actual (Solicitado, Reservado, Confirmado, Asistió, Cancelado, No asistió), donde Reservado representa un turno aprobado pendiente de confirmación del Paciente.
  * Dado que finalizó el horario previsto de un turno, cuando el Profesional registra expresamente el cierre como "Asistió" o "No asistió", entonces el sistema actualiza el estado, registra la operación en la auditoría y no aplica una multa automática.
  * Dado que un turno ya fue cerrado como "Asistió" o "No asistió", cuando el Profesional corrige ese cierre, entonces el sistema exige un motivo obligatorio, conserva el cierre original y registra un evento de corrección auditado con actor, fecha, hora, estado anterior y estado nuevo.
  * Dado que el cierre corregido pasa de "No asistió" a "Asistió" y existe una multa pendiente asociada, cuando el Profesional confirma la corrección, entonces el sistema anula de inmediato la multa y restaura la reserva autónoma con ese Profesional.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 2.2 | Crear Turno
**Como** profesional de la salud, **quiero** crear manualmente un turno en mi agenda para un paciente determinado, especificando fecha, horario y tipo de consulta **para** garantizar la continuidad y flexibilidad en la atención, permitiendo incorporar casos particulares o reagendamientos que no pueden canalizarse a través del flujo de reserva estándar del paciente, sin comprometer la integridad de la agenda.
* **Valor:** 8 | **Prioridad:** 4 | **Estimación:** 12 h
* **Validación:**
  * Dado que el profesional intenta crear un turno y adicionalmente el paciente ya tiene otro turno en el mismo horario, cuando confirma la operación, entonces el sistema rechaza la creación y muestra un mensaje de conflicto de agenda.
   * Verificar que cuando el profesional crea un turno antes de D-1, el sistema utiliza el flujo de confirmación por WhatsApp; si lo crea durante D-1, omite dicho flujo.
   * Dado que el horario está disponible, cuando el profesional guarda el turno, entonces el sistema registra el turno en estado Reservado si la creación ocurrió antes de D-1, o en estado Confirmado si ocurrió durante D-1.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 2.3 | Modificar Turno
**Como** profesional de la salud, **quiero** modificar los datos de un turno existente, incluyendo fecha, horario y tipo de consulta **para** adaptar la agenda ante imprevistos o cambios operativos sin necesidad de cancelar y recrear el turno, preservando la trazabilidad del historial operativo del paciente y minimizando el impacto operativo en la gestión administrativa.
* **Valor:** 8 | **Prioridad:** 3 | **Estimación:** 18 h
* **Validación:**
   * Dado que el profesional modifica fecha u horario sobre un turno en estado Confirmado, cuando guarda cambios, entonces el sistema solicita una decisión explícita, valida disponibilidad y conserva el historial previo.
   * Dado que el profesional modifica fecha u horario sobre un turno en estado Confirmado, cuando confirma la edición, entonces el sistema aplica la decisión elegida: si es "Acordado con el paciente", mantiene el turno Confirmado y solo informa el nuevo horario por WhatsApp; si es "Requiere confirmación", pasa el turno a Reservado y solicita nueva confirmación por WhatsApp.
   * Dado que la modificación ocurre con menos de 24 horas para el nuevo horario, cuando se guarda el turno, entonces el sistema solo permite la opción "Acordado con el paciente"; si no hubo acuerdo, corresponde cancelar el turno.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 2.4 | Cancelar Turno
**Como** profesional de la salud, **quiero** cancelar un turno de mi agenda para liberar el bloque horario inmediatamente y ponerlo a disposición de otros pacientes, evitando que la agenda presente huecos bloqueados que no generan atenciones efectivas ni ingresos para el centro, sin borrar físicamente el turno y preservando su historial operativo.
* **Valor:** 5 | **Prioridad:** 3 | **Estimación:** 16 h
* **Validación:**
   * Dado que el turno se encuentra en estado Reservado o Confirmado y adicionalmente el profesional selecciona la opción “Cancelar”, cuando confirma la acción en el diálogo de verificación, entonces el sistema cambia el estado operativo a Cancelado sin eliminar físicamente el turno ni asignar un nuevo horario de reemplazo.
   * Dado que el turno es cancelado exitosamente, cuando finaliza la operación, entonces el sistema libera el bloque horario de forma inmediata, lo refleja como disponible en el calendario interactivo del paciente y registra la operación en el log de auditoría con actor, fecha, hora, motivo obligatorio y estado anterior.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 2.8 | Listar turnos por paciente
**Como** profesional de la salud, **quiero** listar mis turnos filtrados por paciente específico o rango de fechas **para** acceder de forma ágil al historial operativo de turnos de mis pacientes y facilitar la gestión administrativa continuada, sin depender de búsquedas manuales que insumen tiempo y aumentan la probabilidad de errores de gestión.
* **Valor:** 8 | **Prioridad:** 2 | **Estimación:** 24 h
* **Validación:**
   * Dado que el profesional autenticado accede a la sección "Listar Turnos", cuando solicita la generación del listado, entonces el sistema consulta la base de datos y renderiza la tabla con los turnos asignados a dicho profesional.
   * Dado que no existen turnos registrados para el profesional en el rango de fechas consultado, cuando el profesional ejecuta la búsqueda, entonces el sistema muestra un mensaje informativo que indica "No se encontraron turnos para los criterios seleccionados".
    * Dado que el profesional autenticado selecciona un paciente, cuando el sistema muestra el historial, entonces solo expone los turnos de ese paciente vinculados a la relación con dicho profesional autenticado, sin incluir información de otros profesionales ni contenido clínico.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 2.9 | Listar Turno del Paciente
**Como** paciente, **quiero** visualizar en mi panel principal un listado completo de mis turnos (tanto próximos como pasados), incluyendo la fecha, horario, profesional asignado y el estado del turno, **para** llevar un control personal de mis turnos, recordar mis próximas citas y autogestionar mi historial operativo sin necesidad de contactar a la secretaría del centro.
* **Valor:** 5 | **Prioridad:** 2 | **Estimación:** 24h
* **Validación:**
  * Dado que el paciente autenticado accede a la sección "Mis Turnos" de su perfil, cuando el sistema carga la vista, entonces consulta la base de datos y renderiza una lista ordenada cronológicamente con todos los turnos asociados a ese paciente.
  * Dado que el paciente revisa su historial, cuando visualiza la lista, entonces el sistema diferencia visualmente (por ejemplo, con etiquetas o colores) el estado de cada turno (Ej: Reservado, Confirmado, Asistió, Cancelado).
  * Dado que el paciente es nuevo o no ha realizado reservas, cuando accede a la sección de turnos, entonces el sistema muestra un mensaje amigable indicando "Aún no tienes turnos registrados".
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 3.1 | Editar Periodo
**Como** profesional de la salud, **quiero** configurar y modificar la ventana temporal de anticipación con la que los pacientes pueden realizar reservas de turno **para** adaptar la planificación de la agenda a mis necesidades operativas y administrativas, evitando reservas con escasa o excesiva anticipación que afectan la organización del centro y la calidad del servicio ofrecido.
* **Valor:** 3 | **Prioridad:** 2 | **Estimación:** 12 h
* **Validación:**
  * Dado que el profesional autenticado accede al módulo de configuración de agenda, cuando selecciona la opción "Editar Periodo de Reserva", entonces el sistema presenta una interfaz con los valores actuales de ventana de reserva (días o meses) permitiendo su modificación.
  * Dado que los datos ingresados superan todas las validaciones de negocio (formato, rango, coherencia), cuando el profesional confirma el guardado, entonces el sistema persiste la nueva configuración en la base de datos y actualiza inmediatamente el comportamiento del calendario del paciente.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 3.2 | Editar Disponibilidad
**Como** profesional de la salud, **quiero** configurar mis horarios regulares de atención, registrar ausencias y bloquear días no laborables en la agenda **para** asegurar que el calendario visible para los pacientes refleje únicamente mi disponibilidad real, previniendo reservas en horarios no habilitados y eliminando la necesidad de cancelaciones manuales posteriores que deterioran la experiencia del paciente.
* **Valor:** 21 | **Prioridad:** 5 | **Estimación:** 24 h
* **Validación:**
  * Dado que el profesional guarda los cambios realizados en la disponibilidad, y adicionalmente el sistema analiza los horarios modificados, cuando se ejecuta la validación, entonces el sistema verifica automáticamente la existencia de conflictos con turnos futuros activos y muestra todos los turnos afectados.
  * Dado que existen conflictos detectados en los horarios afectados, cuando el profesional intenta guardar la modificación, entonces el sistema impide la persistencia del cambio hasta que cada turno conflictivo sea reprogramado o cancelado individualmente por los flujos ya definidos.
  * Dado que no existen conflictos en los horarios afectados, y adicionalmente la nueva disponibilidad respeta las restricciones de duración por tipo de consulta, cuando finaliza la operación, entonces el sistema persiste la nueva disponibilidad y la refleja en el calendario interactivo del paciente.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 3.3 | Definir Tipos de Consulta
**Como** profesional de la salud, **quiero** crear y gestionar los distintos tipos de consulta que ofrezco, definiendo para cada uno su nombre, duración estimada y valor monetario base **para** estructurar y estandarizar el catálogo de servicios del centro, permitiendo que los pacientes seleccionen el tipo de atención adecuado al reservar y que el sistema calcule automáticamente la disponibilidad horaria en función de la duración de cada prestación. Al crearse un turno, el sistema debe conservar en ese turno el nombre, la duración y el precio base vigentes del tipo de consulta en ese momento.
* **Valor:** 8 | **Prioridad:** 4 | **Estimación:** 16h
* **Validación:**
  * Dado que el profesional autenticado accede al módulo "Tipos de Consulta", cuando crea un nuevo tipo de consulta ingresando nombre, duración estimada (en minutos) y valor monetario base, entonces el sistema registra la entidad en la base de datos y la asocia al perfil del profesional.
  * Dado que el profesional modifica un tipo de consulta existente (nombre, duración o precio base), cuando guarda los cambios, entonces el sistema actualiza el catálogo para reservas nuevas y conserva sin cambios los turnos ya existentes, sin importar si están Solicitados, Reservados o Confirmados.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 3.4 | Modificar Precio de Consulta
**Como** profesional de la salud, **quiero** aplicar un precio individual y personalizado a un turno específico, desvinculándolo del valor base configurado en el tipo de consulta **para** otorgar flexibilidad tarifaria ante situaciones particulares (descuentos, convenios o excepciones) sin alterar el precio estándar del catálogo de servicios, manteniendo así la integridad del registro financiero del centro. En turnos no Pagados, una reducción o descuento podrá aplicarse directamente y un aumento deberá requerir aceptación expresa del Paciente; mientras no acepte, seguirá vigente el precio anterior. Si el Paciente rechaza el aumento, el turno conservará el precio anterior y no se cancelará automáticamente; si el Profesional no desea mantener ese precio, podrá cancelar manualmente el turno con motivo auditado y sin sanción para el Paciente. Una vez Pagado, el precio no podrá editarse. Los cambios posteriores del catálogo no deben reescribir retroactivamente el nombre, la duración ni el precio base ya guardados en turnos existentes.
* **Valor:** 3 | **Prioridad:** 4 | **Estimación:** 8h
* **Validación:**
  * Dado que el profesional autenticado accede al detalle de un turno específico, cuando ingresa un nuevo valor monetario en el campo "precio" (diferente al precio base del tipo de consulta), entonces el sistema valida que el formato sea numérico positivo y que el turno no haya sido marcado como "Pagado".
   * Dado que el profesional propone un aumento de precio para un turno no Pagado, cuando el Paciente no lo ha aceptado todavía, entonces el sistema conserva el precio anterior; si el Paciente lo rechaza, el precio anterior sigue vigente y el turno no se cancela automáticamente.
   * Dado que el profesional decide no mantener el precio anterior tras un rechazo de aumento, cuando confirma la cancelación manual, entonces el sistema cancela el turno con motivo auditado y sin multa para el Paciente.
  * Dado que el precio del turno se actualiza exitosamente en la base de datos, y adicionalmente el sistema completa el registro de auditoría, cuando finaliza la operación, entonces el sistema muestra un mensaje de confirmación al profesional y refleja el nuevo monto en la interfaz de listado y detalle del turno.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 1.4 | Listar pacientes
**Como** la Secretaría, **quiero** visualizar y buscar el listado de pacientes registrados en el sistema, **para** poder consultar rápidamente su información y facilitar la gestión administrativa y de turnos.
* **Valor:** 5 | **Prioridad:** 3 | **Estimación:** 8h
* **Validación:**
  * Comprobar que el sistema muestre un listado con todos los pacientes registrados.
  * Comprobar que en el listado se visualicen como mínimo los datos nombre, apellido, DNI, email y teléfono del paciente.
  * Comprobar que el listado pueda visualizarse únicamente por usuarios autorizados con rol la Secretaria.
  * Verificar que cuando la Secretaria accede al módulo de gestión de pacientes consigue visualizar el listado actualizado de pacientes registrados.
  * Verificar que cuando existen pacientes registrados en el sistema consigue que la información se presente de manera ordenada y legible.
  * Verificar que cuando no existen pacientes registrados consigue que el sistema informe correctamente que no hay pacientes cargados.
   * Dado que la Secretaria posee permisos válidos y accede a la funcionalidad de listado de pacientes entonces el sistema recupera y muestra la información registrada de los pacientes disponibles, sin exponer el listado a otros roles.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 1.1 | Alta paciente
**Como** la Secretaria, **quiero** registrar un nuevo paciente ingresando sus datos personales, **para** poder incorporarlo al sistema y permitir la gestión de turnos y atención administrativa correspondiente.
* **Valor:** 8 | **Prioridad:** 5 | **Estimación:** 12h
* **Validación:**
  * Comprobar que los campos nombre, apellido, DNI, fecha de nacimiento, teléfono celular y email sean obligatorios para registrar un paciente.
  * Comprobar que el género sea opcional para registrar un paciente.
  * Comprobar que el DNI y el email sean únicos dentro del sistema, evitando registros duplicados.
  * Comprobar que el campo obra social sea opcional y no bloquee el alta si no se completa.
  * Comprobar que el sistema valide el formato correcto del email ingresado.
  * Comprobar que al registrar un paciente la cuenta quede creada correctamente dentro del sistema.
  * Verificar que cuando la Secretaria realiza el registro de un nuevo paciente consigue que el sistema almacene correctamente la información ingresada.
  * Verificar que cuando la Secretaria ingresa un DNI o email previamente registrado consigue que el sistema rechace la operación e informe el error correspondiente.
  * Verificar que cuando los datos obligatorios no son completados consigue que el sistema impida realizar el alta indicando los campos faltantes.
  * Dado que los datos ingresados son válidos y no se encuentran previamente registrados y adicionalmente la Secretaria confirma la operación cuando realiza el alta entonces el sistema registra al paciente con fecha de creación y habilita su disponibilidad para futuras reservas de turnos.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 5.1 | Registrar Pago
**Como** Profesional o Secretaria, **quiero** registrar manualmente el estado financiero de una consulta, seleccionando el método de pago empleado, **para** mantener actualizada la caja diaria y el estado de cuentas del centro de salud “Origen”.
* **Valor:** 34 | **Prioridad:** 2 | **Estimación:** 12h
* **Validación:**
   * Comprobar que el sistema permite registrar el pago directo en efectivo y lo categoriza como “Pagado” sin comprobante.
  * Comprobar que el sistema despliega un listado con los métodos de pago válidos (Efectivo, Transferencia, Tarjeta, etc.).
    * Verificar que cuando el Profesional o la Secretaría registran un pago directo en efectivo y seleccionan el método de pago, consiguen que el turno actualice su estado financiero a “Pagado” de inmediato.
  * Verificar que cuando la Secretaria visualiza un saldo a favor existente para un Paciente con un Profesional, consigue ver el importe disponible y su origen asociado.
  * Verificar que cuando la Secretaria registra una devolución externa solicitada por el Paciente, consigue que el sistema consuma el saldo a favor correspondiente y deje constancia auditada de la operación.
   * Dado que la Secretaría se encuentra en el detalle del turno de un paciente y adicionalmente el estado actual de la consulta es “Pendiente”, cuando confirma el registro de un pago directo en efectivo con el monto correspondiente, entonces el sistema actualiza la transacción a “Pagado”, impacta el método de pago y genera un registro inmutable en la tabla de auditoría.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.2 | Cargar Comprobante
**Como** Paciente, **quiero** subir al servidor un archivo de imagen o PDF que corresponda al comprobante de la transferencia realizada, **para** que el personal administrativo pueda validar mi pago sin alterar el estado operativo del turno.
* **Valor:** 21 | **Prioridad:** 2 | **Estimación:** 16h
* **Validación:**
  * Comprobar que el módulo de gestión documental permite la carga exclusiva de formatos de imagen (PNG, JPG) y archivos PDF.
  * Comprobar que el tamaño del archivo no exceda el límite máximo permitido por el servidor para el almacenamiento.
   * Verificar que cuando el Paciente sube un archivo válido, consigue que el sistema almacene el documento en el servidor asociado a su turno.
   * Dado que el Paciente se encuentra en la ventana de carga de comprobantes y adicionalmente los datos sensibles del centro (Alias y CBU) están expuestos temporalmente en la interfaz, cuando el usuario confirma la subida del archivo adjunto, entonces el sistema guarda el documento de manera exitosa, notifica a la Secretaria para su posterior validación y mantiene sin cambios el estado operativo del turno.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.3 | Generar Reporte Financiero
**Como** Profesional, **quiero** generar informes tabulares o gráficos de los ingresos percibidos filtrando por períodos mensuales y anuales, **para** evaluar el rendimiento económico de mis consultas en “Origen” y simplificar mi administración fiscal.
* **Valor:** 34 | **Prioridad:** 2 | **Estimación:** 24h
* **Validación:**
   * Comprobar que el sistema procesa única y exclusivamente los importes con estado financiero “Pagado”.
  * Comprobar que la interfaz ofrece filtros obligatorios para segmentar por mes y por año.
  * Verificar que cuando el Profesional aplica los filtros de fecha, consigue visualizar un resumen gráfico o tabular exacto de las transacciones correspondientes.
   * Dado que el Profesional está autenticado en su panel de control y adicionalmente existen importes con estado financiero “Pagado” para el período seleccionado, cuando solicita la generación del reporte, entonces el sistema procesa los datos en un tiempo menor a 2 segundos y renderiza la información de forma clara y legible.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.4 | Estado de Pago
**Como** Profesional o Secretaría, **quiero** visualizar y auditar de manera rápida el estado de pago (Pendiente, En revisión, Pagado o Rechazado) adjunto a cada turno, **para** validar los comprobantes cargados por los pacientes y detectar deudas o inconsistencias antes de la atención en el centro.
* **Valor:** 13 | **Prioridad:** 2 | **Estimación:** 12h
* **Validación:**
   * Comprobar que el sistema muestra los estados de pago Pendiente, En revisión, Pagado y Rechazado directamente en la vista general o de detalle del turno.
   * Comprobar que un turno con comprobante cargado figure en estado “En revisión” y que, al hacer clic sobre él, se permita la apertura y visualización del archivo PDF o imagen adjunta.
    * Verificar que cuando el Profesional o la Secretaría detectan un comprobante erróneo y rechazan la transacción, consiguen que el estado financiero pase a “Rechazado” y se habilite la opción de reclamo.
    * Dado que el Profesional o la Secretaría están revisando el listado de turnos diarios y adicionalmente un paciente ha cargado su comprobante de pago, cuando validan visualmente que el dinero se acreditó, entonces cambian el estado financiero de “En revisión” a “Pagado” y el sistema actualiza la base de datos de manera inmediata sin modificar el estado operativo.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.5 | Listar Pagos
**Como** Administrador, **quiero** acceder a un listado histórico y global de todas las transacciones y pagos registrados en el sistema “Origen”, **para** auditar los movimientos financieros generales, controlar los métodos de pago utilizados y asegurar que no haya desvíos de información.
* **Valor:** 8 | **Prioridad:** 2 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema restringe el acceso a este módulo global exclusivamente a usuarios con rol Administrador o Secretaria autorizada.
  * Comprobar que en el listado se visualicen de forma clara los campos de: Fecha, Pendiente, Profesional, Monto, Estado de Pago y Método Utilizado.
  * Verificar que cuando no existen registros de pago cargados en el sistema, consigue que la interfaz informe correctamente que no hay transacciones para mostrar.
  * Dado que el Administrador ha iniciado sesión con sus permisos correspondientes y adicionalmente existen movimientos financieros históricos guardados en la base de datos, cuando accede al módulo de lista de pagos, entonces el sistema recupera la información de forma ordenada y la muestra en la pantalla adaptativa en un tiempo inferior a los 2 segundos.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Núm: 7 | Iniciar Sesión Interno
**Como** Usuario Interno, **quiero** ingresar al sistema utilizando mis credenciales y un mecanismo de autenticación en dos pasos, **para** poder acceder de forma segura a las funcionalidades del sistema, protegiendo la información sensible y reduciendo el riesgo de accesos no autorizados.
*Usuario interno = Administrador, secretaria y Profesional*
* **Valor:** 21 | **Prioridad:** 5 | **Estimación:** 24 h
* **Validación:**
  * Comprobar que el sistema solicite usuario y contraseña válidos antes de permitir el acceso.
  * Comprobar que el sistema requiera obligatoriamente un segundo factor de autenticación para completar el inicio de sesión.
  * Comprobar que el acceso sea denegado cuando las credenciales ingresadas sean incorrectas.
  * Comprobar que el acceso sea denegado cuando el código de segundo factor sea inválido o haya expirado.
  * Demostrar que únicamente los usuarios internos con credenciales válidas y segundo factor verificado pueden acceder a las funcionalidades del sistema.
  * Verificar que cuando el Usuario Interno hace el ingreso de sus credenciales y completa correctamente el segundo factor de autenticación consigue acceder al sistema de acuerdo con los permisos asignados a su rol.
  * Verificar que cuando el Usuario Interno hace el ingreso de un código de segundo factor inválido o expirado consigue que el sistema rechace el acceso e informe el error correspondiente.
  * Dado que el Usuario Interno posee una cuenta activa y adicionalmente ha ingresado correctamente sus credenciales cuando completa satisfactoriamente el proceso de segundo factor de autenticación entonces el sistema concede el acceso y habilita las funcionalidades correspondientes a su rol.
* **HECHO POR:** Santiago Casali 

### HISTORIA DE USUARIO Núm: 8.1 | Iniciar Sesión con Google
**Como** Paciente, **quiero** acceder al sistema utilizando mi cuenta de Google, **para** poder ingresar de forma rápida y segura, evitando la necesidad de recordar credenciales adicionales.
* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema permita al paciente iniciar el proceso de autenticación utilizando una cuenta de Google válida.
  * Comprobar que el sistema obtenga y valide correctamente la identidad del paciente a través del proveedor de autenticación externo.
  * Comprobar que el acceso sea denegado cuando la autenticación con Google no pueda completarse satisfactoriamente.
  * Demostrar que, si no existe una cuenta con ese correo, el sistema crea una cuenta de Paciente en estado Pendiente de completar y permite el acceso sin habilitar la reserva de turnos.
  * Demostrar que, si ya existe una cuenta de Paciente con ese correo, el sistema no crea un duplicado y vincula Google con la ficha existente solo cuando el Paciente valida además DNI y fecha de nacimiento contra esa ficha.
  * Demostrar que, si la cuenta de Paciente completa los datos obligatorios de RF-02, el sistema la pasa a estado Activa y habilita la reserva de turnos.
  * Verificar que, si la comprobación de DNI o fecha de nacimiento no coincide con la ficha existente, el sistema no vincula Google ni crea un duplicado.
  * Verificar que, para una cuenta en estado Pendiente de completar, el sistema solo habilite la activación cuando el Paciente complete y valide los datos obligatorios definidos para Paciente en RF-02.
  * Demostrar que el paciente puede acceder al sistema sin necesidad de ingresar una contraseña propia de la plataforma.
  * Verificar que cuando el Paciente hace la autenticación mediante su cuenta de Google consigue acceder al sistema utilizando una identidad previamente validada.
  * Verificar que cuando el Paciente hace la cancelación o rechazo del proceso de autenticación en Google consigue que el sistema interrumpa el inicio de sesión sin conceder acceso.
  * Dado que el Paciente posee una cuenta de Google válida y adicionalmente autoriza el acceso solicitado por el sistema cuando selecciona la opción "Iniciar sesión con Google" entonces el sistema valida su identidad, recupera la información necesaria y concede el acceso correspondiente.
* **HECHO POR:** Santiago Casali (borrador)

### HISTORIA DE USUARIO Núm: 8.2 | Iniciar Sesión con Magic Link
**Como** Paciente, **quiero** acceder al sistema a través de un Magic Link enviado a mi correo electrónico, **para** poder iniciar sesión de forma rápida y segura sin necesidad de recordar una contraseña.
* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema permita al paciente solicitar un Magic Link utilizando un correo electrónico.
  * Comprobar que el Magic Link generado sea único, seguro y posea un tiempo de validez limitado.
  * Comprobar que el sistema envíe correctamente el Magic Link únicamente cuando exista una cuenta elegible asociada al correo ingresado.
  * Comprobar que el acceso sea denegado cuando el Magic Link haya expirado o ya haya sido utilizado.
  * Demostrar que el paciente puede acceder al sistema sin necesidad de ingresar una contraseña.
  * Demostrar que el sistema autentica correctamente al paciente cuando utiliza un Magic Link válido dentro del período de vigencia establecido.
  * Verificar que cuando el Paciente hace la solicitud de acceso mediante Magic Link recibe la respuesta visible: "Si el correo está registrado, recibirás un enlace de acceso."
  * Verificar que cuando el Paciente hace uso de un Magic Link válido consigue acceder al sistema sin necesidad de ingresar credenciales adicionales.
  * Verificar que cuando el Paciente hace uso de un Magic Link expirado o previamente utilizado consigue que el sistema rechace el acceso e informe el motivo correspondiente.
  * Dado que el Paciente posee una cuenta activa y adicionalmente ha solicitado un Magic Link válido cuando accede al enlace recibido dentro del período de vigencia establecido entonces el sistema valida su identidad y concede el acceso correspondiente a la plataforma.
  * Comprobar que el sistema no envíe Magic Links a correos electrónicos no registrados en la plataforma.
  * Comprobar que cada nueva solicitud de Magic Link invalide los enlaces previamente generados para la misma cuenta.
  * Demostrar que el paciente puede solicitar un nuevo Magic Link en caso de que el anterior haya expirado.
  * Verificar que cuando el Paciente hace una solicitud utilizando un correo electrónico no registrado consigue la misma respuesta visible: "Si el correo está registrado, recibirás un enlace de acceso."
  * Verificar que cuando el Paciente hace múltiples solicitudes consecutivas de Magic Link consigue que únicamente el enlace más reciente permanezca válido.
* **HECHO POR:** Santiago Casali (borrador)

### HISTORIA DE USUARIO Num: 1.2 | Baja paciente
**Como** Secretaria, **quiero** dar de baja a un paciente específico, **para** evitar que continúe realizando nuevas reservas y mantener actualizada la base de datos del centro de salud.
* **Valor:** 5 | **Prioridad:** 2 | **Estimación:** 8 h
* **Validación:**
  * Comprobar que la baja de un paciente se realice mediante una fecha de cierre o estado inactivo, sin eliminar su historial del sistema.
  * Comprobar que el sistema impida la baja cuando el paciente posea turnos futuros en estado Reservado o Confirmado.
  * Comprobar que el sistema solicite una confirmación previa antes de ejecutar la baja.
  * Demostrar que una vez dado de baja el paciente deja de poder solicitar nuevos turnos.
  * Verificar que cuando la Secretaria realiza la baja de un paciente consigue que el sistema marque correctamente el registro como inactivo.
  * Verificar que cuando la Secretaria intenta dar de baja un paciente con turnos futuros activos consigue que el sistema rechace la operación e informe el motivo correspondiente.
  * Dado que la Secretaria seleccionó un paciente activo y adicionalmente el paciente no posee turnos futuros pendientes, cuando confirma la operación de baja, entonces el sistema registra la fecha de cierre, inhabilita nuevas reservas y conserva toda la información histórica asociada.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 1.3 | Modificación paciente
**Como** Secretaria, **quiero** modificar los datos de un paciente registrado, **para** mantener actualizada su información personal y de contacto dentro del sistema.
* **Valor:** 8 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que el sistema permita editar los datos habilitados del paciente.
  * Comprobar que las validaciones de unicidad continúen aplicándose para DNI y correo electrónico.
  * Comprobar que el sistema valide el formato correcto del correo electrónico ingresado.
  * Demostrar que los cambios realizados sean almacenados correctamente en la base de datos.
  * Verificar que cuando la Secretaria modifica datos válidos de un paciente consigue que la información quede actualizada correctamente.
  * Verificar que cuando la Secretaria intenta ingresar un DNI o correo electrónico ya existente consigue que el sistema rechace la operación e informe el error correspondiente.
   * Verificar que cualquier cambio de correo de un paciente preserve el correo anterior como identidad principal hasta que el nuevo quede verificado.
   * Verificar que la Secretaría pueda iniciar cambios de correo únicamente para Pacientes y no para Profesionales, Administradores ni otras Secretarías.
  * Verificar que cuando la Secretaria modifica información obligatoria dejando campos vacíos consigue que el sistema impida guardar los cambios.
  * Dado que la Secretaria ha realizado modificaciones válidas sobre los datos de un paciente y adicionalmente la información cumple las reglas de validación definidas, cuando confirma la operación, entonces el sistema actualiza la información y registra la modificación correctamente.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 2.5.1 | Reservar turno (Paciente)
**Como** Paciente, **quiero** reservar un turno seleccionando un profesional, fecha y horario disponible, **para** asegurar mi turno de manera rápida y sin necesidad de asistencia administrativa.
* **Valor:** 21 | **Prioridad:** 5 | **Estimación:** 24 h
* **Validación:**
  * Comprobar que el sistema muestre únicamente horarios disponibles para la reserva.
  * Comprobar que el sistema muestre al paciente el límite de cancelación aplicable antes de confirmar la reserva.
  * Comprobar que el sistema muestre al paciente la política de multa y el porcentaje vigente, si corresponde, antes de confirmar la reserva.
  * Comprobar que un paciente no pueda reservar dos turnos superpuestos en el mismo horario.
  * Comprobar que el sistema impida reservar horarios ya ocupados por otro paciente.
  * Comprobar que el Paciente pueda reservar hasta las 23:59 horas del día D-1 para una cita del día D y que el sistema rechace reservas posteriores.
  * Comprobar que, si el Paciente posee una multa pendiente asociada al Profesional seleccionado, el sistema bloquee solo la nueva reserva autónoma con ese Profesional y mantenga habilitadas las reservas con otros Profesionales.
  * Comprobar que la multa pendiente no cancele ni modifique turnos existentes del Paciente con ese Profesional.
  * Comprobar que, al pagarse o perdonarse la multa, el Paciente recupere inmediatamente la posibilidad de reservar autónomamente con ese Profesional.
  * Demostrar que una vez confirmada la reserva el horario deja de estar disponible para nuevas solicitudes.
  * Comprobar que una reserva creada durante el día D-1 no dispare el flujo de confirmación por WhatsApp.
  * Comprobar que, para una reserva creada durante el día D-1, el estado inicial dependa del perfil: Solicitado si el profesional requiere aprobación manual y Confirmado si la aprobación es automática.
  * Verificar que cuando el Paciente selecciona un horario disponible consigue registrar correctamente la reserva.
  * Verificar que cuando el Paciente intenta reservar un horario ya ocupado consigue que el sistema rechace la operación e informe la indisponibilidad.
  * Verificar que cuando el Paciente posee un turno en el mismo horario consigue que el sistema impida la nueva reserva.
  * Dado que el Paciente selecciona un profesional, una fecha y un horario disponible y adicionalmente no posee conflictos de agenda, cuando confirma la reserva, entonces el sistema registra el turno con el estado inicial que corresponda según la fecha de la cita y la modalidad de aprobación del perfil profesional, y aplica el flujo de confirmación por WhatsApp solo cuando la reserva no fue creada en D-1.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 2.5.2 | Reservar turno (Secretaria)
**Como** Secretaria, **quiero** reservar un turno para un paciente registrado seleccionando el profesional, la fecha, el horario y el tipo de consulta, **para** asistir a los pacientes en la gestión de sus turnos cuando no puedan realizar la reserva por sus propios medios.
* **Valor:** 13 | **Prioridad:** 4 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que la Secretaria pueda seleccionar un paciente previamente registrado en el sistema.
  * Comprobar que el sistema muestre únicamente los horarios disponibles para el profesional seleccionado.
  * Comprobar que no sea posible reservar turnos en horarios ya ocupados.
  * Comprobar que la Secretaria pueda reservar hasta las 23:59 horas del día D-1 para una cita del día D y que el sistema rechace reservas posteriores.
  * Comprobar que el sistema impida registrar turnos superpuestos para un mismo paciente.
  * Comprobar que, si el Paciente posee una multa pendiente asociada al Profesional seleccionado, la Secretaria pueda crear excepcionalmente el turno dejando la excepción auditada.
  * Comprobar que esa multa pendiente no altere los turnos existentes del Paciente.
   * Comprobar que la Secretaria pueda asignar directamente un cupo liberado a un Paciente registrado, sin pasar por la cola de espera.
   * Comprobar que la asignación directa exija un motivo obligatorio y deje auditados actor, Paciente, Profesional, cupo y fecha/hora.
   * Comprobar que la asignación directa solo pueda realizarse hasta el inicio del turno, nunca después.
   * Comprobar que el turno creado por asignación directa nazca directamente en estado Confirmado.
   * Comprobar que la asignación directa no modifique la cola de espera ni consuma la prioridad de los Pacientes que permanecen en cola.
  * Demostrar que una vez confirmada la reserva el horario deja de estar disponible para futuras reservas.
  * Verificar que cuando la Secretaria selecciona correctamente un paciente, profesional y horario disponible consigue registrar el turno en el sistema.
  * Verificar que cuando la Secretaria intenta reservar un horario ya ocupado consigue que el sistema rechace la operación e informe la indisponibilidad.
  * Verificar que cuando la Secretaria intenta reservar un turno superpuesto para un paciente consigue que el sistema impida la operación.
  * Dado que la Secretaria seleccionó un paciente registrado y adicionalmente existe disponibilidad en la agenda del profesional, cuando confirma una reserva estándar, entonces el sistema registra el turno con el estado y flujo que correspondan según la fecha de la cita y la modalidad de aprobación del perfil profesional.
   * Dado que la Secretaria ejecuta una asignación directa de un cupo liberado con motivo obligatorio, cuando confirma la acción, entonces el sistema registra el turno directamente en estado Confirmado, audita la excepción y conserva el orden de la lista de espera.
   * Comprobar que la Secretaria deba marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario» para realizar una asignación directa, sin que el sistema solicite ni almacene evidencia, grabación, comprobante o canal del acuerdo.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 2.5.3 | Reservar turno (Profesional)
**Como** Profesional de la salud, **quiero** reservar un turno para uno de mis pacientes dentro de mi agenda, **para** coordinar futuras consultas y asegurar la continuidad del tratamiento o seguimiento profesional dentro del conjunto de pacientes ya vinculados a mi práctica.
* **Valor:** 13 | **Prioridad:** 4 | **Estimación:** 12 h
* **Validación:**
   * Comprobar que el Profesional solo pueda seleccionar pacientes que ya tengan o hayan tenido al menos un turno con ese Profesional.
   * Comprobar que el Profesional únicamente pueda reservar turnos dentro de su propia agenda.
  * Comprobar que el sistema muestre únicamente los horarios disponibles del profesional autenticado.
  * Comprobar que no sea posible reservar turnos en horarios previamente ocupados.
  * Comprobar que el Profesional pueda crear o reservar hasta las 23:59 horas del día D-1 para una cita del día D y que el sistema rechace reservas posteriores.
  * Comprobar que el sistema impida registrar turnos superpuestos para un mismo paciente.
   * Comprobar que, si el Paciente posee una multa pendiente asociada al Profesional autenticado, el Profesional pueda crear excepcionalmente el turno dejando la excepción auditada.
   * Comprobar que esa multa pendiente no cancele ni altere turnos existentes del Paciente.
   * Comprobar que el Profesional no pueda navegar ni listar la base global de Pacientes ni seleccionar pacientes fuera de su relación previa con ese Profesional.
    * Comprobar que el Profesional solo pueda asignar directamente un cupo liberado a Pacientes que ya tengan o hayan tenido al menos un turno con ese Profesional.
    * Comprobar que el Profesional deba marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario» para realizar una asignación directa, sin que el sistema solicite ni almacene evidencia, grabación, comprobante o canal del acuerdo.
    * Comprobar que la asignación directa exija un motivo obligatorio y deje auditados actor, Paciente, Profesional, cupo y fecha/hora.
    * Comprobar que la asignación directa solo pueda realizarse hasta el inicio del turno, nunca después.
    * Comprobar que el turno creado por asignación directa nazca directamente en estado Confirmado.
    * Comprobar que la asignación directa no modifique la cola de espera ni consuma la prioridad de los Pacientes que permanecen en cola.
    * Comprobar que, si el Paciente destinatario estaba inscripto en la lista de espera del Profesional, el sistema elimine únicamente esa inscripción al crearse el turno y registre la salida con el motivo «Cubierto por asignación directa».
  * Demostrar que una vez confirmada la reserva el horario seleccionado deja de estar disponible para futuras reservas.
   * Comprobar que un turno creado por Profesional antes de D-1 inicie en estado Reservado.
   * Comprobar que un turno creado por Profesional durante D-1 inicie directamente en estado Confirmado.
  * Comprobar que la capacidad del Profesional para crear turnos no se amplíe a otros estados sin una decisión explícita adicional.
  * Verificar que cuando el Profesional selecciona un paciente y un horario disponible consigue registrar correctamente el turno.
  * Verificar que cuando el Profesional intenta reservar un horario ya ocupado consigue que el sistema rechace la operación e informe el conflicto de agenda.
  * Verificar que cuando el Profesional intenta generar una reserva fuera de su propia agenda consigue que el sistema deniegue la operación.
   * Dado que el Profesional seleccionó un paciente registrado y adicionalmente existe disponibilidad en su agenda para el horario elegido, cuando confirma una reserva estándar, entonces el sistema registra el turno en estado Reservado si la creación ocurrió antes de D-1, o en estado Confirmado si ocurrió durante D-1, actualiza la disponibilidad y mantiene o omite el flujo de confirmación según corresponda.
   * Dado que el Profesional ejecuta una asignación directa de un cupo liberado con motivo obligatorio sobre un Paciente elegible, cuando confirma la acción, entonces el sistema registra el turno directamente en estado Confirmado, audita la excepción y conserva el orden de la lista de espera.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 2.7 | Aceptar turno (Profesional)
**Como** Profesional de la salud, **quiero** aceptar una solicitud de turno pendiente, **para** confirmar la disponibilidad de atención y notificar al paciente sobre la aprobación de la cita.
* **Valor:** 8 | **Prioridad:** 4 | **Estimación:** 8 h
* **Validación:**
  * Comprobar que únicamente los turnos en estado Solicitado puedan ser aceptados.
  * Comprobar que, para reservas anteriores a D-1, el sistema actualice el estado del turno a Reservado luego de la aceptación.
  * Comprobar que, para reservas creadas durante D-1, el sistema actualice el estado del turno directamente a Confirmado luego de la aceptación.
  * Comprobar que el sistema registre la fecha y hora de la aprobación profesional.
  * Demostrar que al aceptar un turno se genere automáticamente una notificación para el paciente solo cuando el flujo requiera confirmación posterior.
  * Verificar que cuando el Profesional acepta una solicitud pendiente consigue que el sistema reserve correctamente el turno.
  * Verificar que cuando el Profesional intenta aceptar un turno previamente cancelado consigue que el sistema rechace la operación.
  * Verificar que cuando el Profesional aprueba un turno consigue que el paciente reciba la notificación correspondiente solo si el flujo de turno la exige.
  * Dado que existe un turno en estado Solicitado y adicionalmente el Profesional posee permisos para gestionarlo, cuando selecciona la opción Aceptar Turno, entonces el sistema cambia el estado según la fecha de la cita: a Reservado si la reserva es anterior a D-1, o a Confirmado si fue creada durante D-1, y registra la operación.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 2.10 | Confirmar Asistencia al Turno
**Como** Paciente, **quiero** confirmar mi asistencia al turno mediante el mensaje recibido por WhatsApp, **para** mantener activa mi reserva y evitar que el turno sea cancelado automáticamente si no respondo dentro del plazo definido.
* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema envíe un primer mensaje de WhatsApp a las 08:00 horas del día D-2 solicitando confirmación.
  * Comprobar que el sistema envíe un segundo mensaje de WhatsApp a las 08:00 horas del día D-1 advirtiendo explícitamente que la falta de respuesta causará la cancelación.
  * Comprobar que el mensaje permita al paciente confirmar su asistencia de manera simple.
  * Comprobar que, cuando el paciente confirma su asistencia, el turno cambie al estado Confirmado.
  * Comprobar que, si el paciente no confirma antes de las 18:00 horas del día anterior al turno, el sistema cancele automáticamente la reserva y libere el horario.
  * Comprobar que esa cancelación automática por falta de confirmación no genere ni habilite multa.
  * Comprobar que toda cancelación realizada desde las 18:00 horas del día D-1 sobre un turno Confirmado se considere tardía.
  * Comprobar que la aplicación de una multa por cancelación tardía dependa de una decisión expresa del Profesional.
  * Comprobar que al cancelarse automáticamente el turno, el horario quede nuevamente disponible en la agenda.
  * Comprobar que los turnos creados o aprobados durante D-1 no utilicen este flujo de WhatsApp.
  * Verificar que cuando el Paciente confirma su asistencia mediante WhatsApp consigue que el sistema mantenga activa la reserva y actualice el estado del turno.
  * Verificar que cuando el Paciente no confirma su asistencia dentro del plazo establecido consigue que el sistema cancele automáticamente el turno e informe la disponibilidad del horario.
  * Dado que el Paciente posee un turno reservado y adicionalmente recibe el primer mensaje de confirmación por WhatsApp, cuando responde confirmando su asistencia dentro del plazo permitido, entonces el sistema cambia el estado del turno a Confirmado y conserva la reserva activa.
  * Dado que el Paciente posee un turno reservado y adicionalmente no confirma su asistencia antes de las 18:00 horas del día anterior al turno, cuando se ejecuta la rutina automática de cancelación, entonces el sistema cambia el estado del turno a Cancelado, libera el horario en la agenda y registra la operación correspondiente.
* **HECHO POR:** Lucca Giordana

---

## Pila de tareas (Product Backlog) - Sprint 0

| ID Tarea | Categoría | Descripción Técnica | Dependencia Asociada |
|---|---|---|---|
| T0.1 | DevOps y Git | **Inicialización del Repositorio Centralizado:** Crear el repositorio en GitHub para el proyecto “Origen”. Configurar las ramas principales (main, develop) y establecer reglas de protección para que no se suba código a producción sin que este haya sido revisado. | N/A |
| T0.2 | DevOps y Git | **Definición del Estándar de Ramas e Historial (Git Flow):** Acordar con el grupo de trabajo la nomenclatura de ramas de trabajo y las convenciones de mensajes de Commit, etc. | T0.1 |
| T0.3 | DevOps y Git | **Decisión para el stack tecnológico:** Acordar con el grupo de trabajo qué tecnologías se van a implementar para el desarrollo de los módulos del sistema (Frontend, Backend, BD, etc.). | N/A |
| T0.4 | Arquitectura | **Inicialización del Proyecto Backend:** Estructurar el framework elegido para el backend. Configurar las carpetas base en base a la arquitectura planteada e implementar el sistema de Logs de Auditoría requerido para las especificaciones (RF-23: registro inmutable del identificador de usuario, operación, fecha y hora del lado del servidor). | T0.3 |
| T0.5 | Arquitectura | **Inicialización del proyecto Frontend:** Crear el armazón del frontend. Instalar librerías de componentes UI (o desarrollarlos) que aseguren el cumplimiento del Requisito de Diseño Responsivo (RD-01) para resoluciones de monitores, tabletas y móviles. | T0.3 |
| T0.6 | Arquitectura | **Migración Inicial de la Base de Datos:** Escribir los scripts de migración (DDL) para crear físicamente las tablas e índices analizados en sus modelos de datos (incluyendo estados financieros de consultas). | T0.3 |
| T0.7 | Interfaces | **Sandbox de Google Cloud Platform para Google Auth:** Registrar el proyecto en la consola de Google Cloud Developer. Configurar las credenciales OAuth 2.0 necesarias para dar soporte al inicio de sesión Passwordless sin contraseñas tradicionales para pacientes y secretarias (RF-01, RIE-02). | T0.4 |
| T0.8 | Interfaces | **Entorno de Pruebas para API de WhatsApp Business:** Configurar la cuenta de desarrollo en Meta for Developers para interactuar con la API de WhatsApp. Estructurar los primeros Webhooks o llamadas Mock para el envío de dos recordatorios automáticos a las 08:00 horas del día D-2 y del día D-1, con advertencia explícita de cancelación ante falta de respuesta (RF-17, RIE-01). | T0.4 |
| T0.9 | Metodología | **Puesta a punto de la Herramienta de Gestión (Jira / Trello):** Cargar todas las historias de usuario del backlog (módulos 1, 2, 3, 4 y 5) en el tablero ágil. Configurar las columnas del flujo de trabajo (Ej: To Do, In Progress, Code Review, Testing, Done). | N/A |
| T0.10 | Metodología | **Definición de “Definition of Done” (DoD):** Pactar el criterio unificado de cuándo una tarea está realmente terminada. Por ejemplo: “Código subido a develop + pasa pruebas de validación con los escenarios Dado que/Cuando/Entonces escritos + renderiza en menos de 2 segundos según Rend-02.” | N/A |

Este Sprint asegura que las bases de datos locales queden exactamente en el mismo estado maduro que expone nuestro Diagrama Entidad-Relación de la sección de Apéndices.

**Entorno de Trabajo y Repositorio (DevOps y Git)**
*   **Tarea 0.1: Inicialización del Repositorio Centralizado**
    Descripción: Crear el repositorio en GitHub para el proyecto “Origen”. Configurar las ramas principales (main, develop) y establecer reglas de protección para que no se suba código a producción sin que este haya sido revisado.
*   **Tarea 0.2: Definición del Estándar de Ramas e Historial (Git Flow)**
    Descripción: Acordar con el grupo de trabajo la nomenclatura de ramas de trabajo y las convenciones de mensajes de Commit, etc.
*   **Tarea 0.3: Decisión para el stack tecnológico**
    Descripción: Acordar con el grupo de trabajo qué tecnologías se van a implementar para el desarrollo de los módulos del sistema (Frontend, Backend, BD, etc).

**Preparación de la Arquitectura de Software (Backend y Frontend)**
*   **Tarea 0.4: Inicialización del Proyecto Backend**
    Descripción: Estructurar el framework elegido para el backend. Configurar las carpetas base en base a la arquitectura planteada e implementar el sistema de Logs de Auditoría requerido para las especificaciones (RF-23: registro inmutable del identificador de usuario, operación, fecha y hora del lado del servidor).
*   **Tarea 0.5: Inicialización del proyecto Frontend**
    Descripción: Crear el armazón del frontend. Instalar librerías de componentes UI (o desarrollarlos) que aseguren el cumplimiento del Requisito de Diseño Responsivo (RD-01) para resoluciones de monitores, tabletas y móviles.
*   **Tarea 0.6: Migración Inicial de la Base de Datos**
    Descripción: Escribir los scripts de migración (DDL) para crear físicamente las tablas e índices analizados en sus modelos de datos (incluyendo estados financieros de consultas).

**Configuraciones y Conexiones Externas (Interfaces Externas)**
*   **Tarea 0.7: Sandbox de Google Cloud Platform para Google Auth**
    Descripción: Registrar el proyecto en la consola de Google Cloud Developer. Configurar las credenciales OAuth 2.0 necesarias para dar soporte al inicio de sesión Passwordless sin contraseñas tradicionales para pacientes y secretarias (RF-01, RIE-02).
*   **Tarea 0.8: Entorno de Pruebas para API de WhatsApp Business**
    Descripción: Configurar la cuenta de desarrollo en Meta for Developers para interactuar con la API de WhatsApp. Estructurar los primeros Webhooks o llamadas Mock para el envío de dos recordatorios automáticos a las 08:00 horas del día D-2 y del día D-1, con advertencia explícita de cancelación ante falta de respuesta (RF-17, RIE-01).

**Calidad y Metodología (Aseguramiento del Proceso Scrum)**
*   **Tarea 0.9: Puesta a punto de la Herramienta de Gestión (Jira / Trello)**
    Descripción: Cargar todas las historias de usuario del backlog (módulos 1, 2, 3, 4 y 5) en el tablero ágil. Configurar las columnas del flujo de trabajo (Ej: To Do, In Progress, Code Review, Testing, Done).
*   **Tarea 0.10: Definición de “Definition of Done” (DoD)**
    Descripción: Pactar el criterio unificado de cuándo una tarea está realmente terminada. Por ejemplo: “Código subido a develop + pasa pruebas de validación con los escenarios Dado que/Cuando/Entonces escritos + renderiza en menos de 2 segundos según Rend-02.”

---

## Pila de tareas (Product Backlog) - Sprint 1

| ID Tarea | Categoría | Descripción Técnica | Dependencia Asociada |
|---|---|---|---|
| T1.1 | Autenticación | Login Interno con Segundo Factor de Autenticación (HU 7) | T0.4, T0.7 |
| T1.2 | Gestión de Pacientes | Alta de Paciente (HU 1.1) | T1.1, T0.6 |
| T1.3 | Gestión de Profesionales | Alta de Profesional (HU 4.2) | T1.1, T0.6 |
| T1.4 | Gestión de Profesionales | Listar Profesionales (HU 4.1) | T1.3 |
| T1.5 | Configuración de Agenda | Editar Disponibilidad del Profesional (HU 3.2) | T1.3, T0.6 |
| T1.6 | Gestión de Turnos | Visualizar Turnos del Profesional (HU 2.1) | T1.5, T1.2 |
| T1.7 | Gestión de Turnos | Crear Turno por Profesional (HU 2.2 / 2.5.3) | T1.6, T1.2 |
| T1.8 | Interfaces Externas | Mock de Notificación WhatsApp Post-Creación (RF-17 parcial) | T1.7, T0.8 |
| T1.9 | Calidad y Metodología | Tests E2E del Flujo Crítico | Todas |
| T1.10 | Metodología | Puesta a Punto de Definition of Done (DoD) | N/A |

### Autenticación
**Tarea T1.1: Login Interno con Segundo Factor de Autenticación (HU 7)**
* **Descripción:** Implementar el flujo de autenticación para usuarios internos del sistema (Administrador, Profesional y Secretaría). El mecanismo deberá validar credenciales tradicionales (usuario y contraseña) y aplicar segundo factor de autenticación (2FA) válido para los tres roles internos. El sistema deberá rechazar accesos con credenciales inválidas y códigos incorrectos o expirados, y garantizar el cierre automático de sesión al vencer el período configurado de autenticación. La implementación deberá integrarse con el Sandbox de Google Cloud Platform configurado durante el Sprint 0 (T0.7), permitiendo la validación de códigos temporales mediante TOTP. Esta tarea completa la implementación del requisito funcional RF-01 para usuarios internos.
* **Estimación:** 24 horas

### Gestión de Pacientes
**Tarea T1.2: Alta de Paciente (HU 1.1)**
* **Descripción:** Crear el endpoint POST /pacientes y la interfaz de registro correspondiente. Implementar validaciones obligatorias para: Nombre, Apellido, DNI, Fecha de nacimiento, Teléfono celular y Correo electrónico; el género y la obra social deberán permanecer opcionales. El sistema deberá garantizar la unicidad de DNI y correo electrónico, validar el formato del email y rechazar solicitudes que no cumplan las reglas definidas. Una vez completado correctamente el registro, el paciente deberá persistirse en la base de datos junto con su fecha de creación y quedar habilitado para futuras reservas de turnos. Esta tarea cubre completamente la Historia de Usuario 1.1 y satisface parcialmente el requisito RF-02.
* **Estimación:** 12 horas

### Gestión de Profesionales
**Tarea T1.3: Alta de Profesional (HU 4.2)**
* **Descripción:** Crear el endpoint POST /profesionales y la pantalla administrativa para registrar profesionales. Validar los campos: Nombre, Apellido, DNI y Correo electrónico como obligatorios y únicos dentro del sistema. El género y la fecha de nacimiento no deberán solicitarse para este rol. El campo teléfono será opcional. Al registrarse, el profesional deberá quedar con estado Pendiente de Validación y el sistema deberá generar una invitación para completar la activación de la cuenta mediante correo electrónico o teléfono. Esta tarea implementa la Historia de Usuario 4.2 y contribuye al cumplimiento de RF-03 y RF-04.
* **Estimación:** 16 horas

**Tarea T1.4: Listar Profesionales (HU 4.1)**
* **Descripción:** Crear el endpoint GET /profesionales con soporte para paginación server-side. El listado deberá mostrar únicamente profesionales activos (sin fecha de cierre), permitir búsquedas por nombre y apellido, y aplicar filtros básicos definidos por negocio. El tiempo máximo de respuesta deberá mantenerse por debajo de 2 segundos según Rend-02. Esta tarea cubre la Historia de Usuario 4.1.
* **Estimación:** 12 horas

### Configuración de Agenda
**Tarea T1.5: Editar Disponibilidad del Profesional (HU 3.2)**
* **Descripción:** Implementar el módulo que permita a los profesionales: Configurar horarios regulares de atención. Registrar ausencias. Bloquear días feriados. Definir la ventana temporal disponible para reservas futuras. Cuando la operación afecte turnos futuros activos, el sistema deberá detectar y mostrar todos los conflictos, impedir el guardado mientras existan turnos alcanzados y conservar intactos esos turnos hasta que sean reprogramados o cancelados uno por uno mediante los flujos ya definidos. Una vez aplicada la modificación sin conflictos, la disponibilidad deberá reflejarse inmediatamente en el calendario utilizado por los pacientes. Esta tarea implementa la Historia de Usuario 3.2 y el requisito RF-07.
* **Estimación:** 24 horas

### Gestión de Turnos
**Tarea T1.6: Visualizar Turnos del Profesional (HU 2.1)**
* **Descripción:** Crear el endpoint GET /turnos/hoy que retorne los turnos asignados al profesional autenticado para la fecha actual. La vista deberá mostrar: Horario, Nombre del paciente, Tipo de consulta, Estado actual. Los turnos en estado Solicitado deberán resaltarse visualmente como pendientes de aprobación profesional. El estado Reservado indica que el turno fue aprobado y está pendiente de confirmación de asistencia del paciente; el estado Confirmado indica que la asistencia fue confirmada por el paciente. Al finalizar el horario previsto de un turno, la interfaz de cierre deberá presentar "Asistió" preseleccionado como opción predeterminada, pero requerirá confirmación expresa del actor antes de registrar el cierre. Si no existen turnos para la fecha solicitada, el sistema deberá informar la situación mediante un mensaje adecuado. Esta tarea cubre completamente la Historia de Usuario 2.1.
* **Validación adicional:**
  * Comprobar que el profesional pueda registrar "No asistió" únicamente sobre turnos cuyo horario previsto ya finalizó.
  * Comprobar que el registro de "No asistió" quede auditado con actor, fecha y hora.
  * Comprobar que, al registrar "No asistió", el sistema no aplique multa de forma automática y deje la decisión explícita de multa para el Profesional.
* **Estimación:** 24 horas

**Tarea T1.7: Crear Turno por Profesional (HU 2.2 / 2.5.3)**
 * **Descripción:** Crear el endpoint POST /turnos para permitir que los profesionales registren manualmente nuevos turnos. El sistema deberá validar: Disponibilidad del horario. Ausencia de superposición de turnos. Que el paciente no posea otro turno en el mismo horario. Que el profesional únicamente opere sobre su propia agenda. Al completarse correctamente la operación, el turno deberá crearse en estado Reservado si la creación ocurre antes de D-1, o en estado Confirmado si ocurre durante D-1; en el primer caso deberá mantener el flujo de confirmación definido por RF-10 y RF-17, y en el segundo no deberá usarlo. Hasta la implementación de Tipos de Consulta en Sprint 2, se asumirá una duración fija de 30 minutos por turno. Esta tarea cubre parcialmente las Historias de Usuario 2.2 y 2.5.3.
* **Estimación:** 12 horas

### Interfaces Externas
**Tarea T1.8: Mock de Notificación WhatsApp Post-Creación (RF-17 parcial)**
 * **Descripción:** Implementar el envío de notificaciones automáticas utilizando el entorno de pruebas de WhatsApp Business configurado durante el Sprint 0. La notificación deberá enviarse automáticamente según el calendario definido por RF-17 y contener: Profesional asignado. Fecha. Horario. Consultorio. Los mensajes se registrarán únicamente en el entorno de pruebas hasta validar la estabilidad completa del flujo. Esta tarea implementa parcialmente RF-17 y acompaña el flujo de aprobación o reserva solo para turnos que no fueron creados o aprobados durante D-1. No aplica a turnos creados por Profesional durante D-1, que nacen Confirmado y omiten WhatsApp.
* **Estimación:** 8 horas

### Calidad y Metodología
**Tarea T1.9: Tests E2E del Flujo Crítico**
* **Descripción:** Automatizar los escenarios funcionales correspondientes a las historias implementadas en este sprint. La cobertura mínima deberá incluir: Alta de paciente. Alta de profesional. Listado de profesionales. Configuración de disponibilidad. Creación de turnos. Visualización de turnos pendientes de aprobación. Notificación automática. Además, deberán contemplarse los casos de error más relevantes: DNI duplicado. Email duplicado. Conflicto de agenda. Turnos simultáneos para un mismo paciente. Los tests deberán ejecutarse automáticamente en el pipeline de integración continua.
* **Estimación:** 12 horas

### Metodología
**Tarea T1.10: Puesta a Punto de Definition of Done (DoD)**
* **Descripción:** Crear la plantilla de Pull Request del proyecto, configurar GitHub Actions para la ejecución automática de linting y pruebas, y documentar el flujo de trabajo oficial del repositorio. La documentación deberá incluir: Creación de ramas. Convenciones de commits. Pull Requests. Code Reviews. Proceso de merge a develop. Esta tarea consolida la Definition of Done acordada durante el Sprint 0.
* **Estimación:** 4 horas

---

## Resumen del Sprint
Este Sprint entrega el primer flujo funcional completo del sistema Origen: un administrador registra profesionales, los profesionales se autentican, configuran su disponibilidad, consultan su agenda diaria, gestionan solicitudes de turno y crean turnos para pacientes con notificación automática mediante WhatsApp (entorno de pruebas).
Carga total estimada: 148 horas.

| Integrante | Tareas | Horas |
|---|---|---|
| Santiago Casali | T1.1, T1.3 | 40 h |
| Lucca Giordana | T1.2, T1.4 | 24 h |
| Said Quioto | T1.5, T1.6, T1.7 | 60 h |
| Samuel Olmos | T1.8, T1.9 | 20 h |
| Equipo completo | T1.10 | 4 h |
| **Total** | — | **148 h** |

**Cadena crítica del demo:** T1.5 → T1.6 → T1.7 → T1.8.

---

## Pantallas 
* Paciente
* Reserva de turno
* Turnos próximos
* Historial de turnos
* Detalle del turno
* Confirmar reserva de turno
* Home del paciente
* Profesional
* Calendario profesional
* Home del profesional
* Detalle del turno
* Disponibilidad
* Reporte financiero
* Tipos de consulta
* Secretaría
* Agenda general
* Home secretaria
* Detalle de pago
* Gestión de pacientes
* Gestión pagos
* Inicio de sesión y creación de cuenta

---

## Aplicada II
### Documentación de Configuración de Entorno en GitHub

**1. Estructura de la Organización**
Se ha creado la organización Team-Origen en GitHub para centralizar el desarrollo del Sistema de Gestión de Turnos "Origen". Este espacio permite una gestión unificada de permisos, repositorios y tableros de proyectos para todo el equipo.
Se ha configurado un perfil público para la organización, incluyendo una descripción clara del proyecto y sus objetivos principales (gestión de turnos, agendas profesionales y comunicación con pacientes).

**1.1. Repositorios Creados**
Se han establecido tres repositorios públicos dentro de la organización:
* **origen-api:** Repositorio destinado al desarrollo del backend (API) del sistema.
* **origen-web:** Repositorio destinado al desarrollo del frontend (aplicación web) del sistema.
* **.github:** Repositorio especial utilizado para la personalización de la organización. Contiene el archivo README.md que se visualiza en la página principal del perfil de Team-Origen.

**2. Flujo de Trabajo y Políticas de Desarrollo**
Para garantizar la calidad del código, proteger el historial del proyecto y mantener un flujo de trabajo ordenado, se han implementado políticas a nivel de organización.

**2.1. Implementación de Rulesets (Políticas Organizacionales)**
En lugar de utilizar las reglas clásicas por repositorio (Branch Protection Rules), se optó por implementar Rulesets. Esta decisión técnica se tomó porque:
* Permite aplicar las mismas reglas de forma centralizada y simultánea a todos los repositorios de desarrollo (origen-api y origen-web).
* Facilita la escalabilidad en caso de agregar nuevos repositorios en el futuro.
* Proporciona un control más granular sobre quién puede eludir las reglas (Bypass list).

**2.2. Reglas Configuradas**
Se han creado Rulesets específicos para proteger las ramas principales (main y develop), aplicando las siguientes restricciones:
* **Protección contra eliminación (Restrict deletions):** Las ramas main y develop están protegidas; ningún miembro del equipo puede eliminarlas accidental o intencionalmente.
* **Integración mediante Pull Requests (Require a pull request before merging):** Queda estrictamente prohibido hacer commit directamente (push) a las ramas main o develop. Todo código nuevo debe desarrollarse en ramas secundarias (ej. feature/*) y fusionarse únicamente a través de un Pull Request.
* **Revisión de Código Obligatoria:** Para que un Pull Request pueda ser fusionado (merged), requiere la revisión y aprobación de al menos otro miembro del equipo distinto al autor.
* **Protección del Historial (Block force pushes):** Se prohíben los force pushes hacia las ramas protegidas para evitar la reescritura del historial de commits, asegurando la trazabilidad del trabajo del equipo.
* **Excepciones controladas:** Se ha configurado una lista de excepciones (Bypass list) permitiendo únicamente a los administradores de la organización eludir estas reglas en situaciones críticas.

**3. Gestión de Tareas (Kanban)**
Se ha creado un proyecto tipo Kanban denominado "Origen Development" a nivel de organización para gestionar el trabajo de los repositorios.
* Flujo del tablero: New → In Progress → On Review → Done.
* Política de control de calidad: Un desarrollador no puede mover su propio Issue de la columna On Review a Done. Este movimiento debe ser realizado por el compañero de equipo responsable de aprobar el Pull Request asociado, validando así la finalización de la tarea.

https://github.com/Team-Origen
