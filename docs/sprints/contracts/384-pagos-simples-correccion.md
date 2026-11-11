# Contrato #384: Pagos simples y corrección (#287)

**Estado: contrato documental aprobado explícitamente por el usuario.**
Las decisiones puntuales de la sección 2 fueron confirmadas durante la preparación. Tras revisar el resumen del contrato, el usuario aprobó el documento completo y autorizó commit y PR con la instrucción: «CONTRATO APROVADO, HAS EL PR Y COMMIT».

Este contrato prepara [#287](https://github.com/Team-Origen/origen/issues/287) mediante [#384](https://github.com/Team-Origen/origen/issues/384). No implementa pagos, no certifica integración ni cierra ninguna issue. No asigna responsables o aprobadores diferentes de los establecidos en el seguimiento del slice.

## 1. Identificación y fuentes

- **OpenSpec Change:** `health-center-beta-core`.
- **Ruta:** `openspec/changes/health-center-beta-core/`.
- **Scope:** Sprint 4 / parent #287 / implementation slice 12 of 17 / contract #384.
- **Mapa:** [#266](https://github.com/Team-Origen/origen/issues/266).
- **Base inspeccionada:** `develop`, commit `87158ab`; rama de preparación `docs/384-contract`.

| Fuente | Alcance aplicable |
| --- | --- |
| [#287](https://github.com/Team-Origen/origen/issues/287) y [#384](https://github.com/Team-Origen/origen/issues/384) | Criterios del slice y preparación documental; sin comentarios adicionales al momento de la consulta. |
| [Propuesta](../../../openspec/changes/health-center-beta-core/proposal.md) | `Confirmed scope`, `Product boundaries`, `Current-code reconciliation`, `Security and data impact`. |
| [Diseño](../../../openspec/changes/health-center-beta-core/design.md) | Vocabulario, autorización, estados y obligaciones de implementación futura. |
| [Pagos y resumen](../../../openspec/changes/health-center-beta-core/specs/payments-and-period-summary/spec.md) | `Single total payment and correction`; `Cancellation and summary scope`, sólo preservación y compatibilidad de datos para #288. |
| [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) | Capacidades excluidas; prioridades no recortan el alcance aprobado. |
| [Guía de trabajo](../GUIA_TRABAJO_BETA.md) | Reglas y contrato, evidencia, dependencias, aprobación e integración. |
| [Resolución histórica #272](https://github.com/Team-Origen/origen/issues/272#issuecomment-6251968462) | Pago total, precio, corrección, visibilidad y exclusiones; excepción de cobro de ausencias sustituida expresamente en sección 2. |
| [Resolución histórica #271](https://github.com/Team-Origen/origen/issues/271#issuecomment-6251967780), [ciclo operativo](../sprint-4/contrato-285-ciclo-operativo-turno.md) y [backend del ciclo](../../booking/APPOINTMENT_LIFECYCLE.md) | Frontera con #285: aprobación, cancelación, asistencia y ausencia; no redefinir el ciclo desde pagos. |

## 2. Decisiones explícitas de esta preparación

### D1. Registrar pago sólo en confirmado o asistido

Pregunta: si un turno quedó como ausencia e impago, ¿puede cobrarse después? Respuesta del usuario: **«No, sólo confirmado o asistido»**.

- Prevalece la restricción de #287, #384 y OpenSpec: sólo `confirmed` o `attended` admiten registrar una marca pagada.
- Se sustituye expresamente la parte de #272 que permitía cobrar después una ausencia impaga. No se sustituye el resto del acuerdo.
- Un pago registrado antes de pasar a `no_show` se conserva. Conservar un pago no equivale a admitir uno nuevo sobre una ausencia.
- No se introduce una transición de ausencia a asistido para poder cobrar ni una operación «No se cobra».

### D2. Precio final cero permitido

Pregunta: tratamiento de precio final $0. Respuesta del usuario: **«Permitir $0 y marcarlo pagado»**.

- El precio final admite cero; no admite importes negativos.
- Un turno de $0 puede marcarse pagado, con método, actor y fecha, igual que un turno de importe positivo.
- La marca pagada de $0 bloquea el precio; su corrección lo desbloquea.
- No se incorpora un estado financiero «sin cargo» ni una excepción de permisos.

Estas decisiones quedan registradas aquí; no se afirma que ya estén publicadas en GitHub. D1 coincide con la restricción vigente de OpenSpec; D2 precisa un caso no desarrollado explícitamente allí.

## 3. Alcance y reglas

### 3.1 Estados independientes

El estado operativo del turno y su estado de pago son dimensiones diferentes. `pending` significa pago pendiente; no debe confundirse con una solicitud `requested` pendiente de aprobación.

- Un turno tiene un único pago total lógico, con estado `pending` o `paid`. No admite varios pagos acumulados ni parciales.
- Los únicos métodos son efectivo o transferencia. La transferencia se verifica fuera del sistema, sin adjuntar ni revisar comprobantes.
- El pago pendiente no impide reservar, conservar el turno, aprobarlo ni registrar su resultado operativo.
- Marcar pago no confirma una solicitud ni cambia el estado operativo, horario, paciente o profesional del turno.
- Un estado histórico como `reserved` no habilita por sí mismo registrar pago: la operación debe comprobar un estado contractual `confirmed` o `attended`, sin ampliaciones por compatibilidad implícita.

### 3.2 Precio final del turno

Profesional sobre sus turnos y Secretaría sobre todos pueden editar el precio final antes de la marca pagada. La edición es individual: no cambia el catálogo, los precios de otros turnos ni el snapshot histórico de reserva.

El modelo actual conserva el precio de catálogo al reservar en `snapshot_exact_price_ars`. La implementación deberá distinguir ese valor histórico del precio final editable, sin eliminar su protección de inmutabilidad. El mecanismo de persistencia y la inicialización/migración de datos se resolverán en backend preservando la historia; este contrato no prescribe una tabla ni una firma de función nueva.

El precio final es monetario en ARS, coherente con la representación decimal existente; se rechazan valores negativos o malformados. El valor cero es válido por D2. No se agrega un importe parcial ni un monto recibido diferente del precio final: pagar significa cubrirlo por completo.

Al marcar `paid`, el precio queda bloqueado. Para corregir el precio de un turno pagado, primero se revierte la marca, después se edita y, si corresponde y el estado operativo lo permite, se registra nuevamente el pago.

### 3.3 Registro del pago total

Precondiciones: actor autorizado y vigente, turno dentro de su alcance, estado operativo `confirmed` o `attended`, pago pendiente, método admitido y precio final válido.

Resultado: pago `paid` por el precio final completo, método, actor y fecha conservados, precio bloqueado y estado operativo intacto. Identidad y fecha del actor no se aceptan como una declaración libre del cliente.

Una nueva solicitud de pago sobre un turno ya pagado no crea otro pago ni sobrescribe la marca previa. Debe informar que ya está pagado sin duplicar efectos. El formato concreto del resultado y los identificadores de errores se definirán en backend; aquí no se inventan APIs implementadas.

### 3.4 Corrección de una marca errónea

Profesional sobre sus turnos y Secretaría sobre todos pueden revertir una marca `paid` mediante confirmación breve. No se exige motivo escrito ni texto aclaratorio adicional sobre devoluciones.

- Si se cancela la confirmación, no cambia ningún dato.
- Si se confirma, vuelve a `pending` y habilita editar el precio final; no cambia por sí misma el importe ni el estado operativo.
- Se preservan la marca anterior, su método, importe, actor y fecha, y la acción de corrección con su actor y fecha. No se sobrescribe ni elimina la evidencia previa.
- Una marca pagada conservada en un turno cancelado o ausente sigue siendo corregible: la regla de corrección no añade una restricción operativa. Corregir no habilita registrar un nuevo pago en esos estados, por D1.
- No es devolución, salida de dinero, crédito ni traslado de pago.
- Si después se vuelve a pagar un turno elegible, continúa existiendo un único pago total vigente, con la secuencia anterior trazable.

### 3.5 Cancelación y compatibilidad con #288

Cancelar un turno no borra ni revierte un pago. Marcar ausencia tampoco elimina un pago previo. No se cancelan turnos como efecto de corregir un pago.

El cambio de fecha/hora/tipo sigue siendo cancelar y crear otro turno, según #285. El nuevo turno no hereda automáticamente el pago del anterior.

Los datos deben permitir que [#288](https://github.com/Team-Origen/origen/issues/288) calcule por **fecha del turno**, no de cobro:

- Pagados: todos los pagados del período, incluidos cancelados y ausentes con pago conservado.
- Pendientes: únicamente confirmados o asistidos impagos; excluye cancelados, solicitudes sin aprobar/rechazadas/vencidas y ausencias impagas.
- Al revertir una marca, deja de contar como pagada; sólo podrá contar como pendiente si su estado operativo es confirmado o asistido.

#287 no debe implementar el resumen ni una pantalla, endpoint o mecanismo de caché de #288 para cerrar. No se exige un resumen global ni se presenta el precio como deuda completa, caja mensual, ingreso neto o saldo disponible.

## 4. Matriz de permisos

| Actor autenticado | Consultar precio final/estado | Editar precio impago | Registrar pago elegible | Revertir marca pagada |
| --- | --- | --- | --- | --- |
| Profesional activo | Sólo sus turnos | Sólo sus turnos | Sólo sus turnos | Sólo sus turnos |
| Secretaría activa | Todos los turnos del centro | Todos | Todos | Todos |
| Paciente | Sólo sus propios turnos; únicamente precio final y estado de pago | No | No | No |
| Administrador | No | No | No | No |
| Anónimo, sesión inválida o personal inactivo | No | No | No | No |

El paciente no paga desde el sistema, no elige método ni ve actor, fecha o historial interno de correcciones. Ser Administrador no da acceso financiero. Cambiar el identificador del turno o invocar directamente backend no puede eludir el alcance de la matriz.

Las denegaciones no deben exponer datos financieros fuera del alcance ni modificar pago, precio, turno, catálogo o historia de acciones efectivas. La revalidación de sesión y el default-deny existentes son la base; ocultar botones no basta.

## 5. Operaciones contractuales y rechazos

Son capacidades observables, no nombres de funciones ya implementadas.

| Operación | Entrada necesaria | Resultado | Rechazos a cubrir |
| --- | --- | --- | --- |
| Consultar | Actor validado y turno | Proyección autorizada; paciente limitada a precio final/estado | Identidad/sesión inválida, turno ajeno, Administrador, turno inexistente sin fuga de información |
| Editar precio | Actor validado, turno y precio final | Precio individual actualizado; snapshot y catálogo intactos | Fuera de alcance, pago `paid`, precio negativo/malformado |
| Registrar pago | Actor validado, turno, método | Único pago total `paid`, trazabilidad y precio bloqueado | Turno fuera de alcance o no elegible, método no admitido, precio inválido, ya pagado |
| Revertir marca | Actor validado, turno pagado y confirmación | Pago `pending`, precio editable y secuencia conservada | Fuera de alcance, pago ya pendiente; confirmación no aceptada no ejecuta la operación |

Una operación rechazada no deja una mutación parcial. La futura implementación debe mantener consistentes pago, precio y trazabilidad aun ante errores o solicitudes concurrentes; no puede crear pagos duplicados ni permitir que el precio cambie después de que se registra un pago. Se reutilizará el patrón transaccional existente cuando corresponda, sin fijar aquí el mecanismo concreto.

## 6. Estado actual y mapa de preparación

### 6.1 Código encontrado

| Clasificación | Evidencia en la base inspeccionada | Preparación requerida |
| --- | --- | --- |
| Reutilizar | [`Appointment`](../../../lib/origen/booking/appointment.ex), `schema`, `changeset/2`: identidad, estado operativo y `snapshot_exact_price_ars` decimal no negativo | Conservar referencias e historia; no confundir snapshot con precio final. |
| Reutilizar/adaptar | [`Lifecycle`](../../../lib/origen/booking/lifecycle.ex) y operaciones públicas descritas en [APPOINTMENT_LIFECYCLE.md](../../booking/APPOINTMENT_LIFECYCLE.md): `cancel_appointment/3`, `record_attendance/4`, `list_appointment_history/2` | Reusar patrones de alcance, revalidación y transacción; integrar preservación del pago sin duplicar el ciclo #285. |
| Adaptar | [Inmutabilidad de turnos](../../../priv/repo/migrations/20261024100100_add_appointment_immutability.exs), `reject_appointment_snapshot_mutation` | Preservar snapshot y núcleo del turno; representar separadamente el precio final. |
| Adaptar | [Matriz de autorización](../../security/AUTHORIZATION_MATRIX.md) y [`authorization/rules.ex`](../../../lib/origen/authorization/rules.ex) | Agregar operaciones financieras y pruebas de denegación antes de exponerlas. La matriz incremental no otorga permisos por omisión. |
| Adaptar | [`audit/events.ex`](../../../lib/origen/audit/events.ex) y auditoría del ciclo en `Lifecycle` | Soportar trazabilidad de marca/corrección, conservando actor y fecha; no asumir que el catálogo de eventos actual ya cubre pagos. |
| Crear | No se encontró recorrido operativo de pagos en la exploración de `lib/` y `test/` | Persistencia de precio final/pago/historia, operaciones autorizadas, controles de interfaz y pruebas específicas. |
| Retirar del recorrido beta | Reglas históricas de [Origen_Documentacion.md](../../Origen_Documentacion.md) y vocabulario financiero en [CONTEXT.md](../../CONTEXT.md) | No arrastrar comprobantes, estados financieros extra, multas, créditos ni Administrador financiero. Reconciliar documentación al implementar; este contrato no borra archivos históricos. |

### 6.2 Pruebas leídas y evidencia no ejecutada

- [`test/origen/booking/appointment_test.exs`](../../../test/origen/booking/appointment_test.exs): inmutabilidad de identidad/horario y reemplazo mediante cancelar y crear.
- [`test/origen/booking/attendance_test.exs`](../../../test/origen/booking/attendance_test.exs): asistencia/ausencia por Profesional propio y Secretaría, proyección de historia y eventos.
- La exploración previa también revisó [`test/origen/booking/lifecycle_test.exs`](../../../test/origen/booking/lifecycle_test.exs) para cancelación, alcance y conservación del turno.
- **No se ejecutaron pruebas funcionales para este contrato.** No se atribuyen a #384 los resultados históricos registrados por #377 ni se afirma que prueben pagos.
- Los escenarios de la sección 7 son obligaciones futuras, no tests existentes o aprobados. No hay evidencia funcional de pago, precio final editable o reversión implementados.

## 7. Escenarios verificables

Cada escenario de éxito debe comprobar el resultado público y todos sus efectos persistidos observables por las interfaces autorizadas. Cada rechazo debe comprobar resultado de error, ausencia de fuga y ausencia de cambios en precio, pago, turno, catálogo e historia de acciones efectivas. El formato exacto de errores se acordará con la API implementada, sin exigir mensajes inventados aquí.

| ID | Dado / Cuando | Resultado esperado |
| --- | --- | --- |
| P1 | Profesional sobre turno propio o Secretaría sobre cualquier turno, confirmado o asistido e impago; registra efectivo o transferencia | Pago total `paid` por el precio final, método/actor/fecha conservados, precio bloqueado, estado operativo intacto. Cubrir ambos estados, métodos y alcances. |
| P2 | Turno solicitado sin aprobar, vencido, cancelado o ausente impago; se intenta registrar pago | Rechazo sin mutaciones. Una solicitud no se confirma al intentar pagar. La ausencia impaga no se cobra después (D1). |
| P3 | Profesional intenta consultar/editar/pagar/revertir un turno de otro Profesional; Administrador, paciente o sesión inválida intenta mutar | Denegación en backend y recorrido de interfaz, sin datos ajenos ni cambios. |
| P4 | Paciente consulta un turno propio y luego intenta consultar uno ajeno o modificar el suyo | Sólo ve precio final/estado del propio; no método, actor o historia financiera. Consulta ajena y modificaciones denegadas. |
| P5 | Profesional propio o Secretaría edita un precio impago, por ejemplo de $10.000 a $8.000 | Sólo cambia el precio final de ese turno; catálogo, snapshot histórico y otros turnos intactos. Después de pagar, la misma edición se rechaza. |
| P6 | Precio final $0; actor autorizado marca pago en confirmado/asistido | Acepta $0 y conserva método/actor/fecha; bloquea precio. La corrección devuelve a pendiente y desbloquea (D2). Precio negativo o malformado se rechaza sin mutaciones. |
| P7 | Registro con método distinto de efectivo/transferencia, o segundo registro sobre un pago `paid` | Rechazo sin reemplazar la marca ni duplicar pagos o acciones efectivas. |
| P8 | Turno pagado; operador cancela la confirmación de reversión | Pago, precio, estado operativo e historia permanecen iguales. No se solicita motivo obligatorio. |
| P9 | Turno pagado; operador autorizado confirma la reversión | Pago pendiente, precio editable, importe y estado operativo intactos; marca previa y corrección con actores/fechas trazables. No devolución ni crédito. |
| P10 | Se paga en confirmado, luego se cancela por el ciclo autorizado de #285 o se marca ausencia | Se conserva pago, importe, método e historia; no se traslada a otro turno. Si era ausencia impaga, sigue impaga. |
| P11 | Marca pagada conservada en cancelado/ausente; se confirma su corrección | Pago pendiente y precio editable; se conserva el estado operativo y la historia. No cuenta como pendiente elegible de #288 y se rechaza volver a pagar en esos estados. |
| P12 | Turno elegible pagado; se revierte, ajusta precio y paga nuevamente | Un único pago total vigente por el nuevo precio; secuencia anterior completa, sin sobrescribir la marca corregida ni alterar catálogo/snapshot. |
| P13 | Se reserva o conserva un turno sin pago | El estado pendiente de pago no bloquea el recorrido de reserva ni dispara confirmación, cancelación o sanción. |
| P14 | Pago tardío en turno asistido de un período anterior o corrección de una marca anterior | Se conservan fecha del turno y fechas de acciones para #288. No se requiere implementar el resumen; datos suficientes para retirar una marca revertida del conjunto pagado. |
| P15 | Error al persistir marca/corrección o intentos simultáneos de pagar y editar precio | No quedan escrituras parciales ni duplicados; una edición no modifica el precio de un pago ya consolidado. Verificar mediante operaciones públicas sobre estado aislado. |

## 8. Dependencias, pendientes y aprobación

### Dependencias

- Al consultar GitHub en esta preparación, #384 no tenía blockers nativos directos.
- #287 conserva su blocker nativo abierto [#285](https://github.com/Team-Origen/origen/issues/285). La existencia de backend del ciclo no certifica el cierre ni la integración de esa padre.
- Se puede preparar e implementar lo realmente independiente contra este contrato una vez aprobado. No se copian automáticamente los blockers a cada hija ni se duplica trabajo del ciclo.
- Integración debe respetar todas las hermanas terminadas/aprobadas y blockers de la padre, con dependencias explícitas según la guía. Aquí no se alteran vínculos de GitHub.
- #288 es consumidor posterior, no un bloqueo nuevo para cerrar #287. Tampoco se agregan decisiones de hosting, identidad visual o funcionalidades posteriores como requisitos de este contrato.

### Pendientes reales

1. Registrar la referencia de publicación del contrato aprobado en el seguimiento de #384 cuando corresponda; la aprobación documental ya fue otorgada explícitamente en esta conversación.
2. Backend: decidir APIs, representación persistida de precio final y pago, migración/rollback que preserve historia, autorización y trazabilidad; implementar y probar los escenarios aplicables.
3. Interfaz: controles de precio/pago/corrección y proyecciones autorizadas, sin textos o funciones excluidos. Cualquier navegación debe respetar [URL_CONVENTIONS.md](../../navigation/URL_CONVENTIONS.md); este contrato no crea rutas ni habilita una funcionalidad pendiente.
4. Integración: verificar recorrido real, errores, permisos, cancelación/ausencia con pago y regresiones cuando las dependencias estén disponibles. Registrar resultados y aprobación; no se consideran realizados por este documento.

No quedaron dudas de producto adicionales identificadas tras D1/D2. Si la implementación descubre una contradicción o dependencia técnica imprescindible, debe traer la evidencia y la pregunta al responsable antes de ampliar alcance.

### Registro de aprobación

- **Decisiones puntuales confirmadas:** D1 y D2, respuestas explícitas del usuario durante la preparación.
- **Documento completo:** aprobado explícitamente por el usuario: «CONTRATO APROVADO, HAS EL PR Y COMMIT». La aprobación se limita al contrato; no certifica backend ni integración.
- **Implementación / integración / cierre de #287:** no realizados por este contrato.
- **Publicación y cierre de #384:** no realizados; no se infieren de crear este archivo.
