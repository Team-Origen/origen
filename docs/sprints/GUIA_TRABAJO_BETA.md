# Guía de trabajo para la beta: tickets, subtareas y cierre

Esta guía está dirigida a los desarrolladores del equipo. Cada integrante se hace responsable de una funcionalidad completa: su issue padre y las subissues que correspondan. Los tipos de trabajo organizan la entrega; no representan puestos separados de producto, backend o frontend.

## Recorrido rápido

1. Leer la issue padre y las secciones aplicables de la especificación beta.
2. Revisar el estado actual de esa funcionalidad y acordar sus reglas y contrato.
3. Implementar backend e interfaz, con pruebas en cada parte. Adelantar sólo trabajo compatible con las dependencias y el contrato.
4. Comenzar Integración y verificación únicamente cuando todas las demás subissues de la padre estén terminadas y aprobadas.
5. Corregir las fallas de integración, verificar todos los criterios de la padre y registrar su cierre después de aprobar la integración.

## Fuente de verdad y alcance

- La [especificación beta aprobada](../../openspec/changes/health-center-beta-core/proposal.md), cambio `health-center-beta-core`, define el comportamiento esperado.
- Las issues de GitHub son el registro operativo del alcance, dependencias, avances y evidencia. Esta guía no duplica sus criterios de aceptación.
- El código, las pruebas y las integraciones anteriores sirven para conocer el punto de partida. No reemplazan las reglas de la beta.
- Si una regla histórica contradice la beta, se identifica la adaptación necesaria. Si hay contradicciones entre requisitos vigentes, se consulta antes de implementar.
- Profundizar un contrato no autoriza a inventar requisitos ni ampliar la funcionalidad.

## Responsabilidad por ticket

Un mismo integrante lleva la issue padre y sus subissues hasta obtener un resultado integrado. Puede alternar entre reglas, backend e interfaz para aprovechar el tiempo mientras espera dependencias.

Por ahora no se asignan personas diferentes para aprobar las secciones. La aprobación debe quedar registrada explícitamente en el ticket o en su evidencia vinculada; no se presume por haber escrito código o cerrado una PR. Esta guía no establece una aprobación independiente obligatoria.

Los responsables de funcionalidades relacionadas deben acordar los contratos compartidos. Tener un responsable por ticket no significa trabajar aislados.

## Tipos de trabajo

El patrón se aplica cuando corresponde. No se crean cuatro subtickets automáticamente para cada funcionalidad: se evita dividir trabajo pequeño o inventar capas que no existen.

| Tipo y etiqueta | Qué debe resolver | Qué permite terminar esa parte |
| --- | --- | --- |
| **Reglas y contrato** — `work:contract` | Revisar el estado actual del slice, incluidas integraciones anteriores; precisar escenarios, permisos, estados, entradas, resultados y errores según la beta. | Un contrato claro, con referencias al código y pruebas existentes, diferencias frente a la beta y ejemplos verificables. No incluye implementar la funcionalidad. |
| **Backend** — `work:backend` | Lógica de negocio, persistencia, autorización, auditoría y operaciones necesarias. | Implementación y pruebas de su alcance, incluidos rechazos y efectos sobre los datos. |
| **Interfaz** — `work:frontend` | Componentes, formularios, navegación propia del recorrido, mensajes y estados visuales. | Comportamiento de interfaz probado contra el contrato. Puede usar fixtures o dobles de prueba si la conexión real pertenece a Integración. |
| **Integración y verificación** — `work:integration` | Conectar las partes reales, corregir fallas y comprobar el resultado completo. | Evidencia de que se cumplen todos los criterios de aceptación de la padre, sin defectos pendientes que los incumplan. |

La etiqueta histórica `backend` se conserva. Para identificar las nuevas subtareas de este esquema se utiliza `work:backend`.

### Qué revisar en Reglas y contrato

La revisión se limita a la funcionalidad de la padre; no es una auditoría general del repositorio.

| Resultado de la revisión | Pregunta que debe responder |
| --- | --- |
| Reutilizar | ¿Qué implementación o integración existe y coincide con la beta? |
| Adaptar | ¿Qué existe, pero necesita cambios? |
| Crear | ¿Qué comportamiento todavía falta? |
| Reemplazar o retirar del recorrido | ¿Qué regla anterior es incompatible con la beta? |

Las conclusiones deben señalar archivos, operaciones y pruebas relevantes. Hay que distinguir entre **código encontrado**, **pruebas leídas** y **pruebas ejecutadas con resultado observado**. Una issue anterior cerrada no demuestra por sí sola compatibilidad con la beta.

## Dependencias: preparar no es integrar

Backend e interfaz pueden avanzar contra un contrato acordado sin esperar necesariamente la implementación completa del otro. Un borrador visual también puede adelantarse si no depende de decisiones pendientes.

Mientras una dependencia esté pendiente, se puede:

- Precisar escenarios y preparar casos de prueba.
- Diseñar componentes y estados con fixtures coherentes con el contrato.
- Implementar partes propias que realmente sean independientes.

No se puede duplicar el backend de otra issue, suponer contratos no acordados ni presentar datos simulados como evidencia de un recorrido real. En Phoenix LiveView la separación entre interfaz y dominio no implica construir dos aplicaciones independientes.

Los blockers nativos de GitHub representan las dependencias registradas. Antes de descomponer una issue, se distingue qué bloquea el inicio de una subtarea y qué bloquea su integración o cierre. Esta guía no elimina ni modifica los blockers existentes.

## Regla de Integración y verificación

**La subissue de Integración sólo puede realizarse cuando todas las demás subissues de su issue padre estén terminadas y aprobadas.** Debe tener blockers nativos explícitos hacia todas sus subtareas hermanas y hacia todos los tickets que bloquean a su padre: no se asume que GitHub herede esas dependencias. Los blockers actuales entre padres se conservan. También deben estar disponibles las dependencias externas necesarias para ejecutar el recorrido real.

```text
Reglas y contrato
       ├── Backend terminado y aprobado ──┐
       └── Interfaz terminada y aprobada ──┤
                                          ▼
                             Integración y verificación
                                          ▼
                               Aprobación y cierre padre
```

Si hay otras subissues bajo la misma padre, también deben estar terminadas y aprobadas antes de iniciar Integración.

### Arreglos durante la integración

Integración puede modificar backend o interfaz para corregir fallas detectadas al conectar las partes. **No se reabren las subissues anteriores de backend o frontend por esas correcciones.**

Los arreglos, su motivo y las pruebas realizadas se registran en Integración. Deben conservarse o actualizarse las pruebas de las partes afectadas y comprobarse las regresiones aplicables. Esto no habilita funcionalidades nuevas fuera del alcance de la padre.

Si falta una decisión o una dependencia que impide demostrar el resultado, no se aprueba la integración ni se declara terminada la padre.

### Cierre de la issue padre

Aprobar Integración significa que la funcionalidad completa está terminada, no sólo que la pantalla se conecta con el backend.

Antes de aprobarla se comprueba:

- [ ] Todas las demás subissues están terminadas y aprobadas.
- [ ] El recorrido funciona con las implementaciones reales, no sólo con fixtures.
- [ ] Se verificaron todos los criterios de aceptación de la padre, incluidos permisos y errores aplicables.
- [ ] Se corrigieron las fallas encontradas y se ejecutaron las pruebas correspondientes.
- [ ] Quedaron registradas la evidencia y la aprobación final.

Después se registra el cierre de la padre en GitHub. La jerarquía de subissues y las etiquetas no garantizan un cierre automático.

## Contexto mínimo de cada subissue

Cada subtarea debe indicar su padre, el cambio OpenSpec y su ruta, las secciones que debe consultar, su alcance, criterios de aceptación y dependencias. Las referencias facilitan encontrar el contexto; no reemplazan su lectura.

Cada subissue debe tener su etiqueta `work:*` y el milestone correspondiente. No se asume que herede esos datos de la padre. La estimación de la funcionalidad se reparte entre sus partes; no se repite completa en cada hija.

## Tickets existentes por sprint

Esta tabla sirve como índice. El estado y el alcance actualizado de cada ticket se consultan en GitHub. Las issues padre y subissues del Sprint 3 se asignaron según la alternativa B indicada abajo; las subissues del Sprint 4 todavía no se crearon.

### Sprint 3 — Identidad y reservas

[Milestone en GitHub](https://github.com/Team-Origen/origen/milestone/5). Duración prevista: dos semanas; fechas pendientes.

| Issue | Funcionalidad |
| --- | --- |
| [#276](https://github.com/Team-Origen/origen/issues/276) | Registrar paciente inexistente desde Secretaría |
| [#277](https://github.com/Team-Origen/origen/issues/277) | Vincular acceso de paciente por magic link |
| [#278](https://github.com/Team-Origen/origen/issues/278) | Configurar perfil profesional apto para reserva |
| [#280](https://github.com/Team-Origen/origen/issues/280) | Reservar turno propio como Paciente |
| [#281](https://github.com/Team-Origen/origen/issues/281) | Agendar paciente existente desde Secretaría |
| [#282](https://github.com/Team-Origen/origen/issues/282) | Agendar paciente existente desde Profesional con privacidad |
| [#283](https://github.com/Team-Origen/origen/issues/283) | Registrar y agendar paciente inexistente desde Profesional |
| [#284](https://github.com/Team-Origen/origen/issues/284) | Resolver solicitudes con aprobación manual |
| [#290](https://github.com/Team-Origen/origen/issues/290) | Definir artefacto de aceptación de entrega beta |

Contrato para revisión de #317: [alta y reserva desde Profesional (#283)](sprint-3/contrato-283-alta-y-reserva-profesional.md). El acuerdo y la aprobación siguen pendientes.

Definir el artefacto de aceptación en #290 no equivale a producir todo el manual ni a ejecutar la aceptación final.

#### Tablero operativo de la beta

[Appointment Manager — Beta W16](https://github.com/orgs/Team-Origen/projects/6) reúne las issues existentes de esta entrega, sin duplicarlas. El proyecto anterior conserva el registro histórico.

- **Father Issues:** Wayfinder #266 y las 17 issues funcionales padre #276–#292. Esta columna identifica su nivel de seguimiento, no indica que estén desbloqueadas.
- **Ready:** subissues sin blockers nativos abiertos.
- **Backlog:** subissues con al menos un blocker nativo abierto.

El orden manual ubica primero el Wayfinder y los padres por slice de implementación. En Ready se priorizan los contratos que ayudan a desbloquear los recorridos; Backlog mantiene el orden por padre y etapa. La clasificación se toma de los blockers abiertos al organizar el tablero: no implica una automatización para futuros cierres de dependencias.

La vista general **Backlog** no tiene filtro. Las vistas copiadas **My Work** y **Current Sprint** conservan filtros de `Sprint 0`, y **History** usa la iteración anterior; esos filtros heredados no representan los milestones de la beta y requieren revisión antes de usarlas para el seguimiento actual.

#### Responsables del Sprint 3 — alternativa B

Cada responsable lleva las issues padre indicadas y todas sus subissues, incluida Integración y verificación. Los tipos de trabajo no se reparten entre integrantes distintos.

| Integrante | Usuario de GitHub | Issues padre |
| --- | --- | --- |
| Said | `Saidqr` | #276, #283 y #290 |
| Samuel | `samuel-olmos` | #277 y #280 |
| Santiago | `SantiCasali` | #278 y #282 |
| Lucca | `ChordanDev` | #281 y #284 |

Prioridad de arranque: completar #276 y #278 para desbloquear los recorridos; preparar temprano los contratos de #277 y #284. Se pueden adelantar partes independientes, pero las integraciones mantienen todos sus blockers. La asignación no autoriza cerrar tareas sin cumplir sus criterios ni cambia las fechas pendientes.

#### Subissues publicadas del Sprint 3

Cada enlace identifica un ticket real. Backend e Interfaz dependen de su Contrato; cada Integración depende de todas sus hermanas y de todos los blockers de su padre. #290 sólo tiene Contrato y verificación documental final: no necesita backend ni interfaz artificiales.

| Padre | Contrato | Backend | Interfaz | Integración y verificación |
| --- | --- | --- | --- | --- |
| #276 | [#293](https://github.com/Team-Origen/origen/issues/293) | [#294](https://github.com/Team-Origen/origen/issues/294) | [#295](https://github.com/Team-Origen/origen/issues/295) | [#296](https://github.com/Team-Origen/origen/issues/296) |
| #277 | [#297](https://github.com/Team-Origen/origen/issues/297) | [#298](https://github.com/Team-Origen/origen/issues/298) | [#299](https://github.com/Team-Origen/origen/issues/299) | [#300](https://github.com/Team-Origen/origen/issues/300) |
| #278 | [#301](https://github.com/Team-Origen/origen/issues/301) | [#302](https://github.com/Team-Origen/origen/issues/302) | [#303](https://github.com/Team-Origen/origen/issues/303) | [#304](https://github.com/Team-Origen/origen/issues/304) |
| #280 | [#305](https://github.com/Team-Origen/origen/issues/305) | [#306](https://github.com/Team-Origen/origen/issues/306) | [#307](https://github.com/Team-Origen/origen/issues/307) | [#308](https://github.com/Team-Origen/origen/issues/308) |
| #281 | [#309](https://github.com/Team-Origen/origen/issues/309) | [#310](https://github.com/Team-Origen/origen/issues/310) | [#311](https://github.com/Team-Origen/origen/issues/311) | [#312](https://github.com/Team-Origen/origen/issues/312) |
| #282 | [#313](https://github.com/Team-Origen/origen/issues/313) | [#314](https://github.com/Team-Origen/origen/issues/314) | [#315](https://github.com/Team-Origen/origen/issues/315) | [#316](https://github.com/Team-Origen/origen/issues/316) |
| #283 | [#317](https://github.com/Team-Origen/origen/issues/317) | [#318](https://github.com/Team-Origen/origen/issues/318) | [#319](https://github.com/Team-Origen/origen/issues/319) | [#320](https://github.com/Team-Origen/origen/issues/320) |
| #284 | [#321](https://github.com/Team-Origen/origen/issues/321) | [#322](https://github.com/Team-Origen/origen/issues/322) | [#323](https://github.com/Team-Origen/origen/issues/323) | [#324](https://github.com/Team-Origen/origen/issues/324) |
| #290 | [#325](https://github.com/Team-Origen/origen/issues/325) | No aplica | No aplica | [#326](https://github.com/Team-Origen/origen/issues/326) |

### Sprint 4 — Operación y beta integrada

[Milestone en GitHub](https://github.com/Team-Origen/origen/milestone/6). Duración prevista: dos semanas; fechas pendientes.

| Issue | Funcionalidad |
| --- | --- |
| [#279](https://github.com/Team-Origen/origen/issues/279) | Administrar ciclo de cuentas internas |
| [#285](https://github.com/Team-Origen/origen/issues/285) | Cerrar ciclo operativo del turno |
| [#286](https://github.com/Team-Origen/origen/issues/286) | Bloquear rangos puntuales de agenda |
| [#287](https://github.com/Team-Origen/origen/issues/287) | Registrar y corregir pagos simples |
| [#288](https://github.com/Team-Origen/origen/issues/288) | Consultar resumen económico por fecha de turno |
| [#289](https://github.com/Team-Origen/origen/issues/289) | Unificar navegación y mensajes del núcleo |
| [#291](https://github.com/Team-Origen/origen/issues/291) | Aplicar identidad visual aprobada |
| [#292](https://github.com/Team-Origen/origen/issues/292) | Completar aceptación de hosting en nube |

#291 depende de la decisión visual de [#274](https://github.com/Team-Origen/origen/issues/274). #292 depende de las condiciones de [#275](https://github.com/Team-Origen/origen/issues/275) y de las demás dependencias registradas en GitHub. Ubicar una issue en un sprint no elimina sus bloqueos ni garantiza su fecha de entrega.

### Sprint 5 — Estabilización y documentación

[Milestone en GitHub](https://github.com/Team-Origen/origen/milestone/7). Duración prevista: dos semanas; fechas pendientes. Reservado para correcciones puntuales, regresión, documentación final, datos ficticios por flujos reales y evidencia de entrega. Por ahora no tiene issues asignadas.

No se planifica dejar funcionalidades incompletas deliberadamente para este sprint. La ejecución del manual y las evidencias requiere seguimiento propio; no se considera realizada por cerrar #290.

## Ejemplo de trabajo de un integrante

En #287, el responsable revisa primero qué existe sobre precios y pagos y fija el contrato según la beta. Implementa y prueba las operaciones de pago; prepara la interfaz con los estados acordados. Puede alternar esas actividades según sus dependencias.

Cuando Contrato, Backend e Interfaz están terminados y aprobados, comienza Integración. Ejecuta el recorrido real, corrige allí las fallas que aparezcan sin reabrir las otras subissues, registra las pruebas y verifica todos los criterios de #287. Sólo después aprueba Integración y registra el cierre de #287.

## Siguiente paso

Comenzar el Sprint 3 con los responsables acordados, revisar los contratos y ajustar las estimaciones con evidencia del estado actual. Las subissues y asignaciones del Sprint 4 requieren su propio lote autorizado. No forzar cuatro subtareas en documentación, identidad visual, infraestructura o cambios pequeños cuando el patrón no corresponda.
