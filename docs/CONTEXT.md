# Glosario de dominio

## Solicitudes y turnos

| Término | Definición |
| --- | --- |
| Solicitado | Estado inicial de un turno solicitado por el paciente cuando el perfil profesional usa aprobación manual. Espera aprobación profesional. |
| Reservado | Estado de un turno aprobado o creado con reserva pendiente de confirmación cuando corresponde. Representa una reserva activa. |
| Confirmado | Estado de un turno cuya asistencia ya quedó confirmada, ya sea por el paciente o porque el flujo aplicable lo estableció directamente. |
| Asistió | Estado de un turno que ya se realizó y fue atendido. |
| Cancelado | Estado de un turno que fue anulado y deja de mantenerse como reserva activa. |
| No asistió | Estado de un turno que no fue atendido por ausencia del paciente. |
| Sobreturno | Tipo o modalidad de turno, no un estado del ciclo de vida. Puede atravesar estados compatibles con el flujo del turno. |

## Catálogo y agenda

| Término | Definición |
| --- | --- |
| Tipo de consulta | Prestación perteneciente a un único Profesional, con identidad propia y una duración vigente derivada de su cantidad de Intervalos de agenda. |
| Intervalo de agenda | Granularidad temporal propia de la agenda de un Profesional, expresada en minutos. No es la duración histórica de un turno ni el Período de reserva. |
| Período | Ventana de anticipación futura durante la cual pueden reservarse turnos. No representa la granularidad de la agenda. |

## Cuentas de pacientes

| Término | Definición |
| --- | --- |
| Pendiente de completar | Estado de una cuenta de Paciente creada por Google OAuth que todavía no completó y validó todos los datos obligatorios del registro. |
| Activa | Estado de una cuenta de Paciente que ya completó y validó los datos obligatorios y puede operar normalmente dentro del sistema. |

## Cuentas internas

| Término | Definición |
| --- | --- |
| Pendiente de activación | Estado de una cuenta de Administrador, Profesional o Secretaría que todavía no completó la definición de contraseña y el enrolamiento TOTP mediante su invitación de un solo uso. |
| Activa | Estado de una cuenta de Administrador, Profesional o Secretaría que ya completó la definición de contraseña y el enrolamiento TOTP y puede iniciar sesión. |

### First Administrator bootstrap boundaries

The first Administrator bootstrap is a deployment-only, non-production capability. It is disabled by default, denied in `MIX_ENV=prod`, and creates a `Pendiente de activación` account rather than credentials. Activation is invitation-bound, TLS-only, consume-once, and changes the account to `Activa` only after password and TOTP enrollment succeeds.

Operational ownership is split deliberately:

- The application enforces the gate, invitation lifetime and consumption, credential persistence, default-deny authorization, and typed sanitized audit events.
- Deployment owns accurate environment classification, TLS, ingress/APM/error-reporting redaction, secret-provider wiring, and removal of the exposed surface after use.
- Rollback disables the task and route while preserving account, invitation, and audit history. Destructive rollback requires explicit approval.
- Approved invocation boundaries are the source-checkout Mix task and packaged `bin/origen_bootstrap_admin`; both use the shared fail-closed gate before bootstrap argument parsing or I/O, and production-compiled releases deny execution.
- Delivery approval is a separate authority: Samuel/requester cannot self-approve. A distinct authorized confirmer must approve the exact destination, non-production environment, and operation through protected approval input for every fresh issue/reissue; this authority never derives from an application role.
- Issuance plus required audit and failure revocation plus required audit are bounded database transactions. Provider handoff occurs outside those transactions and returns reference-only evidence; failed delivery requires revocation, a fresh approval, and a fresh invitation rather than retry.
- Staging acceptance is **prepared/not executed**. No Samuel→Santiago email, credentials, deployment, activation, or operational bootstrap is included; Issue #3 remains open pending a separately authorized real-staging journey.
- Current callback replay storage is node-local/in-memory with no time-based pruning. Staging remains blocked pending ingress affinity or shared replay storage, a retention/pruning policy, provider controls and provider credentials, human approvals, and full-stack integration.

See [the bootstrap deployment runbook](deployment/FIRST_ADMIN_BOOTSTRAP.md) and [activation data handling controls](security/ACTIVATION_DATA_HANDLING.md).

## Cierre administrativo y pago

| Término | Definición |
| --- | --- |
| Abierto | Estado administrativo que indica que el turno mantiene alguna pendiente operativa o financiera. |
| Cerrado | Estado administrativo que indica que el turno alcanzó un resultado operativo terminal y no mantiene pendientes. |
| Pendiente | Estado financiero usado para indicar que el pago aún no fue registrado. |
| En revisión | Estado financiero usado para indicar que un comprobante fue cargado y espera validación. |
| Pagado | Estado financiero usado para indicar que el pago fue registrado. |
| Rechazado | Estado financiero usado para indicar que el comprobante no fue aceptado. |
| No corresponde | Estado financiero usado cuando la consulta no tiene obligación de pago. |
