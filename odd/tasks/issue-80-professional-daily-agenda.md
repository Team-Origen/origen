# Issue 80: Construir la agenda diaria del Profesional

## Outcome

Construir la interfaz Phoenix LiveView de la agenda diaria del Profesional autenticado (PLN-10 / Issue #80), visualizando turnos en orden cronológico, con estados de carga, agenda vacía y error, operable con teclado y adaptada a pantallas angostas.

## Problem

El profesional requiere una interfaz web interactiva para visualizar sus turnos programados del día, navegar entre fechas, y obtener claridad inmediata sobre su agenda sin retrasos ni desbordamientos en dispositivos móviles.

## Why

Proveer una experiencia de usuario rápida, accesible y segura donde el profesional visualice exclusivamente su actividad diaria sin riesgo de fugas de datos y con resiliencia ante estados vacíos o errores.

## Authorized scope

- LiveView en `lib/origen_web/live/professional_agenda_live.ex`.
- Enrutamiento en `lib/origen_web/router.ex` bajo `/profesional/agenda` protegido por pipelines y `on_mount` de rol profesional.
- Suite de pruebas de LiveView en `test/origen_web/live/professional_agenda_live_test.exs`.
- Rama local: `feature/80-professional-daily-agenda`.
- Pull Request: [PR #176](https://github.com/Team-Origen/origen/pull/176).

## Checklist

- [x] ODD-80-01 — Crear `OrigenWeb.ProfessionalAgendaLive` con `on_mount: [{OrigenWeb.InternalAuthLive, :ensure_professional}]`.
- [x] ODD-80-02 — Montar ruta `/profesional/agenda` en `lib/origen_web/router.ex` protegida con pipeline de sesión interna y rol profesional.
- [x] ODD-80-03 — Implementar renderizado cronológico de turnos del día invocando el backend de #79.
- [x] ODD-80-04 — Implementar estado vacío ("No hay turnos programados para este día") y estado de error/indisponibilidad ante fallos de backend.
- [x] ODD-80-05 — Implementar navegación de fechas (selector de fecha y botones día previo / siguiente) y compatibilidad con teclado y pantallas angostas (responsive UI).
- [x] ODD-80-06 — Pruebas de integración LiveView cubriendo autenticación, renderizado, navegación, estado vacío y manejo de errores.

## Acceptance criteria

- [x] Muestra cronológicamente los turnos del día del Profesional autenticado.
- [x] Incluye estados de carga, agenda vacía y error.
- [x] Puede comenzar con fixtures, pero debe integrar #79 antes de Done.
- [x] Funciona con teclado y en pantallas angostas.

## Applicable checks

- `mix test test/origen_web/live/professional_agenda_live_test.exs` (10 passed)
- `mix compile --warnings-as-errors` (limpio)
- `mix format --check-formatted` (limpio)

## Progress and evidence

- Commit: `3f3ea4b` (`Closes #80`).
- Pull Request: [PR #176](https://github.com/Team-Origen/origen/pull/176).
- LiveView `OrigenWeb.ProfessionalAgendaLive` implementado en `lib/origen_web/live/professional_agenda_live.ex` integrando `Origen.Booking.get_professional_agenda/2`.
- Ruta `/profesional/agenda` montada en `lib/origen_web/router.ex` con pipeline `:require_internal_session`, `:require_professional` y `live_session` con `InternalAuthLive.on_mount(:ensure_professional)`.
- Renderizado de turnos cronológicos con horarios formateados, etiquetas legibles de estado, tipos de consulta con duración y datos no clínicos de paciente (nombre, teléfono, documento).
- Estados de UI: estado vacío accesible (`#agenda-empty-state`), estado de error (`#agenda-error-state`) con reintento, y navegación accesible por teclado (botones con `aria-label`, foco visible `focus:ring-2`, selector de fechas).
- Suite `test/origen_web/live/professional_agenda_live_test.exs` con 10 pruebas cubriendo control de acceso por roles, renderizado de turnos, estado vacío, errores y navegación de fechas.
