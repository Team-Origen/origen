# #302: perfil profesional persistido

> Registro del backend entregado en #302. La conexión real del editor y la verificación del recorrido se documentan en [integración #304](../integration/304-perfil-profesional.md); las referencias al formulario simulado siguientes describen el alcance original de #302.

Backend del [contrato #301](../contracts/301-perfil-profesional.md): persistencia y permisos del perfil propio, listado elegible y protección exclusiva de la reserva autónoma del Paciente. La carga, almacenamiento y exposición de fotos se posponen; su ausencia no impide completar el perfil.

## Operaciones privadas

`Origen.ProfessionalProfiles` recibe el principal interno creado por el servidor (`session_id`, `account_id`). Revalida sesión, cuenta activa, rol Profesional y propiedad en cada operación. No usa IDs de propietario enviados por el cliente como autorización.

| Operación | Resultado |
| --- | --- |
| `get_own_profile/1` | `{:ok, nil}` si no existe; `{:ok, profile}` si está guardado. Leer no crea un perfil. |
| `save_own_profile/2` | Guarda un parche parcial; campos omitidos conservan su valor. Acepta claves atom o string, texto libre o `nil`. Recorta espacios; vacío borra el campo. |
| Completitud | `complete?` derivado de `first_name`, `last_name`, `specialty`, `license_type`, `license_number`. Los cinco deben tener texto. No exige foto, catálogo ni slots. |
| Datos malformados | `{:error, {:validation, errors}}`; no modifica el perfil ni los ajustes. `id`, `account_id` y `owner_account_id` en atributos se rechazan con `:protected_fields`. |
| Acceso rechazado | `{:error, :unauthorized}` sin datos privados: Secretaría, Administración, sesión inválida/inactiva/revocada o identidad manipulada. |
| Error de persistencia | `{:error, :unavailable}`; la transacción no deja cambios parciales. |

La tabla `professional_profiles` tiene una fila por cuenta, campos textuales anulables y propietario inmutable. El contexto serializa parches sobre la fila para no sobrescribir campos omitidos. Catálogo, intervalo, horarios, anticipación y horizonte siguen perteneciendo a la cuenta: no se migran ni duplican.

La migración concede sólo SELECT/INSERT/UPDATE y uso de secuencia al rol runtime existente; no concede DELETE ni acceso a PUBLIC. El rollback se niega a borrar una tabla poblada. No se ejecutó rollback sobre datos reales.

## Listado y calendario de pacientes

`DatabaseCalendar.list_professionals/0` conserva la API `{:ok, list}` y los IDs de cuenta como strings. Selecciona cuentas Profesionales activas con los cinco campos completos y devuelve únicamente `id`, `name` (nombre y apellido declarados) y `specialty`. No publica email ni matrícula ni agrega requisitos de catálogo o disponibilidad.

Si el listado queda vacío, el calendario muestra «No hay profesionales disponibles para reservar en este momento.», oculta controles y no consulta horarios. Los eventos del cliente se ignoran mientras no haya profesional seleccionado, incluyendo confirmación de reservas. El motor de slots y los turnos existentes no cambian.

## Protección de la reserva autónoma

La ampliación exclusiva del Paciente fue aprobada por Santiago con «si» a «¿Aprobás esa corrección exclusiva del Paciente?». El calendario ignora `change_prof` cuando el ID no pertenece al listado presentado. La frontera de dominio `BookingService.reserve/2` vuelve a comprobar cuenta Profesional activa y los cinco campos completos; si no se cumplen devuelve `{:error, :professional_not_eligible}` sin crear turnos. La comprobación mantiene locks compartidos sobre cuenta y perfil hasta terminar la transacción de reserva, evitando que pierdan elegibilidad entre la validación y la escritura.

Esta condición no se añade a `Booking.reserve_appointment/2`, la persistencia compartida ni `DatabaseCalendar.get_daily_schedule/3`: la reserva asistida de Secretaría y la preparación de agendas incompletas conservan su comportamiento. El formulario simulado de #303 no se conecta al backend.

## Verificación del primer corte

En una partición de pruebas exclusiva (`MIX_TEST_PARTITION=_issue302_pr1`), con dependencias ya instaladas y configuración local de pruebas conservada sin cambios:

- `mix test test/origen/professional_profiles_test.exs test/origen/authorization_test.exs test/origen/consultation_types_test.exs test/origen/availability_test.exs`: exit 0, **71 aprobadas**, seed `362584`.
- `mix test`: exit 0, **703 aprobadas**, 29 omitidas y 8 excluidas, seed `929729`.
- `mix format --check-formatted` y `git diff --check`: exit 0.
- `python3 -m unittest discover -s test/ci -p 'test_*.py'`: exit 0, **3 aprobadas**.

Las ejecuciones Mix usan `env -u ORIGEN_DATABASE_URL MIX_ENV=test`. Las pruebas `postgres_security` siguen excluidas por la configuración existente. No se atribuye validación visual ni ejecución de rollback sobre datos reales. La primera preparación del worktree omitió el archivo ignorado `config/test.local.exs` y abortó antes de ExUnit; se conservó ese archivo sin cambios y se ejecutaron después los checks anteriores. No se instalaron ni descargaron dependencias.

## Verificación del segundo corte

En una partición exclusiva (`MIX_TEST_PARTITION=_issue302_pr2`), con `env -u ORIGEN_DATABASE_URL MIX_ENV=test`:

- Suite focalizada de perfil, autorización, listado, reserva autónoma, calendario LiveView, catálogo, disponibilidad, reserva atómica y recorridos históricos: exit 0, **127 aprobadas**, seed `671285`.
- `mix test`: exit 0, **708 aprobadas**, 29 omitidas y 8 excluidas, seed `842796`.
- `mix format --check-formatted` y `git diff --check`: exit 0.
- `python3 -m unittest discover -s test/ci -p 'test_*.py'`: exit 0, **3 aprobadas**.

Los quince archivos de implementación, pruebas y contrato coinciden por SHA-256 con el candidato final previamente verificado; sólo se organizó su entrega y se acotó la documentación por corte. La verificación independiente anterior del conjunto obtuvo **127 aprobadas**, seed `310051`. No se atribuye esa ejecución a los checks remotos de estos PRs. No se ejecutó navegador ni `postgres_security` localmente; sí se cubrieron renderizado y eventos LiveView. No se instalaron ni descargaron dependencias.

## Alcance y entrega

El primer PR entrega persistencia y permisos; este segundo corte agrega elegibilidad y protección del calendario y la reserva autónoma. No se conecta el editor simulado de #303; su integración real corresponde a #304. No se acredita integración de #278 ni se autorizan merges o cierre manual de issues. La aprobación humana final y los checks remotos siguen siendo condiciones de entrega.
