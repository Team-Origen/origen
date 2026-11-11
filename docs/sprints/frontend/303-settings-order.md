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

La PR preparatoria [#330](https://github.com/Team-Origen/origen/pull/330) referencia `Refs #303` y queda en borrador hasta completar sus checks. La segunda PR [#331](https://github.com/Team-Origen/origen/pull/331), basada en ésta, declara `Closes #303`.

El primer CI rechazó `Refs` porque sólo aceptaba referencias de cierre. Ante la indicación de Santiago de corregir los errores de las PRs, se amplió esa misma validación para aceptar `Refs` sin cambiar el soporte de `Closes/Fixes/Resolves` ni la semántica de cierre de GitHub. Se conserva el rechazo de referencias ausentes o malformadas y la entrada se pasa a Bash mediante la variable de entorno `BODY`, no mediante interpolación del contenido en código.

La regresión ejecuta el comando real del workflow: `python3 -m unittest discover -s test/ci -p 'test_*.py'`. RED inicial: exit **1**, 3 tests con 6 fallos; GREEN inicial: exit **0**, los 3 tests aprobados. Un recontrol detectó que los tokens `Refs #303abc` y `prefixRefs #303` se aceptaban indebidamente; ambos produjeron un RED adicional (exit **1**, 2 fallos) y quedaron cubiertos por el GREEN final (exit **0**, 3 tests aprobados). Las pruebas comprueban código de salida, stdout y stderr para referencias no cerradoras, las tres referencias de cierre y entradas rechazadas. El workflow ejecuta esa prueba antes de preparar Elixir. `shellcheck` no está instalado localmente; la sintaxis Bash y sus resultados se verifican por ejecución pública de la propia validación. El recontrol independiente limitado se canceló sin veredicto; Santiago autorizó continuar sin ese resultado y no se lo declara como aprobación independiente.

Santiago aprobó dividir en stack hacia `develop` y aceptó el exceso de tamaño. El movimiento de secciones produce líneas añadidas y eliminadas sin ampliar comportamiento. No se fragmenta artificialmente el mismo recorrido ni se omiten pruebas para reducir el conteo.
