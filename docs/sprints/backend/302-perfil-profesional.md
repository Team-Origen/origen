# #302: perfil profesional persistido

Primer corte del backend del [contrato #301](../contracts/301-perfil-profesional.md): persistencia y permisos del perfil propio. La carga, almacenamiento y exposición de fotos se posponen; su ausencia no impide completar el perfil.

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

## Alcance del primer corte

Este corte no cambia el listado ni las reservas de pacientes. El filtrado de elegibilidad y la protección de su calendario pertenecen al segundo PR apilado. El [editor simulado de #303](../frontend/303-perfil-profesional.md) conserva sus datos simulados; su conexión real corresponde a #304. No cambia el comportamiento de Secretaría ni la preparación de catálogo y horarios.

## Verificación del primer corte

En una partición de pruebas exclusiva (`MIX_TEST_PARTITION=_issue302_pr1`), con dependencias ya instaladas y configuración local de pruebas conservada sin cambios:

- `mix test test/origen/professional_profiles_test.exs test/origen/authorization_test.exs test/origen/consultation_types_test.exs test/origen/availability_test.exs`: exit 0, **71 aprobadas**, seed `362584`.
- `mix test`: exit 0, **703 aprobadas**, 29 omitidas y 8 excluidas, seed `929729`.
- `mix format --check-formatted` y `git diff --check`: exit 0.
- `python3 -m unittest discover -s test/ci -p 'test_*.py'`: exit 0, **3 aprobadas**.

Las ejecuciones Mix usan `env -u ORIGEN_DATABASE_URL MIX_ENV=test`. Las pruebas `postgres_security` siguen excluidas por la configuración existente. No se atribuye validación visual ni ejecución de rollback sobre datos reales. La primera preparación del worktree omitió el archivo ignorado `config/test.local.exs` y abortó antes de ExUnit; se conservó ese archivo sin cambios y se ejecutaron después los checks anteriores. No se instalaron ni descargaron dependencias.
