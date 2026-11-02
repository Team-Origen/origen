# Contrato: alta y reserva desde Profesional

**Contrato aprobado por Saidqr — #317, hija de #283.** El Profesional busca por
DNI exacto dentro de «Crear turno» y, si no existe, completa el alta junto con la
reserva en su propia agenda. Sólo el éxito conjunto persiste identidad, turno
confirmado y relación Profesional–Paciente. Este documento no implementa el flujo.

## 1. Alcance y fuentes de verdad

- Ticket de esta unidad: [#317](https://github.com/Team-Origen/origen/issues/317).
- Funcionalidad padre: [#283](https://github.com/Team-Origen/origen/issues/283).
- OpenSpec: `health-center-beta-core`, ruta `openspec/changes/health-center-beta-core/`.
- Slice: contrato; backend #318, interfaz #319 e integración #320 son entregas separadas.
- Base inspeccionada: `origin/develop`, commit `dfde7390accd15c7569c099a3542a62c2aaf77b0`.
- Estado operativo recibido para esta revisión: #276 cerrada; #282 abierta.
  No se consultó ni modificó GitHub para certificar esos estados.

| Fuente normativa | Secciones aplicables |
| --- | --- |
| [Proposal](../../../openspec/changes/health-center-beta-core/proposal.md) | `Product boundaries`, `Current-code reconciliation`, `Tracking / Sprint 3 work breakdown` |
| [Design](../../../openspec/changes/health-center-beta-core/design.md) | `Domain vocabulary`, `Authorization boundary`, `Future implementation obligations` |
| [Identidad](../../../openspec/changes/health-center-beta-core/specs/patient-identity-and-access/spec.md) | `Assisted identity and unique patient`; escenario `Professional registers an absent patient`; `Personal access and email maintenance` |
| [Reservas](../../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md) | `Three booking channels and privacy`; `Approval and occupancy` |
| [Límites](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) | `Complete beta scope is not priority-gated`; `Excluded capability set` |
| [Guía beta](../GUIA_TRABAJO_BETA.md) | `Fuente de verdad y alcance`, `Responsabilidad por ticket`, `Regla de Integración y verificación` |

La beta aprobada manda sobre comentarios o pruebas históricas. Said (`Saidqr`)
aprobó explícitamente el contrato de #317 en `a64b930`, según el
[registro de acuerdo](https://github.com/Team-Origen/origen/issues/317#issuecomment-6425202986),
y autorizó la etiqueta `status:approved`, ya presente en la issue. La aprobación
abarca este contrato documental, no la aprobación de #318/#319/#320 ni la
verificación funcional o el cierre de #283.
No se incorporan acceso por magic link, edición de identidad, historia clínica,
verificación telefónica obligatoria ni permisos de Secretaría para Profesionales.

## 2. Recorrido y datos observables

1. Un Profesional autenticado y activo abre «Crear turno» sobre su propia agenda.
2. Selecciona un paciente relacionado o busca un DNI exacto. El caso existente
   pertenece a [#282](https://github.com/Team-Origen/origen/issues/282), sin duplicarlo.
3. Ante ausencia, se habilitan los datos de alta dentro del mismo recorrido.
4. Selecciona tipo de consulta propio y fecha/hora realmente disponible.
5. Confirma alta y reserva juntas; el servidor revalida permisos, DNI y disponibilidad.
6. Sólo después del éxito se presenta el turno `confirmed` y el paciente relacionado.

| Entrada | Regla del contrato |
| --- | --- |
| Nombre y apellido | Obligatorios; no aceptar valores vacíos como identidad válida. |
| DNI | Obligatorio, búsqueda exacta antes del alta y unicidad al confirmar. |
| Fecha de nacimiento | Obligatoria; validar en servidor, reutilizando reglas compatibles. |
| Teléfono | Obligatorio; no exige verificación ni habilita acceso personal. |
| Email de contacto | Opcional y compartible; no confundir con email de acceso personal. |
| Tipo de consulta y fecha/hora | Propios de la agenda y disponibles al confirmar. |
| Actor y agenda | Derivados/validados desde la sesión; el formulario no otorga autoridad. |

No son requisitos nuevos el género, una contraseña ni otro catálogo documental.
La normalización y validaciones técnicas comunes deben acordarse con #276/#282;
la existencia de otros tipos documentales en el modelo no amplía este slice de DNI.

**Resultado de éxito:** identidad única, referencia al paciente y turno persistidos,
agenda propia, tipo de consulta, inicio/fin y estado `confirmed`; relación durable
con ese Profesional. Duración y precio se resuelven desde configuración válida,
no desde valores autoritativos del cliente. No se entrega actividad de terceros.

**Resultado de rechazo:** errores de campos o conflicto recuperable, sin éxito
parcial. La interfaz permite corregir o volver a buscar/elegir horario; no afirma
«paciente creado» si la reserva falló. Nombres de operaciones, tuplas, códigos de
error y forma exacta de respuesta quedan por acordar, no se inventan firmas aquí.

## 3. Límite transaccional, permisos y privacidad

- Buscar, editar el formulario o abandonarlo no crea identidad, turno ni relación.
- El alta profesional no tiene un botón de guardado independiente de la reserva.
  A diferencia del alta de Secretaría, no se encadenan dos éxitos independientes.
- Confirmar debe persistir atómicamente identidad/perfil, turno, relación y la
  auditoría de éxito correspondiente. Cualquier fallo revierte los efectos nuevos;
  una identidad preexistente o creada por otro actor no se borra ni sobrescribe.
- Una búsqueda previa negativa no garantiza ausencia al confirmar. Ante carrera
  de DNI, se rechaza el alta duplicada y se vuelve al recorrido de existente #282;
  no se fusionan datos ni se vincula automáticamente por el mero intento.
- Disponibilidad se revalida al escribir: respetar agenda, duración, bloqueos y
  solapamientos del Profesional y paciente. Un horario mostrado no está reservado.
- La reserva creada por Profesional siempre nace `confirmed`, aun en aprobación
  manual o antes de D-1. No hereda el estado histórico `reserved` por calendario.
- Sólo un Profesional activo opera su agenda. Rechazar suplantación de actor,
  agenda ajena y uso de esta operación por otros roles; Administrador no hereda acceso.
- La búsqueda exacta no habilita un listado global ni acceso a actividad ajena.
  Antes del éxito sólo se expone lo mínimo acordado para identificar y reservar.
- Después del éxito, la relación permite el alcance propio, nunca turnos, historia
  o actividad del paciente con otros Profesionales. Un conflicto de disponibilidad
  tampoco debe revelar quién atiende al paciente ni los detalles de otro turno.
- No se emiten cuentas, sesiones, magic links ni desafíos de teléfono por esta alta.
  La auditoría de intentos, si corresponde, no equivale a persistir identidad o relación.

## 4. Evidencia leída en develop y adaptación necesaria

Las referencias siguientes son **código encontrado y pruebas leídas**, no pruebas
ejecutadas ni evidencia de que #283 funciona de extremo a extremo.

| Evidencia actual | Reutilizar / adaptar / crear |
| --- | --- |
| [Patients](../../../lib/origen/patients.ex): `search_persona_by_document/3`, `register_absent_patient/2` | Alta independiente de Secretaría, autorizada sólo para ese rol. No llamar como Profesional ni ampliar indiscriminadamente sus permisos. Extraer/reutilizar validación y persistencia interna compatible en #318. |
| [Persona](../../../lib/origen/patients/persona.ex): `assisted_changeset/2`, `normalize_number/1` | Reutilizar campos mínimos, email opcional y restricción `personas_document_unique`; acordar validación común de DNI sin duplicar identidades. |
| [Secretaría LiveView](../../../lib/origen_web/live/secretary_patient_live.ex): eventos `search`, `register`, `confirm_assisted_booking` | Ya separa alta y reserva. Reutilizar patrones de formulario/errores, no trasladar ese límite de guardado al Profesional. |
| [AssistedBooking](../../../lib/origen/appointments/assisted_booking.ex): `reserve/4` | Reserva pacientes existentes desde Secretaría, resuelve aprobación y solicita relación. No es una operación profesional de alta y reserva. |
| [Booking.Authorization](../../../lib/origen/booking/authorization.ex): `authorize_reservation/1`, `ensure_patient_permitted/2` | Exige paciente previamente permitido al Profesional; adaptar con #282/#318 sin crear una relación anticipada para sortear la autorización. |
| [Booking](../../../lib/origen/booking.ex): `reserve_appointment/2`, `execute_atomic_reservation/4` | Base transaccional de turno/relación/auditoría, snapshots y conflictos. Falta incorporar alta en el mismo límite; retirar D-1 del recorrido profesional. `requested` tiene tratamiento condicional, no uniforme. |
| [Agenda profesional](../../../lib/origen_web/live/professional_agenda_live.ex) | Agenda diaria y resolución de solicitudes encontradas; no acreditan el formulario de alta y reserva. Crear/conectar ese recorrido en #319 con #282. |

Pruebas consultadas y límite de lo que sus aserciones describen:

- [SecretarySearchTest](../../../test/origen/patients/secretary_search_test.exs):
  búsqueda normalizada, ausencia, denegación a Profesional y alta sin acceso;
  email de contacto compartido y campos mínimos. No prueba la transacción de #283.
- [AssistedBookingTest](../../../test/origen/appointments/assisted_booking_test.exs):
  C1–C4 describen éxito, aprobación desde settings, relación en `requested` y
  horario ocupado para Secretaría, no autorización profesional de alta.
- [AtomicReservationTest](../../../test/origen/booking/atomic_reservation_test.exs):
  rollback de relación/auditoría y relación no duplicada; también conserva casos
  históricos `reserved` y `requested` sin relación. No copiarlos como norma beta.
- [AgendaPrivacyRegressionTest](../../../test/origen/booking/agenda_privacy_regression_test.exs):
  aislamiento entre agendas profesionales; extender protección al nuevo recorrido.

El archivo comparable `docs/sprints/sprint-3/contrato-276-alta-paciente-secretaria.md`
no está presente en esta base (lectura: `ENOENT`). No se usó una copia de otra rama.
El cierre informado de #276 no sustituye la revisión del código vigente ni prueba #283.

## 5. Escenarios de aceptación para las siguientes hijas

| Caso | Resultado verificable exigido |
| --- | --- |
| DNI ausente, campos válidos, sin email | Una identidad/perfil sin acceso, un turno `confirmed` y una relación; teléfono sin exigir verificación. |
| Email de contacto compartido | Alta válida sin crear cuenta ni enlazar otro paciente por email. |
| Profesional en modo manual; fecha anterior a D-1 | La reserva propia igualmente queda `confirmed`, sin solicitud pendiente. |
| DNI ya existente al buscar | No ofrecer duplicación; continuar por #282 con exposición mínima. |
| Otro actor registra el DNI entre búsqueda y confirmación | Ningún duplicado, turno o relación de este intento; identidad existente intacta y retorno seguro a búsqueda. |
| Falta cada campo obligatorio o dato inválido | Error de validación; cero nuevas identidades, turnos o relaciones. |
| Horario ocupado/bloqueado, tipo inválido o disponibilidad cambiada | Rechazo sin alta parcial y sin revelar actividad ajena; refrescar opciones. |
| Fallo de persistencia, relación o auditoría de éxito | Rollback de todos los efectos nuevos; no mostrar éxito parcial. |
| Buscar, volver atrás o abandonar | No persistir identidad, turno ni relación por esos pasos. |
| Rol indebido, cuenta inactiva o agenda manipulada | Denegación en servidor, sin cambios ni información fuera del permiso. |
| Paciente también atendido por otro Profesional | Tras reservar, sólo actividad propia visible; ningún detalle ajeno en resultados o errores. |
| Doble envío/reintento tras respuesta incierta | No duplicar identidad, relación ni turno; definir recuperación e idempotencia antes de integrar. |

## 6. Responsabilidad, coordinación técnica y entrega

La guía asigna #283 y sus hijas a Said (`Saidqr`), y #282 a Santiago (`SantiCasali`).
La aprobación de #317 por Saidqr queda registrada arriba; no presume acuerdo de
Santiago sobre las decisiones técnicas compartidas ni designa aprobadores nuevos.

| Unidad | Responsabilidad y condición de salida |
| --- | --- |
| [#318 Backend](https://github.com/Team-Origen/origen/issues/318) | Implementar límite atómico, autorización default-deny, unicidad, conflictos y auditoría; pruebas de éxito, rechazo y concurrencia. Acordar con #282 operaciones comunes y actualizar matriz de permisos. |
| [#319 Interfaz](https://github.com/Team-Origen/origen/issues/319) | Alta dentro de «Crear turno», estados de búsqueda/formulario/envío/éxito/error y abandono sin guardar; pruebas contra contrato acordado. Fixtures no equivalen a integración. |
| [#320 Integración](https://github.com/Team-Origen/origen/issues/320) | Esperar #317/#318/#319 terminadas y aprobadas y todos los blockers de #283, incluida #282; ejecutar flujo real y matriz de escenarios, registrar evidencia y aprobación. |

**Decisiones futuras de implementación a coordinar entre responsables de #283 y #282:**

- Operaciones públicas y forma de respuestas/errores; datos mínimos visibles del
  paciente encontrado y manejo de identidades históricas sin perfil enlazado.
- Validaciones/normalización comunes, composición transaccional, eventos de
  auditoría con actor Profesional y recuperación de doble envío/respuesta incierta.

Esta coordinación técnica no deja pendiente la aprobación documental de #317 ni
vuelve opcionales la atomicidad, unicidad, confirmación directa y privacidad
definidas arriba. Si una dependencia contradice esas reglas, consultar
antes de implementar; no resolver la discrepancia concediendo permisos más amplios.

Entrega vigente: #317 acompaña pruebas de #318 en un PR hijo del integrador
[#348](https://github.com/Team-Origen/origen/pull/348), en borrador y sin merge.
No cierra #317/#318; reversión documental: retirar este archivo y su enlace.

## 7. Verificación de esta unidad documental

No hay RED/GREEN funcional significativo: sólo se redactó documentación.
Se revisan trazabilidad, destinos relativos y whitespace (incluido el archivo nuevo,
que `git diff --check` no cubre mientras sea untracked). Los resultados observados
se entregan con el handoff; no se ejecutaron pruebas de aplicación ni recorrido manual.
La verificación funcional de los escenarios queda a cargo de #318/#319/#320.
