# Task: Issue #67 — Implementar búsqueda y reutilización documental de Personas por Secretaría

## OpenSpec Traceability

- Change: `pln-12-assisted-booking`
- Path: `odd/tasks/issue-67-secretary-person-search.md`
- Scope: Implementation of Issue #67 (PLN-12 Slice 1 of 3)
- Tracking Issue: https://github.com/Team-Origen/origen/issues/67
- Subissue parent: #45 (PLN-12)
- Commit: `f1cada1`

## Description

Implementar la búsqueda y reutilización documental de Personas por Secretaría según RF-01, RF-02 y BOOK-02.
Permite a una Secretaría autenticada buscar personas por tipo controlado y número normalizado de documento,
reutilizar identidades existentes sin duplicarlas ni sobrescribir datos indebidamente, asociar o crear
un perfil de Paciente (incluso pendiente de completar para la vía asistida) y auditar cada búsqueda,
alta y reutilización.

## Acceptance Criteria

- [x] Permite buscar o registrar Personas con tipo controlado y número normalizado de documento.
- [x] Reutiliza una identidad existente sin duplicarla ni sobrescribir datos indebidamente.
- [x] Permite asociar un perfil de Paciente pendiente de completar para la vía asistida.
- [x] Audita búsquedas, altas y reutilizaciones con la Secretaría autenticada como actora.
- [x] Interfaz LiveView accesible bajo rol `:secretary` (y `:administrator`) con feedback claro y validación en tiempo real.
- [x] Suite de pruebas unitarias y de LiveView verificando casos de éxito, no duplicación, autorización y auditoría.

## Planned Steps

1. [x] Crear rama `feature/67-secretary-person-search` y documento de tracking ODD.
2. [x] Extender `Origen.Patients` con `search_persona_by_document/3` y `register_or_reuse_assisted_persona/2` con auditoría sanitizada.
3. [x] Implementar `OrigenWeb.SecretaryPatientLive` en `lib/origen_web/live/secretary_patient_live.ex` y registrar ruta protegida en `router.ex`.
4. [x] Crear pruebas de contexto en `test/origen/patients/secretary_search_test.exs`.
5. [x] Crear pruebas de LiveView en `test/origen_web/live/secretary_patient_live_test.exs`.
6. [x] Validar con `mix test` y `mix format`.

## Implementation Notes

- Audit actor reference uses the plain account id (`actor_kind: "secretary"`, `actor_ref: "<account_id>"`)
  because `Origen.Audit.Events` sanitization rejects any reference containing `secret` — the literal
  `"secretary:#{id}"` prefix is always rejected by `valid_reference?/1`. `actor_kind` already carries the role,
  matching the existing professional precedent (`{:professional, "42"}`).
- Entity reference for `persona_searched`/`persona_created`/`persona_reused` is the normalized document
  (`"dni:35987654"`) because a persona id does not exist for missed searches.
- `register_or_reuse_assisted_persona/2` runs inside a transaction with `FOR UPDATE` locking on the
  existing persona; unique-constraint races surface as `{:error, changeset}`.
- `SecretaryPatientLive` authenticates via `OrigenWeb.InternalAuthLive.on_mount(:ensure_authenticated)`
  and authorizes `:secretary`/`:administrator` in `mount/3`, redirecting to `/` otherwise.
- "Iniciar Reserva Asistida" is a stable hook point that currently renders an informational notice;
  the actual flow lands with #68.

## Validation Evidence

- `mix test test/origen/patients/secretary_search_test.exs` — 13 passed.
- `mix test test/origen_web/live/secretary_patient_live_test.exs` — 10 passed.
- `mix test` — 555/556 passed, 29 skipped, 8 excluded. The single failure is a pre-existing,
  time-of-day-dependent flake in `OrigenWeb.PatientBookingCalendarLiveTest` ("renders view, slots…"): the
  mock calendar's demo windows for today (09:00–12:00, 14:00–17:00 UTC) are fully consumed by the 30-minute
  lead time once the UTC afternoon advances (verified: `MockCalendar.get_daily_schedule("PRO-DEMO-001", Date.utc_today())`
  returns 0 slots at ~16:13 UTC, independent of this change's files).
- `mix format --check-formatted` — clean.
