# Borrador del estándar de trabajo entre IA y equipo

> **Para revisión del equipo.** Este documento propone los artefactos y reglas que podrían activarse después de una aprobación explícita de los cuatro integrantes.

## Índice

1. [Estado del borrador](#1-estado-del-borrador)
2. [Decisiones ya acordadas](#2-decisiones-ya-acordadas)
3. [Arquitectura futura de archivos](#3-arquitectura-futura-de-archivos)
4. [Borradores copiables](#4-borradores-copiables)
5. [Reglas de colaboración humano--IA](#5-reglas-de-colaboración-humanoia)
6. [Flujo operativo resumido](#6-flujo-operativo-resumido)
7. [Decisiones pendientes](#7-decisiones-pendientes-antes-de-activar)
8. [Plan de adopción](#8-plan-de-adopción)
9. [Qué no duplicar](#9-qué-no-duplicar)

## 1. Estado del borrador

Este documento es **pasivo**: no está activo, no configura IA, no instala skills, no publica ni modifica issues y no cambia GitHub. Su único fin es permitir que el equipo revise, comente y corrija el estándar antes de convertirlo en archivos operativos.

## 2. Decisiones ya acordadas

| Tema                 | Acuerdo vigente                                                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Equipo y ritmo       | Cuatro integrantes; sprints de dos semanas.                                                                                  |
| Capacidad            | Máximo planificable inicial: **64 h-equipo** por sprint.                                                                     |
| Unidad de alcance    | Las issues son **slices verticales** pequeñas, demostrables y revisables.                                                    |
| Descomposición       | Cada issue contiene un checklist de tareas; no se crean issues separadas por capa.                                           |
| Nivel administrativo | No existe `work unit` como nivel administrativo.                                                                             |
| Commits              | Son coherentes por comportamiento y pueden completar una o varias tareas del checklist.                                      |
| PR                   | Idealmente, una issue vertical por PR.                                                                                       |
| Tablero              | `Backlog -> Ready -> In Progress -> Review -> Validation -> Done`.                                                           |
| WIP inicial          | Una issue activa por integrante; si se acumula revisión o validación, se ayuda a vaciar esas columnas antes de iniciar otra. |
| Autoridad documental | `Origen_Documentacion.md` es la fuente funcional y `CONTEXT.md` es el glosario canónico.                                     |

## 3. Arquitectura futura de archivos

El siguiente árbol **no existe todavía** como configuración activa; muestra qué se materializaría tras la aprobación:

```text
proyectoOrigen/
├── AGENTS.md
├── .opencode/
│   └── skills/
│       └── origen-delivery-workflow/
│           └── SKILL.md
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── vertical-slice.md
│   └── pull_request_template.md
├── Origen_Documentacion.md       # fuente funcional existente
├── CONTEXT.md                    # glosario canónico existente
└── sprints/
    └── PLAN_TENTATIVO_11_SPRINTS.md  # roadmap, flujo y DoD canónicos existentes
```

No se requiere un `opencode.json` para una skill de proyecto en la ruta estándar propuesta. Una skill versionada del proyecto se comparte al clonar o actualizar el repositorio; después de activarla, cada integrante debe reiniciar OpenCode para que cargue el cambio.

## 4. Borradores copiables

### 4.1 Futuro `AGENTS.md`

```markdown
# Estándar de entrega de Origen

## Reglas obligatorias

- Consulta `Origen_Documentacion.md` como fuente funcional y `CONTEXT.md` para términos y estados canónicos. No los contradigas ni los reinterpretes.
- Sigue `sprints/PLAN_TENTATIVO_11_SPRINTS.md` como fuente canónica del flujo y la DoD: `Backlog -> Ready -> In Progress -> Review -> Validation -> Done`.
- Toma una issue solo desde `Ready`: debe ser una slice vertical con resultado, criterios de aceptación, dependencias, permisos, auditoría, privacidad y prueba enfocada definidos.
- Mantén el checklist dentro de la issue. No crees trabajo separado por modelo, backend, interfaz o pruebas.
- Respeta el WIP inicial: una issue activa por integrante. Ayuda a vaciar `Review` o `Validation` antes de iniciar otra.
- Crea commits coherentes por comportamiento; un commit puede completar una o varias tareas e incluye las pruebas relacionadas. No uses `work unit` como estado o nivel administrativo.
- Vincula la PR con la issue; idealmente una issue vertical por PR. Mueve a `Review` al abrirla y a `Done` solo tras revisión, validación, merge y cierre correspondiente.
- Ejecuta y registra las pruebas proporcionales al riesgo. La DoD exige camino positivo, errores relevantes, permisos de backend, auditoría y privacidad cuando apliquen.
- Aplica autorización por defecto-denegar en backend. No expongas datos personales, secretos ni evidencia prohibida en interfaz, logs o auditoría.
- La IA puede proponer, implementar y documentar; no publica ni cierra issues, no hace merge y no cambia la fuente funcional sin aprobación humana explícita.
- Los artefactos técnicos se escriben en inglés salvo que el repositorio o la persona solicitante indiquen otra convención; la documentación de equipo puede estar en español profesional.
```

### 4.2 Futura skill `.opencode/skills/origen-delivery-workflow/SKILL.md`

```markdown
---
name: origen-delivery-workflow
description: "Trigger: sprint, issue, task, commit, PR, implementar issue. Apply Origen's approved vertical-slice delivery workflow."
license: Apache-2.0
metadata:
  author: "<github-username-o-equipo>"
  version: "1.0"
---

## Activation Contract

Load when planning a sprint slice, refining or implementing an issue, creating commits, or preparing a PR in Origen.

## Hard Rules

- Treat `Origen_Documentacion.md` as functional authority and `CONTEXT.md` as the canonical glossary.
- Deliver one demonstrable vertical slice; keep its tasks, permissions, audit, privacy, and focused tests in the same issue.
- Do not create horizontal issues, invent domain rules, bypass backend authorization, expose personal data or secrets, or treat a work unit as an administrative level.
- Do not publish or close issues, merge, or alter functional authority without explicit human approval.

## Decision Gates

| Condition                                                         | Action                                                    |
| ----------------------------------------------------------------- | --------------------------------------------------------- |
| Criteria, dependencies, authorization, audit, or test are unclear | Keep in `Backlog`; request the smallest missing decision. |
| Slice exceeds sprint capacity or has unresolved blocker           | Split by demonstrable outcome or defer.                   |
| `Review` or `Validation` accumulates                              | Help clear it before starting new work.                   |

## Execution Steps

1. Read the local sources and confirm the slice fits `Ready`.
2. Respect one active issue per contributor and move through the documented board states.
3. Implement behavior across necessary layers; test during development.
4. Commit coherent behaviors with related tests; one commit may cover multiple checklist tasks.
5. Prepare one linked PR per issue when practical; record scope, review path, evidence, risks, and exclusions.
6. Require independent review, functional validation, merge, then issue closure before `Done`.

## Output Contract

Return the proposed or completed state, checklist progress, tests/evidence, blockers, risks, and required human approvals. State when no publication, closure, merge, or authority change was performed.

## References

- `../../../Origen_Documentacion.md`
- `../../../CONTEXT.md`
- `../../../sprints/PLAN_TENTATIVO_11_SPRINTS.md`
```

### 4.3 Futuro template `.github/ISSUE_TEMPLATE/vertical-slice.md`

```markdown
---
name: Vertical slice
about: Plan a small, demonstrable Origen outcome
title: "[Sprint N] "
labels: []
assignees: []
---

## Resultado a construir

<!-- Resultado observable para una persona usuaria o rol. Referenciar HU/RF/RNF si aplica. -->

## Criterios de aceptación

- [ ]

## Checklist de tareas

- [ ] Regla de dominio, persistencia e integración o interfaz necesarias para el resultado
- [ ] Autorización de backend por defecto-denegar, cuando aplique
- [ ] Auditoría y privacidad, cuando apliquen
- [ ] Pruebas enfocadas: camino positivo, errores relevantes y controles aplicables

## Dependencias y bloqueos

- Dependencias:
- Bloqueos:
- Reestimación requerida:

## Fuera de alcance

-

## Evidencia y Definition of Done

- [ ] Criterios de aceptación demostrados
- [ ] Pruebas ejecutadas y resultado registrado
- [ ] Permisos, auditoría y privacidad revisados cuando aplican
- [ ] PR revisada y validada funcionalmente
- [ ] Cambio integrado sin pendiente crítica fuera de esta issue

## Planificación

| Campo              | Valor      |
| ------------------ | ---------- |
| Sprint / Iteration |            |
| Tipo               | AFK / HITL |
| Estimación         |            |

## AFK / HITL

- **AFK:** trabajo que puede avanzar sin decisión humana adicional una vez aprobado el alcance.
- **HITL:** decisión, aprobación, validación o acceso humano requerido.
- Acción humana pendiente:
```

### 4.4 Futuro template `.github/pull_request_template.md`

```markdown
## Issue vinculada

<!-- Usar `Closes #...` solo si el merge debe cerrar esta issue. -->

## Qué cambia

-

## Cómo revisar

1.

## Evidencia de pruebas

| Prueba o validación | Comando o escenario | Resultado |
| ------------------- | ------------------- | --------- |
|                     |                     |           |

## Riesgos, permisos y auditoría

- Permisos de backend:
- Auditoría:
- Privacidad o secretos:
- Riesgo residual:

## Fuera de alcance

-

## Checklist

- [ ] La PR corresponde a una issue aprobada y vinculada.
- [ ] Los criterios de aceptación y el checklist relevante están cubiertos.
- [ ] Las pruebas y su evidencia están registradas.
- [ ] Otra persona revisó permisos, auditoría, privacidad y reglas de dominio aplicables.
- [ ] La validación funcional está registrada cuando corresponde.
- [ ] No hay cambios laterales no explicados.

<!-- Closes #<issue-number> -->
```

## 5. Reglas de colaboración humano–IA

| La IA puede                                                              | Los humanos deciden, revisan o autorizan                    |
| ------------------------------------------------------------------------ | ----------------------------------------------------------- |
| Proponer slices, checklist, pruebas, código y documentación.             | Alcance y prioridad.                                        |
| Implementar y resumir evidencia bajo instrucciones aprobadas.            | Aprobación de producto.                                     |
| Detectar riesgos de permisos, auditoría, privacidad y reglas de dominio. | Revisión de permisos, privacidad y reglas de negocio.       |
| Preparar borradores de issue y PR.                                       | Validación funcional y autorización de merge o publicación. |

La IA no publica issues, no cierra issues, no hace merge ni modifica la fuente funcional sin aprobación humana explícita.

## 6. Flujo operativo resumido

1. El equipo selecciona slices por dependencia y riesgo dentro de la capacidad del Sprint.
2. Se refina cada slice: resultado vertical, criterios, checklist, permisos, auditoría, privacidad, pruebas, dependencias, estimación y fuera de alcance.
3. Solo una slice entendible y desbloqueada entra en `Ready`.
4. Una persona la toma y mueve a `In Progress`, respetando el WIP.
5. Se implementa y prueba durante el desarrollo; los commits cuentan comportamientos coherentes, no capas o archivos.
6. Se abre la PR vinculada y la issue pasa a `Review`; otra persona revisa código y requisitos.
7. Con aprobación, pasa a `Validation`; se demuestra el comportamiento y se registra evidencia.
8. Tras revisión, validación y merge autorizados, la issue se cierra cuando corresponda y pasa a `Done`.

## 7. Decisiones pendientes antes de activar

- [ ] Confirmar el stack Phoenix / Elixir / LiveView / PostgreSQL: actualmente es recomendado, no una decisión formal.
- [ ] Definir el nombre final del repositorio.
- [ ] Definir la rama base y la estrategia de ramas.
- [ ] Completar el username o autor de la skill.
- [ ] Acordar labels y quién puede aplicarlos.
- [ ] Definir reglas de protección de ramas.
- [ ] Definir quién puede hacer merge.
- [ ] Acordar el comando de pruebas y los controles obligatorios.
- [ ] Acordar el formato de estimación.

## 8. Plan de adopción

1. Revisión de los cuatro integrantes.
2. Aprobación explícita del estándar y de las decisiones pendientes.
3. Materialización de los archivos propuestos.
4. Actualización del skill registry ya resuelto en `.atl/skill-registry.md`.
5. Commit de los artefactos aprobados.
6. Todos actualizan su clon del repositorio.
7. Reinicio de OpenCode para cargar la skill de proyecto activada.
8. Prueba piloto con una issue vertical.

## 9. Qué no duplicar

| Contenido                                                                        | Fuente que debe conservarlo |
| -------------------------------------------------------------------------------- | --------------------------- |
| Requisitos, reglas funcionales y restricciones detalladas                        | `Origen_Documentacion.md`   |
| Definiciones y términos del dominio                                              | `CONTEXT.md`                |
| Roadmap, capacidad, dependencias, riesgos, flujo y Definition of Done por Sprint | `sprints/PLAN_TENTATIVO_11_SPRINTS.md` |

Los futuros artefactos de operación deben referenciar estas fuentes, no copiarlas ni redefinirlas.

a- Añadir que las issues se vinculen a su archive de openspec

b- El agente tiene que saber que existe tidewave

c- dailys

d- Pr en draft luego de primer commit

e- La persona debe linkear la issue al PR

f- Bloquear de manera las issues

g- Feature branch chain
