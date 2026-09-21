# Issue 86: Implementar emisión y consumo de Magic Link para Pacientes

## Outcome

Backend robusto y seguro para la emisión, entrega y consumo de enlaces de acceso temporal (*Magic Link*) sin contraseña para pacientes, cumpliendo los criterios de seguridad de #38 (tokens opacos de un solo uso, expiración estricta, respuesta no enumeradora y auditoría sanitizada).

## Contexto y Alcance Autorizado

- Subissue ejecutable de #38 (PLN-05). Responsable: `@samuel-olmos`.
- Rama de trabajo: `feature/86-magic-link-patients`.
- Revisor: `@ChordanDev` (Lucca).
- Dominio: Pacientes, Cuentas, Backend, Seguridad.
- Fuera de alcance: Resolver otras subissues del mismo PLN (#87 completado de perfil), Google OAuth (postergado para sprint posterior), usar credenciales o servicios de producción.

## Criterios de Aceptación

- [ ] Genera enlaces con tokens opacos, de un solo uso y duración limitada (15 minutos).
- [ ] Autentica al Paciente al consumir un enlace válido e invalida el token inmediatamente.
- [ ] Evita enumerar cuentas en solicitudes y respuestas inválidas.
- [ ] Audita emisión y consumo sin registrar tokens ni enlaces completos en logs ni eventos de auditoría.

## Tareas de Implementación

### Tarea 1: Migración y Esquema de Base de Datos para Magic Links
- Crear migración `priv/repo/migrations/*_create_patient_magic_links.exs` con columnas:
  - `id` (bigint identity)
  - `email` (string normalizado)
  - `token_digest` (binary/string SHA-256)
  - `expires_at` (utc_datetime_usec)
  - `consumed_at` (utc_datetime_usec, nullable)
  - `inserted_at` (timestamps)
- Crear índice único para tokens activos y asegurar permisos defensivos.
- Crear esquema Ecto `Origen.PatientAccess.MagicLink`.

### Tarea 2: Contexto de Dominio `Origen.PatientAccess` — Emisión
- Generar tokens criptográficamente seguros (`:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)`).
- Calcular y almacenar exclusivamente el digest SHA-256 (`token_digest`).
- Invalidar enlaces previos no consumidos para el mismo correo.
- Construir y entregar el correo de acceso a través de Swoosh (`/dev/mailbox` en desarrollo).
- Auditar el evento de emisión sin incluir el token en plano ni la URL completa.
- Retornar siempre `:ok` de forma no enumeradora.

### Tarea 3: Contexto de Dominio `Origen.PatientAccess` — Consumo y Validación
- Búsqueda por `token_digest` en la base de datos.
- Validar que el token no haya sido consumido y que `now < expires_at`.
- Invalidar atómicamente el token marcando `consumed_at = now`.
- Rechazar tokens inexistentes, expirados o ya consumidos con error fail-closed.
- Auditar el consumo (éxito o fallo) sin exponer secretos.
- Resolver o vincular la cuenta/identidad del paciente para la sesión.

### Tarea 4: Controlador Web de Consumo y Verificación
- Registrar endpoint `/access/verify` en `OrigenWeb.Router`.
- Crear `OrigenWeb.PatientAccessController` para procesar el clic del enlace mágico.
- En caso exitoso: iniciar sesión del paciente en la conexión HTTP y redirigir al área correspondiente.
- En caso fallido: redirigir a `/access` con mensaje neutro/seguro sin enumeración.

### Tarea 5: Integración con la Pantalla de Acceso (`PatientAccessLive`)
- Conectar el formulario de `PatientAccessLive` (`phx-submit`) con la función `PatientAccess.request_magic_link/1`.
- Preservar la respuesta no enumeradora ante cualquier resultado de emisión.

### Tarea 6: Suite Completa de Tests y Calidad
- Tests unitarios y de integración de emisión (generación, digest, correo, auditoría).
- Tests de consumo (éxito, expiración, reutilización/un solo uso, tokens corruptos).
- Tests de no enumeración y protección de secretos (probar que ningún token llega a logs ni auditoría).
- Verificación de formato (`mix format --check-formatted`) y compilación limpia (`mix compile --warnings-as-errors`).

## Evidence
- Commit: `a115cea` (feat(auth): implementar emisión y consumo de magic link para pacientes)
- Acceptance criteria verified: all 4 criteria satisfied.
