# #375 — Integración y verificación: ciclo de cuentas internas (#279)

## Alcance y prerrequisitos

Integra y verifica el alcance completo de la issue padre [#279](https://github.com/Team-Origen/origen/issues/279) utilizando el [contrato aprobado #372](../contracts/372-ciclo-cuentas-internas.md), el backend de [#373](https://github.com/Team-Origen/origen/issues/373) y la interfaz de [#374](https://github.com/Team-Origen/origen/issues/374) conectados con las implementaciones reales de base de datos PostgreSQL, sesiones internas, auditoría y los tres canales de reserva de la beta.

- **OpenSpec change:** `health-center-beta-core`
- **Ruta:** `openspec/changes/health-center-beta-core/`
- **Alcance:** Sprint 4 / parent #279 / integration (#375)
- **Blockers nativos resueltos:** `#372` (Contrato), `#373` (Backend) y `#374` (Interfaz) (todos cerrados y aprobados en GitHub).
- **Referencia inversa:** `openspec/changes/health-center-beta-core/proposal.md` declara el desglose completo de la issue padre #279.

## Recorrido integrado real y navegación desde la navbar

1. **Acceso desde la barra de navegación del Administrador:**
   - La barra de navegación de Administrador (`#role-navigation[data-role="administrator"]`) expone el acceso `#nav-accounts[href="/administrador/cuentas"]` marcado con `aria-current="page"`.
   - No expone destinos operativos reservados a otros roles (`#nav-agenda`, `#nav-patients`, `#nav-summary`, `#nav-settings`).
   - Las sesiones con roles `secretary`, `professional`, `patient` o anónimas/sin autenticar son denegadas y redirigidas a `/` inmediatamente al intentar ingresar a `/administrador/cuentas`.

2. **Matriz de operaciones verificadas con implementaciones reales (sin dobles):**
   - **Alta con invitación y reemisión (C1):**
     - Administrador emite invitaciones para `professional` y `secretary`.
     - Inserción en `internal_accounts` en estado `pending_activation`, creación de token unívoco en `internal_account_invitations` y registro de auditoría append-only.
     - La acción de reemitir invitación (`#reissue-invitation-<id>`) emite un nuevo token revocando los anteriores no consumidos.
   - **Edición de correo con unicidad (C2, C3):**
     - Actualización inline del correo electrónico desde el formulario de la fila.
     - Validación de formato y unicidad case-insensitive contra `internal_accounts_lower_email_idx`.
     - Preservación estricta del `id` de la cuenta, sus relaciones profesionales-pacientes, perfil profesional, configuraciones de agenda y turnos existentes.
     - Rechazo de correos duplicados (`:email_taken`) e inválidos (`:invalid_email`) sin efectos colaterales.
   - **Desactivación urgente y corte inmediato de acceso (C4, C5, C6):**
     - Transición atómica de la cuenta a `deactivated`.
     - Revocación inmediata de todas las sesiones activas en `internal_account_sessions` (`Sessions.terminate_all_sessions/2`). Las peticiones subsiguientes fallan cerrado con `401 Unauthorized` / redirección.
     - Corte inmediato de nuevas reservas en los tres canales:
       - **Paciente autónomo:** el profesional desaparece de `DatabaseCalendar.list_professionals/0`, las consultas de slots fallan cerrado y `BookingService.reserve/2` rechaza la reserva con `:professional_not_eligible`.
       - **Secretaría asistida:** el profesional desaparece de `AssistedBooking.list_professionals/0` y `AssistedBooking.reserve/4` rechaza con `{:error, :invalid_professional}`.
       - **Profesional propio:** `Booking.reserve_professional_appointment/3` rechaza con `{:error, :unauthorized}` o `:invalid_professional_account`.
     - **Preservación estricta de historia y turnos existentes:** ningún turno se cancela automáticamente. Los turnos pasados `attended`, futuros `confirmed`, solicitudes `requested` y cancelaciones previas permanecen en sus estados originales.
     - **Conteo de turnos futuros afectados (`future_affected_appointments_count`):** cálculo exacto para seguimiento por Secretaría (`start_time > now` en estados `confirmed`, `requested`, `reserved`), expuesto en el aviso de feedback y en el badge de la fila.
     - **Privacidad estricta:** el Administrador únicamente visualiza la cantidad numérica de turnos afectados; no se le exponen nombres, documentos ni agendas clínicas de los pacientes.
   - **Seguimiento operativo por Secretaría (C7):**
     - Mientras el Profesional está desactivado, Secretaría puede cancelar turnos futuros con motivo justificado por su flujo operativo (`Booking.cancel_appointment/3`).
     - El turno pasa a `cancelled` liberando el horario, mientras los demás turnos y solicitudes permanecen preservados.
   - **Reactivación sin restauración de turnos cancelados (C8):**
     - Transición de la cuenta de vuelta a `active`.
     - El Profesional recupera el acceso y vuelve a ser elegible para nuevas reservas en todos los canales.
     - **Los turnos cancelados (`cancelled`) durante o antes de la desactivación permanecen cancelados.** No se restaura ningún turno cancelado.
     - Los turnos `confirmed` y solicitudes `requested` continúan en sus estados vigentes.
   - **Aislamiento de roles y default-deny (C9, C10, C11):**
     - El Administrador no puede desactivar ni editar a otro Administrador ni auto-desactivarse.
     - No tiene autoridad sobre pacientes, agendas, turnos, pagos ni ajustes profesionales.
     - Roles no administradores reciben `{:error, :unauthorized}` al intentar invocar las operaciones de ciclo de cuentas en dominio.

## Ajustes de integración realizados en #375

Siguiendo la guía de trabajo beta (corregir brechas detectadas al conectar las partes reales sin reabrir `#373` ni `#374`):

- `lib/origen_web/live/admin_internal_live.ex`:
  - Se agregó `Code.ensure_loaded?(context)` en `accounts_context/0` para garantizar que el módulo de contexto esté cargado en la máquina virtual antes de evaluar `function_exported?/3`.
  - En `load_accounts/1`, `invoke_update_account/3`, `invoke_deactivate_account/2` y `invoke_reactivate_account/2`, se ampliaron las cláusulas para contemplar tanto las aridades sin opciones como las aridades con lista de opciones por defecto (`/2`, `/3`, `/4`), incorporando un fallback directo a `Origen.Accounts` para evitar listas vacías o errores de indisponibilidad ante variaciones en la resolución de aridad.

## Verificación ejecutada

Se construyó la suite de integración dedicada `test/origen_web/live/internal_accounts_integration_test.exs` que cubre los 8 escenarios reales de extremo a extremo sin dobles de prueba:

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test mix test \
  test/origen_web/live/internal_accounts_integration_test.exs \
  test/origen/accounts_test.exs \
  test/origen/accounts/admin_permissions_verification_test.exs \
  test/origen/accounts/internal_account_lifecycle_test.exs \
  test/origen_web/live/admin_internal_live_test.exs \
  test/origen_web/live/role_navigation_live_test.exs
```

- **Resultado observado:** Código de salida **0**, **114 pruebas aprobadas, 0 fallos** en 3.2 segundos.
- Se verificó determinismo ejecutando la suite de integración bajo múltiples semillas (`seed: 0`, `seed: 12345`, `seed: 99999`, `seed: 54321`) con 8/8 pruebas aprobadas en cada corrida.
- Formato verificado: `mix format --check-formatted` (limpio).

## Aprobación explícita de integración (#375) y cierre de #279

Habiéndose verificado todos los criterios de aceptación de [#279](https://github.com/Team-Origen/origen/issues/279) y [#375](https://github.com/Team-Origen/origen/issues/375) con la base de datos real, sesiones activas, auditoría y los canales de reserva sin dobles, Lucca Giordana (`ChordanDev`, responsable de `#279` y sus subissues `#372`–`#375`) registra la **aprobación explícita** de [#375](https://github.com/Team-Origen/origen/issues/375), habilitando el cierre formal de la issue padre [#279](https://github.com/Team-Origen/origen/issues/279).
