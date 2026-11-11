# Integración #387 — Pagos simples y corrección

Estado: **entrega aprobada por el usuario por ahora**, con los límites de verificación registrados. Última suite completa de la implementación: 1169 aprobadas, 35 omitidas y 8 excluidas, exit 0. La aprobación humana no sustituye el dictamen independiente ni la comprobación en navegador, que siguen sin evidencia disponible. El usuario autorizó commits, publicación y PRs con `Refs #387`, sin cierre automático ni merge. `status:approved` agregado a #387 por autorización explícita. Se conserva la evidencia histórica de fallos y resultados anteriores.

## Alcance y fuentes

- Padre: [#287](https://github.com/Team-Origen/origen/issues/287).
- OpenSpec: `health-center-beta-core`, `openspec/changes/health-center-beta-core/`, slice 12 de 17 / integración [#387](https://github.com/Team-Origen/origen/issues/387).
- Contrato aprobado: [#384](../contracts/384-pagos-simples-correccion.md), especialmente D1/D2 y escenarios P1–P15.
- Base original: `32d1489`, merge de #478 en develop; base actualizada por fast-forward a `7372371` antes de publicación. Tracker `feat/387-payment-integration-verification`; estrategia elegida: feature-branch-chain, con slices Paciente y Staff.

### Condiciones previas verificadas

Consulta real a GitHub: #384, #385, #386 y #285 están cerradas. Se leyeron los comentarios de aprobación y las limitaciones, no sólo los estados:

- #384: aprobación explícita del contrato y merge #453.
- #385: aprobación técnica backend, publicación en cadena #474–#478. Sus comentarios históricos LOCALONLY son anteriores a la integración; el HEAD base incluye el merge #478.
- #386: aceptación explícita del mock visual mediante #469, **no** de persistencia ni permisos financieros reales. La corrección de pagos conservados en cancelados quedó diferida a integración.
- #285: cierre autorizado con evidencia de integración #379 del ciclo operativo. No certifica pagos.

## Recorrido real incorporado

1. Profesional entra por navbar → Agenda; Secretaría por navbar → Agenda del centro. No se agregaron rutas ni filtros. Las tarjetas conservan su estructura y sus acciones operativas. El botón celeste «Ver turno», junto a las acciones, abre un único modal; las entradas del historial también lo abren. No se muestran formularios financieros directamente en tarjetas ni en el historial.
2. El modal reutiliza la estructura y el flujo del mock original #386: encabezado con cierre, horario/duración, estado operativo, sección de pago y acción por pasos. «Editar precio» y «Registrar pago» muestran únicamente su formulario correspondiente; «Cancelar» abandona la acción sin modificar datos. Escape o el botón de cierre salen del detalle y restauran el foco. `AppointmentPaymentComponent` consulta y modifica exclusivamente mediante `Booking.get_payment`, `update_final_price`, `record_payment`, `revert_payment` y `list_payment_actions`, con la sesión del servidor. No recibe identidad, fecha ni importe cobrado del cliente.
3. El precio individual pendiente se guarda sin cambiar el snapshot. El pago total usa efectivo o transferencia y sólo se ofrece para confirmado/asistido; la API conserva la validación real, incluso si una pantalla quedó desactualizada.
4. Pagado bloquea el formulario de precio. «Corregir marca pagada» abre una confirmación breve; «Volver» no modifica el dominio. Confirmar vuelve a pendiente sin exigir motivo. El historial interno conserva pago/corrección con método, importe, actor y fecha.
5. Cancelar o marcar ausencia conserva la marca pagada. Corregirla continúa permitido y habilita el precio; no habilita registrar un nuevo pago en cancelado/ausente.
6. Paciente entra por navbar → Mis turnos y consulta el precio final persistido y el estado pendiente/pagado. No se muestran método, actor, fecha ni historial financiero ni controles de mutación. Si la consulta falla se muestra indisponibilidad, no un precio histórico como si fuera final.
7. Administrador no recibe acceso financiero. No se cambió la autorización del backend, ni se implementó #288, devoluciones, parciales, comprobantes o traslados.

## Evidencia reproducible observada

Todas las pruebas usan PostgreSQL aislado por partición, sin borrar bases preexistentes. Los datos de preparación son ficticios; las acciones de interfaz bajo prueba llaman al dominio y persistencia reales, no al preview en memoria de #386.

| Paso | Comando | Resultado observado |
| --- | --- | --- |
| Base sin cambios | `MIX_TEST_PARTITION=_387_baseline mix test` | exit 0; 1158 aprobadas, 35 omitidas, 8 excluidas |
| RED personal | `MIX_TEST_PARTITION=_387_integration mix test test/origen_web/live/payment_integration_live_test.exs` | exit 2; 7 fallos por controles inexistentes |
| Primer intento GREEN personal | mismo comando después de conectar | exit 2; 1 aprobada, 6 fallos; expectativas de actor/error/HTTP y precisión no coincidían con contrato existente |
| GREEN personal | mismo comando tras corregir expectativas | exit 0; 7 aprobadas |
| RED Paciente | `MIX_TEST_PARTITION=_387_integration mix test test/origen_web/live/patient_appointments_live_test.exs` | exit 2; 5 aprobadas y 1 fallo por falta de precio final/estado |
| GREEN y regresiones UI | `MIX_TEST_PARTITION=_387_integration mix test test/origen_web/live/patient_appointments_live_test.exs test/origen_web/live/payment_integration_live_test.exs test/origen_web/live/professional_agenda_live_test.exs test/origen_web/live/secretary_agenda_live_test.exs` | exit 0; 58 aprobadas |
| Suite final | `MIX_TEST_PARTITION=_387_integration mix test` | exit 0; 1166 aprobadas, 35 omitidas, 8 excluidas |
| Estructura | `mix format --check-formatted` sobre los seis archivos Elixir modificados/nuevos; `git diff --check` | exit 0 |

Las pruebas nuevas cubren edición, efectivo/transferencia, confirmado/asistido, cero, pago/reversión/nuevo pago, actor/fecha/historia, cancelación/ausencia con pago y corrección, rechazo de repago terminal, precios negativos/malformados, solicitud impaga, alcance profesional, operación de Secretaría, denegación de Administrador, persistencia al reingresar y consulta reducida de Paciente. Las pruebas previas de dominio se conservaron y corrieron en la suite. El snapshot se verifica por la historia pública; la preservación de catálogo sigue cubierta por pruebas existentes del backend.

## Corrección del flujo visual solicitada

Se retiró la presentación de formularios dentro de las tarjetas. Se revisó el mock `appointment_payment_preview_live.ex:356–507` y se reutilizó su organización de detalle y acciones por pasos, sin volver a los datos simulados ni introducir su bloqueo de corrección en cancelados. La selección del turno se limita a las proyecciones autorizadas cargadas por la agenda. Existe un solo modal por pantalla, incluso cuando el mismo turno aparece en agenda e historial; las acciones de cancelación, asistencia y ausencia permanecen donde estaban.

- RED antes del cambio: 8 fallos de las nuevas expectativas de modal (`_387_modal`), exit 2.
- Primer intento GREEN: 58/59; falló un helper de prueba que pretendía volver a abrir una edición ya abierta tras un rechazo. No se cambió la regla de validación del dominio.
- GREEN final: 59 aprobadas, exit 0, en los cuatro archivos de pruebas UI indicados anteriormente.
- Suite completa posterior al modal: `MIX_TEST_PARTITION=_387_modal mix test`, exit 0; 1167 aprobadas, 35 omitidas y 8 excluidas. `mix format --check-formatted` sobre el componente, ambas agendas y las pruebas de integración, más `git diff --check`: exit 0. El resultado de 1166 anterior se conserva como evidencia del estado previo. El log final conserva el ruido de ownership del sandbox observado también en la base; no se omitieron los resultados fallidos históricos.

## Disposición del historial del Profesional

Corrección visual posterior solicitada por el usuario: el título de cada tarjeta del historial operativo muestra `tipo de consulta — nombre del paciente`; ya no muestra el número de turno. «Ver turno» está dentro de la tarjeta, inmediatamente después del horario y alineado a la izquierda. La etiqueta de estado permanece arriba a la derecha, también en pantallas angostas. Se conservan los motivos/orígenes de cancelación, las acciones y el modal existente. La agenda diaria y las tarjetas de Secretaría/Paciente no cambian por este ajuste.

Para mostrar el nombre también en fechas históricas, la consulta ya autorizada y limitada al Profesional agrega `patient_name` mediante la identidad del paciente del propio turno. No se amplía el alcance de lectura; si no hay identidad personal registrada se muestra «Paciente». El componente compartido conserva sus valores por defecto para Secretaría y recibe una disposición opcional sólo desde el historial profesional.

- Preparación de prueba: un primer fallo usó `id` en lugar de `session_id` al leer la sesión; se corrigió antes del RED funcional.
- RED funcional: 37 aprobadas y 1 fallo por el título sin nombre de paciente.
- GREEN: 64 aprobadas, exit 0, incluyendo agenda profesional, agenda de Secretaría, pagos integrados y ciclo operativo.
- Primera suite completa de este ajuste: exit 2; 1167/1168 aprobadas, 35 omitidas y 8 excluidas. Falló únicamente una aserción anterior de `professional_agenda_lifecycle_live_test.exs` que exigía mostrar `#<id>`: se actualizó para identificar ambas tarjetas por ID DOM, preservar los estados/motivos y comprobar que no muestran `Turno <id>`, acorde al pedido. La verificación posterior `MIX_TEST_PARTITION=_387_history mix test test/origen_web/live/professional_agenda_lifecycle_live_test.exs` y luego `MIX_TEST_PARTITION=_387_history mix test` terminó con exit 0; suite completa: **1168 aprobadas, 35 omitidas y 8 excluidas**. Formato y `git diff --check`: exit 0. Los controles de formato/diff encadenados a la primera suite no se ejecutaron porque ésta falló; sí se ejecutaron en la comprobación final. La revisión independiente acotada de S14 también falló antes de emitir dictamen (`assistant reported an error`); no se atribuye aprobación independiente ni se reintenta.

## Información visible en Turnos del centro (Secretaría)

Corrección S15: las tarjetas diarias y el historial muestran el nombre real del paciente y `Profesional: nombre apellido`, conservando el tipo de consulta. Se elimina el número de turno visible. El modal «Detalle del turno» muestra los mismos nombres y el profesional correspondiente, sin alterar sus pagos, fechas, horarios, estados ni controles. Las clases y la ubicación de los elementos existentes no se reorganizan; el nombre del paciente del historial permanece en su contenedor original.

La proyección ya autorizada de Secretaría obtiene las identidades del paciente y del profesional de cada turno, incluso con perfiles profesionales incompletos que no aparecen en el selector de agenda. Las uniones opcionales mantienen los turnos sin identidad registrada; se muestran «Paciente no identificado» o «Profesional no identificado», nunca un nombre inventado ni un ID como sustituto. Los IDs internos y DOM permanecen para que los eventos existentes funcionen.

- Primer intento RED: 7/9; un fixture usó `DNI` en lugar del valor permitido `dni`. Corregido antes del RED funcional.
- RED funcional: 7/9, por nombres ausentes y el fallback con ID.
- Primer GREEN: 71/73; pasó la prueba nueva con dos profesionales diferentes, tarjetas, historial y modal. Las dos pruebas anteriores que aún exigían IDs visibles se actualizaron al nuevo texto y a IDs DOM; se conservan las aserciones sobre cancelación, rechazo de IDs forjados y ausencia de mutación.
- Verificación final job-24: **73 pruebas focalizadas aprobadas** y **1169 aprobadas, 35 omitidas y 8 excluidas** en la suite completa, exit 0. Formato y `git diff --check`: exit 0. El log conserva mensajes de ownership del sandbox, aunque las pruebas terminaron sin fallos. La revisión independiente y visual de la integración continúa sin evidencia disponible; no se atribuye aprobación ni se reintenta automáticamente el verificador no disponible.

## Límites y decisión pendiente

- El agente `gentle-ai-verify` falló antes de devolver un dictamen. **No existe verificación independiente completada de esta integración.** No se volvió a lanzar ni se reemplazó por una autoaprobación.
- El intento original `tidewave_browser_eval` con acción `help` no pudo conectarse a `http://localhost:4000/tidewave/mcp`. En la corrección posterior Phoenix responde HTTP 200 y el servidor Tidewave informa que no hay navegador conectado a su página de control. No hay evidencia de navegador, inspección responsiva ni interacción manual. LiveView automatizado no equivale a esa evidencia.
- `gentle-ai review mode status` indicó RDD apagado. ASSESS no estuvo disponible (`package-local-binary-missing`); se trató como alto riesgo para requerir verificación independiente. No se inició una revisión nativa ni se modificó el switch.
- Las 35 pruebas omitidas y 8 excluidas no se presentan como aprobadas; `postgres_security` permanece excluida. La suite imprimió ruido de ownership del sandbox tanto en la base como al final; ambos procesos terminaron con exit 0. No se certifica un rol PostgreSQL de producción ni concurrencia nueva con conexiones distintas.
- No se modificó el mock de #386 ni se presenta como integración real. No se ejecutaron migraciones destructivas, rollback ni backfill sobre datos existentes.
- La estrategia elegida es cadena sobre rama de funcionalidad. No se creó la cadena de entrega porque todavía no se autorizaron commits/publicación.

**Para aprobar #387/#287:** resolver la verificación independiente no disponible y la evidencia de navegador, revisar esta entrega y registrar aprobación humana explícita. Este documento no concede esa aprobación ni cierra issues.
