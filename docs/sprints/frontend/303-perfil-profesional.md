# #303: vista previa del perfil profesional

La pantalla prepara el frontend de [#303](https://github.com/Team-Origen/origen/issues/303) desde el [contrato aprobado de #301](../contracts/301-perfil-profesional.md). Usa datos ficticios y guardado sólo en memoria de la LiveView: **no guarda perfiles reales ni modifica reservas**. No completa #278 ni acredita la integración de #304.

## Recorrido local

1. En desarrollo, iniciar la aplicación con `mix phx.server`.
2. Ingresar con una cuenta Profesional activa y abrir `/configuracion/profesional`.
3. En la primera tarjeta, **Perfil profesional · Datos simulados**, revisar nombre, apellido y especialidad tal como se presentarían al Paciente. Seleccionar **Editar perfil** si la muestra tiene datos cargados, aun incompletos; **Completar perfil** corresponde a la muestra sin datos.
4. Editar los datos en `/configuracion/profesional/perfil` y seleccionar **Guardar cambios**. Los avances parciales se aceptan; el estado se calcula sobre el último guardado simulado.
5. **Cancelar** restaura el último guardado de esta visita. Salir, recargar o volver a entrar recupera la muestra inicial; no hay persistencia entre visitas.

La ruta y la tarjeta se compilan sólo para `:dev` y `:test`. No se habilitan en producción. La ruta conserva la autenticación y el rol Profesional del ámbito de Ajustes; la LiveView también exige ese rol al montar. No hay acceso de Secretaría o Administración a la pantalla.

## Orden de Ajustes

Por la última indicación de Santiago, el orden vigente es **perfil profesional → disponibilidad semanal de la agenda → tipos de consulta → intervalo de agenda → zona horaria**. Esta decisión reemplaza el orden anterior que colocaba Perfil después de Tipos de consulta. Intervalo y zona horaria quedan al fondo. Se conserva el orden en el documento y la navegación por teclado, no sólo mediante posiciones visuales CSS; no se cambian reglas ni valores de configuración.

## Qué revisar

| Área | Comportamiento de la muestra |
| --- | --- |
| Datos | Nombre, apellido, especialidad, tipo y número de matrícula; los cinco son necesarios para completar, no para guardar avances. |
| Resumen en Ajustes | La primera tarjeta muestra sólo nombre, apellido y especialidad en su proyección para pacientes; no incluye matrícula ni email. Los datos ausentes se indican como pendientes, sin inventar identidad o especialidad. Los requisitos faltantes se enumeran aparte para el Profesional. |
| Acción del resumen | Cualquier dato cargado ofrece **Editar perfil**, incluso en un perfil incompleto; una muestra totalmente vacía ofrece **Completar perfil**. El escenario enlazado al editor conserva la misma muestra. |
| Matrícula | Texto libre, sin catálogo, conversión numérica ni verificación de credenciales. |
| Completitud | Depende del último guardado exitoso; un borrador completo sin guardar no cambia el estado. Vacíos o espacios mantienen el perfil incompleto. |
| Foto | Nota opcional, sin input de archivo ni carga real. No bloquea completitud. |
| Errores | Carga fallida oculta el formulario; guardado fallido conserva el borrador y el estado previamente guardado. |
| Componentes | Petal existente: `container`, tipografía, `card`, `card_header`, `card_content`, `field`, `alert` y `button`. Esquemas de `field`, `card`, `alert` y `button` consultados en el MCP Petal v4.17.1. Sin biblioteca ni identidad visual nueva. |
| Ajustes | Intervalo, disponibilidad y catálogo conservan su comportamiento. No se cambia propiedad de cuenta ni se introduce el bloqueo adicional de reservas de Secretaría por perfil incompleto. |

Los controles de muestra del resumen permiten revisar `?scenario=empty`, `?scenario=incomplete`, `?scenario=complete` y `?scenario=load-error`. El editor también permite `?scenario=save-error`. Son respuestas locales de interfaz, no estados guardados de la cuenta autenticada. El aviso de simulación permanece visible durante todo el recorrido.

## Verificaciones observadas

Comandos ejecutados desde la raíz, sin `ORIGEN_DATABASE_URL` y con una partición exclusiva:

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue303_frontend \
  mix test test/origen_web/professional_profile_live_test.exs

env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue303_frontend \
  mix test test/origen_web/professional_profile_live_test.exs \
  test/origen_web/professional_availability_live_test.exs \
  test/origen_web/consultation_type_catalog_live_test.exs

env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue303_frontend mix test
```

- **RED:** primera ejecución de perfil, antes de implementar ruta y pantalla: exit **2**, **13 fallos**.
- Primer intento de GREEN detenido en compilación por uso de `Application.compile_env` dentro de `mount`; se corrigió llevándolo a un atributo de módulo.
- **GREEN y regresión de Ajustes:** exit **0**, **84 aprobadas**, seed `208593`.
- **Suite general:** exit **0**, **691 aprobadas**, **29 skipped**, **8 excluded**, seed `677538`. ExUnit excluyó `postgres_security`; no se atribuye verificación de esos casos.
- **Verificación independiente:** mismo archivo de perfil con `MIX_TEST_PARTITION=_issue303_verify`: exit **0**, **13 aprobadas**, seed `70196`; sin blockers de código reportados.
- Exclusión de la ruta y tarjeta en producción comprobada por lectura de la configuración y las condiciones de compilación; no se ejecutó una compilación de producción.
- **Comprobación visual pendiente:** posteriormente se conectó el navegador a Tidewave, pero la ruta respondió `Unauthorized`. Se dejó el navegador en `/login`; falta ingresar con una cuenta Profesional activa para revisar la pantalla. No se afirma revisión visual ni aprobación de esta entrega.

Las pruebas de LiveView cubren navegación, cinco campos individualmente incompletos, texto libre, ausencia de foto, guardado completo/parcial, distinción entre borrador y estado guardado, cancelación, ausencia de persistencia entre visitas y fallos de carga/guardado. Observan también los rechazos HTTP 401 para anónimos y 403 para Secretaría/Administración.

## Historial de verificación del primer reorden de Ajustes

Se agregó una prueba que comprueba el orden de encabezados en el HTML público. El primer intento usó Floki, no disponible en este proyecto; se corrigió sin agregar dependencias. RED observado por orden incorrecto: exit **2**, **1 fallo**. Las pruebas de regresión detectaron además que la composición reiniciaba el editor y ocultaba secciones cuando fallaba disponibilidad: se corrigieron preservando el borrador en actualizaciones de presentación y manteniendo las otras secciones independientes del error de carga. Resultados finales: **85 pruebas focalizadas aprobadas**, exit **0**, seed `485657`; incluyen los dos archivos de Ajustes y las 13 pruebas de perfil. Suite general posterior: **692 aprobadas**, **29 skipped**, **8 excluded**, exit **0**, seed `6363` (se excluye `postgres_security`). Verificación independiente del reorden sobre los dos archivos de Ajustes: **72 aprobadas**, exit **0**, seed `763351`, sin blockers; la diferencia de conteo corresponde a no incluir las 13 pruebas de perfil. Formato y `git diff --check` correctos. La revisión visual sigue pendiente de inicio de sesión en el navegador conectado.

## Verificación del resumen y orden vigente

La última corrección del usuario coloca Perfil primero y agrega la proyección para pacientes a la tarjeta. Se reutilizan fixtures en `lib/origen_web/live/professional_profile_preview.ex`, sin persistencia ni contexto de dominio real.

- **RED:** exit **2**, **6 fallos** de los 18 casos seleccionados por falta del nuevo resumen, acciones y orden.
- **GREEN y regresión:** los tres archivos focalizados del comando anterior, exit **0**, **89 aprobadas**, seed `380030`.
- **Suite general posterior:** exit **0**, **696 aprobadas**, **29 skipped**, **8 excluded**, seed `955587`. `postgres_security` sigue excluido.
- **Verificación independiente:** perfil y disponibilidad, partición `_issue303_summary_verify`, exit **0**, **36 aprobadas**, seed `937941`. Confirmó funcionalidad, privacidad del resumen y permisos; señaló como único blocker el orden desactualizado de esta guía, corregido en la sección de orden vigente y recorrido local.
- La revisión visual continúa pendiente de inicio de sesión Profesional en el navegador conectado. Los fixtures no acreditan que los cambios guardados en el editor persistan al volver a Ajustes.

## Entrega en stack

- Primer corte: [PR #330](https://github.com/Team-Origen/origen/pull/330), rama `feat/303-settings-order` hacia `develop`; preparación en borrador con `Refs #303`. Su validación remota de referencia de issue falló porque el CI sólo acepta referencias de cierre. No se modifica CI ni se declara completada la issue desde ese corte.
- Segundo corte: rama `feat/303-profile-screen` sobre `feat/303-settings-order`, entrega este perfil mock y declara `Closes #303`. Sólo después de integrar el primer corte corresponde retargetearlo a `develop` y verificar de nuevo el diff; no se hace merge automáticamente.
- Suite aislada del primer corte: exit **0**, **679 aprobadas**, **29 skipped**, **8 excluded**, seed `230912`.
- Suite aislada de este segundo corte con `MIX_TEST_PARTITION=_issue303_stack_profile`: exit **0**, **696 aprobadas**, **29 skipped**, **8 excluded**, seed `797311`. `postgres_security` quedó excluido. Se observó una advertencia de redefinición de un módulo de migración, sin fallo.
- El código de aplicación y las pruebas de este corte se compararon byte a byte con el árbol aprobado y previamente verificado; son idénticos. Los cortes conservan sus pruebas y documentación. Santiago aprobó el exceso de tamaño sin eliminar contenido ni comprimir código.
- No se incluye el archivo ajeno `odd/tasks/gentle-pi-wsl-setup.md`, configuración local ignorada ni credenciales. Se conserva el árbol de trabajo original.

## Pendientes para integración

- Conectar carga y guardado reales de #302 a la identidad autenticada; no convertir este fixture en un contexto de dominio paralelo.
- Resolver almacenamiento, validaciones y exposición de foto antes de implementar su carga.
- Verificar autorización de dominio, persistencia y proyección real para pacientes en #302/#304. Los fixtures de #303 no prueban esos requisitos.
- Aprobación explícita de esta interfaz registrada por Santiago: «esta arobado, nos queda algo por hacer o podemos ya hacer el stack de prs». La revisión visual automatizada sigue pendiente del inicio de sesión Profesional; no se convierte la aprobación humana en una comprobación de navegador ejecutada.
