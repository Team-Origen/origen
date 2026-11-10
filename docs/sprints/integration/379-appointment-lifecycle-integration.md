# #379 — Resultado técnico de integración del ciclo de turnos

## Resultado primero

La corrección L24 queda verificada: el primer slice independiente pasó 1/1 y
el focused final pasó 62/62 con los cuatro escenarios authored y 58 pruebas
complementarias. Después de corregir el helper, el parent volvió a observar
`1080 passed, 32 skipped, 8 excluded`, seed 0, exit 0 (job 5, 65,7 segundos).
`mix compile --warnings-as-errors` y formato también pasaron. Esto no es aceptación
humana final, cierre de #285 ni auto-cierre de #379; el parent conserva la
revisión de prueba-gap, la decisión de slices y la publicación sin merge.

## Evidencia y límites

- **Booking real:** las filas de `appointments` de los cuatro escenarios se
  originan en UI de Paciente o Secretaría. Identidades, cuentas internas,
  perfiles profesionales, disponibilidad, agenda y catálogo son fixtures de
  configuración/identidad; no sustituyen el dominio de booking ni su
  persistencia.
- **Persistencia:** los escenarios consultan filas y auditorías persistidas,
  recargan LiveViews por rol y consultan historial después de las operaciones.
- **Expiry:** el escenario authored ejecuta el sweep público
  `Booking.expire_due_requested/1`. No prueba un timer autónomo. El worker y su
  prueba existente son evidencia separada dentro del fullsuite.
- **Complemento:** el focused L24 suma 4 escenarios nuevos y 58 pruebas
  existentes; el fullsuite del parent ejecutó nuevamente el conjunto completo
  después de la corrección L24. Browser real,
  navegación atrás/adelante, cloud y checks `postgres_security` excluidos no se
  presentan como evidencia.
- **Entrega:** no hubo commits, push, PR, merge ni cambio de issue en este
  worker. `status:approved` de #379 fue aplicado previamente por el parent;
  no se inventa aceptación final ni se elige referencia de cierre.

## Matriz S2–S9

| S# | Evidencia observada | Resultado y límite |
|---|---|---|
| S2 | Navbar y navegación de Paciente, Profesional y Secretaría; agendas/historial accesibles desde sus flujos LiveView. | **Verificado** en focused L24 62/62; fullsuite posterior pendiente. |
| S3 | Paciente reserva; Profesional ve y resuelve solicitud; Secretaría reserva asistidamente; filas sobreviven reload e historial por rol. | **Verificado** con UI y persistencia reales; no es una prueba de datos simulados. |
| S4 | Alcance por rol, cancelación antes del inicio, motivo obligatorio del personal, rechazo sin mutación/auditoría exitosa, asistencia/no-show sólo confirmado y rechazo de asistencia del Paciente. | **Verificado** por los 4 escenarios y regresiones complementarias del focused L24. |
| S5 | Expiry libera slot y conserva historial; cancelaciones de Paciente/Profesional/Secretaría; origen/motivo; asistencia/ausencia; reemplazos separados por fecha, hora y tipo. | **Verificado** para el sweep público y operaciones reales. Timer autónomo: sólo evidencia separada del worker existente. |
| S6 | Las aprobaciones y dependencias hermanas están registradas en el historial de trabajo; el resultado técnico no sustituye la aceptación final. | **Pendiente de aceptación humana**, sin cierre de #285. |
| S7 | No se agregan WhatsApp, multas automáticas, notificaciones, pagos, bloqueos ni reprogramación directa. La UI usa el copy exacto `Podés cancelar hasta antes del inicio, sin multa.` | **Verificado** por alcance y aserciones; no amplía producto. |
| S8 | La autorización de publicación y cadena a `develop` existe; este worker no publicó. | **Pendiente de ejecución del parent**, sin merge. |
| S9 | #379 tiene `status:approved` aplicado por autorización explícita del owner. | **Registrado**; no equivale a aceptación final ni auto-cierre. |

## Qué revisar primero

1. `test/origen_web/live/appointment_lifecycle_integration_test.exs`: cuatro
   escenarios, navegación, operaciones reales, auditoría, privacidad,
   reemplazos y sweep público.
2. `test/support/appointment_lifecycle_integration_helpers.ex`: helper completo;
   sólo fixtures de identidad/configuración y recorridos UI para crear bookings.
3. `tmp/issue-379/focused-l24-firstslice.log`: primer slice independiente, 1/1.
4. `tmp/issue-379/focused-l24-final.log`: focused final, 62/62.
5. Resultado del parent: job completo histórico, 1080/32/8, exit 0; formato previo pasado. Requiere observación posterior a L24.
5. `openspec/changes/health-center-beta-core/proposal.md`: referencia inversa
   de #379 bajo el cambio OpenSpec.

## Cobertura authored y complementaria

| Corte | Contenido | Prueba |
|---|---|---|
| Authored 1 | Primer flujo Paciente → Profesional: navbar, booking real, resolución, auditoría y reload del historial. | `stage1integration.exs` y `stage1evidence.md`. |
| Authored final | Los 4 escenarios: resolución/reload; cancelación profesional y reemplazos; cancelación/asistencia de Secretaría; expiry, privacidad y límites por rol. | `finalintegration.exs`, 385 líneas, focused L24 62/62. |
| Complemento existente | Manual approval, booking Patient/Professional/Secretary, agenda/historial, attendance, lifecycle/history y database calendar/expiry. | 58 casos del focused; fullsuite 1080/32/8. |

Métodos authored exactos: `patient request resolves through the professional UI
and survives role reloads`; `professional cancellation requires a reason,
preserves rejected state, and replacement is a new booking`; `secretary
cancellation and attendance use real bookings and remain visible after reload`;
`public expiry sweep releases the slot and history remains private across roles`.
El helper completo tiene 258 líneas después de la corrección L24.

## Historia de ejecución

| Momento | Resultado histórico conservado |
|---|---|
| Preflight inicial | `pg_ctl` no pudo crear el lock en `/var/run/postgresql`; cero tests. Cluster y datos del owner intactos. |
| Continuación previa | Archive Hex incompatible con OTP28 durante `mix ecto.create`; cero tests, sin instalar ni mutar dependencias. |
| L10 | El helper authored falló compilando `get/2`; cero tests. La corrección exacta añadió `Phoenix.ConnTest` y `@endpoint`, y la compilación standalone posterior pasó. |
| L15, primer focused | La fixture de disponibilidad tenía sólo cinco días; se observó fallo authored antes de cobertura funcional completa. |
| L15, batch 1 | La disponibilidad de siete días permitió ejecutar; quedaron 4 fallos authored de selector/orden/aserciones. Resultado 58/62. |
| L15, batch 2 | Se corrigieron esos defectos salvo la aserción amplia de `multa`; resultado 61/62. Ambos batches originales quedaron consumidos. |
| L18 | Una única corrección autorizada cambió esa aserción por el copy público sin multa. Focused exacto: 62/62, exit 0. |
| L20 | Parent job 2 histórico: fullsuite exit 0, 1080 passed, 32 skipped, 8 excluded, seed 0; formato pasado antes de L24. |
| L22 | El primer slice independiente falló 0/1 por `String.to_existing_atom("requested")` en el helper; la suite completa previa lo ocultaba por orden de carga. El árbol final fue restaurado sin cambios. |
| L24 | Una única corrección authored sustituyó ambos `String.to_existing_atom/1` por mapas finitos canónicos (`manual`/`automatic` y `requested`/`confirmed`). Stage1 independiente: 1/1. Focused exacto: 62/62. |
| Posterior a L24 | Parent job 5: fullsuite 1080 passed, 32 skipped, 8 excluded, seed 0, exit 0; formato y `mix compile --warnings-as-errors` pasaron. |

## Runtime y trazabilidad

- Runner probado: `tmp/issue-379/runtime-env.sh`, con Elixir
  `/home/samu/.asdf/installs/elixir/1.20.3-otp-28/bin/elixir`, OTP28 y
  `MIX_ARCHIVES` local existente.
- PostgreSQL aislado: data directory
  `/home/samu/Documents/origen/tmp/issue-379/postgres18-cluster`, socket
  `/home/samu/Documents/origen/tmp/issue-379/s`, puerto `55443`, partición
  `_issue379_integration`. No se usó la base/puerto del owner.
- Logs preservados: `preflight.log`, `preflight-continuation.log`,
  `preflight-l10.log`, `focused-l15-1.log`, `focused-l15-2.log`,
  `focused-l15-3.log`, `focused-l18.log`, `focused-l24-firstslice.log`,
  `focused-l24-final.log` y sus logs de PostgreSQL.

## Estado posterior a L24

La verificación independiente del primer corte de PR falló históricamente 0/1
porque `String.to_existing_atom("requested")` dependía de que otra prueba
cargara el átomo. L24 corrigió únicamente el helper con mapas finitos de valores
canónicos, sin cambiar producción ni el test authored final. El stage1 pasó 1/1
y el focused final pasó 62/62, usando el mismo runner, partición preparada y
cluster propio.

El fullsuite posterior a L24 pasó: `1080/32/8`, seed 0, exit 0. Los resultados
anteriores se conservan en la cronología, no sustituyen esta nueva observación. No se creó ningún commit ni PR. El PostgreSQL propio quedó arriba para
la continuación autorizada del parent, con `data_directory` y socket de proyecto
ya validados; el runtime del propietario no se modificó.

## Estado de entrega

T2/T3 tienen evidencia técnica verde posterior a L24. T4 permanece en manos
del parent: reconciliar commits y slices, crear la cadena a `develop`, verificar
CI remoto y registrar limitaciones. La cadena propuesta conserva el contexto
`develop ← slice 1 ← slice 2 ← bookkeeping opcional`; los PR numbers y enlaces
anterior/siguiente son placeholders hasta que existan. No hay aceptación humana
final, aprobación inventada, cierre de #285 ni referencia de cierre automática.
