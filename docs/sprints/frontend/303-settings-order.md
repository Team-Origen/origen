# #303: preparar el orden de Ajustes

Primer corte del stack de [#303](https://github.com/Team-Origen/origen/issues/303). Deja las opciones operativas en el orden **disponibilidad semanal → tipos de consulta → intervalo de agenda → zona horaria**. El segundo corte agrega el perfil profesional como primera tarjeta; esta preparación no completa #303.

## Alcance

- Conserva componentes Petal, permisos, validaciones y valores guardados.
- Usa contenido opcional del componente de disponibilidad para ubicar catálogo e intervalo antes de zona horaria; la vista previa de disponibilidad sin contenido sigue funcionando.
- Las actualizaciones de presentación del padre conservan el editor y su borrador. La confirmación de un cambio de intervalo mantiene su actualización explícita de configuración.
- Un error al cargar disponibilidad no oculta catálogo ni intervalo.

## Verificación

Prueba del orden agregado a `test/origen_web/professional_availability_live_test.exs`. Las regresiones existentes cubren edición, cancelación, guardado, fallos, cambio de intervalo y vista previa sin persistencia. El árbol completo original pasó 696 pruebas. Este primer corte se comprobó aisladamente con `env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue303_stack_order mix test`: exit **0**, **679 aprobadas**, **29 skipped**, **8 excluded**, seed `230912`. `postgres_security` quedó excluido. El primer intento no ejecutó casos por faltar la configuración local ignorada de PostgreSQL en el worktree; se copió con permisos restringidos, sin versionarla ni modificar el original, y la ejecución posterior completó correctamente. Se observó una advertencia de redefinición de un módulo de migración; no falló la suite.

## Entrega

La PR preparatoria referencia `Refs #303`, queda en borrador y depende de la política del repositorio para poder integrarse: el CI actual sólo acepta referencias de cierre (`Closes/Fixes/Resolves`), por lo que su validación de issue no pasa. No se altera CI ni se declara #303 terminada desde este corte. La segunda PR, basada en ésta, declara `Closes #303`.

Santiago aprobó dividir en stack hacia `develop` y aceptó el exceso de tamaño. El movimiento de secciones produce líneas añadidas y eliminadas sin ampliar comportamiento. No se fragmenta artificialmente el mismo recorrido ni se omiten pruebas para reducir el conteo.
