# Casos de reserva — ejemplos válidos y rechazados

Subissue [#61 "Escribir casos de reserva"](https://github.com/Team-Origen/origen/issues/61),
de [#41 "Operación única y transaccional de reserva" (PLN-08)](https://github.com/Team-Origen/origen/issues/41).

## Alcance de este documento

Enumera los escenarios de ejemplo que la futura operación compartida de reserva deberá
soportar, con su resultado esperado y la regla funcional que lo respalda. No implementa
el motor de reserva: eso corresponde a las subissues [#62](https://github.com/Team-Origen/origen/issues/62)
(datos), [#63](https://github.com/Team-Origen/origen/issues/63) (guardar el turno),
[#64](https://github.com/Team-Origen/origen/issues/64) (permisos),
[#65](https://github.com/Team-Origen/origen/issues/65) (superposiciones) y
[#66](https://github.com/Team-Origen/origen/issues/66) (transacción todo-o-nada).

**Bloqueo real:** #41 depende de PLN-05 (#38), PLN-06 (#39), PLN-07 (#40) y PLN-15 (#48).
Ninguna está mergeada a `develop` todavía, por lo que estos casos son especificación,
no verificación contra un motor real. El archivo hermano
`test/origen/booking/reservation_cases_test.exs` los deja como esqueletos `skip` para
completar cuando el motor exista.

Referencias funcionales: `docs/Origen_Documentacion.md` — RF-02, RF-05, RF-10, RF-14, RF-16.

## Convenciones

- **Actor**: quién dispara la operación (Paciente, Secretaría, Profesional).
- **Momento**: antes de D-1 o durante D-1 (afecta el estado inicial, RF-10).
- **Resultado**: estado final del turno y efectos secundarios (relación, auditoría).

## Casos válidos (aceptados)

| ID | Actor | Momento | Precondiciones | Resultado esperado | Referencia |
|----|-------|---------|-----------------|---------------------|------------|
| V1 | Paciente (autogestión, primera reserva) | Antes de D-1 | Perfil propio completo; teléfono verificado; Profesional en modalidad automática | Turno nace `Reservado`; la propia transacción crea la relación Profesional–Paciente y la auditoría | RF-05, RF-10 |
| V2 | Paciente (autogestión, primera reserva) | Antes de D-1 | Igual a V1, pero Profesional en modalidad manual | Turno nace `Solicitado`; **no** crea relación ni visibilidad todavía | RF-10, RF-14 |
| V3 | Paciente (autogestión) | Durante D-1 | Perfil completo, teléfono verificado | Turno nace `Confirmado` directo, sin pasar por `Solicitado`/`Reservado`; no dispara WhatsApp | RF-10, RF-17 |
| V4 | Secretaría (asistida, primera reserva) | Antes de D-1 | Paciente con perfil incompleto según RF-02; Secretaría elige `Reservado` | Turno nace `Reservado`; crea relación al persistir con éxito, aunque el perfil siga incompleto | RF-02, RF-05 |
| V5 | Secretaría (asistida) | Antes de D-1 | Horario ya acordado con el Paciente; Secretaría elige `Confirmado` explícitamente | Turno nace `Confirmado`; se registra declaración simple de aceptación del horario | RF-10 |
| V6 | Secretaría (asistida) | Durante D-1 | — | Solo puede crear `Confirmado` (no hay opción `Reservado` durante D-1) | RF-10 |
| V7 | Profesional (turno posterior) | Antes de D-1 | Paciente ya en la lista permitida por una primera reserva válida previa | Turno nace `Reservado`; continúa flujo de confirmación por WhatsApp | RF-05, RF-10, RF-17 |
| V8 | Profesional (turno posterior) | Durante D-1 | Paciente ya en la lista permitida | Turno nace `Confirmado` directo; no usa confirmación por WhatsApp | RF-10, RF-17 |
| V9 | Cualquiera (aprobación manual) | — | Solicitud existente en `Solicitado`; Profesional aprueba | Pasa a `Reservado`/`Confirmado` según fecha; si era la primera solicitud del Paciente, recién en este momento se crea la relación Profesional–Paciente, atómicamente con turno + copias históricas + auditoría | RF-05, RF-14 |

## Casos rechazados

| ID | Actor | Situación | Resultado esperado | Referencia |
|----|-------|-----------|---------------------|------------|
| R1 | Paciente (autogestión) | Perfil propio incompleto | Rechazado; no crea relación ni turno; error indica perfil incompleto | RF-05 |
| R2 | Paciente (autogestión) | Teléfono del destinatario primario no verificado | Rechazado; no crea relación | RF-05 |
| R3 | Dos solicitudes concurrentes | Mismo horario/Profesional, pedidos simultáneos | Solo una persiste; la otra se rechaza por conflicto de agenda, sin turno duplicado | #41 (criterio de superposición), RF-14 |
| R4 | Profesional | Intenta crear turno para un Paciente fuera de su lista permitida (sin relación previa) | Denegado en backend y auditado; no expone ni crea nada | RF-05 |
| R5 | Profesional | Intenta listar o buscar el registro global de Pacientes | Denegado en backend y auditado | RF-05 |
| R6 | Cualquiera | Tipo de consulta inactivo, o perteneciente a otro Profesional | Rechazado; el tipo debe pertenecer al Profesional y estar activo | PLN-06 (#39) |
| R7 | Cualquiera | Horario sin intervalos de agenda contiguos suficientes para la duración vigente | Rechazado por falta de disponibilidad | PLN-07 (#40) |
| R8 | Profesional (rechazo manual) | Solicitud en `Solicitado` es rechazada | Pasa a `Cancelado` con motivo obligatorio, actor y fecha auditados; sin multa; si era la primera solicitud, no deja relación ni turno válido | Sección 8 (decisiones resueltas), RF-14 |
| R9 | Paciente (autogestión pública) | Intenta reservar después de las 23:59 del día D-1, fuera de las excepciones controladas (lista de espera manual, asignación directa interna) | Rechazado; el corte de reserva pública/autónoma ya cerró | RF-10 |

## Qué queda fuera de este documento

- La implementación del motor de reserva y sus validaciones (#62–#66).
- Los flujos de WhatsApp (RF-16, RF-17) y de multas (RF-16 bis): se referencian como
  contexto de por qué un turno nace en un estado u otro, pero su lógica no es parte de #41.
- La interfaz completa de aprobación manual (explícitamente fuera de alcance de #41).
