# ORIGEN - CENTRO DE SALUD

## INFORME DE DECISIONES DE ARQUITECTURA DE SOFTWARE

### SISTEMA DE GESTIÓN DE TURNOS

**HECHO POR:** CASALI | GIORDANA | OLMOS | QUIOTO

---

## 1. Introducción

### 1.1. Propósito

El propósito de este documento es definir los requisitos funcionales y no funcionales para el sistema "Origen", incluida la gestión de turnos, la seguridad de credenciales internas y las comunicaciones no clínicas posteriores a consultas. Está dirigido a los desarrolladores, al equipo de pruebas y a los interesados del centro de salud.

### 1.2. Ámbito del sistema

El sistema, denominado "Origen", es una plataforma web diseñada para la gestión operativa y administrativa de turnos, la comunicación con pacientes —incluidas las Notas de devolución no clínicas y los avisos por WhatsApp— y la administración financiera básica. No procesa, cobra, transfiere ni devuelve dinero real: los pagos, multas, saldos a favor, compensaciones y devoluciones externas son registros administrativos declarados por usuarios autorizados.

* **Lo que hará:** Permitir la reserva de turnos, gestión de agendas profesionales, publicación web de Notas de devolución no clínicas posteriores a consultas atendidas, envío de notificaciones automáticas, gestión segura de credenciales internas, registro de auditoría y consulta de historial operativo de turnos.
* **Lo que no hará:** No almacenará ni mostrará historia clínica, seguimiento o evolución clínica, indicaciones clínicas, diagnósticos, prescripciones, dosis de medicamentos, resultados de estudios ni notas clínicas. Las Notas de devolución admitidas por este documento son comunicaciones no clínicas y no se gestionan como historia clínica, receta, certificado ni documento formal. No integrará pasarelas de pago ni bancos; los comprobantes serán evidencia para validación manual, no confirmación bancaria automática, y los reportes no serán factura, recibo fiscal, contabilidad legal ni conciliación bancaria.

### 1.3. Definiciones, acrónimos, abreviaturas

* **Passwordless:** Método de autenticación que no requiere una contraseña almacenada.
* **ERS:** Especificación de Requisitos de Software.
* **Log:** Registro cronológico de operaciones del sistema.
* **Sobreturno:** Turno asignado fuera de la disponibilidad regular ante situaciones excepcionales o necesidades operativas.
* **Persona:** Identidad única del dominio, preservada mediante un identificador interno inmutable y distinguida en el negocio por la combinación de tipo de documento controlado y número de documento normalizado.
* **Perfil:** Proyección de una Persona para operar como Paciente o Profesional. Una Persona puede acumular varios roles y perfiles sin duplicar su identidad ni su historial.
* **Cuenta de acceso:** Identidad de autenticación separada de la Persona y de sus perfiles. Su correo electrónico es único entre cuentas de acceso y puede pertenecer a cualquier proveedor.
* **Representación:** Relación explícita, activa o inactiva, auditable y limitada a perfiles de Paciente, por la cual un Paciente registrado puede operar sobre el perfil de otro Paciente.
* **Documento de identidad:** Combinación de un tipo perteneciente al catálogo controlado —DNI, pasaporte, cédula/tarjeta de identidad u Otro— y un número normalizado. No incluye país emisor ni admite variantes libres del tipo.
* **Estado de credencial:** Condición de autenticación de una cuenta interna, separada de su estado administrativo. `Recuperación pendiente` bloquea la autenticación aunque la cuenta permanezca administrativamente Activa.
* **Dispositivo confiable:** Dispositivo al que la política global de sesiones internas permite recordar temporalmente la validación TOTP. Nunca sustituye la contraseña de una nueva sesión ni la reautenticación reforzada exigida por un flujo sensible.
* **Tipo de consulta:** Prestación identificada de forma inmutable —nunca por su nombre, aunque existan nombres duplicados— y perteneciente a un único Profesional, que define su nombre, precio base exacto en ARS, color actual, estado y cantidad de Intervalos de agenda. Mientras está inactiva no puede editarse y conserva la duración histórica que tenía al desactivarse.
* **Intervalo de agenda:** Granularidad temporal propia de la agenda de un Profesional, expresada en minutos, a partir de la cual se obtiene la duración vigente de sus Tipos de consulta activos sin alterar la cantidad de intervalos, la duración histórica de los inactivos ni los turnos ya reservados.
* **Período:** Ventana de anticipación futura durante la cual pueden reservarse turnos. No representa la granularidad ni la duración de la agenda.
* **Nota de devolución:** Comunicación no clínica dirigida al Paciente y vinculada a una consulta atendida, creada por el Profesional asociado. Origen no la gestiona como historia clínica, receta, certificado ni documento formal.
* **Nota profesional privada:** Registro futuro, visible exclusivamente para su Profesional autor y separado de la Nota de devolución. No comparte con ella entidad, indicador de visibilidad, conversión, copia ni sincronización.

### 1.4. Referencias

* IEEE Std 830-1998: Recommended Practice for Software Requirements Specifications.
* Documentación oficial de la API de WhatsApp Business Platform.
* Documentación oficial de autenticación OAuth 2.0 de Google.

### 1.5. Visión general del documento

El documento se divide en: Descripción general del contexto (Sección 2) y Requisitos específicos detallados (Sección 3), incluyendo funciones por rol y atributos de calidad.

---

## 2. Descripción general

### 2.1. Perspectiva del producto

El sistema constituye una solución de software independiente orientada a la gestión de turnos, los accesos internos reforzados y las comunicaciones no clínicas posteriores a consultas en centros de salud. Si bien opera de manera autónoma respecto de otros sistemas institucionales, requiere integración con servicios externos de autenticación y mensajería, tales como Google OAuth para autenticar cuentas de acceso por correo electrónico, correo electrónico para credenciales y avisos de seguridad, y WhatsApp para el envío automatizado de notificaciones a Pacientes.

### 2.2. Funciones del producto

El sistema cumplirá con las siguientes funciones principales:

* **Gestión de accesos:** Cuentas de acceso separadas de las Personas y sus perfiles, autenticación passwordless para Pacientes, autenticación reforzada para usuarios internos, selección de perfil de Paciente y control de los roles Administrador, Profesional, Secretaría y Paciente.
* **Seguridad de credenciales internas:** Activación, cambio autenticado de contraseña, recuperación administrativa de contraseña o TOTP y política global de sesiones con invalidación y auditoría de accesos.
* **Control de Agenda:** Configuración de horarios, ausencias y tipos de consulta con costos variables.
* **Portal de Reservas:** Interfaz interactiva para que el paciente seleccione y gestione sus turnos.
* **Devolución no clínica:** Creación y publicación web de comunicaciones no clínicas posteriores a consultas con estado Asistió, visibles únicamente para su Profesional autor y el perfil de Paciente correspondiente.
* **Automatización:** Notificaciones por WhatsApp y máquina de estados para el ciclo de vida del turno.
* **Administración:** Gestión de lista de espera por profesional con modo automático o manual, trazabilidad de ofertas y respuestas, y módulo de validación de pagos.

### 2.3. Características de los usuarios

* **Administrador:** Usuario interno con cuenta propia, responsable de gestionar cuentas, accesos, recuperación autorizada de credenciales de Profesional y Secretaría y operaciones de identidad reforzadas, sin acceder a los secretos ni a las Notas de devolución mediante la interfaz de producto.
* **Profesional:** Usuario interno con cuenta propia, responsable de gestionar su agenda, disponibilidad, atención administrativa y Notas de devolución no clínicas asociadas a los turnos de sus Pacientes permitidos.
* **Secretaría:** Usuario interno con cuenta propia, encargado de asistir en la administración operativa del sistema, incluyendo gestión de turnos, identidades, accesos y validaciones autorizadas.
* **Paciente:** Usuario externo con niveles variables de alfabetización digital. Puede operar su perfil propio y, mediante relaciones activas de representación, uno o más perfiles de Paciente representados; la representación no constituye un rol adicional.

### 2.4. Restricciones

* Los pacientes podrán cancelar turnos voluntariamente hasta el límite de cancelación configurado por el perfil profesional. La configuración predeterminada habilita la cancelación hasta las 23:59 del día D-1.
* El sistema deberá garantizar la privacidad de los datos personales de pacientes y profesionales.
* El sistema deberá implementar mecanismos de seguridad y control de acceso acordes a cada rol de usuario, incluyendo la protección criptográfica obligatoria de los datos actuales y de los módulos futuros que almacenen información sensible.

### 2.5. Suposiciones y dependencias

Se asume que los usuarios finales disponen de una conexión a internet estable. Para recibir notificaciones por WhatsApp, cada perfil de Paciente deberá tener seleccionado un único destinatario primario —el propio Paciente o su representante activo— con teléfono verificado. El sistema depende de la disponibilidad operativa de la API de WhatsApp y, para el flujo de Google OAuth, de los servicios de autenticación de Google.

### 2.6. Requisitos futuros

Como evolución funcional futura, se contempla la incorporación de un módulo de registro de Notas profesionales privadas cifradas, destinado al almacenamiento privado de observaciones individuales realizadas por cada Profesional. Esta funcionalidad no forma parte del alcance de la versión actual del sistema, pero ha sido acordada como una extensión posterior con el cliente. La Nota profesional privada y la Nota de devolución son entidades y funcionalidades diferentes: la primera será privada del Profesional y futura; la segunda es una comunicación no clínica dirigida al Paciente dentro del alcance actual. No compartirán indicador de visibilidad ni admitirán conversión, copia o sincronización entre sí.

La estrategia de backups y recuperación no bloquea el desarrollo, prototipo ni demo sin datos reales y no forma parte del Sprint 1 actual. Será obligatoria antes de producción o de almacenar datos reales de Pacientes.

La política de solicitud de eliminación o anonimización y de conservación obligatoria de datos personales de Pacientes queda pendiente de validación legal. La retención de las Notas de devolución seguirá esa futura política general de datos personales: hasta su validación no habrá eliminación automática y retirar una Nota no equivaldrá a eliminarla. La retención del log de auditoría también queda pendiente de validación legal y contable y de aprobación del cliente; provisionalmente no habrá eliminación automática del log. Antes de producción, el cliente deberá aprobar qué datos se eliminan, anonimizan o conservan y durante cuánto tiempo, así como el plazo y la conducta de conservación o eliminación del log considerando los datos personales, la seguridad y los registros financieros. Hasta esas aprobaciones no habrá borrado ni anonimización automática de datos personales ni eliminación automática del log, y la salida a producción quedará bloqueada.

---

## 3. Requisitos Específicos

### 3.1. Interfaces externas

* **RIE-01:** Interfaz con API de WhatsApp para envío de recordatorios y avisos permitidos.
* **RIE-02:** Interfaz de autenticación con Google OAuth. Las cuentas de acceso no estarán restringidas a direcciones de Gmail.
* **RIE-03:** Interfaz con un servicio de correo electrónico para invitaciones, recuperación de credenciales y avisos de seguridad dirigidos al correo verificado vigente.

### 3.2. Funciones

#### 3.2.1 Gestión de Usuarios y Roles

* **RF-01: Autenticación Mixta y Control de Acceso:** El sistema deberá separar la cuenta de acceso de la Persona y de sus perfiles. Cada cuenta de acceso se identificará por un correo electrónico único entre cuentas, válido y perteneciente a cualquier proveedor. El acceso de Pacientes será passwordless mediante Google OAuth o Magic Link; ambos mecanismos autenticarán la cuenta por su correo electrónico. Después de autenticarse, el usuario deberá seleccionar uno de los perfiles de Paciente vinculados a su cuenta —el propio o uno representado— antes de utilizar funciones del sistema. El nombre completo del Paciente seleccionado deberá permanecer visible como contexto activo, por ejemplo, «Estás gestionando a…». El usuario podrá volver al selector y cambiar de perfil dentro de la misma sesión sin solicitar otro Magic Link ni repetir Google OAuth; cada selección y cambio deberá quedar auditado. Al cerrar la sesión, un acceso posterior requerirá una nueva autenticación. Si el correo ya identifica una cuenta de acceso, el sistema abrirá exclusivamente sus perfiles vinculados. Si el correo es nuevo y el tipo y número normalizado de documento proporcionados no identifican a ninguna Persona, el sistema podrá crear una cuenta de acceso y un perfil propio de Paciente en estado **Pendiente de completar**. Si esa identidad documental ya existe, el sistema no creará otra Persona ni vinculará automáticamente el acceso por documento, fecha de nacimiento o coincidencias de datos; derivará el caso a Secretaría para verificación externa de identidad y otorgamiento explícito del acceso. Google OAuth será exclusivo de Pacientes y no proveerá el segundo factor de los usuarios internos. El primer Administrador deberá provisionarse mediante un proceso único de despliegue, sin credenciales predeterminadas, y recibirá una invitación de un solo uso para definir su contraseña y enrolar TOTP; solo entonces quedará Activo. Luego, un Administrador podrá crear cuentas propias de Profesional o Secretaría en estado **Pendiente de activación**; cada cuenta requerirá correo electrónico válido y único, sin restricción de proveedor, contraseña y TOTP. En cada nueva sesión interna se deberá ingresar la contraseña; en un dispositivo declarado confiable, el segundo factor podrá recordarse hasta 30 días sin dejar de ser obligatorio, conforme a RNF-09.
* **RF-02: Personas, perfiles y registro:** Cada Persona deberá conservar un identificador interno único e inmutable al que permanecerán asociados todos sus turnos, comprobantes, pagos, historiales y demás registros. La unicidad de negocio de la Persona será la combinación de tipo de documento controlado y número de documento normalizado. El catálogo de tipos deberá incluir DNI, pasaporte, cédula/tarjeta de identidad y Otro; no deberá solicitar país emisor ni aceptar variantes libres. Una Persona podrá acumular los roles existentes bajo la misma identidad y no deberá duplicarse por rol. Antes de que Secretaría cree o gestione de forma asistida el primer turno de un Paciente, deberá registrar o reutilizar su Persona y perfil con exactamente estos datos de identidad mínima: nombres, apellidos, tipo de documento controlado, número de documento normalizado y fecha de nacimiento. El género será opcional. El correo electrónico pertenecerá a la cuenta de acceso y no será un dato obligatorio del perfil: un Paciente representado podrá carecer de cuenta y correo propios. Para un Profesional, Administrador deberá registrar o reutilizar la Persona por su identidad documental, asignarle el perfil y rol Profesional y crearle una cuenta propia con correo electrónico válido y único. Una colisión documental deberá impedir la creación de otra Persona y conducir a reutilizar la identidad existente cuando corresponda asignar un nuevo rol, sin perder su historial.
  Un perfil de Paciente podrá quedar **Pendiente de completar**. Secretaría podrá asignarle turnos mientras esté incompleto. Un Profesional podrá asignar o gestionar turnos de ese Paciente mientras esté incompleto únicamente si ya pertenece a su lista permitida conforme a RF-05. El perfil no podrá efectuar reservas autónomas hasta completar los datos requeridos y verificar el teléfono del destinatario primario de notificaciones seleccionado. Al crear una representación, nombres, apellidos, tipo y número de documento y fecha de nacimiento serán campos verificados y controlados por personal autorizado; el representante podrá completar teléfono, género opcional y otros campos no identitarios, pero no modificará esos campos de identidad.
* **RF-02 bis: Representación de Pacientes:** Toda representación deberá ser una relación explícita, activa o inactiva, limitada a perfiles de Paciente y auditable. El representante deberá ser una Persona ya registrada como Paciente; la relación otorgará permisos por alcance y no creará un rol `Representante` ni una cuenta sin rol. Un Profesional no podrá representar a otro Profesional, y Profesional y Secretaría siempre deberán acceder mediante sus propias cuentas internas. Cada Paciente representado tendrá como máximo un representante activo, mientras que un representante podrá representar a varios Pacientes. Secretaría podrá activar, revocar o reemplazar la representación de cualquier Paciente registrado. Un Profesional solo podrá hacerlo para Pacientes incluidos en su lista permitida y no podrá navegar el registro global. Antes de activar la relación, el personal deberá verificar externamente la identidad y autoridad del representante y registrar el tipo de relación, el actor interno, la fecha y hora del servidor y una declaración simple de que realizó la verificación. El sistema no solicitará ni almacenará fotografías o copias de documentos legales; las reglas de evidencia legal quedan pendientes de validación antes de producción. El reemplazo deberá desactivar la relación anterior y activar la nueva en una única operación atómica, sin permitir dos representantes activos ni estados intermedios inconsistentes. La activación, revocación o sustitución deberá enviar avisos de seguridad a las cuentas afectadas por canales verificados y auditar tanto el éxito como el fallo. La representación no tendrá reglas automáticas por edad, vencimiento, notificación ni transición: una persona menor de 18 años podrá gestionar su cuenta con correo verificado, una adulta podrá continuar representada y el acceso independiente podrá coexistir con la representación. Agregar o cambiar la cuenta o el correo propio del representado no revocará la relación; el personal deberá revocarla por separado.
  La ausencia de notificaciones automáticas se refiere a recordatorios o transiciones del ciclo de representación por edad o paso del tiempo; no elimina los avisos de seguridad obligatorios que responden a una activación, revocación o sustitución explícita.
* **RF-02 ter: Teléfono y destinatario de notificaciones:** Cada perfil de Paciente deberá tener exactamente un destinatario primario de notificaciones seleccionado explícitamente: el propio Paciente o su representante activo. El personal deberá elegirlo al activar la representación; si el Paciente no posee teléfono verificado, deberá seleccionar al representante. El sistema enviará cada mensaje una sola vez al teléfono verificado del destinatario elegido y no lo duplicará para ambas personas. Cuando el destinatario sea el representante, utilizará el teléfono verificado de este sin copiarlo en los perfiles representados. El Paciente podrá registrar y verificar posteriormente su teléfono propio y ser seleccionado como destinatario sin perder historial ni revocar la representación. Al iniciar un cambio del teléfono actualmente seleccionado, el sistema suspenderá de inmediato las automatizaciones y WhatsApp al número anterior; el nuevo número no recibirá mensajes ni habilitará reservas autónomas hasta validar el código enviado. Mientras la validación esté pendiente, los turnos próximos quedarán señalados para revisión manual de Profesional y Secretaría. El alta, la selección, el cambio, la verificación y los fallos deberán quedar auditados.
* **RF-03: Cambios de correo electrónico:** Solo Secretaría o Administrador podrán iniciar un cambio de correo electrónico de una cuenta de acceso. Secretaría podrá iniciarlo únicamente para cuentas con acceso a perfiles de Paciente; Administrador podrá iniciarlo para cualquier cuenta. Paciente y Profesional no podrán iniciar el cambio. El correo anterior permanecerá activo hasta que el nuevo, que deberá ser único entre cuentas y podrá pertenecer a cualquier proveedor, sea verificado correctamente; ningún actor interno podrá activar un correo no verificado. El sistema deberá notificar el proceso a los canales verificados anteriores y auditar por separado su inicio, verificación, activación y fallos. La operación modificará únicamente el correo o vínculo de acceso y conservará la Persona, sus perfiles y todo su historial. No habrá cambios automáticos por edad: la Persona deberá solicitar la gestión a Secretaría. Para recuperar credenciales internas cuando el correo vigente sea inaccesible deberá completarse primero un procedimiento reforzado y separado de cambio de correo, conforme a RF-01 quater.
* **RF-03 bis: Corrección de documento de identidad:** Solo Secretaría o Administrador podrán corregir el tipo o número de documento de una Persona mediante una operación reforzada que exija reautenticación reciente con TOTP válido, un motivo obligatorio, una declaración de verificación externa de identidad y validación de unicidad. El sistema deberá conservar en auditoría los valores anteriores y nuevos, el actor y la fecha y hora del servidor. Paciente, el Paciente que actúe como representante y Profesional no podrán efectuar la corrección. Si la identidad corregida colisiona con otra Persona, el sistema deberá bloquear la operación y no fusionará, sobrescribirá ni transferirá historial; la resolución de duplicados será un proceso futuro separado. Una corrección válida conservará sin cambios el identificador interno inmutable de la Persona y todos sus registros históricos.
* **RF-04: Roles:** El sistema deberá implementar control de acceso para los roles Administrador, Profesional, Secretaría y Paciente. Una Persona podrá acumular varios de estos roles sin duplicarse. No se creará un rol adicional de representante: la representación activa solo ampliará el alcance con el que un Paciente registrado opera sobre otro perfil de Paciente. El primer Administrador se incorporará exclusivamente mediante el proceso único de despliegue definido en RF-01. Un Administrador podrá crear cuentas de Profesional y Secretaría, que permanecerán en **Pendiente de activación** hasta completar la definición de contraseña y el enrolamiento TOTP mediante su invitación de un solo uso; solo entonces quedarán **Activas**.
* **RF-05: Aislamiento y visibilidad Profesional–Paciente:** El sistema deberá restringir en backend e interfaz la selección y visualización del Profesional a los Pacientes de su lista permitida y a los registros operativos de turnos vinculados con su propia relación. Un Paciente autenticado podrá reservar de forma autónoma su primera cita con un Profesional sin intervención de Secretaría ni relación previa, siempre que el perfil propio seleccionado esté completo, el teléfono del destinatario primario esté verificado y se cumplan la disponibilidad, las reglas de estado de RF-10 y las demás validaciones aplicables. Como alternativa, Secretaría podrá registrar o reutilizar la Persona y el perfil de Paciente y crear de forma asistida esa primera cita, incluso cuando el perfil esté incompleto conforme a RF-02. Únicamente el almacenamiento exitoso de un primer turno válido establecerá de forma auditable la relación de visibilidad y agregará al Paciente a la lista permitida del Profesional; un intento, clic, solicitud denegada o fallo de persistencia no creará relación alguna. El turno, la relación, las copias históricas aplicables y la auditoría deberán guardarse atómicamente. Desde entonces, el Profesional podrá asignar y gestionar turnos de ese Paciente, incluso si el perfil permanece incompleto, sin obtener acceso a relaciones con otros Profesionales. El Profesional no podrá crear turnos para Pacientes todavía no relacionados ni navegar, listar o consultar el registro global de Pacientes. Los intentos fuera de alcance deberán denegarse en el backend y auditarse.
* **RF-06: Privacidad y alcance de Secretaría:** Secretaría podrá listar y buscar a todos los Pacientes del centro y tendrá acceso de lectura y escritura a sus datos generales y de contacto para la gestión operativa. Podrá iniciar cambios de correo solo para cuentas con acceso de Paciente, gestionar teléfonos y destinatarios, corregir documentos mediante RF-03 bis y gestionar representaciones mediante RF-02 bis. No podrá modificar correos de Profesional, Administrador u otra Secretaría ni acceder a información sensible ajena a la gestión de turnos. Los campos de identidad verificados y las relaciones de representación solo podrán modificarse mediante sus operaciones reforzadas específicas, no mediante una edición general del perfil.
* **RF-06 bis: Autorización del representante:** Una cuenta con representación activa podrá ejecutar sobre el perfil representado todas las operaciones ordinarias de Paciente: reservar y cancelar turnos, confirmar asistencia, gestionar la participación en listas de espera, consultar el historial operativo de turnos y cargar o visualizar los comprobantes aplicables. No podrá modificar campos de identidad verificados, correo electrónico, credenciales ni relaciones de representación. Cada operación deberá registrar a la Persona propietaria de la cuenta de acceso como actor y al Paciente representado como sujeto o propietario del registro. El backend deberá comprobar en cada solicitud que la relación esté activa y dentro de su alcance; ante ausencia, revocación o inconsistencia deberá denegar por defecto y auditar el intento.

##### Credenciales internas — extensiones de RF-01

* **RF-01 bis: Contraseñas y TOTP internos:** Toda contraseña definida durante activación, cambio autenticado o recuperación deberá tener entre 12 y 128 caracteres, admitir espacios y frases de contraseña, rechazar valores comunes o comprometidos e impedir reutilizar la contraseña vigente. No se impondrán reglas de composición ni vencimiento periódico. TOTP deberá utilizar una aplicación autenticadora, un secreto único por cuenta cifrado en reposo, códigos de seis dígitos e intervalos de 30 segundos; solo se aceptarán el intervalo actual y el inmediatamente anterior, y un código ya validado con éxito no podrá reutilizarse. El enrolamiento exigirá confirmar un código válido antes de activar la cuenta. No existirán códigos de recuperación de respaldo. Los secretos y códigos TOTP nunca se mostrarán al Administrador ni se registrarán en logs o auditoría.
* **RF-01 ter: Cambio autenticado de contraseña:** Profesional y Secretaría podrán cambiar su propia contraseña desde una sesión autenticada; Administrador queda fuera de este flujo de autoservicio. La operación exigirá la contraseña vigente y un TOTP vigente aunque el dispositivo sea confiable. Al guardar una nueva contraseña válida, el sistema invalidará inmediatamente todas las sesiones —incluida la actual— y todos los dispositivos confiables, bloqueará el uso de la contraseña anterior, conservará el TOTP existente y enviará un aviso de seguridad al correo verificado vigente. El acceso siguiente exigirá la contraseña nueva y TOTP.
* **RF-01 quater: Recuperación administrativa de credenciales internas:** La recuperación se aplicará únicamente a cuentas administrativamente Activas de Profesional y Secretaría; la recuperación del Administrador queda fuera de alcance. Una cuenta Pendiente de activación utilizará la reemisión de invitación y una cuenta inactiva deberá reactivarse antes. Toda solicitud deberá iniciarse fuera de la aplicación, aun si existe una sesión, y el Administrador verificará la identidad presencialmente o mediante un canal laboral registrado previamente, dejando declaración y canal de verificación. Para autorizar y emitir la recuperación, reemitirla o cancelarla, el Administrador deberá reautenticarse con contraseña y TOTP dentro de los cinco minutos anteriores y registrar un motivo obligatorio; un dispositivo confiable no sustituirá estos factores. Desde la autorización, la cuenta conservará el estado administrativo Activa, pasará al estado de credencial `Recuperación pendiente`, invalidará inmediatamente todas sus sesiones y dispositivos confiables y quedará bloqueada para autenticación. El Administrador nunca accederá al enlace, token, contraseña nueva ni secreto TOTP.
  Para recuperar solo la contraseña, el sistema enviará un enlace opaco de un solo uso al correo verificado vigente. El enlace vencerá a los 30 minutos según la hora del servidor; una reemisión invalidará todos los anteriores. Abrirlo o enviar una contraseña que incumpla la política no lo consumirá; se consumirá únicamente al guardar con éxito una contraseña válida junto con el TOTP vigente, exigido aunque el dispositivo hubiera sido confiable. Se admitirán como máximo cinco envíos fallidos: el quinto invalidará el enlace sin bloquear administrativamente la cuenta. El vencimiento o la cancelación mantendrán bloqueada la autenticación y la contraseña anterior seguirá inutilizable. La finalización conservará el TOTP existente, enviará un aviso de seguridad al correo verificado vigente y exigirá iniciar una sesión nueva con contraseña nueva y TOTP.
  Si el correo verificado vigente es inaccesible, deberá completarse primero un procedimiento reforzado y separado de cambio de correo; ningún enlace se enviará a una dirección alternativa ni se notificará automáticamente por un canal secundario. El correo de emisión y el de finalización se enviarán únicamente al correo verificado vigente y no contendrán secretos salvo el enlace aplicable en el mensaje de emisión.
* **RF-01 quinquies: Recuperación de TOTP interno:** Cuando se conserve la contraseña, el titular deberá contactar por fuera de la aplicación y se aplicarán la misma verificación de identidad, reautenticación reciente del Administrador, motivo, enlace de un solo uso y vencimiento de 30 minutos definidos en RF-01 quater; toda reemisión invalidará los enlaces anteriores. Al autorizar, el sistema invalidará inmediatamente el TOTP anterior, todas las sesiones y dispositivos confiables y bloqueará la autenticación. Mediante el enlace, el titular deberá ingresar la contraseña vigente, enrolar y confirmar un TOTP nuevo; los secretos anterior y nuevo nunca podrán estar válidos simultáneamente. Si se perdieron contraseña y TOTP, la verificación será exclusivamente presencial y el enlace permitirá definir atómicamente una contraseña conforme a RF-01 bis y enrolar y confirmar el TOTP nuevo; la cuenta permanecerá bloqueada hasta que ambos pasos finalicen con éxito. En ambos casos, el Administrador nunca verá el secreto y el sistema avisará al correo verificado vigente al iniciar y completar la recuperación, sin incluir secretos salvo el enlace de emisión aplicable.

#### 3.2.2 Configuración de Agenda

* **RF-07: Disponibilidad:** El sistema deberá proporcionar un módulo de configuración que permita establecer y modificar horarios de atención regulares, registrar ausencias, bloquear días feriados y definir la ventana de tiempo (rango de meses o días) disponible para la reserva futura de turnos. Cuando una modificación de disponibilidad, una ausencia o un bloqueo afecte turnos futuros activos, el sistema deberá detectar y mostrar todos los turnos alcanzados por el conflicto, impedir el guardado mientras existan conflictos y mantener sin cambios esos turnos hasta que cada uno sea reprogramado o cancelado individualmente por los flujos ya definidos. El sistema no deberá mover, cancelar ni modificar automáticamente ningún turno afectado.
* **RF-08: Tipos de consulta e Intervalo de agenda:** Cada Profesional deberá poseer un único Intervalo de agenda, con valor predeterminado de 30 minutos y valores válidos entre 5 y 240 minutos inclusive, en incrementos de 5 minutos. Cada Tipo de consulta deberá conservar una identidad inmutable y pertenecer a un único Profesional; sus datos modificables mientras esté activo serán el estado activo o inactivo, un nombre obligatorio normalizado de hasta 32 caracteres, un precio base exacto en ARS no negativo —incluido cero— y con hasta dos decimales, un color actual con formato `#RRGGBB` y una cantidad de Intervalos de agenda. No deberá imponerse un máximo comercial a un precio válido que pueda representarse exactamente. Podrán coexistir nombres normalizados duplicados; el nombre no será identidad y las acciones deberán vincularse al identificador inmutable, aunque la presentación podrá distinguirlos mediante nombre, duración en minutos y precio. La cantidad válida de un tipo activo estará comprendida entre 1 y `min(10, floor(180 / intervalo_en_minutos))`; su duración vigente será esa cantidad multiplicada por el Intervalo de agenda y nunca superará tres horas.
  La desactivación deberá conservar la identidad, las referencias históricas, la cantidad de intervalos y la duración que el Tipo de consulta tenía al desactivarse. Un tipo inactivo no podrá editarse, podrá mostrarse mediante `Mostrar consultas inactivas` y podrá reactivarse, pero no estará disponible para reservas nuevas. Su desactivación no modificará los turnos ya reservados. Al crear un turno, deberán conservarse como copias históricas su nombre normalizado, su duración resultante en minutos y su precio base exacto vigentes; la cantidad de intervalos y el color no deberán copiarse. Los cambios posteriores del catálogo o del Intervalo de agenda no deberán modificar esas copias históricas ni la duración histórica de los tipos inactivos. Los turnos deberán utilizar el color actual del Tipo de consulta incluso después de editarlo o desactivarlo. Toda presentación deberá conservar el contraste WCAG AA aplicable y ofrecer una señal adicional al color.
  Al seleccionar un nuevo Intervalo de agenda, el sistema deberá advertir que cambiarán las duraciones de los tipos activos. Cada tipo activo conservará su cantidad de intervalos y recalculará su duración con el nuevo intervalo, sin reemplazos ni adaptación individual. Si alguna duración resultante supera tres horas, la aplicación deberá bloquearse sin modificar el intervalo ni el catálogo y deberá identificar todos los tipos bloqueantes de forma inequívoca, manteniendo registros y acciones vinculados a sus identidades inmutables. Si ninguna supera tres horas, el Profesional deberá confirmar explícitamente mediante `Aplicar intervalo` y el cambio se aplicará atómicamente. Al reactivar un tipo inactivo, su duración activa volverá a derivarse de su cantidad preservada y del Intervalo de agenda vigente; si supera tres horas, la reactivación se rechazará sin cambios, identificará el tipo y no ofrecerá reemplazo ni adaptación.
  La disponibilidad y la lista de espera deberán identificar el Tipo de consulta activo por su identidad inmutable y Profesional propietario, y exigir suficientes Intervalos de agenda contiguos para su duración vigente; otro tipo con el mismo nombre no deberá considerarse equivalente. Solo un Profesional autenticado, activo, expresamente autorizado y propietario podrá modificar su propio Intervalo de agenda o crear, editar, desactivar o reactivar sus Tipos de consulta. La selección para un turno deberá estar autorizada por su regla específica y validar que el tipo esté activo y pertenezca al Profesional del turno, sin que la propiedad del catálogo otorgue por sí sola permiso para crear turnos. Los resultados permitidos, denegados, exitosos o fallidos deberán auditarse de forma inmutable y minimizada mediante referencias estables, sin registrar nombres, colores, precios, intervalos, cantidades ni copias históricas; los cambios exitosos y su evento requerido deberán confirmarse atómicamente.
* **RF-09: Edición de Precios y Multa Asociada:** El sistema deberá otorgar la capacidad de modificar de manera individual el valor monetario de un turno específico, permitiendo la aplicación de excepciones o descuentos sobre el precio estándar de la consulta. Para un turno existente no Pagado, una reducción o descuento podrá aplicarse directamente, deberá notificarse al Paciente y quedará auditada. Para ese mismo estado financiero, un aumento deberá tratarse como una propuesta que requiere aceptación expresa del Paciente; mientras no acepte, seguirá vigente el precio anterior. Si el Paciente rechaza el aumento, se conservará el precio anterior y el turno no se cancelará automáticamente. Si el Profesional decide no mantener el precio anterior, podrá cancelar manualmente el turno con motivo auditado, sin multa para el Paciente. Una vez que el estado financiero sea Pagado, el precio no podrá editarse. La multa por cancelación tardía deberá permanecer desactivada por defecto para cada Profesional. Si el Profesional la activa, deberá configurar un porcentaje entero entre 1 % y 100 % sobre el precio efectivo del turno. Cuando exista una multa por cancelación tardía, su importe deberá calcularse a partir del precio efectivo del turno y del porcentaje de multa vigente configurado por el Profesional. Un cambio posterior de configuración deberá afectar únicamente a las cancelaciones futuras y no recalcular ni modificar multas ya determinadas. La edición posterior de un tipo de consulta no deberá alterar retroactivamente los turnos ya creados; solo deberá afectar a los turnos nuevos.
* **RF-10: Aprobación:** El sistema deberá proveer una opción de configuración a nivel de perfil profesional que permita definir la modalidad de aprobación de los turnos solicitados, alternando entre un flujo de aprobación manual y un flujo de aprobación automática. En el flujo manual, la solicitud del paciente inicia en estado Solicitado; en el flujo automático, inicia en estado Reservado. Para reservas creadas durante el día D-1, la aprobación manual lleva la solicitud directamente a Confirmado y la aprobación automática genera Confirmado desde el inicio. La reserva estándar creada por Secretaría nunca pasará por Solicitado ni dependerá de la modalidad de aprobación del Profesional: antes de D-1, Secretaría deberá elegir explícitamente crearla en estado Reservado, sujeto al flujo posterior de confirmación por WhatsApp, o en estado Confirmado, porque el horario ya fue acordado con el Paciente; durante D-1, solo podrá crearla en estado Confirmado. Para todo turno estándar que Secretaría cree como Confirmado, especialmente durante D-1, deberá registrar una declaración simple de que el Paciente aceptó el horario, sin almacenar evidencia, grabación, comprobante ni canal del acuerdo. En turnos creados por Profesional, si la creación ocurre antes de D-1 el turno nace en estado Reservado y continúa el flujo de confirmación por WhatsApp; si ocurre durante D-1, el turno nace directamente en estado Confirmado y no usa confirmación por WhatsApp. Esta regla no amplía la selección de Pacientes ni modifica los permisos del Profesional. La reserva pública o autónoma para una cita del día D cerrará a las 23:59 horas del día D-1. Son excepciones controladas a este corte: la lista de espera operada en modo Manual para un cupo liberado el mismo día D, sin exposición pública ni habilitación de reserva autónoma; y la asignación directa interna de un cupo por Secretaría o Profesional, que podrá ejecutarse hasta el inicio del turno. Ninguna de estas excepciones habilita reserva pública autónoma ni modifica los permisos vigentes.
* **RF-10 bis: Cancelación voluntaria del paciente:** El sistema deberá permitir configurar por perfil profesional el plazo de cancelación voluntaria del paciente. La configuración predeterminada deberá habilitar la cancelación hasta las 23:59 del día D-1. La configuración personalizada deberá permitir definir un entero entre 1 y 72 horas antes del horario del turno, pudiendo habilitar cancelaciones dentro del mismo día de la cita. Antes de confirmar la reserva, el sistema deberá mostrar al paciente el límite de cancelación aplicable según el perfil profesional. Este límite solo determina hasta cuándo el Paciente puede cancelar por su cuenta; no define por sí mismo si una cancelación es tardía ni si corresponde una multa. La política de multa y el porcentaje vigente también deberán mostrarse al Paciente antes de confirmar la reserva.

#### 3.2.3 Portal del Paciente y Turnos

* **RF-11: Calendario:** El sistema deberá renderizar una interfaz gráfica de usuario en forma de calendario interactivo para el paciente, en la cual se deberán reflejar exclusivamente las franjas horarias con disponibilidad de atención.
* **RF-12: Control de Masividad:** El sistema deberá ejecutar reglas de validación que impidan a un mismo perfil de Paciente la reserva simultánea de múltiples turnos superpuestos, independientemente de qué cuenta propia o representante actúe, previniendo el acaparamiento de la agenda. Si un Paciente registra una multa pendiente asociada a un Profesional, el sistema deberá bloquear únicamente sus nuevas reservas autónomas con ese Profesional, sin afectar reservas con otros Profesionales ni turnos ya existentes.
* **RF-13: Historial operativo de turnos:** El sistema deberá permitir a una cuenta autenticada consultar el historial del perfil de Paciente seleccionado cuando sea su perfil propio o exista una representación activa. El listado incluirá únicamente información operativa y administrativa de los turnos pasados, como fecha, horario, Profesional, tipo de consulta, estado operativo, estado administrativo y estado financiero. No deberá mostrar historia clínica, seguimiento o evolución clínica, indicaciones clínicas, diagnósticos, prescripciones, resultados de estudios ni notas clínicas. Podrá mostrar el indicador de Nota de devolución definido en RF-13 bis, sin exponer contenido en el listado. En el acceso representado deberán auditarse actor y Paciente sujeto.
* **RF-13 bis: Notas de devolución:** Después de una consulta, únicamente el Profesional asociado al turno podrá crear Notas de devolución para el perfil de Paciente correspondiente. Cada Nota será una comunicación no clínica independiente y podrá contener recomendaciones generales, próximos pasos, recordatorios, observaciones no diagnósticas, formato básico y enlaces web seguros. Deberá incluir un título opcional de hasta 100 caracteres y un cuerpo obligatorio de hasta 5.000 caracteres; ambos campos aplicarán las mismas prohibiciones de contenido. No admitirá diagnóstico, prescripción, dosis de medicamentos, resultados de estudios, evolución clínica, información urgente o crítica en el tiempo, imágenes, PDF ni adjuntos. La comunicación urgente deberá realizarse por un canal externo. La interfaz mostrará autor, destinatario y el texto: `Esta devolución es una comunicación no clínica vinculada a la consulta. Origen no la gestiona como historia clínica, receta, certificado ni documento formal.`
  El turno deberá encontrarse en estado Asistió al publicar. El plazo de publicación será exactamente de siete días desde el inicio programado del turno, según la hora del servidor, sin utilizar una hora real de inicio. Una corrección posterior de Asistió a No asistió o Cancelado mantendrá visibles y retirables las Notas ya publicadas, pero impedirá nuevas publicaciones mientras el turno no esté en Asistió. Se permitirán múltiples Notas independientes por consulta, sin relación ni concepto de Nota correctiva. El borrador será privado y editable por su autor; al vencer el plazo pasará a ser de solo lectura para el autor, no podrá publicarse y podrá eliminarse por este. Antes de publicar, el sistema mostrará una vista previa exacta con el perfil y Paciente destinatarios resueltos, la consulta, el título opcional, el cuerpo y los enlaces, y exigirá confirmar el destinatario y declarar que el contenido es no clínico. No se exigirá ni prometerá control mediante palabras clave o inteligencia artificial. La publicación podrá realizarse aunque el Paciente no tenga cuenta de acceso actual, representante activo o teléfono verificado.
  Una Nota publicada será inmutable y no admitirá respuesta ni acuse del Paciente. Solo su Profesional creador podrá retirarla, en cualquier momento y aunque haya sido leída; una Nota independiente posterior solo podrá publicarse dentro del plazo ordinario. El retiro quitará al Paciente el acceso al contenido, conservará el original inmutable para el autor y dejará en el portal un marcador con fecha y categoría del motivo, sin enviar WhatsApp. Si el autor está inactivo, el Paciente conservará acceso a las Notas publicadas, el autor no podrá acceder, no habrá transferencia y nadie podrá retirarlas hasta su reactivación legítima.
  El contenido será exclusivamente web: Origen no generará PDF ni ofrecerá descarga, sin prometer impedir las funciones de copia o impresión del navegador ni las capturas de pantalla. Solo podrán acceder al contenido el Profesional creador y el perfil de Paciente destinatario mediante su cuenta propia o un representante activo; ningún otro Profesional podrá acceder. Un representante nuevo y activo verá todas las Notas históricas vigentes; el representante anterior perderá acceso de inmediato. Un enlace profundo autenticado deberá verificar la autorización actual, activar el perfil de Paciente correcto y mostrar visiblemente ese perfil; será navegación y no una credencial portadora. Ninguna interfaz de producto de Secretaría o Administrador expondrá la existencia, metadatos ni contenido de la Nota, aunque se conservarán sus asociaciones técnicas y auditoría.
  Las Notas aparecerán únicamente en el detalle de la consulta, sin bandeja longitudinal global. Las listas de consultas del Paciente y del Profesional mostrarán un icono solo cuando exista al menos una Nota publicada y no retirada; la vista del Profesional tendrá además un indicador distinto para borradores. Si todas las Notas están retiradas y no existen borradores, no habrá icono, aunque los marcadores de retiro permanecerán en el detalle. Si una cuenta o representación se habilita posteriormente, las Notas previas vigentes pasarán a ser visibles sin aviso retroactivo por WhatsApp. La retención se regirá por la futura política general de datos personales; hasta validarla no habrá eliminación automática y el retiro no equivaldrá a eliminación.
* **RF-14: Máquina de Estados:** El sistema deberá gestionar el ciclo de vida de cada turno mediante una máquina de estados finitos, registrando las transiciones obligatorias entre los estados operativos: Solicitado, Reservado, Confirmado, Asistió, Cancelado y No asistió, y el estado administrativo: Abierto o Cerrado. El estado inicial dependerá del rol que crea o reserva el turno y de la fecha de la cita según RF-10. Sobreturno no deberá utilizarse como estado del ciclo de vida, sino como tipo o modalidad de turno compatible con esos estados. El cierre administrativo deberá mantenerse Abierto mientras exista alguna acción operativa o financiera pendiente, y solo deberá pasar a Cerrado cuando el turno alcance un resultado operativo terminal y no queden obligaciones financieras ni decisiones de multa pendientes. La cancelación automática de un turno Reservado por falta de confirmación únicamente deberá liberar la agenda; no deberá considerarse, por sí misma, una cancelación tardía sancionable. La cancelación manual de un turno deberá unificarse bajo la operación de dominio Cancelar turno, cambiar el estado operativo a Cancelado, liberar de inmediato el horario y conservar de forma auditada el actor, la fecha, la hora, el motivo obligatorio y el estado anterior. Cuando un turno Confirmado sea modificado por Profesional en fecha u horario, el sistema deberá registrar explícitamente una de dos decisiones: "Acordado con el paciente", dejando el turno Confirmado y limitándose WhatsApp a informar el nuevo horario, o "Requiere confirmación", pasando el turno a Reservado y solicitando nueva confirmación por WhatsApp. "Requiere confirmación" solo deberá estar disponible si faltan al menos 24 horas para el nuevo horario; si faltan menos de 24 horas, deberá elegirse "Acordado con el paciente" y, si no hubo acuerdo, corresponderá cancelar el turno en lugar de reprogramarlo unilateralmente. La decisión elegida, el actor, la fecha y hora de la modificación, y los valores anteriores y nuevos deberán quedar auditados. Después de finalizar el horario previsto del turno, el Profesional o la Secretaría deberán poder registrar el resultado operativo como "Asistió" o "No asistió"; la interfaz deberá presentar "Asistió" preseleccionado como opción predeterminada, pero dicha preselección solo deberá representar una elección de interfaz y requerirá confirmación humana expresa para concretar el cierre. El registro de "No asistió" solo deberá habilitarse una vez finalizado el horario previsto del turno (hora de inicio más duración aplicable) y deberá dejar constancia del actor, la fecha y la hora de la operación. Si posteriormente se corrige un cierre entre "Asistió" y "No asistió", el sistema deberá conservar el cierre original y agregar un evento de corrección auditado con actor, fecha, hora, estado anterior, estado nuevo y motivo obligatorio.
  Una consulta Cancelada sin multa ni otra obligación deberá pasar a No corresponde y cerrar administrativamente; una consulta con No asistió sin multa o con multa perdonada deberá pasar a No corresponde y cerrar cuando no quede otra obligación o decisión pendiente. Una consulta con estado financiero Pendiente, En revisión o Rechazado deberá mantener el cierre Abierto; una consulta Asistió deberá mantenerse Abierta hasta quedar Pagada. La multa deberá conservar un ciclo y una obligación separados del estado financiero de la consulta.
  Si un turno permanece Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, Profesional o Secretaría deberán cerrarlo como Asistió si el Paciente asistió o como No asistió si no asistió. En este caso no deberá usarse Cancelado para representar la ausencia; el cierre como No asistió no será elegible para multa y el sistema deberá mostrar claramente su causa no sancionable.
* **RF-15: Sobreturnos:** El sistema deberá habilitar a los roles con privilegios administrativos (Secretaría o Profesional) la creación manual de turnos denominados "sobreturnos", permitiendo su inserción en la agenda en horarios atípicos o por fuera de los bloques regulares de disponibilidad.

#### 3.2.4 Automatizaciones y Notificaciones

* **RF-16: Confirmación y Cancelación:** El sistema deberá gestionar la confirmación por WhatsApp para los turnos sujetos a ese flujo. A las 18:00 horas del día D-1, si el turno permanece Reservado sin respuesta y al menos uno de los dos mensajes de confirmación alcanzó el estado `delivered`, deberá cambiar automáticamente a Cancelado y liberar de inmediato el bloque horario. Si ninguno de los mensajes alcanzó `delivered` —porque ambos fallaron o porque la entrega es desconocida o no consta al corte— el turno no deberá cancelarse automáticamente: permanecerá Reservado y visible como revisión urgente. Profesional o Secretaría deberán contactar al Paciente fuera del sistema. Si el Paciente acepta asistir, el actor deberá cambiar el turno a Confirmado; si rechaza, deberá cambiarlo a Cancelado y liberar de inmediato el bloque horario. Si no logra contactarlo, el turno deberá permanecer Reservado y visible como revisión urgente, sin resolución automática. Si permanece Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, Profesional o Secretaría deberán cerrarlo como Asistió si el Paciente asistió o como No asistió si no asistió; no deberá usarse Cancelado para representar la ausencia. Ese No asistió no será elegible para multa y el sistema deberá mostrar claramente la causa no sancionable. Para confirmar o cancelar por este flujo, el actor deberá registrar una declaración simple del resultado del contacto, sin almacenar evidencia ni el canal utilizado. El contacto, el intento fallido, la declaración, el actor, la fecha y hora, y cada transición deberán quedar auditados. Ninguno de estos resultados por falta de confirmación deberá habilitar ni generar multa.
* **RF-16 bis: Cancelación tardía y multa aplicada:** El sistema deberá distinguir entre cancelación tardía y multa aplicada. Solo podrá considerarse multa cuando el Paciente cancele desde las 18:00 horas del día D-1 un turno que estaba Confirmado, o cuando el turno se registre como No asistió, excepto si ese No asistió deriva de que ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual. En ambos casos elegibles, el Profesional deberá decidir expresamente si aplica o perdona la multa configurada para su perfil; no deberá ingresar un monto manual. Si decide aplicarla, el sistema deberá calcular el importe a partir del porcentaje vigente configurado sobre el precio efectivo del turno. Si la configuración de multa cambia luego de determinada una cancelación, no deberán recalcularse ni alterarse las multas ya determinadas. El registro de "No asistió" no deberá generar multa automática: solo deberá habilitar la decisión posterior del Profesional sobre su aplicación o perdón cuando sea elegible. Si un cierre de "No asistió" se corrige a "Asistió" y existiera una multa pendiente, el sistema deberá anularla de inmediato y restaurar la reserva autónoma con ese Profesional. Toda cancelación atribuible al Profesional deberá realizarse sin multa para el Paciente. Cuando una consulta Pagada se cancele sin penalización, su estado financiero deberá pasar a No corresponde, sin borrar ni modificar el pago original, y el sistema deberá generar automáticamente un saldo a favor del Paciente con ese Profesional por el monto pagado. Cuando el Paciente rechace una propuesta de aumento en un turno no Pagado, el sistema deberá conservar el precio anterior; si el Profesional decide no mantener ese precio anterior, podrá iniciar una cancelación manual del turno con motivo auditado y sin multa para el Paciente.
* **RF-17: Recordatorios:** El sistema deberá integrarse con la API de WhatsApp para enviar de manera automatizada dos mensajes de recordatorio y solicitud de confirmación al único destinatario primario seleccionado para el perfil de Paciente conforme a RF-02 ter: el primero a las 08:00 horas del día D-2 y el segundo a las 08:00 horas del día D-1, advirtiendo explícitamente las consecuencias de la falta de respuesta según RF-16. El teléfono del destinatario deberá estar verificado y el mensaje no se duplicará al Paciente y al representante. Todo mensaje de WhatsApp, incluidos recordatorios, reprogramaciones, ofertas de lista de espera y demás mensajes, podrá saludar o identificar al Paciente relevante con sus nombres y apellidos completos, por ejemplo, «Hola Santiago Ariel Casali Pérez», e incluir únicamente el nombre del centro, el nombre del Profesional, la fecha y el horario, el consultorio o ubicación y la acción necesaria para confirmar, rechazar o responder al flujo aplicable. No podrá incluir tipo ni número de documento de identidad —incluido DNI—, tipo de consulta, pagos, montos, multas, estado financiero, comprobantes ni datos clínicos o sensibles; esos detalles solo podrán consultarse dentro del sistema autenticado. No se enviarán automatizaciones a teléfonos no verificados. Cuando cambie el teléfono actualmente seleccionado, se aplicarán la suspensión y revisión manual definidas en RF-02 ter; si el representante continúa como destinatario, el alta o cambio del teléfono propio del Paciente no deberá interrumpir los mensajes dirigidos al representante. Para cada mensaje, `sent` significará que WhatsApp lo aceptó o procesó, sin probar entrega; `delivered` probará su llegada al dispositivo y será la evidencia mínima de entrega; `read` no será obligatorio; y `failed` indicará fallo. Un estado ausente o desconocido al corte se tratará como entrega no comprobada. Los turnos creados o aprobados durante D-1 omiten este flujo de WhatsApp. Los turnos creados por Profesional antes de D-1 sí deben atravesarlo; los creados durante D-1 no. Este calendario regular es independiente del disparador inmediato que debe enviarse cuando un turno Confirmado es modificado en fecha u horario por Profesional. En esa modificación, WhatsApp deberá reflejar la decisión explícita elegida entre "Acordado con el paciente" o "Requiere confirmación", según corresponda al umbral de 24 horas.
* **RF-17 bis: Aviso de publicación de Nota de devolución:** Cada Nota publicada intentará una sola vez y de inmediato enviar por WhatsApp un aviso genérico al destinatario primario seleccionado y verificado. El mensaje no incluirá contenido de la Nota y contendrá un enlace directo autenticado que aplicará la autorización y selección de perfil de RF-13 bis. Cada Nota se notificará por separado, sin agrupación, reintento automático ni reenvío manual. El fallo no revertirá la publicación y mostrará al Profesional: `La devolución fue publicada correctamente, pero el mensaje de aviso falló.` Si no existe un destinatario con teléfono verificado, la publicación también tendrá éxito, no se intentará un aviso posterior y se mostrará: `La devolución fue publicada correctamente, pero no se envió el aviso porque no existe un destinatario con teléfono verificado.` Este mensaje se denominará `aviso`; `recordatorio` quedará reservado para los mensajes de turnos D-2/D-1. El retiro no enviará WhatsApp.
* **RF-18: Liberación de Agenda:** El sistema deberá liberar el bloque horario en la base de datos de manera inmediata tras la cancelación de un turno, reflejando la disponibilidad instantánea en el calendario interactivo. Esta liberación deberá ser inmediata tanto en cancelaciones automáticas como manuales.

#### 3.2.5 Lista de Espera y Facturación

* **RF-19: Lista de Espera:** El sistema deberá mantener, por cada Profesional, una única cola de espera ordenada por fecha y hora de inscripción. Ante la liberación de un cupo, el sistema deberá ofrecerlo a una sola persona por vez, comenzando por el primer Paciente elegible de la cola. Al enviar una oferta de lista de espera, el cupo deberá quedar retenido exclusivamente durante 30 minutos; mientras dure la retención no deberá aparecer disponible para otras reservas ni podrá ofrecerse a otra persona. La retención no deberá crear un turno ni modificar el historial o el estado del Paciente. Si el Paciente acepta dentro del plazo, la retención deberá convertirse en turno según el flujo aplicable. Si rechaza o vence el plazo, el sistema deberá liberar la retención y ofrecer el cupo al siguiente Paciente elegible con una nueva retención de 30 minutos. Cuando el Paciente rechace una oferta, el sistema deberá liberar la retención de ese cupo y continuar con el siguiente Paciente elegible. El Paciente que rechazó deberá permanecer inscripto, conservando su fecha y hora de inscripción, sus preferencias y su posición relativa para futuras ofertas compatibles. El rechazo no deberá generar multa, penalización ni baja. Ante vencimientos consecutivos de ofertas sin respuesta, el primer y segundo vencimiento no deberán alterar la inscripción: el Paciente permanecerá inscripto, conservará antigüedad y posición, y el flujo continuará. Al tercer vencimiento consecutivo sin respuesta, el sistema deberá pausar automáticamente la inscripción. Una inscripción pausada no deberá recibir nuevas ofertas. El Paciente podrá reactivarla, conservando sus preferencias pero recibiendo una nueva fecha y hora de inscripción y una nueva posición en la cola. Una respuesta explícita a una oferta posterior a esa reactivación deberá reiniciar el contador de vencimientos consecutivos. El estado de pausa, la reactivación, el contador de vencimientos consecutivos y los cambios de antigüedad deberán quedar auditados. El Paciente solo deberá salir de la lista de espera al aceptar un turno, solicitar la baja voluntaria o quedar cubierto por una asignación directa. La baja voluntaria de una inscripción deberá permitir que el Paciente retire su propia inscripción, que Secretaría retire cualquier inscripción y que Profesional retire solo inscripciones de Pacientes vinculados con él. Cuando actúen Secretaría o Profesional, deberán dejar una declaración simple de que lo hacen a pedido del Paciente, sin almacenar evidencia. Si existe una oferta o retención activa, la baja deberá cancelarla y liberar de inmediato el cupo para continuar el flujo aplicable. La baja no deberá generar multa ni penalización. Cada Profesional deberá configurar la modalidad de operación en Automático o Manual.

  Al inscribirse en la lista de espera, el Paciente deberá declarar el tipo de consulta requerido, los días aceptables y las franjas horarias aceptables, o indicar «Cualquier horario». Solo deberán ofrecerse cupos compatibles con esas preferencias. Si el primer Paciente por antigüedad no coincide con un cupo, el sistema deberá saltearlo temporalmente para esa oferta, sin eliminarlo de la cola, cambiar su fecha de inscripción ni modificar su posición relativa para futuras ofertas, y deberá seleccionar al Paciente elegible más antiguo.

  La inscripción y edición de la preferencia deberán estar permitidas según el rol: el Paciente podrá crear y editar su propia inscripción; Secretaría podrá crear y editar la inscripción de cualquier Paciente registrado; Profesional podrá crear y editar solo inscripciones de Pacientes que tengan o hayan tenido al menos un turno con ese Profesional. Cuando actúen Secretaría o Profesional, deberán registrar una declaración simple de que actúan a pedido del Paciente, sin almacenar evidencia del pedido. El alta o edición, el actor, el Paciente, el Profesional, las preferencias anteriores y nuevas, la fecha/hora y la declaración deberán quedar auditados. Si la edición solo modifica días aceptables, franjas horarias o alterna «Cualquier horario», el sistema deberá conservar la fecha/hora original de inscripción y la posición relativa en la cola. Si la edición cambia el tipo de consulta requerido, el sistema deberá tratar la modificación como una nueva solicitud, reiniciar la fecha/hora de inscripción y reubicar la entrada según la nueva antigüedad. Antes de guardar un cambio de tipo, el sistema deberá advertir de forma explícita que la posición cambiará y exigir confirmación.
  La reactivación asistida de una inscripción pausada deberá estar permitida para Secretaría sobre cualquier Paciente y para Profesional únicamente sobre Pacientes vinculados con él. En esa reactivación, el actor interno deberá dejar constancia de una declaración simple de que actúa a pedido del Paciente, sin almacenar evidencia adicional. La reactivación deberá conservar las preferencias vigentes, reiniciar el contador de vencimientos consecutivos, asignar una nueva fecha y hora de inscripción y ubicar la inscripción con una nueva posición en la cola. No deberá restaurarse la posición anterior ni habilitarse una reactivación automática.
  Una cuenta con representación activa podrá ejecutar para el perfil representado las mismas altas, ediciones, bajas, respuestas y reactivaciones ordinarias permitidas al Paciente. Cada operación deberá validar la relación en el backend y auditar al propietario de la cuenta como actor y al Paciente representado como sujeto; una relación ausente, revocada o inconsistente deberá causar la denegación por defecto.

  La asignación directa de un cupo liberado por Secretaría o Profesional deberá respetar el mismo corte temporal que la reserva de un turno del día D: solo podrá ejecutarse hasta el inicio del turno, nunca después. Esa asignación no deberá depender de la cola de espera ni alterar el orden relativo o la prioridad de los Pacientes que permanecen en ella. Si el Paciente destinatario estaba inscripto en la lista de espera de ese Profesional, el sistema deberá eliminar únicamente su inscripción al crearse el turno y registrar la salida con el motivo «Cubierto por asignación directa». Para realizarla, el actor deberá marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario». El acuerdo podrá ser verbal o producirse fuera del sistema; el sistema no deberá solicitar ni almacenar evidencia, grabación, comprobante o canal de dicho acuerdo.
* **RF-20: Pagos:** El sistema deberá requerir el registro del estado financiero de cada consulta, categorizando la transacción como Pendiente, En revisión, Pagado, Rechazado o No corresponde y documentando el método de pago empleado cuando corresponda. Un pago directo en efectivo registrado por el Profesional o la Secretaría deberá pasar a Pagado sin comprobante. La carga de un comprobante deberá pasar a En revisión; su validación, a Pagado; y su rechazo, a Rechazado. Estas transiciones no deberán alterar el estado operativo del turno. El cierre administrativo deberá permanecer Abierto cuando exista pago pendiente, multa pendiente o decisión de multa pendiente, y solo deberá pasar a Cerrado cuando no quede ninguna obligación pendiente. La multa por cancelación tardía no deberá confundirse con el estado financiero de la consulta: su decisión de aplicación/perdón y su eventual cálculo deberán registrarse por separado. La cancelación automática por falta de confirmación no deberá generar ni activar multa. Cuando la multa sea pagada o perdonada, y no quede otra obligación pendiente, el cierre administrativo deberá poder pasar a Cerrado. Si una multa que nació de un cierre de "No asistió" corregido a "Asistió" ya estaba "Pendiente", el sistema deberá anularla; si ya estaba "Pagado", el sistema deberá conservar el registro y, al invalidarse la multa por la corrección, deberá generar automáticamente un saldo a favor del Paciente con ese Profesional por el importe pagado. Cuando una consulta Pagada se cancele sin penalización, el sistema deberá cambiar su estado financiero a No corresponde, conservar sin cambios el pago original y generar automáticamente un saldo a favor del Paciente con ese Profesional por el monto pagado, vinculado a ese pago. Secretaría deberá poder visualizar ese saldo a favor y registrar una devolución realizada fuera del sistema si el Paciente la solicita; dicho registro deberá consumir el saldo a favor correspondiente y conservar el vínculo con el pago original que generó el saldo. El sistema no deberá borrar ni alterar el pago, la multa ni la corrección originales.
  El estado financiero de cada consulta podrá ser Pendiente, En revisión, Pagado, Rechazado o No corresponde. Todos los pagos, multas, saldos a favor, compensaciones y devoluciones externas serán exclusivamente registros administrativos declarados por usuarios autorizados; el sistema no procesará, cobrará, transferirá ni devolverá dinero real. Una consulta Cancelada sin multa ni otra obligación deberá pasar a No corresponde y su cierre administrativo a Cerrado. Si una consulta Pagada se cancela tarde, deberá pasar a No corresponde, conservar el pago original y generar un saldo a favor por ese importe. Si el Profesional aplica la multa, el sistema deberá registrar por separado la compensación administrativa de la multa contra ese saldo a favor y conservar como saldo a favor el remanente; si la perdona, deberá conservar el saldo completo. Estos registros no implicarán movimiento de dinero real. Una consulta con No asistió sin multa o con multa perdonada deberá pasar a No corresponde; su cierre administrativo será Cerrado cuando no quede otra obligación o decisión pendiente. No corresponde no deberá significar Pagado ni eliminar el historial de la consulta. Una consulta Asistió deberá permanecer Abierta hasta que su estado financiero sea Pagado; los estados Pendiente, En revisión y Rechazado deberán mantener el cierre Abierto. La multa por cancelación tardía deberá conservar una obligación y ciclo separados del estado financiero de la consulta.
* **RF-21: Comprobantes:** El sistema deberá contar con un módulo de gestión documental que permita la carga, almacenamiento privado en el servidor y posterior validación o rechazo de archivos de imagen o PDF correspondientes a comprobantes de pago. El comprobante será evidencia para validación manual y no confirmación bancaria automática. Deberá aceptar únicamente PNG, JPG/JPEG y PDF, con un tamaño máximo de 10 MB por archivo, verificando el tipo real y el contenido antes de admitirlos; deberá rechazar archivos corruptos, ejecutables o que no correspondan al formato declarado. Antes de habilitar la visualización, deberá analizar los archivos en busca de malware. El acceso quedará restringido al Paciente propietario, a una cuenta con representación activa para ese Paciente, al Profesional asociado al turno y a Secretaría, sin exponer URLs públicas permanentes. En accesos representados, la auditoría distinguirá al propietario de la cuenta como actor y al Paciente como propietario del comprobante. La carga, el rechazo técnico, el resultado del análisis y toda visualización o acceso deberán quedar auditados. La carga o validación no deberá modificar por sí misma el estado operativo del turno; únicamente afectará el estado financiero asociado. La política de retención o eliminación de comprobantes queda pendiente de validación legal y contable; provisionalmente no habrá eliminación automática. Antes de producción, el cliente deberá aprobar un plazo concreto y la conducta de eliminación o retención.
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

* **RNF-01 Privacidad de Datos Bancarios y Comprobantes:** El sistema deberá aplicar medidas de ofuscación o restricción de vista de la información financiera, asegurando que los datos sensibles como el Alias y el CBU sean expuestos en la interfaz únicamente dentro de la ventana de carga de comprobantes del Paciente. Los comprobantes deberán mantenerse privados, sin URLs públicas permanentes, y solo podrán ser accedidos por el Paciente propietario, una cuenta con representación activa para ese Paciente, el Profesional asociado al turno y Secretaría, dentro de sus respectivos alcances.
* **RNF-02 Integridad:** El backend deberá tratar la Persona, los perfiles, las cuentas de acceso y las representaciones como conceptos separados. Deberá imponer la unicidad de la combinación de tipo de documento controlado y número normalizado entre Personas y la unicidad del correo electrónico entre cuentas de acceso. Solo Administrador podrá modificar credenciales de acceso de terceros. Los cambios de correo deberán aplicar los actores, alcances y verificación de RF-03; las correcciones documentales, la operación reforzada de RF-03 bis; y toda actuación sobre un perfil representado, la relación activa y denegación por defecto de RF-06 bis. Ninguna coincidencia de correo compartido, documento o fecha de nacimiento otorgará acceso por sí sola. La carga, el rechazo técnico, el resultado del análisis de malware y los accesos o visualizaciones de comprobantes deberán quedar auditados junto con actor, sujeto, fecha y operación.
  El backend deberá aplicar los permisos de consulta del log de auditoría: Administrador tendrá acceso global de solo lectura; Profesional solo podrá consultar eventos vinculados a su agenda, sus Pacientes relacionados y sus propias operaciones; Secretaría solo podrá consultar los eventos operativos necesarios para la gestión, sin acceso a eventos internos sensibles de seguridad; y Paciente no tendrá acceso al log técnico. Ningún rol podrá editar ni borrar registros de auditoría.
* **RNF-06 Gestión de baja y datos personales:** La baja operativa de un perfil de Paciente o la desactivación de su cuenta de acceso deberán ser lógicas y distinguirse entre sí. La baja del perfil bloqueará nuevas reservas sin eliminar la Persona ni sus turnos, pagos, comprobantes, relaciones o auditoría; la desactivación de una cuenta bloqueará su acceso sin borrar los perfiles ni el historial y no revocará por sí sola una representación independiente. La política de solicitud de eliminación o anonimización y de conservación obligatoria de datos personales queda pendiente de validación legal. Las Notas de devolución seguirán esa política general; no se eliminarán automáticamente mientras permanezca pendiente y su retiro no será una eliminación. Hasta que el cliente apruebe, antes de producción, qué datos se eliminan, anonimizan o conservan y durante cuánto tiempo, no habrá borrado ni anonimización automática y la salida a producción quedará bloqueada.
* **RNF-07 Protección criptográfica y secretos:** Toda comunicación del sistema deberá estar cifrada en tránsito mediante TLS. La base de datos, los discos, los backups y los comprobantes deberán estar cifrados en reposo. Las Notas de devolución dependerán de esta protección general en reposo y no de cifrado de campos específico de la aplicación; su acceso exclusivo será una garantía de autorización de la aplicación, no cifrado de extremo a extremo ni aislamiento de infraestructura. Las contraseñas de Usuarios Internos deberán almacenarse únicamente mediante un hash seguro, nunca en texto plano ni en forma reversible. Cada secreto TOTP deberá cifrarse individualmente por cuenta. Los secretos y las credenciales deberán mantenerse fuera del repositorio y del código fuente. Antes de producción deberá existir capacidad y un procedimiento para rotar credenciales comprometidas. El cumplimiento de este requisito para los datos actuales será un gate de preproducción/DoD y no forma parte del alcance funcional del Sprint 1.
* **RNF-08 Matriz de autorización y denegación por defecto:** Antes de implementar módulos sensibles deberá existir una única matriz de autorización con filas para las operaciones sensibles y columnas para Administrador, Profesional, Secretaría y Paciente. La representación deberá expresarse como condición de alcance de una cuenta con rol Paciente, no como otra columna o rol. La matriz incluirá selección y cambio de perfil, operaciones representadas, gestión de representación, corrección documental, cambio de correo, recuperación de credenciales internas, selección de destinatario, establecimiento de visibilidad Profesional–Paciente y creación, publicación, visualización y retiro de Notas de devolución. Cada cruce deberá indicar permitir, denegar o permitir con condición o alcance. Todo permiso no declarado se denegará por defecto. El backend será la autoridad y aplicará estas reglas aunque el frontend o cualquier cliente intente eludirlas; ocultar controles no constituye seguridad. Los permisos críticos deberán contar con pruebas automatizadas, incluidos los intentos denegados por relación inactiva, inconsistente o fuera de alcance. Los cambios de la matriz deberán versionarse, revisarse y quedar asociados a sus requisitos.
* **RNF-09 Sesiones internas:** Administrador definirá una única política global para las sesiones de Administrador, Profesional y Secretaría, sin excepciones por usuario ni valores fuera de rango. La duración máxima absoluta podrá configurarse entre 4 y 12 horas, con valor predeterminado de 12 horas; el bloqueo por inactividad, entre 5 y 30 minutos, con valor predeterminado de 15 minutos; y el recordatorio de TOTP en dispositivos confiables, entre 0 y 30 días, con valor predeterminado de 7 días. Cada nueva sesión exigirá siempre contraseña. El dispositivo confiable solo podrá omitir TOTP durante el plazo global vigente y no sustituirá los factores expresamente requeridos para cambios o recuperaciones de credenciales. Todo cambio de política exigirá reautenticación reciente con contraseña y TOTP, motivo obligatorio y auditoría de valores anteriores y nuevos. Las reducciones se aplicarán inmediatamente a las sesiones actuales: las que ya excedan el nuevo límite de inactividad se bloquearán y las que excedan el nuevo límite absoluto terminarán; las ampliaciones regirán solo para sesiones nuevas. Para desbloquear una sesión por inactividad se exigirá contraseña y, si la confianza no existe o venció, TOTP; el desbloqueo no reiniciará la duración absoluta.
  RNF-09 es la autoridad normativa para los valores y efectos de la política de sesiones internas; cualquier valor fijo diferente conservado en contenido de planificación no modifica estos rangos, valores predeterminados ni reglas de propagación.
* **RNF-10 Sesiones de Paciente:** Las sesiones de cuentas con acceso de Paciente no tendrán duración máxima absoluta mientras exista actividad y expirarán tras 60 días consecutivos de inactividad. Después de Google OAuth o Magic Link, la cuenta deberá seleccionar un perfil de Paciente vinculado antes de operar. El contexto activo mostrará permanentemente el nombre completo del Paciente y permitirá regresar al selector y cambiar entre perfiles vinculados sin repetir la autenticación dentro de la misma sesión; cada selección y cambio deberá auditarse con cuenta actora, perfil seleccionado, fecha y hora del servidor. El usuario podrá cerrar la sesión actual o todas sus sesiones; después de cerrarla deberá autenticarse nuevamente mediante Google OAuth o un nuevo Magic Link. La activación de un cambio de correo invalidará las demás sesiones activas de esa cuenta. Paciente y Profesional no podrán iniciar cambios de correo, y toda acción sensible deberá respetar los flujos reforzados definidos en RF-03 y RF-03 bis.
* **RNF-11 Minimización de mensajería:** El sistema deberá limitar el contenido de los mensajes de WhatsApp a la información operativa permitida por RF-17 y, para una Nota de devolución, al aviso genérico y enlace autenticado de RF-17 bis. Los datos prohibidos por RF-17 y el contenido de las Notas de devolución no deberán enviarse por WhatsApp; solo podrán consultarse dentro del sistema autenticado.
* **RNF-12 Protección de Notas de devolución:** El contenido de una Nota de devolución nunca deberá aparecer en logs de aplicación, auditoría ni WhatsApp. La aplicación deberá aplicar en cada acceso la autorización actual de RF-13 bis, incluida la representación vigente, y denegar por defecto todo acceso ajeno al Profesional creador o al perfil de Paciente destinatario.

#### 3.5.2 Disponibilidad

* **RNF-03 Operatividad:** El sistema deberá alcanzar un objetivo de disponibilidad mensual del 99,5 %, medido mediante monitoreo externo. Este objetivo excluye el mantenimiento programado comunicado y las caídas atribuibles exclusivamente a Google OAuth o WhatsApp. Un 99,9 % queda como objetivo futuro, sujeto a presupuesto y a infraestructura y operación formal.
* **RNF-04 Backups y recuperación:** Antes de producción o de almacenar datos reales de Pacientes, el sistema deberá contar con backups automáticos cifrados, con retención de 30 días, y con una prueba de restauración realizada al menos mensualmente. La pérdida máxima aceptable de datos (RPO) será de 1 hora y el tiempo objetivo de recuperación del servicio (RTO) será de 4 horas. La salida a producción quedará bloqueada hasta contar con evidencia de backup y de restauración probada.

#### 3.5.3 Accesibilidad

* **RNF-05 Accesibilidad:** Las pantallas principales orientadas a Paciente y los flujos críticos internos deberán cumplir WCAG 2.2 nivel AA, incluyendo navegación por teclado, contraste suficiente, texto ampliable, nombres y etiquetas accesibles para lectores de pantalla, errores explicados en texto, información no dependiente solo del color y objetivos táctiles adecuados para celular. Este cumplimiento deberá verificarse mediante controles automáticos y revisión manual de los flujos críticos.

### 3.6 Otros Requisitos

* **RF-23 Registro de Auditoría:** El sistema deberá registrar de forma automática, silenciosa e inmutable en una tabla de auditoría (log) cada transacción realizada, persistiendo obligatoriamente el identificador del usuario que ejecutó la acción, el tipo de operación, la fecha y la hora del evento del lado del servidor. Las operaciones vinculadas a la lista de espera —alta, edición, baja voluntaria, oferta enviada, aceptación de la oferta, rechazo de la oferta, vencimiento de la oferta, liberación de la retención, conversión de la retención en turno, cambio de orden, autorización de envío, salto temporal de un Paciente no elegible y fin del proceso por alcanzar el límite temporal de la lista de espera— deberán quedar auditadas de forma diferenciada. La evaluación de elegibilidad, las preferencias vigentes que la determinan y cualquier salto temporal de un Paciente no elegible también deberán quedar registradas. La aceptación, el rechazo, la liberación de la retención y la continuidad del flujo hacia el siguiente Paciente elegible deberán quedar diferenciados como eventos auditables. Los vencimientos consecutivos sin respuesta, la pausa automática de una inscripción, la reactivación por parte del Paciente, la reactivación asistida por Secretaría o Profesional, la declaración simple registrada en esa reactivación, la conservación de preferencias, el reinicio del contador de vencimientos y la reasignación de antigüedad/posición asociada también deberán quedar auditadas de forma diferenciada. Las cancelaciones de turno, el registro de "No asistió", el cierre manual de un turno como "Asistió" o "No asistió", la decisión del Profesional de aplicar o perdonar la multa, el registro de pagos en efectivo o por transferencia y la eventual multa aplicada deberán quedar diferenciadas como operaciones distintas en la auditoría. La cancelación automática por falta de confirmación también deberá registrarse como operación de liberación de agenda, sin etiquetarse como cancelación tardía sancionable. El inicio, la verificación, la activación y cualquier fallo de cambios de correo iniciados por el Administrador o por Secretaría en correos de Pacientes deberán quedar auditados como eventos separados. La creación excepcional de un turno pese a una multa pendiente también deberá quedar auditada indicando el actor que ejerció la excepción. La asignación directa de un cupo liberado por Secretaría o Profesional deberá respetar el mismo corte temporal que la reserva de un turno del día D: solo podrá ejecutarse hasta el inicio del turno, nunca después. Esa asignación no deberá depender de la cola de espera ni alterar el orden relativo o la prioridad de los Pacientes que permanecen en ella. Si el Paciente destinatario estaba inscripto en la lista de espera de ese Profesional, el sistema deberá eliminar únicamente su inscripción al crearse el turno y registrar la salida con el motivo «Cubierto por asignación directa». Para realizarla, el actor deberá marcar una declaración simple equivalente a «Declaro que el Paciente aceptó este horario». El acuerdo podrá ser verbal o producirse fuera del sistema; el sistema no deberá solicitar ni almacenar evidencia, grabación, comprobante o canal de dicho acuerdo.
  Para cada reserva estándar creada por Secretaría deberán auditarse de forma diferenciada el estado elegido, la declaración simple de aceptación del horario cuando se cree como Confirmado, el actor y la fecha y hora; no deberá almacenarse evidencia, grabación, comprobante ni canal del acuerdo.
  El bootstrap del primer Administrador, la emisión, el consumo y cada fallo de una invitación de Usuario Interno, la configuración de contraseña, el enrolamiento TOTP y la activación de la cuenta deberán quedar auditados como eventos diferenciados. El pase de una consulta a No corresponde deberá quedar auditado como operación diferenciada, conservando el historial financiero previo cuando exista. Cuando ese pase provenga de la cancelación sin penalización de una consulta Pagada, también deberán auditarse de forma diferenciada la generación automática del saldo a favor, su monto, el Paciente, el Profesional y el vínculo con el pago original; toda devolución externa registrada por Secretaría deberá auditarse como consumo de ese saldo y conservar el mismo vínculo. Cuando provenga de una cancelación tardía de una consulta Pagada, deberán auditarse por separado el saldo a favor generado por el pago original, la decisión de aplicar o perdonar la multa, la compensación administrativa de la multa contra el saldo cuando corresponda y el remanente, vinculados al pago original y sin representar movimiento de dinero real.
  Para la verificación telefónica deberán auditarse de forma diferenciada el alta del teléfono, el destinatario al que pertenece, el envío del código, su validación, cada fallo y las capacidades del perfil habilitadas al completarse la verificación, sin almacenar el código. Para cada cambio del teléfono seleccionado como destinatario primario deberán auditarse el inicio, la suspensión de automatizaciones y WhatsApp al número anterior, el envío, la validación y cada fallo, la activación del nuevo número, el actor y los turnos señalados para revisión manual. Para la confirmación por WhatsApp deberán diferenciarse los estados de cada mensaje, la evaluación de entrega al corte, la cancelación automática cuando corresponda y el pase a revisión manual cuando no exista entrega comprobada. En esa revisión deberán auditarse el contacto fuera del sistema, cada intento fallido, la declaración simple del resultado, el actor, la fecha y hora y las transiciones a Confirmado o Cancelado; no deberán almacenarse evidencia ni el canal de contacto.
  Cuando un turno permanezca Reservado hasta finalizar su horario porque ninguno de los mensajes D-2/D-1 alcanzó `delivered` y no hubo contacto manual, deberán auditarse el cierre como Asistió o No asistió, el actor, la fecha y hora, los estados de entrega de ambos mensajes y la exclusión de multa por causa no sancionable.
  La auditoría de acceso de Pacientes deberá diferenciar la autenticación de la selección de perfil y de cada cambio de perfil, registrando la cuenta o Persona actora y el perfil de Paciente seleccionado. Para toda operación realizada por representación deberá registrar al propietario de la cuenta como actor y al Paciente representado como sujeto o propietario. Deberán auditarse por separado la activación, revocación y sustitución atómica de representaciones; el tipo de relación; la declaración de verificación externa; el actor interno; los avisos de seguridad y sus éxitos o fallos; las denegaciones por relación ausente, inactiva o inconsistente; y cualquier intento de mantener dos representantes activos.
  También deberán auditarse la selección y cada cambio del destinatario primario de notificaciones; la corrección de tipo o número de documento con valores anteriores y nuevos, motivo, declaración de verificación, actor y resultado de unicidad; el ciclo de cambio de correo con inicio, verificación, activación y fallos; y la creación del primer turno que establece la visibilidad Profesional–Paciente. Los intentos denegados o inconsistentes de estas operaciones deberán conservar su causa. El log no deberá almacenar secretos, contraseñas, hashes, códigos TOTP, códigos de verificación, tokens de Magic Link, tokens de OAuth ni fotografías o copias de documentos legales.
  El ciclo completo de recuperación de credenciales internas deberá auditar al Administrador actor y la cuenta objetivo; la declaración y el canal de verificación de identidad; el motivo; la autorización; la emisión y el resultado de entrega del enlace; su vencimiento, reemplazo por reemisión, cancelación, intentos fallidos y consumo; la finalización; y la invalidación de contraseña anterior, TOTP, sesiones y dispositivos confiables según corresponda. También se auditarán de forma diferenciada el cambio autenticado de contraseña y sus invalidaciones de acceso, y todo cambio de la política global de sesiones con actor, motivo y valores anteriores y nuevos. Nunca se registrarán contraseñas, hashes, enlaces, tokens, secretos o códigos TOTP. Los eventos de entrega registrarán su resultado sin conservar el enlace enviado.
  Para las Notas de devolución solo se auditarán la publicación y el retiro, con actor, fecha y hora del servidor, consulta vinculada y categoría del motivo de retiro cuando corresponda; el contenido nunca se incluirá. No se crearán eventos específicos de Nota por guardado o edición de borradores ni por lecturas. Los intentos de acceso denegados podrán registrarse como eventos generales de autorización sin revelar existencia, metadatos ni contenido a actores no autorizados.
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
| --- | --- | --- |
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

**Como** Administrador, **quiero** incorporar el perfil Profesional a una Persona y dejar su cuenta propia en Pendiente de activación, **para poder** asegurar una incorporación ordenada sin duplicar identidades ni historiales.

* **Valor:** 8 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que nombres, apellidos, tipo de documento controlado, número de documento normalizado y correo electrónico de la cuenta de acceso sean obligatorios para registrar un Profesional.
  * Comprobar que el género y la fecha de nacimiento no sean obligatorios para registrar un profesional.
  * Comprobar que la combinación de tipo y número normalizado de documento sea única entre Personas y que el correo electrónico sea único entre cuentas de acceso, sin restringir su proveedor.
  * Comprobar que el campo teléfono sea opcional y no bloquee el alta si no se completa.
  * Demostrar que, al registrar un profesional, la cuenta queda en estado Pendiente de activación hasta que complete la definición de contraseña y el enrolamiento TOTP mediante una invitación de un solo uso.
  * Comprobar que la contraseña de activación cumpla RF-01 bis y que el enrolamiento TOTP utilice una aplicación autenticadora y exija confirmar un código válido antes de pasar la cuenta a Activa.
  * Verificar que cuando Administrador hace el registro de un nuevo profesional consigue que el sistema genere la cuenta en estado Pendiente de activación y emita una invitación de un solo uso.
  * Verificar que, si la identidad documental ya pertenece a una Persona con otro rol, el sistema reutilice esa Persona y preserve su historial; si ya posee perfil Profesional, deberá rechazar el duplicado.
  * Verificar que un correo electrónico ya utilizado por otra cuenta de acceso sea rechazado sin modificar Personas ni perfiles.
  * Dado que los datos son válidos, cuando Administrador confirma el alta, entonces el sistema crea o reutiliza la Persona, asigna el perfil y rol Profesional y genera su cuenta propia en estado Pendiente de activación. Al definir contraseña y enrolar TOTP mediante la invitación de un solo uso, la cuenta pasa a Activa.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.3.1 | Modificación Profesional (Administrador)

**Como** administrador **quiero** poder modificar los datos de un profesional en particular **para poder** garantizar información confiable y actualizada, reduciendo inconsistencias administrativas y asegurando la correcta operación del sistema.

* **Valor:** 8 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que la edición general permita únicamente los datos habilitados y no modifique el identificador interno inmutable, los campos de identidad verificados ni la fecha de creación.
  * Comprobar que una corrección del tipo o número de documento use exclusivamente la operación reforzada de RF-03 bis, con reautenticación reciente y TOTP válido, motivo obligatorio, declaración de verificación externa y validación de unicidad.
  * Comprobar que una colisión documental bloquee la corrección sin fusionar Personas, sobrescribir datos ni transferir historial.
  * Demostrar que el sistema persiste correctamente los cambios realizados en la base de datos una vez confirmada la modificación.
  * Demostrar que cuando se modifica el correo electrónico, el sistema exige la validación previa del nuevo dato antes de activar el cambio.
  * Verificar que cuando el Administrador hace una modificación sobre los datos de un profesional consigue que la información quede actualizada correctamente dentro del sistema.
  * Verificar que cuando el Administrador hace una modificación válida del correo electrónico consigue que el sistema inicie automáticamente el proceso de verificación correspondiente sin reemplazar la identidad principal anterior.
  * Dado que el Administrador inició una modificación de correo de la cuenta de un Profesional, cuando guarda una dirección válida y única, entonces el sistema registra la solicitud, mantiene activo el correo anterior hasta verificar el nuevo, notifica los canales anteriores y audita inicio, verificación, activación y fallos.
  * Dado que una corrección documental válida se completa, cuando el sistema la confirma, entonces conserva el identificador interno de la Persona y todos sus turnos, pagos, comprobantes e historial, y audita valores anteriores y nuevos.
  * Comprobar que si el profesional ya existe en estado inactivo, el sistema permita reactivar su registro en lugar de crear uno nuevo.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 4.3.2 | Modificación Profesional (Profesional)

**Como** profesional, **quiero** actualizar determinados datos personales autorizados, **para poder** mantener mi información operativa vigente sin depender de intervención administrativa.

* **Valor:** 5 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que el profesional solo pueda editar los datos autorizados: alias bancario, teléfono, foto de perfil y datos de contacto visibles.
  * Comprobar que el sistema mantenga no habilitada la edición del correo electrónico propio del Profesional en este flujo.
  * Comprobar que el sistema bloquee en este flujo general de perfil la edición de datos restringidos como nombres y apellidos verificados, tipo y número de documento, fecha de nacimiento, fecha de alta, estado de cuenta, credenciales principales y rol asignado; el cambio propio de contraseña se realizará exclusivamente mediante RF-01 ter.
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
  * Comprobar que cada consulta muestre un icono de Nota de devolución solo cuando exista al menos una Nota publicada y no retirada, además de un indicador distinto para los borradores del Profesional; si todas están retiradas y no hay borradores, no deberá mostrarse ningún icono.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 2.2 | Crear Turno

**Como** profesional de la salud, **quiero** crear manualmente un turno en mi agenda para un paciente determinado, especificando fecha, horario y tipo de consulta **para** garantizar la continuidad y flexibilidad en la atención, permitiendo incorporar casos particulares o reagendamientos que no pueden canalizarse a través del flujo de reserva estándar del paciente, sin comprometer la integridad de la agenda.

* **Valor:** 8 | **Prioridad:** 4 | **Estimación:** 12 h
* **Validación:**
  * Dado que el profesional intenta crear un turno y adicionalmente el paciente ya tiene otro turno en el mismo horario, cuando confirma la operación, entonces el sistema rechaza la creación y muestra un mensaje de conflicto de agenda.
  * Comprobar que el Profesional solo pueda seleccionar Pacientes de su lista permitida, que el backend deniegue y audite cualquier intento fuera de alcance y que un perfil incompleto sea admisible si ya está vinculado.
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
  * Dado que una cuenta autenticada seleccionó un perfil de Paciente propio o representado, cuando accede a "Mis Turnos", entonces el sistema muestra exclusivamente los turnos de ese perfil y mantiene visible su nombre completo como contexto activo.
  * Comprobar que el acceso a un perfil representado requiera una relación activa y registre al propietario de la cuenta como actor y al Paciente seleccionado como sujeto.
  * Dado que el paciente revisa su historial, cuando visualiza la lista, entonces el sistema diferencia visualmente (por ejemplo, con etiquetas o colores) el estado de cada turno (Ej: Reservado, Confirmado, Asistió, Cancelado).
  * Dado que el paciente es nuevo o no ha realizado reservas, cuando accede a la sección de turnos, entonces el sistema muestra un mensaje amigable indicando "Aún no tienes turnos registrados".
  * Comprobar que cada consulta muestre un icono de Nota de devolución solo cuando exista al menos una Nota publicada y no retirada, sin exponer el contenido fuera del detalle; si todas están retiradas, no deberá mostrarse el icono y el marcador de retiro permanecerá en el detalle.
* **HECHO POR:** Said Quioto

### HISTORIA DE USUARIO Num: 3.1 | Editar Período

**Como** profesional de la salud, **quiero** configurar y modificar la ventana temporal de anticipación con la que los pacientes pueden realizar reservas de turno **para** adaptar la planificación de la agenda a mis necesidades operativas y administrativas, evitando reservas con escasa o excesiva anticipación que afectan la organización del centro y la calidad del servicio ofrecido.

* **Valor:** 3 | **Prioridad:** 2 | **Estimación:** 12 h
* **Validación:**
  * Dado que el profesional autenticado accede al módulo de configuración de agenda, cuando selecciona la opción "Editar Período de Reserva", entonces el sistema presenta una interfaz con los valores actuales de la ventana de reserva (días o meses) permitiendo su modificación, sin confundirla con el Intervalo de agenda.
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

**Como** Profesional de la salud, **quiero** configurar mi Intervalo de agenda y gestionar los Tipos de consulta que me pertenecen **para** ofrecer un catálogo inequívoco y reservar únicamente horarios contiguos compatibles con la duración de cada prestación, sin alterar los turnos existentes. Cada Tipo de consulta conserva identidad propia aunque repita un nombre y su duración vigente se obtiene de la cantidad de intervalos configurada.

* **Valor:** 8 | **Prioridad:** 4 | **Estimación:** 16h
* **Validación:**
  * Dado un Profesional autenticado, activo y expresamente autorizado, cuando crea un Tipo de consulta propio con nombre normalizado obligatorio de hasta 32 caracteres, precio exacto en ARS no negativo y con hasta dos decimales, color `#RRGGBB` y cantidad válida, entonces el tipo conserva identidad propia y queda disponible para reservas; un nombre normalizado duplicado no impide su creación.
  * Dado un Intervalo de agenda, cuando se valida la cantidad de un Tipo de consulta activo, entonces se admite únicamente el rango de 1 a `min(10, floor(180 / intervalo_en_minutos))`, la duración resultante no supera tres horas y se muestra en minutos.
  * Dado que se modifica o desactiva un Tipo de consulta, cuando se confirma el cambio, entonces se conservan su identidad, sus referencias históricas y las copias de nombre, duración y precio de los turnos existentes; un tipo inactivo no puede editarse, conserva su cantidad y duración al desactivarse, puede mostrarse mediante `Mostrar consultas inactivas` y deja de estar disponible solo para reservas nuevas, mientras los turnos ya reservados permanecen sin cambios y continúan usando su color actual con una señal adicional al color.
  * Dado que se selecciona un nuevo Intervalo de agenda, cuando el sistema evalúa el cambio, entonces advierte que cambiarán las duraciones activas, conserva cada cantidad y recalcula cada duración activa sin reemplazo ni adaptación individual.
  * Dado ese mismo cambio, cuando alguna duración activa resultante supera tres horas, entonces se bloquea la aplicación sin cambios y se identifican todos los tipos bloqueantes de forma inequívoca mediante sus identidades inmutables; en caso contrario, el Profesional confirma explícitamente con `Aplicar intervalo` y el cambio se aplica atómicamente.
  * Dado un tipo inactivo, cuando se solicita su reactivación, entonces conserva su cantidad y deriva la duración activa con el Intervalo de agenda vigente; si supera tres horas, la reactivación se rechaza sin cambios, identifica el tipo y no ofrece reemplazo ni adaptación.
  * Comprobar que la disponibilidad y la lista de espera utilicen la identidad, el propietario y la duración vigente del tipo activo; que las presentaciones distingan nombres duplicados mediante nombre, duración y precio y cumplan contraste WCAG AA con una señal no basada únicamente en color; y que las decisiones de autorización y resultados del catálogo o intervalo queden auditados de forma inmutable y minimizada.
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
  * Comprobar que en el listado se visualicen como mínimo nombres, apellidos, tipo y número de documento, estado del perfil, disponibilidad de cuenta propia y destinatario primario de notificaciones; el correo electrónico o teléfono propio podrán estar ausentes en perfiles representados.
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
  * Comprobar que, antes de crear el primer turno, Secretaría capture exactamente nombres, apellidos, tipo de documento controlado, número de documento normalizado y fecha de nacimiento como identidad mínima del Paciente.
  * Comprobar que el género y los demás datos no identitarios sean opcionales para el alta mínima.
  * Comprobar que la combinación de tipo y número normalizado de documento sea única entre Personas y que no se solicite país emisor ni se admitan tipos de documento libres.
  * Comprobar que el correo electrónico no sea obligatorio para el perfil de Paciente y, cuando exista una cuenta propia, sea válido y único entre cuentas de acceso sin restricción de proveedor.
  * Comprobar que el campo obra social sea opcional y no bloquee el alta si no se completa.
  * Comprobar que un perfil pueda quedar Pendiente de completar y sin cuenta, correo o teléfono propios cuando sea representado.
  * Comprobar que Secretaría pueda registrar al Paciente y crear o asignar sus turnos aunque el perfil esté incompleto o el destinatario seleccionado aún no tenga teléfono verificado, mostrando una advertencia clara.
  * Comprobar que el sistema bloquee las reservas autónomas hasta que los datos requeridos estén completos y el teléfono del destinatario primario seleccionado esté verificado.
  * Verificar que cuando la Secretaria realiza el registro de un nuevo paciente consigue que el sistema almacene correctamente la información ingresada.
  * Verificar que una identidad documental existente no cree una Persona duplicada ni vincule automáticamente una cuenta; el sistema deberá informar el caso y exigir el flujo autorizado correspondiente.
  * Verificar que, cuando falta cualquiera de los campos de identidad mínima, el sistema impida el alta e indique el campo faltante; los demás datos podrán quedar pendientes de completar.
  * Dado que la identidad mínima es válida y no existe otra Persona con el mismo tipo y número normalizado de documento, cuando Secretaría confirma el alta, entonces el sistema crea la Persona con identificador interno inmutable y el perfil de Paciente disponible para gestión interna; la autogestión solo se habilita al completar los datos requeridos y verificar el teléfono del destinatario seleccionado.
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
  * Comprobar que solo puedan acceder al comprobante el Paciente propietario, una cuenta con representación activa para ese Paciente, el Profesional asociado al turno y Secretaría.
  * Comprobar que el acceso representado registre al propietario de la cuenta como actor y al Paciente como propietario, y que sea denegado al revocarse la relación.
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
      *Comprobar que, al cancelar sin penalización una consulta Pagada, el estado pase a No corresponde, el pago original permanezca sin cambios y se genere automáticamente un saldo a favor del Paciente con ese Profesional, vinculado a dicho pago.
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
  * Comprobar que la contraseña definida durante la activación cumpla RF-01 bis y que el enrolamiento TOTP no finalice hasta confirmar un código válido de la aplicación autenticadora.
  * Comprobar que el sistema solicite usuario y contraseña válidos antes de permitir el acceso.
  * Comprobar que el sistema requiera obligatoriamente TOTP para completar el inicio de sesión, salvo cuando se aplique el recordatorio vigente de un dispositivo confiable conforme a la política global de RNF-09.
  * Comprobar que, aun con dispositivo confiable, cada nueva sesión solicite la contraseña y que el recordatorio de TOTP respete el rango global de 0 a 30 días y su valor predeterminado de 7 días.
  * Comprobar que el sistema solicite nuevamente TOTP al vencer o eliminarse la confianza, usarse un dispositivo nuevo, cambiarse el correo, la contraseña o la configuración TOTP, o detectarse actividad sospechosa.
  * Comprobar que el acceso sea denegado cuando las credenciales ingresadas sean incorrectas.
  * Comprobar que el acceso sea denegado cuando el código TOTP sea inválido, no pertenezca al intervalo actual o al inmediatamente anterior, o ya se haya utilizado con éxito.
  * Comprobar que la política global permita una duración absoluta de 4 a 12 horas, predeterminada en 12, y un bloqueo por inactividad de 5 a 30 minutos, predeterminado en 15.
  * Comprobar que las reducciones de límites bloqueen o terminen inmediatamente las sesiones actuales que ya los excedan, que las ampliaciones rijan solo para sesiones nuevas y que el desbloqueo por inactividad no reinicie la duración absoluta.
  * Comprobar que desbloquear por inactividad exija contraseña y, cuando la confianza no exista o haya vencido, TOTP.
  * Comprobar que solo Administrador pueda cambiar la política global, sin excepciones por usuario ni valores fuera de rango, mediante reautenticación reciente con contraseña y TOTP, motivo obligatorio y auditoría de valores anteriores y nuevos.
  * Comprobar que las acciones sensibles sobre credenciales, correo o TOTP requieran la reautenticación reciente definida por su flujo y que un dispositivo confiable no sustituya los factores expresamente requeridos.
  * Demostrar que únicamente los usuarios internos con credenciales válidas y segundo factor verificado, ya sea durante el inicio de sesión o dentro de un recordatorio vigente de dispositivo confiable, pueden acceder a las funcionalidades del sistema.
  * Verificar que cuando el Usuario Interno hace el ingreso de sus credenciales y completa correctamente el segundo factor de autenticación consigue acceder al sistema de acuerdo con los permisos asignados a su rol.
  * Verificar que cuando el Usuario Interno hace el ingreso de un código de segundo factor inválido o expirado consigue que el sistema rechace el acceso e informe el error correspondiente.
  * Dado que el Usuario Interno posee una cuenta activa y adicionalmente ha ingresado correctamente sus credenciales cuando completa satisfactoriamente el proceso de segundo factor de autenticación entonces el sistema concede el acceso y habilita las funcionalidades correspondientes a su rol.
* **HECHO POR:** Santiago Casali

### HISTORIA DE USUARIO Núm: 7 bis | Cambiar contraseña interna

**Como** Profesional o Secretaría con sesión autenticada, **quiero** cambiar mi contraseña mediante una comprobación reforzada, **para** reemplazarla sin conservar accesos asociados a la credencial anterior.

* **Validación:**
  * Comprobar que Administrador quede fuera de este autoservicio y que Profesional o Secretaría deban ingresar la contraseña vigente y un TOTP vigente aunque utilicen un dispositivo confiable.
  * Comprobar que la contraseña nueva tenga entre 12 y 128 caracteres, admita espacios y frases de contraseña, rechace valores comunes o comprometidos, no reutilice la contraseña vigente y no aplique reglas de composición ni vencimiento periódico.
  * Dado que el cambio finaliza correctamente, comprobar que se invaliden inmediatamente todas las sesiones —incluida la actual— y todos los dispositivos confiables, que la contraseña anterior deje de ser utilizable y que el TOTP existente se conserve.
  * Comprobar que el sistema envíe un aviso de seguridad sin secretos al correo verificado vigente y que el acceso siguiente exija contraseña nueva y TOTP.

### HISTORIA DE USUARIO Núm: 7 ter | Recuperar credenciales internas

**Como** Profesional o Secretaría con cuenta administrativamente Activa, **quiero** recuperar mi contraseña, mi TOTP o ambos mediante una autorización administrativa verificable, **para** restablecer el acceso sin exponer secretos al Administrador.

* **Validación:**
  * Comprobar que la recuperación del Administrador quede fuera de alcance, que una cuenta Pendiente de activación utilice reemisión de invitación y que una cuenta inactiva deba reactivarse antes.
  * Comprobar que la solicitud se origine fuera de la aplicación aunque exista una sesión y que el Administrador verifique presencialmente o mediante un canal laboral registrado previamente, dejando declaración y canal.
  * Comprobar que autorizar y emitir la recuperación, reemitirla o cancelarla exija al Administrador contraseña y TOTP validados dentro de los cinco minutos anteriores, además de motivo obligatorio, sin aceptar la confianza del dispositivo como sustituto.
  * Dado que se autoriza una recuperación, comprobar que la cuenta permanezca administrativamente Activa, pase a `Recuperación pendiente`, invalide todas las sesiones y dispositivos confiables y bloquee la autenticación; en la recuperación de contraseña, la contraseña anterior deberá quedar inutilizable, y en la de TOTP deberá invalidarse de inmediato el secreto anterior.
  * Comprobar que el enlace sea opaco, de un solo uso, enviado únicamente al correo verificado vigente y válido durante 30 minutos según la hora del servidor; una reemisión deberá invalidar todos los anteriores.
  * Comprobar que abrir el enlace o enviar una contraseña que incumpla la política no lo consuma, que solo se consuma después de guardar exitosamente y que el quinto envío fallido lo invalide sin bloquear administrativamente la cuenta.
  * Comprobar que el vencimiento o la cancelación mantengan la autenticación bloqueada y la contraseña anterior inutilizable, y que un correo vigente inaccesible exija primero el procedimiento reforzado y separado de cambio de correo.
  * Dado que solo se recupera la contraseña, comprobar que la finalización exija enlace válido, TOTP vigente y contraseña nueva conforme a la política, conserve el TOTP y obligue a iniciar una sesión nueva con contraseña nueva y TOTP.
  * Dado que solo se recupera TOTP, comprobar que el titular ingrese la contraseña vigente y enrole y confirme el TOTP nuevo, sin superposición entre los secretos anterior y nuevo y sin códigos de recuperación de respaldo.
  * Dado que se perdieron contraseña y TOTP, comprobar que la verificación sea exclusivamente presencial y que la contraseña nueva y el TOTP nuevo se definan y confirmen atómicamente antes de desbloquear la autenticación.
  * Comprobar que el Administrador nunca vea enlaces, tokens, contraseñas ni secretos TOTP, y que el inicio y la finalización envíen avisos al correo verificado vigente sin canal secundario automático ni secretos, salvo el enlace aplicable en la emisión.
  * Comprobar que la auditoría registre el ciclo completo y las invalidaciones exigidas por RF-23 sin almacenar contraseñas, hashes, enlaces, tokens, secretos ni códigos TOTP.

### HISTORIA DE USUARIO Núm: 8.1 | Iniciar Sesión con Google

**Como** Paciente, **quiero** autenticar mi cuenta de acceso mediante Google y seleccionar un perfil de Paciente vinculado, **para** operar de forma passwordless sobre mi perfil propio o uno representado sin confundir la cuenta con la Persona atendida.

* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema permita al paciente iniciar el proceso de autenticación utilizando una cuenta de Google válida.
  * Comprobar que Google OAuth autentique la cuenta de acceso por su correo electrónico y no otorgue acceso a perfiles basándose en documento o fecha de nacimiento.
  * Comprobar que el acceso sea denegado cuando la autenticación con Google no pueda completarse satisfactoriamente.
  * Demostrar que, si ya existe una cuenta de acceso con ese correo, el sistema no crea un duplicado y abre el selector con sus perfiles de Paciente vinculados.
  * Demostrar que, si el correo es nuevo y el tipo y número normalizado de documento proporcionados no existen, el sistema puede crear una cuenta de acceso y un perfil propio de Paciente Pendiente de completar.
  * Verificar que, si la identidad documental ya existe, el sistema no crea ni vincula automáticamente una Persona o perfil, aunque coincida la fecha de nacimiento, y deriva el caso a Secretaría para verificación externa y otorgamiento explícito.
  * Verificar que el perfil Pendiente de completar no pueda reservar autónomamente hasta completar los datos requeridos y verificar el teléfono del destinatario primario seleccionado.
  * Comprobar que la sesión de Paciente creada mediante Google cumpla RNF-10.
  * Demostrar que el paciente puede acceder al sistema sin necesidad de ingresar una contraseña propia de la plataforma.
  * Verificar que, después de autenticarse, el usuario deba seleccionar un perfil vinculado y vea permanentemente el nombre completo del Paciente activo mediante un texto equivalente a «Estás gestionando a…».
  * Verificar que pueda volver al selector y cambiar de perfil dentro de la misma sesión sin repetir Google OAuth, y que cada selección y cambio quede auditado con actor y perfil sujeto.
  * Verificar que cuando el Paciente hace la cancelación o rechazo del proceso de autenticación en Google consigue que el sistema interrumpa el inicio de sesión sin conceder acceso.
  * Dado que el usuario posee una cuenta de Google válida y autoriza el acceso, cuando completa Google OAuth, entonces el sistema autentica la cuenta por correo electrónico y muestra exclusivamente sus perfiles vinculados; solo después de seleccionar uno concede acceso a sus funciones.
* **HECHO POR:** Santiago Casali (borrador)

### HISTORIA DE USUARIO Núm: 8.2 | Iniciar Sesión con Magic Link

**Como** Paciente, **quiero** acceder al sistema a través de un Magic Link enviado a mi correo electrónico, **para** poder iniciar sesión de forma rápida y segura sin necesidad de recordar una contraseña.

* **Valor:** 13 | **Prioridad:** 5 | **Estimación:** 16 h
* **Validación:**
  * Comprobar que el sistema permita al paciente solicitar un Magic Link utilizando un correo electrónico.
  * Comprobar que el Magic Link generado sea único, seguro y posea un tiempo de validez limitado.
  * Comprobar que, si existe una cuenta elegible asociada al correo ingresado, el sistema envíe el Magic Link a esa cuenta; si el correo es nuevo, el alta deberá aplicar las validaciones documentales de RF-01 antes de crear una cuenta y un perfil propio Pendiente de completar.
  * Comprobar que el acceso sea denegado cuando el Magic Link haya expirado o ya haya sido utilizado.
  * Comprobar que la sesión de Paciente creada mediante Magic Link cumpla RNF-10.
  * Demostrar que el paciente puede acceder al sistema sin necesidad de ingresar una contraseña.
  * Demostrar que el sistema autentica correctamente al paciente cuando utiliza un Magic Link válido dentro del período de vigencia establecido.
  * Verificar que cuando el Paciente hace la solicitud de acceso mediante Magic Link recibe la respuesta visible: "Si el correo está registrado, recibirás un enlace de acceso."
  * Verificar que cuando el Paciente hace uso de un Magic Link válido consigue acceder al sistema sin necesidad de ingresar credenciales adicionales.
  * Verificar que cuando el Paciente hace uso de un Magic Link expirado o previamente utilizado consigue que el sistema rechace el acceso e informe el motivo correspondiente.
  * Dado que la cuenta posee un Magic Link válido, cuando accede al enlace dentro del período de vigencia, entonces el sistema autentica la cuenta y exige seleccionar uno de sus perfiles de Paciente vinculados antes de operar.
  * Comprobar que un correo nuevo no permita vincular automáticamente una Persona existente mediante tipo o número de documento o fecha de nacimiento y que el caso sea derivado a Secretaría.
  * Comprobar que cada nueva solicitud de Magic Link invalide los enlaces previamente generados para la misma cuenta.
  * Demostrar que el paciente puede solicitar un nuevo Magic Link en caso de que el anterior haya expirado.
  * Verificar que cuando el Paciente hace una solicitud utilizando un correo electrónico no registrado consigue la misma respuesta visible: "Si el correo está registrado, recibirás un enlace de acceso."
  * Verificar que cuando el Paciente hace múltiples solicitudes consecutivas de Magic Link consigue que únicamente el enlace más reciente permanezca válido.
  * Comprobar que el nombre completo del Paciente seleccionado permanezca visible, que el usuario pueda cambiar entre perfiles vinculados sin otro Magic Link durante la misma sesión y que cada cambio quede auditado.
  * Comprobar que, después de cerrar sesión, el usuario necesite solicitar y utilizar un nuevo Magic Link.
* **HECHO POR:** Santiago Casali (borrador)

### HISTORIA DE USUARIO Núm: 8.3 | Gestionar representación de Paciente

**Como** Secretaría o Profesional autorizado, **quiero** activar, revocar o reemplazar la representación de un Paciente, **para** otorgar acceso explícito y trazable sin compartir correos ni duplicar Personas.

* **Valor:** 21 | **Prioridad:** 5 | **Estimación:** Pendiente de estimación
* **Validación:**
  * Comprobar que el representante ya esté registrado como Paciente y que la operación no cree un rol adicional ni una cuenta sin rol.
  * Comprobar que Secretaría pueda operar sobre cualquier Paciente registrado y que el Profesional solo pueda hacerlo sobre Pacientes de su lista permitida, sin acceso al registro global.
  * Comprobar que, antes de activar, el actor interno registre el tipo de relación y una declaración de verificación externa de identidad y autoridad, junto con fecha y hora del servidor, sin cargar fotografías ni copias de documentos legales.
  * Comprobar que un Paciente tenga como máximo un representante activo y que un representante pueda representar varios Pacientes.
  * Dado que existe un representante activo, cuando personal autorizado confirma un reemplazo válido, entonces el sistema desactiva la relación anterior y activa la nueva atómicamente, sin estados intermedios ni dos representantes activos.
  * Comprobar que activación, revocación y reemplazo envíen avisos de seguridad por canales verificados, auditen éxitos y fallos y no dependan de edad, vencimiento ni transición automática.
  * Comprobar que el acceso independiente y la representación puedan coexistir y que agregar o cambiar el correo propio del representado no revoque automáticamente la representación.
  * Comprobar que el personal seleccione un único destinatario primario de notificaciones y deba elegir al representante si el Paciente no posee teléfono verificado.
  * Dado que la relación está activa, cuando el representante reserva o cancela turnos, confirma asistencia, gestiona la lista de espera, consulta historial operativo o carga o visualiza comprobantes aplicables, entonces el backend autoriza la acción y audita al propietario de la cuenta como actor y al representado como sujeto.
  * Dado que la relación está inactiva, ausente o fuera de alcance, cuando la cuenta intenta operar sobre el perfil representado, entonces el backend deniega por defecto y audita el intento.
  * Comprobar que el representante no pueda modificar identidad verificada, correo, credenciales ni relaciones de representación.
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

**Como** Paciente o Secretaría, **quiero** modificar únicamente los datos autorizados de un perfil de Paciente, **para** mantener actualizada su información sin alterar indebidamente su identidad, acceso o representación.

* **Valor:** 8 | **Prioridad:** 3 | **Estimación:** 12 h
* **Validación:**
  * Comprobar que el sistema permita editar los datos habilitados del paciente.
  * Comprobar que la edición general no permita modificar nombres, apellidos, tipo o número de documento ni fecha de nacimiento verificados.
  * Comprobar que solo Secretaría o Administrador puedan corregir tipo o número de documento mediante RF-03 bis y que la combinación normalizada permanezca única entre Personas.
  * Comprobar que el correo electrónico se gestione sobre la cuenta de acceso, mantenga unicidad entre cuentas y pueda pertenecer a cualquier proveedor.
  * Demostrar que los cambios realizados sean almacenados correctamente en la base de datos.
  * Verificar que cuando la Secretaria modifica datos válidos de un paciente consigue que la información quede actualizada correctamente.
  * Verificar que una corrección documental que colisione con otra Persona sea rechazada sin fusionar, sobrescribir ni transferir historial.
  * Verificar que solo Secretaría o Administrador puedan iniciar el cambio de correo de una cuenta con acceso de Paciente y que el correo anterior continúe activo hasta verificar el nuevo.
  * Verificar que Secretaría pueda iniciar cambios de correo únicamente para cuentas con acceso a perfiles de Paciente y no para cuentas de Profesional, Administrador ni otras Secretarías.
  * Comprobar que ningún actor pueda activar un correo no verificado, que se notifiquen los canales verificados anteriores y que inicio, verificación, activación y fallos queden auditados.
  * Comprobar que el cambio modifique solo el correo o vínculo de acceso, conserve la Persona, perfiles, representación e historial y no se inicie automáticamente por edad.
  * Comprobar que el Paciente, el Paciente que actúa como representante dentro de su alcance o Secretaría puedan completar datos no identitarios autorizados y gestionar el teléfono correspondiente sin modificar identidades ni representación.
  * Comprobar que, al cambiar el teléfono actualmente seleccionado como destinatario primario, se suspendan inmediatamente las automatizaciones y WhatsApp al número anterior.
  * Comprobar que, mientras el nuevo teléfono seleccionado como destinatario esté pendiente de validación por código, no reciba mensajes ni habilite reservas autónomas y los turnos próximos queden señalados para contacto o revisión manual de Profesional y Secretaría.
  * Comprobar que, al validar el código enviado al nuevo teléfono y seleccionarlo como destinatario primario, se activen ese número, WhatsApp y la autogestión del perfil cuando todos los datos requeridos estén completos.
  * Verificar que el inicio del cambio, la suspensión, el envío, la validación y cada fallo del código, la activación, el actor y los turnos afectados queden auditados.
  * Verificar que cuando la Secretaria modifica información obligatoria dejando campos vacíos consigue que el sistema impida guardar los cambios.
  * Dado que Secretaría realizó modificaciones válidas sobre datos autorizados, cuando confirma la operación, entonces el sistema actualiza solo esos campos, conserva el identificador interno y el historial de la Persona y registra actor, sujeto y cambios realizados.
* **HECHO POR:** Lucca Giordana

### HISTORIA DE USUARIO Num: 2.5.1 | Reservar turno (Paciente)

**Como** Paciente, **quiero** reservar un turno seleccionando un profesional, fecha y horario disponible, **para** asegurar mi turno de manera rápida y sin necesidad de asistencia administrativa.

* **Valor:** 21 | **Prioridad:** 5 | **Estimación:** 24 h
* **Validación:**
  * Comprobar que el sistema muestre únicamente horarios disponibles para la reserva.
  * Comprobar que el sistema muestre al paciente el límite de cancelación aplicable antes de confirmar la reserva.
  * Comprobar que el sistema muestre al paciente la política de multa y el porcentaje vigente, si corresponde, antes de confirmar la reserva.
  * Comprobar que el sistema impida la reserva autónoma cuando el perfil seleccionado esté incompleto o el teléfono verificado no corresponda al destinatario primario seleccionado, e informe claramente la condición pendiente.
  * Comprobar que una cuenta con representación activa pueda reservar para el perfil representado y que la auditoría distinga al actor del Paciente sujeto.
  * Comprobar que, al validar el teléfono del destinatario primario seleccionado y completar el perfil, el Paciente recupere la posibilidad de realizar reservas autónomas.
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
  * Comprobar que, antes del primer turno, el Paciente posea nombres, apellidos, tipo de documento controlado, número normalizado y fecha de nacimiento; si faltan, Secretaría deberá capturarlos antes de continuar.
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
  * Dado que Secretaría seleccionó un Paciente registrado y existe disponibilidad en la agenda del Profesional, cuando confirma su primer turno, entonces el sistema registra el turno, establece de forma auditable la visibilidad Profesional–Paciente y agrega al Paciente a la lista permitida del Profesional. Antes de D-1 lo registra como Reservado o Confirmado según la elección explícita de Secretaría; durante D-1, solo como Confirmado con la declaración exigida.
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
  * Comprobar que el Profesional pueda gestionar turnos de un Paciente incompleto únicamente cuando una primera reserva válida —autónoma del Paciente o asistida por Secretaría— ya lo incorporó a su lista permitida.
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
  * Comprobar que cada mensaje se envíe una sola vez al teléfono verificado del destinatario primario seleccionado y pueda saludar al Paciente relevante con sus nombres y apellidos completos; además, que incluya solo el nombre del centro, el nombre del Profesional, la fecha y horario, el consultorio o ubicación y la acción necesaria, y no incluya tipo ni número de documento —incluido DNI—, tipo de consulta, pagos, montos, multas, estado financiero, comprobantes ni datos clínicos o sensibles.
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

### HISTORIA DE USUARIO Núm: 2.11 | Publicar Nota de devolución

**Como** Profesional asociado a una consulta atendida, **quiero** publicar una comunicación no clínica para el perfil de Paciente correspondiente, **para** compartir recomendaciones generales, próximos pasos, recordatorios u observaciones no diagnósticas después de la consulta.

* **Validación:**
  * Comprobar que solo el Profesional asociado pueda crearla y que el turno esté en Asistió al publicar dentro de los siete días exactos posteriores al inicio programado, según hora del servidor y sin usar una hora real de inicio.
  * Comprobar que el título sea opcional y no supere 100 caracteres, que el cuerpo sea obligatorio y no supere 5.000, y que ambos admitan formato básico y enlaces web seguros bajo las mismas reglas de contenido.
  * Comprobar que se admitan recomendaciones generales, próximos pasos, recordatorios y observaciones no diagnósticas, y se prohíban diagnóstico, prescripción, dosis de medicamentos, resultados de estudios, evolución clínica, información urgente o crítica en el tiempo, imágenes, PDF y adjuntos; la interfaz deberá indicar que la comunicación urgente utiliza un canal externo sin prometer control por palabras clave o inteligencia artificial.
  * Comprobar que la Nota muestre autor, destinatario y el texto exacto definido en RF-13 bis.
  * Dado que existe un borrador, comprobar que sea privado y editable por su autor y que, al vencer el plazo, quede de solo lectura para este, no pueda publicarse y pueda eliminarse.
  * Dado que el Profesional intenta publicar, comprobar que vea la representación exacta que verá el Paciente con perfil y destinatario resueltos, consulta, título opcional, cuerpo y enlaces, y que deba confirmar el destinatario y declarar que el contenido es no clínico.
  * Comprobar que puedan publicarse múltiples Notas independientes sin relación de corrección y aunque el Paciente no tenga cuenta actual, representante activo o teléfono verificado.
  * Dado que el estado se corrige posteriormente de Asistió a No asistió o Cancelado, comprobar que las Notas publicadas permanezcan visibles y retirables, pero no puedan publicarse nuevas mientras el turno no esté en Asistió.
  * Comprobar que una Nota publicada sea inmutable, no admita respuesta ni acuse y solo pueda retirarla su Profesional creador en cualquier momento, incluso después de su lectura.
  * Dado que se retira una Nota, comprobar que el Paciente pierda acceso al contenido, el original inmutable permanezca accesible para el autor, el portal muestre un marcador con fecha y categoría del motivo y no se envíe WhatsApp.
  * Dado que el autor está inactivo, comprobar que el Paciente conserve acceso, el autor no pueda acceder, no exista transferencia y nadie pueda retirar la Nota hasta una reactivación legítima.
  * Comprobar que solo accedan al contenido el Profesional creador y el perfil de Paciente destinatario por cuenta propia o representante activo; un representante nuevo deberá ver las Notas históricas vigentes y el anterior perder acceso inmediatamente.
  * Comprobar que un enlace profundo exija autenticación y autorización actual, active el perfil correcto y lo muestre visiblemente, sin funcionar como credencial portadora.
  * Comprobar que Secretaría y Administrador no dispongan de interfaz que revele existencia, metadatos o contenido, que ningún otro Profesional acceda y que la Nota aparezca únicamente en el detalle de la consulta, sin bandeja longitudinal global.
  * Comprobar que Origen no genere PDF ni ofrezca descarga, sin afirmar que puede impedir copia, impresión o capturas del navegador, y que la retención aplique la política general futura sin eliminación automática mientras permanezca pendiente ni confundir retiro con eliminación.
  * Dado que se publica una Nota, comprobar que se intente una sola vez y de inmediato un aviso genérico independiente al destinatario primario verificado, sin contenido, agregación, reintento automático ni reenvío manual, y con un enlace autenticado.
  * Comprobar que el fallo del aviso no revierta la publicación y muestre `La devolución fue publicada correctamente, pero el mensaje de aviso falló.`; si no hay destinatario con teléfono verificado, deberá mostrar `La devolución fue publicada correctamente, pero no se envió el aviso porque no existe un destinatario con teléfono verificado.` y no enviar un aviso posterior.
  * Comprobar que una cuenta o representación habilitada posteriormente permita ver las Notas previas vigentes sin aviso retroactivo por WhatsApp y que se utilice el término `aviso`, reservando `recordatorio` para D-2/D-1.
  * Comprobar que solo publicación y retiro generen eventos específicos de auditoría con actor, fecha y hora del servidor, consulta y categoría del motivo de retiro cuando corresponda; guardados o ediciones de borrador y lecturas no deberán generarlos, y el contenido nunca deberá aparecer en logs, auditoría ni WhatsApp.

---

## Pila de tareas (Product Backlog) - Sprint 0

| ID Tarea | Categoría | Descripción Técnica | Dependencia Asociada |
| --- | --- | --- | --- |
| T0.1 | DevOps y Git | **Inicialización del Repositorio Centralizado:** Crear el repositorio en GitHub para el proyecto “Origen”. Configurar las ramas principales (main, develop) y establecer reglas de protección para que no se suba código a producción sin que este haya sido revisado. | N/A |
| T0.2 | DevOps y Git | **Definición del Estándar de Ramas e Historial (Git Flow):** Acordar con el grupo de trabajo la nomenclatura de ramas de trabajo y las convenciones de mensajes de Commit, etc. | T0.1 |
| T0.3 | DevOps y Git | **Decisión para el stack tecnológico:** Acordar con el grupo de trabajo qué tecnologías se van a implementar para el desarrollo de los módulos del sistema (Frontend, Backend, BD, etc.). | N/A |
| T0.4 | Arquitectura | **Inicialización del Proyecto Backend:** Estructurar el framework elegido e implementar el log inmutable de RF-23, preparado para distinguir cuenta o Persona actora, Paciente sujeto, operación, resultado, fecha y hora del servidor, sin almacenar secretos, códigos, tokens ni copias de documentos legales. | T0.3 |
| T0.5 | Arquitectura | **Inicialización del proyecto Frontend:** Crear el armazón del frontend. Instalar librerías de componentes UI (o desarrollarlos) que aseguren el cumplimiento del Requisito de Diseño Responsivo (RD-01) para resoluciones de monitores, tabletas y móviles. | T0.3 |
| T0.6 | Arquitectura | **Migración Inicial de la Base de Datos:** Crear las tablas e índices para Persona, perfiles, roles acumulables, cuentas de acceso, identidad documental controlada, representación, destinatario primario, relación Profesional–Paciente, turnos y estados financieros, con sus unicidades y cardinalidades. | T0.3 |
| T0.9 | Metodología | **Puesta a punto de la Herramienta de Gestión (Jira / Trello):** Cargar todas las historias de usuario del backlog (módulos 1, 2, 3, 4 y 5) en el tablero ágil. Configurar las columnas del flujo de trabajo (Ej: To Do, In Progress, Code Review, Testing, Done). | N/A |
| T0.10 | Metodología | **Definición de “Definition of Done” (DoD):** Pactar el criterio unificado de cuándo una tarea está realmente terminada. Por ejemplo: “Código subido a develop + pasa pruebas de validación con los escenarios Dado que/Cuando/Entonces escritos + para las pantallas principales, cumple el percentil 95 de Rend-02 y RNF-05 cuando aplique + si implementa un flujo crítico, se prueba en la matriz de RD-02 + si implementa permisos críticos, cuenta con pruebas automatizadas de esos permisos.” | N/A |
| T0.11 | Seguridad | **Matriz de autorización:** Definir la matriz de RNF-08 incluyendo selección de perfil, representación activa, actor/sujeto, corrección documental, cambio de correo, destinatario de notificaciones y alcance Profesional–Paciente con denegación por defecto. | N/A |
| T0.12 | Seguridad | **Bootstrap inicial del Administrador:** Preparar el proceso único de despliegue que provisiona al primer Administrador sin credenciales predeterminadas, emite su invitación de un solo uso y registra los eventos exigidos por RF-23. | T0.4, T0.6 |

Este Sprint asegura que las bases de datos locales queden exactamente en el mismo estado maduro que expone nuestro Diagrama Entidad-Relación de la sección de Apéndices.

**Entorno de Trabajo y Repositorio (DevOps y Git)**

* **Tarea 0.1: Inicialización del Repositorio Centralizado**
    Descripción: Crear el repositorio en GitHub para el proyecto “Origen”. Configurar las ramas principales (main, develop) y establecer reglas de protección para que no se suba código a producción sin que este haya sido revisado.
* **Tarea 0.2: Definición del Estándar de Ramas e Historial (Git Flow)**
    Descripción: Acordar con el grupo de trabajo la nomenclatura de ramas de trabajo y las convenciones de mensajes de Commit, etc.
* **Tarea 0.3: Decisión para el stack tecnológico**
    Descripción: Acordar con el grupo de trabajo qué tecnologías se van a implementar para el desarrollo de los módulos del sistema (Frontend, Backend, BD, etc).

**Preparación de la Arquitectura de Software (Backend y Frontend)**

* **Tarea 0.4: Inicialización del Proyecto Backend**
    Descripción: Estructurar el framework elegido para el backend e implementar el log inmutable de RF-23, preparado para distinguir cuenta o Persona actora, Paciente sujeto, operación, resultado, fecha y hora del servidor, sin almacenar secretos, códigos, tokens ni copias de documentos legales.
* **Tarea 0.5: Inicialización del proyecto Frontend**
    Descripción: Crear el armazón del frontend. Instalar librerías de componentes UI (o desarrollarlos) que aseguren el cumplimiento del Requisito de Diseño Responsivo (RD-01) para resoluciones de monitores, tabletas y móviles.
* **Tarea 0.6: Migración Inicial de la Base de Datos**
    Descripción: Escribir los scripts de migración para separar Persona, perfiles y cuentas de acceso; permitir roles acumulables; imponer unicidad de identidad documental y correo en sus ámbitos; representar la cardinalidad de representación y destinatario primario; y conservar relaciones Profesional–Paciente, turnos y estados financieros.

**Calidad y Metodología (Aseguramiento del Proceso Scrum)**

* **Tarea 0.9: Puesta a punto de la Herramienta de Gestión (Jira / Trello)**
    Descripción: Cargar todas las historias de usuario del backlog (módulos 1, 2, 3, 4 y 5) en el tablero ágil. Configurar las columnas del flujo de trabajo (Ej: To Do, In Progress, Code Review, Testing, Done).
* **Tarea 0.10: Definición de “Definition of Done” (DoD)**
    Descripción: Pactar el criterio unificado de cuándo una tarea está realmente terminada. Por ejemplo: “Código subido a develop + pasa pruebas de validación con los escenarios Dado que/Cuando/Entonces escritos + para las pantallas principales, cumple el percentil 95 de Rend-02 y RNF-05 cuando aplique + si implementa un flujo crítico, se prueba en la matriz de RD-02 + si implementa permisos críticos, cuenta con pruebas automatizadas de esos permisos.”
* **Tarea 0.11: Matriz de autorización**
    Descripción: Definir y revisar la matriz única exigida por RNF-08 antes de implementar módulos sensibles, incluyendo selección de perfil, representación activa, actor y sujeto, corrección documental, cambio de correo, destinatario de notificaciones y alcance Profesional–Paciente con denegación por defecto.
* **Tarea 0.12: Bootstrap inicial del Administrador**
    Descripción: Preparar el proceso único de despliegue que provisiona al primer Administrador sin credenciales predeterminadas, emite su invitación de un solo uso y registra los eventos exigidos por RF-23.

---

## Pila de tareas (Product Backlog) - Sprint 1

> Esta pila conserva identificadores, asignaciones y estimaciones históricas. Para la planificación vigente de las próximas dos semanas y su reestimación, ver [Plan tentativo revisado](sprints/PLAN_TENTATIVO_11_SPRINTS.md). En caso de diferencia de alcance o secuencia, ese plan revisado reemplaza esta distribución histórica sin alterar los requisitos funcionales.

| ID Tarea | Categoría | Descripción Técnica | Dependencia Asociada |
| --- | --- | --- | --- |
| T1.1 | Autenticación | Login Interno con Segundo Factor de Autenticación (HU 7) | T0.4, T0.6, T0.12 |
| T1.2 | Gestión de Pacientes | Alta de Persona y perfil de Paciente, identidad documental y verificación del destinatario telefónico (HU 1.1) | T1.1, T0.6 |
| T1.3 | Gestión de Profesionales | Alta de Profesional (HU 4.2) | T1.1, T0.6 |
| T1.4 | Gestión de Profesionales | Listar Profesionales (HU 4.1) | T1.3 |
| T1.5 | Configuración de Agenda | Editar Disponibilidad del Profesional (HU 3.2) | T1.3, T0.6 |
| T1.5.1 | Configuración de Agenda | Definir Tipos de Consulta (mínimo) (HU 3.3) | T1.3, T0.6 |
| T1.6 | Gestión de Turnos | Visualizar Turnos Internos del Profesional (HU 2.1) | T1.5, T1.2 |
| T1.6.1 | Gestión de Turnos | Crear primera reserva válida por Paciente o Secretaría (HU 2.5.1 / 2.5.2 mínimo) | T1.2, T1.3, T1.5, T1.5.1 |
| T1.7 | Gestión de Turnos | Crear Turno por Profesional (HU 2.2 / 2.5.3) | T1.6, relación válida creada, T1.2, T1.5.1 |
| T1.8 | Interfaces Externas | Notificación WhatsApp Post-Creación (RF-17 parcial) | T1.7, T1.2 |
| T1.9 | Calidad y Metodología | Tests E2E del Flujo Crítico, incluida primera reserva autónoma o asistida | Todas |
| T1.10 | Metodología | Puesta a Punto de Definition of Done (DoD) | N/A |

### Autenticación

**Tarea T1.1: Login Interno con Segundo Factor de Autenticación (HU 7)**

* **Descripción:** Implementar el flujo de activación y autenticación para usuarios internos del sistema (Administrador, Profesional y Secretaría). El primer Administrador será provisionado por T0.12 y deberá definir contraseña y enrolar TOTP mediante su invitación de un solo uso antes de quedar Activo. Un Administrador podrá crear cuentas de Profesional y Secretaría en Pendiente de activación; cada una deberá definir contraseña y enrolar TOTP mediante su invitación de un solo uso para pasar a Activa. Solo las cuentas Activas podrán iniciar sesión con correo, contraseña y TOTP válido. Cada nueva sesión deberá requerir contraseña, tendrá una duración máxima absoluta de 12 horas y se bloqueará tras 30 minutos de inactividad. En un dispositivo declarado confiable, el segundo factor podrá recordarse hasta 30 días; deberá requerirse nuevamente al vencer ese plazo, usarse un dispositivo nuevo, cambiarse el correo, la contraseña o la configuración de 2FA, o detectarse actividad sospechosa. El recordatorio no elimina la obligatoriedad de TOTP. Las acciones sensibles sobre credenciales, correo o TOTP requerirán reautenticación reciente. El sistema deberá rechazar accesos con credenciales inválidas y códigos incorrectos o expirados. Google OAuth será exclusivo de Pacientes y no integrará este flujo interno. El bootstrap, la emisión, el consumo y cada fallo de invitación, la configuración de contraseña, el enrolamiento TOTP y la activación deberán auditarse según RF-23. Esta tarea completa la implementación del requisito funcional RF-01 para usuarios internos.
* **Estimación:** 24 horas

### Gestión de Pacientes

**Tarea T1.2: Alta de Paciente (HU 1.1)**

* **Descripción:** Crear el endpoint POST /pacientes y la interfaz de registro para que Secretaría cree una Persona y su perfil de Paciente con la identidad mínima exigida: nombres, apellidos, tipo de documento del catálogo controlado, número normalizado y fecha de nacimiento. La combinación documental deberá ser única entre Personas; no se solicitará país emisor ni se aceptarán tipos libres. El género y la obra social permanecerán opcionales. El perfil podrá quedar Pendiente de completar y no requerirá cuenta, correo ni teléfono propios. Si se crea una cuenta de acceso, su correo deberá ser válido, único entre cuentas y de cualquier proveedor. La gestión interna permanecerá habilitada mientras el perfil esté incompleto, pero la reserva autónoma exigirá completar los datos requeridos y verificar el teléfono del destinatario primario seleccionado. El alta, la colisión documental, la selección del destinatario, el envío y validación del código y sus fallos deberán auditarse sin almacenar el código. Esta tarea cubre HU 1.1 y las bases de RF-02 y RF-02 ter; la representación permanece diferida. El acceso sin contraseña y la preparación del perfil propio para la reserva autónoma se incorporan al horizonte vigente mediante el [plan tentativo revisado](sprints/PLAN_TENTATIVO_11_SPRINTS.md).
* **Estimación:** 12 h base + reestimación pendiente del equipo

### Gestión de Profesionales

**Tarea T1.3: Alta de Profesional (HU 4.2)**

* **Descripción:** Crear el endpoint POST /profesionales y la pantalla administrativa para registrar o reutilizar una Persona mediante nombres, apellidos, tipo de documento controlado y número normalizado, y asignarle el perfil y rol Profesional sin duplicarla por rol. Si la Persona ya posee perfil Profesional, la operación deberá rechazarse. La cuenta interna propia requerirá un correo electrónico válido, único entre cuentas y de cualquier proveedor. El género y la fecha de nacimiento no deberán solicitarse para este rol y el teléfono será opcional. La cuenta quedará Pendiente de activación hasta definir contraseña y enrolar TOTP mediante una invitación de un solo uso; solo entonces pasará a Activa. Esta tarea implementa HU 4.2 y contribuye a RF-01, RF-02 y RF-04.
* **Estimación:** 16 horas

**Tarea T1.4: Listar Profesionales (HU 4.1)**

* **Descripción:** Crear el endpoint GET /profesionales con soporte para paginación server-side. El listado deberá mostrar únicamente profesionales activos (sin fecha de cierre), permitir búsquedas por nombre y apellido, y aplicar filtros básicos definidos por negocio. La evaluación de rendimiento deberá referenciar el percentil 95 definido en Rend-02. Esta tarea cubre la Historia de Usuario 4.1.
* **Estimación:** 12 horas

### Configuración de Agenda

**Tarea T1.5: Editar Disponibilidad del Profesional (HU 3.2)**

* **Descripción:** Implementar el módulo que permita a los profesionales: Configurar horarios regulares de atención. Registrar ausencias. Bloquear días feriados. Definir la ventana temporal disponible para reservas futuras. Cuando la operación afecte turnos futuros activos, el sistema deberá detectar y mostrar todos los conflictos, impedir el guardado mientras existan turnos alcanzados y conservar intactos esos turnos hasta que sean reprogramados o cancelados uno por uno mediante los flujos ya definidos. Una vez aplicada la modificación sin conflictos, la disponibilidad deberá reflejarse inmediatamente en el calendario utilizado por los pacientes. Esta tarea implementa la Historia de Usuario 3.2 y el requisito RF-07.
* **Estimación:** 24 horas

**Tarea T1.5.1: Definir Tipos de Consulta e Intervalo de agenda (HU 3.3)**

* **Descripción:** Implementar el contrato de HU 3.3 y RF-08 para que el Profesional autenticado, activo, expresamente autorizado y propietario configure su Intervalo de agenda y gestione el ciclo de vida de sus Tipos de consulta. El alcance deberá aplicar las validaciones de nombre, precio exacto en ARS, color, estado, cantidad y duración activa máxima de tres horas; obtener la duración en minutos; permitir nombres duplicados sin usarlos como identidad; advertir y exigir `Aplicar intervalo`, conservar las cantidades y recalcular las duraciones activas, bloqueando el cambio si alguna supera tres horas; conservar identidad, cantidad, duración histórica y turnos ya reservados al desactivar; impedir la edición inactiva; y reactivar sin reemplazo cuando la duración derivada actual sea válida. También deberá auditar resultados de forma inmutable y minimizada. La creación de turnos deberá seleccionar un tipo activo del Profesional y conservar las copias históricas de nombre, duración en minutos y precio, pero no de color ni cantidad de intervalos. La presentación y los selectores corresponden a la interfaz consumidora y deberán respetar las reglas de accesibilidad y distinción de RF-08.
* **Estimación:** 16 horas

### Gestión de Turnos

**Tarea T1.6: Visualizar Turnos del Profesional (HU 2.1)**

* **Descripción:** Crear el endpoint GET /turnos/hoy que retorne todos los turnos asignados al profesional autenticado para la fecha actual, independientemente de si fueron reservados por el Paciente o creados por Secretaría o por el Profesional. La vista deberá mostrar: Horario, Nombre del paciente, Tipo de consulta y Estado actual. Reservado indica que el turno está pendiente de confirmación de asistencia del Paciente y Confirmado indica que la asistencia fue confirmada. Al finalizar el horario previsto de un turno, la interfaz de cierre deberá presentar "Asistió" preseleccionado como opción predeterminada, pero requerirá confirmación expresa del actor antes de registrar el cierre. Si no existen turnos para la fecha solicitada, el sistema deberá informar la situación mediante un mensaje adecuado. Esta tarea cubre el alcance de HU 2.1 incluido en el Sprint 1.
* **Validación adicional:**
  * Comprobar que el profesional pueda registrar "No asistió" únicamente sobre turnos cuyo horario previsto ya finalizó.
  * Comprobar que el registro de "No asistió" quede auditado con actor, fecha y hora.
  * Comprobar que, al registrar "No asistió", el sistema no aplique multa de forma automática y deje la decisión explícita de multa para el Profesional.
* **Estimación:** 24 horas

**Tarea T1.6.1: Crear primera reserva válida por Paciente o Secretaría (HU 2.5.1 / 2.5.2 mínimo)**

* **Descripción:** Implementar una operación compartida para la primera reserva válida entre un Paciente y un Profesional. Un Paciente autenticado podrá reservar de forma autónoma sin relación previa cuando su perfil propio esté completo, el teléfono del destinatario primario esté verificado y se cumplan disponibilidad, privacidad y demás reglas aplicables. Secretaría podrá buscar un Paciente registrado y asistirlo sin relación previa, incluso si el perfil continúa incompleto según RF-02. En ambos caminos se seleccionarán un Profesional, uno de sus Tipos de consulta activos y un horario con suficientes Intervalos de agenda contiguos para su duración vigente; el tipo deberá pertenecer al Profesional y se identificará por su identidad inmutable, sin considerar equivalente otro tipo con el mismo nombre. Se impedirán superposiciones y se conservarán las copias históricas de nombre, duración en minutos y precio, pero no el color ni la cantidad de intervalos. Para el Paciente, el estado inicial seguirá la modalidad de aprobación y la fecha definidas en RF-10. Para Secretaría, la reserva no pasará por Solicitado: antes de D-1 elegirá Reservado o Confirmado y durante D-1 solo podrá crear Confirmado; cuando corresponda, registrará la declaración simple exigida. Solo al almacenar con éxito la primera reserva, la misma transacción creará la relación Profesional–Paciente y la auditoría. Una solicitud fallida o denegada no creará relación.
* **Validación adicional:** En la vía autónoma se exigirán perfil propio completo y teléfono verificado. En la vía asistida, antes del primer turno Secretaría completará nombres, apellidos, tipo de documento controlado, número normalizado y fecha de nacimiento, aunque otros datos puedan seguir incompletos. Ambas vías deberán auditar el establecimiento de visibilidad y la incorporación a la lista permitida. El Profesional no podrá crear esa primera relación ni buscar al Paciente en el registro global.
* **Estimación:** 12 horas

**Tarea T1.7: Crear Turno por Profesional (HU 2.2 / 2.5.3)**

* **Descripción:** Crear el endpoint POST /turnos para permitir que los profesionales registren manualmente nuevos turnos para Pacientes incorporados previamente a su lista permitida por una primera reserva válida, autónoma o asistida, incluso si el perfil continúa incompleto. El backend deberá impedir la búsqueda global y denegar y auditar toda selección fuera de esa relación. Además, validará ausencia de superposición, que el Paciente no posea otro turno en el mismo horario, que el Profesional opere solo sobre su agenda y que el Tipo de consulta seleccionado esté activo, pertenezca a su perfil y disponga de suficientes Intervalos de agenda contiguos para su duración vigente. El turno conservará las copias históricas de nombre, duración en minutos y precio base exacto, pero resolverá el color desde el Tipo de consulta actual y no conservará la cantidad de intervalos. Nacerá Reservado antes de D-1 o Confirmado durante D-1; solo el primer caso usará el flujo de RF-10 y RF-17. Esta tarea cubre parcialmente HU 2.2 y HU 2.5.3.
* **Estimación:** 12 horas

### Interfaces Externas

**Tarea T1.8: Notificación WhatsApp Post-Creación (RF-17 parcial)**

* **Descripción:** Al iniciar esta primera tarea consumidora de WhatsApp, configurar el entorno de pruebas del proveedor detrás de un límite o adaptador y mantener las credenciales fuera del repositorio. Implementar un único envío al teléfono verificado del destinatario primario seleccionado para el perfil de Paciente, sin duplicarlo al Paciente y al representante. El mensaje podrá saludar al Paciente relevante con sus nombres y apellidos completos y contendrá únicamente el nombre del centro, Profesional, fecha, horario, consultorio o ubicación y acción necesaria. No incluirá tipo ni número de documento —incluido DNI—, tipo de consulta, pagos, montos, multas, estado financiero, comprobantes ni datos clínicos o sensibles. Los estados de envío se registrarán en el entorno de pruebas sin guardar credenciales ni contenido secreto. Esta tarea implementa parcialmente RF-17 para turnos que no fueron creados o aprobados durante D-1; la representación permanece diferida, pero el diseño del destinatario no deberá copiar teléfonos entre perfiles.
* **Estimación:** 8 horas

### Calidad y Metodología

**Tarea T1.9: Tests E2E del Flujo Crítico**

* **Descripción:** Automatizar los escenarios funcionales implementados en el Sprint 1. La cobertura mínima incluirá: creación de Persona y perfil de Paciente con identidad documental controlada; normalización y colisión de tipo y número; perfil incompleto sin correo ni teléfono propios; verificación telefónica exitosa y fallida sin registrar el código en auditoría; selección de un único destinatario; alta de Profesional reutilizando una Persona con otro rol; unicidad del correo entre cuentas de acceso; listado de Profesionales; disponibilidad; tipos de consulta; primera reserva autónoma con perfil completo y teléfono verificado, o primera reserva asistida por Secretaría con identidad mínima; copias históricas, auditoría y creación atómica de la relación solo ante éxito; aparición del turno en la agenda; turnos posteriores por el Profesional únicamente dentro de su lista permitida, incluso con perfil incompleto; estados según actor y fecha definidos en RF-10; y notificación única solo al teléfono verificado seleccionado. Los errores incluirán colisión documental sin duplicar o fusionar Personas, correo de cuenta duplicado, conflicto de agenda, turnos simultáneos, tipo de consulta ajeno y denegación auditada del intento del Profesional de operar fuera de alcance o buscar el registro global. Los flujos críticos se probarán según RD-02 y los tests se ejecutarán automáticamente en integración continua. El acceso sin contraseña forma parte del horizonte vigente según el plan tentativo revisado; los escenarios de cambio entre múltiples perfiles y representación se incorporarán cuando se planifique ese alcance.
* **Estimación:** 12 horas

### Metodología

**Tarea T1.10: Puesta a Punto de Definition of Done (DoD)**

* **Descripción:** Crear la plantilla de Pull Request del proyecto, configurar GitHub Actions para la ejecución automática de linting y pruebas, y documentar el flujo de trabajo oficial del repositorio. La documentación deberá incluir: Creación de ramas. Convenciones de commits. Pull Requests. Code Reviews. Proceso de merge a develop. Esta tarea consolida la Definition of Done acordada durante el Sprint 0.
* **Estimación:** 4 horas

---

## Resumen del Sprint

Este Sprint entrega un flujo funcional del sistema Origen sobre el modelo separado de Persona, perfiles, roles y cuentas de acceso. Administrador registra o reutiliza Personas para incorporar Profesionales con cuenta interna propia; los Profesionales se autentican y configuran disponibilidad y tipos de consulta. Un Paciente autenticado, con perfil propio completo y teléfono verificado, puede realizar su primera reserva autónoma; alternativamente, Secretaría puede registrar o reutilizar su Persona, asistirlo y reservar aun cuando el perfil admita datos pendientes. La primera reserva válida almacenada por cualquiera de esas dos vías establece atómicamente y de forma auditada la relación Profesional–Paciente. Desde esa lista permitida, el Profesional consulta su agenda y crea turnos posteriores, incluso mientras el perfil esté incompleto, sin acceso al registro global. Los estados iniciales respetan las reglas específicas por actor y fecha de RF-10; cada turno conserva las copias históricas de su tipo de consulta.
Carga conocida del Sprint 1: 176 h base. El total final queda pendiente de la reestimación de T1.2 por verificación telefónica.

| Integrante | Tareas | Carga base / pendiente |
| --- | --- | --- |
| Santiago Casali | T1.1, T1.3 | 40 h base |
| Lucca Giordana | T1.2, T1.4, T1.6.1 | 36 h base + incremento pendiente por reestimación de T1.2 |
| Said Quioto | T1.5, T1.5.1, T1.6, T1.7 | 76 h base |
| Samuel Olmos | T1.8, T1.9 | 20 h base |
| Equipo completo | T1.10 | 4 h base |
| **Total** | — | **176 h base + total final pendiente de reestimación de T1.2** |

**Alcance diferido:** La aprobación manual completa de HU 2.7, el cambio entre múltiples perfiles, la representación completa de HU 8.3, los cambios de correo y las correcciones documentales reforzadas quedan fuera de este recorte. La primera reserva autónoma y el acceso sin contraseña ya no se consideran diferidos para el horizonte vigente; su desglose y estimación están en el [plan tentativo revisado](sprints/PLAN_TENTATIVO_11_SPRINTS.md).

**Cadena crítica del demo:** identidad y acceso del Paciente, teléfono verificado, alta del Profesional, disponibilidad y tipo de consulta convergen en la operación compartida de primera reserva. Una reserva autónoma válida o una reserva asistida válida crea atómicamente la relación Profesional–Paciente; T1.6 muestra el resultado en la agenda. T1.7 permite al Profesional crear turnos posteriores únicamente para Pacientes ya relacionados bajo RF-05. T1.5.1 debe completarse antes de crear turnos para que cada uno use la duración del tipo de consulta y conserve sus copias históricas.

---

## Pantallas

* Paciente
* Selector de perfiles de Paciente y contexto activo
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
* Gestión de representación, identidad documental y cuentas de acceso de Pacientes
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

<https://github.com/Team-Origen>
