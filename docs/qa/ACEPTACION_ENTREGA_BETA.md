# Contrato de aceptación de entrega beta

> **Estado:** contrato aprobado en [#325](https://github.com/Team-Origen/origen/issues/325#issuecomment-6499068891) para la versión `c59cf6b` y publicado por [PR #408](https://github.com/Team-Origen/origen/pull/408); ejecución de la entrega beta pendiente.
> **Alcance:** definir evidencia de entrega, no implementar ni certificar la aplicación.
> **Ejecución de aceptación:** no ejecutada por esta tarea. Ningún resultado está aprobado.

Este artefacto separa el acuerdo sobre **qué demostrar** de la aprobación de **lo entregado**.
La beta académica debe demostrar los seis resultados siguientes sin recortar el alcance funcional aprobado.
Escribir este contrato no produce el manual completo, datos persistidos, despliegue ni estabilización.

## Recorrido de aprobación

1. Revisar criterios, fuentes, diferencias históricas y pendientes de este contrato.
2. Registrar acuerdo humano explícito sobre la versión del contrato en #325 (hecho para `c59cf6b`; la publicación no equivale a aceptación final).
3. Realizar la verificación documental de #326 cuando sus dependencias estén aprobadas.
4. Producir y ejecutar las evidencias de entrega en el seguimiento autorizado correspondiente.
5. Resolver faltantes y registrar por separado la aceptación final de la beta.

La verificación documental de #326 y el cierre eventual de #290 no certifican la entrega final.
No se asignan aquí nuevos responsables, fechas, infraestructura ni autoridades de aprobación.
La aprobación de #325 autoriza el contrato, no despliegue, cierre de #290 ni aceptación final; la publicación documental se decidió por separado.

## Fuentes y trazabilidad

| Referencia | Función en este contrato |
| --- | --- |
| [#266 — Wayfinder](https://github.com/Team-Origen/origen/issues/266) | Alcance aprobado; el orden de implementación no excluye capacidades. |
| [#290 — Artefacto de aceptación](https://github.com/Team-Origen/origen/issues/290) | Padre del contrato y de su verificación documental. |
| [#325 — Reglas y contrato](https://github.com/Team-Origen/origen/issues/325#issuecomment-6499068891) | Criterios aprobados para `c59cf6b` y publicados en `develop` por PR #408. |
| [#326 — Verificación documental](https://github.com/Team-Origen/origen/issues/326) | Verifica por separado la definición; no acredita la entrega final. |
| [#274 — Identidad visual](https://github.com/Team-Origen/origen/issues/274#issuecomment-6691979001) | Decisión registrada y cerrada; los recursos se incorporaron por #416. Contrastar su aplicación y el manual, sin darla por aceptada aquí. |
| [#275 — Fecha académica](https://github.com/Team-Origen/origen/issues/275#issuecomment-6691042373) | Se aclaró la fecha de primera entrega académica. No resolvió proveedor, presupuesto ni detalles técnicos; corresponden a #292. |

**OpenSpec:** cambio `health-center-beta-core`, ruta `openspec/changes/health-center-beta-core/`.
Slice: contrato documental de entrega de #290, subissue #325; sin backend ni interfaz.

- [Proposal](../../openspec/changes/health-center-beta-core/proposal.md): alcance y frontera de entrega de semana 16.
- [Design](../../openspec/changes/health-center-beta-core/design.md): vocabulario, privacidad y obligaciones de evidencia.
- [Beta boundaries](../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md): pendientes y exclusiones.
- [Identidad y acceso](../../openspec/changes/health-center-beta-core/specs/patient-identity-and-access/spec.md).
- [Cuentas y configuración](../../openspec/changes/health-center-beta-core/specs/staff-accounts-and-professional-settings/spec.md).
- [Reservas y ciclo](../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md).
- [Pagos y resumen](../../openspec/changes/health-center-beta-core/specs/payments-and-period-summary/spec.md).
- [Guía de trabajo beta](../sprints/GUIA_TRABAJO_BETA.md): preparación, integración y aprobación explícita.

Las especificaciones beta definen el resultado esperado; código y documentación histórica describen el punto de partida.
Si una fuente histórica contradice la beta, no se convierte esa contradicción en criterio de éxito.
Si divergen requisitos vigentes, se registra la pregunta antes de implementar o aprobar.

## Estados de evidencia

| Estado | Uso |
| --- | --- |
| No ejecutado | Existe el criterio, pero todavía no hay ejecución observada. |
| Bloqueado | Se identifica dependencia o decisión concreta que impide ejecutar o evaluar. |
| Cumple | Hay recibo reproducible y resultado observado que satisface el criterio. |
| No cumple | La ejecución observada contradice el criterio; debe enlazarse el defecto. |

«Cumple» no equivale a aprobación humana. No se usa «no aplica» para retirar alcance aprobado.
Un criterio sin evidencia queda pendiente; una captura aislada no demuestra persistencia ni permisos de backend.
Los criterios de este contrato están acordados en #325; su ejecución y la aceptación de la beta siguen pendientes.

## Resultado 1 — Manual de usuario

**Criterio de aprobación:** una persona puede seguir el manual de la versión candidata y completar los recorridos de su rol sin instrucciones ocultas.

- [ ] Identifica versión, entorno, roles, acceso inicial y límites de la beta.
- [ ] Explica acceso Paciente por magic link y consulta propia, sin contraseña ni verificación telefónica obligatoria para reservar.
- [ ] Incluye búsqueda/alta asistida, vinculación y corrección de identidad según permisos.
- [ ] Explica configuración profesional, reservas por los tres canales y aprobación manual/automática.
- [ ] Describe cancelación, expiración, asistencia, ausencia, bloqueos y consulta de historia no clínica.
- [ ] Describe cuentas internas, pago total/corrección y resumen por fecha del turno.
- [ ] Incluye errores recuperables, restricciones de rol y pasos para informar una incidencia.
- [ ] Coincide con navegación, mensajes y estados observados; no presenta funciones excluidas como disponibles.

**Evidencia esperada:** enlace versionado al manual, índice de recorridos por rol y recibos de lectura guiada con pasos y resultados.
Las imágenes deben corresponder a datos ficticios y ocultar secretos; el manual no debe contener credenciales de acceso.
La identidad visual acordada en #274 debe contrastarse con el manual cuando exista y con la aplicación de #291; su acuerdo no acredita esos recorridos.

**Estado inicial:** no ejecutado. Manual final, recorrido guiado y aprobación pendientes.

## Resultado 2 — Datos ficticios persistentes por flujos reales

**Criterio de aprobación:** el conjunto de demostración se crea mediante los flujos reales del producto y puede volver a consultarse en el entorno de entrega.

- [ ] Define un conjunto ficticio identificable por alias, con roles y escenarios cubiertos.
- [ ] Registra origen de cada alta y operación: actor, recorrido, fecha, versión e identificador sanitizado.
- [ ] Incluye pacientes asistidos sin correo y pacientes con acceso personal, sin duplicar identidad por DNI.
- [ ] Incluye profesionales configurados, turnos y solicitudes, operaciones de ciclo, pagos y correcciones aplicables.
- [ ] Permite demostrar privacidad con pacientes y profesionales distintos, no sólo un único recorrido feliz.
- [ ] Después de guardar, recargar y cerrar/reabrir sesión, conserva identidad, estados e historia esperados.
- [ ] Una nueva consulta en el entorno persistente recupera los mismos registros y relaciones.
- [ ] Las comprobaciones de almacenamiento complementan el recorrido, no sustituyen su creación por el producto.

**Evidencia esperada:** inventario sanitizado de datos, recibos de creación y consulta posterior, capturas o registros mínimos correlacionados.
Fixtures, mocks, seeds e inserciones SQL directas no acreditan este resultado.
Los datos de preparación técnica deben distinguirse del conjunto aceptado; no se ejecutan resets sobre la evidencia persistente.
No se usan pacientes reales ni destinatarios de correo/teléfono ajenos para una demostración.

**Estado inicial:** no ejecutado. Conjunto ficticio, carga real y comprobación de persistencia pendientes.

## Resultado 3 — Comprobaciones funcionales y de permisos

**Criterio de aprobación:** cada capacidad beta tiene evidencia positiva y sus fronteras negativas aplicables, sobre la versión candidata.

| Grupo | Comportamiento observable que debe cubrirse |
| --- | --- |
| Identidad/acceso | DNI único; alta asistida sin acceso automático; magic link; sustitución de correo conserva historia e invalida acceso anterior. |
| Cuentas/configuración | Sólo cuentas Profesional/Secretaría administrables; perfil obligatorio para aparecer en reserva; foto opcional; desactivación conserva registros. |
| Reserva | Paciente propio, Secretaría y Profesional usan disponibilidad real; búsqueda sola no crea relación; solicitud completada sí la crea. |
| Aprobación | Automática confirma; manual genera solicitud según canal/configuración; sólo Profesional dueño resuelve; cambiar modo no resuelve solicitudes previas. |
| Ciclo/bloqueos | Expiración al inicio; cancelación libera; asistencia/ausencia; bloqueo conflictivo no cancela; cambio de turno requiere cancelar y crear otro. |
| Pagos/resumen | Pago total y corrección trazable; solicitud no se paga; precio bloqueado al pagar; resumen por fecha del turno, no del cobro. |
| Interfaz | Recorridos conectados, mensajes y estados coherentes con el backend y con el manual. |

- [ ] Cada grupo enlaza casos, fuente normativa, resultado observado y defectos pendientes.
- [ ] Se comprueba rechazo por backend, no sólo ausencia de botones.
- [ ] Se intenta acceso anónimo, sesión inválida/inactiva y rol no autorizado cuando corresponda.
- [ ] Se prueban identificadores ajenos: Paciente sólo ve lo propio; Profesional no ve actividad con otros profesionales.
- [ ] Secretaría no accede a configuración profesional ni aprueba/rechaza solicitudes.
- [ ] Administrador no adquiere acceso a pacientes, agendas, pagos o configuración por jerarquía.
- [ ] Los rechazos y conflictos no dejan cambios parciales ni relaciones indebidas.
- [ ] Se enlazan filas de la matriz de autorización revisada y pruebas de cada operación sensible.

**Evidencia esperada:** matriz caso–requisito–recibo, salida sanitizada de pruebas ejecutadas y recorridos reales, con defectos y reejecuciones.
La [matriz de autorización](../security/AUTHORIZATION_MATRIX.md) es incremental y está en borrador: requiere reconciliación beta, no copia automática.
Este contrato no concede permisos nuevos ni reemplaza esa matriz.
Las pruebas automatizadas y la comprobación del producto integrado se complementan; ninguna salida histórica basta.

**Estado inicial:** no ejecutado. Cobertura beta completa y resultados funcionales/de permisos pendientes.

## Resultado 4 — Acceso en nube

**Criterio de aprobación:** las personas autorizadas pueden acceder a la versión candidata en el entorno de nube acordado, sin depender de la máquina del presentador.

- [ ] Se referencia la fecha aclarada en #275 y las decisiones técnicas autorizadas y la aceptación de acceso pendientes de #292.
- [ ] Se identifica entorno, versión desplegada, URL de entrada sin tokens y fecha de observación.
- [ ] Se demuestra acceso desde un navegador fuera del entorno local de desarrollo.
- [ ] Funcionan autenticación y recorridos representativos con los datos persistentes del Resultado 2.
- [ ] Se comprueban las restricciones de rol sobre ese despliegue, no sólo en localhost.
- [ ] Se documentan límites de disponibilidad y operación acordados, y cualquier interrupción observada.
- [ ] Se describe cómo obtener acceso autorizado por canal seguro, sin publicar credenciales.

**Evidencia esperada:** recibo de acceso remoto, identificación de versión, resultados de recorridos y referencia a la decisión de hosting.
No se elige proveedor, dominio, presupuesto ni garantía de disponibilidad desde este contrato.
No se presenta el buzón de desarrollo, una captura local o un comando de arranque como despliegue aceptado.

**Estado inicial:** no ejecutado; fecha aclarada en #275. Decisiones técnicas de #292, URL, despliegue y acceso remoto sin evidencia en esta tarea.

## Resultado 5 — Condiciones docentes de entrega

**Criterio de aprobación:** las condiciones acordadas con docentes están registradas y cada una tiene una comprobación vinculada.

- [ ] Se enlaza la fecha aclarada en #275 y, cuando existan, el acuerdo docente de evaluación y las decisiones de entorno autorizadas en #292; no se atribuyen a #275.
- [ ] Se identifican versión del acuerdo, quién lo confirmó, fecha y alcance, sin presumir autoridad.
- [ ] Se precisan modalidad de acceso/demostración, período requerido y restricciones que efectivamente se acuerden.
- [ ] Se vinculan las condiciones al manual, conjunto de datos, acceso en nube y evidencia funcional.
- [ ] Se registran discrepancias o faltantes antes de solicitar aceptación de entrega.
- [ ] Toda modificación del acuerdo conserva referencia a la versión anterior y su nueva confirmación.

**Evidencia esperada:** referencia durable al acuerdo docente y tabla condición–recibo–resultado.
No se inventan rúbrica, fecha de evaluación, costo permitido, cuentas docentes ni nivel de servicio.
La posibilidad de preparar manual/casos no resuelve estas decisiones ni bloquea trabajo independiente.

**Estado inicial:** no ejecutado; fecha de entrega aclarada en #275, pero sin recibo de condiciones docentes detalladas ni de su comprobación en este artefacto.

## Resultado 6 — Estabilización de dos semanas

**Criterio de aprobación:** se documenta una ventana de dos semanas y su seguimiento real, con correcciones y regresión de la versión entregable.

- [ ] Se acuerdan y registran inicio, fin, versión inicial y seguimiento de la ventana de dos semanas.
- [ ] Se parte de funcionalidades integradas; no se reserva deliberadamente esta ventana para completar alcance faltante.
- [ ] Se mantiene registro de incidencias con impacto, reproducción, criterio afectado y estado.
- [ ] Cada corrección enlaza versión y evidencia de regresión; se actualizan manual y datos si cambian.
- [ ] Se registran observaciones durante la ventana, incluidos bloqueos e interrupciones, sin reconstruir resultados ficticios.
- [ ] Al finalizar se revisan los seis resultados y se enumeran faltantes y defectos aún abiertos.
- [ ] No se declara aceptación final mientras existan defectos que incumplan criterios de entrega.

**Evidencia esperada:** fechas acordadas, bitácora de seguimiento, incidencias/correcciones, recibos de regresión y evaluación final.
Dos semanas planificadas no equivalen a dos semanas transcurridas ni observadas.
La guía ubica esta actividad en Sprint 5 con fechas pendientes; aquí no se fija un calendario ni se afirma que haya comenzado.

**Estado inicial:** no ejecutado. Inicio, fin, seguimiento y aceptación al cierre pendientes.

## Recibo de evidencia reutilizable

Completar un recibo por caso o grupo coherente; dividirlo si cambian versión, entorno o resultado.
Un enlace a CI sólo acredita lo que esa ejecución efectivamente comprobó.

```text
ID de recibo: pendiente
Resultado (1–6) y criterio/caso: pendiente
Fuente normativa / issue: pendiente
Tipo: lectura de fuente | prueba automatizada | recorrido real | acuerdo humano
Versión / commit del producto y versión del documento: pendiente
Entorno y URL sin secretos (si aplica): pendiente
Fecha/hora y zona; ejecutor o confirmante: pendiente
Rol, precondiciones y alias ficticios: pendiente
Pasos o comando exacto ejecutado: pendiente
Resultado esperado: pendiente
Resultado observado: no ejecutado
Estado: no ejecutado | bloqueado | cumple | no cumple
Artefactos sanitizados y correlación entre creación/consulta: pendiente
Defecto / dependencia / limitación: pendiente
Reejecución y recibo anterior (si aplica): pendiente
Aprobación humana, alcance y referencia (separada de ejecución): pendiente
```

No adjuntar contraseñas, tokens, magic links completos, cookies, secretos TOTP ni credenciales de despliegue.
Recortar/redactar capturas y logs antes de compartirlos; conservar sólo identificadores necesarios y alias ficticios.
Un recibo incompleto no se transforma en «cumple» por copiar una salida esperada.

## Inventario de partida: reutilizar, adaptar y crear

Revisión acotada de fuentes locales para el contrato; no es una auditoría exhaustiva ni certificación del código.

| Tipo de observación | Fuente leída | Conclusión y uso permitido |
| --- | --- | --- |
| Código encontrado | [BookingService](../../lib/origen/appointments/booking_service.ex), `reserve/2`, `establish_relationship!/1` | Hay validación de elegibilidad profesional, persistencia y creación de relación también para `requested`; base para futuros casos, no éxito ejecutado. |
| Código encontrado | Mismo archivo, `reserve/2`, `initial_status/1` y `determine_initial_status/2` | La reserva automática usa `confirmed` y la manual `requested` sin regla D/D-1. `determine_initial_status/2` conserva `reserved` sólo como helper obsoleto de compatibilidad; no participa en `reserve/2`. |
| Código encontrado | [Patients](../../lib/origen/patients.ex), `ready_for_booking?/1` | Exige perfil completo sin requerir verificación telefónica para reservar. |
| Pruebas leídas | [BookingServiceTest](../../test/origen/appointments/booking_service_test.exs) | Incluye elegibilidad, snapshots, solicitud manual con relación, anónimo, identificador inválido, teléfono no verificado permitido y confirmación automática independiente de D/D-1. |
| Pruebas leídas | Mismo archivo | Conserva expectativas `reserved`/D-1 sólo para el helper legado. Usa preparación directa de datos: no demuestra carga por el producto ni aceptación integrada. |
| Documento histórico | [Runbook integrado](../demo/RUNBOOK_DEMO_INTEGRADA.md) | Reutilizar estructura de pasos, negativos y evidencia sanitizada; su aprobación, entorno local y resultados pertenecen al alcance histórico. |
| Documento histórico | [QA #93](qa-93-patient-autonomous-booking.md) | Reutilizar formato de escenario; retirar del guion beta la exigencia telefónica y expectativas `reserved`/D-1. |
| Documento a reconciliar | [Matriz de autorización](../security/AUTHORIZATION_MATRIX.md) | Conserva condiciones históricas y alcance incremental; revisar filas/pruebas beta sin inferir permisos por ausencia. |
| Crear | Este contrato y evidencias futuras | Manual final, conjunto persistente real, cobertura completa, aceptación cloud/docente y bitácora de estabilización siguen pendientes. |

**Pruebas ejecutadas por esta tarea: ninguna.** Leer tests no demuestra que pasen.
Los controles documentales de enlaces/estructura/espacios no son pruebas funcionales de la aplicación.
No se ejecutaron scripts históricos, migraciones, carga de datos ni despliegues para redactar este contrato.
El diagnóstico de la proposal sobre ausencia de relación para `requested` es histórico: el código leído ya incluye esa creación.
Esto no elimina otros gaps ni acredita el recorrido integrado; evita repetir como actual una carencia ya modificada.
La ambigüedad histórica de `Confirmed` no se arrastra: en beta significa turno aprobado, no asistencia confirmada.

## Pendientes y registro de aprobación

| Pendiente | Qué impide afirmar | Próxima evidencia necesaria |
| --- | --- | --- |
| Verificación #326 | Artefacto documental verificado en su etapa posterior | Revisión tras aprobación de dependencias; no ejecutada aquí. |
| #274 resuelta; #291 abierta | Manual e interfaz contrastados con la identidad acordada | Citar la resolución y los recursos de #416; verificar #291 y lectura del manual cuando existan. |
| #275 resuelta; #292 abierta | Acceso cloud y condiciones técnicas/docentes aceptados | Separar la fecha aclarada de las decisiones de entorno y recibos de #292; verificar Resultados 4–5 y el acuerdo docente aplicable. |
| Resultados 1–3 sin ejecución | Manual usable, datos persistentes y funcionalidad/permisos aceptados | Recibos por criterio y corrección de incompatibilidades. |
| Resultado 6 sin ejecución | Estabilización completada | Ventana acordada y seguimiento observado de dos semanas. |
| Aceptación final | Beta entregada y aprobada | Evaluación conjunta de resultados con evidencia y aprobación explícita. |

- **Aprobación del contrato #325:** Saidqr aprobó la versión `c59cf6b` en el [comentario de #325](https://github.com/Team-Origen/origen/issues/325#issuecomment-6499068891); no certifica ejecución.
- **Verificación documental #326:** pendiente; no realizada por este documento.
- **Aprobación final de entrega:** pendiente; no se deduce de la aprobación contractual.

Siguiente paso: verificar la definición en #326 y registrar el acuerdo sobre #290 por separado, sin anticipar la aceptación final de la beta.
