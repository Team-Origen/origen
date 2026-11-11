# Contrato #313: agenda del Profesional con privacidad

**Estado: contrato aprobado explícitamente por el usuario en esta conversación; no implementa código de aplicación.**
Prepara Backend #314 e Interfaz #315 de la padre #282. No acredita su implementación ni el cierre de Integración #316. La aprobación incluye la proyección mínima del selector y el recorrido paciente → tipo de consulta → fecha y horario → confirmación. Las pruebas de referencia se ejecutaron exitosamente después de que el usuario confirmó PostgreSQL disponible: 109 aprobadas. Esto verifica la base existente, no implementa ni demuestra el nuevo recorrido.

## Alcance y fuentes

- Contrato: [#313](https://github.com/Team-Origen/origen/issues/313); padre: [#282](https://github.com/Team-Origen/origen/issues/282).
- OpenSpec: cambio `health-center-beta-core`, ruta `openspec/changes/health-center-beta-core/`, alcance Sprint 3 / parent #282 / contract.
- [Propuesta](../../../openspec/changes/health-center-beta-core/proposal.md), especialmente diferencias históricas y Tracking; [diseño](../../../openspec/changes/health-center-beta-core/design.md), autorización por defecto denegada y privacidad.
- [Reserva y ciclo de vida](../../../openspec/changes/health-center-beta-core/specs/appointment-booking-and-lifecycle/spec.md), requisitos «Three booking channels and privacy» y «Approval and occupancy».
- [Identidad y acceso](../../../openspec/changes/health-center-beta-core/specs/patient-identity-and-access/spec.md), identidad por DNI y paciente registrado.
- [Límites beta](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) y [guía de trabajo](../GUIA_TRABAJO_BETA.md).
- [#202](https://github.com/Team-Origen/origen/issues/202): base de consultas de agenda y regresión de privacidad. Consultada en estado OPEN; su existencia no demuestra cumplimiento beta.
- [#284](https://github.com/Team-Origen/origen/issues/284): dueño de configuración de aprobación y resolución de solicitudes; no se duplica aquí.

Las issues #313 y #282 se consultaron completas, incluidos comentarios: ninguna tenía comentarios al relevamiento. La propuesta ya contiene referencias inversas a #282 y #313–#316; no se duplica Tracking.

### Exclusiones

No incluye registrar pacientes inexistentes (#283), resolver solicitudes o diseñar otra configuración de aprobación (#284), consultar agendas ajenas, historia clínica ni actividad con otros Profesionales. No agrega navegación global de pacientes, dependientes, reprogramación directa, notificaciones automáticas ni verificación telefónica obligatoria. No cambia dependencias de GitHub ni asigna aprobadores.

## Flujo de reserva del canal Profesional

**Seleccionar paciente → elegir tipo de consulta y horario disponible → confirmar → recibir el resultado.**

| Paso | Acción del Profesional | Comportamiento esperado |
| --- | --- | --- |
| 1. Iniciar | Inicia una reserva desde su propia agenda | El servidor identifica al Profesional por su sesión vigente; no permite operar otra agenda |
| 2. Seleccionar paciente | Elige de sus relacionados o busca un paciente registrado por DNI exacto | Ve sólo nombre, apellido y DNI; buscar, seleccionar o abandonar no crea relación ni turno |
| 3. Elegir consulta y horario | Selecciona un tipo de consulta ofrecido por él y un horario disponible | Se consultan catálogo y disponibilidad reales existentes; no se muestran como libres los horarios ocupados |
| 4. Confirmar | Confirma la reserva para el paciente, consulta y horario seleccionados | El servidor revalida permisos y disponibilidad; crea atómicamente el turno `confirmed` y crea o reutiliza la relación Profesional–Paciente |
| 5. Recibir el resultado | Ve la confirmación o el motivo de rechazo | El éxito informa el turno creado; el rechazo no deja una creación parcial ni expone actividad ajena |

### Qué define este contrato y qué reutiliza

Este recorrido define las particularidades del **canal Profesional**: selección de paciente, proyección mínima, agenda propia, momento de creación de la relación y confirmación directa incluso con aprobación manual. No redefine el sistema general de reservas.

Se reutilizan el cálculo de disponibilidad, las validaciones de consulta y horario, los snapshots, la persistencia transaccional y el control de solapamientos del motor existente. La configuración de aprobación y la resolución de solicitudes corresponden a #284; aquí sólo se exige que una reserva creada por el Profesional quede `confirmed`. Reutilizar no supone compatibilidad beta automática: las adaptaciones necesarias se enumeran en el mapa de estado actual.

## Recorrido y reglas

1. Un Profesional con sesión vigente y cuenta activa inicia una reserva en **su propia agenda**. La identidad y el alcance se derivan de la sesión revalidada, nunca de parámetros del cliente.
2. Puede seleccionar un paciente ya relacionado con él o buscar un paciente registrado por **DNI exacto**. Ambos caminos deben estar disponibles; no se requiere relación previa para el segundo.
3. La búsqueda exacta se limita al recorrido de creación. No admite prefijos, sugerencias ni resultados globales. Una coincidencia de documento debe corresponder a un paciente registrado, no solamente a una Persona sin perfil de paciente. La normalización reutiliza las reglas documentales existentes; no convierte la búsqueda en coincidencia aproximada.
4. Lista y resultado exacto muestran exclusivamente **nombre, apellido y DNI**. No exponen teléfono, email, otros Profesionales, citas, historial, cantidad de atenciones ni indicadores de actividad ajena. El identificador técnico necesario para seleccionar no constituye autorización por sí mismo.
5. Consultar la lista, encontrar/no encontrar un DNI, seleccionar un resultado y abandonar no crean relación ni turno. Una búsqueda puede conservar la auditoría de consulta prevista por el sistema; no se confunde con una reserva exitosa.
6. Al confirmar, el servidor revalida sesión, agenda propia, paciente seleccionado y condiciones reales de reserva. Alterar IDs no habilita una selección ni una agenda ajena. Un paciente registrado sin relación sigue siendo seleccionable por la vía de DNI exacto: su relación con otro Profesional no lo excluye ni se revela.
7. Se reutilizan el catálogo y disponibilidad reales, snapshots y motor transaccional de reservas. No se implementan otro calendario, otro motor ni otra configuración de aprobación. Un resultado de disponibilidad anterior no garantiza que el horario siga libre al confirmar.
8. La creación por Profesional nace **`confirmed`**, ocupa el horario y establece o reutiliza la relación Profesional–Paciente de manera atómica, tanto en modalidad automática como manual. No aplica el estado histórico calculado por D-1.
9. La regla transversal beta es que completar una solicitud `requested` **o** un turno crea relación. Esto no habilita crear pendientes desde este canal: los pedidos de otros canales y su resolución siguen siendo responsabilidad de sus slices y de #284.
10. Una validación rechazada o una falla de persistencia no deja turno, relación nueva ni evento de reserva exitosa parcial. Una relación preexistente permanece intacta. El rechazo no devuelve actividad ni datos de otra agenda.

## Respuestas y errores propuestos

Estas categorías son el contrato observable; no prescriben nuevas funciones públicas, átomos ni textos literales de UI. Backend e Interfaz deben mapearlas de forma coherente sin ampliar los datos permitidos.

| Resultado | Respuesta observable | Efecto sobre turno/relación |
| --- | --- | --- |
| Lista propia | Sólo pacientes relacionados con el actor, con proyección mínima; puede estar vacía | Ninguno |
| DNI exacto válido encontrado | Un paciente registrado, con proyección mínima | Ninguno |
| DNI inválido o incompleto | Error de validación, sin coincidencias parciales | Ninguno |
| DNI sin paciente registrado | Sin resultado; permite corregir o abandonar, no registrar en este slice | Ninguno |
| Sesión inválida, rol indebido o agenda ajena | Acceso denegado, sin datos del recurso ajeno | Ninguno |
| Selección manipulada o no válida | Rechazo sin revelar existencia, vínculo o actividad ajena | Ninguno |
| Consulta/horario no válido, ocupado o ya no disponible | No se creó el turno; permite actualizar disponibilidad | Ninguno |
| Error de persistencia | No se completó la reserva; sin éxito aparente | Reversión de toda la creación |
| Creación exitosa | Confirmación del turno propio en estado `confirmed` | Un turno; relación creada o reutilizada |

La búsqueda exacta permite conocer la identidad mínima del paciente registrado porque la beta lo autoriza expresamente; eso no habilita conocer con quién se atiende. Los errores de autorización no deben convertirse en un mecanismo adicional de enumeración.

## Estado actual: reutilizar, adaptar y crear

Referencias correspondientes a la base `dfde739`; los rangos sirven como orientación, no como prueba de ejecución.

| Clasificación | Evidencia | Diferencia o uso |
| --- | --- | --- |
| Reutilizar | `lib/origen/booking/agenda.ex:52-95,125-137` | Revalidación de sesión y filtro estricto por dueño; no es un selector de pacientes |
| Reutilizar | `lib/origen/booking/professional_patient_relationship.ex:1-29` | Relación durable y unicidad del par; no crearla al buscar |
| Reutilizar | `lib/origen/booking.ex:194-210` y migración `20260927100000_add_appointment_overlap_exclusion_constraints.exs` | Transacción, snapshots y exclusión de solapamientos; no duplicar motor |
| Adaptar | `lib/origen/booking/authorization.ex:104-116,146-176` | Actualmente exige relación o antecedentes habilitantes; falta el camino controlado de DNI exacto sin relación previa |
| Adaptar | `lib/origen/booking.ex:29,429-433` | `requested` no establece relación de forma uniforme; existen excepciones de otros canales. Coordinar la regla beta sin romperlos |
| Retirar del nuevo recorrido | Estado histórico de reserva/D-1 en `lib/origen/booking.ex`; `lib/origen/appointments/booking_service.ex:48-106` | No trasladar reglas de reserva autónoma del Paciente al Profesional: éste confirma directamente |
| Reutilización parcial | `lib/origen/patients.ex:172-198,310-326` | Normalización y consulta documental como referencia; operación actual sólo autorizada a Secretaría. No abrir su permiso global al Profesional |
| Reutilización parcial | `lib/origen/appointments/assisted_booking.ex:81-154,194-206` | Referencia de orquestación del motor; autorización de Secretaría no reutilizable como permiso Profesional |
| Crear #314 | Operaciones de lista relacionada, búsqueda exacta contextual y reserva Profesional | Servidor valida ambos caminos y efectos atómicos; no se fija una API pública nueva en este documento |
| Crear #315 | `lib/origen_web/live/professional_agenda_live.ex` | Hoy consulta agenda y opera aprobación; falta selector y recorrido de creación con proyección mínima |

No se prohíbe seleccionar por DNI exacto a un paciente relacionado con otro Profesional. Se prohíbe acceder a esa relación o actividad ajena.

## Escenarios verificables

Son expectativas para #314/#315 y posteriormente #316, **no pruebas nuevas ya ejecutadas**. Los rechazos deben comprobar también ausencia de cambios en turnos y relaciones; las relaciones previas se conservan. La evidencia usa datos ficticios y las interfaces públicas de las operaciones, sin credenciales ni tokens.

| ID | Caso | Resultado esperado |
| --- | --- | --- |
| C1 | A lista sus relacionados; existe un paciente relacionado sólo con B | A ve sólo sus relacionados; no recibe datos ni indicadores de B; ningún alta |
| C2 | A busca DNI exacto de paciente registrado no relacionado con A | Una coincidencia con nombre, apellido y DNI; no contacto ni actividad ajena; ninguna relación nueva |
| C3 | DNI parcial/inválido, inexistente o Persona sin perfil de paciente | Validación o sin resultado según tabla; sin sugerencias, turnos ni relaciones |
| C4 | A busca, selecciona y abandona | No crea turno ni relación, incluso tras búsquedas repetidas |
| C5 | A confirma paciente relacionado en horario válido | Un turno `confirmed`, slot ocupado y misma relación sin duplicación |
| C6 | A confirma paciente obtenido por DNI exacto, sin relación previa | Un turno `confirmed` y una relación con A en la misma transacción; vínculos con B no se revelan ni modifican |
| C7 | Repetir C5/C6 con aprobación automática y manual | Siempre `confirmed`; no se altera configuración ni se resuelven pendientes existentes |
| C8 | Anónimo, cuenta inactiva, sesión revocada o rol distinto intenta las operaciones del recorrido Profesional | Denegado sin datos; no habilita estas operaciones a Secretaría por compartir código |
| C9 | A manipula dueño de agenda, selección o parámetros de cita para operar como B | Denegado sin actividad de B; ninguna reserva ni relación nueva |
| C10 | Tipo/horario inválido, slot ocupado o que dejó de estar libre | Rechazo atómico sin éxito aparente ni relación espuria |
| C11 | Falla de persistencia al crear turno/relación o dos confirmaciones compiten por el mismo slot | Sin creación parcial; en la competencia sólo un éxito y sin duplicar relaciones |
| C12 | Luego de crear, A consulta su agenda y trata de consultar actividad del paciente con B | Ve sólo su turno; persiste aislamiento de #202, sin expandir proyecciones del selector |
| C13 | Solicitud completada `requested` en otro canal autorizado | Crea relación y ocupa horario conforme beta; resolverla sigue siendo exclusivo del dueño y #284 |
| C14 | UI selecciona por lista o DNI y confirma/rechaza/abandona | Usa ambos caminos, proyección mínima y resultados coherentes; no muestra alta de inexistente como entrega de #282 |

C13 es compatibilidad transversal a coordinar con los slices existentes; no autoriza duplicar su implementación. Conservar las regresiones de consulta y autorización de agendas de #202 y las de reserva de otros canales cuando se adapten helpers compartidos.

## Evidencia de revisión

### Código encontrado y pruebas leídas

- `test/origen/booking/agenda_privacy_regression_test.exs` y `professional_agenda_test.exs`: aislamiento por dueño, parámetros manipulados, sesiones y proyección de agenda. Se reutilizan; no prueban el selector todavía inexistente.
- `test/origen/booking/authorization_test.exs:214-272`: permisos de reserva y relación; contiene una expectativa histórica para `requested` que debe contrastarse con beta.
- `test/origen/booking/atomic_reservation_test.exs:102-128`: expectativa histórica de `requested` sin relación; no presentarla como conformidad beta.
- `test/origen/patients/secretary_search_test.exs:39-128`: búsqueda documental y denegación al Profesional; preservar el contrato de Secretaría.
- `test/origen/appointments/assisted_booking_test.exs`, `test/origen/booking/request_resolution_test.exs` y `test/origen_web/live/professional_agenda_live_test.exs`: apoyo de otros canales/aprobación, no cobertura del nuevo recorrido.

### Ejecución de referencia

Comando lanzado sobre la base, sin modificar aplicación ni pruebas:

```sh
mix test test/origen/booking/authorization_test.exs \
  test/origen/booking/atomic_reservation_test.exs \
  test/origen/booking/agenda_privacy_regression_test.exs \
  test/origen/booking/professional_agenda_test.exs \
  test/origen/appointments/assisted_booking_test.exs \
  test/origen/booking/request_resolution_test.exs \
  test/origen_web/live/professional_agenda_live_test.exs
```

**Resultado observado: código de salida 1, ejecución bloqueada antes de correr las pruebas.** Postgrex informó `tcp connect (localhost:5433): connection refused - :econnrefused`; Mix terminó con `The database for Origen.Repo couldn't be created: killed`. No hay cantidad de pruebas aprobadas ni evidencia de comportamiento en esta ejecución. No se cambió el entorno desde el agente.

**Segunda ejecución, autorizada expresamente después de que el usuario confirmó PostgreSQL disponible:** mismo comando, código de salida **0**, **109 pruebas aprobadas**, duración ExUnit **1.6 segundos**, seed **485272**. ExUnit informó `Excluding tags: [postgres_security: true]`; no se ejecutaron los casos etiquetados `postgres_security`.

La configuración de prueba usa PostgreSQL y sandbox (`config/test.exs`); no se usan datos reales como fixtures. Esta suite verifica comportamiento existente, incluidas expectativas históricas identificadas más arriba: su éxito no demuestra C1–C14 ni cumplimiento completo de #282. No se ejecutó la suite completa del repositorio; este cambio es exclusivamente documental.

## Acuerdos, pendientes y aprobación

- **Acuerdo registrado en esta conversación:** ante la propuesta de mostrar sólo nombre, apellido y DNI, sin teléfono, email ni actividad de otros Profesionales, el usuario respondió «si». Este acuerdo vale para ambos selectores, no como aprobación anticipada del resto del contrato.
- **Aprobación explícita del contrato completo:** luego de revisar el documento y discutir el orden de selección, el usuario expresó «CLARO ES LOJICO, APRUEBO EL CONTARTO». Se conserva el recorrido paciente → tipo de consulta → fecha y horario → confirmación, sin agregar entrada alternativa desde un hueco de agenda. Incluye las respuestas/errores propuestos; no atribuye aprobaciones a otras personas ni demuestra comportamiento implementado.
- **Pendiente compartido:** coordinar con #284 la confirmación directa del canal Profesional y la compatibilidad de relación para `requested`, sin otro motor o configuración.
- **Pendiente de implementación:** #314 backend y #315 interfaz, con pruebas que cubran C1–C14 según su alcance.
- **Integración #316:** sólo después de las demás hermanas terminadas y aprobadas y dependencias reales disponibles; fixtures no acreditan integración real.
- No se publicaron comentarios, no se cerraron issues ni se cambiaron blockers con este documento. La aprobación está registrada localmente; queda pendiente vincular esta evidencia al ticket antes de declarar #313 terminada.
