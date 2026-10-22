# Contrato #301: perfil profesional apto para reserva

**Estado: aprobado por Santiago Casali (`SantiCasali`) en esta conversación.** La aprobación cubre el documento y la propiedad de los ajustes por cuenta; no incluye la propuesta posterior de bloquear nuevas reservas desde Secretaría por perfil incompleto.
Este documento prepara [#302 (Backend)](https://github.com/Team-Origen/origen/issues/302) y [#303 (Interfaz)](https://github.com/Team-Origen/origen/issues/303). No implementa ni acredita el cierre de [#278](https://github.com/Team-Origen/origen/issues/278) o [#304 (Integración)](https://github.com/Team-Origen/origen/issues/304).

## Alcance y fuentes

- Contrato: [#301](https://github.com/Team-Origen/origen/issues/301), Sprint 3, padre #278.
- OpenSpec: cambio `health-center-beta-core`, ruta `openspec/changes/health-center-beta-core/`, alcance Sprint 3 / parent #278 / contract.
- [Propuesta beta](../../../openspec/changes/health-center-beta-core/proposal.md) y [diseño](../../../openspec/changes/health-center-beta-core/design.md).
- [Cuentas internas y ajustes profesionales](../../../openspec/changes/health-center-beta-core/specs/staff-accounts-and-professional-settings/spec.md), secciones aplicables al perfil y preparación del Profesional.
- [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md): sin catálogo de matrículas ni verificación de credenciales.
- [Guía de trabajo beta](../GUIA_TRABAJO_BETA.md): distinguir código, pruebas leídas, pruebas ejecutadas y aprobación explícita.
- #278 y #301 no tenían comentarios al realizar el relevamiento. Las issues históricas cerradas no se usan como prueba de cumplimiento beta.

## Reglas y datos del perfil

| Dato | Regla beta | Efecto sobre el listado reservable |
| --- | --- | --- |
| Nombre | Obligatorio | Su ausencia mantiene el perfil incompleto. |
| Apellido | Obligatorio | Su ausencia mantiene el perfil incompleto. |
| Especialidad | Obligatoria | Su ausencia mantiene el perfil incompleto. |
| Tipo de matrícula | Obligatorio, texto libre | No se selecciona de un catálogo ni se verifica. |
| Número de matrícula | Obligatorio, texto libre | No se exige validación externa ni conversión a número. |
| Foto | Opcional | Su ausencia nunca impide acceso, preparación ni reserva. |

La completitud requiere los cinco datos obligatorios. No se reemplazan datos faltantes con el email de la cuenta, una especialidad fija u otros valores ficticios. Un campo ausente o vacío no satisface la obligatoriedad. La validación de presencia no equivale a verificar credenciales.

**Decisión posterior para #303, aprobada por Santiago:** «apruebo tu recomendacion de guardar cambios. . crera las pantalla. sera en un entrada moqueada no??». Se permite guardar avances parciales; los cinco datos son obligatorios para completar el perfil, no para guardar. El estado completo/incompleto refleja los últimos datos guardados, no el borrador sin guardar. En la preparación frontend, el guardado es simulado y no acredita persistencia ni integración de #302/#304. Ver [alcance y evidencia de la pantalla #303](../frontend/303-perfil-profesional.md).

No se introducen en este contrato longitudes máximas nuevas, unicidad de matrículas, catálogos de especialidades o mensajes literales de error no definidos por la beta. Los detalles de validación y presentación que requieran decisiones adicionales deberán registrarse antes de implementar la operación afectada.

## Estado y visibilidad

| Cuenta / perfil | Preparación de ajustes propios | Aparece en listado reservable |
| --- | --- | --- |
| Profesional activo, sin perfil o incompleto | Permitida | No |
| Profesional activo, perfil completo, sin foto | Permitida | Sí |
| Profesional activo, perfil completo, con foto | Permitida | Sí |
| Cuenta profesional no activa | No habilitada por este contrato; respetar ciclo de cuenta y sesión vigente | No |
| Cuenta de otro rol | Sin permisos profesionales por este contrato | No |

Para este slice, la elegibilidad del listado reservable consultado por el Paciente es **cuenta profesional activa y perfil completo**. Este filtro no se extiende al listado administrativo de cuentas ni impone un bloqueo adicional a nuevas reservas desde Secretaría por perfil incompleto; esa propuesta no fue aprobada. No se agrega como condición de listado tener foto, un tipo de consulta activo o slots disponibles. Aparecer en el listado no garantiza que exista un turno reservable en cualquier fecha: la consulta de horarios sigue aplicando catálogo, duración, disponibilidad y restricciones temporales.

Perder un dato obligatorio debe reflejarse en el siguiente listado consultado, sin borrar catálogo, horarios ni turnos existentes. No se autoriza modificar el ciclo de cuentas ni de turnos.

**Decisión posterior para #302:** Santiago respondió «si» a «¿Aprobás esa corrección exclusiva del Paciente?», referida a revalidar cuenta activa y perfil completo en la reserva autónoma y rechazar IDs fuera del listado en el calendario de Paciente. Esta protección no se extiende a las reservas asistidas de Secretaría ni impide preparar o consultar la agenda con perfil incompleto. Ver [implementación y evidencia de #302](../backend/302-perfil-profesional.md).

## Propiedad y permisos

### Decisión acordada

Santiago seleccionó **«Conservar propiedad por cuenta (recomendado)»** durante esta sesión:

- El nuevo perfil se asocia 1:1 con la cuenta interna del Profesional.
- Catálogo, intervalo y disponibilidad conservan su propietario por cuenta (`owner_account_id`); no se migra su propiedad al perfil como parte de #278.
- La inexistencia o incompletitud del perfil no bloquea la preparación de los ajustes de un Profesional activo.
- Se conserva la identidad de cuenta usada por las integraciones actuales; no se obliga a consumidores a sustituirla por un identificador nuevo de perfil.

La decisión de propiedad se aprobó primero de forma independiente; posteriormente Santiago aprobó el contrato completo, excluyendo la regla adicional propuesta para nuevas reservas desde Secretaría.

### Matriz del slice

| Actor / operación | Perfil y ajustes propios | Perfil y ajustes privados ajenos |
| --- | --- | --- |
| Profesional activo | Leer y editar, incluso con perfil incompleto | Denegado |
| Secretaría | Denegado: lectura y escritura | Denegado |
| Paciente | Sin acceso a operaciones privadas de ajustes | Sólo la proyección pública del listado reservable, no el registro privado |
| Otros roles o sesión inválida | No se conceden permisos en este slice; default-deny | Denegado |

La identidad propietaria se obtiene de la sesión autenticada; un identificador recibido del cliente no autoriza por sí solo. Los rechazos no deben alterar perfil, catálogo o disponibilidad ni devolver sus valores privados. La ruta, los eventos LiveView y las operaciones de dominio deben sostener la misma frontera de permisos.

La proyección para reservas debe usar identidad estable de cuenta y nombre/especialidad declarados, sustituyendo los valores ficticios actuales. Este contrato no autoriza publicar matrículas, email u otros datos privados adicionales. La política concreta de exposición y almacenamiento de la foto permanece pendiente; no se presupone un proveedor externo ni un mecanismo de carga.

## Ajustes e integraciones

| Área | Contrato de #278 | Estado / tratamiento |
| --- | --- | --- |
| Intervalo | El Profesional configura su intervalo de reserva. | Reutilizar contexto y persistencia; conservar propietario por cuenta. |
| Catálogo | Configura consultas, duración y precio propios. | Reutilizar catálogo; comprobar compatibilidad beta sin duplicarlo. |
| Horarios semanales | Configura su disponibilidad propia. | Reutilizar configuración y motor de slots. |
| Anticipación mínima | Restringe el primer momento reservable. | Reutilizar evaluación temporal y sus pruebas. |
| Horizonte | Restringe hasta cuándo se puede reservar. | Reutilizar evaluación temporal y sus pruebas. |
| Perfil completo | Controla visibilidad profesional en reservas. | Crear perfil y adaptar listado; no bloquear preparación. |
| Autorización | Ajustes propios exclusivos del Profesional activo. | Conservar controles existentes y extenderlos al perfil. |

Los límites numéricos y reglas históricas de los ajustes no se elevan automáticamente a requisitos beta. #302 debe contrastar las validaciones existentes con las fuentes vigentes y registrar cualquier contradicción antes de alterarlas. #303 puede preparar escenarios con fixtures acordes al contrato; fixtures no prueban integración real.

## Mapa de reutilización y faltantes

Referencias del árbol relevado al crear `feat/301-professional-profile-contract` desde `develop`; los números de línea pueden cambiar con la implementación.

| Clasificación | Evidencia encontrada | Acción posterior |
| --- | --- | --- |
| Reutilizar | `lib/origen/consultation_types.ex:30-101,268-332`; `priv/repo/migrations/20260919235000_create_consultation_configuration.exs:4-79` | Catálogo, intervalo y propiedad por cuenta. |
| Reutilizar | `lib/origen/availability.ex:17-61,141-151,288-299`; `priv/repo/migrations/20260925100000_add_availability_configuration.exs:6-23` | Disponibilidad, anticipación, horizonte y controles por sesión. |
| Reutilizar | `lib/origen/appointments/availability.ex:1-58`; `lib/origen/appointments/database_calendar.ex:50-103` | Slots calculados con duración, intervalo y restricciones temporales. |
| Reutilizar / extender | `lib/origen/authorization/rules.ex:51-57`; `lib/origen_web/router.ex:52-57` | Mantener ajustes propios y agregar operaciones autorizadas para perfil. |
| Adaptar | `lib/origen_web/live/consultation_type_catalog_live.ex:1-58,307-320`; `lib/origen_web/live/professional_availability_component.ex:28-90,303-365` | Integrar edición del perfil sin exigir completitud para entrar a preparación. |
| Reemplazar en el recorrido | `lib/origen/appointments/database_calendar.ex:25-48` | Actualmente lista todas las cuentas profesionales activas, usa email como nombre y «Medicina General» fija. Filtrar completitud y usar datos declarados. |
| Adaptar | `lib/origen_web/live/patient_booking_calendar_live.ex:7-28` | Consumir el listado real elegible; no confundirlo con la completitud del perfil del Paciente. |
| Crear | No se encontró esquema, migración ni contexto de perfil profesional persistido en el relevamiento. | Perfil 1:1, operaciones propias, completitud y pruebas de elegibilidad/foto/permisos. |

## Escenarios verificables para las siguientes subtareas

Son criterios del contrato, **no resultados de pruebas ya ejecutadas ni funcionalidad implementada**.

| ID | Preparación / acción | Resultado observable y efectos |
| --- | --- | --- |
| C1 | Profesional activo sin perfil abre preparación y configura ajustes propios. | Accede y guarda ajustes válidos; no aparece en listado reservable. |
| C2 | Omitir por separado nombre, apellido, especialidad, tipo o número de matrícula. | El perfil no se considera completo ni aparece como reservable; no se inventan valores. |
| C3 | Completar los cinco campos sin foto. | Aparece con sus datos declarados; la falta de foto no bloquea acceso ni reserva cuando los demás requisitos del turno se cumplen. |
| C4 | Usar valores libres de tipo/número de matrícula, sin catálogo ni comprobación externa. | Se aceptan como texto conforme a las validaciones acordadas; no se exige una matrícula verificable. |
| C5 | Consultar listado con profesional completo pero cuenta no activa. | No aparece; no se alteran perfil ni ajustes por consultar. |
| C6 | Profesional A intenta leer o editar perfil/ajustes de B, incluso alterando identificadores del cliente. | Denegado sin exponer valores privados ni modificar datos de B. |
| C7 | Secretaría intenta leer o modificar perfil, catálogo, intervalo o disponibilidad profesional. | Denegado por dominio y recorrido web; no se devuelven valores privados ni cambian datos. |
| C8 | Sesión inválida intenta acceso o edición de perfil/ajustes. | No obtiene acceso ni altera datos. |
| C9 | Profesional activo e incompleto usa catálogo, intervalo, horarios, anticipación y horizonte. | La preparación conserva su comportamiento; la incompletitud sólo restringe listado. |
| C10 | Perfil completo y agenda con diferentes duraciones/intervalos y límites temporales. | El motor conserva disponibilidad, encaje de duración, anticipación y horizonte; listado no equivale a existencia de slots. |
| C11 | Consultar listado de perfil completo con email distinto de nombre/especialidad. | Se muestran datos declarados, no email como nombre ni especialidad fija; no se expone el registro privado completo. |
| C12 | Editar perfil manteniendo la misma cuenta y ajustes ya guardados. | Catálogo y disponibilidad conservan propietario, valores y acceso; no se exige migración de propiedad. |

Para cada denegación se comprobarán resultado de error, ausencia de exposición y ausencia de mutaciones mediante las interfaces públicas. Las pruebas web y de dominio deben distinguir datos simulados de integraciones reales. #304 sólo comienza cuando sus hermanas estén terminadas y aprobadas, con sus blockers vigentes satisfechos.

## Evidencia de verificación

### Código encontrado y pruebas leídas

El relevamiento de sólo lectura identificó las referencias anteriores y pruebas existentes de:

- Catálogo y denegación a Secretaría/Administrador: `test/origen/consultation_types_test.exs:70-100`.
- Disponibilidad y permisos por rol/estado/propiedad: `test/origen/availability_test.exs` y `test/origen/authorization_test.exs:36-65`.
- Pantalla de ajustes y disponibilidad: `test/origen_web/consultation_type_catalog_live_test.exs`, `test/origen_web/professional_availability_live_test.exs`.
- Listado histórico sin perfil: `test/origen/appointments/database_calendar_test.exs:38-50`.
- Slots y restricciones temporales: `test/origen/appointments/availability_test.exs:8-120`.
- Consumo del calendario: `test/origen_web/live/patient_booking_calendar_live_test.exs`.

La existencia o lectura de estas pruebas no demuestra aprobación ni cumplimiento beta. En particular, una prueba del listado histórico puede pasar y seguir siendo incompatible con la regla nueva.

### Ejecución observada

Se intentó una ejecución de referencia en una partición exclusiva de test, sin usar `ORIGEN_DATABASE_URL`:

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue301_contract mix test \
  test/origen/consultation_types_test.exs \
  test/origen/availability_test.exs \
  test/origen/authorization_test.exs \
  test/origen_web/consultation_type_catalog_live_test.exs \
  test/origen_web/professional_availability_live_test.exs \
  test/origen/appointments/database_calendar_test.exs \
  test/origen/appointments/availability_test.exs \
  test/origen_web/live/patient_booking_calendar_live_test.exs
```

**Primer intento:** código de salida 1 antes de ejecutar casos. PostgreSQL no aceptó conexiones en `localhost:5433`: `tcp connect (localhost:5433): connection refused - :econnrefused`. Mix terminó con `The database for Origen.Repo couldn't be created: killed`. Ese intento no produjo resultados funcionales; no se levantaron servicios ni se modificó configuración desde el agente.

**Ejecución posterior autorizada:** Santiago encendió PostgreSQL y confirmó «esta listo». Se ejecutó el mismo comando y partición de test: código de salida **0**, **152 pruebas aprobadas**, duración ExUnit **10,2 segundos**, seed **841528**. ExUnit informó `Excluding tags: [postgres_security: true]`. Estas pruebas verifican el comportamiento existente de los ocho archivos seleccionados; no demuestran que el perfil, su completitud ni los escenarios C1–C12 estén implementados.

**Verificación documental observada:** enlaces locales y referencias a archivos de código/pruebas existentes válidos; trazabilidad #301/#278/#302/#303/#304, decisión de propiedad, estado de borrador y doce escenarios presentes. `git diff --check` pasó para el árbol versionado; el documento nuevo se validó además con una comprobación explícita de referencias. La revisión nativa no se inició porque el switch RDD está `off`.

No hay pruebas implementadas de perfil, completitud o foto en esta subtarea. Al ser un cambio documental sin comportamiento ejecutable nuevo, no se aplica RED/GREEN. La suite completa no se ejecutó: se limitó la verificación a los ocho archivos de referencia del slice, sin modificar código de aplicación. Las pruebas etiquetadas `postgres_security` no formaron parte de esta ejecución.

## Pendientes y aprobación

- Aprobado por Santiago: conservar propiedad por cuenta y asociar perfil 1:1.
- Resuelto: PostgreSQL de test disponible tras intervención de Santiago; ejecución focalizada con 152 pruebas aprobadas y código de salida 0. Se conserva arriba el fallo de infraestructura del primer intento como evidencia histórica.
- Aprobado explícitamente por Santiago en esta conversación: «apuebo el cocumento, no la regla». Se aprueba este contrato con sus escenarios, diferencias y pendientes documentados. No se aprueba la propuesta posterior de bloquear nuevas reservas desde Secretaría por perfil incompleto; no se incorpora como requisito ni escenario. Tipo y número de matrícula permanecen obligatorios según la beta. No se atribuye aprobación a ninguna persona adicional.
- Antes de implementar la foto: acordar almacenamiento, validaciones y exposición concreta, sin convertirla en obligatoria. No se elige infraestructura en #301.
- Antes de fijar validaciones adicionales de textos: acordar las que no deriven ya de las fuentes beta o de límites técnicos existentes; no inventar reglas de credenciales.
- #302: persistencia y operaciones de perfil, permisos, elegibilidad y regresiones de ajustes.
- #303: edición/estados de perfil, preparación incompleta y consumo de proyección real, con pruebas propias.
- #304: integración real y evidencia de todos los criterios de #278; no queda aprobada por este documento.
- Aprobación contractual registrada localmente. #301 sigue abierto en GitHub: no se publicaron comentarios ni cambios de estado, ni se realizaron commits. La aprobación del contrato no acredita implementación de #278 ni aprobación de #304.
