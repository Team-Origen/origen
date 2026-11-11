# Contrato: ciclo operativo del turno

**Contrato documental de #376, hija de #285 — aprobado explícitamente por el usuario.**
Define vencimiento, cancelación, asistencia, ausencia e historial no clínico.
No implementa funcionalidad ni certifica la integración o el cierre de #285.

## 1. Alcance y fuentes de verdad

- Padre: [#285](https://github.com/Team-Origen/origen/issues/285).
- Contrato: [#376](https://github.com/Team-Origen/origen/issues/376).
- OpenSpec: `health-center-beta-core`.
- Ruta: `openspec/changes/health-center-beta-core/`.
- Scope: Sprint 4 / parent #285 / implementation slice 10 of 17 / contract.
- Base local inspeccionada: `2af8236`, rama de origen
  `feat/308-patient-booking-integration`; no se presume equivalencia con `develop`.
- Rama documental original: `docs/376-appointment-lifecycle-contract`.
- Rama de entrega: `docs/376-appointment-lifecycle-contract-pr`, desde `develop`,
  sin el commit documental ajeno de #308 presente en la rama original.

| Fuente | Sección aplicable |
| --- | --- |
| [Proposal](../../../openspec/changes/health-center-beta-core/proposal.md) | `Confirmed scope`, `Current-code reconciliation`, `Security and data impact`, `Tracking` |
| [Design](../../../openspec/changes/health-center-beta-core/design.md) | Estados canónicos, autorización y obligaciones futuras de implementación |
| [Reservas y ciclo de vida](../../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md) | `Three booking channels and privacy`, `Approval and occupancy`, `Expiry, cancellation, attendance, and history` |
| [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) | Alcance completo y capacidades excluidas |
| [Guía beta](../GUIA_TRABAJO_BETA.md) | Responsabilidad por ticket; preparación documental; integración y verificación |
| [Mapa #266](https://github.com/Team-Origen/origen/issues/266) | Índice de decisiones aprobadas y exclusiones |
| [Resolución histórica #271](https://github.com/Team-Origen/origen/issues/271#issuecomment-6251967780) | Aprobación, vencimiento, cancelación, presencia/ausencia e historial |

Se leyeron completas #285, #376, #284 y #266 con sus comentarios disponibles;
#285, #376 y #284 no tenían comentarios. La decisión histórica de #271 se
consultó por el enlace del mapa. Esa decisión de producto no equivale a aprobar
este documento. La dependencia nativa de #285 consultada es #284, abierta.

Fuera de alcance: WhatsApp, multas y sus advertencias, notificaciones automáticas,
reprogramación directa, contenido clínico, pagos y resumen económico. No se
condiciona este contrato a bloqueos puntuales ni a slices posteriores.

## 2. Reglas y efectos observables

`confirmed` significa turno aprobado, no presencia registrada. Los estados
canónicos aplicables son `requested`, `confirmed`, `expired`, `cancelled`,
`attended` y `no_show`; `reserved` no es un estado nuevo aprobado para esta beta.

| Operación | Condición y resultado exigido |
| --- | --- |
| Vencer solicitud | Una `requested` no resuelta pasa a `expired` al llegar su inicio. Permanece en historial y deja de ocupar disponibilidad. No se confirma, no cuenta como ausencia y no genera multa. |
| Cancelar como Paciente | Sólo solicitudes o turnos confirmados propios, antes del inicio: `requested`/`confirmed` → `cancelled`, sin multa y liberando horario. No se exige motivo al Paciente por este contrato. |
| Cancelar como Profesional | Sólo sobre su agenda; motivo visible al paciente y origen Profesional distinguible. Queda `cancelled`, libera horario y conserva historial. No se atribuye ausencia. |
| Cancelar como Secretaría | Sobre todas las agendas; mismo resultado y motivo visible, con origen Secretaría distinguible del Profesional y del Paciente. |
| Registrar asistencia/ausencia | Profesional en su agenda y Secretaría en todas registran `attended` o `no_show` sobre el turno correspondiente; el resultado queda observable en historial. Una solicitud vencida no se transforma en ausencia. |
| Cambiar fecha, hora o tipo | Cancelar el turno original y crear otro por el canal de reserva autorizado. Conservar el original cancelado en historial; el nuevo turno respeta disponibilidad, autorización y aprobación vigentes. Nunca editar esos datos como reprogramación directa. |

Para cancelación del Paciente la frontera es estricta: antes del inicio está
permitida; exactamente al inicio o después no está habilitada por esta regla.
No se traslada la política histórica D-1. La cancelación del personal conserva
su alcance aprobado sin inventarle esa restricción temporal del Paciente.

La visibilidad del motivo es una consulta del turno/historial por el paciente,
no un envío de correo, WhatsApp ni otra notificación automática. Conservar
resultado, motivo cuando corresponda y origen distinguible; este contrato no
impone columnas, nombres de eventos o una firma de API concreta.

La liberación se observa al consultar disponibilidad: el registro histórico no
se borra para liberar ocupación. Una denegación por permisos o una transición
no habilitada no modifica estado, motivo, origen, historial ni ocupación. No
se admite confirmar una solicitud ya vencida como alternativa a vencerla.

## 3. Permisos, privacidad e historial

| Actor | Alcance observable y operativo |
| --- | --- |
| Paciente | Ve todos sus propios turnos y resultados, incluidas solicitudes vencidas y cancelaciones con motivo del personal; cancela sólo los propios antes del inicio. No marca asistencia/ausencia ni opera turnos ajenos. |
| Profesional | Cancela y registra asistencia/ausencia sólo en su agenda. Ve historia de esa agenda, nunca turnos, historia o actividad del paciente con otros Profesionales. |
| Secretaría | Opera y consulta las agendas del centro según sus permisos existentes; cancelar no le otorga la aceptación/rechazo de pendientes reservada al Profesional en #284. |
| Administrador | No adquiere acceso implícito a turnos, pacientes o historial por administrar cuentas. |

La autorización se exige en servidor, no sólo ocultando botones. Manipular el
identificador de turno o agenda no amplía permisos ni revela información ajena.
El historial es operativo, sin notas, devoluciones ni historia clínica. Vencer
o cancelar no borra el registro histórico ni justifica perder la relación
Profesional–Paciente creada por una reserva/solicitud completada.

## 4. Reconciliación con el código actual

Esta matriz registra **código encontrado**, no cumplimiento certificado. Las
líneas son referencias de la base indicada; los enlaces apuntan al archivo.

| Acción | Archivo / operación encontrada | Compatibilidad o pendiente |
| --- | --- | --- |
| Reutilizar y adaptar | [Appointment](../../../lib/origen/booking/appointment.ex), líneas 14–62: estados y snapshots | Preservar snapshots e historial. Existe `reserved` y falta `expired`; revisar modelo y persistencia sin descartar datos históricos. Este contrato no ejecuta migraciones. |
| Reutilizar | [RequestResolution](../../../lib/origen/booking/request_resolution.ex), líneas 4–14 y 143–167: aceptación/rechazo de `requested`, bloqueo y auditoría transaccional | Base para conservar autoridad profesional y transiciones consistentes; no demuestra vencimiento, cancelación del Paciente/personal ni asistencia. No duplicar la resolución de #284. |
| Adaptar | [Overlap](../../../lib/origen/booking/overlap.ex), líneas 10–31 y 83–111: estados activos y ocupación | `requested` ocupa; hoy se excluyen `cancelled` y `rejected`. Incorporar la liberación por `expired` y reconciliar estados legacy en todas las fuentes de disponibilidad, no sólo en etiquetas visuales. |
| Adaptar | [Authorization](../../../lib/origen/booking/authorization.ex), líneas 15–39: relación histórica | El fallback considera `reserved`, `confirmed`, `attended`, `no_show`, no `requested`. Revisar compatibilidad con relación durable e historia sin ampliar exposición entre Profesionales. |
| Retirar del recorrido beta | [MockCalendar](../../../lib/origen/appointments/mock_calendar.ex), líneas 22–31: D-1/multa 50 % | No usar como norma ni activar sanciones. Retirar mensajes/reglas incompatibles del recorrido; no implica borrar indiscriminadamente módulos legacy. |
| Adaptar / crear conexión real | [Agenda profesional](../../../lib/origen_web/live/professional_agenda_live.ex): representación de `no_show`; [Secretaría](../../../lib/origen_web/live/secretary_patient_live.ex): cancelación de reserva asistida | Etiquetas y cancelación de una reserva asistida no acreditan las operaciones persistidas del ciclo de #285. Conectar estados, acciones autorizadas, motivo/origen e historia. |
| Crear o completar | Operaciones públicas y pruebas del ciclo integral | Vencimiento, cancelación propia/personal con motivo y origen, asistencia/ausencia e historial autorizado no quedaron acreditados por la evidencia leída. No se inventan nombres de funciones ni endpoints. |

### Pruebas leídas, no ejecutadas

| Archivo | Evidencia que describe y límite |
| --- | --- |
| [RequestResolutionTest](../../../test/origen/booking/request_resolution_test.exs), líneas 20–190 | Ocupación de pendientes, aceptación/rechazo, liberación, autorización y auditoría. No prueba el ciclo completo de #285. |
| [ReservationCasesTest](../../../test/origen/booking/reservation_cases_test.exs), líneas 19–73 | Casos históricos D-1, multas y `reserved`: adaptar/retirar su expectativa incompatible, no copiarlos como contrato beta. |
| [BookingServiceTest](../../../test/origen/appointments/booking_service_test.exs), líneas 80–90 y 193–194 | Evidencia de D-1 legacy, no cumplimiento beta. |
| [MockCalendarTest](../../../test/origen/appointments/mock_calendar_test.exs), líneas 36–37 | Política histórica de multa; aislar o retirar del recorrido beta. |
| [PatientBookingIntegrationTest](../../../test/origen_web/live/patient_booking_integration_test.exs), líneas 89–144 | Reserva manual y mensajes D-1; no acredita vencimiento, motivo/origen, asistencia ni privacidad del historial de #285. |

## 5. Escenarios verificables para implementación e integración

Son expectativas de producto, **no resultados de pruebas ejecutadas**. Cada
caso debe verificarse por operaciones públicas y consultas autorizadas, con
persistencia real en entorno de prueba aislado cuando modifique datos.

| Caso | Dado / cuando | Resultado observable exigido |
| --- | --- | --- |
| E1 — límite de vencimiento | Solicitud pendiente; se consulta antes y al llegar su inicio sin resolución | Antes ocupa y sigue pendiente; al inicio está `expired`, libera ocupación y sigue en historial. Sin confirmación, ausencia ni multa. |
| E2 — distinguir vencimiento | Un turno ya confirmado llega al inicio | No vence como solicitud pendiente ni se marca automáticamente como ausencia por esta regla. |
| E3 — cancelar solicitud propia | Paciente cancela su `requested` antes del inicio | `cancelled`, horario liberado, historial conservado, sin multa. |
| E4 — cancelar confirmado propio | Paciente cancela su `confirmed` antes del inicio | Mismos efectos que E3, sin exigir D-1. |
| E5 — frontera de cancelación | Paciente intenta cancelar al inicio o después | No se habilita cancelación propia; rechazo sin cambios atribuibles al intento. Un vencimiento debido de una solicitud se verifica separadamente. |
| E6 — titularidad | Paciente intenta cancelar o consultar un turno ajeno | Denegado; no cambia datos ni ocupación y no revela historia ajena. |
| E7 — origen Profesional | Profesional cancela en su agenda con motivo | Cancelación persistida; paciente ve motivo y origen Profesional; libera horario, conserva historial, sin ausencia, multa ni notificación automática. |
| E8 — origen Secretaría | Secretaría cancela en cualquiera de las agendas con motivo | Mismos efectos, origen Secretaría distinguible de Profesional/Paciente. No equivale a aceptar/rechazar pendientes por #284. |
| E9 — motivo requerido | Personal intenta cancelar sin motivo | Rechazo sin cambiar estado, ocupación ni datos históricos. No aplicar este requisito al Paciente. |
| E10 — agenda ajena | Profesional intenta cancelar, marcar asistencia/ausencia o leer historial de otra agenda | Denegado sin cambios ni exposición de actividad ajena, aunque comparta paciente. |
| E11 — asistencia y ausencia | Profesional propio y Secretaría, por separado, registran presencia y ausencia de turnos confirmados | `attended` o `no_show` persistido según la acción; resultado consultable por actores autorizados y paciente propio. No se crean multas. |
| E12 — vencido no es ausencia | Se intenta confirmar o atribuir ausencia a solicitud `expired` | No se convierte el vencimiento en confirmación/ausencia; permanece vencida en historia. |
| E13 — historial privado | Un paciente tiene turnos con dos Profesionales | Paciente ve los propios; cada Profesional sólo los de su agenda; Secretaría conserva alcance del centro; Administrador sin acceso implícito. |
| E14 — cambio de datos | Se cambia fecha, hora o tipo, un caso por cada dato | Cancelación del original más nueva reserva por canal autorizado, con reglas actuales de creación; original preservado. Sin edición directa del original ni transferencia automática de pagos. |

## 6. Dependencias, pendientes reales y aprobación

#284 es la dependencia existente de la padre #285 y conserva su alcance de
aprobación manual. Esta preparación documental es independiente: no añade
blockers, no duplica ese slice ni presume que su integración está terminada.
La integración final debe conservar los blockers de la padre y verificar los
escenarios anteriores junto al comportamiento real de #284.

Pendientes de implementación: reconciliar estados y disponibilidad, persistir
transiciones e historia, conectar operaciones autorizadas e interfaz y ejecutar
las pruebas de E1–E14. Deben coordinarse mecanismo de vencimiento, respuestas de
operaciones y representación de motivo/origen. Son decisiones técnicas futuras,
no requisitos de producto nuevos ni funcionalidad entregada por esta unidad.
No se fija aquí una ventana temporal para marcar asistencia, correcciones entre
resultados terminales ni otras transiciones que las fuentes no precisan.

**Aprobación explícita del contrato: otorgada por el usuario en esta conversación.**
Constancia textual: «apruebo el contrato, procede con el cierre formal de la subissue».
La aprobación corresponde a la versión documental presentada, con E1–E14 y las
limitaciones de evidencia registradas. Se conserva en [la constancia de #376](https://github.com/Team-Origen/origen/issues/376#issuecomment-6716373759)
una copia del contrato aprobado. #376 se cerró inicialmente con sus criterios
documentales marcados, pero el usuario corrigió el procedimiento: «antes de cerrar
la issue deberías haber vinculado el PR de la rama en la que documentaste el contrato».
Se reabrió para vincular el PR y permanecer abierta hasta su integración. La
aprobación del contrato se mantiene; no se designan nuevos aprobadores ni se
atribuye esta aprobación a la resolución histórica de #271. No certifica la
implementación ni el cierre de #285.

## 7. Verificación y límites de evidencia

- Código encontrado y pruebas leídas: matriz de la sección 4.
- Pruebas funcionales ejecutadas: **ninguna**. No hay RED/GREEN significativo
  para esta modificación exclusivamente documental; no se certifica backend,
  interfaz, liberación efectiva de horario ni integración.
- Verificación de esta unidad: enlaces locales, cobertura documental de los
  criterios de #376 y whitespace, incluyendo el archivo nuevo no seguido por Git.
  Los resultados observados se informan en la entrega.
- Durante la preparación, GitHub se consultó sólo en lectura. Tras la aprobación
  explícita, el usuario autorizó registrar la evidencia y cerrar #376. Luego
  autorizó reabrirla, aplicar `status:approved`, publicar la rama y crear el PR
  vinculado, sin merge. No se añaden dependencias ni se certifica funcionalidad.
