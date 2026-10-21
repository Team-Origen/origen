# Contrato #321: resolución de solicitudes con aprobación manual

**Estado: borrador de contrato para #321, preparado por Lucca Giordana (`ChordanDev`).**
Este documento prepara [#322 (Backend)](https://github.com/Team-Origen/origen/issues/322) y [#323 (Frontend)](https://github.com/Team-Origen/origen/issues/323). No implementa código de aplicación ni acredita el cierre de [#284](https://github.com/Team-Origen/origen/issues/284) o [#324 (Integración)](https://github.com/Team-Origen/origen/issues/324).

---

## Alcance y fuentes

- **Contrato:** [#321](https://github.com/Team-Origen/origen/issues/321), Sprint 3, issue padre [#284](https://github.com/Team-Origen/origen/issues/284).
- **OpenSpec:** cambio `health-center-beta-core`, ruta `openspec/changes/health-center-beta-core/`, alcance Sprint 3 / parent #284 / contract.
- [Propuesta beta](../../../openspec/changes/health-center-beta-core/proposal.md) y [diseño](../../../openspec/changes/health-center-beta-core/design.md).
- [Reserva de turnos y ciclo de vida](../../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md):
  - **Requisito: Modalidad de aprobación y ocupación (`Approval and occupancy`):**
    - Todo Profesional elige entre aprobación automática (`automatic`) o manual (`manual`).
    - En modo automático, las reservas de Paciente y Secretaría se confirman directamente (`confirmed`).
    - En modo manual, las reservas de Paciente nacen como solicitud (`requested`); una subconfiguración única del profesional define si Secretaría confirma directamente (`confirmed`) o genera solicitudes (`requested`).
    - Las reservas creadas por el propio Profesional nacen siempre confirmadas (`confirmed`).
    - **Ocupación:** Una solicitud pendiente (`requested`) ocupa el slot del horario, impidiendo reservas solapadas.
    - **Resolución exclusiva:** Únicamente el Profesional dueño de la agenda puede aceptar o rechazar solicitudes pendientes.
    - La aceptación pasa la solicitud a confirmada (`confirmed`) manteniendo la ocupación.
    - El rechazo cancela la solicitud (`cancelled`) y **libera inmediatamente el slot**.
    - **Inmutabilidad de pendientes ante cambio de modalidad:** Modificar la modalidad de aprobación afecta únicamente a reservas nuevas; no resuelve ni altera las solicitudes pendientes existentes.
- [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md):
  - Sin vencimiento automático en tiempo real dentro de este slice (pertenece al ciclo de vida global).
  - Sin cancelación operativa por motivo ni gestión de inasistencias/multas.
- [Guía de trabajo beta](../GUIA_TRABAJO_BETA.md):
  - Desbloqueo de backend e interfaz contra el contrato sin requerir la implementación completa del otro.
  - Distinguir código encontrado, pruebas leídas y pruebas ejecutadas con resultado observado.

---

## Reglas de negocio y matriz normativa

### 1. Matriz de canales y modalidades de reserva

| Canal / Origen | Modo Automático | Modo Manual (`secretary: confirmed`) | Modo Manual (`secretary: requested`) |
| --- | --- | --- | --- |
| **Paciente autónomo** | Nace `confirmed` | Nace `requested` | Nace `requested` |
| **Secretaría asistida** | Nace `confirmed` | Nace `confirmed` | Nace `requested` |
| **Profesional propio** | Nace `confirmed` | Nace `confirmed` | Nace `confirmed` |

- En todos los casos donde el turno nace como `requested`, el horario queda **ocupado** en la agenda. Ningún otro paciente o secretaría puede reservar en ese slot mientras la solicitud esté pendiente.
- Al nacer la solicitud (`requested`), se establece la relación `ProfessionalPatientRelationship` entre el profesional y el paciente.

### 2. Resolución de solicitudes pendientes (Aceptar / Rechazar)

1. **Aceptar solicitud (`accept_request`):**
   - Transición de estado: `requested` $\rightarrow$ `confirmed`.
   - Efecto sobre el horario: El slot **continúa ocupado**.
   - Actor autorizado: **Únicamente el Profesional dueño** de la agenda correspondiente al turno.
   - Emisión de auditoría de confirmación de solicitud.

2. **Rechazar solicitud (`reject_request`):**
   - Transición de estado: `requested` $\rightarrow$ `cancelled`.
   - Efecto sobre el horario: El slot **queda libre inmediatamente** para que pueda ser reservado por otro turno.
   - Actor autorizado: **Únicamente el Profesional dueño** de la agenda correspondiente al turno.
   - Emisión de auditoría de rechazo/cancelación de solicitud.

3. **Restricción de estado:**
   - Sólo turnos en estado `requested` pueden ser aceptados o rechazados. Intentar aceptar o rechazar un turno ya confirmado (`confirmed`), cancelado (`cancelled`) o atendido (`attended`) es rechazado con error de transición inválida (`{:error, :invalid_status_transition}`).

### 3. Cambio de modalidad de aprobación

1. El Profesional puede alternar su configuración de aprobación entre `automatic` y `manual` (y su subconfiguración de secretaría).
2. El cambio surte efecto únicamente a partir de las **nuevas solicitudes o reservas** que ingresen.
3. Las solicitudes pendientes creadas con anterioridad **no se resuelven automáticamente ni cambian de estado**: permanecen en estado `requested` hasta que el profesional las resuelva explícitamente o expiren.

---

## Matriz de permisos y delimitación estricta

| Actor | Operación | Resultado esperado |
| --- | --- | --- |
| **Profesional dueño** | Aceptar solicitud pendiente propia | Autorizado (`{:ok, appointment}`) |
| **Profesional dueño** | Rechazar solicitud pendiente propia | Autorizado (`{:ok, appointment}`) |
| **Profesional ajeno** | Aceptar/Rechazar solicitud de otro profesional | Denegado (`{:error, :unauthorized}`) |
| **Secretaría** | Aceptar/Rechazar cualquier solicitud | **Denegado** (`{:error, :unauthorized}`) |
| **Administrador** | Aceptar/Rechazar solicitudes de agenda | **Denegado** (`{:error, :unauthorized}`) |
| **Paciente** | Aceptar/Rechazar solicitudes | **Denegado** (`{:error, :unauthorized}`) |
| **Anónimo / Inválido** | Cualquier operación de resolución | Denegado (`{:error, :unauthorized}`) |
| **Profesional dueño** | Cambiar su modalidad de aprobación | Autorizado |
| **Secretaría / Admin** | Modificar modalidad de aprobación profesional | Denegado (`{:error, :unauthorized}`) |

---

## Mapa de reutilización y componentes

| Clasificación | Componente / Archivo | Detalle |
| --- | --- | --- |
| **Reutilizar** | `lib/origen/booking/appointment.ex` | Schema de turnos, estados `requested`, `confirmed`, `cancelled`. |
| **Reutilizar** | `priv/repo/migrations/20260927100000_add_appointment_overlap_exclusion_constraints.exs` | Restricción GiST en PostgreSQL que ya excluye `status NOT IN ('cancelled', 'rejected')`, liberando el slot automáticamente al cancelar. |
| **Reutilizar** | `lib/origen/booking/overlap.ex` | Motor de solapamiento en Elixir que ya trata a `cancelled` y `rejected` como liberadores de slot. |
| **Reutilizar** | `lib/origen/appointments/assisted_booking.ex` | Servicio de agendamiento asistido que ya respeta `approval_mode`. |
| **Extender (#322)** | `lib/origen/booking.ex` / `lib/origen/appointments/approval.ex` | Contexto de dominio con operaciones `accept_request/2` y `reject_request/2` que validan propiedad, estado previo y atomicidad. |
| **Extender (#322)** | `priv/repo/migrations/` & `agenda_settings` | Campo `secretary_approval_mode` (`confirmed` / `requested`) para la subconfiguración única de Secretaría. |
| **Extender (#323)** | `lib/origen_web/live/professional_agenda_live.ex` | Renderizar botones "Aceptar" y "Rechazar" en cada tarjeta de turno con estado `requested`, con confirmación y actualización reactiva. |
| **Extender (#323)** | Configuración del Profesional | Controles para que el profesional seleccione entre aprobación automática y manual (con subconfiguración de secretaría). |

---

## Escenarios verificables para Backend (#322) y Frontend (#323)

| ID | Escenario / Acción | Resultado esperado |
| --- | --- | --- |
| **C1** | Profesional con aprobación manual recibe solicitud de paciente; el turno nace en estado `requested`. | El turno ocupa el slot y ningún otro paciente o secretaría puede agendar en ese horario. |
| **C2** | Profesional dueño acepta la solicitud `requested`. | El turno pasa a estado `confirmed`, el slot continúa ocupado y se audita el evento. |
| **C3** | Profesional dueño rechaza la solicitud `requested`. | El turno pasa a estado `cancelled`, el slot queda libre inmediatamente para nuevas reservas. |
| **C4** | Otro horario disponible se reserva en el slot liberado tras un rechazo. | La nueva reserva en ese mismo slot es exitosa sin colisión. |
| **C5** | Secretaría o Administrador intenta llamar a `accept_request` o `reject_request`. | La operación es denegada con `{:error, :unauthorized}` sin alterar el turno. |
| **C6** | Profesional A intenta aceptar o rechazar una solicitud perteneciente a la agenda de Profesional B. | Denegado con `{:error, :unauthorized}` sin mutaciones. |
| **C7** | Intento de aceptar o rechazar un turno que ya está en estado `confirmed` o `cancelled`. | Rechazado con `{:error, :invalid_status_transition}`. |
| **C8** | Profesional cambia su configuración de aprobación de manual a automática teniendo solicitudes pendientes. | Las solicitudes previas permanecen en estado `requested`; las nuevas reservas nacen como `confirmed`. |
| **C9** | En modo manual con subconfiguración de secretaría en `confirmed`, secretaría agenda un turno. | El turno de secretaría nace como `confirmed`. |
| **C10** | En modo manual con subconfiguración de secretaría en `requested`, secretaría agenda un turno. | El turno de secretaría nace como `requested` y ocupa el slot. |
| **C11** | En `ProfessionalAgendaLive`, cada turno con estado `requested` muestra botones de "Aceptar" y "Rechazar". | Las solicitudes se distinguen visualmente de los turnos confirmados y presentan acciones exclusivas del dueño. |
| **C12** | Al hacer clic en "Aceptar" o "Rechazar" en la vista de agenda, la UI se actualiza reactivamente. | Al aceptar, el badge cambia a "Confirmado". Al rechazar, el turno refleja la cancelación o se remueve de la lista activa. |

---

## Evidencia de verificación

### Código encontrado y pruebas leídas
- Agenda profesional LiveView: `lib/origen_web/live/professional_agenda_live.ex:1-350`.
- Pruebas de agenda profesional: `test/origen_web/live/professional_agenda_live_test.exs:1-250`.
- Restricciones GiST de exclusión: `priv/repo/migrations/20260927100000_add_appointment_overlap_exclusion_constraints.exs:25-50`.
- Servicio de reserva asistida con soporte de approval mode: `lib/origen/appointments/assisted_booking.ex:75-125`.

### Ejecución observada
- Ejecución previa de la suite completa: 692 pruebas aprobadas, 0 fallas (`mix test`).
- Verificación de formateo estricto: `mix format --check-formatted` superado limpiamente.

---

## Próximos pasos

1. **Aprobación de #321:** Registro del contrato en la issue.
2. **Backend [#322](https://github.com/Team-Origen/origen/issues/322):**
   - Incorporar `secretary_approval_mode` en `agenda_settings`.
   - Implementar `accept_request/2` y `reject_request/2` en contexto con validación de dueño y liberación de slot.
   - Escribir suite de pruebas de backend cubriendo C1–C10.
3. **Frontend [#323](https://github.com/Team-Origen/origen/issues/323):**
   - Agregar acciones de Aceptar / Rechazar en `ProfessionalAgendaLive`.
   - Incorporar selector de modo de aprobación en configuración del profesional.
   - Tests de LiveView para C11–C12.
4. **Integración [#324](https://github.com/Team-Origen/origen/issues/324):**
   - Verificación global de la funcionalidad padre #284 una vez aprobadas las subissues.
