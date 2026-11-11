# Issue #472 — Relocación de Solicitudes y aprobación

Se trasladan controles existentes, sin rediseñar Solicitudes ni Ajustes y sin modificar las reglas de negocio. Referencia: [#472](https://github.com/Team-Origen/origen/issues/472).

## Destinos y componentes

| Destino | Componentes y comportamiento |
| --- | --- |
| `/profesional/solicitudes` | Nueva ubicación de los controles existentes de aceptar/rechazar y sus mensajes. Reutiliza `AgendaAppointmentCard`, las clases de las tarjetas y los botones de Agenda. Muestra identificación del paciente, fecha y hora de cada turno, tipo de consulta y estado solicitado. |
| `/profesional/ajustes` | Recibe el panel `approval-config-panel` y el formulario `approval-config-form`, incluidos ambos selectores y el aviso de alcance, con su presentación existente, inmediatamente debajo de Tipos de consulta y antes de Intervalo de Agenda. Conserva las demás configuraciones y el acceso al perfil. |
| `/profesional/agenda` | Conserva turnos y estados, navegación por fecha, creación, cancelación con motivo, asistencia/ausencia e historial. No duplica la resolución ni la configuración trasladadas. Las capacidades de acceso del paciente se conservan a nivel de aplicación; el botón de reemplazo se oculta solo de la tarjeta según la aclaración visual. |
| `/secretaria/pacientes` | Conserva búsqueda, registro y reserva asistida. Cambia los colores mediante un límite local de tema claro y el tamaño del título; aplica además el ocultamiento visual acotado del resumen del paciente detallado debajo. |

Solicitudes usa la consulta dedicada `Booking.list_professional_pending_requests/1`: sesión revalidada, cuenta profesional propia y estado `requested`, sin límite diario, orden por `start_time` e `id` ascendente. Conserva las tarjetas y acciones; cada tarjeta muestra fecha y hora en la zona horaria de la organización. Se retiran el calendario y los controles diarios solo de Solicitudes. Un parámetro `date` heredado se ignora, no filtra ni produce un error de fecha. Agenda mantiene intactos su consulta diaria, controles y `?date=AAAA-MM-DD`. No se agregan filtros ni paginación. La navegación usa el indicador de carga compartido de LiveView y se conservan error con reintento y listado vacío.

El historial en `/paciente/turnos` se presenta del turno más reciente al más antiguo (fecha/hora e ID descendentes). El orden se aplica únicamente en `PatientAppointmentsLive`; `Booking.list_appointment_history/1` conserva su contrato y no cambia el historial de otros roles.

La ruta de Solicitudes utiliza el mismo pipeline y `live_session` con `ensure_professional` que Agenda. Aceptar y rechazar siguen delegando a `Booking.accept_request/2` y `Booking.reject_request/2`. Las solicitudes ajenas o ya procesadas se rechazan mediante el contrato existente y se vuelve a consultar el listado. Los resultados se ven al volver a consultar Agenda; no se introduce sincronización en tiempo real entre pestañas.

La modalidad conserva `Booking.update_approval_configuration/2`. Solo afecta reservas nuevas; las solicitudes pendientes existentes conservan su estado y ocupación. Secretaría no recibe acceso a ajustes ni resolución.

## Inventario de botones y coordinación con #471

- **Solicitudes del Profesional:** se reemplaza su comportamiento de aviso sin destino por el enlace funcional. Se marca activa en su pantalla.
- **Aceptar/Rechazar y selectores de aprobación en Agenda:** retirados únicamente de esa ubicación, porque ahora están disponibles en Solicitudes y Ajustes respectivamente.
- **Pacientes del Profesional:** no existe una entrada en la navbar de la base `61a9f35`; no se elimina ni se inventa un destino. Su futura incorporación al listado de [#471](https://github.com/Team-Origen/origen/issues/471) queda pendiente de que ese recorrido esté disponible. La selección de paciente en `/profesional/agenda/crear` se conserva.
- **Pacientes de Secretaría:** se conserva porque `/secretaria/pacientes` funciona y es necesario para operaciones asistidas. #471 deberá coordinar su convivencia o conexión al nuevo listado sin perder búsqueda, registro ni reserva asistida.
- **Agenda, Resumen económico, Ajustes, perfil, creación y cierre de sesión:** conservados; no se identificaron otros botones sin función en las navbars afectadas. No se retiran accesos activos para completar una limpieza nominal.

## Colores y título de Secretaría

Aclaración del usuario: usar colores institucionales y achicar un poco el título; no cambiar el formato restante.

- Antes, el contenedor heredaba el tema y podía aplicar el fondo oscuro `dark:bg-gray-950`; el título usaba los tamaños predeterminados de Petal (`text-4xl sm:text-5xl lg:text-6xl`). Esto es evidencia de código, **no una reproducción visual del defecto**.
- Ahora, el contenedor tiene `data-theme="light"` local, igual que Ajustes, y fondo institucional blanco (`bg-surface`). Reutiliza las rampas primarias/secundarias existentes, sin cambiar CSS global ni crear un tema.
- El título sigue siendo `h1`, un tamaño menor por breakpoint: `text-3xl sm:text-4xl lg:text-5xl`.
- Se conservan los colores semánticos de éxito, advertencia y error, así como todos los formularios, tarjetas, campos, espaciados y recorridos.
- Referencia de identidad: [visual-design-system.md](../visual-design-system.md).

## Aclaración posterior: limpieza visual de tarjetas de pacientes

Autorizada después del traslado inicial. En la tarjeta del paciente de Agenda del Profesional y en el resumen de búsqueda/reserva asistida de Secretaría se ocultan **solo**:

1. La etiqueta y el valor del teléfono.
2. El indicador **Acceso verificado**, únicamente cuando el acceso está verificado. Los estados **Sin acceso** y **Pendiente de verificación** se conservan.
3. El botón **Reemplazar correo** / **Reemplazar correo de acceso**.

Se mantienen nombre, documento, correo y demás información del turno/paciente; en Agenda también horarios, tipo y estado del turno y sus demás operaciones. No se ocultan las etiquetas diferentes **Teléfono verificado/no verificado**, el campo de teléfono necesario para registrar una persona, ni el botón para vincular un correo cuando no existe. No se alteran otras pantallas.

El cambio se limita a las plantillas. No borra datos ni cambia funciones, permisos o validaciones: consulta de teléfono, verificación y reemplazo de correo siguen disponibles a nivel de aplicación. Los handlers y formularios existentes se conservan para su reutilización; el ocultamiento no concede ni revoca autorización. Las pruebas de regresión invocan los eventos LiveView públicos de reemplazo sin depender del botón retirado y siguen comprobando efectos, validaciones y correo enviado. Las pruebas nuevas comprueban la ausencia de los tres elementos y consultan los datos/estado por las APIs existentes. #471 decidirá la ubicación definitiva sin bloquear esta corrección.

## Enlaces locales para revisión manual

En la sesión anterior, `http://localhost:4000/login` respondió HTTP 200; no se volvió a comprobar su disponibilidad en esta sesión. Iniciar sesión con el rol correspondiente antes de abrir cada destino:

- [Solicitudes del Profesional](http://localhost:4000/profesional/solicitudes)
- [Ajustes del Profesional](http://localhost:4000/profesional/ajustes)
- [Agenda del Profesional](http://localhost:4000/profesional/agenda)
- [Mis turnos del Paciente](http://localhost:4000/paciente/turnos)
- [Buscar paciente y hacer turno — Secretaría](http://localhost:4000/secretaria/pacientes)

Para ver las tarjetas, usar una fecha con turnos ficticios en Agenda y buscar un paciente ficticio existente en Secretaría. Los enlaces no saltan los permisos ni constituyen evidencia de revisión visual.

## Verificación y límites de evidencia

- RED inicial de traslado: 11 fallos de 43 pruebas, salida 2, por los destinos/controles todavía no trasladados.
- GREEN funcional: 60 pruebas aprobadas de Agenda, navegación, ciclo y aprobación integrada. Cubre resolución obsoleta, eventos forjados sobre solicitudes ajenas, liberación/ocupación de horarios, cambios de modalidad solo para reservas nuevas y rechazo de roles no autorizados.
- RED visual estructural: falla la aserción del límite local de tema antes del cambio, salida 2. GREEN: 36 pruebas de búsqueda y mantenimiento de acceso aprobadas.
- Primera suite completa aislada: 1112 de 1113 aprobadas, 32 omitidas y 8 excluidas; la prueba restante todavía intentaba aceptar desde Agenda. Se actualizó para resolver desde Solicitudes y consultar nuevamente Agenda, conservando sus aserciones de auditoría y recarga del Paciente.
- Suite completa final: `MIX_TEST_PARTITION=_issue472 mix test`, **1113 aprobadas, 32 omitidas y 8 excluidas**, salida 0. El log contiene una advertencia de API de compatibilidad deprecada y un mensaje de ownership del Sandbox; no hubo pruebas fallidas. No se atribuyen esos mensajes a una causa confirmada ni se ocultan.
- `mix assets.build`, formato de archivos modificados y `git diff --check`: aprobados. Los archivos compilados no agregan cambios versionados.
- Ampliación visual de tarjetas: RED de 12 fallos/80 pruebas, salida 2; GREEN inicial de 80/80, salida 0. La primera suite completa de esta ampliación tuvo 1113/1114 aprobadas: una prueba del recorrido prototipo todavía esperaba teléfono en la tarjeta. Se adaptó para seguir comprobando teléfono conservado en la API y ahora ausente del HTML. Ejecución focalizada posterior: **85/85 aprobadas**, salida 0; incluye conservación de datos, estado de acceso verificado, estados no verificados, vinculación, reemplazo, validaciones, registro, resumen y reserva asistida. Build de assets, formato y `git diff --check` aprobados. Suite completa final de la ampliación: **1114 aprobadas, 32 omitidas y 8 excluidas**, salida 0 (`MIX_TEST_PARTITION=_issue472 mix test`). El log vuelve a incluir texto de ownership del Sandbox sin fallos de pruebas; no se atribuye a una causa confirmada.
- La comprobación independiente no estuvo disponible: el subagente falló al iniciar. No se presenta como revisión aprobada.
- Navegador: Tidewave informó que no hay un navegador conectado. Las capturas antes/después y la comprobación visual en escritorio/móvil **no están realizadas**. Las pruebas de DOM no sustituyen esa evidencia. Usar exclusivamente datos ficticios al completarla.

### Ampliación autorizada del handoff

- Solicitudes generales: RED funcional de 2/2 fallos (salida 2), seguido de GREEN **37/37** pruebas de Agenda/Solicitudes. Una versión inicial de las pruebas usó Floki, no instalado; se corrigió sin agregar dependencias antes del RED funcional.
- Historial del Paciente: RED de 1/1 fallo sobre el orden del HTML; GREEN **5/5**, conservando las pruebas de cancelación, aislamiento y el orden ascendente de la API pública.
- Ubicación de aprobación: RED de 1/1 fallo por posición; GREEN conjunto de **44/44** pruebas de Agenda/Solicitudes/catálogo/aprobación. Se verifican hermanos DOM contiguos, guardado de configuración y conservación de solicitudes pendientes; esto no reemplaza revisión visual.
- Suite completa posterior a los tres ajustes: `MIX_TEST_PARTITION=_issue472 mix test`, **1115 aprobadas, 32 omitidas, 8 excluidas**, salida 0. El log conserva mensajes de ownership de Sandbox; no se afirma una causa ni un log limpio.
- `mix assets.build`: salida 0. RDD continúa desactivado; no se habilitó ni se abrió una transacción nativa.
- Capturas y revisión visual escritorio/móvil, y verificación independiente: siguen **pendientes/no disponibles** según el handoff. No se reintentaron los agentes fallidos ni se presenta autoinspección como aprobación independiente.
