# Academic patient magic link — issue #511

Tracker: `feat/511-academic-patient-magic-link` → `develop`; baseline `78f467a`. Local fictional-data enablement and PR publication authorized; no deployment or merge.
Delivery: user selected `feature-branch-chain`; tracker draft/no-merge, backend slice `feat/511-01-academic-issuance`, then UI slice `feat/511-02-academic-ui`. Nonclosing `Refs #511` until browser and deployment evidence are complete.

## Specs

### S1 — Issue #511 (verbatim)

### Objetivo

Facilitar el acceso de pacientes ficticios durante la primera evaluación académica mostrando el magic link en la misma pantalla donde se solicita, con las acciones Copiar enlace y Abrir acceso, sin depender de la recepción de correo ni consultar MailBox.

### Contexto y alcance

Solución temporal y adicional para la beta académica de Sprint 4. Todos los pacientes y datos del entorno de evaluación serán ficticios. No es un mecanismo válido de autenticación para pacientes reales: en esta modalidad se permite deliberadamente acceder a un paciente ficticio registrado conociendo su correo.

**Recorrido acordado**

1. Mantener el formulario actual de ingreso de correo en `/paciente/acceso`.
2. Al solicitar el acceso con un correo correspondiente a un paciente registrado en la beta, generar el magic link con el mecanismo existente.
3. Mostrar el enlace en el mismo bloque de resultado de esa pantalla, reutilizando la presentación de Administración: campo de solo lectura, Copiar enlace y Abrir acceso.
4. Permitir abrir el enlace e ingresar a la cuenta ficticia por el recorrido normal, conservando vencimiento y uso único.
5. No mostrar un enlace si no corresponde a un paciente registrado ni crear pacientes o vincular identidades por esta acción.

**Sin selector ni lista adicional**

No incorporar un selector de pacientes, un listado de cuentas de prueba, una allowlist individual adicional ni otra pantalla. El usuario utilizará el correo en el formulario existente. No agregar una contraseña genérica al recorrido. La separación de seguridad se establece en el entorno y sus datos, no en una selección de pacientes.

**Reutilización y relación con el correo**

- Reutilizar la generación y consumo del magic link del paciente, así como los controles visuales de copiar/abrir de Administración. No reutilizar la activación de personal con contraseña/TOTP ni crear un segundo sistema de tokens.
- El enlace debe estar disponible solo en el resultado transitorio de emisión; dejar de mostrarlo al recargar o abandonar la pantalla, como la invitación administrativa. No almacenar tokens en texto plano para recuperarlos posteriormente.
- Mantener el vencimiento y uso único existentes y los efectos vigentes sobre enlaces anteriores al emitir uno nuevo.
- No eliminar ni reemplazar la integración de correo de #490. La presentación académica debe permitir completar el acceso aunque no haya entrega externa, sin que la disponibilidad del proveedor sea requisito de la demostración.
- Fuera de la modalidad de evaluación, conservar el flujo normal por correo y su respuesta pública no enumeradora, sin presentar tokens.
- Generar el enlace con el origen público HTTPS aprobado del entorno de evaluación, no con localhost en el despliegue.

**Límite estricto de entorno**

- Habilitar la presentación directa mediante configuración explícita exclusiva de evaluación, desactivada por defecto.
- Usar un despliegue y una base aislados, exclusivamente con datos ficticios. Comprobar esta condición antes de habilitar la modalidad; no asumir que cualquier despliegue llamado beta está aislado.
- No habilitar esta presentación en el entorno con pacientes reales. La modalidad académica acepta una relajación deliberada de autenticación solo para identidades ficticias; no debe describirse como equivalente a verificar posesión del correo.
- No publicar `/dev/mailbox`, activar rutas de desarrollo ni usar el modo de desarrollo del servidor como solución para el despliegue académico.
- No incluir tokens, enlaces completos utilizables ni credenciales en logs, issues o capturas compartidas. Los ejemplos y evidencia deben redactar el enlace.
- Documentar cómo habilitar, comprobar y desactivar la modalidad al finalizar la evaluación.

**Organización del trabajo**

Mantener la integración definitiva de correo en su rama y preservar sus cambios. La implementación académica debe partir de `develop` actualizado en una rama independiente. Antes de cambiar de rama, preservar de forma segura los cambios pendientes; alternativamente, usar un worktree separado para no tocar el árbol de trabajo de #490. No depender de integrar primero la rama de correo ni descartar sus cambios. Esta issue no autoriza publicar, desplegar ni modificar otras ramas automáticamente.

Referencias de implementación a revisar: `lib/origen/patient_access.ex`, `lib/origen/patient_access/email.ex`, `lib/origen_web/live/patient_access_live.ex`, `lib/origen_web/controllers/patient_access_controller.ex` y la presentación de invitación en `lib/origen_web/live/admin_internal_live.ex`. Seguir `docs/navigation/URL_CONVENTIONS.md` sin cambiar las URLs de acceso.

Si se asocia la implementación a un cambio OpenSpec, registrar nombre, ruta y slice conforme a AGENTS.md y mantener las referencias inversas en proposal.md; no se asigna uno por suposición en esta publicación.

### Área principal

Frontend

### Criterios de aceptación

- [ ] El formulario actual permite ingresar el correo sin agregar selector, listado de pacientes, pantalla adicional ni contraseña genérica.
- [ ] Con la modalidad académica explícitamente habilitada en el entorno ficticio aislado, un correo de paciente registrado produce el magic link en el mismo bloque de resultado.
- [ ] La presentación reutiliza el formato administrativo con campo de solo lectura, Copiar enlace y Abrir acceso; no rediseña la pantalla.
- [ ] Copiar obtiene el enlace correcto y Abrir acceso permite completar el ingreso del paciente ficticio correspondiente; el enlace apunta al origen HTTPS del entorno evaluable.
- [ ] Un correo no registrado no produce enlaces, altas ni vinculaciones de pacientes.
- [ ] Se mantienen vencimiento, uso único e invalidación vigente de enlaces anteriores, mediante el mecanismo existente y sin persistir tokens en texto plano.
- [ ] El enlace deja de mostrarse al recargar o abandonar el resultado; no se habilita un mecanismo de recuperación de tokens desde su hash.
- [ ] El acceso académico puede completarse sin recepción de correo ni disponibilidad del proveedor, y la integración definitiva no se elimina ni sustituye.
- [ ] Con la modalidad desactivada, no se muestran magic links ni se altera la respuesta pública no enumeradora del flujo normal.
- [ ] La configuración queda desactivada por defecto y se registra la comprobación de despliegue/base exclusivamente ficticios antes de habilitarla; no se aplica a entornos con pacientes reales.
- [ ] No se exponen rutas de desarrollo, MailBox ni tokens en logs o evidencia compartida.
- [ ] Las pruebas cubren modalidad activada/desactivada, correo registrado/desconocido, enlace de un solo uso/vencido, emisión sin entrega externa y conservación del flujo normal. Se verifica en navegador copiar, abrir y recargar.
- [ ] Se documentan habilitación, desactivación, acceso para los profesores y restricciones de uso, con evidencia sanitizada y pendientes explícitos.
- [ ] El trabajo queda separado de #490, con sus cambios preservados y sin modificar ni descartar el trabajo pendiente de esa rama.

### Dependencias y bloqueos

Antes de habilitar: disponer de un entorno de evaluación con HTTPS y base separada, confirmar que contiene únicamente datos ficticios y preparar correos registrados de pacientes ficticios. Si no puede comprobarse el aislamiento o existen datos reales, no habilitar esta modalidad y resolver esa condición primero.

No depende de Gmail, Resend ni otro proveedor para realizar la demostración de acceso. La preservación de los cambios de #490 debe resolverse antes de mover el árbol de trabajo. No se agregan bloqueos nativos por esta publicación.

### Fuera de alcance

- Exponer enlaces de pacientes reales o habilitar esta modalidad como autenticación de producción.
- Agregar selector, listado o allowlist individual de pacientes de prueba, contraseña compartida o un nuevo rol de evaluación.
- Sustituir la integración definitiva de correo de #490.
- Reimplementar tokens o el flujo de activación del personal.
- Modificar reglas de permisos o permitir que el formulario cree/vincule pacientes.
- Publicar MailBox de desarrollo, secretos o enlaces de acceso utilizables en la evidencia.
- Rediseñar las pantallas o cambiar las rutas actuales.

### Evidencia esperada

Capturas con enlace redactado del resultado y controles reutilizados; pruebas de ingreso con paciente ficticio, expiración y uso único; evidencia de modalidad desactivada y preservación del flujo normal; comprobación de entorno/base ficticios aislados; instrucciones para profesores y desactivación; referencia a la rama independiente y preservación del trabajo de correo. No publicar credenciales ni tokens. Crear esta issue no significa que la solución esté implementada o habilitada.


### S2 — Local development (verbatim user corrections)

> lo estoy probando desde local host, ha qu se pueda visualizar desde aqui tambien y no solo en el despligue

> solo tine datos ficticios

Local enablement is authorized for this fictional-data development instance only; deployment remains HTTPS-only and default-off.

## Tasks

- T1 [S1] DONE: Guarded issuance and transient UI implemented; focused configuration/domain/LiveView/controller/integration tests observed 35 passed, exit 0 after test parser correction. Route: inline; no commit yet.
- T2 [S1] DONE: Operator guide and independent security verification completed; B1 origin validation corrected and independently rechecked. Route: inline documentation, gentle-ai-verify (security risk); commit: not authorized.
- T3 [S1] BLOCKED: Focused DB-backed tests passed (35). Full mix test exited 2: 1102/1218 passed, 116 failures, 35 skipped, 8 excluded; 103 failures report internal_accounts/agenda_settings foreign key violations. Causality against baseline is unproven. Browser copy/open/reload unavailable (no connected browser). Await user decision on separate suite diagnosis or draft PR with explicit failing checks; no approval/publication yet.

- T4 [S2] DONE: Explicit dev-build-only loopback exception implemented and temporarily enabled on the user's running local fictional-data instance. Configuration RED/GREEN observed, docs updated, independent security verifier found no blocker. Browser/DB evidence remains separately blocked in T3. Route: inline coupled change, independent security verifier. Commit: not authorized.

- T5 [S1] BLOCKED: User authorized status:approved and PR conditional on successful checks. Full suite fails; no label, commit, push or PR executed pending decision. Destination github.com/Team-Origen/origen, planned base develop, actor has admin permission.

- T6 [S1] BLOCKED (proof unavailable): Candidate fresh-partition suite exit 0, 1218 passed, 35 skipped, 8 excluded. Baseline worktree 78f467a failed before tests, exit 1, missing PostgreSQL password. No retry or credential copying. Baseline causality comparison incomplete; browser proof still missing. Human disposition required before publication.

## Log

L16: Baseline reevaluation exited 0: 1206 passed, 35 skipped, 8 excluded; candidate isolated suite exited 0: 1218 passed, 35 skipped, 8 excluded, same seed 511. Temporary baseline credentials removed and absence verified. No unrelated source fixes. Historical failures did not reproduce; compatible with old test-state contamination, not a definitive causal proof.

L17: User selected feature-branch-chain in the delivery questionnaire. One slicing pass: tracker document (~160 lines), backend/config/domain tests (~290 lines), UI/docs/LiveView tests (~350 lines). Publish tracker draft plus dependent slices; no merge. Main is the verified repository default; develop remains the explicitly planned integration destination. Remote develop advanced to 4040c7e; local suite evidence remains pinned to 78f467a. CI/integration against updated destination is pending.

L14: PRUBAEVLAUAR DENUEVO EL PROBLEMA ANTES DE MEREGUIAR

L15: Reevaluation identified missing ignored config/test.local.exs in baseline worktree. Structural inspection (without printing values) confirmed only Repo username/password overrides, no database or URL override. Explicit reevaluation uses a temporary mode-600 copy inside baseline worktree with EXIT cleanup, new partition _511_baseline_recheck_20261113 and seed 511. Candidate's 1218-test GREEN remains valid. Baseline recheck job-3 pending; no merge or publication.

L12: CONTINUA CON LO QUE ETSABA AHICENOD, SI SE SOLUCIONA EL PROVEMA, ABANZA DIRECTAMENTE CON LA CREACION DEL PR

L13: Candidate `env -u ORIGEN_DATABASE_URL MIX_ENV=test MIX_TEST_PARTITION=_511_candidate_20261113 mix test --seed 511` exited 0: 1218 passed, 35 skipped, 8 excluded. Fresh isolated database, no unrelated fixes. Baseline at 78f467a in registered .git/agent-worktrees/511-baseline failed before tests (exit 1) due to missing PostgreSQL password. Candidate failures did not reproduce, but baseline comparison and browser proof remain incomplete. No automatic retry or credential reuse; no publication yet.

L10: AL FUNCIONAMIENTO ANCTUAL ANDA, HAS LA PRUEBAS, LUEGO, SI YA ES POSIBLE, DEJA LA ISSUE EN STATUS APROVAD Y HACER EL PR

L11: Focused run first exited 2 (34/35) due to nonexistent Floki test parser; replaced with repository-standard LazyHTML, rerun exited 0 (35 passed). Full mix test job-3 exited 2 after 54s, 1102/1218 passed, 116 failed, 35 skipped, 8 excluded. Bounded log summary found 103 Postgrex foreign key violations deleting internal_accounts referenced by agenda_settings; not proven pre-existing or caused by this candidate. Do not claim baseline failure without baseline evidence. No full-suite retry or extra investigation performed. Browser help unavailable (no connected browser). Publication and issue approval paused for explicit disposition.

L6: lo estoy probando desde local host, ha qu se pueda visualizar desde aqui tambien y no solo en el despligue

L7: solo tine datos ficticios

L8: Tidewave confirmed environment :dev, endpoint http://localhost:4000, academic display false before changes. Added compile-time dev restriction and explicit local_development override, allowing exact localhost/127.0.0.1/::1 HTTP(S) only. Remote deployment remains public HTTPS-only; both enable/isolation gates remain mandatory. ExUnit config probe on dev server observed RED (3/4 passed) then GREEN (4/4 passed). Temporarily enabled configuration in the running local process and observed academic_display_enabled true. Activation does not persist after restart; documented explicit startup variables. No environment files or real deployment modified.

L9: Format check, MIX_ENV=test compile --warnings-as-errors and git diff --check exited 0. Independent security verifier scoped to S2 found no blocker. browser_eval help failed because no browser was connected; no retry. Full DB tests and browser copy/open/reload remain unverified. No commits, push or production enablement. Local correction complete; full #511 remains partial pending T1/T3 evidence.

L1: quiero que hagas una rama nueva y trabajes en la issue #511 — Mostrar el magic link en pantalla para la beta académica con pacientes ficticios

L2: Fetched origin/develop; local develop matched. Created independent branch. Existing untracked PRUEBA_INTEGRAL_PACIENTES.md and odd/tasks/491-stack-rebase.md preserved. Forecast about 350 changed lines; no push, deployment, mode enablement or commits authorized. Real isolated deployment and browser evidence remain to be established.

L3: Initial `mix test test/origen/academic_patient_access_test.exs` exited 1 before tests: PostgreSQL localhost:5433 connection refused. No functional RED/GREEN claimed; no DB retry or infrastructure mutation. Added domain and LiveView tests, but they remain unexecuted.

L4: Independent verify found B1: origin guard accepted loopback variants and malformed ports. Isolated no-start configuration test observed RED exit 2 twice, then GREEN exit 0 (1 passed). Corrected with URI.new and DNS-host validation; verifier rechecked only B1 and reported resolved, probe exit 0 and diff check exit 0.

L5: `mix format --check-formatted`, `MIX_ENV=test mix compile --warnings-as-errors`, `git diff --check` all exit 0. RDD mode status reports off (default); no native review started. No commits, push, deployment or mode enablement performed. Pending required DB/browser proof is a human decision blocker, not a completed feature. Risk: item 2 (deliberate authentication relaxation), contained behind default-off explicit isolation confirmation.
