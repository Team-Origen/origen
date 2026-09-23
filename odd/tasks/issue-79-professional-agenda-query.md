# Issue 79: Implementar consulta de turnos propios del Profesional

## Outcome

Implementar la consulta backend de turnos propios de la agenda de un Profesional autenticado (PLN-10 / Issue #79), derivando su identidad exclusivamente de la sesión activa en el servidor, con proyección sanitizada de turnos (horario, paciente no clínico, tipo y estado) e imposibilidad de ampliar el alcance mediante parámetros del cliente.

## Problem

Actualmente los turnos se persisten y reservan transaccionalmente (PLN-08), pero el Profesional autenticado no cuenta con una función de backend para consultar su agenda diaria de turnos propios con validación de identidad y protección contra acceso a agendas de colegas.

## Why

Garantizar la privacidad estricta de las agendas profesionales, impidiendo la exposición cruzada de turnos entre profesionales o la filtración de datos clínicos innecesarios en la vista operativa de agenda.

## Authorized scope

- Seam de consulta en `lib/origen/booking.ex` (o sub-módulo bajo `lib/origen/booking/agenda.ex`).
- Autorización formal en `lib/origen/authorization/rules.ex` para operación `:read_own_agenda`.
- Integración con `Origen.Sessions.revalidate_principal/2` para derivar identidad del profesional desde sesión activa.
- Suite de pruebas unitarias y de integración en `test/origen/booking/professional_agenda_test.exs`.
- Local branch: `feature/79-professional-agenda-query`.
- Pull Request: [PR #175](https://github.com/Team-Origen/origen/pull/175).

## Checklist

- [x] ODD-79-01 — Registrar regla de autorización `:read_own_agenda` para rol `:professional` en `Origen.Authorization.Rules`.
- [x] ODD-79-02 — Implementar `Origen.Booking.get_professional_agenda/2` que resuelve al profesional exclusivamente mediante sesión/cuenta autenticada, rechazando parámetros arbitrarios que pretendan modificar el `professional_account_id`.
- [x] ODD-79-03 — Modelar la consulta Ecto sobre `appointments` con join a `patient_profiles` y `personas`, proyectando únicamente horario (`start_time`, `end_time`), datos de Paciente no clínicos (nombre, apellido, contacto básico), tipo de consulta (`snapshot_consultation_type_name`, duración) y estado (`status`).
- [x] ODD-79-04 — Implementar filtrado por fecha (`date`) y ordenamiento cronológico ascendente (`start_time ASC`).
- [x] ODD-79-05 — Crear suite de pruebas exhaustiva para verificar casos de éxito, aislamiento entre profesionales y rechazo a sesiones inválidas o parámetros maliciosos.

## Acceptance criteria

- [x] Deriva el Profesional exclusivamente desde la sesión autenticada.
- [x] Devuelve únicamente sus turnos con horario, Paciente, tipo y estado necesarios.
- [x] No acepta identificadores del cliente para ampliar el alcance de la consulta.
- [x] No expone información clínica ni agendas ajenas.

## Applicable checks

- `mix test test/origen/booking/professional_agenda_test.exs`
- `mix compile --warnings-as-errors`
- `mix format --check-formatted`

## Progress and evidence

- Commit: `cf23c0d` (`Closes #79`).
- Pull Request: [PR #175](https://github.com/Team-Origen/origen/pull/175).
- Regla `{:own_02, :read_own_agenda, {:role, :professional}, :active, %{owner_matches_actor: true}, %{authenticated: true}}` agregada en `lib/origen/authorization/rules.ex`.
- `Origen.Booking.Agenda.get_professional_agenda/2` implementado en `lib/origen/booking/agenda.ex` (revalidación `Origen.Sessions.revalidate_principal/2` + `Origen.Authorization.decide/1`, filtro `[day_start, day_end)` UTC, `start_time ASC`, join `patient_profiles` con left join `personas`, proyección no clínica con `name` resuelto como nombre completo o email) y expuesto vía delegación desde `Origen.Booking.get_professional_agenda/2`.
- Suite `test/origen/booking/professional_agenda_test.exs`: 15 pruebas cubriendo orden cronológico, aislamiento entre profesionales, inyección de identidad ignorada, fail closed (sesión revocada/expirada/alterada, cuenta inactiva, roles `administrator`/`secretary`, principals malformados), fecha vacía/malformada y ausencia de campos clínicos.
- Checks ejecutados: `mix test test/origen/booking/professional_agenda_test.exs` (15 passed), `mix test test/origen/authorization_test.exs` (9 passed, sin regresión), `mix compile --warnings-as-errors` (limpio), `mix format --check-formatted` (limpio). Sin commit, según instrucción.
