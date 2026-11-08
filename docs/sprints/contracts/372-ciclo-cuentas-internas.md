# Contrato #372: Ciclo de cuentas internas (#279)

**Estado: Aprobado para implementación (#372), preparado por Lucca Giordana (`ChordanDev`).**
Este documento formaliza el contrato, las reglas de negocio, la matriz de permisos, el análisis de estado actual y los escenarios verificables para [#279](https://github.com/Team-Origen/origen/issues/279), preparando [#373 (Backend)](https://github.com/Team-Origen/origen/issues/373) y [#374 (Interfaz)](https://github.com/Team-Origen/origen/issues/374). **No implementa código de aplicación ni certifica la funcionalidad como terminada ni integrada** (lo cual corresponde a [#375 (Integración y verificación)](https://github.com/Team-Origen/origen/issues/375)).

---

## 1. Identificación, Alcance y Fuentes Normativas

- **OpenSpec Change:** `health-center-beta-core`
- **Ruta OpenSpec:** `openspec/changes/health-center-beta-core/`
- **Scope:** Sprint 4 / parent [#279](https://github.com/Team-Origen/origen/issues/279) / implementation slice 4 of 17 / contract ([#372](https://github.com/Team-Origen/origen/issues/372))
- **Mapa Wayfinder aprobado:** [#266](https://github.com/Team-Origen/origen/issues/266) y resolución histórica [#269](https://github.com/Team-Origen/origen/issues/269#issuecomment-6251966424)
- **Responsable:** `ChordanDev` (Lucca Giordana)
- **Base inspeccionada:** `origin/develop` (`ce13af7`)

| Fuente normativa | Secciones aplicables |
| --- | --- |
| [`openspec/changes/health-center-beta-core/proposal.md`](../../../openspec/changes/health-center-beta-core/proposal.md) | `Confirmed scope` (punto 4), `Product boundaries` (alcance exclusivo del Administrador), `Security and data impact` |
| [`openspec/changes/health-center-beta-core/design.md`](../../../openspec/changes/health-center-beta-core/design.md) | `Authorization boundary` (Administrador sólo ciclo de cuentas de Profesional y Secretaría; sin acceso operativo ni financiero implícito), `Future implementation obligations` |
| [`openspec/changes/health-center-beta-core/specs/staff-accounts-and-professional-settings/spec.md`](../../../openspec/changes/health-center-beta-core/specs/staff-accounts-and-professional-settings/spec.md) | `Requirement: Administrative account lifecycle` y escenario `Urgent professional deactivation` |
| [`openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md`](../../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) | `Complete beta scope is not priority-gated`, `Excluded capability set` |
| [`docs/sprints/GUIA_TRABAJO_BETA.md`](../GUIA_TRABAJO_BETA.md) | `Tipos de trabajo` (`work:contract`), `Qué revisar en Reglas y contrato`, `Regla de Integración y verificación` |

---

## 2. Reglas de Negocio y Contrato del Dominio

### 2.1 Alcance exclusivo del Administrador
1. El **Administrador activo** (`role: "administrator"`, `state: "active"`) puede **listar, crear, editar (incluido correo electrónico), reemitir invitación pendiente, desactivar y reactivar únicamente cuentas de `professional` y `secretary`**.
2. **Prohibición de jerarquía implícita:** El rol Administrador **no** otorga autoridad sobre pacientes, turnos, agendas, solicitudes pendientes, pagos, resúmenes económicos ni ajustes/perfiles profesionales (`professional_profiles`, `agenda_settings`, `consultation_types`).
3. **Frontera sobre cuentas de Administrador:** Desde este ciclo de cuentas internas de personal (`staff`), el Administrador **no** puede crear, editar, desactivar ni reactivar cuentas con rol `administrator` (ni auto-desactivarse). El bootstrap del primer administrador se mantiene en su canal exclusivo (`Origen.BootstrapAdmin`).
4. **Denegación a otros roles:** Ningún actor con rol `professional`, `secretary`, `patient` o sesión inválida/inactiva puede crear, listar, editar, desactivar o reactivar cuentas internas.

### 2.2 Ciclo de estados de la cuenta interna (`internal_accounts.state`)
- **`pending_activation`:** Cuenta creada con invitación emitida pendiente de activación (`password_hash IS NULL`, `totp_secret IS NULL`, `activated_at IS NULL`).
- **`active`:** Cuenta activada con credenciales enrolled (`password_hash IS NOT NULL`, `totp_secret IS NOT NULL`, `activated_at IS NOT NULL`) y habilitada para operar.
- **`deactivated`** (o estado inactivo equivalente en `internal_accounts_state_check`): Cuenta desactivada administrativamente.
  - Si la cuenta ya había sido activada, conserva sus credenciales e historial (`activated_at`, `password_hash`, `totp_secret`) para poder reactivarse sin pérdida de identidad ni re-enrolamiento forzoso, o si estaba en `pending_activation`, revoca cualquier invitación activa sin consumir.

### 2.3 Operaciones contractuales

#### A. Crear cuenta interna (`create_and_invite_internal_account`)
- **Entradas:** Actor Administrador activo (`actor_id` / sesión revalidada), `role` (`:professional` | `:secretary`), `email` (formato válido sin espacios, normalizado con `trim`, único case-insensitively en `lower(email)`).
- **Efecto:** Inserta cuenta en `pending_activation`, emite invitación verificable, registra auditoría `internal_invitation_issued` en la misma transacción.
- **Rechazos:** Rol distinto de `:professional` / `:secretary` (`{:error, :unauthorized}` o `{:error, :invalid_role}`), email vacío o malformado (`{:error, :invalid_request}` / changeset), email ya utilizado por otra cuenta interna (`{:error, :email_taken}` / `{:error, :invalid_request}`), actor no autorizado (`{:error, :unauthorized}`). Cero mutaciones ante rechazo.

#### B. Editar cuenta interna, incluido correo (`update_internal_account` / `update_staff_account_email`)
- **Entradas:** Actor Administrador activo, `target_account_id` perteneciente a una cuenta `professional` o `secretary`, y atributos de cuenta permitidos (correo electrónico `email`).
- **Alcance de edición:** Actualiza el correo electrónico (`email`) de la cuenta interna respetando formato válido y unicidad case-insensitive (`internal_accounts_lower_email_idx`).
- **Frontera con Ajustes Profesionales (#278):** Editar la cuenta desde Administración **no** abre ni modifica la configuración operativa del profesional (`agenda_settings`, `consultation_types`) ni exige que el Administrador gestione matrículas/especialidades del perfil privado del profesional.
- **Efecto sobre datos e historia:** Mantiene intacto el `id` de `internal_accounts`, conservando todas las relaciones (`professional_patient_relationships`), turnos (`appointments`), perfil (`professional_profiles`) y configuraciones asociadas. Registra evento de auditoría append-only sin exponer secretos.
- **Rechazos:** Target inexistente o con rol `administrator`, email duplicado, email inválido, o actor sin rol `administrator` activo.

#### C. Desactivar cuenta interna (`deactivate_internal_account`)
- **Entradas:** Actor Administrador activo, `target_account_id` (`professional` o `secretary` en estado `active` o `pending_activation`).
- **Efectos inmediatos y atómicos:**
  1. **Cambio de estado:** La cuenta pasa a estado desactivado (`deactivated`).
  2. **Corte inmediato de acceso del personal:**
     - Se revocan todas las sesiones activas de la cuenta en `internal_account_sessions` (`Sessions.terminate_all_sessions/2`).
     - Si tenía invitaciones pendientes en `internal_account_invitations`, se marcan con `revoked_at = clock_timestamp()`.
     - Cualquier request subsiguiente o intento de login (`authenticate_internal_account`, `Sessions.fetch_session`, `Sessions.touch_session`, `Sessions.revalidate_principal`) falla cerrado con `{:error, :unauthenticated}` porque exige `a.state = 'active'`.
  3. **Corte inmediato de nuevas reservas (cuando el target es Profesional):**
     - El profesional deja de aparecer inmediatamente en `DatabaseCalendar.list_professionals/0` y `AssistedBooking.list_professionals/0` (`a.state = 'active'`).
     - El motor de reservas rechaza inmediatamente cualquier intento de crear un turno nuevo para ese profesional en los tres canales: Paciente autónomo (`BookingService.reserve/2` -> `:professional_not_eligible`), Secretaría asistida (`AssistedBooking.reserve/4` -> `:invalid_professional`) y Profesional propio (`ProfessionalBooking.reserve/3` / `Booking.Authorization` -> `:unauthorized` / `:invalid_professional_account`).
     - La consulta de horarios reservables para nuevas reservas (`DatabaseCalendar.get_daily_schedule/3`, `DatabaseCatalog.execute/1` y `AssistedBooking.list_consultation_types/1`) debe verificar también `a.state = 'active'` para no ofrecer slots ni catálogo activo de un profesional desactivado a un cliente con caché o ID previo.
  4. **Preservación estricta de historia y turnos existentes (sin cancelación automática):**
     - **Ningún turno ni solicitud existente se cancela ni modifica automáticamente.**
     - Los turnos futuros confirmados (`confirmed`) y las solicitudes pendientes (`requested`) permanecen en sus estados actuales.
     - Las solicitudes `requested` pendientes pueden esperar una eventual reactivación antes de su hora de inicio (o vencerán por la regla general de expiración al llegar su hora sin confirmarse automáticamente), y Secretaría puede cancelar turnos con motivo por su propio flujo operativo (#285), pero **la desactivación administrativa jamás cancela turnos**.
     - Se conservan íntegros `appointments`, `professional_patient_relationships`, `professional_profiles`, `agenda_settings`, `consultation_types` y `audit_events`.
  5. **Conteo de turnos futuros afectados para seguimiento de Secretaría:**
     - La operación devuelve (y la vista de Administrador muestra) la **cantidad entera (`future_affected_appointments_count`)** de turnos futuros afectados del Profesional (`professional_account_id == target_id`, `start_time > now`, en estados activos de agenda: `requested`, `confirmed`, y `reserved` si existiera por compatibilidad). Para cuentas de Secretaría, el conteo es `0`.
     - **Privacidad y frontera de permisos:** Al Administrador **sólo** se le informa la cantidad numérica para advertir que Secretaría debe dar seguimiento; **no** se le exponen nombres de pacientes, DNI, horarios detallados ni acceso a las vistas de agenda o historia de turnos.
     - Adicionalmente, en el listado/detalle administrativo de cuentas profesionales desactivadas (o antes de confirmar la baja), el Administrador puede visualizar ese conteo de turnos futuros afectados sin abrir agendas ni datos de pacientes.
  6. **Auditoría:** Registra evento append-only de desactivación con actor `administrator` y referencia a la cuenta objetivo.

#### D. Reactivar cuenta interna (`reactivate_internal_account`)
- **Entradas:** Actor Administrador activo, `target_account_id` (`professional` o `secretary` en estado `deactivated`).
- **Efectos atómicos:**
  1. **Restablecimiento de estado:**
     - Si la cuenta tenía credenciales activadas (`password_hash IS NOT NULL` y `totp_secret IS NOT NULL`), vuelve a estado `active` (o si había sido desactivada desde `pending_activation` sin credenciales, vuelve a `pending_activation` permitiendo reemitir invitación).
  2. **Restablecimiento de acceso y reservas:**
     - El integrante del personal puede volver a iniciar sesión en `/login` con sus credenciales y TOTP.
     - Si es Profesional y su perfil profesional (#278) está completo, vuelve a ser elegible para nuevas reservas.
  3. **No restauración de turnos cancelados:**
     - **Ningún turno que haya sido cancelado (`status = 'cancelled'`) o rechazado/expirado antes o durante el período de desactivación se restaura ni cambia de estado.**
     - Los turnos futuros que seguían en `confirmed` o `requested` continúan exactamente en el estado en que se encuentren al momento de reactivar.
  4. **Auditoría:** Registra evento append-only de reactivación con actor `administrator` y referencia a la cuenta objetivo.

---

## 3. Matriz de Permisos y Autorización (`default-deny`)

| Actor | Estado del Actor | Operación | Target | Resultado Esperado |
| --- | --- | --- | --- | --- |
| **Administrador** | `active` | Listar cuentas internas de personal | `professional`, `secretary` | **Permitido** (proyección administrativa: id, email, rol, estado, conteo de turnos futuros afectados; sin datos de pacientes ni agendas) |
| **Administrador** | `active` | Crear e invitar cuenta | `professional`, `secretary` | **Permitido** (`:s1_02`, `:s1_03`) |
| **Administrador** | `active` | Editar cuenta (incluido email) | `professional`, `secretary` | **Permitido** (nueva regla en `Authorization.Rules`) |
| **Administrador** | `active` | Desactivar cuenta | `professional`, `secretary` | **Permitido** (nueva regla en `Authorization.Rules`; corta sesiones y reservas, retorna conteo de turnos futuros afectados) |
| **Administrador** | `active` | Reactivar cuenta | `professional`, `secretary` | **Permitido** (nueva regla en `Authorization.Rules`; restaura acceso sin tocar turnos cancelados) |
| **Administrador** | `active` | Reemitir invitación pendiente | `professional`, `secretary` (`pending_activation`) | **Permitido** (`:rei_02`) |
| **Administrador** | `active` | Crear / editar / desactivar / reactivar otro Administrador | `administrator` | **Denegado** (`{:error, :unauthorized}`) |
| **Administrador** | `active` | Operar pacientes, agendas, turnos, solicitudes, pagos o ajustes profesionales | Cualquiera | **Denegado** (`{:error, :unauthorized}` / redirección) |
| **Administrador** | `pending_activation` / `deactivated` | Cualquier operación administrativa | Cualquiera | **Denegado** (`{:error, :unauthorized}` / `:unauthenticated`) |
| **Secretaría** | `active` | Crear, listar, editar, desactivar o reactivar cuentas (`professional` o `secretary`) | Cualquiera | **Denegado** (`{:error, :unauthorized}` y bloqueo de ruta en `/administrador/cuentas`) |
| **Profesional** | `active` | Crear, listar, editar, desactivar o reactivar cuentas | Cualquiera | **Denegado** (`{:error, :unauthorized}` y bloqueo de ruta) |
| **Paciente / Anónimo** | Cualquiera | Cualquier operación de cuentas internas | Cualquiera | **Denegado** (`{:error, :unauthorized}` / `:unauthenticated`) |

---

## 4. Relevamiento del Estado Actual (Código, Pruebas Leídas y Pruebas Ejecutadas)

En cumplimiento de `docs/sprints/GUIA_TRABAJO_BETA.md`, se distingue estrictamente entre **código encontrado**, **pruebas leídas** y **pruebas realmente ejecutadas con resultados observados**.

### 4.1 Código encontrado en `origin/develop` (`ce13af7`)
- **Esquema y migraciones de `internal_accounts`:**
  - `priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs:6-20`: Crea `public.internal_accounts` con `CONSTRAINT internal_accounts_state_check CHECK (state IN ('pending_activation', 'active'))` y `CONSTRAINT internal_accounts_state_fields_check`. **No incluye aún el estado `'deactivated'`** ni permite preservar credenciales en un estado desactivado.
  - `priv/repo/migrations/20260918130000_add_email_to_internal_accounts.exs:11-14`: Índice único `internal_accounts_lower_email_idx` sobre `(lower(email)) WHERE email IS NOT NULL`.
  - `priv/repo/migrations/20260918140000_expand_internal_accounts_roles.exs:6-9`: Check de roles `('administrator', 'professional', 'secretary')`.
- **Contexto de cuentas y sesiones:**
  - `lib/origen/accounts.ex:63-147`: Implementa `create_and_invite_internal_account/3` y `reissue_internal_invitation/3`. **No existen aún funciones para listar cuentas internas, editar cuenta/email, desactivar cuenta ni reactivar cuenta.**
  - `lib/origen/accounts.ex:237-305`: `authenticate_internal_account/4` ya exige `account.state == "active"`.
  - `lib/origen/sessions.ex:48-65, 117-166, 209-227`: `create_session/2`, `fetch_session/2`, `touch_session/2` y `revalidate_principal/3` hacen `JOIN internal_accounts a ON a.id = s.account_id` exigiendo `"active"`, y `terminate_all_sessions/2` revoca todas las sesiones activas de un `account_id`.
- **Autorización y Auditoría:**
  - `lib/origen/authorization/rules.ex:61-84`: Contiene `:s1_02` (`:create_professional_account`), `:s1_03` (`:create_secretary_account`) y `:rei_02` (`:reissue_internal_invitation`). **Faltan las reglas de autorización para listar, editar, desactivar y reactivar cuentas de personal.**
  - `lib/origen/audit/events.ex:28-56`: Define eventos de invitación y activación; **faltan constructores de auditoría para edición, desactivación y reactivación de cuenta interna.**
- **Interfaz y Router:**
  - `lib/origen_web/router.ex:59`: `live "/administrador/cuentas", AdminInternalLive, :index` está montado en el scope general `:browser` sin pipeline `:require_internal_session` ni `on_mount` de rol administrador.
  - `lib/origen_web/live/admin_internal_live.ex:1-262`:
    - Sólo tiene un formulario básico para crear invitación (`role` + `email`). **No lista cuentas existentes, no permite editar email, no permite desactivar/reactivar ni muestra conteo de turnos futuros afectados.**
    - **Incompatibilidad beta detectada en línea 167:** `defp allowed_roles_for(%{"role" => "secretary"}), do: ["secretary"]`. Esto permite actualmente que una sesión de Secretaría monte `/administrador/cuentas` y vea el formulario con la opción `"Secretaria"` (aunque el backend luego rechace el submit). Según la beta (`design.md` y `spec.md`), Secretaría **no** tiene acceso a la pantalla de administración de cuentas.
- **Corte de nuevas reservas e integridad de turnos:**
  - `lib/origen/appointments/database_calendar.ex:28-40`: `list_professionals/0` ya filtra `WHERE a.role = 'professional' AND a.state = 'active'`. Sin embargo, `get_daily_schedule/3` (`líneas 56-94`) consulta `agenda_settings` sin verificar que `internal_accounts.state == 'active'`.
  - `lib/origen/consultation_types/database_catalog.ex:19-30`: `snapshot/2` consulta `agenda_settings` y `consultation_types` sin verificar que la cuenta profesional esté `active`.
  - `lib/origen/appointments/booking_service.ex:112-128`: `lock_eligible_professional!/1` ya bloquea `WHERE a.id = $1 AND a.role = 'professional' AND a.state = 'active'`.
  - `lib/origen/appointments/assisted_booking.ex:62-97, 250-258`: `ensure_active_professional/1` en `reserve/4` ya exige `state = 'active'`, pero `list_consultation_types/1` y `get_daily_schedule/3` no verifican `state = 'active'`.
  - `lib/origen/booking/authorization.ex:222-233`: `fetch_internal_account/3` ya exige `state == "active"`.
  - `priv/repo/migrations/20260926100000_create_appointments_table.exs` y `20261024100100_add_appointment_immutability.exs`: Los turnos tienen `ON DELETE RESTRICT` hacia `internal_accounts(id)` e inmutabilidad de snapshots e identidad.

### 4.2 Pruebas leídas
- `test/origen/accounts_test.exs`: Pruebas de autenticación, creación e invitación por administrador, reemisión y activación de cuentas `professional` y `secretary`.
- `test/origen/accounts/admin_permissions_verification_test.exs`: Verifica que Secretaría, Profesional y administradores pendientes no pueden crear cuentas (`create_and_invite_internal_account/3`).
- `test/origen_web/live/admin_internal_live_test.exs`: Pruebas del formulario actual en `/administrador/cuentas`. Nota: el test en líneas 52-58 (`"shows only secretary option for non-administrator"`) refleja el comportamiento histórico de permitir montar la vista a Secretaría, que debe reemplazarse en #374 para denegar/redirigir a Secretaría.
- `test/origen/authorization_test.exs`: Pruebas unitarias de `Origen.Authorization.Rules`.
- `test/origen/sessions_test.exs`: Pruebas de `create_session/2`, `fetch_session/2`, `touch_session/2`, `terminate_session/2` y `terminate_all_sessions/2`.
- `test/origen/appointments/database_calendar_test.exs`, `test/origen/appointments/patient_self_booking_test.exs` y `test/origen/appointments/assisted_booking_test.exs`: Pruebas de elegibilidad de profesionales activos en reservas autónomas y asistidas.

### 4.3 Pruebas realmente ejecutadas y resultados observados
Se ejecutó en el worktree limpio de este contrato el subconjunto de pruebas de referencia sobre cuentas internas, permisos de administrador, sesiones, plugs de autenticación/rol y elegibilidad de calendario/reservas:

```sh
env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_issue372_contract mix test \
  test/origen/accounts_test.exs \
  test/origen/accounts/admin_permissions_verification_test.exs \
  test/origen_web/live/admin_internal_live_test.exs \
  test/origen/authorization_test.exs \
  test/origen/sessions_test.exs \
  test/origen_web/plugs/authenticate_internal_session_test.exs \
  test/origen_web/plugs/require_internal_role_test.exs \
  test/origen/appointments/database_calendar_test.exs \
  test/origen/appointments/patient_self_booking_test.exs \
  test/origen/appointments/assisted_booking_test.exs
```

- **Resultado observado:** Código de salida **0**, **127 pruebas aprobadas, 0 fallos** (`Finished in 2.6 seconds`, `seed: 388965`, `Excluding tags: [postgres_security: true]`).
- **Alcance de la evidencia:** Esta ejecución comprueba únicamente el punto de partida existente (alta con invitación, sesiones, denegación de alta en dominio a otros roles y filtro de profesionales activos en `list_professionals/0` y `reserve`). **No prueba ni certifica** la edición de cuenta/email, la desactivación, el conteo de turnos futuros afectados ni la reactivación, que aún no están implementados y corresponden a #373, #374 y #375.

---

## 5. Mapa de Reutilización, Adaptación, Creación y Retiro

| Clasificación | Archivo / Componente | Estado actual | Acción requerida para #373 (Backend) / #374 (Interfaz) |
| --- | --- | --- | --- |
| **Reutilizar** | `lib/origen/accounts.ex` (`create_and_invite_internal_account/3`, `reissue_internal_invitation/3`, `authenticate_internal_account/4`) | Crea cuentas `professional` y `secretary` con invitación, reemite invitaciones y valida `state == "active"` al autenticar. | Conservar operación de alta con invitación y validación de login activo. |
| **Reutilizar** | `lib/origen/sessions.ex` (`terminate_all_sessions/2`, `fetch_session/2`, `revalidate_principal/3`) | Revoca todas las sesiones de una cuenta y rechaza sesiones cuya cuenta no esté en estado `"active"`. | Invocar `Sessions.terminate_all_sessions/2` dentro de la transacción de desactivación para corte inmediato de sesiones activas. |
| **Reutilizar** | `lib/origen/appointments/booking_service.ex` (`lock_eligible_professional!/1`), `lib/origen/booking/authorization.ex` (`fetch_internal_account/3`) | Ya exigen `a.state = 'active'` para autorizar y concretar nuevas reservas. | Conservar y cubrir con pruebas de regresión ante cuentas `"deactivated"`. |
| **Adaptar (#373)** | `priv/repo/migrations/` (`internal_accounts`) | `internal_accounts_state_check` sólo permite `'pending_activation'` y `'active'`, y `internal_accounts_state_fields_check` exige que solo `'active'` tenga `password_hash`/`totp_secret`. | Crear nueva migración que extienda `internal_accounts_state_check` para incluir `'deactivated'` (y ajuste `internal_accounts_state_fields_check` y `internal_account_verifier_projection` si aplica) preservando `password_hash`, `totp_secret` y `activated_at` al desactivar una cuenta activada, o `NULL` si se desactiva desde `pending_activation`. |
| **Adaptar (#373)** | `lib/origen/authorization/rules.ex` y `lib/origen/audit/events.ex` | Sólo contemplan creación (`:s1_02`, `:s1_03`) y reemisión (`:rei_02`). | Extender reglas `default-deny` para `:list_internal_accounts`, `:update_internal_account`, `:deactivate_internal_account` y `:reactivate_internal_account` (exclusivas de `{:role, :administrator}` en estado `:active` sobre targets `:professional` y `:secretary`), y agregar constructores de eventos de auditoría correspondientes. |
| **Adaptar (#373)** | `lib/origen/appointments/database_calendar.ex` (`get_daily_schedule/3`), `lib/origen/consultation_types/database_catalog.ex` (`execute/1`), `lib/origen/appointments/assisted_booking.ex` (`list_consultation_types/1`, `get_daily_schedule/3`) | `list_professionals/0` filtra `a.state = 'active'`, pero las consultas directas de horarios/catálogo por `professional_id` no verifican que la cuenta siga activa. | Asegurar que consultar horarios o catálogo de reserva para un profesional desactivado falle cerrado (`{:error, :invalid_professional}` / `{:error, :unavailable}`), cerrando cualquier vía de selección de slots para nuevas reservas. |
| **Crear (#373)** | `lib/origen/accounts.ex` (operaciones de ciclo de cuentas) | No existen funciones de listado, edición, desactivación ni reactivación. | Implementar `list_internal_accounts/1`, `update_internal_account/3` (incluido email con normalización y unicidad), `deactivate_internal_account/2` (cambio de estado, revocación de sesiones e invitaciones pendientes, preservación de turnos/historia y retorno de `future_affected_appointments_count`) y `reactivate_internal_account/2` (restauración de acceso sin restaurar turnos cancelados). |
| **Adaptar / Crear (#374)** | `lib/origen_web/live/admin_internal_live.ex` y `lib/origen_web/router.ex` | `AdminInternalLive` sólo renderiza el formulario de alta y permite montar a Secretaría con `allowed_roles_for(%{"role" => "secretary"})`. | Completar la vista de administración de cuentas para listar cuentas de Profesional y Secretaría, crear, editar correo, desactivar (mostrando el conteo de turnos futuros afectados para seguimiento de Secretaría) y reactivar; proteger la ruta/montaje exclusivamente para Administrador activo. |
| **Retirar del recorrido (#374)** | `lib/origen_web/live/admin_internal_live.ex:167` y `test/origen_web/live/admin_internal_live_test.exs:52-58` | Regla histórica que permitía a Secretaría montar `/administrador/cuentas` con opción `"Secretaria"`. | Retirar el permiso de montaje para Secretaría en `AdminInternalLive`; Secretaría debe ser denegada y redirigida fuera de `/administrador/cuentas`. |

---

## 6. Escenarios Verificables para Backend (#373) e Interfaz (#374)

> **Nota:** Los siguientes escenarios definen el contrato verificable que deben implementar y probar #373, #374 y #375. **No representan funcionalidad ya implementada ni certificada en este ticket.**

| ID | Escenario | Dado (GIVEN) | Cuando (WHEN) | Entonces (THEN) |
| --- | --- | --- | --- | --- |
| **C1** | **Alta de cuenta de Profesional y Secretaría por Administrador** | Un Administrador activo autenticado. | Crea una cuenta con rol `professional` o `secretary` y un email válido y único. | Se crea la cuenta en `pending_activation`, se emite invitación y se registra auditoría. |
| **C2** | **Edición de correo de cuenta interna** | Un Administrador activo y una cuenta existente de `professional` o `secretary` (con turnos e historial si es profesional). | El Administrador actualiza el `email` de esa cuenta a un nuevo correo válido y libre. | Se actualiza el `email` en `internal_accounts`, se registra auditoría y se conservan intactos el `id` de la cuenta, sus turnos, relaciones y perfil. |
| **C3** | **Rechazo de edición por correo duplicado o inválido** | Dos cuentas internas `A` y `B`, y un Administrador activo. | El Administrador intenta cambiar el correo de `B` al correo de `A` (incluso con distinta capitalización) o a un formato inválido. | La operación es rechazada (`{:error, :email_taken}` / `{:error, :invalid_email}`), sin modificar `B` ni generar efectos colaterales. |
| **C4** | **Desactivación urgente de Profesional con turnos futuros y solicitudes pendientes** | Un Profesional activo con perfil completo, sesión abierta, 2 turnos futuros `confirmed`, 1 solicitud futura `requested`, 1 turno pasado `attended` y 1 turno futuro `cancelled`. | El Administrador activo desactiva la cuenta de ese Profesional. | 1) La cuenta pasa a `deactivated`. 2) Se revocan inmediatamente las sesiones activas del Profesional. 3) El Profesional desaparece de `list_professionals` y no admite nuevas reservas en ningún canal (Paciente, Secretaría, Profesional). 4) Los 2 turnos `confirmed` y la solicitud `requested` **permanecen sin cambios** (ninguno se cancela automáticamente) y la historia se conserva. 5) La operación informa al Administrador exactamente **`3` turnos futuros afectados** (`2 confirmed + 1 requested`) para seguimiento por Secretaría, sin exponer identidades de pacientes ni abrir acceso a la agenda. |
| **C5** | **Desactivación de cuenta de Secretaría** | Una cuenta activa de Secretaría con sesión iniciada. | El Administrador activo desactiva la cuenta de Secretaría. | La cuenta pasa a `deactivated`, sus sesiones quedan revocadas inmediatamente, no puede iniciar sesión ni operar pacientes/reservas, y el conteo de turnos futuros afectados es `0`. |
| **C6** | **Corte inmediato de acceso tras desactivación** | Un Profesional o Secretaría cuya cuenta acaba de ser desactivada por el Administrador. | Intenta usar su sesión previa (`fetch_session`, `touch_session`, `revalidate_principal`), navegar a rutas protegidas o iniciar sesión nuevamente en `/login`. | Todos los intentos son rechazados con `{:error, :unauthenticated}` / redirección a login; no puede ejecutar ninguna operación de dominio. |
| **C7** | **Seguimiento de turnos de un Profesional desactivado por Secretaría** | Un Profesional fue desactivado teniendo un turno futuro `confirmed` y una solicitud futura `requested`. | Secretaría cancela uno de esos turnos con motivo justificado (flujo operativo de Secretaría). | El turno cancelado por Secretaría pasa a `cancelled` liberando disponibilidad, mientras los demás turnos no cancelados siguen preservados. Secretaría sigue sin poder aprobar solicitudes `requested`. |
| **C8** | **Reactivación de Profesional sin restaurar turnos cancelados** | El Profesional del escenario anterior (desactivado, con 1 turno futuro `cancelled`, 1 turno futuro `confirmed` y 1 solicitud futura `requested`). | El Administrador activo reactiva la cuenta del Profesional. | 1) La cuenta vuelve a estado `active`. 2) El Profesional recupera el acceso para iniciar sesión y (si su perfil está completo) vuelve a estar disponible para nuevas reservas. 3) El turno `cancelled` **permanece `cancelled`** (no se restaura). 4) El turno `confirmed` y la solicitud `requested` (si aún no expiró) continúan en sus estados. |
| **C9** | **Denegación de gestión de cuentas a otros roles** | Un actor con rol `secretary`, `professional`, `patient`, o un Administrador no activo. | Intenta listar, crear, editar, desactivar o reactivar una cuenta interna (por dominio o por LiveView `/administrador/cuentas`). | Es rechazado con `{:error, :unauthorized}` (y redirigido en LiveView) sin exponer datos de cuentas ni realizar mutaciones. |
| **C10** | **Denegación sobre cuentas de rol Administrador** | Un Administrador activo. | Intenta crear otra cuenta `administrator`, o editar/desactivar/reactivar su propia cuenta u otra cuenta con rol `administrator`. | La operación es rechazada con `{:error, :unauthorized}` sin mutaciones. |
| **C11** | **Aislamiento estricto: Administrador sin permisos operativos ni de ajustes profesionales** | Un Administrador activo autenticado. | Intenta buscar/registrar pacientes, ver agendas profesionales o historial de turnos, crear/cancelar/aprobar turnos, registrar pagos o leer/editar ajustes o perfil profesional (`/profesional/ajustes`, `/profesional/agenda`, `/secretaria/pacientes`, o contextos de dominio). | Todas las operaciones son denegadas con `{:error, :unauthorized}` / redirección. El Administrador sólo ve el conteo de turnos futuros afectados dentro de su módulo de cuentas. |

---

## 7. Diferencias frente al Estado Actual, Pendientes y Registro de Aprobación

### 7.1 Diferencias identificadas respecto del código actual
1. **Base de datos (`internal_accounts`):** Sólo admite `pending_activation` y `active`. Falta el estado `deactivated` en el constraint `internal_accounts_state_check` y en `internal_accounts_state_fields_check`.
2. **Dominio (`Origen.Accounts` y `Origen.Authorization.Rules`):** Sólo existen alta con invitación y reemisión de invitación. Faltan `list_internal_accounts`, `update_internal_account` (edición de correo), `deactivate_internal_account` (con conteo de turnos futuros afectados y revocación de sesiones) y `reactivate_internal_account`.
3. **Consultas de disponibilidad y catálogo (`DatabaseCalendar.get_daily_schedule/3`, `DatabaseCatalog.execute/1`, `AssistedBooking`):** Aunque `list_professionals/0` y `reserve` filtran `state = 'active'`, las lecturas de agenda diaria y catálogo por ID no filtran `internal_accounts.state = 'active'`.
4. **Interfaz (`AdminInternalLive`):** Sólo muestra el formulario de alta y aún permite montar la vista al rol `secretary`. Falta el listado de cuentas internas, edición de email, acciones de desactivar/reactivar, visualización del conteo de turnos futuros afectados y el bloqueo estricto de acceso a Secretaría en `/administrador/cuentas`.

### 7.2 Dependencias y bloqueos
- **Blockers nativos de #372 y de la padre #279:** Ninguno.
- No se identificaron dependencias técnicas externas que impidan avanzar con [#373 (Backend)](https://github.com/Team-Origen/origen/issues/373) ni [#374 (Interfaz)](https://github.com/Team-Origen/origen/issues/374).

### 7.3 Registro de aprobación del contrato (#372)
- **Estado:** Contrato aprobado por el responsable del slice (`ChordanDev`) conforme a `docs/sprints/GUIA_TRABAJO_BETA.md`.
- **Alcance de la aprobación:** Cubre exclusivamente la especificación contractual de [#372](https://github.com/Team-Origen/origen/issues/372) y habilita el inicio de [#373 (Backend)](https://github.com/Team-Origen/origen/issues/373) y [#374 (Interfaz)](https://github.com/Team-Origen/origen/issues/374). No acredita implementación de código ni cierre de [#279](https://github.com/Team-Origen/origen/issues/279) o [#375](https://github.com/Team-Origen/origen/issues/375).
