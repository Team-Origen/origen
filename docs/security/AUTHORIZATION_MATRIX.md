# Matriz de autorización de Origen

> **Estado:** Aprobada — validada por el equipo el 2026-08-24  
> **Versión del documento:** `0.4`  
> **Alcance:** bootstrap del primer Administrador, operaciones necesarias para Sprint 1 y consulta de auditoría exigida por RNF-02.

Este es el único artefacto canónico para declarar permisos de Origen. La matriz es incremental: esta versión no autoriza operaciones de sprints posteriores. Toda operación o combinación rol–operación que no aparezca declarada se **deniega por defecto**.

## Reglas de lectura

| Valor | Semántica |
|---|---|
| **Permitir** | El rol autenticado y con cuenta `Activa` puede ejecutar la operación. No implica permisos sobre otras operaciones ni jerarquía sobre otros roles. |
| **Denegar** | El backend debe rechazar la operación para ese rol, aunque la interfaz muestre un control o el cliente construya la solicitud manualmente. |
| **Condicional/alcance — `<ID>`** | La operación solo se permite cuando se cumplen **todas** las condiciones del identificador indicado. Fuera de ese alcance se deniega. |

El backend es la autoridad de autorización. Ocultar controles en el frontend no constituye seguridad. La jerarquía nominal de RF-04 no concede permisos implícitos y, en particular, el rol Administrador no puede realizar una operación salvo que esta matriz lo declare.

Las cuentas internas usan `Pendiente de activación` y `Activa`. Las cuentas de Paciente creadas por Google OAuth usan `Pendiente de completar` y `Activa`. Estos estados pertenecen a flujos diferentes y no son intercambiables.

## Matriz vigente

La columna «Canal o control no basado en rol» separa operaciones de despliegue, sistema, invitación o demostración de posesión que no nacen de una sesión autenticada. En `B-02`, las columnas de rol identifican el rol objetivo de la cuenta interna pendiente; no representan una sesión ya autenticada. En `S1-05`, todos los cruces de rol permanecen en **Denegar** porque la autorización no proviene de un rol: el canal público condicionado demuestra posesión del número para una única cuenta y operación, pero no concede permiso general al público ni a una sesión autenticada.

| ID | Operación | Administrador | Profesional | Secretaría | Paciente | Canal o control no basado en rol | Fuente exacta |
|---|---|---|---|---|---|---|---|
| B-01 | Ejecutar el bootstrap del primer Administrador | Denegar | Denegar | Denegar | Denegar | Condicional/alcance — `DEP-01` | RF-01, RF-04, RF-23; T0.12; `SPRINT_00.md`, «Bootstrap del primer Administrador» |
| B-02 | Completar la activación de la propia cuenta interna mediante invitación: consumir invitación, definir contraseña y enrolar TOTP | Condicional/alcance — `INV-01` | Condicional/alcance — `INV-01` | Condicional/alcance — `INV-01` | Denegar | Invitación de un solo uso vinculada a la cuenta objetivo; no requiere una sesión interna ya activa | RF-01, RF-04, RF-23; HU 7; T1.1 |
| B-03 | Reemitir una invitación para una cuenta interna `Pendiente de activación` | Condicional/alcance — `REI-02` | Denegar | Denegar | Denegar | Condicional/alcance — `REI-01` para el bootstrap | `SPRINT_00.md`, «Registro de bloqueos y decisiones» y «Bootstrap del primer Administrador» |
| A-01 | Agregar automáticamente un evento al log de auditoría | Denegar | Denegar | Denegar | Denegar | Condicional/alcance — `SYS-01` | RF-23; T0.4; `SPRINT_00.md`, «Checklist de esquema mínimo de auditoría» |
| A-02 | Consultar el log técnico de auditoría en modo de solo lectura | Condicional/alcance — `AUD-01` | Condicional/alcance — `AUD-02` | Condicional/alcance — `AUD-03` | Denegar | No aplica | RNF-02; RF-23 |
| A-03 | Editar o borrar eventos del log de auditoría | Denegar | Denegar | Denegar | Denegar | Sin excepción: aplicación y PostgreSQL deben impedir `UPDATE` y `DELETE` | RNF-02; RF-23; `SPRINT_00.md`, decisión de auditoría append-only |
| S1-01 | Iniciar una sesión interna | Condicional/alcance — `AUTH-01` | Condicional/alcance — `AUTH-01` | Condicional/alcance — `AUTH-01` | Denegar | No aplica | RF-01; HU 7; RNF-09; T1.1 |
| S1-02 | Crear una cuenta de Profesional y emitir su invitación inicial | Permitir | Denegar | Denegar | Denegar | La emisión es un efecto del backend; no concede permiso separado para reemitir | RF-01, RF-02, RF-04, RF-23; HU 4.2; T1.3 |
| S1-03 | Crear una cuenta de Secretaría y emitir su invitación inicial | Permitir | Denegar | Denegar | Denegar | La emisión es un efecto del backend; no concede permiso separado para reemitir | RF-01, RF-04, RF-23; T1.1; `PLAN_DE_SPRINTS.md`, Sprint 1 |
| S1-04 | Registrar un Paciente con teléfono inicialmente no verificado y solicitar el envío o reenvío del código | Denegar | Denegar | Condicional/alcance — `TEL-01` | Denegar | El envío o reenvío es un efecto del backend de la operación autorizada; no verifica el teléfono | RF-02, RF-06, RF-23; HU 1.1; T1.2 |
| S1-05 | Validar el teléfono inicial del Paciente mediante el código enviado | Denegar | Denegar | Denegar | Denegar | Condicional/alcance — `TEL-02`: canal público vinculado a un desafío opaco y basado en posesión del número, no en rol | RF-02, RF-23; HU 1.1; T1.2; `SPRINT_00.md`, «Registro de bloqueos y decisiones» |

### Condiciones y alcances

| ID | Condición o alcance obligatorio |
|---|---|
| `DEP-01` | Operación administrativa de despliegue, fuera de las APIs de la aplicación y ejecutada únicamente por el operador asignado en `SPRINT_00.md` mediante el comando aprobado. Solo puede crear el primer registro cuando no existe ningún Administrador, sin credenciales predeterminadas; crea la cuenta en `Pendiente de activación`, emite la invitación y audita resultado y fallos sin secretos. |
| `INV-01` | Política aprobada: la invitación pertenece a la misma cuenta interna `Pendiente de activación`, vence a las 24 horas desde su emisión según el tiempo del servidor, no fue consumida ni invalidada y solo permite definir la contraseña y enrolar TOTP de esa cuenta. La transición a `Activa` ocurre únicamente después de completar ambos pasos. Una nueva emisión para la misma cuenta pendiente invalida inmediatamente todos los tokens anteriores, aunque todavía no hayan vencido, y no crea una cuenta duplicada. |
| `REI-01` | Excepción de bootstrap: solo Samuel, como operador de despliegue asignado, puede reemitir mediante el comando administrativo aprobado para la misma cuenta del primer Administrador `Pendiente de activación`, y únicamente mientras no exista ningún Administrador `Activo`. No es una API ni un permiso de sesión. La reemisión no crea otra cuenta, invalida inmediatamente cualquier token anterior, inicia una nueva vigencia de 24 horas según el tiempo del servidor y audita actor, cuenta objetivo, resultado y fecha/hora sin registrar el token en claro. Si ya existe un Administrador `Activo`, Samuel y el canal de despliegue quedan denegados para esta operación. |
| `REI-02` | Flujo normal: solo un Administrador autenticado con cuenta `Activa` puede reemitir desde el flujo administrativo para la misma cuenta de Profesional o Secretaría `Pendiente de activación`. No puede usar este alcance para una cuenta de Administrador. La reemisión no crea otra cuenta, invalida inmediatamente cualquier token anterior, inicia una nueva vigencia de 24 horas según el tiempo del servidor y audita actor, cuenta objetivo, resultado y fecha/hora sin registrar el token en claro. Profesional, Secretaría, Paciente y la propia cuenta pendiente no pueden auto-reemitir ni invocar un canal alternativo. |
| `SYS-01` | Solo el backend agrega eventos automáticos mediante el camino interno de auditoría. No existe API ni contexto público para insertar, editar o borrar eventos. La base debe impedir `UPDATE` y `DELETE`; una corrección genera un evento nuevo. |
| `AUD-01` | Acceso global de solo lectura para Administrador. Cada consulta registra actor, fecha/hora del servidor, alcance o filtros y resultado. No permite editar ni borrar. |
| `AUD-02` | Solo eventos vinculados a la propia agenda del Profesional, sus Pacientes relacionados y sus propias operaciones. Cada consulta también queda auditada. No permite acceso global, editar ni borrar. |
| `AUD-03` | Solo eventos operativos necesarios para la gestión de Secretaría. Excluye eventos internos sensibles de seguridad. Cada consulta también queda auditada. No permite editar ni borrar. |
| `AUTH-01` | Cuenta interna `Activa`; contraseña válida en cada nueva sesión; TOTP válido o recordatorio vigente en dispositivo confiable por un máximo de 30 días. Se exige nuevamente TOTP ante vencimiento, dispositivo nuevo, cambios de correo, contraseña o 2FA, o actividad sospechosa. La sesión dura como máximo 12 horas y se bloquea tras 30 minutos de inactividad. |
| `TEL-01` | Solo Secretaría autenticada con cuenta `Activa`, dentro de su operación autorizada sobre la cuenta de Paciente y su número asociados, puede iniciar el envío o reenvío del código. El backend debe aplicar los límites de frecuencia y reintentos configurados. Este alcance no permite conocer el código, marcar manualmente el teléfono como verificado, consumir el desafío en nombre del Paciente ni eludir `TEL-02`. |
| `TEL-02` | Canal público condicionado: el Paciente presenta el código en una pantalla vinculada a un desafío opaco. Código y desafío deben ser válidos, vigentes, no consumidos, estar sujetos a límites de frecuencia y reintentos, y corresponder a la misma cuenta y al mismo número. Solo el backend puede consumir el desafío y establecer el teléfono como verificado tras comprobar todas las condiciones. Un fallo no modifica el estado. No existe operación alternativa para establecer `verified` directamente: ningún rol, canal interno ni solicitud directa al backend puede omitir el desafío o el código. Éxitos y fallos se auditan sin código, token del desafío, teléfono ni otros datos sensibles. |

## Pruebas mínimas de autorización

Estas pruebas son obligatorias en backend para las operaciones críticas. Deben probar el permiso y su frontera; una prueba de interfaz no las reemplaza.

| Operación | Evidencia automatizada mínima esperada |
|---|---|
| `B-01` Bootstrap | Crea una única cuenta `Pendiente de activación` cuando no existe Administrador; rechaza la ejecución si ya existe alguno y no produce efectos secundarios; no está expuesto por API ni por sesión de ningún rol; registra eventos diferenciados y verifica que no contienen token, enlace, contraseña, secreto/código TOTP ni credenciales. |
| `B-02` Activación por invitación | Acepta una invitación válida solo para su cuenta objetivo antes de cumplirse 24 horas desde la emisión según el tiempo del servidor; acepta a las 23 h 59 min 59 s, rechaza al cumplirse exactamente 24 horas y después, e ignora el reloj informado por el cliente. Rechaza token inválido, consumido, invalidado o asociado a otra cuenta; tras una reemisión, rechaza inmediatamente todos los tokens anteriores y acepta el nuevo dentro de su propia vigencia sin crear otra cuenta. Impide pasar a `Activa` si falta contraseña o TOTP; audita consumo, configuración, enrolamiento, activación y fallos sin secretos. |
| `B-03` Reemisión | **Bootstrap positivo:** Samuel puede reemitir mediante el comando administrativo aprobado para la misma cuenta del primer Administrador `Pendiente de activación` cuando no existe ningún Administrador `Activo`; se invalida inmediatamente todo token anterior, el nuevo vence a las 24 horas según el tiempo del servidor, no se crea otra cuenta y la auditoría no contiene el token en claro. **Bootstrap negativo:** se rechaza a cualquier otra persona o canal, a Samuel cuando ya existe un Administrador `Activo`, y cualquier intento sobre una cuenta distinta. **Flujo normal positivo:** un Administrador `Activo` puede reemitir desde el flujo administrativo para la misma cuenta de Profesional o Secretaría `Pendiente de activación`, con idénticas garantías de invalidación, nueva vigencia, no duplicación y auditoría sanitizada. **Flujo normal negativo:** se rechaza al Administrador `Pendiente de activación`, a Profesional, Secretaría, Paciente, a la propia cuenta pendiente y al Administrador `Activo` si el objetivo es una cuenta de Administrador o no está `Pendiente de activación`; una solicitud directa al backend o al canal de despliegue no elude estos límites. |
| `A-01` Escritura de auditoría | Verifica que la operación de negocio genere el evento desde backend y que ningún rol pueda insertar eventos arbitrarios por una interfaz pública. |
| `A-02` Consulta de auditoría | Administrador puede consultar globalmente en solo lectura; Profesional no obtiene eventos fuera de `AUD-02`; Secretaría no obtiene eventos fuera de `AUD-03` ni eventos internos sensibles; Paciente recibe denegación; cada consulta genera su propio evento de auditoría. |
| `A-03` Inmutabilidad | `UPDATE` y `DELETE` fallan desde la aplicación y directamente en PostgreSQL para las credenciales usadas por la aplicación; una corrección conserva el original y agrega un evento nuevo. |
| `S1-01` Sesión interna | Permite acceso a cada rol interno con cuenta `Activa` y factores válidos; deniega `Pendiente de activación`, contraseña o TOTP inválidos y Paciente; verifica límite absoluto, inactividad, recordatorio de TOTP y disparadores de nueva solicitud de segundo factor. |
| `S1-02` Alta de Profesional | Administrador puede crear la cuenta en `Pendiente de activación`; Profesional, Secretaría y Paciente reciben denegación; una solicitud directa al backend no elude el control; la invitación inicial y el alta quedan auditadas. |
| `S1-03` Alta de Secretaría | Administrador puede crear la cuenta en `Pendiente de activación`; Profesional, Secretaría y Paciente reciben denegación; una solicitud directa al backend no elude el control; la invitación inicial y el alta quedan auditadas. |
| `S1-04` Alta de Paciente y envío | Secretaría `Activa` puede registrar y solicitar el envío o reenvío para la cuenta y el número asociados; Administrador, Profesional y Paciente reciben denegación. El teléfono permanece no verificado después del registro, envío o reenvío; se rechazan solicitudes fuera de la cuenta/número autorizados y al superar los límites configurados. Ningún envío o reenvío permite a Secretaría obtener el código, consumir el desafío ni establecer `verified`; resultados y fallos quedan auditados sin datos sensibles. |
| `S1-05` Verificación inicial de teléfono | **Positiva:** un desafío opaco y un código válidos, vigentes, no consumidos y vinculados a la misma cuenta y número permiten consumir el desafío y establecer el teléfono como verificado una sola vez. **Negativas:** se rechazan código o desafío inválidos, vencidos o consumidos; cualquier diferencia de cuenta o número; y cada intento o reenvío que exceda los límites configurados, verificando también la frontera y el reinicio permitido por la política. Administrador, Profesional, Secretaría, Paciente autenticado y cualquier canal interno continúan denegados para establecer `verified` directamente; una solicitud directa al backend, una mutación manual o la manipulación del cliente no pueden omitir código ni desafío. Todo rechazo conserva el teléfono no verificado. Éxitos y fallos generan auditoría sin código, token del desafío, teléfono ni otros datos sensibles. |

## Trazabilidad de alcance

| Bloque | Requisitos, historias y tareas |
|---|---|
| Gobierno de la matriz | RNF-08; T0.11; `PLAN_DE_SPRINTS.md`, DoD y Sprint 0 |
| Bootstrap y activación inicial | RF-01, RF-04, RF-23; HU 7; T0.12; T1.1; `SPRINT_00.md`, decisiones de bootstrap y auditoría |
| Sesión interna | RF-01; HU 7; RNF-09; T1.1 |
| Alta de Profesional y Secretaría | RF-01, RF-02, RF-04, RF-23; HU 4.2; T1.1; T1.3 |
| Alta de Paciente y teléfono inicial | RF-02, RF-06, RF-23; HU 1.1; T1.2 |
| Consulta e inmutabilidad de auditoría | RNF-02; RF-23; `SPRINT_00.md`, decisiones de auditoría append-only |

Quedan fuera de esta versión las operaciones de agenda, turnos, Google OAuth/Magic Link, WhatsApp, lista de espera, pagos, comprobantes, reportes y gestión posterior de datos o credenciales. Su ausencia no concede acceso: permanecen denegadas por defecto hasta incorporarse con fuente, alcance y pruebas antes del sprint que las implemente.

## Estado de decisiones

No quedan gaps de autorización abiertos en esta versión. `S1-05` queda resuelta como un canal público condicionado por demostración de posesión del número, sin permiso derivado de rol y bajo default deny fuera de `TEL-02`. El equipo aprobó y validó integralmente la matriz el 2026-08-24. Esta aprobación es documental: no implica que los permisos estén implementados ni que las pruebas aquí definidas hayan sido ejecutadas.

## Cambio, versionado y revisión

1. Modificar únicamente este archivo para cambiar permisos; otros documentos deben enlazarlo y conservar solo decisiones o evidencia, no copiar la tabla.
2. Cada cambio debe identificar operación, cruces de rol afectados, condición/alcance, requisito o historia exactos y pruebas de autorización asociadas.
3. Una operación nueva permanece denegada hasta que su fila, fuente y pruebas sean revisadas. Un gap no puede resolverse por inferencia de implementación.
4. Toda modificación requiere revisión de seguridad por una persona distinta de quien la redactó y validación explícita del equipo. El estado no cambia a aprobado sin esa evidencia humana.
5. Antes de implementar cada sprint posterior, ampliar esta misma matriz solo con sus operaciones sensibles y actualizar las pruebas en el mismo cambio revisable.
6. Incrementar la versión del documento y registrar el cambio. Los borradores usan sufijo `-draft`; una versión sin ese sufijo requiere aprobación explícita registrada.

### Historial

| Versión | Fecha | Estado | Cambio |
|---|---|---|---|
| `0.4` | 2026-08-24 | Aprobada — validada por el equipo | Aprobación humana explícita e integral del contenido de `0.4-draft`, sin ampliar permisos ni modificar el default deny, las condiciones, los alcances o las pruebas mínimas. La aprobación documental no acredita implementación ni ejecución de pruebas. |
| `0.4-draft` | 2026-08-24 | Draft — pending team validation | Se resolvió `S1-05` como canal público condicionado por desafío opaco y demostración de posesión del número, sin permiso basado en rol. Se delimitó el envío o reenvío autorizado de Secretaría, se prohibió establecer `verified` por fuera del flujo y se agregaron pruebas positivas, negativas, de límites y de auditoría sanitizada. No quedan gaps de autorización abiertos; continúa pendiente la aprobación integral humana. |
| `0.3-draft` | 2026-08-23 | Draft — pending team validation | Se resolvió `DG-02`: `B-03` distingue la excepción de bootstrap, limitada a Samuel mediante el comando aprobado mientras no exista un Administrador `Activo`, del flujo normal, limitado a un Administrador `Activo` para cuentas pendientes de Profesional o Secretaría. Se agregaron pruebas positivas y negativas; permanecía pendiente definir el canal de validación telefónica inicial. |
| `0.2-draft` | 2026-08-23 | Draft — pending team validation | Reconciliación de la política aprobada: vigencia de 24 horas según tiempo del servidor, reemisión sin duplicado e invalidación inmediata de tokens anteriores; se cerró el gap de vigencia y se definieron las pruebas temporales de `B-02`. Permanecían pendientes la autorización de reemisión y el canal de validación telefónica inicial. |
| `0.1-draft` | 2026-08-23 | Draft — pending team validation | Ubicación canónica y alcance inicial de bootstrap + Sprint 1; contenido todavía no aprobado. |
