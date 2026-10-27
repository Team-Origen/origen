# Issue #314 — Professional agenda privacy backend
OpenSpec change: `health-center-beta-core` (`openspec/changes/health-center-beta-core/`).
Scope: backend slice of parent #282 under the approved contract #313; UI #315 and integration #316 remain out of scope.

## Specs

1. **S1 — Backend entry points.** Issue #314: “Permitir al Profesional seleccionar relacionado o buscar por DNI exacto y agendar únicamente en su agenda sobre motor compartido.”
2. **S2 — Relationship timing and privacy.** Issue #314: “Crear relación sólo al concretar solicitud/turno, incluida solicitud pendiente; nunca al buscar/abandonar; impedir acceso a agendas e historia ajenas.”
3. **S3 — Required backend evidence.** Issue #314: “Probar búsqueda, abandono, concreción, ocupación y aislamiento entre dos Profesionales; verificar ausencia de relación/cambios ante búsquedas o rechazos y reutilizar regresión #202.”
4. **S4 — Parent acceptance.** Parent #282: “Buscar/abandonar no crea relación.” “Concretar solicitud o turno crea relación.” “No revela actividad con otros Profesionales.”
5. **S5 — Professional booking result.** Contract #313: “La creación por Profesional nace `confirmed`, ocupa el horario y establece o reutiliza la relación Profesional–Paciente de manera atómica, tanto en modalidad automática como manual. No aplica el estado histórico calculado por D-1.”
6. **S6 — Minimal projection and exact search.** Contract #313: “Lista y resultado exacto muestran exclusivamente **nombre, apellido y DNI**. No exponen teléfono, email, otros Profesionales, citas, historial, cantidad de atenciones ni indicadores de actividad ajena.” “La búsqueda exacta se limita al recorrido de creación. No admite prefijos, sugerencias ni resultados globales.”
7. **S7 — Session-bound authorization.** Contract #313: “El servidor identifica al Profesional por su sesión vigente; no permite operar otra agenda.” “Alterar IDs no habilita una selección ni una agenda ajena.”
8. **S8 — Atomic rejection.** Contract #313: “Una validación rechazada o una falla de persistencia no deja turno, relación nueva ni evento de reserva exitosa parcial. Una relación preexistente permanece intacta. El rechazo no devuelve actividad ni datos de otra agenda.”
9. **S9 — Shared requested rule.** Contract #313: “La regla transversal beta es que completar una solicitud `requested` **o** un turno crea relación. Esto no habilita crear pendientes desde este canal: los pedidos de otros canales y su resolución siguen siendo responsabilidad de sus slices y de #284.”
10. **S10 — Boundaries.** Issue #314: “No ampliar el alcance de la padre, inventar decisiones pendientes, asignar personas, seleccionar branding/hosting/presupuesto ni cambiar blockers entre padres. No dar por verificado el recorrido integrado ni sustituir pruebas propias por la futura integración.”

## Tasks

- [ ] **T1** — S1, S2, S4, S6, S7: add session-bound related-patient listing and exact-DNI registered-patient lookup with minimal projection; test RED/GREEN. Route: parent inline. Commit: pending explicit authorization.
- [ ] **T2** — S1, S2, S3, S5, S7, S8: add professional-own-agenda booking orchestration over the shared engine, always `confirmed`, with atomic relationship behavior and occupied-slot/privacy tests. Route: parent inline. Commit: pending explicit authorization.
- [ ] **T3** — S2, S4, S9: align the shared `requested` relationship rule with beta without duplicating #284, and update touched-channel regressions. Route: parent inline; high-risk shared contract requires independent verification. Commit: pending explicit authorization.
- [ ] **T4** — S3, S8, S10: run focused and full regression checks, independently verify high-risk authorization/privacy behavior, and record sanitized evidence without claiming UI/integration completion. Route: parent plus `gentle-ai-verify`. Commit: pending explicit authorization.

## Log

- **L1 — User request:** “quiero que veas lo que se a implementado lo que hay que hacer en esta issue, lo que pide la issue padre y lo que pide el contrato y nos pongamos a trabajar”
- **L2 — Exploration:** Existing code already provides the shared atomic booking engine, overlap constraints, durable unique relationships, own-agenda authorization, and #202 privacy regressions. Missing backend operations are related-patient listing, contextual exact-DNI lookup, and session-bound professional booking that always confirms. The shared `requested` relationship exception conflicts with the approved beta rule and must be changed carefully because other channels use it.
- **L3 — T1 progress:** Added public-interface tests and implementation for session-bound related-patient listing and exact-DNI lookup with minimal projection. `mix format --check-formatted` and `mix compile --warnings-as-errors` pass. The first database run reached ExUnit after PostgreSQL became available: 6/7 passed and one fixture setup violated the existing inactive-account database constraint. After correcting only that fixture, the focused suite passed: 7/7. T1 awaits its required work-unit commit before closure.
