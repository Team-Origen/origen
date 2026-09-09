# Sprint 0 — Fundaciones verificables

## Propósito y modelo operativo

Sprint 0 establece el repositorio, la arquitectura mínima, CI, auditoría transversal y autorización default-deny necesarios para iniciar slices sensibles con controles revisables.

- **GitHub Issues:** trabajo ejecutable y criterios de aceptación.
- **Project #3 `Origen Development`:** tablero diario.
- **Este Markdown:** contexto histórico, decisiones, gates y enlaces; no duplica el detalle de ejecución de las issues.

## Enlaces rápidos

- [#1 — Scaffold Phoenix/LiveView with PostgreSQL and minimum CI](https://github.com/Team-Origen/origen/issues/1)
- [#2 — Implement append-only audit and default-deny authorization](https://github.com/Team-Origen/origen/issues/2) — depende de [#1](https://github.com/Team-Origen/origen/issues/1).
- [#3 — Bootstrap and activate the first Administrator](https://github.com/Team-Origen/origen/issues/3) — depende de [#1](https://github.com/Team-Origen/origen/issues/1) y [#2](https://github.com/Team-Origen/origen/issues/2).

## Ficha histórica

| Campo | Registro |
| --- | --- |
| Estado | En progreso |
| Timebox | 2026-08-23 a 2026-09-05; el 5 de septiembre es el límite, no una obligación de completar días |
| Capacidad | Techo de 64 h-equipo; 52 h planificadas y 12 h sin comprometer |
| Alcance | Repositorio, Phoenix/LiveView, PostgreSQL 17, CI mínimo, auditoría, autorización y bootstrap no productivo |
| Fuera de alcance | Google OAuth y WhatsApp; no se crean mocks, credenciales, webhooks ni conectividad para esas integraciones |

**Criterio de cierre:** camino demostrable de despliegue local e integración, matriz de autorización aprobada y evidencia de auditoría del bootstrap. La fecha real y los aprendizajes se registran aquí al cerrar el sprint.

## Decisiones y restricciones vigentes

### Repositorio y entrega

- El repositorio público `Team-Origen/origen-api` fue renombrado y redirige a [`Team-Origen/origen`](https://github.com/Team-Origen/origen). Esta es una verificación ya realizada.
- Stack: Phoenix + Elixir + LiveView, aplicación `origen` en la raíz, sin Umbrella inicialmente.
- `develop` y `main` requieren PR, aprobación y CI verde; no hay push directo. Las ramas siguen `tipo/<issue>-descripcion-breve` y se vinculan a una issue.
- GitHub Actions ejecutará formato, compilación sin warnings, tests con PostgreSQL 17 y escaneo de secretos. Las issues y PRs son la referencia ejecutable.

### Seguridad, datos y configuración

- El repositorio permanece público: nunca se versionan credenciales, tokens, datos reales de pacientes, archivos locales sensibles ni cadenas de conexión.
- Desarrollo local usa `config/dev.local.exs` ignorado por Git y `config/dev.local.example.exs` con placeholders no sensibles. Staging, producción y CI usan variables de entorno y gestores de secretos del entorno.
- Origen usa PostgreSQL 17 local en una instancia separada, `localhost:5433`; CI y otros entornos usan el endpoint entregado por su configuración, sin imponer ese puerto.
- Fly.io es solo candidato provisional para staging/piloto con datos sintéticos. Producción requiere gates separados de costo, cumplimiento, residencia de datos, seguridad, backups, recuperación, SLA y operación.

### Autorización y auditoría

- La matriz canónica es [`docs/security/AUTHORIZATION_MATRIX.md`](../security/AUTHORIZATION_MATRIX.md), versión 0.4 aprobada el 2026-08-24. El backend es la autoridad y todo permiso no declarado se deniega por defecto.
- La auditoría es automática, silenciosa, minimizada e inmutable. La tabla aprobada es `audit_events`; no almacena secretos ni datos sensibles. El rol de aplicación no puede ejecutar `UPDATE`, `DELETE` ni `TRUNCATE`, con trigger defensivo adicional.
- Una corrección agrega un evento nuevo; no se editan ni borran eventos existentes.

### Bootstrap del primer Administrador

- `mix origen.bootstrap_admin` solo se ejecuta en un entorno no productivo, con buzón local/de prueba y sin datos reales u operativos.
- Samuel opera el bootstrap; Santiago recibe la invitación, define personalmente la contraseña y enrola TOTP. La cuenta pasa de `Pendiente de activación` a `Activa` únicamente mediante ese flujo.
- La creación es única, la invitación es de un solo uso y vence a las 24 horas. No se permite inserción manual ni credenciales predeterminadas; emisión, reemisión, consumo, vencimiento, fallos y activación se auditan sin secretos.
- La decisión de producción DA-03 no bloquea este bootstrap no productivo; sí bloquea cualquier uso real.

#### Issue #3 operational handoff

The implementation remains a non-production capability, not a production-readiness claim. Reviewers and operators must use these boundaries:

| Topic | Current decision |
| --- | --- |
| Invocation | Approved entry points are `mix origen.bootstrap_admin` from a source checkout and packaged `bin/origen_bootstrap_admin`. Both call the same fail-closed gate before bootstrap argument parsing or I/O; production-compiled releases deny execution. Do not substitute `bin/origen eval`, a remote console, or direct database/context calls. |
| Dependencies and keys | Argon2, TOTP, and Cloak dependencies resolve, but deployment must still provide the native build toolchain, a verifier key of at least 32 bytes, and a tagged encryption keyring with exactly one active key. Runtime secret-provider wiring and key rotation/read verification remain deployment prerequisites. |
| Ingress and observability | Keep the activation route unexposed until TLS and ingress, access-log, APM, exception, mail/support, and database-telemetry redaction have passed canary checks. Application parameter filtering alone is insufficient. |
| Rollback | Disable the gate, remove ingress exposure, and stop token delivery while preserving account, invitation, and append-only audit history. The migration refuses to drop populated bootstrap tables; destructive removal needs separate maintainer and security approval. |
| Delivery limitation | Current task output and email contain references only. End-to-end activation requires a separately reviewed one-time token channel; no operator may reconstruct or disclose the raw token through logs, mail diagnostics, or support tooling. |

Operational details and verification checklists are in [`FIRST_ADMIN_BOOTSTRAP.md`](../deployment/FIRST_ADMIN_BOOTSTRAP.md) and [`ACTIVATION_DATA_HANDLING.md`](../security/ACTIVATION_DATA_HANDLING.md).

## Decisiones humanas pendientes

| ID | Decisión | Límite actual |
| --- | --- | --- |
| **DA-03** | Definir el entorno definitivo de producción y el proveedor de correo productivo. | Fly.io solo puede considerarse para staging/piloto sin datos reales. No autoriza producción ni cambia el bootstrap no productivo aprobado. |
| **DA-04** | Definir nombres físicos de columnas, tipos y constraints de PostgreSQL para la auditoría append-only. | La base ya aprobada es `audit_events`, con actor, evento, entidad, resultado y fecha/hora; faltan los detalles alineados con el scaffold. |

## Responsables y gates

| Entregable | Responsable principal | Gates esenciales |
| --- | --- | --- |
| #1 Scaffold y CI | Lucca (scaffold), Samuel (CI), Said (revisión) | Rename verificado, PostgreSQL 17 local verificado y PR con CI verde. |
| #2 Auditoría y autorización | Santiago | #1 integrado, OTP 29, PostgreSQL 17 en `5433`, pruebas de permisos, denegación, inmutabilidad y minimización, más revisión independiente. |
| #3 Bootstrap | Lucca (autor), Samuel (operador), Santiago (activador), Said (revisor) | #1 y #2 integrados; ejecución no productiva, revisión independiente y evidencia sanitizada. |
| Candidato 4 | Owner por asignar | Sigue siendo draft interno. Antes de publicarlo requiere owner, inventario exacto de archivos y criterios finales de aceptación. Depende del scaffold. |

## Registro breve de evidencia

- 2026-08-24: se aprobó la matriz de autorización 0.4, la secuencia #1 → #2 → #3 y la capacidad de 52 h-equipo.
- 2026-08-24: PostgreSQL 17.11 quedó verificado para Origen en `localhost:5433` en el entorno de Lucca; las verificaciones del resto del equipo siguen siendo gates de sus issues.
- Se verificó que `Team-Origen/origen-api` fue renombrado y redirige a `Team-Origen/origen`.
- La configuración operativa autenticada de Project #3 aún requiere readback. No se da por verificada ninguna vista, workflow, asignación de iteración ni vinculación de issues.

## Pendientes operativos

- Obtener readback autenticado de Project #3 y verificar la vinculación de las issues al tablero.
- Refinar Candidate 4 con owner, inventario de archivos y criterios finales de aceptación antes de publicarlo como issue.
