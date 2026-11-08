# Convención de URLs y plan de migración

Las URLs de producto de Origen se escriben en español y se organizan por rol, sección y subpantalla. Este es el documento canónico para crear o modificar rutas y enlaces del frontend.

Esta sección de planificación corresponde a [#369](https://github.com/Team-Origen/origen/issues/369), hija de [#368](https://github.com/Team-Origen/origen/issues/368). Documenta destinos y compatibilidad; no implementa rutas. La migración corresponde a [#370](https://github.com/Team-Origen/origen/issues/370). El diseño de navbars se acordará por separado y su implementación corresponde a [#371](https://github.com/Team-Origen/origen/issues/371). Este documento no completa por sí solo la issue #369.

## Aplicación rápida

1. Consultar el inventario antes de crear o modificar una ruta o enlace.
2. Reutilizar la estructura y los nombres definidos aquí; conservar comportamiento, filtros y autorización existentes.
3. Si el caso no encaja o requiere una decisión pendiente, señalarlo antes de inventar otra estructura.

## Convención

| Tema | Regla |
| --- | --- |
| Estructura | `/<rol>/<seccion>/<subpantalla>`. No invertir la jerarquía con formas como `/configuracion/profesional`. |
| Idioma | Español en rutas de producto nuevas o migradas, salvo excepciones explícitas. |
| Escritura | Minúsculas, segmentos sin tildes ni `ñ`, palabras separadas por guiones. |
| Roles | `paciente`, `profesional`, `secretaria`, `administrador`, en singular. |
| Secciones | Nombre de producto: `agenda`, `ajustes`, `resumen-economico`. Colecciones en plural: `turnos`, `pacientes`, `cuentas`. |
| Pertenencia | Una subpantalla conserva su sección: `/profesional/ajustes/perfil`. Esto no exige una entrada propia en la futura navbar. |
| Recursos | Agregar `/:id` solo si hay una pantalla independiente que lo necesite; no crear pantallas por cumplir un patrón. |
| Acciones | Un botón, modal o paso de formulario no necesita una URL propia. Conservar los recorridos existentes. |
| Filtros existentes | Si hoy no se muestran en la URL, mantenerlos así. No agregar parámetros ni cambiar su persistencia por esta migración. |
| Parámetros existentes | Conservar nombres y comportamiento, incluido `?date=AAAA-MM-DD` en Agenda. No traducirlos solo por uniformidad. |
| Pantallas nuevas | Definir sus parámetros cuando se acuerde su recorrido. Usar parámetros para filtros si corresponde, sin imponerlos a pantallas existentes. |
| Autorización | El prefijo de rol organiza, no concede permisos. Reutilizar los controles existentes; no reauditar ni modificar permisos en esta migración. |

No colocar DNI, teléfono o correo en rutas nuevas. El token del magic link es una credencial del mecanismo existente, no un ejemplo de identificador de recurso para nuevas pantallas.

## Inventario y destinos

Base relevada: commit `a735b37`, [router](../../lib/origen_web/router.ex) y enlaces del frontend. «Existente» no significa que toda la funcionalidad prevista por la beta esté completa. Las pantallas previstas no deben presentarse como implementadas ni crearse automáticamente durante el cambio de URLs.

### Paciente

| URL actual | Destino | Tratamiento |
| --- | --- | --- |
| `/access` | `/paciente/acceso` | Migrar la solicitud de magic link. |
| `/access/verify?token=…` | `/paciente/acceso/verificar?token=…` | Migrar el punto de consumo conservando el mecanismo y enlaces anteriores. No es una sección de menú. |
| `/patient/calendar` | `/paciente/turnos/reservar` | Migrar el recorrido de reserva existente sin cambiar sus filtros ni pasos. |
| `/patient/phone/verify` | `/paciente/telefono/verificar` | Destino si se conserva este recorrido. Su ubicación en el flujo beta sigue pendiente; no imponer verificación telefónica como requisito de reserva. |
| `/patient/profile/complete` | Sin equivalente habilitado | La ruta está bloqueada por `deny_self_edit`. Mantener la denegación; no habilitar autoedición ni crear otra pantalla por renombrarla. |
| Sin ruta actual | `/paciente/turnos` | Ubicación prevista para consultar turnos propios, estados, precio y estado de pago según la beta. Su implementación no pertenece a la migración de rutas existentes. |

No se define una sección independiente de pagos del Paciente: la beta permite consultar precio y estado, no registrar pagos ni cargar comprobantes.

### Profesional

| URL actual | Destino | Tratamiento |
| --- | --- | --- |
| `/profesional/agenda` | `/profesional/agenda` | Conservar, incluido `?date=AAAA-MM-DD`. |
| `/profesional/agenda/crear` | `/profesional/agenda/crear` | Conservar el recorrido real de reserva. El modo demo opcional no convierte esta ruta en un borrador exclusivo. |
| `/configuracion/profesional` | `/profesional/ajustes` | Migrar sin dividir las configuraciones actuales en nuevas pantallas. |
| `/configuracion/profesional/perfil` | `/profesional/ajustes/perfil` | Migrar; Mi perfil continúa dentro de Ajustes. |
| Sin ruta actual | `/profesional/resumen-economico` | Ubicación prevista para #288, limitada al resumen propio. |

Aceptar solicitudes, cancelar, marcar asistencia y registrar o corregir pagos no requieren URLs nuevas por sí mismos. Esta planificación no rediseña esas interacciones.

### Secretaría

| URL actual | Destino | Tratamiento |
| --- | --- | --- |
| `/secretaria/pacientes` | `/secretaria/pacientes` | Conservar búsqueda, registro y operaciones asistidas existentes. |
| Sin ruta actual | `/secretaria/agenda` | Ubicación prevista para operar agendas según la beta. Selección de Profesional y recorrido pendientes del diseño de esa pantalla. |
| Sin ruta actual | `/secretaria/resumen-economico` | Ubicación prevista para #288: un Profesional por vez. |

No se exige `/secretaria/agenda/crear`: antes de agregarla debe acordarse su relación con la reserva asistida existente en Pacientes. No duplicar el flujo. No se define acceso de Secretaría a ajustes profesionales.

### Administrador

| URL actual | Destino | Tratamiento |
| --- | --- | --- |
| `/admin/internal` | `/administrador/cuentas` | Migrar la ubicación de cuentas internas. El ciclo completo de crear, editar, desactivar y reactivar pertenece a #279. |

La pantalla actual ejecuta operaciones reales de cuentas; no se excluye como un mockup. No se exige una URL por cada acción: si #279 necesita pantallas independientes, deberán seguir la estructura `/administrador/cuentas/crear`, `/administrador/cuentas/:cuenta_id` o `/administrador/cuentas/:cuenta_id/editar`, según lo que se acuerde allí. Estos patrones no autorizan crear esas pantallas ahora.

Administrador no recibe acceso a pacientes, agendas, pagos, resumen económico ni ajustes profesionales.

### Acceso compartido y activación

| Método y URL actual | Destino | Tratamiento |
| --- | --- | --- |
| `GET /` | `/` | Conservar. Hoy funciona como portal de Paciente; el destino del logo y el comportamiento de inicio por rol se acordarán con navegación. |
| `GET /login`, `POST /login` | Sin cambio | Excepción explícita para ingreso interno. |
| `POST /logout` | Sin cambio | Excepción explícita: reutilizar el cierre de sesión interno existente y retorno a `/login`. No convertirlo en GET ni equipararlo al flujo de Paciente. |
| `GET /activate`, `POST /activate` | `/activar` | Destino en español para el mismo flujo de invitación. |
| `POST /activate/exchange` | `/activar/intercambiar` | Paso técnico del mismo flujo, no una pantalla de menú. |
| `GET /admin/activate`, `POST /admin/activate` | `/administrador/activar` | Destino en español para la activación especial del Administrador inicial. |
| `POST /admin/activate/exchange` | `/administrador/activar/intercambiar` | Paso técnico de esa activación. |

La traducción de activación no permite cambiar su autenticación, tokens ni protección CSRF. Su compatibilidad debe resolverse conservando el mecanismo existente, no rediseñándolo.

## Compatibilidad y alcance de la implementación

- Actualizar rutas, enlaces, formularios y redirecciones afectados de manera conjunta.
- Para páginas GET ordinarias renombradas, mantener la URL anterior como entrada compatible que redirige al destino acordado, preservando los parámetros existentes que use el recorrido. No crear pantallas duplicadas.
- En magic links y activaciones, mantener la aceptación de enlaces e invitaciones anteriores mediante el manejo existente. No redirigir indiscriminadamente credenciales ni solicitudes POST. El mecanismo implementado en #370 se detalla en «Implementación de la migración»: los endpoints anteriores conservan handlers directos.
- Conservar sin cambio las rutas ya consistentes y el parámetro `date` de Agenda.
- No agregar filtros a la URL cuando actualmente viven en el estado de la pantalla; no cambiar cómo funcionan al recargar o usar Atrás/Adelante. Para rutas migradas, preservar el comportamiento existente de acceso directo y navegación del navegador.
- Conservar la denegación de la antigua ruta de autoedición de perfil del Paciente; no convertirla en una pantalla accesible.
- No implementar funciones pendientes para llenar los destinos previstos. No reauditar ni alterar autorizaciones por rol: el alcance sobre pantallas existentes es cambiar su URL y referencias.
- Verificar en #370 la correspondencia de rutas, enlaces y compatibilidad afectada. En #371 se podrá probar la navegación por rol y la conservación de restricciones existentes al integrar las navbars, sin rediseñar seguridad.

## Exclusiones y pendientes

Quedan fuera las rutas de borradores y herramientas de desarrollo (`/dev/professional-availability`, `/dev/dashboard`, `/dev/mailbox`), assets y endpoints de integración como `/api/bootstrap/provider-events`. No traducir estos contratos técnicos como efecto colateral de la convención del frontend.

Pendientes explícitos:

- Lugar de la verificación telefónica existente en el recorrido beta; no resolverlo imponiendo requisitos históricos.
- Diseño de las pantallas nuevas, filtros que realmente necesiten y acceso a la creación asistida desde Agenda de Secretaría.
- Compatibilidad de magic links y activación: resuelta en la implementación de #370 mediante handlers directos para los endpoints anteriores (ver sección siguiente).
- La pantalla actual `/admin/internal` contempla Secretaría en `allowed_roles_for`, mientras la beta asigna gestión de cuentas al Administrador. Registrar esta discrepancia no autoriza corregir permisos en la migración ni reproducirla como permiso aprobado.
- Navbars: entradas, orden, sección activa, destinos de logo/nombre y ubicación de cierre de sesión se definirán en la siguiente sección de planificación. No están acordados por este inventario.

## Implementación de la migración (#370)

Las rutas existentes del inventario cuentan con sus destinos canónicos en español. La verificación telefónica conserva su recorrido actual en `/paciente/telefono/verificar`, sin incorporarse como requisito nuevo de reserva. Los destinos sin pantalla actual siguen siendo planificación.

- Las entradas GET antiguas de acceso, reserva, teléfono, cuentas y ajustes redirigen al destino canónico conservando la cadena de consulta. Ajustes conserva sus controles de sesión y rol antes de la redirección.
- `/access/verify` sigue consumiendo directamente el magic link mediante el mismo controlador que `/paciente/acceso/verificar`: no hay redirección intermedia del token. Los correos nuevos usan el destino canónico.
- Las rutas anteriores de activación conservan sus handlers GET y POST, incluidos los intercambios. Los formularios y pasos siguientes utilizan `/activar` y `/administrador/activar`, con sus respectivos endpoints `/intercambiar`. No se redirigen cuerpos POST ni se cambia el mecanismo de credenciales en fragmentos.
- La configuración de origen de la invitación inicial admite tanto el path anterior exacto como el nuevo, con las mismas restricciones de host, entorno y HTTPS. Normaliza la emisión de invitaciones nuevas a `/administrador/activar`; no exige cambiar de inmediato una configuración existente.
- `/patient/profile/complete` permanece denegada. Login, logout, Agenda, `date`, Secretaría y endpoints técnicos no cambian.

Las decisiones visuales e inicios por rol registrados en `NAVIGATION_DECISIONS.md` siguen separados de esta migración y no se implementan aquí.

### Verificación

- RED inicial: las ocho pruebas nuevas de migración fallaron antes de modificar las rutas.
- Suite completa sobre una base de pruebas aislada (`MIX_TEST_PARTITION=_issue370_verify`): 929 pruebas aprobadas, 32 omitidas y 8 excluidas; salida 0.
- Verificación independiente: controles de sesión/rol, preservación exacta de consultas, handlers de compatibilidad y validadores de origen aprobados.
- La base local preexistente produjo errores de preparación por la FK `agenda_settings_owner_account_id_fkey`; no se borraron ni corrigieron sus datos para hacer pasar las pruebas.
- Acceso directo, guards de LiveView y recarga de activación se comprobaron mediante pruebas automatizadas. Atrás/Adelante y recarga en navegador real no se verificaron; no se presentan como evidencia completada.

## Fuentes y trazabilidad

| Fuente | Qué establece |
| --- | --- |
| [Issue #369](https://github.com/Team-Origen/origen/issues/369), [padre #368](https://github.com/Team-Origen/origen/issues/368) | Alcance de planificación y cadena #369 → #370 → #371, sin redefinir permisos ni implementar funciones pendientes. |
| [Router](../../lib/origen_web/router.ex) | Rutas reales y separación de recorridos actuales. |
| [Agenda profesional](../../lib/origen_web/live/professional_agenda_live.ex) | Parámetro `date` existente. |
| [Autorización de Paciente](../../lib/origen_web/live/patient_session_auth_live.ex) | Sesión de Paciente y denegación de autoedición. |
| [Cuentas internas](../../lib/origen_web/live/admin_internal_live.ex) | Pantalla actual y discrepancia declarada, sin aprobación de nuevos permisos. |
| [Sesión interna](../../lib/origen_web/controllers/internal_session_controller.ex) | Login, cierre de sesión y retorno a `/login`. |
| [Reserva y ciclo de turno](../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md) | Alcances beta sobre turnos, agendas y privacidad por rol. |
| [Cuentas y ajustes](../../openspec/changes/health-center-beta-core/specs/staff-accounts-and-professional-settings/spec.md) | Responsabilidades de Administrador y Profesional, exclusión de Secretaría de ajustes profesionales. |
| [Pagos y resumen](../../openspec/changes/health-center-beta-core/specs/payments-and-period-summary/spec.md) | Resumen propio o por Profesional, consulta limitada del Paciente y exclusión del Administrador. |
| [Matriz de autorización](../security/AUTHORIZATION_MATRIX.md) | Fuente canónica incremental de permisos; declara `0.6-draft` y aprobación histórica de `0.4`, no aprobación general de versiones posteriores. |

Las aclaraciones del responsable de esta planificación preservan filtros fuera de la URL, autorizaciones existentes y el alcance de renombrado de pantallas ya implementadas. Este documento no sustituye las especificaciones de negocio ni convierte una discrepancia en un permiso nuevo.
