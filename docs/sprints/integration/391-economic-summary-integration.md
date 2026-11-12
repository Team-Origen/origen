# Integración del resumen económico — #391

Integra la entrega de #288 conforme al [contrato #388](../contracts/388-resumen-economico-por-fecha-turno.md) y a OpenSpec `health-center-beta-core`, sección `payments-and-period-summary`.

## Implementación

- `EconomicSummaryLive` consulta `Origen.Booking.economic_summary/3`; no calcula elegibilidad ni duplica agregados financieros.
- Profesional: usa la cuenta de la sesión vigente y consulta únicamente su propio resumen.
- Secretaría: selecciona un Profesional activo de la fuente real `DatabaseCalendar`, sin opción global ni selección múltiple.
- Mes y rango inclusivo se validan en el backend. Los importes `Decimal` ARS se presentan como Pagado, Pendiente y Total considerado.
- Se retiraron profesionales, importes y detalle de pacientes ficticios. El backend agregado no ofrece un listado de pacientes.
- Se conservan las rutas `/profesional/resumen-economico` y `/secretaria/resumen-economico` y sus enlaces en la navbar. Administrador no tiene acceso.

## Dependencias de inicio

#388 y #390 tienen aprobación explícita documentada. La integración de pagos #287 está disponible mediante #387 y sus PRs fusionadas. El responsable aprobó explícitamente el backend #389 antes de iniciar #391. Estas aprobaciones no equivalen a la aceptación final de #391.

## Pruebas reproducibles

Usar PostgreSQL descartable, con `btree_gist`, y dependencias ya instaladas. Exportar **antes de crear/migrar la base**:

```sh
export MIX_ENV=test
export PGHOST=127.0.0.1 PGPORT=<puerto-aislado> PGUSER=<usuario-de-pruebas>
export PGDATABASE=<base-descartable>
export ORIGEN_DATABASE_URL="ecto://$PGUSER@$PGHOST:$PGPORT/$PGDATABASE"
mix ecto.create
mix ecto.migrate

mix test test/origen_web/live/secretary_agenda_live_test.exs \
  test/origen_web/live/economic_summary_live_test.exs \
  test/origen_web/live/economic_summary_integration_test.exs \
  test/origen/booking/economic_summary_test.exs \
  test/origen/booking/economic_summary_period_test.exs \
  test/origen/booking/authorization_test.exs --seed 391
mix test test/origen/booking/*payment*.exs --seed 391
mix test --seed 391
```

`PGDATABASE` debe coincidir con la URL: algunas pruebas de bootstrap abren conexiones propias. No utilizar la base de desarrollo ni producción.

Resultados propios posteriores a la corrección, sobre PostgreSQL 18.6 descartable y semilla 391:

| Comprobación | Resultado | Salida |
|---|---|---|
| Conjunto focalizado anterior (incluye Secretaría) | 68 aprobadas, 0 fallidas | 0 |
| Pagos | 35 aprobadas, 3 omitidas | 0 |
| Suite completa | 1189 aprobadas, 35 omitidas, 8 excluidas | 0 |
| Compilación, formato y `git diff --check` | Aprobados | 0 |

Las omitidas/excluidas no se presentan como verificadas. Persisten advertencias ambientales de OTP 28.0 y mensajes de ownership del SQL Sandbox/`ExpiryWorker`; no hubo pruebas fallidas. Además, una verificación independiente ejecutada sobre otra base PostgreSQL descartable aprobó las mismas 68 pruebas focalizadas y 35 de pagos (3 omitidas), formato, compilación y `git diff --check`, todos con salida 0.

## Diagnóstico del fallo de Secretaría

La prueba `shows real patient and corresponding professional names without visible appointment IDs` creaba turnos a partir de `DateTime.utc_now()` y una hora después, pero abría la agenda del día actual. Después de las 23:00, el segundo turno cae al día siguiente y falla la búsqueda del paciente en la agenda actual.

Se compararon la base `ed30b05` y el cambio, con bases aisladas equivalentes y semilla 391: ambas aprobaron 9/9 al ejecutarse fuera del límite diario. En copias temporales se fijó el inicio a las 23:30 del día actual: ambas reprodujeron el mismo fallo en `has_element?(view, selector, "Juan Pérez")`, código de salida 1. Por tanto, es un fixture preexistente sensible al reloj, no una regresión introducida por el resumen.

La corrección conserva todas las aserciones y sitúa ambos turnos a las 09:00 y 10:00 del día de la organización, convertidos a UTC. No modifica lógica de producción ni elimina cobertura.

## Estado de verificación y límites

- Las pruebas de integración usan sesiones, perfiles, turnos y pagos persistidos en PostgreSQL, no el catálogo de importes ficticios del prototipo.
- Los intentos independientes anteriores se detuvieron antes de ExUnit por preparación del entorno y se conservan como fallidos, no como pruebas aprobadas. El nuevo intento usó una base ya migrada y el entorno comprobado; ejecutó y aprobó las pruebas indicadas arriba.
- Se preparó Hex 2.4.0 desde su fuente oficial, tag `v2.4.0`, commit `fa621312067a6c4453d30415ed928f0957afd5d2`, compilado con Elixir 1.20.3/OTP 28 en un directorio temporal. No se modificaron herramientas globales ni dependencias del proyecto. La disponibilidad de herramientas no sustituye el dictamen independiente.
- Se completó el recorrido de navegador detallado abajo en una instancia Phoenix y una base PostgreSQL separadas, sin datos de desarrollo. Las cuentas y perfiles temporales son preparación de prueba; los turnos se crearon mediante `BookingService.reserve/2` y se aceptaron, pagaron y cancelaron mediante operaciones públicas de Booking, sin insertar filas de turnos o pagos manualmente. La reconsulta de pagos se verificó en navegador; la marca y su reversión se ejecutaron mediante la API pública real, no mediante clics en el diálogo de pagos.
- La primera sesión se interrumpió al vencer el límite de ejecución de PostgreSQL. Con autorización explícita posterior se reactivaron sólo los servicios temporales y se completaron los recorridos restantes, sin repetir las suites aprobadas. El timeout se conserva como interrupción ambiental, no como prueba aprobada. La aprobación humana explícita se registra al final de este documento.
- Riesgo: item 2, autorización de sesión y selección de Profesional para importes financieros. La verificación independiente aprobó alcance propio, selección de Secretaría, rechazo de IDs forjados, revocación de sesión y denegación administrativa. No se encontraron defectos bloqueantes en el alcance verificado. La aceptación humana final no se deduce de los resultados técnicos.

## Evidencia de navegador real

Se usó el inicio de sesión real con contraseña y TOTP; no se fabricaron cookies ni se omitió la autenticación. Dos intentos iniciales fueron rechazados; el ingreso funcionó con el código de la ventana TOTP vigente. Las credenciales temporales no forman parte de esta documentación.

| Recorrido | Resultado observado |
|---|---|
| Profesional: login y acceso desde la navbar | Ingreso a Agenda y clic en Resumen económico, sin escribir su URL manualmente. Identidad propia, sin selector de otro Profesional. |
| Resumen mensual de noviembre de 2026 | Pagado ARS 18.000,00; Pendiente ARS 18.000,00; Total considerado ARS 36.000,00. El pagado provenía de un turno pagado y luego cancelado; un solicitado impago no se sumó. |
| Rango inclusivo del 17/11/2026 al mismo día | Mismos tres importes y período visible de un día. |
| Rango invertido | No sustituyó el resultado anterior. No se atribuye un mensaje de error que no se observó en el snapshot. |
| Día vacío, 18/11/2026 | Tres importes cero y estado explícito de período sin turnos elegibles. |
| Secretaría: login y acceso desde la navbar | Ingreso real; resumen inicialmente sin importes y selector con dos Profesionales activos y opción de limpiar, sin opción global. |
| Secretaría: selección de Profesional A | ARS 18.000,00 pagados; ARS 18.000,00 pendientes; ARS 36.000,00 total. |
| Secretaría: alternancia a Profesional B y regreso a A | B mostró ARS 22.000,00 pagados; ARS 0,00 pendientes; ARS 22.000,00 total, sin los importes de A. Volver a A restituyó sus importes. |
| Secretaría: limpiar selección | Desaparecieron los importes y volvió la indicación de seleccionar un Profesional. |
| Reconsulta después de registrar pago | `Booking.record_payment(principal, appointment_id, :cash)` sobre el confirmado impago; cambiar al mes anterior y volver en la UI mostró ARS 36.000,00 pagados, ARS 0,00 pendientes y ARS 36.000,00 total para A. |
| Reconsulta después de corregir la marca | `Booking.revert_payment(principal, appointment_id, true)`; la misma reconsulta en la UI devolvió ARS 18.000,00 pagados, ARS 18.000,00 pendientes y ARS 36.000,00 total. |
| Administrador: navbar y ruta de Profesional | Login real con contraseña/TOTP, navbar únicamente de Cuentas; acceso directo al resumen de Profesional mostró `Forbidden`, sin importes. |
| Administrador: ruta de Secretaría | Un nuevo login real de Administrador seguido del acceso directo redirigió a `/`, sin resumen ni importes. `EconomicSummaryLive.mount/3` rechaza el rol distinto al esperado mediante esa redirección. |

Un chequeo de navegador que esperaba literalmente `Forbidden` también para la ruta de Secretaría falló. La inspección del límite de autorización confirmó la redirección existente en `lib/origen_web/live/economic_summary_live.ex`; no se cambió la aplicación ni se sustituyó una denegación por acceso permitido. El resultado observado es una denegación por redirección, no un 403 atribuido ficticiamente.

La evidencia combinada cubre la integración real y los recorridos anteriores. Ausencias pagadas, pagos tardíos, otras exclusiones, sesiones revocadas y ausencia de mutaciones rechazadas tienen evidencia automatizada independiente; no se atribuye a estas sesiones de navegador la ejecución de esos casos adicionales. No se repitieron suites ni se modificó código de producción durante la reanudación del navegador. La aprobación humana explícita de #391 se registra a continuación; no implica cierre de #391/#288 ni autorización de publicación.

## Aprobación funcional

El responsable aprobó explícitamente la integración en esta conversación:

> Apruebo la integración de la #391.

La aprobación corresponde a la integración y a la evidencia y limitaciones documentadas arriba. No se extiende a capacidades ajenas al alcance ni convierte pruebas omitidas, excluidas o no ejecutadas en verificaciones aprobadas. El registro es local: no se hicieron commits, publicaciones ni cambios de estado en GitHub con esta aprobación.
