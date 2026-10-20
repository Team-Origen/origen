# Health-center beta core specification

Scope: beta specification and authorized GitHub planning, including Sprint 3 subissue publication; no application implementation or deployment. Sprint 3 assignments are authorized by S11. The user subsequently authorized a local documentation commit; push is not authorized.
Source of truth: approved beta OpenSpec, Wayfinder map #266 and its historical resolutions #267–#273.

## Specs

1. **S1 — Core scope.** "Todo lo incluido se busca para beta. Orden no constituye recorte automático ni estimación o reparto."
2. **S2 — Independent pending decisions.** "No se darán por resueltos: bloquearán únicamente el trabajo que dependa de ellos, sin inventar nombre, colores, proveedor o presupuesto."
3. **S3 — Patient identity and access.** "Autogestión solo de turnos propios. Acceso exclusivamente mediante magic link enviado a correo, sin contraseña." "Profesional y secretaría buscan primero al paciente existente; si no existe pueden registrarlo y agendarlo sin cuenta ni correo."
4. **S4 — Roles, booking, and privacy.** "Tres canales" for booking; the professional relationship is created only when an appointment request or appointment is completed; professionals cannot see a patient's other-professional activity.
5. **S5 — Appointment lifecycle.** "Pendiente ocupa horario"; only the professional decides pending requests; unresolved requests expire at their start time; cancellation, attendance, and history follow #271.
6. **S6 — Payments and summaries.** "Un único pago total por turno, pendiente/pagado, efectivo o transferencia." Summaries use appointment date, not collection date, and preserve the stated inclusions/exclusions.
7. **S7 — Week-16 delivery boundary.** "Sistema accesible desde un entorno en la nube" and its manual, real-flow test data, functional/permission checks, and stabilization remain required beta outcomes, but belong to a separate acceptance artifact, not this core specification.
8. **S8 — Exclusions.** Preserve every beta exclusion in #266 and `notes/resumen-beta-semana-16.md`, including mandatory phone verification, WhatsApp, clinical records, fines, direct rescheduling, payment receipts/partials/refunds, dependants, waiting list, advanced reporting, patient self-editing, credential verification/catalogues, per-centre branding, and performance testing.
9. **S9 — Ticket publication (verbatim):** "/to-tickets  openspec/changes/health-center-beta-core/

   Usá la spec completa y las resoluciones del mapa #266. Proponé tickets para todo el núcleo aprobado, sin asignar
 integrantes, sprints ni estimaciones: eso lo haremos después de revisar los tickets.

   Identidad visual y hosting siguen pendientes y solo bloquean trabajo dependiente. No pierdas el alcance
 obligatorio de entrega de beta, que tendrá un artefacto de aceptación separado. Respetá la trazabilidad
 OpenSpec–GitHub de AGENTS.md."

10. **S10 — Sprint 3 subissues (verbatim):** "creemos las sub issues del sprint 3"
    - "el contrado y el frond se puede ir desarrllanod, pero algo que si o si tiene que etar bloqeuado sgun los bloques de su padre es la iisue de integracion"
    - "la sub issue de integracion recien se va a poder realizar una ves realizadas los otras otras sub issues de la ticken en si. el hecho que se apruebe esta da como entendido que la issue padre completa esta  terminada."
    - "en seccion de integracion y verificacion se podra hacer arreglos si falla el integracion. no se tendra que reabrir la issue de back o de fornd. coisdo con vos con pruebas de cada parte. no estaremos por ahora asigando a personas distintas la seccion de aprovacion."

11. **S11 — Alternative B assignment (verbatim):** "avancemos con la alternativa B". Assign each parent and all its children to one owner: Saidqr #276/#283/#290; samuel-olmos #277/#280; SantiCasali #278/#282; ChordanDev #281/#284. Preserve scope, bodies, blockers, labels and milestones; no Sprint 4 changes.

12. **S12 — Project organization (verbatim):** "losto ahi cree el proyecto Appointment Manager — Beta W16. agrupa la issue en el orden correspondiente y relacionalas a ese proyecto. incluyendo tambien la issue de way finder. en fater por la issue padres, en bckalog las que estan bloqueadas y en readi las desblqoeuadas". Authorization continuation: "estas autorizado". Target: organization project 6; Wayfinder #266 and functional parents #276–#292 in Father Issues; children #293–#326 in Backlog when any native blocker remains open, otherwise Ready. Preserve issue content, assignees, labels, milestones and dependencies, and existing project items. Order parents by implementation slice and children by parent/dependency order, with early-unblocking contracts first in Ready.

## Tasks

- **T1 — S1–S2, S7–S8 — completed inline — commit: not authorized:** Published proposal and design boundaries.
- **T2 — S3–S6 — completed inline — commit: not authorized:** Published normative OpenSpec capability specifications.
- **T3 — S1–S8 — completed inline — commit: not authorized:** Validated terminology, traceability, and scope exclusions.
- **T4 — S9 — completed — commit: not authorized:** Published #276–#292 under #266, verified native blockers, and synchronized reverse OpenSpec references.

- **T5 — S10 — completed — commit: not authorized:** Published and verified 34 Sprint 3 subissues #293–#326 under nine parents; verified exact bodies, labels, milestone, 54 native dependencies and unchanged parent bodies/blockers. Reverse links and developer guide updated. No Sprint 4 subissues or assignees.

- **T6 — S11 — completed — commit: not authorized:** Applied Alternative B to all 43 Sprint 3 issues; final GitHub readback verified exact owners, same ownership per family and unchanged bodies, titles, labels, milestones, hierarchy and blockers. Developer guide updated and local checks passed.

- **T7 — S12 — completed — commit: not authorized:** Added and independently read back 52 existing issues in project 6: 18 Father Issues, nine Ready and 25 Backlog. Exact membership, manual order, blocker-based classification and unchanged issue metadata verified. Guide updated; local links and git diff --check passed.

## Log

- **L11 — Local commit authorization (verbatim):** "puedes hacer commit de lo realizado??". Later scope correction (verbatim): "si todavia aparceen lo documento de skalidaw, quiero que los borres, ya que tiene muchas lineas de codigo". Removed remaining diagram SVG, snapshot, generator and diagram-specific task record; editable Excalidraw file was already absent. Removed guide diagram links. Commit includes only beta specification, guide and planning evidence; unrelated repository changes and the original Downloads reference remain untouched. Structural and guide-link checks plus `git diff --check` passed; an initial over-strict local assertion requiring scenarios in every spec was corrected because beta-boundaries is a requirements-only document. OpenSpec CLI validation remains unavailable. No application tests apply to this documentation-only commit; no push authorized.

- **L10 — Project verification evidence:** Population job-9 and final read-only verification job-10 exited 0. Project 6 contains exactly #266 and #276–#326: 18 Father Issues, nine Ready contracts and 25 Backlog subissues. Exact global manual order verified. Titles, bodies, states, assignees, labels, milestones and native blocker sets unchanged; Ready items have no open native blockers. Record: `odd/tasks/health-center-beta-core-project.json` (`status: verified`). Guide updated and local structural/link checks plus `git diff --check` passed. Copied My Work and Current Sprint views still filter Sprint 0; general Backlog view is unfiltered. No automatic dependency-to-status workflow was configured. No application implementation or commits.
- **L9 — User project request (verbatim):** "losto ahi cree el proyecto Appointment Manager — Beta W16. agrupa la issue en el orden correspondiente y relacionalas a ese proyecto. incluyendo tambien la issue de way finder. en fater por la issue padres, en bckalog las que estan bloqueadas y en readi las desblqoeuadas". Continuation: "estas autorizado". Access confirmed after the user authorization; actual Status option is Father Issues, not Feature. Project: https://github.com/orgs/Team-Origen/projects/6.
- **L1 — User request (verbatim):** "/to-spec  Prepará una propuesta de especificación del núcleo aprobado usando
   como fuente el mapa Wayfinder:
   https://github.com/Team-Origen/origen/issues/266

   Leé las resoluciones completas de los tickets históricos enlazados,
   no solamente los resúmenes del mapa. Contrastá lo acordado con el
   código y las convenciones del proyecto.

   Mantené identidad visual y condiciones de hosting como pendientes
   explícitos, sin inventar respuestas ni bloquear partes independientes.
   La prioridad de implementación no significa exclusión de la beta."
- **L2:** User approved publishing the refined specification after choosing to keep week-16 cross-cutting delivery acceptance outside the core specification.
- **L3:** Published `openspec/changes/health-center-beta-core/` with proposal, design, and five capability specifications. `git diff --check` passed; the OpenSpec CLI is unavailable, so no CLI validation ran. No implementation tickets, source-code changes, tests, deployment, or commit were created.
- **L4:** User approved the refined vertical-slice batch, including splitting Secretary work into registration of an absent patient and agenda operation for an existing patient. User selected explicit blocked tickets for visual identity and hosting, and authorized creation as new GitHub subissues of #266 using the active GitHub session.
- **L5:** Created and read back all 17 issues #276–#292, verified parent membership, OpenSpec bindings, labels, native blockers, and no assignees/milestones. Updated proposal Tracking with all reverse links. `git diff --check` passed. Initial CLI attempt rejected unsupported `--parent` before creation; used the documented REST subissue operation. Open implementation frontier: #276, #278, #279, #290. No implementation or commit performed.
- **L6 — User request (verbatim):** "creemos las sub issues del sprint 3". Previously approved milestones and work labels apply. Follow docs/sprints/GUIA_TRABAJO_BETA.md with the later explicit rule: integration also depends directly on every current parent blocker. All subissues remain unassigned; no separate approvers; integration fixes do not reopen backend/frontend.
- **L8 — User authorization (verbatim):** "avancemos con la alternativa B". Preflight confirmed the four assignable users, nine open parents and 34 open children in milestone 5 with no previous assignees. Final verification confirmed Saidqr owns #276/#283/#290 and all children (13 issues); samuel-olmos #277/#280 (10); SantiCasali #278/#282 (10); ChordanDev #281/#284 (10). Original bodies, titles, labels, milestones, hierarchy and blockers preserved. Record: `odd/tasks/health-center-beta-core-sprint3-assignment.json` (`status: verified`). Developer guide ownership table, local links, whitespace and `git diff --check` passed. No Sprint 4 changes, application implementation, deployment or commits.
- **L7 — Publication evidence:** Created #293–#326: four children for each of #276, #277, #278, #280, #281, #282, #283 and #284; contract and final documentary verification for #290. GitHub readback confirmed 34 exact child bodies, nine child sets, work labels, milestone 5, no assignees, 54 exact native dependency edges and original parent bodies/blockers unchanged. Sprint 3 contains 43 issues including its nine parents. Record: `odd/tasks/health-center-beta-core-sprint3-publication.json` (`status: verified`). Local reverse links, guide links, document structure and dependency/parent-closure acyclicity passed; `git diff --check` passed. No application implementation, Sprint 4 publication, deployment or commit performed. Existing beta specification and guide remain local uncommitted artifacts; publication does not make those files available in remote GitHub branches.
