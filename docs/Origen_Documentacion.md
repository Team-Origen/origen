# ORIGEN - CENTRO DE SALUD

## INFORME DE DECISIONES DE ARQUITECTURA DE SOFTWARE
### SISTEMA DE GESTIÓN DE TURNOS

**HECHO POR:** CASALI | GIORDANA | OLMOS | QUIOTO

---

## 1. Introducción
### 1.1. Propósito
El propósito de este documento es definir los requisitos funcionales y no funcionales para el sistema de gestión de turnos "Origen". Está dirigido a los desarrolladores, al equipo de pruebas y a los interesados del centro de salud.

### 1.2. Ámbito del sistema
El sistema, denominado "Origen", es una plataforma web diseñada para la gestión operativa y administrativa de turnos, comunicación con pacientes vía WhatsApp y administración financiera básica. No procesa, cobra, transfiere ni devuelve dinero real: los pagos, multas, saldos a favor, compensaciones y devoluciones externas son registros administrativos declarados por usuarios autorizados.
* **Lo que hará:** Permitir la reserva de turnos, gestión de agendas profesionales, envío de notificaciones automáticas, registro de auditoría y consulta de historial operativo de turnos.
* **Lo que no hará:** No almacenará ni mostrará historia clínica, seguimiento clínico, indicaciones clínicas, diagnósticos, observaciones profesionales ni notas clínicas. No integrará pasarelas de pago ni bancos; los comprobantes serán evidencia para validación manual, no confirmación bancaria automática, y los reportes no serán factura, recibo fiscal, contabilidad legal ni conciliación bancaria.

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
* El sistema deberá implementar mecanismos de seguridad y control de acceso acordes a cada rol de usuario, incluyendo la protección criptográfica obligatoria de los datos actuales y de los módulos futuros que almacenen información sensible.

### 2.5. Suposiciones y dependencias
Se asume que los usuarios finales disponen de una conexión a internet estable y una cuenta activa de WhatsApp para recibir notificaciones. El sistema depende de la disponibilidad operativa de la API de WhatsApp y de los servicios de Google Auth.

### 2.6. Requisitos futuros
Como evolución funcional futura, se contempla la incorporación de un módulo de registro de notas profesionales cifradas, destinado al almacenamiento privado de observaciones individuales realizadas por cada profesional. Esta funcionalidad no forma parte del alcance de la versión actual del sistema, pero ha sido acordada como una extensión posterior con el cliente.

La estrategia de backups y recuperación no bloquea el desarrollo, prototipo ni demo sin datos reales y no forma parte del Sprint 1 actual. Será obligatoria antes de producción o de almacenar datos reales de Pacientes.

La política de solicitud de eliminación o anonimización y de conservación obligatoria de datos personales de Pacientes queda pendiente de validación legal. La retención del log de auditoría también queda pendiente de validación legal y contable y de aprobación del cliente; provisionalmente no habrá eliminación automática del log. Antes de producción, el cliente deberá aprobar qué datos se eliminan, anonimizan o conservan y durante cuánto tiempo, así como el plazo y la conducta de conservación o eliminación del log considerando los datos personales, la seguridad y los registros financieros. Hasta esas aprobaciones no habrá borrado ni anonimización automática de datos personales ni eliminación automática del log, y la salida a producción quedará bloqueada.

---

## 3. Requisitos Específicos
### 3.1. Interfaces externas
* **RIE-01:** Interfaz con API de WhatsApp para envío de recordatorios.
* **RIE-02:** Interfaz de autenticación con Google (Gmail).

### 3.2. Funciones

#### 3.2.1 Gestión de Usuarios y Roles
* **RF-01: Autenticación Mixta y Control de Acceso:** El sistema deberá implementar un mecanismo de acceso diferenciado por rol. Para el rol Paciente, soportará un inicio de sesión Passwordless (Google OAuth y Magic Link). En el flujo de Google OAuth, la autenticación verificará la identidad y el correo del Paciente; si no existe una cuenta con ese correo, el sistema creará una cuenta en estado **Pendiente de completar**, permitirá el acceso y bloqueará la reserva de turnos hasta que el Paciente complete y valide los datos obligatorios de RF-02. Si ya existe una cuenta de Paciente con ese correo, el sistema no deberá crear un duplicado y deberá iniciar la vinculación de Google con esa ficha existente; para completar esa vinculación, el Paciente deberá validar además su DNI y fecha de nacimiento contra la ficha existente. Si la comprobación no coincide, no deberá producirse la vinculación ni la creación de un duplicado. Las sesiones de Paciente se regirán por RNF-10. Google OAuth será exclusivo de Pacientes y no proveerá el segundo factor de los Usuarios Internos. El primer Administrador deberá provisionarse mediante un proceso único de despliegue, sin credenciales predeterminadas, y recibirá una invitación de un solo uso para definir su contraseña y enrolar TOTP; solo entonces quedará Activo. Luego, un Administrador podrá crear cuentas de Profesional o Secretaría en estado **Pendiente de activación**; su invitación de un solo uso deberá permitir definir contraseña y enrolar TOTP, y la cuenta solo pasará a **Activa** al completar ambos pasos. El acceso de los Usuarios Internos requerirá una cuenta Activa, credenciales tradicionales (correo y contraseña) y TOTP válido para Administrador, Profesional y Secretaría. En cada nueva sesión deberán ingresar la contraseña; en un dispositivo declarado confiable, el segundo factor podrá recordarse hasta 30 días, sin dejar de ser obligatorio. El sistema deberá requerir nuevamente el 2FA al vencer ese plazo, usarse un dispositivo nuevo, cambiarse el correo, la contraseña o la configuración de 2FA, o detectarse actividad sospechosa. El flujo Magic Link no deberá modificarse.
* **RF-02: Registro:** El sistema deberá requerir, de manera obligatoria durante el proceso de registro, la captura y validación de los siguientes campos según el rol: para Paciente, Nombres, Apellidos, Documento Nacional de Identidad, Fecha de Nacimiento, Número de Teléfono Celular y Correo Electrónico; para Profesional, Nombres, Apellidos, Documento Nacional de Identidad y Correo Electrónico. El género será opcional en ambos casos. El DNI y el correo electrónico deberán ser únicos en ambos roles. El teléfono obligatorio del Paciente deberá iniciar como no verificado y solo pasará a verificado al validar un código enviado a ese número. Una cuenta de Paciente con teléfono no verificado no podrá realizar reservas autónomas. Secretaría podrá registrar al Paciente y crear o asignar sus turnos aunque el teléfono no esté verificado; el Profesional solo podrá operar dentro de sus permisos existentes, sin ampliarlos por esta regla. El sistema deberá mostrar una advertencia clara a los roles internos cuando el teléfono del Paciente no esté verificado. Para las cuentas de Paciente creadas por Google OAuth en estado **Pendiente de completar**, la activación a estado **Activa** deberá producirse únicamente cuando dichos datos obligatorios queden completos y validados, incluido el teléfono verificado. El Paciente o Secretaría podrán iniciar un cambio posterior del teléfono. Al iniciarlo, el sistema deberá suspender inmediatamente las automatizaciones y WhatsApp al número anterior; el nuevo número permanecerá no verificado, no recibirá mensajes ni habilitará reservas autónomas hasta validar un código enviado a ese número. Mientras la validación esté pendiente, los turnos próximos deberán quedar señalados para contacto o revisión manual de Profesional y Secretaría. Al validar el código, el sistema deberá activar el nuevo número, WhatsApp y la autogestión del Paciente.
* **RF-03: Recuperación:** El sistema deberá permitir al rol Administrador iniciar la modificación de las direcciones de correo electrónico de los usuarios mediante un flujo de verificación previo. El nuevo correo no deberá quedar activo hasta que sea verificado; mientras tanto, el correo anterior seguirá siendo la identidad principal. El sistema deberá notificar el intento a los canales anteriores disponibles y auditar el inicio, la verificación, la activación y cualquier fallo del proceso.
* **RF-04: Roles:** El sistema deberá implementar un control de acceso basado en roles, definiendo y segmentando jerárquicamente los siguientes niveles de acceso: Administrador, Profesional, Secretaría y Paciente. El primer Administrador se incorporará exclusivamente mediante el proceso único de despliegue definido en RF-01. Un Administrador podrá crear cuentas de Profesional y Secretaría, que permanecerán en **Pendiente de activación** hasta que completen la definición de contraseña y el enrolamiento TOTP mediante su invitación de un solo uso; solo entonces quedarán **Activas**.
* **RF-05: Aislamiento de datos:** El sistema deberá restringir la visualización de la información a nivel de base de datos e interfaz, garantizando que el rol Profesional únicamente pueda ver pacientes que tengan o hayan tenido al menos un turno con ese Profesional, y que solo acceda a los registros operativos de turnos vinculados a su propia relación con cada Paciente. El Profesional no deberá poder navegar, listar ni consultar la base global de Pacientes ni ver información de relaciones con otros Profesionales.
* **RF-06: Privacidad Secretaría:** El sistema deberá permitir al rol Secretaría el acceso de lectura y escritura a los datos generales y de contacto de los pacientes, incluyendo la posibilidad de iniciar cambios de correo y de teléfono de Pacientes, pero deberá denegar el acceso a información sensible no relacionada con la gestión de turnos y no otorgar permisos para modificar correos de Profesional, Administrador u otra Secretaría. La Secretaría sí podrá listar y buscar a todos los Pacientes del centro para gestión operativa.

#### 3.2.2 Configuración de Agenda
* **RF-07: Disponibilidad:** El sistema deberá proporcionar un módulo de configuración que permita establecer y modificar horarios de atención regulares, registrar ausencias, bloquear días feriados y definir la ventana de tiempo (rango de meses o días) disponible para la reserva futura de turnos. Cuando una modificación de disponibilidad, una ausencia o un bloqueo afecte turnos futuros activos, el sistema deberá detectar y mostrar todos los turnos alcanzados por el conflicto, impedir el guardado mientras existan conflictos y mantener sin cambios esos turnos hasta que cada uno sea reprogramado o cancelado individualmente por los flujos ya definidos. El sistema no deberá mover, cancelar ni modificar automáticamente ningún turno afectado.
* **RF-08: Consultas:** El sistema deberá permitir la creación de distintos tipos de consulta, exigiendo para el registro de cada una la definición de un tiempo de duración estimado y un valor monetario base. Al crear un turno, el sistema deberá conservar como valores propios de ese turno el nombre del tipo de consulta, su duración y su precio base vigentes en ese momento.
* **RF-09: Edición de Precios y Multa Asociada:** El sistema deberá otorgar la capacidad de modificar de manera individual el valor monetario de un turno específico, permitiendo la aplicación de excepciones o descuentos sobre el precio estándar de la consulta. Para un turno existente no Pagado, una reducción o descuento podrá aplicarse directamente, deberá notificarse al Paciente y quedará auditada. Para ese mismo estado financiero, un aumento deberá tratarse como una propuesta que requiere aceptación expresa del Paciente; mientras no acepte, seguirá vigente el precio anterior. Si el Paciente rechaza el aumento, se conservará el precio anterior y el turno no se cancelará automáticamente. Si el Profesional decide no mantener el precio anterior, podrá cancelar manualmente el turno con motivo auditado, sin multa para el Paciente. Una vez que el estado financiero sea Pagado, el precio no podrá editarse. La multa por cancelación tardía deberá permanecer desactivada por defecto para cada Profesional. Si el Profesional la activa, deberá configurar un porcentaje entero entre 1 % y 100 % sobre el precio efectivo del turno. Cuando exista una multa por cancelación tardía, su importe deberá calcularse a partir del precio efectivo del turno y del porcentaje de multa vigente configurado por el Profesional. Un cambio posterior de configuración deberá afectar únicamente a las cancelaciones futuras y no recalcular ni modificar multas ya determinadas. La edición posterior de un tipo de consulta no deberá alterar retroactivamente los turnos ya creados; solo deberá afectar a los turnos nuevos.
* **RF-10: Aprobación:** El sistema deberá proveer una opción de configuración a nivel de perfil profesional que permita definir la modalidad de aprobación de los turnos solicitados, alternando entre un flujo de aprobación manual y un flujo de aprobación automática. En el flujo manual, la solicitud del paciente inicia en estado Solicitado; en el flujo automático, inicia en estado Reservado. Para reservas creadas durante el día D-1, la aprobación manual lleva la solicitud directamente a Confirmado y la aprobación automática genera Confirmado desde el inicio. La reserva estándar creada por Secretaría nunca pasará por Solicitado ni dependerá de la modalidad de aprobación del Profesional: antes de D-1, Secretaría deberá elegir explícitamente crearla en estado Reservado, sujeto al flujo posterior de confirmación por WhatsApp, o en estado Confirmado, porque el horario ya fue acordado con el Paciente; durante D-1, solo podrá crearla en estado Confirmado. Para todo turno estándar que Secretaría cree como Confirmado, especialmente durante D-1, deberá registrar una declaración simple de que el Paciente aceptó el horario, sin almacenar evidencia, grabación, comprobante ni canal del acuerdo. En turnos creados por Profesional, si la creación ocurre antes de D-1 el turno nace en estado Reservado y continúa el flujo de confirmación por WhatsApp; si ocurre durante D-1, el turno nace directamente en estado Confirmado y no usa confirmación por WhatsApp. Esta regla no amplía la selección de Pacientes ni modifica los permisos del Profesional. La reserva pública o autónoma para una cita del día D cerrará a las 23:59 horas del día D-1. Son excepciones controladas a este corte: la lista de espera operada en modo Manual para un cupo liberado el mismo día D, sin exposición pública ni habilitación de reserva autónoma; y la asignación directa interna de un cupo por Secretaría o Profesional, que podrá ejecutarse hasta el inicio del turno. Ninguna de estas excepciones habilita reserva pública autónoma ni modifica los permisos vigentes.
* **RF-10 bis: Cancelación voluntaria del paciente:** El sistema deberá permitir configurar por perfil profesional el plazo de cancelación voluntaria del paciente. La configuración predeterminada deberá habilitar la cancelación hasta las 23:59 del día D-1. La configuración personalizada deberá permitir definir un entero entre 1 y 72 horas antes del horario del turno, pudiendo habilitar cancelaciones dentro del mismo día de la cita. Antes de confirmar la reserva, el sistema deberá mostrar al paciente el límite de cancelación aplicable según el perfil profesional. Este límite solo determina hasta cuándo el Paciente puede cancelar por su cuenta; no define por sí mismo si una cancelación es tardía ni si corresponde una multa. La política de multa y el porcentaje vigente también deberán mostrarse al Paciente antes de confirmar la reserva.

#### 3.2.3 Portal del Paciente y Turnos
* **RF-11: Calendario:** El sistema deberá renderizar una interfaz gráfica de usuario en forma de calendario interactivo para el paciente, en la cual se deberán reflejar exclusivamente las franjas horarias con disponibilidad de atención.
* **RF-12: Control de Masividad:** El sistema deberá ejecutar reglas de validación que impidan a un mismo usuario la reserva simultánea de múltiples turnos que se superpongan en horario, previniendo el acaparamiento de la agenda. Si un Paciente registra una multa pendiente asociada a un Profesional, el sistema deberá bloquear únicamente sus nuevas reservas autónomas con ese Profesional, sin afectar reservas con otros Profesionales ni turnos ya existentes.
* **RF-13: Historial operativo de turnos:** El sistema deberá permitir al paciente acceder a un listado histórico de sus turnos pasados (completados o cancelados), incluyendo únicamente información operativa y administrativa del turno, como fecha, horario, Profesional, tipo de consulta, estado operativo, estado administrativo y estado financiero. No deberá mostrar historia clínica, seguimiento clínico, indicaciones clínicas, diagnósticos, observaciones profesionales ni notas clínicas.
* **RF-14: Máquina de Estados:** El sistema deberá gestionar el ciclo de vida de cada turno mediante una máquina de estados finitos, registrando las transiciones obligatorias entre los estados operativos: Solicitado, Reservado, Confirmado, Asistió, Cancelado y No asistió, y el estado administrativo: Abierto o Cerrado. El estado inicial dependerá del rol que crea o reserva el turno y de la fecha de la cita según RF-10. Sobreturno no deberá utilizarse como estado del ciclo de vida, sino como tipo o modalidad de turno compatible con esos estados. El cierre administrativo deberá mantenerse Abierto mientras exista alguna acción operativa o financiera pendiente, y solo deberá pasar a Cerrado cuando el turno alcance un resultado operativo terminal y no queden obligaciones financieras ni decisiones de multa pendientes. La cancelación automática de un turno Reservado por falta de confirmación únicamente deberá liberar la agenda; no deberá considerarse, por sí misma, una cancelación tardía sancionable. La cancelación manual de un turno deberá unificarse bajo la operación de dominio Cancelar turno, cambiar el estado operativo a Cancelado, liberar de inmediato el horario y conservar de forma auditada el actor, la fecha, la hora, el motivo obligatorio y el estado anterior. Cuando un turno Confirmado sea modificado por Profesional en fecha u horario, el sistema deberá registrar explícitamente una de dos decisiones: "Acordado con el paciente", dejando el turno Confirmado y limitándose WhatsApp a informar el nuevo horario, o "Requiere confirmación", pasando el turno a Reservado y solicitando nueva confirmación por WhatsApp. "Requiere confirmación" solo deberá estar disponible si faltan al menos 24 horas para el nuevo horario; si faltan menos de 24 horas, deberá elegirse "Acordado con el paciente" y, si no hubo acuerdo, corresponderá cancelar el turno en lugar de reprogramarlo unilateralmente. La decisión elegida, el actor, la fecha y hora de la modificación, y los valores anteriores y nuevos deberán quedar auditados. Después de finalizar el horario previsto del turno, el Profesional o la Secretaría deberán poder registrar el resultado operativo como "Asistió" o "No asistió"; la interfaz deberá presentar "Asistió" preseleccionado como opción predeterminada, pero dicha preselección solo deberá representar una elección de interfaz y requerirá confirmación humana expresa para concretar el cierre. El registro de "No asistió" solo deberá habilitarse una vez finalizado el horario previsto del turno (hora de inicio más duración aplicable) y deberá dejar constancia del actor, la fecha y la hora de la operación. Si posteriormente se corrige un cierre entre "Asistió" y "No asistió", el sistema deberá conservar el cierre original y agregar un evento de corrección auditado con actor, fecha, hora, estado anterior, estado nuevo y motivo obligatorio.
  Una consulta Cancelada sin multa ni otra obligación deberá pasar a No corresponde y cerrar administrativamente; una consulta con No asistió sin multa o con multa perdonada deberá pasar a No corresponde y cerrar cuando no quede otra obligación o decisión pendiente. Una consulta con estado financiero Pendiente, En revisión o Rechazado deberá mantener el cierre Abierto; una consulta Asistió deberá mantenerse Abierta hasta quedar Pagada. La multa deberá conservar un ciclo y una obligación separados del estado financiero de la consulta.
  Si un turno permanece Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, Profesional o Secretaría deberán cerrarlo como Asistió si el Paciente asistió o como No asistió si no asistió. En este caso no deberá usarse Cancelado para representar la ausencia; el cierre como No asistió no será elegible para multa y el sistema deberá mostrar claramente su causa no sancionable.
* **RF-15: Sobreturnos:** El sistema deberá habilitar a los roles con privilegios administrativos (Secretaría o Profesional) la creación manual de turnos denominados "sobreturnos", permitiendo su inserción en la agenda en horarios atípicos o por fuera de los bloques regulares de disponibilidad.

#### 3.2.4 Automatizaciones y Notificaciones
* **RF-16: Confirmación y Cancelación:** El sistema deberá gestionar la confirmación por WhatsApp para los turnos sujetos a ese flujo. A las 18:00 horas del día D-1, si el turno permanece Reservado sin respuesta y al menos uno de los dos mensajes de confirmación alcanzó el estado `delivered`, deberá cambiar automáticamente a Cancelado y liberar de inmediato el bloque horario. Si ninguno de los mensajes alcanzó `delivered` —porque ambos fallaron o porque la entrega es desconocida o no consta al corte— el turno no deberá cancelarse automáticamente: permanecerá Reservado y visible como revisión urgente. Profesional o Secretaría deberán contactar al Paciente fuera del sistema. Si el Paciente acepta asistir, el actor deberá cambiar el turno a Confirmado; si rechaza, deberá cambiarlo a Cancelado y liberar de inmediato el bloque horario. Si no logra contactarlo, el turno deberá permanecer Reservado y visible como revisión urgente, sin resolución automática. Si permanece Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, Profesional o Secretaría deberán cerrarlo como Asistió si el Paciente asistió o como No asistió si no asistió; no deberá usarse Cancelado para representar la ausencia. Ese No asistió no será elegible para multa y el sistema deberá mostrar claramente la causa no sancionable. Para confirmar o cancelar por este flujo, el actor deberá registrar una declaración simple del resultado del contacto, sin almacenar evidencia ni el canal utilizado. El contacto, el intento fallido, la declaración, el actor, la fecha y hora, y cada transición deberán quedar auditados. Ninguno de estos resultados por falta de confirmación deberá habilitar ni generar multa.
* **RF-16 bis: Cancelación tardía y multa aplicada:** El sistema deberá distinguir entre cancelación tardía y multa aplicada. Solo podrá considerarse multa cuando el Paciente cancele desde las 18:00 horas del día D-1 un turno que estaba Confirmado, o cuando el turno se registre como No asistió, excepto si ese No asistió deriva de que ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual. En ambos casos elegibles, el Profesional deberá decidir expresamente si aplica o perdona la multa configurada para su perfil; no deberá ingresar un monto manual. Si decide aplicarla, el sistema deberá calcular el importe a partir del porcentaje vigente configurado sobre el precio efectivo del turno. Si la configuración de multa cambia luego de determinada una cancelación, no deberán recalcularse ni alterarse las multas ya determinadas. El registro de "No asistió" no deberá generar multa automática: solo deberá habilitar la decisión posterior del Profesional sobre su aplicación o perdón cuando sea elegible. Si un cierre de "No asistió" se corrige a "Asistió" y existiera una multa pendiente, el sistema deberá anularla de inmediato y restaurar la reserva autónoma con ese Profesional. Toda cancelación atribuible al Profesional deberá realizarse sin multa para el Paciente. Cuando una consulta Pagada se cancele sin penalización, su estado financiero deberá pasar a No corresponde, sin borrar ni modificar el pago original, y el sistema deberá generar automáticamente un saldo a favor del Paciente con ese Profesional por el monto pagado. Cuando el Paciente rechace una propuesta de aumento en un turno no Pagado, el sistema deberá conservar el precio anterior; si el Profesional decide no mantener ese precio anterior, podrá iniciar una cancelación manual del turno con motivo auditado y sin multa para el Paciente.
* **RF-17: Recordatorios:** El sistema deberá integrarse con la API de WhatsApp para enviar de manera automatizada dos mensajes de recordatorio y solicitud de confirmación a cada paciente con teléfono verificado: el primero a las 08:00 horas del día D-2 y el segundo a las 08:00 horas del día D-1, advirtiendo explícitamente las consecuencias de la falta de respuesta según RF-16. Todo mensaje de WhatsApp, incluidos recordatorios, reprogramaciones, ofertas de lista de espera y demás mensajes, solo podrá incluir el nombre del centro, el nombre del Profesional, la fecha y el horario, el consultorio o ubicación y la acción necesaria para confirmar, rechazar o responder al flujo aplicable. No podrá incluir DNI, tipo de consulta, pagos, montos, multas, estado financiero, comprobantes ni datos clínicos o sensibles; esos detalles solo podrán consultarse dentro del sistema autenticado. No se enviarán automatizaciones de WhatsApp a un teléfono no verificado. Cuando se inicie un cambio posterior de teléfono, deberán suspenderse inmediatamente las automatizaciones y WhatsApp al número anterior; el nuevo número no recibirá mensajes hasta verificarse por código. Mientras el cambio esté pendiente, los turnos próximos deberán quedar señalados para contacto o revisión manual de Profesional y Secretaría. Al verificarse el nuevo número, deberán activarse WhatsApp y las automatizaciones hacia ese número. Para cada mensaje, `sent` significará que WhatsApp lo aceptó o procesó, sin probar entrega; `delivered` probará su llegada al dispositivo y será la evidencia mínima de entrega; `read` no será obligatorio; y `failed` indicará fallo. Un estado ausente o desconocido al corte se tratará como entrega no comprobada. Los turnos creados o aprobados durante D-1 omiten este flujo de WhatsApp. Los turnos creados por Profesional antes de D-1 sí deben atravesar este flujo; los creados durante D-1 no. Este calendario regular es independiente del disparador inmediato que debe enviarse cuando un turno Confirmado es modificado en fecha u horario por Profesional. En esa modificación, WhatsApp deberá reflejar la decisión explícita elegida entre "Acordado con el paciente" o "Requiere confirmación", según corresponda al umbral de 24 horas.
* **RF-18: Liberación de Agenda:** El sistema deberá liberar el bloque horario en la base de datos de manera inmediata tras la cancelación de un turno, reflejando la disponibilidad instantánea en el calendario interactivo. Esta liberación deberá ser inmediata tanto en cancelaciones automáticas como manuales.

#### 3.2.5 Lista de Espera y Facturación
* **RF-19: Lista de Espera:** El sistema deberá mantener, por cada Profesional, una única cola de espera ordenada por fecha y hora de inscripción. Ante la liberación de un cupo, el sistema deberá ofrecerlo a una sola persona por vez, comenzando por el primer Paciente elegible de la cola. Al enviar una oferta de lista de espera, el cupo deberá quedar retenido exclusivamente durante 30 minutos; mientras dure la retención no deberá aparecer disponible para otras reservas ni podrá ofrecerse a otra persona. La retención no deberá crear un turno ni modificar el historial o el estado del Paciente. Si el Paciente acepta dentro del plazo, la retención deberá convertirse en turno según el flujo aplicable. Si rechaza o vence el plazo, el sistema deberá liberar la retención y ofrecer el cupo al siguiente Paciente elegible con una nueva retención de 30 minutos. Cuando el Paciente rechace una oferta, el sistema deberá liberar la retención de ese cupo y continuar con el siguiente Paciente elegible. El Paciente que rechazó deberá permanecer inscripto, conservando su fecha y hora de inscripción, sus preferencias y su posición relativa para futuras ofertas compatibles. El rechazo no deberá generar multa, penalización ni baja. Ante vencimientos consecutivos de ofertas sin respuesta, el primer y segundo vencimiento no deberán alterar la inscripción: el Paciente permanecerá inscripto, conservará antigüedad y posición, y el flujo continuará. Al tercer vencimiento consecutivo sin respuesta, el sistema deberá pausar automáticamente la inscripción. Una inscripción pausada no deberá recibir nuevas ofertas. El Paciente podrá reactivarla, conservando sus preferencias pero recibiendo una nueva fecha y hora de inscripción y una nueva posición en la cola. Una respuesta explícita a una oferta posterior a esa reactivación deberá reiniciar el contador de vencimientos consecutivos. El estado de pausa, la reactivación, el contador de vencimientos consecutivos y los cambios de antigüedad deberán quedar auditados. El Paciente solo deberá salir de la lista de espera al aceptar un turno, solicitar la baja voluntaria o quedar cubierto por una asignación directa. La baja voluntaria de una inscripción deberá permitir que el Paciente retire su propia inscripción, que Secretaría retire cualquier inscripción y que Profesional retire solo inscripciones de Pacientes vinculados con él. Cuando actúen Secretaría o Profesional, deberán dejar una declaración simple de que lo hacen a pedido del Paciente, sin almacenar evidencia. Si existe una oferta o retención activa, la baja deberá cancelarla y liberar de inmediato el cupo para continuar el flujo aplicable. La baja no deberá generar multa ni penalización. Cada Profesional deberá configurar la modalidad de operación en Automático o Manual.

  Al inscribirse en la lista de espera, el Paciente deberá declarar el tipo de consulta requerido, los días aceptables y las franjas horarias aceptables, o indicar «Cualquier horario». Solo deberán ofrecerse cupos compatibles con esas preferencias. Si el primer Paciente por antigüedad no coincide con un cupo, el sistema deberá saltearlo temporalmente para esa oferta, sin eliminarlo de la cola, cambiar su fecha de inscripción ni modificar su posición relativa para futuras ofertas, y deberá seleccionar al Paciente elegible más antiguo.

  La inscripción y edición de la preferencia deberán estar permitidas según el rol: el Paciente podrá crear y editar su propia inscripción; Secretaría podrá crear y editar la inscripción de cualquier Paciente registrado; Profesional podrá crear y editar solo inscripciones de Pacientes que tengan o hayan tenido al menos un turno con ese Profesional. Cuando actúen Secretaría o Profesional, deberán registrar una declaración simple de que actúan a pedido del Paciente, sin almacenar evidencia del pedido. El alta o edición, el actor, el Paciente, el Profesional, las preferencias anteriores y nuevas, la fecha/hora y la declaración deberán quedar auditados. Si la edición solo modifica días aceptables, franjas horarias o alterna «Cualquier horario», el sistema deberá conservar la fecha/hora original de inscripción y la posición relativa en la cola. Si la edición cambia el tipo de consulta requerido, el sistema deberá tratar la modificación como una nueva solicitud, reiniciar la fecha/hora de inscripción y reubicar la entrada según la nueva antigüedad. Antes de guardar un cambio de tipo, el sistema deberá advertir de forma explícita que la posición cambiará y exigir confirmación.
  La reactivación asistida de una inscripción pausada deberá estar permitida para Secretaría sobre cualquier Paciente y para Profesional únicamente sobre Pacientes vinculados con él. En esa reactivación, el actor interno deberá dejar constancia de una declaración simple de que actúa a pedido del Paciente, sin almacenar evidencia adicional. La reactivación deberá conservar las preferencias vigentes, reiniciar el contador de vencimientos consecutivos, asignar una nueva fecha y hora de inscripción y ubicar la inscripción con una nueva posición en la cola. No deberá restaurarse la posición anterior ni habilitarse una reactivación automática.

  La asignación directa de un cupo liberado por Secretaría o Profesional deberá respetar el mismo corte temporal que la reserva de un turno del día D: solo podrá ejecutarse hasta el inicio del turno, nunca después. Esa asignación no deberá depender de la cola de espera ni alterar el orden relativo o la prioridad de los Pacientes que permanecen en ella. Si el Paciente destinatario estaba inscripto en la lista de espera de ese Profesional, el sistema deberá eliminar únicamente su inscripción al crearse el turno y registrar la salida con el motivo «Cubierto por asignación directa». Para realizarla, el actor deberá marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario». El acuerdo podrá ser verbal o producirse fuera del sistema; el sistema no deberá solicitar ni almacenar evidencia, grabación, comprobante o canal de dicho acuerdo.
* **RF-20: Pagos:** El sistema deberá requerir el registro del estado financiero de cada consulta, categorizando la transacción como Pendiente, En revisión, Pagado, Rechazado o No corresponde y documentando el método de pago empleado cuando corresponda. Un pago directo en efectivo registrado por el Profesional o la Secretaría deberá pasar a Pagado sin comprobante. La carga de un comprobante deberá pasar a En revisión; su validación, a Pagado; y su rechazo, a Rechazado. Estas transiciones no deberán alterar el estado operativo del turno. El cierre administrativo deberá permanecer Abierto cuando exista pago pendiente, multa pendiente o decisión de multa pendiente, y solo deberá pasar a Cerrado cuando no quede ninguna obligación pendiente. La multa por cancelación tardía no deberá confundirse con el estado financiero de la consulta: su decisión de aplicación/perdón y su eventual cálculo deberán registrarse por separado. La cancelación automática por falta de confirmación no deberá generar ni activar multa. Cuando la multa sea pagada o perdonada, y no quede otra obligación pendiente, el cierre administrativo deberá poder pasar a Cerrado. Si una multa que nació de un cierre de "No asistió" corregido a "Asistió" ya estaba "Pendiente", el sistema deberá anularla; si ya estaba "Pagado", el sistema deberá conservar el registro y, al invalidarse la multa por la corrección, deberá generar automáticamente un saldo a favor del Paciente con ese Profesional por el importe pagado. Cuando una consulta Pagada se cancele sin penalización, el sistema deberá cambiar su estado financiero a No corresponde, conservar sin cambios el pago original y generar automáticamente un saldo a favor del Paciente con ese Profesional por el monto pagado, vinculado a ese pago. Secretaría deberá poder visualizar ese saldo a favor y registrar una devolución realizada fuera del sistema si el Paciente la solicita; dicho registro deberá consumir el saldo a favor correspondiente y conservar el vínculo con el pago original que generó el saldo. El sistema no deberá borrar ni alterar el pago, la multa ni la corrección originales.
  El estado financiero de cada consulta podrá ser Pendiente, En revisión, Pagado, Rechazado o No corresponde. Todos los pagos, multas, saldos a favor, compensaciones y devoluciones externas serán exclusivamente registros administrativos declarados por usuarios autorizados; el sistema no procesará, cobrará, transferirá ni devolverá dinero real. Una consulta Cancelada sin multa ni otra obligación deberá pasar a No corresponde y su cierre administrativo a Cerrado. Si una consulta Pagada se cancela tarde, deberá pasar a No corresponde, conservar el pago original y generar un saldo a favor por ese importe. Si el Profesional aplica la multa, el sistema deberá registrar por separado la compensación administrativa de la multa contra ese saldo a favor y conservar como saldo a favor el remanente; si la perdona, deberá conservar el saldo completo. Estos registros no implicarán movimiento de dinero real. Una consulta con No asistió sin multa o con multa perdonada deberá pasar a No corresponde; su cierre administrativo será Cerrado cuando no quede otra obligación o decisión pendiente. No corresponde no deberá significar Pagado ni eliminar el historial de la consulta. Una consulta Asistió deberá permanecer Abierta hasta que su estado financiero sea Pagado; los estados Pendiente, En revisión y Rechazado deberán mantener el cierre Abierto. La multa por cancelación tardía deberá conservar una obligación y ciclo separados del estado financiero de la consulta.
* **RF-21: Comprobantes:** El sistema deberá contar con un módulo de gestión documental que permita la carga, almacenamiento privado en el servidor y posterior validación o rechazo de archivos de imagen o PDF correspondientes a comprobantes de pago. El comprobante será evidencia para validación manual y no confirmación bancaria automática. Deberá aceptar únicamente PNG, JPG/JPEG y PDF, con un tamaño máximo de 10 MB por archivo, verificando el tipo real y el contenido antes de admitirlos; deberá rechazar archivos corruptos, ejecutables o que no correspondan al formato declarado. Antes de habilitar la visualización, deberá analizar los archivos en busca de malware. El acceso a los comprobantes deberá quedar restringido al Paciente propietario, al Profesional asociado al turno y a Secretaría, sin exponer URLs públicas permanentes. La carga, el rechazo técnico, el resultado del análisis y toda visualización o acceso deberán quedar auditados. La carga o validación del comprobante no deberá modificar por sí misma el estado operativo del turno; únicamente deberá afectar el estado financiero asociado. La política de retención o eliminación de comprobantes queda pendiente de validación legal y contable; provisionalmente no habrá eliminación automática. Antes de producción, el cliente deberá aprobar un plazo concreto y la conducta de eliminación o retención.
* **RF-22: Reportes:** El sistema deberá procesar únicamente los importes con estado financiero Pagado para generar informes tabulares o gráficos administrativos que resuman los ingresos registrados para el profesional, filtrables por periodos mensuales y anuales. Estos informes no serán factura, recibo fiscal, contabilidad legal ni conciliación bancaria.

### 3.3 Requisitos de Rendimiento
* **Rend-01:** En un entorno de pruebas equivalente a producción, el sistema deberá soportar una carga operativa de hasta 50 sesiones de usuario concurrentes manteniendo la estabilidad del servicio.
* **Rend-02:** En un entorno de pruebas equivalente a producción y con hasta 50 sesiones de usuario concurrentes, al menos el percentil 95 de las cargas de las pantallas principales deberá completarse en menos de 2 segundos. Las pantallas principales son: calendario/reserva, agenda diaria, listado/gestión de Pacientes y gestión/listado de pagos. Se excluyen la carga o descarga de archivos y los tiempos atribuibles a Google OAuth o WhatsApp. Este criterio no constituye una garantía absoluta para cada petición.
* **Rend-03:** El sistema deberá procesar y encolar los mensajes programados D-2 y D-1 en un lapso inferior a 5 minutos desde el horario o evento planificado. Los mensajes inmediatos por reprogramación, oferta de lista de espera y otros cambios urgentes ya documentados deberán procesarse y encolarse en un lapso inferior a 1 minuto desde el evento. La entrega final al dispositivo depende de WhatsApp y deberá medirse y registrarse por separado; no forma parte de la latencia de encolado.

### 3.4 Restricciones de Diseño
* **RD-01 Diseño Responsivo:** El sistema deberá desarrollarse utilizando patrones de diseño web adaptativo (Responsive Design), garantizando que los componentes de la interfaz de usuario se autoajusten dinámicamente a las resoluciones de monitores de escritorio, tabletas y teléfonos móviles. El cumplimiento de este requisito no sustituye el cumplimiento de accesibilidad definido en RNF-05.
* **RD-02 Navegación:** En cada versión del producto, el sistema deberá soportar la versión estable actual y la anterior de Google Chrome, Mozilla Firefox, Apple Safari y Microsoft Edge en escritorio, además de Chrome en Android y Safari en iOS. Los flujos críticos deberán probarse en esta matriz. Las versiones más antiguas podrán funcionar, pero no se garantizan.

### 3.5 Atributos del Sistema 
#### 3.5.1 Seguridad
* **RNF-01 Privacidad de Datos Bancarios y Comprobantes:** El sistema deberá aplicar medidas de ofuscación o restricción de vista de la información financiera, asegurando que los datos sensibles como el Alias y el CBU sean expuestos en la interfaz de usuario únicamente dentro de la ventana de carga de comprobantes del paciente. Los comprobantes de pago deberán mantenerse privados, sin URLs públicas permanentes, y solo podrán ser accedidos por el Paciente propietario, el Profesional asociado al turno y Secretaría.
* **RNF-02 Integridad:** El sistema deberá asegurar, mediante reglas del backend, que exclusivamente los usuarios autenticados bajo el rol de Administrador posean los permisos necesarios para ejecutar operaciones de modificación sobre credenciales de acceso de terceros. Para el cambio de correo electrónico, el Administrador podrá iniciar un cambio verificado para cualquier usuario y Secretaría podrá iniciarlo únicamente para Pacientes; Secretaría no podrá cambiar correos de roles internos. Ninguno de estos roles podrá activar unilateralmente el cambio: el nuevo correo deberá verificarse y el correo anterior deberá permanecer activo hasta que esa verificación se complete. La carga, el rechazo técnico, el resultado del análisis de malware y los accesos o visualizaciones de comprobantes deberán quedar auditados junto con el usuario, la fecha y la operación realizada.
  El backend deberá aplicar los permisos de consulta del log de auditoría: Administrador tendrá acceso global de solo lectura; Profesional solo podrá consultar eventos vinculados a su agenda, sus Pacientes relacionados y sus propias operaciones; Secretaría solo podrá consultar los eventos operativos necesarios para la gestión, sin acceso a eventos internos sensibles de seguridad; y Paciente no tendrá acceso al log técnico. Ningún rol podrá editar ni borrar registros de auditoría.
* **RNF-06 Gestión de baja y datos personales:** La baja inmediata de una cuenta de Paciente deberá ser lógica: deberá inactivarla y bloquear nuevas reservas, sin eliminar automáticamente turnos, pagos, comprobantes ni registros de auditoría. La política de solicitud de eliminación o anonimización y de conservación obligatoria de datos personales queda pendiente de validación legal. Hasta que el cliente apruebe, antes de producción, qué datos se eliminan, anonimizan o conservan y durante cuánto tiempo, no habrá borrado ni anonimización automática y la salida a producción quedará bloqueada.
* **RNF-07 Protección criptográfica y secretos:** Toda comunicación del sistema deberá estar cifrada en tránsito mediante TLS. La base de datos, los backups y los comprobantes deberán estar cifrados en reposo. Las contraseñas de Usuarios Internos deberán almacenarse únicamente mediante un hash seguro, nunca en texto plano ni en forma reversible. Los secretos y las credenciales deberán mantenerse fuera del repositorio y del código fuente. Antes de producción deberá existir capacidad y un procedimiento para rotar credenciales comprometidas. El cumplimiento de este requisito para los datos actuales será un gate de preproducción/DoD y no forma parte del alcance funcional del Sprint 1.
* **RNF-08 Matriz de autorización y denegación por defecto:** Antes de implementar módulos sensibles deberá existir una única matriz de autorización con filas para las operaciones sensibles y columnas para Administrador, Profesional, Secretaría y Paciente. Cada cruce deberá indicar permitir, denegar o permitir con condición o alcance. Todo permiso no declarado se denegará por defecto. El backend será la autoridad y deberá aplicar estas reglas aunque el frontend o cualquier cliente intente eludirlas; ocultar controles en el frontend no constituye seguridad. Los permisos críticos deberán contar con pruebas automatizadas. Los cambios de la matriz deberán versionarse, revisarse y quedar asociados a sus requisitos.
* **RNF-09 Sesiones internas:** Las sesiones de Administrador, Profesional y Secretaría tendrán una duración máxima absoluta de 12 horas y se bloquearán tras 30 minutos de inactividad. Cada nueva sesión exigirá el ingreso de contraseña. En un dispositivo declarado confiable, el segundo factor podrá recordarse por un máximo de 30 días; vencido ese plazo, ante el uso de un dispositivo nuevo, un cambio de correo, contraseña o configuración de 2FA, o la detección de actividad sospechosa, el sistema deberá exigir nuevamente el 2FA. Esta excepción solo modifica la frecuencia de solicitud: el 2FA seguirá siendo obligatorio para los tres roles internos. Las acciones sensibles sobre credenciales, correo o 2FA requerirán una reautenticación reciente.
* **RNF-10 Sesiones de Paciente:** Las sesiones de Paciente no tendrán duración máxima absoluta mientras exista actividad y expirarán tras 60 días consecutivos de inactividad. El Paciente podrá cerrar sesión manualmente y cerrar todas sus sesiones. Para cambiar el correo u otros datos sensibles ya documentados, deberá reautenticarse mediante Google o Magic Link. Al activarse un cambio de correo, el sistema invalidará las demás sesiones activas del Paciente.
* **RNF-11 Minimización de mensajería:** El sistema deberá limitar el contenido de todos los mensajes de WhatsApp a la información operativa permitida por RF-17. Los datos prohibidos por RF-17 no deberán enviarse por WhatsApp y solo podrán consultarse dentro del sistema autenticado.

#### 3.5.2 Disponibilidad
* **RNF-03 Operatividad:** El sistema deberá alcanzar un objetivo de disponibilidad mensual del 99,5 %, medido mediante monitoreo externo. Este objetivo excluye el mantenimiento programado comunicado y las caídas atribuibles exclusivamente a Google OAuth o WhatsApp. Un 99,9 % queda como objetivo futuro, sujeto a presupuesto y a infraestructura y operación formal.
* **RNF-04 Backups y recuperación:** Antes de producción o de almacenar datos reales de Pacientes, el sistema deberá contar con backups automáticos cifrados, con retención de 30 días, y con una prueba de restauración realizada al menos mensualmente. La pérdida máxima aceptable de datos (RPO) será de 1 hora y el tiempo objetivo de recuperación del servicio (RTO) será de 4 horas. La salida a producción quedará bloqueada hasta contar con evidencia de backup y de restauración probada.

#### 3.5.3 Accesibilidad
* **RNF-05 Accesibilidad:** Las pantallas principales orientadas a Paciente y los flujos críticos internos deberán cumplir WCAG 2.2 nivel AA, incluyendo navegación por teclado, contraste suficiente, texto ampliable, nombres y etiquetas accesibles para lectores de pantalla, errores explicados en texto, información no dependiente solo del color y objetivos táctiles adecuados para celular. Este cumplimiento deberá verificarse mediante controles automáticos y revisión manual de los flujos críticos.

### 3.6 Otros Requisitos
* **RF-23 Registro de Auditoría:** El sistema deberá registrar de forma automática, silenciosa e inmutable en una tabla de auditoría (log) cada transacción realizada, persistiendo obligatoriamente el identificador del usuario que ejecutó la acción, el tipo de operación, la fecha y la hora del evento del lado del servidor. Las operaciones vinculadas a la lista de espera —alta, edición, baja voluntaria, oferta enviada, aceptación de la oferta, rechazo de la oferta, vencimiento de la oferta, liberación de la retención, conversión de la retención en turno, cambio de orden, autorización de envío, salto temporal de un Paciente no elegible y fin del proceso por alcanzar el límite temporal de la lista de espera— deberán quedar auditadas de forma diferenciada. La evaluación de elegibilidad, las preferencias vigentes que la determinan y cualquier salto temporal de un Paciente no elegible también deberán quedar registradas. La aceptación, el rechazo, la liberación de la retención y la continuidad del flujo hacia el siguiente Paciente elegible deberán quedar diferenciados como eventos auditables. Los vencimientos consecutivos sin respuesta, la pausa automática de una inscripción, la reactivación por parte del Paciente, la reactivación asistida por Secretaría o Profesional, la declaración simple registrada en esa reactivación, la conservación de preferencias, el reinicio del contador de vencimientos y la reasignación de antigüedad/posición asociada también deberán quedar auditadas de forma diferenciada. Las cancelaciones de turno, el registro de "No asistió", el cierre manual de un turno como "Asistió" o "No asistió", la decisión del Profesional de aplicar o perdonar la multa, el registro de pagos en efectivo o por transferencia y la eventual multa aplicada deberán quedar diferenciadas como operaciones distintas en la auditoría. La cancelación automática por falta de confirmación también deberá registrarse como operación de liberación de agenda, sin etiquetarse como cancelación tardía sancionable. El inicio, la verificación, la activación y cualquier fallo de cambios de correo iniciados por el Administrador o por Secretaría en correos de Pacientes deberán quedar auditados como eventos separados. La creación excepcional de un turno pese a una multa pendiente también deberá quedar auditada indicando el actor que ejerció la excepción. La asignación directa de un cupo liberado por Secretaría o Profesional deberá respetar el mismo corte temporal que la reserva de un turno del día D: solo podrá ejecutarse hasta el inicio del turno, nunca después. Esa asignación no deberá depender de la cola de espera ni alterar el orden relativo o la prioridad de los Pacientes que permanecen en ella. Si el Paciente destinatario estaba inscripto en la lista de espera de ese Profesional, el sistema deberá eliminar únicamente su inscripción al crearse el turno y registrar la salida con el motivo «Cubierto por asignación directa». Para realizarla, el actor deberá marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario». El acuerdo podrá ser verbal o producirse fuera del sistema; el sistema no deberá solicitar ni almacenar evidencia, grabación, comprobante o canal de dicho acuerdo.
  Para cada reserva estándar creada por Secretaría deberán auditarse de forma diferenciada el estado elegido, la declaración simple de aceptación del horario cuando se cree como Confirmado, el actor y la fecha y hora; no deberá almacenarse evidencia, grabación, comprobante ni canal del acuerdo.
  El bootstrap del primer Administrador, la emisión, el consumo y cada fallo de una invitación de Usuario Interno, la configuración de contraseña, el enrolamiento TOTP y la activación de la cuenta deberán quedar auditados como eventos diferenciados. El pase de una consulta a No corresponde deberá quedar auditado como operación diferenciada, conservando el historial financiero previo cuando exista. Cuando ese pase provenga de la cancelación sin penalización de una consulta Pagada, también deberán auditarse de forma diferenciada la generación automática del saldo a favor, su monto, el Paciente, el Profesional y el vínculo con el pago original; toda devolución externa registrada por Secretaría deberá auditarse como consumo de ese saldo y conservar el mismo vínculo. Cuando provenga de una cancelación tardía de una consulta Pagada, deberán auditarse por separado el saldo a favor generado por el pago original, la decisión de aplicar o perdonar la multa, la compensación administrativa de la multa contra el saldo cuando corresponda y el remanente, vinculados al pago original y sin representar movimiento de dinero real.
  Para la verificación inicial del teléfono del Paciente, deberán auditarse de forma diferenciada el alta del teléfono, el envío del código, su validación, cada fallo de validación y la activación de la cuenta o de las capacidades habilitadas al verificarse el teléfono. Para cada cambio posterior de teléfono deberán auditarse de forma diferenciada el inicio, la suspensión de automatizaciones y WhatsApp al número anterior, el envío, la validación y cada fallo de validación del código, la activación del nuevo número, WhatsApp y autogestión, el actor y los turnos afectados señalados para contacto o revisión manual. Para la confirmación por WhatsApp, deberán auditarse de forma diferenciada los estados de cada mensaje, la evaluación de entrega al corte, la cancelación automática cuando corresponda y el pase a revisión manual cuando no exista entrega comprobada. En esa revisión, deberán auditarse el contacto fuera del sistema, cada intento fallido, la declaración simple del resultado, el actor, la fecha y hora, y las transiciones a Confirmado o Cancelado; no deberán almacenarse evidencia ni el canal de contacto.
  Cuando un turno permanezca Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, deberán auditarse el cierre como Asistió o No asistió, el actor, la fecha y hora, los estados de entrega de ambos mensajes y la exclusión de multa por causa no sancionable.
  Toda consulta del log de auditoría deberá registrarse como un evento de auditoría, incluyendo el actor, la fecha y hora, el alcance o los filtros aplicados y el resultado de la consulta. El plazo de retención del log queda sin definir hasta su validación legal y contable y la aprobación del cliente; provisionalmente no habrá eliminación automática. Antes de producción deberá aprobarse el plazo y la conducta de conservación o eliminación considerando los datos personales, la seguridad y los registros financieros; sin esa política aprobada, la salida a producción quedará bloqueada.

#### 3.6.1 Auditoría de comprobantes
* La carga, el rechazo técnico, el resultado del análisis de malware y toda visualización o acceso a comprobantes de pago deberán quedar registrados en la auditoría con usuario, fecha, hora y operación realizada.
---

## 4. Apéndices
* **A.1:** Diagrama de estados del turno (Solicitado -> Reservado -> Confirmado -> Asistió; Reservado -> Cancelado; Confirmado -> No asistió como ausencia ordinaria; excepcionalmente, Reservado -> No asistió solo si no hubo entrega (delivered) en D-2 ni D-1, no hubo contacto manual y finalizó el horario del turno; esta transición excepcional no es sancionable; casos D-1 que llegan directo a Confirmado; Sobreturno como tipo/modalidad compatible).
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
  * Dado que existen profesionales registrados con fecha de cierre nula y adicionalmente el Administrador cuenta con permisos de acceso al módulo cuando accede a la funcionalidad de listado entonces el sistema muestra el listado de profesionales activos actualizado. La evaluación de rendimiento deberá referenciar el percentil 95 definido en Rend-02.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.2 | Alta Profesional
**Como** Administrador, **quiero** registrar un nuevo profesional ingresando sus datos personales y dejar su cuenta en Pendiente de activación, **para poder** asegurar una incorporación ordenada y validada, minimizando errores administrativos dentro del sistema.
* **Valor:** 8 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
   * Comprobar que los campos nombre, apellido, DNI y email sean obligatorios para registrar un profesional. 
   * Comprobar que el género y la fecha de nacimiento no sean obligatorios para registrar un profesional. 
   * Comprobar que el DNI y el email sean únicos dentro del sistema, evitando registros duplicados. 
   * Comprobar que el campo teléfono sea opcional y no bloquee el alta si no se completa. 
   * Demostrar que, al registrar un profesional, la cuenta queda en estado Pendiente de activación hasta que complete la definición de contraseña y el enrolamiento TOTP mediante una invitación de un solo uso.
   * Verificar que cuando Administrador hace el registro de un nuevo profesional consigue que el sistema genere la cuenta en estado Pendiente de activación y emita una invitación de un solo uso.
  * Verificar que cuando Administrador hace el ingreso de datos duplicados en DNI o email consigue que el sistema rechace la operación e informe el error correspondiente. 
   * Dado que los datos ingresados son válidos y no se encuentran previamente registrados y adicionalmente el Administrador confirma la operación cuando realiza el alta entonces el sistema registra al profesional con fecha de creación y estado Pendiente de activación. Al definir contraseña y enrolar TOTP mediante la invitación de un solo uso, la cuenta pasa a Activa.
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
  * Dado que un turno permanece Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, cuando Profesional o Secretaría lo cierran, entonces el sistema permite Asistió o No asistió según corresponda, muestra claramente la causa no sancionable y no usa Cancelado ni habilita multa si se registra No asistió.
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
   * Comprobar que al registrar un paciente el teléfono obligatorio quede inicialmente no verificado y que el sistema envíe un código a ese número para su validación.
   * Comprobar que Secretaría pueda registrar al Paciente y crear o asignar sus turnos aunque el teléfono no esté verificado, y que el sistema muestre una advertencia clara sobre esa condición.
   * Comprobar que al validar el código enviado al teléfono, el sistema habilite las reservas autónomas y las automatizaciones de WhatsApp del Paciente.
  * Verificar que cuando la Secretaria realiza el registro de un nuevo paciente consigue que el sistema almacene correctamente la información ingresada.
  * Verificar que cuando la Secretaria ingresa un DNI o email previamente registrado consigue que el sistema rechace la operación e informe el error correspondiente.
  * Verificar que cuando los datos obligatorios no son completados consigue que el sistema impida realizar el alta indicando los campos faltantes.
   * Dado que los datos ingresados son válidos y no se encuentran previamente registrados y adicionalmente la Secretaria confirma la operación cuando realiza el alta entonces el sistema registra al Paciente con fecha de creación, teléfono no verificado y disponibilidad para gestión interna de turnos; las reservas autónomas y las automatizaciones de WhatsApp quedan habilitadas al validar el código enviado al teléfono.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 5.1 | Registrar Pago
**Como** Profesional o Secretaria, **quiero** registrar manualmente el estado financiero de una consulta, seleccionando el método de pago declarado, **para** mantener actualizados los registros administrativos del centro de salud “Origen”.
* **Valor:** 34 | **Prioridad:** 2 | **Estimación:** 12h
* **Validación:**
   * Comprobar que el sistema permite registrar el pago directo en efectivo y lo categoriza como “Pagado” sin comprobante.
  * Comprobar que el sistema despliega un listado con los métodos de pago válidos (Efectivo, Transferencia, Tarjeta, etc.).
    * Verificar que cuando el Profesional o la Secretaría registran un pago directo en efectivo y seleccionan el método de pago, consiguen que el turno actualice su estado financiero a “Pagado” de inmediato.
   * Verificar que cuando se cancela sin penalización una consulta Pagada, el sistema cambia su estado financiero a No corresponde, conserva sin cambios el pago original y genera automáticamente un saldo a favor del Paciente con ese Profesional por el monto pagado, vinculado a ese pago.
   * Verificar que cuando la Secretaria visualiza un saldo a favor existente para un Paciente con un Profesional, consigue ver el importe disponible y su origen asociado.
   * Verificar que cuando la Secretaria registra una devolución externa solicitada por el Paciente, consigue que el sistema consuma el saldo a favor correspondiente, mantenga el vínculo con el pago original y deje constancia auditada de la operación.
    * Verificar que, ante la cancelación tardía de una consulta Pagada, el sistema la pase a No corresponde, conserve el pago original y genere el saldo a favor correspondiente; si el Profesional aplica la multa, deberá registrar por separado su compensación administrativa contra ese saldo y el remanente, y si la perdona deberá conservar el saldo completo.
    * Dado que la Secretaría se encuentra en el detalle del turno de un paciente y adicionalmente el estado actual de la consulta es “Pendiente”, cuando confirma el registro de un pago directo en efectivo con el monto correspondiente, entonces el sistema actualiza la transacción a “Pagado”, registra el método declarado y genera un registro inmutable en la tabla de auditoría, sin procesar dinero real.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.2 | Cargar Comprobante
**Como** Paciente, **quiero** subir al servidor un archivo de imagen o PDF que corresponda a un comprobante de pago, **para** que el personal administrativo pueda validar manualmente el registro sin alterar el estado operativo del turno.
* **Valor:** 21 | **Prioridad:** 2 | **Estimación:** 16h
* **Validación:**
  * Comprobar que el módulo permita cargar únicamente archivos PNG, JPG/JPEG y PDF.
  * Comprobar que cada archivo tenga un tamaño máximo de 10 MB.
  * Comprobar que el sistema valide el tipo real y el contenido del archivo, no solo su extensión o tipo declarado.
  * Comprobar que el sistema rechace archivos corruptos, ejecutables o que no correspondan al formato declarado.
  * Comprobar que el archivo sea analizado en busca de malware antes de habilitar su visualización.
  * Comprobar que solo puedan acceder al comprobante el Paciente propietario, el Profesional asociado al turno y Secretaría.
  * Comprobar que el comprobante no quede expuesto mediante una URL pública permanente.
   * Comprobar que la carga, el rechazo técnico, el resultado del análisis y toda visualización o acceso queden auditados.
    * Dado que se carga, valida o rechaza un comprobante, cuando finaliza la operación, entonces el sistema mantiene sin cambios el estado operativo del turno y actualiza únicamente el estado financiero cuando corresponda, sin confirmar una operación bancaria automática.
   * Comprobar que no exista eliminación automática de comprobantes mientras la política de retención o eliminación permanezca pendiente de validación legal y contable, y que antes de producción el cliente apruebe un plazo concreto y la conducta de eliminación o retención.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.3 | Generar Reporte Financiero
**Como** Profesional, **quiero** generar informes tabulares o gráficos administrativos de los ingresos registrados filtrando por períodos mensuales y anuales, **para** evaluar el rendimiento económico de mis consultas en “Origen”.
* **Valor:** 34 | **Prioridad:** 2 | **Estimación:** 24h
* **Validación:**
   * Comprobar que el sistema procesa única y exclusivamente los importes con estado financiero “Pagado”.
  * Comprobar que la interfaz ofrece filtros obligatorios para segmentar por mes y por año.
  * Verificar que cuando el Profesional aplica los filtros de fecha, consigue visualizar un resumen gráfico o tabular exacto de las transacciones correspondientes.
    * Comprobar que el reporte no se presente como factura, recibo fiscal, contabilidad legal ni conciliación bancaria.
    * Dado que el Profesional está autenticado en su panel de control y adicionalmente existen importes con estado financiero “Pagado” para el período seleccionado, cuando solicita la generación del reporte, entonces el sistema procesa los datos administrativos y renderiza la información de forma clara y legible. La evaluación de rendimiento deberá referenciar el percentil 95 definido en Rend-02.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.4 | Estado de Pago
**Como** Profesional o Secretaría, **quiero** visualizar y auditar de manera rápida el estado financiero (Pendiente, En revisión, Pagado, Rechazado o No corresponde) adjunto a cada turno, **para** validar los comprobantes cargados por los pacientes y distinguir las consultas sin obligación de pago.
* **Valor:** 13 | **Prioridad:** 2 | **Estimación:** 12h
* **Validación:**
    * Comprobar que el sistema muestra los estados financieros Pendiente, En revisión, Pagado, Rechazado y No corresponde directamente en la vista general o de detalle del turno.
     * Comprobar que una consulta Cancelada sin multa ni otra obligación, y una consulta con No asistió sin multa o con multa perdonada, pasen a No corresponde sin que ello se muestre como Pagado ni elimine su historial.
      * Comprobar que, al cancelar sin penalización una consulta Pagada, el estado pase a No corresponde, el pago original permanezca sin cambios y se genere automáticamente un saldo a favor del Paciente con ese Profesional, vinculado a dicho pago.
      * Comprobar que, al cancelar tarde una consulta Pagada, el estado pase a No corresponde, se conserve el pago original y se genere el saldo a favor; si el Profesional aplica la multa, deberá quedar registrada su compensación administrativa contra ese saldo y el remanente, y si la perdona deberá conservarse el saldo completo.
   * Comprobar que un turno con comprobante cargado figure en estado “En revisión” y que, al hacer clic sobre él, se permita la apertura y visualización del archivo PDF o imagen adjunta.
    * Verificar que cuando el Profesional o la Secretaría detectan un comprobante erróneo y rechazan la transacción, consiguen que el estado financiero pase a “Rechazado” y se habilite la opción de reclamo.
     * Dado que el Profesional o la Secretaría están revisando el listado de turnos diarios y adicionalmente un paciente ha cargado su comprobante de pago, cuando lo validan manualmente, entonces cambian el estado financiero de “En revisión” a “Pagado” y el sistema actualiza la base de datos de manera inmediata sin modificar el estado operativo ni confirmar una acreditación bancaria.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Num: 5.5 | Listar Pagos
**Como** Administrador, **quiero** acceder a un listado histórico y global de todas las transacciones y pagos administrativos registrados en el sistema “Origen”, **para** auditar los registros financieros generales y los métodos de pago declarados.
* **Valor:** 8 | **Prioridad:** 2 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema restringe el acceso a este módulo global exclusivamente a usuarios con rol Administrador o Secretaria autorizada.
   * Comprobar que en el listado se visualicen de forma clara los campos de: Fecha, Pendiente, Profesional, Monto, Estado de Pago y Método declarado, y que los saldos a favor y compensaciones se identifiquen como registros administrativos sin representar movimientos de dinero real.
  * Verificar que cuando no existen registros de pago cargados en el sistema, consigue que la interfaz informe correctamente que no hay transacciones para mostrar.
  * Dado que el Administrador ha iniciado sesión con sus permisos correspondientes y adicionalmente existen movimientos financieros históricos guardados en la base de datos, cuando accede al módulo de lista de pagos, entonces el sistema recupera la información de forma ordenada y la muestra en la pantalla adaptativa. Conforme a Rend-02, en el entorno y la carga allí definidos, al menos el percentil 95 de las cargas deberá completarse en menos de 2 segundos.
* **HECHO POR:** Samuel Olmos

### HISTORIA DE USUARIO Núm: 7 | Iniciar Sesión Interno
**Como** Usuario Interno con cuenta Activa, **quiero** ingresar al sistema utilizando mi contraseña y TOTP, **para** poder acceder de forma segura a las funcionalidades del sistema, protegiendo la información sensible y reduciendo el riesgo de accesos no autorizados.
*Usuario interno = Administrador, secretaria y Profesional*
* **Valor:** 21 | **Prioridad:** 5 | **Estimación:** 24 h
* **Validación:**
  * Comprobar que el primer Administrador solo pueda quedar Activo después de ser provisionado por el proceso único de despliegue y de completar la definición de contraseña y el enrolamiento TOTP con su invitación de un solo uso.
  * Comprobar que una cuenta de Profesional o Secretaría creada por Administrador permanezca en Pendiente de activación y no pueda iniciar sesión hasta definir contraseña y enrolar TOTP mediante su invitación de un solo uso.
  * Comprobar que, tras completar ambos pasos, la cuenta interna pase a Activa y pueda iniciar sesión.
  * Comprobar que el sistema solicite usuario y contraseña válidos antes de permitir el acceso.
  * Comprobar que el sistema requiera obligatoriamente un segundo factor de autenticación para completar el inicio de sesión, salvo cuando se aplique el recordatorio vigente de un dispositivo declarado confiable.
  * Comprobar que, aun con dispositivo declarado confiable, cada nueva sesión solicite la contraseña y que el recordatorio del segundo factor no exceda 30 días.
  * Comprobar que el sistema solicite nuevamente el segundo factor al vencer los 30 días, usarse un dispositivo nuevo, cambiarse el correo, la contraseña o la configuración de 2FA, o detectarse actividad sospechosa.
  * Comprobar que el acceso sea denegado cuando las credenciales ingresadas sean incorrectas.
  * Comprobar que el acceso sea denegado cuando el código de segundo factor sea inválido o haya expirado.
  * Comprobar que la sesión se bloquee tras 30 minutos de inactividad y no se extienda más allá de 12 horas desde su inicio.
  * Comprobar que las acciones sensibles sobre credenciales, correo o 2FA requieran reautenticación reciente.
  * Demostrar que únicamente los usuarios internos con credenciales válidas y segundo factor verificado, ya sea durante el inicio de sesión o dentro de un recordatorio vigente de dispositivo confiable, pueden acceder a las funcionalidades del sistema.
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
   * Demostrar que, si la cuenta de Paciente completa los datos obligatorios de RF-02 y valida el código enviado al teléfono, el sistema la pasa a estado Activa y habilita la reserva de turnos autónoma y las automatizaciones de WhatsApp.
  * Verificar que, si la comprobación de DNI o fecha de nacimiento no coincide con la ficha existente, el sistema no vincula Google ni crea un duplicado.
   * Verificar que, para una cuenta en estado Pendiente de completar, el sistema solo habilite la activación cuando el Paciente complete y valide los datos obligatorios definidos para Paciente en RF-02, incluido el código enviado al teléfono.
  * Comprobar que la sesión de Paciente creada mediante Google cumpla RNF-10.
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
  * Comprobar que la sesión de Paciente creada mediante Magic Link cumpla RNF-10.
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
  * Comprobar que la baja de un paciente se realice de forma lógica mediante una fecha de cierre o estado inactivo, sin eliminar automáticamente turnos, pagos, comprobantes ni auditoría.
  * Comprobar que la baja lógica no elimine ni modifique automáticamente los turnos futuros del paciente.
  * Comprobar que el sistema solicite una confirmación previa antes de ejecutar la baja.
  * Demostrar que una vez dado de baja el paciente deja de poder solicitar nuevos turnos.
  * Comprobar que la baja no active borrado ni anonimización automáticos mientras la política de eliminación o anonimización y conservación obligatoria permanezca pendiente de validación legal.
  * Verificar que cuando la Secretaria realiza la baja de un paciente consigue que el sistema marque correctamente el registro como inactivo.
  * Dado que la Secretaria seleccionó un paciente activo y confirma la operación de baja, entonces el sistema registra la fecha de cierre, inhabilita nuevas reservas y conserva turnos, pagos, comprobantes y auditoría sin eliminarlos ni anonimizarlos automáticamente.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 1.3 | Modificación paciente
**Como** Paciente o Secretaria, **quiero** modificar los datos de un paciente registrado, **para** mantener actualizada su información personal y de contacto dentro del sistema.
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
   * Comprobar que Paciente o Secretaría puedan iniciar un cambio de teléfono y que, al hacerlo, se suspendan inmediatamente las automatizaciones y WhatsApp al número anterior.
   * Comprobar que, mientras el nuevo teléfono esté pendiente de validación por código, no reciba mensajes ni habilite reservas autónomas y los turnos próximos queden señalados para contacto o revisión manual de Profesional y Secretaría.
   * Comprobar que, al validar el código enviado al nuevo teléfono, se activen ese número, WhatsApp y la autogestión del Paciente.
   * Verificar que el inicio del cambio, la suspensión, el envío, la validación y cada fallo del código, la activación, el actor y los turnos afectados queden auditados.
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
   * Comprobar que el sistema impida la reserva autónoma cuando el teléfono obligatorio del Paciente no esté verificado e informe claramente esa condición.
   * Comprobar que, al validar el código enviado al teléfono, el Paciente recupere la posibilidad de realizar reservas autónomas.
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
   * Comprobar que, antes de D-1, la Secretaria elija explícitamente crear la reserva estándar como Reservado o como Confirmado, sin que intervenga la modalidad de aprobación del Profesional ni el estado Solicitado.
   * Comprobar que, durante D-1, la Secretaria solo pueda crear la reserva estándar como Confirmado y que no se aplique el flujo de confirmación por WhatsApp.
   * Comprobar que la Secretaria pueda crear una reserva estándar hasta las 23:59 horas del día D-1 para una cita del día D y que el sistema rechace esa reserva estándar posteriormente, sin afectar las reglas separadas de asignación directa.
   * Comprobar que, al crear una reserva estándar como Confirmado, la Secretaria registre una declaración simple de que el Paciente aceptó el horario, sin almacenar evidencia, grabación, comprobante ni canal del acuerdo.
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
   * Dado que la Secretaria seleccionó un paciente registrado y adicionalmente existe disponibilidad en la agenda del profesional, cuando confirma una reserva estándar antes de D-1, entonces el sistema registra el turno como Reservado o Confirmado según su elección explícita; si eligió Confirmado, registra su declaración simple de aceptación del horario. Durante D-1, el sistema solo permite Confirmado con esa declaración, sin depender de la modalidad de aprobación del perfil profesional.
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
**Como** Paciente, **quiero** confirmar mi asistencia al turno mediante el mensaje recibido por WhatsApp, **para** mantener activa mi reserva y evitar que el turno sea cancelado automáticamente si no respondo dentro del plazo definido y existe entrega comprobada de al menos un mensaje.
* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema envíe un primer mensaje de WhatsApp a las 08:00 horas del día D-2 solicitando confirmación.
   * Comprobar que el sistema envíe un segundo mensaje de WhatsApp a las 08:00 horas del día D-1 advirtiendo explícitamente que la falta de respuesta causará la cancelación.
   * Comprobar que cada mensaje de WhatsApp incluya solo el nombre del centro, el nombre del Profesional, la fecha y horario, el consultorio o ubicación y la acción necesaria para confirmar, rechazar o responder al flujo aplicable; y que no incluya DNI, tipo de consulta, pagos, montos, multas, estado financiero, comprobantes ni datos clínicos o sensibles.
   * Comprobar que el mensaje permita al paciente confirmar su asistencia de manera simple.
  * Comprobar que, cuando el paciente confirma su asistencia, el turno cambie al estado Confirmado.
   * Comprobar que, si el paciente no confirma antes de las 18:00 horas del día anterior al turno y al menos uno de los dos mensajes alcanzó `delivered`, el sistema cancele automáticamente la reserva y libere el horario.
   * Comprobar que `sent` no pruebe entrega, que `delivered` sea la evidencia mínima, que `read` no sea obligatorio, que `failed` indique fallo y que un estado ausente o desconocido se trate como entrega no comprobada.
   * Comprobar que, si ninguno de los mensajes alcanzó `delivered`, el turno permanezca Reservado y visible como revisión urgente para que Profesional o Secretaría contacten al Paciente fuera del sistema.
    * Comprobar que, durante la revisión manual, si el Paciente acepta asistir el actor cambie el turno a Confirmado; si rechaza, lo cambie a Cancelado y libere el horario; y si no logra contactarlo, el turno permanezca Reservado sin resolución automática hasta finalizar su horario.
    * Comprobar que, si al finalizar el horario el turno continúa Reservado porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, Profesional o Secretaría lo cierren como Asistió o No asistió según corresponda, sin usar Cancelado; si se registra No asistió, el sistema muestre claramente la causa no sancionable y no habilite multa.
   * Comprobar que, al confirmar o cancelar por este flujo, el actor registre una declaración simple del resultado del contacto sin almacenar evidencia ni el canal, y que se auditen el contacto, el intento fallido, la declaración, el actor, la fecha y hora y la transición.
  * Comprobar que esa cancelación automática por falta de confirmación no genere ni habilite multa.
  * Comprobar que toda cancelación realizada desde las 18:00 horas del día D-1 sobre un turno Confirmado se considere tardía.
  * Comprobar que la aplicación de una multa por cancelación tardía dependa de una decisión expresa del Profesional.
  * Comprobar que al cancelarse automáticamente el turno, el horario quede nuevamente disponible en la agenda.
  * Comprobar que los turnos creados o aprobados durante D-1 no utilicen este flujo de WhatsApp.
  * Verificar que cuando el Paciente confirma su asistencia mediante WhatsApp consigue que el sistema mantenga activa la reserva y actualice el estado del turno.
   * Verificar que cuando el Paciente no confirma su asistencia dentro del plazo establecido y existe entrega comprobada de al menos un mensaje, consigue que el sistema cancele automáticamente el turno e informe la disponibilidad del horario.
    * Verificar que cuando el Paciente no confirma su asistencia y no existe entrega comprobada de ninguno de los mensajes, consigue que el turno permanezca Reservado y visible como revisión urgente, sin multa ni resolución automática si no se logra contactarlo hasta finalizar el horario; entonces Profesional o Secretaría lo cierran como Asistió o No asistió según corresponda, y este último conserva la causa no sancionable y no habilita multa.
  * Dado que el Paciente posee un turno reservado y adicionalmente recibe el primer mensaje de confirmación por WhatsApp, cuando responde confirmando su asistencia dentro del plazo permitido, entonces el sistema cambia el estado del turno a Confirmado y conserva la reserva activa.
   * Dado que el Paciente posee un turno reservado, al menos uno de los dos mensajes alcanzó `delivered` y adicionalmente no confirma su asistencia antes de las 18:00 horas del día anterior al turno, cuando se ejecuta la rutina automática de cancelación, entonces el sistema cambia el estado del turno a Cancelado, libera el horario en la agenda y registra la operación correspondiente.
    * Dado que el Paciente posee un turno Reservado, ninguno de los mensajes alcanzó `delivered` y adicionalmente no confirma su asistencia antes de las 18:00 horas del día anterior al turno, cuando se alcanza el corte, entonces el sistema lo mantiene Reservado y visible como revisión urgente. Si Profesional o Secretaría contactan al Paciente fuera del sistema y este acepta asistir, el actor lo cambia a Confirmado; si rechaza, lo cambia a Cancelado y libera el horario; si no logra contactarlo, permanece Reservado sin resolución automática. Si permanece Reservado hasta finalizar su horario porque no hubo contacto manual, Profesional o Secretaría lo cierran como Asistió si asistió o como No asistió si no asistió, sin usar Cancelado; el sistema muestra la causa no sancionable, no habilita multa y audita el cierre, actor, fecha y hora, los estados de entrega y la exclusión de multa. Para las transiciones por contacto, el actor registra una declaración simple del resultado sin evidencia ni canal, y el sistema audita el contacto, el intento fallido, la declaración, el actor, la fecha y hora y la transición.
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
| T0.9 | Metodología | **Puesta a punto de la Herramienta de Gestión (Jira / Trello):** Cargar todas las historias de usuario del backlog (módulos 1, 2, 3, 4 y 5) en el tablero ágil. Configurar las columnas del flujo de trabajo (Ej: To Do, In Progress, Code Review, Testing, Done). | N/A |
| T0.10 | Metodología | **Definición de “Definition of Done” (DoD):** Pactar el criterio unificado de cuándo una tarea está realmente terminada. Por ejemplo: “Código subido a develop + pasa pruebas de validación con los escenarios Dado que/Cuando/Entonces escritos + para las pantallas principales, cumple el percentil 95 de Rend-02 y RNF-05 cuando aplique + si implementa un flujo crítico, se prueba en la matriz de RD-02 + si implementa permisos críticos, cuenta con pruebas automatizadas de esos permisos.” | N/A |
| T0.11 | Seguridad | **Matriz de autorización:** Definir y revisar la matriz única exigida por RNF-08 antes de implementar módulos sensibles. | N/A |
| T0.12 | Seguridad | **Bootstrap inicial del Administrador:** Preparar el proceso único de despliegue que provisiona al primer Administrador sin credenciales predeterminadas, emite su invitación de un solo uso y registra los eventos exigidos por RF-23. | T0.4, T0.6 |

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

**Calidad y Metodología (Aseguramiento del Proceso Scrum)**
*   **Tarea 0.9: Puesta a punto de la Herramienta de Gestión (Jira / Trello)**
    Descripción: Cargar todas las historias de usuario del backlog (módulos 1, 2, 3, 4 y 5) en el tablero ágil. Configurar las columnas del flujo de trabajo (Ej: To Do, In Progress, Code Review, Testing, Done).
*   **Tarea 0.10: Definición de “Definition of Done” (DoD)**
    Descripción: Pactar el criterio unificado de cuándo una tarea está realmente terminada. Por ejemplo: “Código subido a develop + pasa pruebas de validación con los escenarios Dado que/Cuando/Entonces escritos + para las pantallas principales, cumple el percentil 95 de Rend-02 y RNF-05 cuando aplique + si implementa un flujo crítico, se prueba en la matriz de RD-02 + si implementa permisos críticos, cuenta con pruebas automatizadas de esos permisos.”
*   **Tarea 0.11: Matriz de autorización**
    Descripción: Definir y revisar la matriz única exigida por RNF-08 antes de implementar módulos sensibles.
*   **Tarea 0.12: Bootstrap inicial del Administrador**
    Descripción: Preparar el proceso único de despliegue que provisiona al primer Administrador sin credenciales predeterminadas, emite su invitación de un solo uso y registra los eventos exigidos por RF-23.

---

## Pila de tareas (Product Backlog) - Sprint 1

| ID Tarea | Categoría | Descripción Técnica | Dependencia Asociada |
|---|---|---|---|
| T1.1 | Autenticación | Login Interno con Segundo Factor de Autenticación (HU 7) | T0.4, T0.6, T0.12 |
| T1.2 | Gestión de Pacientes | Alta de Paciente y verificación telefónica (HU 1.1) | T1.1, T0.6 |
| T1.3 | Gestión de Profesionales | Alta de Profesional (HU 4.2) | T1.1, T0.6 |
| T1.4 | Gestión de Profesionales | Listar Profesionales (HU 4.1) | T1.3 |
| T1.5 | Configuración de Agenda | Editar Disponibilidad del Profesional (HU 3.2) | T1.3, T0.6 |
| T1.5.1 | Configuración de Agenda | Definir Tipos de Consulta (mínimo) (HU 3.3) | T1.3, T0.6 |
| T1.6 | Gestión de Turnos | Visualizar Turnos Internos del Profesional (HU 2.1) | T1.5, T1.2 |
| T1.6.1 | Gestión de Turnos | Crear primer turno por Secretaría (HU 2.5.2 mínimo) | T1.2, T1.3, T1.5, T1.5.1 |
| T1.7 | Gestión de Turnos | Crear Turno por Profesional (HU 2.2 / 2.5.3) | T1.6, T1.6.1, T1.2, T1.5.1 |
| T1.8 | Interfaces Externas | Notificación WhatsApp Post-Creación (RF-17 parcial) | T1.7, T1.2 |
| T1.9 | Calidad y Metodología | Tests E2E del Flujo Crítico Interno | Todas |
| T1.10 | Metodología | Puesta a Punto de Definition of Done (DoD) | N/A |

### Autenticación
**Tarea T1.1: Login Interno con Segundo Factor de Autenticación (HU 7)**
* **Descripción:** Implementar el flujo de activación y autenticación para usuarios internos del sistema (Administrador, Profesional y Secretaría). El primer Administrador será provisionado por T0.12 y deberá definir contraseña y enrolar TOTP mediante su invitación de un solo uso antes de quedar Activo. Un Administrador podrá crear cuentas de Profesional y Secretaría en Pendiente de activación; cada una deberá definir contraseña y enrolar TOTP mediante su invitación de un solo uso para pasar a Activa. Solo las cuentas Activas podrán iniciar sesión con correo, contraseña y TOTP válido. Cada nueva sesión deberá requerir contraseña, tendrá una duración máxima absoluta de 12 horas y se bloqueará tras 30 minutos de inactividad. En un dispositivo declarado confiable, el segundo factor podrá recordarse hasta 30 días; deberá requerirse nuevamente al vencer ese plazo, usarse un dispositivo nuevo, cambiarse el correo, la contraseña o la configuración de 2FA, o detectarse actividad sospechosa. El recordatorio no elimina la obligatoriedad de TOTP. Las acciones sensibles sobre credenciales, correo o TOTP requerirán reautenticación reciente. El sistema deberá rechazar accesos con credenciales inválidas y códigos incorrectos o expirados. Google OAuth será exclusivo de Pacientes y no integrará este flujo interno. El bootstrap, la emisión, el consumo y cada fallo de invitación, la configuración de contraseña, el enrolamiento TOTP y la activación deberán auditarse según RF-23. Esta tarea completa la implementación del requisito funcional RF-01 para usuarios internos.
* **Estimación:** 24 horas

### Gestión de Pacientes
**Tarea T1.2: Alta de Paciente (HU 1.1)**
* **Descripción:** Crear el endpoint POST /pacientes y la interfaz de registro correspondiente. Implementar validaciones obligatorias para: Nombre, Apellido, DNI, Fecha de nacimiento, Teléfono celular y Correo electrónico; el género y la obra social deberán permanecer opcionales. El sistema deberá garantizar la unicidad de DNI y correo electrónico, validar el formato del email y rechazar solicitudes que no cumplan las reglas definidas. El alta realizada por Secretaría deberá dejar el teléfono sin verificar, enviar un código de verificación y permitir su validación. La gestión interna del Paciente deberá permanecer habilitada mientras el teléfono no esté verificado, pero el envío de WhatsApp solo podrá habilitarse después de una verificación exitosa. El envío, la validación y los fallos de verificación deberán quedar auditados. Una vez completado correctamente el registro, el paciente deberá persistirse en la base de datos junto con su fecha de creación y quedar habilitado para futuras reservas de turnos. Esta tarea cubre completamente la Historia de Usuario 1.1 y satisface parcialmente el requisito RF-02.
* **Estimación:** 12 h base + reestimación pendiente del equipo

### Gestión de Profesionales
**Tarea T1.3: Alta de Profesional (HU 4.2)**
* **Descripción:** Crear el endpoint POST /profesionales y la pantalla administrativa para registrar profesionales. Validar los campos: Nombre, Apellido, DNI y Correo electrónico como obligatorios y únicos dentro del sistema. El género y la fecha de nacimiento no deberán solicitarse para este rol. El campo teléfono será opcional. Al registrarse, el profesional deberá quedar en estado Pendiente de activación y el sistema deberá emitir una invitación de un solo uso para definir contraseña y enrolar TOTP. Solo al completar ambos pasos, la cuenta pasará a Activa. Esta tarea implementa la Historia de Usuario 4.2 y contribuye al cumplimiento de RF-03 y RF-04.
* **Estimación:** 16 horas

**Tarea T1.4: Listar Profesionales (HU 4.1)**
* **Descripción:** Crear el endpoint GET /profesionales con soporte para paginación server-side. El listado deberá mostrar únicamente profesionales activos (sin fecha de cierre), permitir búsquedas por nombre y apellido, y aplicar filtros básicos definidos por negocio. La evaluación de rendimiento deberá referenciar el percentil 95 definido en Rend-02. Esta tarea cubre la Historia de Usuario 4.1.
* **Estimación:** 12 horas

### Configuración de Agenda
**Tarea T1.5: Editar Disponibilidad del Profesional (HU 3.2)**
* **Descripción:** Implementar el módulo que permita a los profesionales: Configurar horarios regulares de atención. Registrar ausencias. Bloquear días feriados. Definir la ventana temporal disponible para reservas futuras. Cuando la operación afecte turnos futuros activos, el sistema deberá detectar y mostrar todos los conflictos, impedir el guardado mientras existan turnos alcanzados y conservar intactos esos turnos hasta que sean reprogramados o cancelados uno por uno mediante los flujos ya definidos. Una vez aplicada la modificación sin conflictos, la disponibilidad deberá reflejarse inmediatamente en el calendario utilizado por los pacientes. Esta tarea implementa la Historia de Usuario 3.2 y el requisito RF-07.
* **Estimación:** 24 horas

**Tarea T1.5.1: Definir Tipos de Consulta (mínimo) (HU 3.3)**
* **Descripción:** Implementar el alta mínima de tipos de consulta para el Profesional autenticado. Cada tipo deberá registrar nombre, duración estimada en minutos y precio base, y quedar asociado exclusivamente a su perfil profesional. La creación de turnos deberá seleccionar uno de estos tipos y conservar en el turno un snapshot del nombre, la duración y el precio base vigentes al momento de crearlo, de modo que cambios posteriores en el catálogo no modifiquen turnos existentes. Esta tarea implementa el alcance mínimo de HU 3.3 y RF-08 necesario antes de T1.7.
* **Estimación:** 16 horas

### Gestión de Turnos
**Tarea T1.6: Visualizar Turnos del Profesional (HU 2.1)**
* **Descripción:** Crear el endpoint GET /turnos/hoy que retorne todos los turnos internos asignados al profesional autenticado para la fecha actual, independientemente de si fueron creados por Secretaría o por el Profesional. La vista deberá mostrar: Horario, Nombre del paciente, Tipo de consulta y Estado actual. Reservado indica que el turno está pendiente de confirmación de asistencia del Paciente y Confirmado indica que la asistencia fue confirmada. Al finalizar el horario previsto de un turno, la interfaz de cierre deberá presentar "Asistió" preseleccionado como opción predeterminada, pero requerirá confirmación expresa del actor antes de registrar el cierre. Si no existen turnos para la fecha solicitada, el sistema deberá informar la situación mediante un mensaje adecuado. Esta tarea cubre el alcance de HU 2.1 incluido en el Sprint 1.
* **Validación adicional:**
  * Comprobar que el profesional pueda registrar "No asistió" únicamente sobre turnos cuyo horario previsto ya finalizó.
  * Comprobar que el registro de "No asistió" quede auditado con actor, fecha y hora.
  * Comprobar que, al registrar "No asistió", el sistema no aplique multa de forma automática y deje la decisión explícita de multa para el Profesional.
* **Estimación:** 24 horas

**Tarea T1.6.1: Crear primer turno por Secretaría (HU 2.5.2 mínimo)**
* **Descripción:** Implementar el flujo interno mínimo para que Secretaría cree el primer turno entre cualquier Paciente registrado y un Profesional. Secretaría deberá poder buscar y seleccionar al Paciente sin requerir una relación previa con el Profesional, seleccionar el Profesional, un tipo de consulta asociado a ese Profesional y un horario disponible conforme a su disponibilidad y a la duración del tipo seleccionado. El sistema deberá validar la ausencia de superposición en la agenda del Profesional y para el Paciente y conservar en el turno el snapshot del nombre, la duración y el precio base vigentes del tipo de consulta. La reserva estándar creada por Secretaría no dependerá de la modalidad de aprobación del Profesional ni pasará por Solicitado: antes de D-1, Secretaría deberá elegir explícitamente Reservado, sujeto al flujo posterior de confirmación por WhatsApp, o Confirmado; durante D-1, solo podrá crear Confirmado. Para crear Confirmado deberá registrar una declaración simple de que el Paciente aceptó el horario, sin almacenar evidencia, grabación, comprobante ni canal del acuerdo. La elección de estado, la declaración cuando corresponda, el actor y la fecha y hora deberán quedar auditados. Al crear el turno, el sistema deberá establecer la relación Profesional–Paciente que habilita al Profesional a operar posteriormente con ese Paciente dentro del alcance de RF-05. Esta tarea implementa exclusivamente el bootstrap mínimo de HU 2.5.2: no incorpora reserva autónoma del Paciente ni aprobación profesional de HU 2.7.
* **Estimación:** 12 horas

**Tarea T1.7: Crear Turno por Profesional (HU 2.2 / 2.5.3)**
 * **Descripción:** Crear el endpoint POST /turnos para permitir que los profesionales registren manualmente nuevos turnos para Pacientes cuya relación con el Profesional haya sido creada previamente por T1.6.1. El backend deberá validar que el Profesional solo pueda seleccionar Pacientes ya vinculados con su perfil. Además, el sistema deberá validar: Disponibilidad del horario según la duración del tipo de consulta seleccionado. Ausencia de superposición de turnos. Que el paciente no posea otro turno en el mismo horario. Que el profesional únicamente opere sobre su propia agenda y seleccione un tipo de consulta asociado a su perfil. Al completarse correctamente la operación, el turno deberá conservar el snapshot de nombre, duración y precio base del tipo de consulta vigente al momento de crearlo, y crearse en estado Reservado si la creación ocurre antes de D-1, o en estado Confirmado si ocurre durante D-1; en el primer caso deberá mantener el flujo de confirmación definido por RF-10 y RF-17, y en el segundo no deberá usarlo. Esta tarea cubre parcialmente las Historias de Usuario 2.2 y 2.5.3.
* **Estimación:** 12 horas

### Interfaces Externas
**Tarea T1.8: Notificación WhatsApp Post-Creación (RF-17 parcial)**
 * **Descripción:** Al iniciar esta primera tarea consumidora de WhatsApp, configurar el entorno de pruebas del proveedor detrás de un límite o adaptador y mantener las credenciales fuera del repositorio. Implementar el envío de notificaciones automáticas solo a teléfonos verificados por T1.2. La notificación deberá enviarse automáticamente según el calendario definido por RF-17 y contener solo: nombre del centro, Profesional asignado, fecha, horario, consultorio o ubicación y la acción necesaria para confirmar, rechazar o responder al flujo aplicable. No deberá incluir DNI, tipo de consulta, pagos, montos, multas, estado financiero, comprobantes ni datos clínicos o sensibles. Los mensajes se registrarán únicamente en el entorno de pruebas hasta validar la estabilidad completa del flujo. Esta tarea implementa parcialmente RF-17 y acompaña el flujo de aprobación o reserva solo para turnos que no fueron creados o aprobados durante D-1. No aplica a turnos creados por Profesional durante D-1, que nacen Confirmado y omiten WhatsApp.
* **Estimación:** 8 horas

### Calidad y Metodología
**Tarea T1.9: Tests E2E del Flujo Crítico**
* **Descripción:** Automatizar los escenarios funcionales correspondientes a las historias implementadas en este sprint. La cobertura mínima deberá incluir: Alta de paciente. Verificación telefónica exitosa y fallida mediante código. Gestión interna de un Paciente con teléfono no verificado. Alta de profesional. Listado de profesionales. Configuración de disponibilidad. Alta de tipos de consulta con nombre, duración, precio base y asociación al Profesional. Creación del primer turno por Secretaría para cualquier Paciente registrado, con selección de Profesional, tipo de consulta y horario disponible, conservación del snapshot y creación de la relación Profesional–Paciente. El primer turno creado por T1.6.1 deberá aparecer en la agenda del Profesional mediante T1.6. Creación interna posterior de turnos por el Profesional únicamente para ese Paciente relacionado bajo RF-05. Visualización de esos turnos en estados Reservado y Confirmado. Notificación automática solo para teléfono verificado y ausencia de envío para teléfono no verificado. Además, deberán contemplarse los casos de error más relevantes: DNI duplicado. Email duplicado. Conflicto de agenda según la duración del tipo de consulta. Turnos simultáneos para un mismo paciente. Selección de un tipo de consulta no asociado al Profesional. Rechazo en backend del intento del Profesional de operar sobre un Paciente sin relación previa. Los flujos críticos deberán probarse según la matriz de navegadores definida en RD-02. Los tests deberán ejecutarse automáticamente en el pipeline de integración continua.
* **Estimación:** 12 horas

### Metodología
**Tarea T1.10: Puesta a Punto de Definition of Done (DoD)**
* **Descripción:** Crear la plantilla de Pull Request del proyecto, configurar GitHub Actions para la ejecución automática de linting y pruebas, y documentar el flujo de trabajo oficial del repositorio. La documentación deberá incluir: Creación de ramas. Convenciones de commits. Pull Requests. Code Reviews. Proceso de merge a develop. Esta tarea consolida la Definition of Done acordada durante el Sprint 0.
* **Estimación:** 4 horas

---

## Resumen del Sprint
Este Sprint entrega el primer flujo interno funcional del sistema Origen: un administrador registra profesionales, los profesionales se autentican y configuran su disponibilidad y sus tipos de consulta. Secretaría registra Pacientes con teléfono inicialmente no verificado y puede gestionarlos internamente; el teléfono se verifica mediante código antes de habilitar el envío de WhatsApp. Secretaría crea el primer turno para cualquier Paciente registrado, seleccionando Profesional, tipo de consulta y horario disponible; esa operación establece la relación Profesional–Paciente. Desde esa relación, el Profesional consulta su agenda diaria y crea turnos posteriores dentro de RF-05, con notificación automática mediante WhatsApp (entorno de pruebas) solo a teléfonos verificados. Cada turno creado conserva el nombre, la duración y el precio base vigentes de su tipo de consulta.
Carga conocida del Sprint 1: 176 h base. El total final queda pendiente de la reestimación de T1.2 por verificación telefónica.

| Integrante | Tareas | Carga base / pendiente |
|---|---|---|
| Santiago Casali | T1.1, T1.3 | 40 h base |
| Lucca Giordana | T1.2, T1.4, T1.6.1 | 36 h base + incremento pendiente por reestimación de T1.2 |
| Said Quioto | T1.5, T1.5.1, T1.6, T1.7 | 76 h base |
| Samuel Olmos | T1.8, T1.9 | 20 h base |
| Equipo completo | T1.10 | 4 h base |
| **Total** | — | **176 h base + total final pendiente de reestimación de T1.2** |

**Alcance diferido:** La reserva autónoma del Paciente (HU 2.5.1) y la aprobación profesional (HU 2.7) se abordarán como un bloque conjunto fuera del Sprint 1.

**Cadena crítica del demo:** T1.2, T1.3, T1.5 y T1.5.1 convergen en T1.6.1 para crear el primer turno por Secretaría y establecer la relación Profesional–Paciente. T1.6 y T1.6.1 convergen en T1.7, que permite al Profesional crear turnos posteriores únicamente para Pacientes relacionados bajo RF-05; luego continúa T1.8. T1.5.1 debe completarse antes de la creación de turnos para que cada turno use la duración del tipo de consulta y conserve su snapshot.

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
