# Issue 70: Integrar el recorrido principal del prototipo

## Outcome

Demostrar e integrar de punta a punta el recorrido principal del prototipo (PLN-14 / Issue #70): Profesional configura consulta y disponibilidad -> Paciente accede y valida identidad/teléfono -> Paciente reserva autónomamente -> Profesional visualiza el turno en su agenda diaria, operando exclusivamente con datos ficticios reproducibles y preservando todas las barreras de autorización, privacidad y transaccionalidad.

## Problem

Hasta el momento, los módulos del sistema (configuración del profesional #74/#77, acceso y validación del paciente #86/#90, motor transaccional de reserva #66/#93 y consulta de agenda diaria #79/#80) se desarrollaron y probaron en sus frentes individuales. Se necesita integrar el flujo completo de forma reproducible, verificando que la interacción entre todas las piezas funcione armoniosamente sin relajar ninguna regla de seguridad ni aislamiento.

## Why

Es el hito central de validación del Sprint 1 (Demo integrada) que prueba la viabilidad arquitectónica de Origen ante el equipo y los evaluadores docentes, certificando que un paciente real puede reservar un turno disponible configurado por un profesional y que este lo ve reflejado inmediatamente en su agenda operativa.

## Authorized scope

- Suite de integración E2E automatizada: `test/origen/integration/prototype_journey_test.exs`.
- Script ejecutable de demostración y comprobación local reproducible: `priv/repo/check_prototype_journey_e2e.exs`.
- Documento de seguimiento ODD: `odd/tasks/issue-70-integrate-prototype-journey.md`.
- Rama local: `feature/70-integrate-prototype-journey`.
- Pull Request: enlazado a la subissue mediante `Closes #70`.

## Checklist

- [x] ODD-70-01 — Crear rama de trabajo `feature/70-integrate-prototype-journey` y verificar baseline limpio.
- [x] ODD-70-02 — Construir suite de integración E2E automatizada (`test/origen/integration/prototype_journey_test.exs`) conectando Profesional configura -> Paciente accede y valida -> Paciente reserva -> Profesional visualiza en agenda.
- [x] ODD-70-03 — Construir script ejecutable reproducible (`priv/repo/check_prototype_journey_e2e.exs`) para demostración interactiva local con fixtures sanitizados.
- [x] ODD-70-04 — Validar que todas las capas preservan autorización estricta, privacidad de agenda, validación telefónica y atomicidad transaccional sin bypasseos.
- [x] ODD-70-05 — Ejecutar suite completa, formateo, verificación de advertencias y documentar evidencia en el artefacto ODD.
- [x] ODD-70-06 — Preparar commit de unidad de trabajo y Pull Request enlazado a la subissue (`Closes #70`).

## Acceptance criteria

- [x] Conecta configuración del Profesional, acceso del Paciente, reserva y agenda en un entorno local.
- [x] Usa exclusivamente datos ficticios y configuración reproducible.
- [x] Demuestra el recorrido Profesional configura → Paciente reserva → Profesional visualiza.
- [x] La integración no desactiva autorización, privacidad, teléfono ni transacciones.

## Applicable checks

- `mix test test/origen/integration/prototype_journey_test.exs` (5 passed)
- `mix run priv/repo/check_prototype_journey_e2e.exs` (ejecución exitosa, 0 warnings)
- `mix test` (611 passed, 0 failures)
- `mix compile --warnings-as-errors` (limpio)
- `mix format --check-formatted` (limpio)

## Progress and evidence

- Rama `feature/70-integrate-prototype-journey` creada desde `develop`.
- Suite automatizada de integración de punta a punta creada en `test/origen/integration/prototype_journey_test.exs` con 5 pruebas exhaustivas:
  1. Recorrido principal completo: Profesional configura tipo de consulta y disponibilidad semanal -> Paciente solicita y consume Magic Link -> Paciente completa identidad (Persona DNI) -> Paciente valida desafío telefónico -> Paciente reserva slot disponible mediante `BookingService.reserve/2` -> Profesional consulta su agenda propia (`Agenda.get_professional_agenda/2`) y visualiza interactivamente el turno en LiveView (`ProfessionalAgendaLive`).
  2. Aislamiento horizontal: Se comprueba que otro Profesional B con sesión propia no visualiza los turnos del Profesional A en su agenda (estado vacío renderizado).
  3. Control mandatorio de teléfono: Paciente con perfil completado pero sin teléfono verificado es rechazado con `:patient_not_ready_for_booking`, sin persistir turnos.
  4. Prevención de solapamiento: Solicitud concurrente sobre el mismo horario y profesional es rechazada con `:slot_already_booked`.
  5. Protección de endpoints y vistas: Accesos anónimos, de secretaría o de administrador a `/profesional/agenda` son rechazados con 401 y 403.
- Script ejecutable creado en `priv/repo/check_prototype_journey_e2e.exs`:
  - Ejecutable vía `mix run priv/repo/check_prototype_journey_e2e.exs`.
  - Configura fixtures reproducibles y sanitizados.
  - Imprime en terminal cada fase con IDs generados, horarios, snapshots y corroboraciones forenses en PostgreSQL.
- Auditoría append-only y snapshots inmutables verificados:
  - Tipo de consulta registrado y resuelto automáticamente de la base de datos sin snapshots precalculados simulados.
  - Eventos de auditoría registrados: `availability_configuration_replaced`, `magic_link_issued`, `magic_link_consumed`, `patient_profile_completed`, `phone_challenge_issued`, `phone_challenge_consumed`.
  - Relación profesional-paciente creada en `professional_patient_relationships`.
