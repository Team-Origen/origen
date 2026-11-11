# Contrato #388: Resumen económico por fecha de turno (#288)

**Estado: contrato documental aprobado explícitamente por el usuario.**
Las modalidades de período y sus límites fueron definidos por el usuario durante la preparación. Tras revisar el resumen del contrato, el usuario aprobó el documento completo y solicitó su PR: «CONTRATO APORVADO, HAS EL PR,». La aprobación documental no certifica la funcionalidad.

Este contrato prepara [#288](https://github.com/Team-Origen/origen/issues/288) mediante [#388](https://github.com/Team-Origen/origen/issues/388). No implementa código de aplicación, no certifica integración ni cierra issues. No asigna responsables o aprobadores distintos de los establecidos para el slice.

## 1. Identificación y fuentes

- **OpenSpec Change:** `health-center-beta-core`.
- **Ruta:** `openspec/changes/health-center-beta-core/`.
- **Scope:** Sprint 4 / parent #288 / implementation slice 13 of 17 / contract #388.
- **Mapa:** [#266](https://github.com/Team-Origen/origen/issues/266).
- **Base inspeccionada:** `develop`, commit `0ffaf08`, sincronizado con `origin/develop` al crear `docs/388-contrato-resumen-economico`.

| Fuente | Alcance aplicable |
| --- | --- |
| [#288](https://github.com/Team-Origen/origen/issues/288) y [#388](https://github.com/Team-Origen/origen/issues/388) | Alcance del resumen y preparación documental. Sin comentarios adicionales al momento de la consulta. |
| [Propuesta](../../../openspec/changes/health-center-beta-core/proposal.md) | `Confirmed scope`, `Product boundaries`, `Current-code reconciliation`, `Security and data impact`. |
| [Diseño](../../../openspec/changes/health-center-beta-core/design.md) | Vocabulario, autorización default-deny y obligaciones futuras. |
| [Pagos y resumen](../../../openspec/changes/health-center-beta-core/specs/payments-and-period-summary/spec.md) | `Cancellation and summary scope`; `Late payment updates appointment period`; compatibilidad con `Single total payment and correction`. |
| [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) | Exclusión de reportes avanzados, resúmenes globales y comparaciones. |
| [Guía de trabajo](../GUIA_TRABAJO_BETA.md) | Preparación, evidencia, dependencias, aprobación e integración. |
| [#287](https://github.com/Team-Origen/origen/issues/287) y [contrato #384](384-pagos-simples-correccion.md) | Precio final, marca pagada vigente, corrección y preservación de pagos; no duplicar su implementación. |
| [Reserva desde Profesional](../integration/316-professional-booking.md), [`ProfessionalBooking`](../../../lib/origen/booking/professional_booking.ex), [configuración](../../../config/config.exs) | Convención existente: límites de fechas en zona organizacional y timestamps UTC. |

Las decisiones de la sección 2 precisan el período, que las fuentes beta denominan genéricamente «período». No se atribuyen esas precisiones al texto original de OpenSpec ni se afirma que ya estén publicadas en GitHub.

## 2. Decisiones explícitas del período

Solicitud del usuario, conservada literalmente:

> SE PUEDEN LA 2 OPCIONES?? UNO QUE SEA POR MESE FECHA CALENDARIO Y OTRO IDNICANDO LA FECHA INICAL Y OTROA LA FECHA FINAL (TAMBIEN SE PUEDE SELECCIONAR COMO UNDIA PONIENDO COMO EXTEREMO EL MISMO DIA COMO FECHA INICIAL Y FECHA FINAL, O RECOMIENDAS HACERLO DE OTRA FORMA ()OVIAMENTE, NO VOY A PODE SELECCION UNA FECHA FINAL MENOR A LA INICIAL

Después de precisar ambas modalidades, el usuario autorizó redactar el documento: «HAS EL CONTARTO».

| Modalidad | Entrada | Interpretación |
| --- | --- | --- |
| Mes calendario | Mes y año | Desde el primer día hasta el último día de ese mes, ambos completos. |
| Rango de fechas | Fecha inicial y fecha final | Incluye ambos extremos y todos los días entre ellos. |

- Inicio igual a fin es válido y consulta un día completo. No hace falta una tercera modalidad independiente para un día.
- Fin anterior a inicio es inválido. La interfaz debe impedir seleccionarlo y backend debe rechazarlo si lo recibe; no intercambia ni corrige silenciosamente los extremos.
- Las fechas deben existir y la modalidad debe tener sus entradas completas y válidas. No se ejecuta un cálculo con entradas inválidas.
- Mes calendario y su rango equivalente deben producir exactamente el mismo resultado. Seleccionar año identifica el mes; no agrega una modalidad anual ni un reporte avanzado.
- No se fija aquí un período predeterminado, restricciones a fechas futuras ni un límite máximo de rango: no fueron requisitos solicitados.

### Frontera temporal compartida

La fecha del turno se deriva de `start_time` en la zona horaria organizacional utilizada por la agenda. La configuración de la base inspeccionada es `America/Argentina/Buenos_Aires`; los tests configuran `Etc/UTC`. No se agrega una zona por Profesional ni se agrupa por la fecha UTC sin aplicar la convención existente.

Para ambas modalidades, la semántica es desde el inicio del primer día local, incluido, hasta el inicio del día siguiente al final, excluido. Incluye el último día completo sin depender de una precisión artificial de «23:59:59». La conversión de esos límites a UTC es una decisión técnica compatible con la agenda, no una nueva modalidad.

## 3. Reglas del resumen

### 3.1 Alcance y resultados

La consulta es de sólo lectura, para un único Profesional y un período válido. Devuelve los importes **Pagado**, **Pendiente** y **Total considerado**, con el Profesional y período a los que corresponden.

Los importes se calculan con el precio final del turno definido por #287, en ARS y con aritmética monetaria exacta; no se usa el precio actual del catálogo ni se confunde el snapshot histórico con el precio final editable. Cada turno aporta como máximo una vez y a un único conjunto. Un período sin turnos elegibles devuelve cero en los tres importes, sin inventar deuda.

| Estado operativo | Con marca pagada vigente | Impago |
| --- | --- | --- |
| Confirmado (`confirmed`) | Pagado | Pendiente |
| Asistido (`attended`) | Pagado | Pendiente |
| Cancelado (`cancelled`) | Pagado, conservando la marca previa | Excluido |
| Ausencia (`no_show`) | Pagado, conservando la marca previa | Excluido |
| Solicitado (`requested`), rechazado o vencido (`expired`) | La regla de resumen incluye todo pago vigente; estos estados no habilitan registrar uno nuevo | Excluido |

«Pagado» incluye todo turno pagado del período. Esto no crea nuevas transiciones ni permite cobrar solicitudes, rechazos, vencidos, cancelados o ausencias: registrar pago sigue restringido por #287 a confirmados o asistidos. La representación técnica de un rechazo se toma del ciclo operativo, sin introducir un estado persistido desde este contrato.

**Total considerado = Pagado + Pendiente.** Ninguno de esos importes se presenta como deuda, caja mensual, ingreso neto o saldo disponible. Pendiente es un subconjunto de turnos impagos elegibles, no una cuenta corriente.

### 3.2 Pagos tardíos y correcciones

- La pertenencia al período depende exclusivamente de la fecha del turno, no de la fecha del pago, corrección o consulta.
- Un pago posterior actualiza Pagado del período original del turno. Si antes era pendiente elegible, ese importe deja de aportar a Pendiente; no cuenta dos veces.
- Revertir una marca retira el importe de Pagado. Sólo vuelve a Pendiente si el turno sigue confirmado o asistido; cancelados y ausencias impagos quedan excluidos.
- Una edición posterior del precio final impago se refleja en Pendiente sólo si el turno es elegible. La consulta no modifica precios ni marcas.
- Cancelar o marcar ausencia no elimina un pago anterior: permanece en Pagado del período del turno.
- Un turno de precio final cero sigue las mismas reglas de elegibilidad y pago que los demás; su aporte monetario es cero.

#288 consume los datos y operaciones de #287. No registra, revierte ni transfiere pagos para poder calcular un resumen, ni duplica el historial de correcciones. El resultado debe reflejar el estado vigente al consultar; no se prescribe caché ni actualización en tiempo real.

## 4. Permisos y rechazos

| Actor | Consulta permitida |
| --- | --- |
| Profesional autenticado y activo | Sólo su propio resumen. Un identificador ajeno no amplía el alcance. |
| Secretaría autenticada y activa | Resumen de un Profesional por vez; no agrega varios ni todo el centro. |
| Administrador | Ningún resumen financiero. |
| Paciente | Ningún resumen por Profesional; su consulta limitada de precio/estado de turnos propios pertenece a #287. |
| Anónimo, sesión inválida o personal inactivo | Ningún resumen. |

La autorización se aplica también al invocar directamente la operación, no sólo ocultando controles. Se reutilizan revalidación y default-deny; las futuras operaciones deben incorporarse explícitamente a la matriz de autorización.

Se rechazan: acceso fuera de alcance, identidad o sesión inválida, selección de Profesional inexistente o no autorizada, intento de consulta agregada, modalidad o fechas inválidas y rango invertido. El formato concreto de errores se define con la API futura; no se inventan nombres de funciones, endpoints ni mensajes implementados.

Una denegación no expone importes de otros profesionales. Consultas válidas y rechazadas no modifican turnos, precios, pagos, catálogo ni historia de acciones de pago. Los registros técnicos de acceso que correspondan no son una corrección financiera.

## 5. Escenarios verificables

Son obligaciones para implementación y pruebas futuras, no evidencia de funcionalidades ya ejecutadas. Deben verificarse por interfaces públicas autorizadas sobre datos aislados; los rechazos comprueban error, ausencia de fuga y ausencia de mutaciones de negocio. No se exige inspeccionar almacenamiento interno desde los tests del contrato.

| ID | Dado / Cuando | Resultado esperado |
| --- | --- | --- |
| R1 | Consultar noviembre de 2026 y luego 01/11/2026–30/11/2026 para el mismo Profesional y datos | Los tres importes y el alcance son idénticos. Incluye el primer y último día completos; excluye días adyacentes. |
| R2 | Inicio y fin 15/11/2026 | Incluye todos los turnos de ese día local; excluye los anteriores y posteriores. No exige modo adicional. |
| R3 | Inicio 20/11/2026 y fin 19/11/2026 | La interfaz impide la selección y backend rechaza una invocación directa. No intercambia extremos, no calcula ni modifica datos. |
| R4 | Fecha inexistente, extremo ausente, mes/año inválido o modalidad inválida | Rechazo sin calcular resultados engañosos ni mutaciones. |
| R5 | Consultar febrero de 2028, febrero de 2027 y diciembre con turnos en sus fronteras | Incluye respectivamente hasta el 29 y 28 de febrero; diciembre termina antes del 1 de enero. Misma semántica que rangos equivalentes. |
| R6 | Turno a las 00:30 UTC del 01/12/2026, equivalente a 21:30 del 30/11 en Buenos Aires | Con esa zona organizacional pertenece a noviembre, no diciembre. Verificar inicio incluido y siguiente día excluido. No hardcodear esa zona en pruebas que configuren otra. |
| R7 | En un período: confirmado pagado $10.000, cancelado pagado $8.000, ausencia pagada $7.000, confirmado impago $6.000 y asistido impago $4.000 | Pagado $25.000; Pendiente $10.000; Total considerado $35.000. Cada turno se cuenta una sola vez. |
| R8 | Agregar cancelado, solicitado, rechazado, vencido y ausencia, todos impagos, a R7 | Ninguno modifica los tres importes. Cubrir cada exclusión sin asumir un estado persistido de rechazo. |
| R9 | Turno asistido de noviembre por $6.000, pagado en diciembre | Noviembre pasa de Pendiente a Pagado por $6.000, sin alterar su total por ese cambio. Diciembre no recibe ese importe por la fecha de cobro. |
| R10 | Revertir mediante #287 un pago de confirmado/asistido y volver a consultar | Se resta de Pagado y pasa a Pendiente por el precio final vigente. No se cuenta la marca histórica revertida. |
| R11 | Revertir mediante #287 un pago conservado en cancelado/ausente y consultar | Se resta de Pagado y Total considerado; no se suma a Pendiente. Cubrir ambos estados. |
| R12 | Cancelar o marcar ausencia después de pagar y consultar | El importe continúa en Pagado, sin traslado de período ni borrado de la marca. |
| R13 | Cambiar precio final de confirmado/asistido impago de $6.000 a $5.000 mediante #287; catálogo diferente y snapshot anterior | Pendiente refleja $5.000; no usa catálogo ni snapshot. Consulta no cambia ninguno de esos datos. Turnos de $0 no agregan importe ni habilitan estados nuevos. |
| R14 | Período vacío o sólo con impagos excluidos | Pagado, Pendiente y Total considerado son cero; no se presentan como deuda o saldo. |
| R15 | Profesional consulta lo propio e intenta sustituir su identificador por uno ajeno | Lo propio es accesible; lo ajeno se deniega tanto en interfaz como en backend sin filtrar importes. |
| R16 | Secretaría consulta A y luego B, con datos de ambos en el mismo período | Cada resultado corresponde exclusivamente al Profesional seleccionado. Solicitar varios o un agregado del centro no produce un resumen autorizado. |
| R17 | Administrador, Paciente, anónimo, sesión inválida o personal inactivo intenta consultar; selección inexistente o no autorizada | Denegación sin exposición financiera ni cambios de negocio. Cubrir cada actor y selección. |
| R18 | Consulta válida o rechazada y revisión de su presentación | Turnos, precios, pagos e historia de acciones intactos. Etiquetas y mensajes no presentan total como deuda, caja mensual, ingreso neto o saldo disponible. |

## 6. Estado actual y mapa de preparación

### Código encontrado

| Tratamiento | Evidencia en la base inspeccionada | Diferencia o trabajo futuro |
| --- | --- | --- |
| Reutilizar | [`Appointment`](../../../lib/origen/booking/appointment.ex): `start_time`, Profesional, estado y `snapshot_exact_price_ars` | Referencias y fecha del turno; el snapshot no reemplaza el precio final de #287. |
| Reutilizar/adaptar | [`Lifecycle`](../../../lib/origen/booking/lifecycle.ex): `cancel_appointment/3`, `record_attendance/4`, `list_appointment_history/2`; [documentación](../../booking/APPOINTMENT_LIFECYCLE.md) | Patrones de alcance y revalidación. El historial no calcula resúmenes ni prueba reglas financieras. |
| Reutilizar | [`ProfessionalBooking`](../../../lib/origen/booking/professional_booking.ex), límites de fechas; [`Availability`](../../../lib/origen/availability.ex), configuración organizacional | Aplicar la convención de días locales y UTC; no introducir una zona financiera independiente. |
| Adaptar | [Matriz de autorización](../../security/AUTHORIZATION_MATRIX.md) y [`rules.ex`](../../../lib/origen/authorization/rules.ex) | Declarar consulta propia y consulta por Secretaría; pruebas de denegación antes de exposición. |
| Adaptar | [`role_navigation.ex`](../../../lib/origen_web/components/role_navigation.ex) y [decisiones de navegación](../../navigation/NAVIGATION_DECISIONS.md) | El ítem actual es un aviso de funcionalidad futura, no una pantalla conectada. Activarlo corresponde a interfaz/integración. |
| Crear | No se encontró implementación de pagos, precio final ni agregación económica en la exploración de `lib/` y `test/` | #287 aporta los datos; #288 deberá crear consulta autorizada, cálculo, controles de período y pruebas. No duplicar pagos. |
| Retirar del recorrido beta | Reportes históricos de [Origen_Documentacion.md](../../Origen_Documentacion.md) | No reutilizar informes de sólo pagados como si cumplieran este contrato ni agregar comparaciones, caja o reportes anuales. No se borran archivos históricos aquí. |

### Pruebas y límites de evidencia

- La exploración leyó [`role_navigation_live_test.exs`](../../../test/origen_web/live/role_navigation_live_test.exs): el ítem de resumen es un control sin pantalla real. No prueba cálculo, permisos financieros ni conexión a pagos.
- Las pruebas de ciclo y reserva existentes son referencias de patrones, no evidencia funcional de #288. No se atribuye a este contrato la ejecución histórica de esas pruebas.
- **No se ejecutaron pruebas funcionales de pagos ni resumen para preparar este documento.** Los escenarios R1–R18 no se presentan como tests existentes o aprobados.
- La existencia del contrato aprobado #384 no acredita que #287 esté implementada o integrada. Tampoco una búsqueda sin resultados certifica por sí sola un recorrido de extremo a extremo.

## 7. Dependencias, pendientes y aprobación

### Dependencias

- Al consultar GitHub durante esta preparación, #388 no tenía blockers nativos directos y #288 conservaba el blocker abierto [#287](https://github.com/Team-Origen/origen/issues/287).
- Ese blocker no se copia automáticamente al contrato ni a trabajo realmente independiente. La integración final deberá tener explícitos los blockers de la padre y todas sus hermanas, conforme a la guía.
- No se modifica ninguna dependencia de GitHub ni se añade un bloqueo hacia funcionalidades posteriores. Si aparece una dependencia técnica imprescindible, se documenta el comportamiento impedido y la evidencia y se consulta el ajuste antes de condicionarle el cierre.
- Hosting e identidad visual no bloquean este contrato. No se resuelven ni se inventan aquí.

### Pendientes reales

1. Registrar la referencia de publicación del contrato aprobado en el seguimiento cuando corresponda; la aprobación documental ya fue otorgada explícitamente en esta conversación.
2. Backend: definir API y errores, implementar alcance y consulta monetaria por período con los datos acordados de #287, extender autorización y probar escenarios aplicables.
3. Interfaz: implementar selección mes/año y rango inclusivo, validación, resultados y denegaciones. No se decide aquí un diseño visual ni una ruta nueva. Cualquier trabajo de navegación debe leer y respetar [URL_CONVENTIONS.md](../../navigation/URL_CONVENTIONS.md).
4. Integración: con dependencias y hermanas terminadas y aprobadas, ejecutar recorrido real, pagos tardíos, correcciones, límites de período, permisos y regresiones; registrar resultados y aprobación por separado.

No quedaron preguntas de producto identificadas después de la definición de ambas modalidades. Las decisiones técnicas pendientes no autorizan ampliar el alcance ni se presentan como preguntas de producto ya bloqueantes.

### Registro de aprobación y fuera de alcance

- **Decisión puntual:** el usuario solicitó mes calendario y rango con extremos inclusivos, día único con fechas iguales y rechazo de fin anterior al inicio (sección 2).
- **Documento completo:** aprobado explícitamente por el usuario: «CONTRATO APORVADO, HAS EL PR,». La aprobación se limita al contrato, no certifica backend ni integración.
- **Implementación, integración y cierre de #288 o #388:** no realizados por este documento.
- **Publicación, commit y PR:** el usuario solicitó crear el PR y autorizó explícitamente commit, push y uso de la sesión de GitHub configurada para `Team-Origen/origen`. También autorizó aplicar `status:approved` a #388. El PR se dirige a `develop` con `Refs #388`, sin cierre automático; no implica integración ni cierre de #288.

No incluye resumen global del centro, comparaciones, reportes avanzados, comprobantes, parciales, devoluciones, créditos, transferencias de pagos ni semántica de deuda, caja, ingreso neto o saldo. No implementa código de aplicación ni certifica entrega por tener documentación.
