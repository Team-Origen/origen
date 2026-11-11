# #390 — Mock de Resumen económico

Prototipo de interfaz para [#390](https://github.com/Team-Origen/origen/issues/390), hija de [#288](https://github.com/Team-Origen/origen/issues/288). Usa datos ficticios locales: no consulta turnos, pacientes ni pagos reales y no certifica integración financiera.

## Aprobación del mock

El usuario aprobó explícitamente la interfaz y solicitó su publicación: «LISTO, FORN APROBADO, HAS LOS PRS». Esta aprobación corresponde al frontend mockeado; no certifica backend financiero ni integración real. La revisión automatizada en navegador y la prueba ejecutable independiente conservan las limitaciones registradas abajo.

## Alcance y decisiones de presentación

Base: [contrato aprobado #388](../contracts/388-resumen-economico-por-fecha-turno.md). Ampliaciones acordadas en la conversación de preparación de #390:

- Mes actual organizacional al ingresar, navegación anterior/siguiente y selector de mes/año; rango de fechas inclusivo y día único con fechas iguales.
- Profesional: resumen propio sin selector. Secretaría: selector de un Profesional de demostración por vez, sin agregado global ni selección inicial implícita. Al seleccionar, muestra una ficha con avatar de iniciales, nombre y especialidad ficticia (Psicología/Nutrición); las opciones incluyen nombre y especialidad. El avatar es un placeholder para la futura foto de perfil, no implementa carga ni consulta de imágenes. La ficha es el botón del selector: las opciones con avatar, nombre y especialidad sólo se despliegan al tocarla; elegir un Profesional, volver a tocar la ficha, hacer clic fuera o presionar Escape cierra el desplegable.
- Pagado, Pendiente y Total considerado en ARS. Pendiente conserva confirmados y asistidos impagos, según el contrato.
- Lista desplegable informativa de **Atenciones pendientes de pago**: fecha completa, paciente ficticio e importe. Sólo asistidos impagos en el período. No incluye confirmados sin asistencia ni infiere asistencia porque haya pasado una fecha.
- El listado es un subconjunto de Pendiente: su suma no tiene por qué coincidir con esa tarjeta. No agrega acciones ni enlaces de pago.
- Sin gráficos, conteos de atenciones, desglose de tipos ni cambios al flujo de pagos.
- Paleta y componentes existentes de Origen: `assets/css/app.css` y `RoleNavigation`. No se crea una identidad visual distinta.

## Implementación futura: impresión y exportación PDF

Por decisión explícita del usuario, la impresión/exportación PDF queda pendiente para una implementación futura; no forma parte de la entrega actual de #390 ni bloquea su cierre.

- Alternativa recomendada para evaluar: «Imprimir / Guardar como PDF» mediante el navegador, con estilos de impresión que oculten navegación, filtros y botones.
- Contenido propuesto, pendiente de especificación y aprobación: Profesional y período efectivamente consultados, los tres importes y la tabla informativa completa, con tratamiento de saltos de página. Si se utiliza con datos simulados, conservar el aviso «Datos ficticios».
- La descarga directa de un PDF con formato controlado es una alternativa distinta, todavía no seleccionada. No se agrega una dependencia ni se decide una herramienta aquí.
- Este registro no implementa un botón, no autoriza ampliar el backend ni acredita exportación funcional. El alcance y sus pruebas se acordarán al retomar la mejora.

## Acceso y prueba manual

Con una sesión interna activa del rol correspondiente:

- `/profesional/resumen-economico`
- `/secretaria/resumen-economico`

Ambas vistas están conectadas al ítem Resumen económico de su navbar. La autenticación sigue siendo real; **los datos financieros y las opciones de profesionales son ficticios**, no autorizaciones sobre cuentas reales. Administrador, Paciente y sesiones anónimas no reciben una pantalla financiera.

Por indicación posterior del usuario, la pantalla ya no muestra «Vista de demostración», la franja «Datos ficticios» ni aclaraciones del prototipo. Esto es un cambio de presentación: los ejemplos siguen siendo locales, ficticios, sin persistencia y sin conexión al backend de pagos. Los recuadros conservan solo importes y explicaciones, sin cantidades de turnos por ahora.

Los ejemplos se generan en el mes actual de la zona organizacional y en noviembre y diciembre de ese mismo año al montar la vista. Si el mes actual es noviembre o diciembre, no se duplican sus datos. Otros meses permiten visualizar el estado vacío. Hay 15 ejemplos de pacientes/turnos por profesional y mes, con nombres ficticios naturales, sin etiquetas «Paciente Demo». Cambiar de Profesional muestra otro conjunto ficticio, nunca un agregado.

- Ejemplo A (Lucía Méndez): Pagado ARS 45.000,00; Pendiente ARS 36.000,00; Total considerado ARS 81.000,00. La tabla contiene cuatro asistidos impagos: Valentina Ríos (día 1, ARS 4.000,00), Benjamín Paz (día 8, ARS 5.000,00), Renata Silva (día 10, ARS 7.500,00) y Malena Costa (día 27, ARS 5.500,00). Los ARS 14.000,00 restantes de Pendiente son reservas confirmadas impagas que no aparecen en la tabla. Pagado incluye ejemplos de turnos confirmados, asistidos, cancelados y ausentes con pago conservado.
- Ejemplo B (Martín Salvatierra): importes dobles y nombres ficticios distintos; por mes, Pagado ARS 90.000,00, Pendiente ARS 72.000,00 y Total considerado ARS 162.000,00.
- Mes anterior/siguiente y selección directa de mes consultan inmediatamente. El botón Consultar resumen sólo aparece en Rango de fechas; editar sus extremos no consulta hasta presionarlo.
- Rango invertido o incompleto: error y conservación del contexto y resultados de la última consulta válida; nunca se convierte un error en cero.
- Un período vacío muestra ceros con explicación. El desplegable tiene su propio estado sin atenciones pendientes.

## Verificación y límites

### Ampliación visual de ejemplos y eliminación de avisos

- Alcance confirmado: no mostrar cantidades de turnos en los tres recuadros por ahora. No se cambian cálculos, permisos, rutas ni persistencia.
- RED: 8 fallos de 9 pruebas, salida 2, antes de modificar avisos, nombres y ejemplos.
- GREEN enfocado: 18 pruebas de resumen económico/navegación, salida 0. Incluye noviembre/diciembre para ambos profesionales, importes exactos, cuatro filas de atenciones impagas, ausencia de avisos y conteos, filtros de mes/rango/día, estados vacíos y selección sin agregado.
- Suite completa posterior: `MIX_TEST_PARTITION=_issue472 mix test`, **1116 aprobadas, 32 omitidas y 8 excluidas**, salida 0. El log incluye mensajes de ownership del SQL Sandbox; no se atribuyen a una causa confirmada ni se presenta como un log limpio.
- Build de assets, formato de los archivos modificados y `git diff --check`: salida 0. RDD permanece desactivado; no se abrió una revisión nativa.
- Las pruebas de DOM no constituyen evidencia visual en navegador. Esta ampliación no declara resueltas las limitaciones de revisión independiente o navegador registradas anteriormente.

### Actualización del PR #464 con develop

Se integró `origin/develop` en `feat/390-resumen-economico-ui` para resolver el conflicto del PR #464. El único conflicto textual estaba en la prueba de navegación de Secretaría: se conserva la cobertura de Agenda y Pacientes incorporada en develop, junto al enlace a Resumen económico. No se descarta ninguna de esas secciones.

- Pruebas enfocadas tras la resolución: 17 aprobadas.
- Suite completa: `MIX_TEST_PARTITION=_issue390_merge mix test`, salida 0: 1088 aprobadas, 32 omitidas y 8 excluidas.
- `mix assets.build`, `mix format --check-formatted` y `git diff --check --cached`: salida 0.
- Se observaron advertencias de uso de una función obsoleta y un barrido diferido de `ExpiryWorker` por ownership del SQL Sandbox; no hubo pruebas fallidas. No se presenta esa salida como ausencia de advertencias.
- Esta actualización de la rama del PR no equivale a fusionar el PR en develop.

### Evidencia previa del mock

- RED observado: cinco pruebas nuevas fallaron antes de añadir las rutas y la pantalla.
- GREEN observado: 14 pruebas enfocadas de LiveView y navegación pasaron tras la implementación inicial, usando `MIX_TEST_PARTITION=_issue390`.
- Las pruebas de LiveView usan fixtures de autenticación aislados y datos financieros ficticios del prototipo. No prueban cálculos contra pagos reales ni el cierre de #288.
- La revisión visual en navegador no pudo iniciarse con Tidewave: el servidor MCP configurado en `localhost:4000` no estaba disponible. No se declara verificación visual completada.
- Suite completa inicial: `MIX_TEST_PARTITION=_issue390 mix test`, salida 0: 1048 aprobadas, 32 omitidas y 8 excluidas (`postgres_security`).
- Ajuste del botón por modalidad: RED observado (una prueba nueva fallida); GREEN enfocado con navegación: 15 aprobadas. Suite completa posterior: `MIX_TEST_PARTITION=_issue390_month mix test`, salida 0: 1049 aprobadas, 32 omitidas y 8 excluidas. Se observaron advertencias de uso de `determine_initial_status/2` obsoleto y redefinición de un módulo de migración durante las pruebas.
- Ajuste del selector con avatar, nombre y especialidad: RED observado (una prueba nueva fallida); GREEN enfocado con navegación: 16 aprobadas. Suite completa posterior: `MIX_TEST_PARTITION=_issue390_avatar mix test`, salida 0: 1050 aprobadas, 32 omitidas y 8 excluidas. Persistieron las advertencias de obsolescencia y redefinición de módulo de migración indicadas arriba.
- Selector desplegable desde la ficha de perfil: RED observado (una prueba nueva fallida); GREEN enfocado con navegación: 17 aprobadas. Suite completa posterior: `MIX_TEST_PARTITION=_issue390_dropdown mix test`, salida 0: 1051 aprobadas, 32 omitidas y 8 excluidas. Persistieron las advertencias de obsolescencia y redefinición de módulo de migración indicadas arriba.
- `mix assets.build`, `git diff --check` y `mix format --check-formatted`: salida 0 en la implementación inicial. En el último ajuste se ejecutó `mix format` sobre los archivos Elixir modificados y `git diff --check`, con salida 0; no se repitió el build de assets.
- Revisión independiente estática: sin defectos bloqueantes observados en alcance, fixtures, filtros, permisos de montaje y navegación. Su ejecución enfocada aislada no pudo iniciar: salida 1 porque el HOME aislado carecía de Hex (`Could not find an SCM for dependency :phoenix`). No se presenta como una segunda ejecución aprobada ni se reintentó.
- El usuario otorgó aprobación explícita del mock (ver registro arriba). No se atribuye al agente una comprobación visual/funcional en navegador que no realizó. La prueba ejecutable independiente sigue sin evidencia disponible; la suite propia aprobada no sustituye esa ejecución.

La futura conexión a backend deberá respetar el contrato económico, autorizar el detalle de pacientes, sustituir explícitamente los fixtures y verificar pagos/correcciones reales. Este prototipo no agrega una API financiera, una nueva operación de cobro ni una aprobación de integración.
