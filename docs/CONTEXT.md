# Glosario de dominio

## Solicitudes y turnos

| Término | Definición |
|---|---|
| Solicitado | Estado inicial de un turno solicitado por el paciente cuando el perfil profesional usa aprobación manual. Espera aprobación profesional. |
| Reservado | Estado de un turno aprobado o creado con reserva pendiente de confirmación cuando corresponde. Representa una reserva activa. |
| Confirmado | Estado de un turno cuya asistencia ya quedó confirmada, ya sea por el paciente o porque el flujo aplicable lo estableció directamente. |
| Asistió | Estado de un turno que ya se realizó y fue atendido. |
| Cancelado | Estado de un turno que fue anulado y deja de mantenerse como reserva activa. |
| No asistió | Estado de un turno que no fue atendido por ausencia del paciente. |
| Sobreturno | Tipo o modalidad de turno, no un estado del ciclo de vida. Puede atravesar estados compatibles con el flujo del turno. |

## Cuentas de pacientes

| Término | Definición |
|---|---|
| Pendiente de completar | Estado de una cuenta de Paciente creada por Google OAuth que todavía no completó y validó todos los datos obligatorios del registro. |
| Activa | Estado de una cuenta de Paciente que ya completó y validó los datos obligatorios y puede operar normalmente dentro del sistema. |

## Cuentas internas

| Término | Definición |
|---|---|
| Pendiente de activación | Estado de una cuenta de Administrador, Profesional o Secretaría que todavía no completó la definición de contraseña y el enrolamiento TOTP mediante su invitación de un solo uso. |
| Activa | Estado de una cuenta de Administrador, Profesional o Secretaría que ya completó la definición de contraseña y el enrolamiento TOTP y puede iniciar sesión. |

## Cierre administrativo y pago

| Término | Definición |
|---|---|
| Abierto | Estado administrativo que indica que el turno mantiene alguna pendiente operativa o financiera. |
| Cerrado | Estado administrativo que indica que el turno alcanzó un resultado operativo terminal y no mantiene pendientes. |
| Pendiente | Estado financiero usado para indicar que el pago aún no fue registrado. |
| En revisión | Estado financiero usado para indicar que un comprobante fue cargado y espera validación. |
| Pagado | Estado financiero usado para indicar que el pago fue registrado. |
| Rechazado | Estado financiero usado para indicar que el comprobante no fue aceptado. |
| No corresponde | Estado financiero usado cuando la consulta no tiene obligación de pago. |
