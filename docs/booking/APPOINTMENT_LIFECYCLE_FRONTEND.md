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
`Origen.Accounts.get_own_navigation_identity/1`, sin cambiar autorización. La pantalla
de Pacientes conserva sus controles de búsqueda, registro y reserva asistida sin
reemplazar el recorrido existente. La pantalla de Agenda identifica cada turno en
formularios e historial con el `patient_profile_id` que ya forma parte de la
proyección pública autorizada de historial; no realiza búsquedas adicionales de
perfiles ajenos ni expone datos clínicos o credenciales. La agrupación y el botón
«Hoy» convierten los instantes UTC a la zona horaria de la organización antes de
comparar fechas. El parámetro de fecha de Agenda no se agrega ni se modifica.

La prueba
`test/origen_web/live/secretary_agenda_live_test.exs` usa PostgreSQL real y
fixtures persistentes para verificar autorización, los seis estados, cancelación
en múltiples agendas, motivo en blanco sin mutación, asistencia/ausencia,
identificadores forjados, identificación segura del paciente, agrupación por
zona horaria y visibilidad del origen Secretaría en la historia pública del
Paciente. La prueba `test/origen_web/live/secretary_patient_live_test.exs`
verifica la entrada funcional a Agenda sin perder los controles existentes.
La prueba de controlador verifica que el inicio autenticado de Paciente enlace
a `/paciente/turnos`, no a un aviso de sección pendiente. Es evidencia de
LiveView y dominio real, no una prueba de navegador, despliegue o integración
final de #285; la verificación independiente queda a cargo de T4.

## Evidencia de integración T4 y limitaciones conocidas

La regresión focal autorizada para esta integración observó `37 passed` en la
base aislada UTF-8, incluyendo Agenda de Secretaría, Pacientes de Secretaría,
navegación de Paciente y `PageController`. La ejecución no demuestra por sí
sola una prueba de navegador ni una aprobación independiente de privacidad.

Se conservan explícitamente los dos intentos de suite completa ejecutados por
el padre y no se presentan como suite verde ni como prueba de una línea base
completamente probada:

- Job-4: `981/986 passed`, `32 skip`, `8 exclude`; cuatro fallos de bootstrap
  por configuración de base ausente cuando sólo se usó URL y un fallo de
  migración Unicode SQLASCII. Después se reparó la preparación a UTF-8 con
  claves de configuración explícitas; no se modificó `config/test.exs`.
- Job-5: `885/986 passed`, `101 failures`; se observó una caída de
  `ExpiryWorker` (`:sweep` después de 60 s) por pérdida de ownership del
  sandbox, seguida por errores de Repo no iniciado. T5 corrigió ese fallo de
  runtime de forma acotada: sólo se difiere y registra el `OwnershipError`
  conocido, se conserva la programación periódica y los demás fallos de base
  siguen propagándose. Una prueba con ownership explícito observó una solicitud
  vencida persistida como `expired` después de enviar `:sweep` al proceso; esto
  prueba el barrido, no el disparo autónomo del temporizador. No se detuvo ni
  deshabilitó el worker para hacer pasar la suite.
- Verificación independiente: preparación fallida antes de las pruebas,
  **cero tests y cero probes ejecutados**. El verificador buscó `initdb` y
  `pg_ctl` en `PATH`, aunque el servidor aislado ya estaba preparado. Los
  ejecutables existen en `/usr/lib/postgresql/18/bin/`; se comprobó su
  disponibilidad sin relanzar el intento. No hubo copia aislada ni una base
  nueva del verificador, ni aprobación funcional independiente.

T4 permanece pendiente de la suite global posterior a T5, de la prueba
independiente y de la evidencia visual: la autorización S3 permite que el padre
repita esa suite, pero este worker sólo ejecutó la regresión focal autorizada.
La prueba independiente previa y la comparación contra `5284df1` se conservan
como evidencia histórica; no se declaran reemplazadas por la prueba focal. No
se ejecutaron comprobaciones visuales en navegador ni integración en nube. La
aprobación de #378 y el cierre de #285 no se declaran.

### Segundo intento independiente autorizado

El usuario autorizó «Autorizo un nuevo intento.». El servidor PostgreSQL aislado
respondió correctamente y `template1` tenía UTF-8, pero la preparación volvió a
fallar: el verificador usó `README.md` en vez del archivo seguido `readme.md`
al crear el archivo de baseline y el `HOME` aislado dejó inutilizable el shim
de `mix` de asdf. **Cero tests y cero probes de aplicación ejecutados**; no se
creó ni migró una base de prueba nueva. No se repitió el intento ni se modificó
la aplicación para sortearlo.

Se observó igualdad del código de `ExpiryWorker` entre `5284df1` y el frontend
actual (SHA-256 `8c6c28c14cc541973b446041e84871cbf1e19b021a7769e3a23d57d5b6cb421c`).
Esto no reemplaza el diagnóstico de comportamiento pendiente. Se identificaron
los binarios reales de Elixir y Erlang, evitando depender de shims bajo un
`HOME` aislado; cualquier intento posterior necesita autorización explícita.
T4 sigue bloqueada y los resultados fallidos anteriores se conservan.

### Tercer intento independiente: pruebas ejecutadas

Autorización del usuario: «Autorizo otro intento independiente con el archivo
correcto.». La preparación con `readme.md`, PATH real de Elixir/Erlang y archivos
de runtime de Hex funcionó. En una copia aislada y dos bases UTF-8 nuevas
(`origen_test378verify3` y `origen_test378verify3base`), el verificador ejecutó
una sola vez las once suites focalizadas de interfaz y dominio:
**107/110 passed, tres fallos, exit 2, seed 232781**.

- `professional_agenda_lifecycle_live_test.exs:63` y `:92`: no aparecieron los
  controles `cancel-appointment-ID`; los turnos estaban en historial pero no
  en la agenda diaria. Falta diagnosticar si la causa está en las fechas de
  fixtures o en el comportamiento de la pantalla; no se afirma una causa.
- `patient_appointments_live_test.exs:66`: falló la búsqueda del identificador
  ajeno como substring del HTML completo. La aserción es frágil y no demuestra
  por sí misma una filtración; debe comprobarse la identidad exacta de la
  tarjeta de turno mediante el DOM y la consulta pública autorizada.

El diagnóstico de baseline `5284df1` se ejecutó: con sandbox manual, enviar
`:sweep` al worker monitorizado produjo `DOWN` con `DBConnection.OwnershipError`
en `expiry_worker.ex:23`. Esa condición ya existe antes del frontend. Esto no
certifica que los 101 fallos anteriores tengan una única causa ni convierte la
suite completa en satisfactoria. El verificador no informó el exit code exacto
del comando baseline; no se inventa ese dato.

No hubo correcciones ni reintentos automáticos. La verificación usa fixtures
sintéticos y PostgreSQL real, no navegador ni nube. T4 permanece bloqueada por
los tres fallos y la prueba integral incompleta; una corrección acotada requiere
una decisión explícita. No se declara aceptación de #378 ni cierre de #285.

### Corrección acotada y reverificación de los tres bloqueos

El usuario autorizó «Autorizo la corrección». Se ejecutó una sola tanda de
correcciones, sin cambios de producción:

- Los dos casos profesionales usan fixtures UTC deterministas para el
  `2099-01-15` y abren explícitamente `?date=2099-01-15`. Los fixtures anteriores
  sumaban minutos a la hora actual y podían caer en el día siguiente, fuera
  del día UTC consultado por la agenda.
- La prueba de privacidad del Paciente usa IDs exactos de tarjetas DOM propias
  y ajenas y conserva la comprobación de identidad mediante
  `Booking.list_appointment_history/1`; no se eliminó ni debilitó esa regla.

Se conserva el RED original independiente de `107/110`. La reproducción local
previa a la corrección observó `109/110` (exit 2): persistía el falso positivo
numérico de privacidad, mientras los dos fallos de fecha no reaparecieron
tras cambiar el día de ejecución. No se afirma haber reproducido localmente
esos dos fallos por segunda vez. Tras la corrección, el comando focalizado de
once archivos con `--seed 232781` obtuvo **110 passed, exit 0**. Formato y
whitespace también pasaron; un error de formato se corrigió antes del resultado
final.

La reverificación independiente usó otra copia y base aisladas
(`origen_test378recheck1`) y ejecutó una sola vez los tres casos originales:

```sh
mix test \
  test/origen_web/live/professional_agenda_lifecycle_live_test.exs:63 \
  test/origen_web/live/professional_agenda_lifecycle_live_test.exs:97 \
  test/origen_web/live/patient_appointments_live_test.exs:30 \
  --seed 232781
```

Resultado: **3 passed, 8 excluded, exit 0**. Los tres bloqueos quedaron
satisfechos: motivo obligatorio/rechazo sin mutación, cancelación de solicitudes
y confirmados, e identidad privada del historial del Paciente. No se tocaron
backend, runtime ni autorización ni se deshabilitó el worker.

Esto verifica la corrección acotada, no una nueva suite completa. Los fallos
integrales anteriores, el problema baseline del sandbox y la ausencia de
validación visual en navegador/nube se conservan como limitaciones. No se
infiere aprobación de #378 ni cierre de #285.

### Corrección del runtime y suite global autorizadas — estado vigente

Autorización: «Te autorizo a corregir el runtime y repetir la suite global».
Se reprodujo el fallo de `ExpiryWorker` sin ownership del sandbox (RED, exit 2).
La corrección sólo rescata y registra `DBConnection.OwnershipError`; conserva
la programación del próximo barrido y no rescata otros errores de base. No se
cambiaron configuración, autorizaciones ni reglas del ciclo operativo.

- Regresión focal del worker y del backend: **13 passed, exit 0, seed 0**.
- Suite global sobre el código corregido real: **990 passed, 32 skipped,
  8 excluded, exit 0, seed 232781**, en 56,1 segundos. Se ejecutó con PostgreSQL
  UTF-8 aislado en `55439`, `MIX_TEST_PARTITION=378runtimeglobal1` y sin
  `ORIGEN_DATABASE_URL`. Las ocho exclusiones son `postgres_security` y no se
  presentan como ejecutadas.
- Persisten warnings de OTP 28.0/regex, helper legado deprecado y redefinición
  de una migración; se registró además el warning esperado del barrido diferido
  por falta de ownership. No hubo caída de Repo ni tests fallidos en esta suite.

La verificación independiente del runtime **no quedó validada**. Su copia
contenía el worker anterior: ejecutó 13 pruebas con exit 2 (primer fallo de
ownership y doce fallos por Repo no iniciado). Son pruebas ejecutadas sobre un
payload incorrecto, no evidencia contra la corrección actual. No se repitió el
intento ni se cuentan esos resultados como aprobación.

El diagnóstico de preparación comprobó que Git dentro del scratch heredaba
la raíz del repositorio padre. Se preservó esa copia fallida y se preparó un
payload nuevo mediante archivo de HEAD y copias explícitas del código actual,
con igualdad de bytes comprobada. Falta un nuevo intento independiente,
expresamente solicitado, para probar inicialización sin ownership, recuperación
mediante temporizador y propagación de errores inesperados. La suite global
exitosa no reemplaza esa prueba requerida.

Los apartados anteriores conservan la secuencia histórica, incluidos todos los
fallos y sus correcciones; este apartado registra el estado vigente. Se usaron
fixtures sintéticos con PostgreSQL real: no se declara verificación visual en
navegador, integración en nube, aprobación de #378 ni cierre de #285.
