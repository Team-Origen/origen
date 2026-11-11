# Issue 72: Construir runbook y reporte durable de la demo integrada

## Outcome

Construir el runbook y reporte durable de la demo integrada (PLN-14 / Issue #72 / Father Issue #47): documentar el procedimiento paso a paso para reproducir la demostración en un entorno local limpio, registrando comandos exactos, estados resultantes esperados, evidencias sanitizadas del caso de éxito y de los controles negativos (solapamientos, perfiles incompletos y accesos no autorizados), quedando como un artefacto durable y profesional para la presentación ante los docentes evaluadores y el equipo.

## Problem

De cara a la evaluación del Sprint 1 ante los profesores, el equipo requiere una guía estandarizada, clara y a prueba de fallos que permita a cualquier integrante o docente clonar el repositorio, levantar la aplicación en un entorno local limpio y ejecutar o comprobar tanto el flujo feliz (Profesional configura -> Paciente reserva -> Profesional visualiza) como los rechazos de seguridad y concurrencia sin riesgo de confusión ni configuraciones ocultas.

## Why

Proveer un artefacto durable de alta calidad técnica que certifique la integración temprana lograda en PLN-14, sirva de guion para la demo en vivo y constituya el reporte formal de cierre de la Father Issue #47.

## Authorized scope

- Runbook y reporte durable de la demo: `docs/demo/RUNBOOK_DEMO_INTEGRADA.md`.
- Suite automatizada de verificación de integridad del runbook y scripts: `test/origen/integration/demo_runbook_verification_test.exs`.
- Documento de seguimiento ODD: `odd/tasks/issue-72-integrated-demo-runbook-report.md`.
- Rama local: `feature/72-integrated-demo-runbook-report`.
- Pull Request: enlazado a la subissue mediante `Closes #72`.

## Checklist

- [x] ODD-72-01 — Crear rama de trabajo `feature/72-integrated-demo-runbook-report` y verificar baseline limpio.
- [x] ODD-72-02 — Redactar el Runbook y reporte durable de la demo integrada (`docs/demo/RUNBOOK_DEMO_INTEGRADA.md`) con procedimiento en local limpio, comandos y guía visual paso a paso para docentes.
- [x] ODD-72-03 — Integrar evidencia sanitizada del recorrido principal (#70) y controles negativos de solapamiento, perfil incompleto y accesos no autorizados (#71).
- [x] ODD-72-04 — Construir suite de verificación automatizada del runbook y consistencia de scripts (`test/origen/integration/demo_runbook_verification_test.exs`).
- [x] ODD-72-05 — Ejecutar comprobaciones, validar formateo y documentar evidencia en el artefacto ODD.
- [x] ODD-72-06 — Preparar commit de unidad de trabajo y Pull Request enlazado a la subissue (`Closes #72`).

## Acceptance criteria

- [x] Documenta el procedimiento para reproducir la demostración en un entorno local limpio.
- [x] Registra comandos, estados resultantes y evidencia sanitizada del recorrido.
- [x] Incluye controles negativos de solapamiento, perfil incompleto y acceso no autorizado.
- [x] Queda como artefacto durable revisable por el equipo y los docentes.

## Applicable checks

- `mix test test/origen/integration/demo_runbook_verification_test.exs` (7 passed)
- `mix test test/origen/integration/` (24 passed)
- `mix test` (630 passed, 0 failures)
- `mix run priv/repo/check_prototype_journey_e2e.exs` (0 warnings)
- `mix run priv/repo/check_journey_failure_regression.exs` (0 warnings)
- `mix compile --warnings-as-errors` (limpio)
- `mix format --check-formatted` (limpio)

## Progress and evidence

- Rama `feature/72-integrated-demo-runbook-report` creada a partir de `feature/71-integrated-journey-regression-rollback`.
- Runbook durable y profesional creado en `docs/demo/RUNBOOK_DEMO_INTEGRADA.md`:
  - Procedimiento de inicialización paso a paso para entorno local limpio (`mix deps.get`, `mix ecto.reset`, `mix phx.server`).
  - Instrucciones de ejecución para scripts automatizados con sus salidas esperadas sanitizadas (`priv/repo/check_prototype_journey_e2e.exs` y `priv/repo/check_journey_failure_regression.exs`).
  - Guion de demostración interactiva web paso a paso para la presentación ante los profesores (Acceso por Magic Link en `/dev/mailbox` -> Completar perfil DNI -> Desafío telefónico de 6 dígitos -> Reserva en calendario interactivo `/patient/calendar` -> Proyección en agenda profesional `/profesional/agenda`).
  - Matriz exhaustiva de 8 controles negativos (CN-01 a CN-08): doble reserva simultánea con exclusión GiST de PostgreSQL, paciente sin teléfono verificado (RF-02 ter), perfil incompleto, colisión documental de DNI derivada a secretaría, aislamiento horizontal entre profesionales, inmunidad contra IDOR, rechazo de accesos no autenticados (401/403) y rollback atómico total ante fallos.
  - Tablas de evidencia forense sanitizada en SQL (`appointments`, no orfandad relacional y `audit_events` append-only).
  - Checklist para el presentador durante la demo en vivo.
- Suite de verificación automatizada creada en `test/origen/integration/demo_runbook_verification_test.exs` con 7 pruebas que validan la existencia y contenido del runbook, las rutas web en `OrigenWeb.Router`, los comandos y la trazabilidad con PLN-14 / Father Issue #47.
