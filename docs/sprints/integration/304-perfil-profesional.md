# #304: integración real del perfil profesional

El editor y la tarjeta de Ajustes usan el perfil persistido de la cuenta autenticada mediante `Origen.ProfessionalProfiles`. Reemplazan la simulación de [#303](../frontend/303-perfil-profesional.md), respetando el [contrato #301](../contracts/301-perfil-profesional.md) y el [backend #302](../backend/302-perfil-profesional.md).

## Recorrido

1. Ingresar con una cuenta Profesional activa y abrir `/configuracion/profesional`.
2. Seleccionar **Ver perfil**. El resumen privado de Ajustes muestra nombre y apellido, especialidad y, junto a ella, tipo y número de matrícula.
3. `/configuracion/profesional/perfil` abre primero en **modo lectura**, con los últimos datos guardados. Los campos ausentes aparecen como pendientes.
4. Seleccionar **Completar perfil** mientras falte cualquiera de los cinco campos requeridos, o **Editar perfil** sólo cuando los cinco estén completos. Ambas acciones abren el formulario dentro del mismo perfil; no hay un recorrido aparte de credenciales de acceso.
5. Editar nombre, apellido, especialidad, tipo y número de matrícula y seleccionar **Guardar cambios**. Se permiten avances parciales. Un guardado exitoso vuelve a lectura; si sólo se completó la matrícula y todavía faltan otros datos, la acción sigue siendo **Completar perfil**, también al volver desde Ajustes.
6. **Cancelar** descarta el borrador y vuelve a lectura con el último guardado exitoso. Salir y volver o recargar conserva los datos persistidos.

La ruta y la tarjeta están habilitadas en todos los entornos, conservando la autenticación y el rol Profesional. `?scenario=...` ya no selecciona muestras. Se mantiene el orden perfil → disponibilidad semanal → tipos de consulta → intervalo → zona horaria.

## Datos y errores

- Los campos `license_type` y `license_number` coinciden con el backend; son textos libres, sin catálogo ni verificación externa.
- El estado completo/incompleto se calcula sobre el último guardado exitoso, no sobre el borrador. Vacíos y espacios se guardan como ausencia de dato.
- El resumen **privado del propio Profesional** muestra nombre, apellido, especialidad y matrícula. La proyección **pública para el Paciente** sigue mostrando únicamente identidad estable de cuenta, nombre y especialidad: no se publica matrícula ni email.
- La acción **Completar perfil** depende de los cinco campos guardados, no de que exista una fila, tenga algún dato o ya se haya guardado la matrícula. Un borrador completo sin guardar no habilita **Editar perfil**.
- En lectura no se muestra el formulario y se ignoran los eventos de cambio/guardado; se entra explícitamente en edición desde el propio perfil.
- Un fallo de carga oculta datos y edición del perfil, sin bloquear las otras secciones de Ajustes. Un fallo de guardado conserva el borrador y el estado guardado anterior.
- La identidad propietaria viene de la sesión autenticada, nunca de parámetros del cliente. El contexto revalida sesión, rol, estado y propiedad en cada operación.
- Foto opcional y carga diferida: no se agrega input de archivo, almacenamiento ni exposición. Sin cambios en reservas asistidas de Secretaría.

## Evidencia histórica inicial del editor y Ajustes

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue304_integration \
  mix test test/origen_web/professional_profile_live_test.exs \
  test/origen_web/consultation_type_catalog_live_test.exs \
  test/origen_web/professional_availability_live_test.exs
```

- RED del editor real: exit 2, 15 fallos entre 16 casos antes del cambio.
- GREEN y regresiones de Ajustes: exit 0, 88 aprobadas, seed `877311`.
- Las pruebas cubren persistencia entre visitas, cada campo requerido ausente, matrícula libre, estado guardado frente a borrador, cancelación, errores de carga/guardado y rechazo tras revocación de sesión. La configuración existente sigue cubierta por sus pruebas de regresión.
- No se ejecutó compilación de producción; la eliminación de la condición dev/test en la ruta se verifica estructuralmente.

## Catálogo y reserva reales

Desarrollo y producción usan `DatabaseCalendar` y `ConsultationTypes.DatabaseCatalog`; ya no dependen del calendario simulado ni de adaptadores ausentes. La configuración de pruebas conserva sus mocks explícitos para regresiones históricas, mientras las pruebas de integración seleccionan los adaptadores reales. No se agregan dependencias ni migraciones.

El nuevo catálogo devuelve sólo identidad de consulta, nombre, cantidad de intervalos, precio y estado activo; no devuelve ajustes privados completos. El calendario toma duración e intervalo persistidos, muestra nombre/especialidad declarados y no inventa consultas ni precio cuando el catálogo está vacío o falla. En esos casos muestra un estado vacío/error y no ofrece slots ni confirmación. Un Profesional completo puede estar listado aunque todavía no tenga consultas o disponibilidad; listado no equivale a turno reservable.

### Recorrido automatizado observado

`professional_profile_integration_test.exs` usa formularios/eventos reales: cambia intervalo a 20 minutos mediante revisión y confirmación; crea consulta de 3 intervalos (60 minutos) a ARS 21.500,50; guarda horarios, horizonte de 14 días y anticipación de 60 minutos aun con perfil incompleto; completa los cinco datos sin foto; recarga el resumen y reserva desde el calendario de un Paciente con teléfono verificado mediante la API pública. Luego borra especialidad, verifica exclusión del siguiente listado y conservación del catálogo/disponibilidad.

El recorrido prueba también catálogos vacío/no disponible y propietario ajeno manipulado. La consulta persistida se comprueba además por su interfaz pública, con rechazos de referencias inválidas sin mutaciones. No se afirma que una prueba de dominio sea una comprobación visual.

- RED del recorrido/catálogo: exit 2, 4 fallos entre 5 casos; incluía un selector de prueba incorrecto, corregido.
- Primer GREEN: exit 2, 16/18 aprobadas. Se corrigió la preparación de controles de fin de semana en la prueba y la expectativa histórica que dependía de inventar una consulta al faltar catálogo.
- GREEN posterior: exit 0, 18 aprobadas, seed `571301`, incluyendo regresiones del calendario y adapter mock.

## Verificación propia inicial

- Suite focalizada ampliada (12 archivos de perfil, integración, catálogo, disponibilidad, autorización y calendario): exit 0, **184 aprobadas**, seed `828879`.
- Suite completa con `env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue304_integration mix test`: exit 0, **713 aprobadas, 29 skipped, 8 excluded**, seed `979652` (26,8 segundos). Las pruebas `postgres_security` quedaron excluidas por la configuración existente; no se atribuye su ejecución.
- `mix format --check-formatted`, `git diff --check` y `python3 -m unittest discover -s test/ci -p 'test_*.py'`: exit 0; Python ejecutó 3 pruebas.
- Lectura efectiva de `config/dev.exs` y `config/prod.exs` mediante `Config.Reader`, sin iniciar aplicación: exit 0; ambos seleccionan calendario/catálogo reales y demo deshabilitada. Esto no equivale a un build ni despliegue de producción.
- La validación de mapas/listas malformados se mantiene en el dominio y se comprueba sin mutaciones de perfil/catálogo/disponibilidad. Una expectativa inicial incorrecta de la prueba se corrigió: LiveView serializa números a texto y el texto libre numérico es válido; no se presenta ese fallo de prueba como defecto funcional.

## Verificación independiente inicial y límites de cierre

El verificador independiente ejecutó una sola vez los mismos 12 archivos en una copia temporal **sin worktree**, con `MIX_TEST_PARTITION=_issue304_independent`: **exit 0, 184 aprobadas**, seed `234713` (6,4 segundos de ExUnit). No reportó defectos funcionales bloqueantes. No duplicó la suite general ni ejecutó `postgres_security`.

Su `mix format --check-formatted` **agotó 30 segundos y no produjo veredicto**. Al ejecutarlo sin `MIX_ENV=test` en una copia que sólo tenía build de test, comenzó a compilar dependencias de desarrollo. No se reintentó ni se presenta como aprobación independiente de formato; la ejecución propia de formato anterior sí terminó con exit 0. No se ejecutó build de producción.

El coordinador comprobó antes de implementar los blockers nativos de #304: #301, #302 y #303 cerradas; #278 sin blockers. Las aprobaciones previas están documentadas en el contrato, guía frontend y comentario de cierre de #302. El verificador local no consultó GitHub de nuevo, por lo que no se atribuye una segunda comprobación externa independiente.

En el intento inicial de navegador no había proceso escuchando en `http://localhost:4000/tidewave/mcp`. Para el nuevo flujo de lectura se hizo una nueva comprobación aplicable: la aplicación ya responde, pero Tidewave informó que **no hay navegador conectado** y pidió abrir `http://localhost:4000/tidewave`. No se reintenta automáticamente ni se afirma comprobación visual. Las pruebas LiveView no sustituyen esta evidencia.

La limpieza de la copia del verificador fue denegada por el harness. Permanece únicamente `_build/issue304-verify.rF34oU`, ignorada por Git y sin ser un worktree; no se intentó borrarla por otra vía. `test/ci/__pycache__/` es un artefacto sin seguimiento de las pruebas Python, no parte de la entrega. Los cuatro documentos ODD preexistentes se preservan sin cambios.

**Pendiente humano:** conectar un navegador a `http://localhost:4000/tidewave` para la revisión visual autenticada. El timeout del formato independiente anterior permanece como antecedente, no como éxito ni comprobación del candidato nuevo. La copia temporal anterior debe limpiarse sólo sobre la ruta exacta indicada, con autorización/acción humana compatible con el harness.

## Cambio vigente: perfil en lectura y edición centralizada

A pedido de Santiago, **Ver perfil** reemplaza la acción de edición en Ajustes. El perfil ofrece **Completar perfil** hasta que estén completos nombre, apellido, especialidad, tipo y número de matrícula, y **Editar perfil** sólo después. «Credenciales» fue aclarado como esta misma pantalla, no contraseña, segundo factor ni otra pantalla de acceso.

- RED del nuevo flujo: exit 2, 13 fallos entre 24 casos.
- GREEN del perfil: exit 0, **24 aprobadas**, seed `485466`.
- Regresión ampliada del nuevo flujo (perfil, integración real, catálogo, disponibilidad, calendario Paciente y contexto de perfil): exit 0, **114 aprobadas**, seed `219639`.
- Las pruebas cubren lectura inicial, edición explícita, guardado/cancelación a lectura, cinco requisitos ausentes por separado y primer guardado exclusivo de matrícula seguido de reingreso desde Ajustes. El recorrido real conserva la matrícula sólo en las vistas privadas, no en el calendario del Paciente.
- Suite completa del nuevo flujo con `MIX_TEST_PARTITION=_issue304_readflow`: exit 0, **720 aprobadas, 29 skipped, 8 excluded**, seed `410496` (30,5 segundos). `postgres_security` sigue excluido.
- `MIX_ENV=test mix format --check-formatted`, `git diff --check` y Python CI (3 pruebas, con `PYTHONDONTWRITEBYTECODE=1`): exit 0.
- Verificación independiente del candidato nuevo: la misma regresión de seis archivos, en la partición aislada `_issue304_readflow_independent`, terminó con **exit 0, 114 aprobadas**, seed `111327` (7,3 segundos). `MIX_ENV=test mix format --check-formatted` independiente terminó con **exit 0**, sin salida. No se reportaron defectos bloqueantes ni recomendaciones adicionales. No se creó otra copia ni worktree; los datos de prueba quedaron aislados mediante sandbox SQL.
- Tidewave no tuvo un navegador conectado en el intento aplicable y no se reintentó; eso queda registrado como límite de herramienta, no como revisión visual atribuida a las pruebas.
- El 2026-10-23, Santiago aprobó explícitamente las pruebas manuales. Esta aprobación cubre el criterio humano pendiente de la integración; no transforma la falta de conexión de Tidewave en evidencia observada.
- Los cambios y sus pruebas permanecen sin commit. Los resultados del candidato nuevo no convierten el timeout histórico del formato anterior en un éxito retroactivo; ese antecedente se conserva arriba.

RDD está deshabilitado. La aprobación humana final de #304/#278 fue registrada para esta integración; crear commits, push, PRs y cierres en GitHub son decisiones separadas. No se hicieron commits, push, PRs, cierres ni publicaciones. Riesgo: frontera de autorización del perfil y configuración de adaptadores dev/prod (items 2 y 5); se conservaron las reglas de Secretaría.
