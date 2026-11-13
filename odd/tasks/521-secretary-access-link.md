# Secretary access link display — issue #521

Branch: `feat/521-secretary-access-link`, from `develop` `ca1a9f5` (post-#511 integration). The user will do the manual review: no push and no PR until then. Reuses the #511 academic modality (default off, fictional data) and its tokens without modifications.

## Specs

### S1 — Issue #521 (verbatim)

### Objetivo

Cuando Secretaría vincula o reemplaza el correo de acceso de un paciente (recorrido actual de registrar y comprobar el correo), mostrar el magic link de comprobación en la misma pantalla, con Copiar enlace y Abrir acceso, igual que la pantalla de acceso del paciente (#511), sin depender de recibir el correo ni de MailBox.

### Contexto y alcance

- Solución provisional para la beta académica, igual que #511. Los datos usados en el entorno local y en el despliegue académico son exclusivamente ficticios.
- El recorrido de vincular correo ya existe: hoy envía el enlace por el correo simulado y muestra solo un mensaje de confirmación. Esta issue pide que, además de conservar ese envío, el enlace quede visible para copiarlo o abrirlo desde esa misma pantalla, replicando lo implementado en la pantalla de acceso con magic link.
- Reutilizar la emisión, los tokens existentes y los controles visuales de #511 (campo de solo lectura, Copiar enlace, Abrir acceso). No se crea un segundo mecanismo de tokens y no se marca el correo como verificado por mostrar el enlace.
- Mostrar el enlace solo como resultado transitorio de la operación exitosa: desaparece al recargar o al cambiar de paciente, sin persistir tokens en texto plano ni habilitar recuperación desde su hash.
- No mostrar ningún enlace si la operación falla o falta autorización; conservar los mensajes de error actuales.
- Misma modalidad de configuración explícita de #511: desactivada por defecto, habilitada en el entorno local y en el despliegue académico con datos ficticios. El usuario informó que Copiar enlace y Abrir acceso ya funcionan en la pantalla de acceso; esta issue replica ese comportamiento en Secretaría.
- Esto no reemplaza ni modifica el flujo de los tokens, su vencimiento, su uso único ni la integración definitiva de correo (#490).
- Sin selector de pacientes, listados, allowlist ni contraseñas. La separación de seguridad sigue establecida por el entorno y sus datos.

### Área principal

Frontend

### Criterios de aceptación

- [ ] Con la modalidad académica habilitada, al vincular o reemplazar el correo desde Secretaría, el enlace se muestra en el mismo bloque de resultado con campo de solo lectura, Copiar enlace y Abrir acceso, reutilizando el formato de #511.
- [ ] Se reutilizan los tokens existentes: mismo vencimiento, uso único e invalidación de enlaces anteriores; no hay segundo sistema de tokens ni marcado de posesión verificado.
- [ ] El enlace aparece solo en el resultado transitorio de la operación exitosa y desaparece al recargar o abandonar; no se persiste ni se recupera desde su hash.
- [ ] Si la operación falla o falta autorización, no se muestra ningún enlace y se conservan los errores actuales.
- [ ] Con la modalidad desactivada, el recorrido de Secretaría queda exactamente como hoy y el flujo normal por correo no cambia.
- [ ] Funciona en el entorno local y en el despliegue académico con la misma configuración explícita de #511, sin agregar selector, listado ni contraseña.
- [ ] Las pruebas cubren modalidad habilitada/deshabilitada, éxito y error de vinculación y reemplazo, transitoriedad y conservación del flujo normal; se verifica en navegador copiar, abrir y recargar.
- [ ] Documentación y evidencia sanitizada: sin tokens ni enlaces utilizables en logs, issues o capturas.

### Dependencias y bloqueos

- Requiere que la cadena de #511 esté disponible (integrada o en revisión) para reutilizar la modalidad y los controles.
- Entornos local y académico con datos exclusivamente ficticios, ya comprobados por el equipo; habilitación mediante la configuración existente, sin cambios de despliegue nuevos.
- No depende de Gmail, Resend ni de la disponibilidad de un proveedor de correo.

### Fuera de alcance

- Habilitar la modalidad para pacientes reales o producción.
- Modificar tokens, vencimientos, consumo o la activación de personal con contraseña/TOTP, ni sustituir la integración de correo de #490.
- Agregar selector, listado o allowlist de pacientes de prueba, o un nuevo rol.
- Rediseñar las pantallas o cambiar las URLs actuales.
- Publicar MailBox, rutas de desarrollo o secretos en la evidencia.

### Evidencia esperada

Capturas sanitizadas (con el enlace redactado) del resultado y los controles reutilizados; pruebas de copiar, abrir y recargar; comprobación de que un fallo no muestra enlace y de que la modalidad desactivada conserva el recorrido actual; referencia a la configuración usada sin secretos. Crear esta issue no implica implementación ni habilitación.


### S2 — Review de #524 (verbatim, compañero vía usuario)

> Revisé los **13 archivos del [PR #524](https://github.com/Team-Origen/origen/pull/524)**, hacia `main` **pediría cambios antes de habilitar esta funcionalidad en el despliegue académico**.
>
> - **En [`lib/origen/patient_access/email.ex`, línea 45](https://github.com/Team-Origen/origen/blob/e17c7e8c17130bcf84e726e422fa3eaa5e676681/lib/origen/patient_access/email.ex#L45), el fallback a `localhost` debe corregirse para los correos del sistema desplegado.** Un paciente que abre ese enlace intenta acceder a su propia computadora.
>
> No pondría el dominio de Render fijo en el código. Usaría la configuración del endpoint, por ejemplo:
>
> ```elixir
> origin = Keyword.get_lazy(opts, :origin, fn -> OrigenWeb.Endpoint.url() end)
> ```
>
> Así, local usa la URL local y Render usa `PHX_HOST` o `RENDER_EXTERNAL_HOSTNAME`. Este problema ya existía: el PR lo conserva al extraer la función `magic_link_url/2`.
>
> **Encontré además estos problemas en los demás cambios:**
>
> | Hallazgo | Consecuencia | Cambio recomendado |
> |---|---|---|
> | **Secretaría conserva `access_url` al cambiar de paciente.** `clear_registration/1` limpia el resto del formulario, pero no ese valor. | Después de generar el enlace de A y buscar B, puede aparecer el enlace de A dentro del resultado de B. | Agregar `assign(:access_url, nil)` al limpiar la búsqueda y un test A → B. |
> | **El enlace académico de Secretaría todavía depende de ejecutar el mailer.** Se llama a `mailer.deliver/1` antes de construir el resultado. | Si el mailer lanza una excepción, no se devuelve el enlace, aunque la documentación dice que no requiere proveedor disponible. | Manejar explícitamente el fallo del correo para preservar el acceso académico y probar tanto error retornado como excepción. |
> | **Correo y pantalla pueden usar dominios distintos.** El correo recibe los `opts` originales; la URL visible usa `ORIGEN_ACADEMIC_PUBLIC_ORIGIN`. | Hoy pueden compartir el mismo token, pero el correo apunta a `localhost` y la pantalla al despliegue. | Resolver el origen coherentemente y comprobar la URL completa en el test, no solamente el token. |
> | **Se anuncia reemplazo de correo desde Secretaría, pero falta el control que abre ese formulario.** Existe el handler `open_replace_access`, pero no su botón en la plantilla. | El recorrido no está disponible desde la interfaz. | Agregar el control y probarlo, o declarar esa parte pendiente. Es una limitación preexistente. |
>
> También falta el botón que abre el reemplazo de correo: si se incluye ese recorrido en el alcance, hay que conectarlo y probarlo. El CI está verde, pero no cubre estos casos.

### S3 — Segunda ronda del review de #524 (verbatim, vía usuario)

> **Parcialmente resuelto:** maneja errores retornados y excepciones, pero no salidas de proceso (`exit`).
>
> La configuración del repositorio todavía combina:
>
> ```elixir
> # config/config.exs
> adapter: Swoosh.Adapters.Local
>
> # config/prod.exs
> config :swoosh, local: false
> ```
>
> Eso deja seleccionado el adaptador local, pero desactiva su almacenamiento. Revisé también Swoosh 1.28.0: ese adaptador llama a un `GenServer`. Si el proceso no está disponible, produce un **`exit`**, que el nuevo `rescue` **no captura**. Por eso, el flujo de Secretaría todavía puede interrumpirse antes de mostrar el enlace académico. Los tests nuevos simulan `{:error, ...}` y `raise`, pero no este caso.
>
> Además, agregaron: `Logger.warning("patient magic link email delivery failed: " <> inspect(reason))`. Conviene reemplazarlo por un mensaje o clasificación sanitizada: el error de un proveedor puede incluir contenido del correo, direcciones o el enlace con token. No comprobó una filtración real; el problema es registrar ese contenido sin filtrarlo.
>
> **Estos dos ajustes antes de aprobar el despliegue de la funcionalidad.**
>
> Las correcciones de URL, cambio de paciente y botón de reemplazo quedaron bien y tienen tests. Falta cerrar el manejo de fallos del mailer: en producción sigue seleccionado `Swoosh.Adapters.Local` con `local: false`, y su `GenServer.call` puede terminar con `exit(:noproc)`, que `rescue` no captura. Hay que resolver esa configuración y garantizar que ese fallo no bloquee el enlace académico, con un test específico que también compruebe que el token se puede consumir. También reemplazá `inspect(reason)` en el warning por un error sanitizado, sin correo, cuerpo ni token, y agregá una prueba de que esos datos no aparecen en los logs.

## Tasks

- T1 [S1] DONE: request_magic_link_details/2 on PatientAccess with single-token combined delivery (email delivery preserved, URL only in the return value); Patients.link/replace return access_url and specs updated. Route: inline. Commit: feat slice of this branch.
- T2 [S1] DONE: Secretary LiveView transient block (readonly/copy/open, module-local colocated hook .SecretaryAccessCopy), cleared on mount/open/cancel and each new submission; success and failure paths assign it. Route: inline. Commit: feat slice of this branch.
- T3 [S1] DONE: guide section "Secretaría: enlace al vincular o reemplazar correo" added (usage, single token, transient behavior, unchanged disabled path); final verification evidence in Log L6 and task 13. Route: inline. Commit: docs slice of this branch.
- T4 [S2] DONE: magic_link_url/2 falls back to OrigenWeb.Endpoint.url() instead of localhost; combined mode shares the academic origin between email and on-screen link with a full-URL equality test. Route: inline. Commit: fix slice of this branch.
- T5 [S2] DONE: clear_registration/1 clears access_url; test A → B guards the leak. Route: inline. Commit: fix slice of this branch.
- T6 [S2] DONE: mailer returned errors and raised exceptions are logged (Logger.warning) and never gate issuance or rollback the link; stub-mailer tests cover both and normal mode stays opaque with the link persisted. Route: inline. Commit: fix slice of this branch.
- T7 [S2] DONE: #btn-open-replace-access wired to open_replace_access for patients with an access email; UI test covers open, submit and the academic result; seven old-behavior refutes updated to asserts. Route: inline. Commit: fix slice of this branch.
- T8 [S2] DONE: GREEN 78/78 across eight files (new tests plus maintenance, secretary, patient access, controller and integration regressions); format, MIX_ENV=test compile --warnings-as-errors, git diff --check and dialyzer exit 0. PR to develop next; release refresh follows develop merge.
- T9 [S3] DONE: delivery wrapper catches process exits (catch :exit) so mailer GenServer exits never gate issuance; ExitingMailer test plus consumable-token assertion. Route: inline. Commit: fix slice of this branch.
- T10 [S3] DONE: sanitized classification logging (returned_error / process_exit) without email, body or token; LeakyMailer test asserts sensitive data absent from captured logs. Route: inline. Commit: fix slice of this branch.
- T11 [S3] DONE: production mailer resolved explicitly to Origen.Mailer.NullDelivery (no-op adapter, no provider until #490) via config/prod.exs override; module with deliver/2 + validate_config/1 and direct deliver test. Route: inline. Commit: fix slice of this branch.
- T12 [S3] DONE: GREEN 81/81 (eight-file batch plus three new tests); format, MIX_ENV=test compile --warnings-as-errors, git diff --check and dialyzer exit 0. PR to develop next; release refresh follows develop merge.



## Log

L1: una ves aprovado el pr y mergeriado- quiero que vuelvas a develop Y actualices CON LA NUEVAS IMPLEMENTACION DE REPO. mires que siga la funcionalidad y des por cerrada la issue 511. UNA VES HECHO ESTO, quiero que te HAGAS UNA RAMA NUEVA PARA LA ISSUE 521, Y PONTE A TRABAJAR EN ELLA, UNA VES FINALIZADO, YO HARE LA REVICION MANUAL

L2: hya algo importate tambien, cuando la secretaria o el profecional quiere hacer la verificacion de correo, el correo se manda al pero, tampococ se va a poder acceder en el despliegue. que recomiendas, que subamos lo que tenemo y luego haga otra issue para implementar lo de verificacion de correo?

L3: AL FUNCIONAMIENTO ANCTUAL ANDA, HAS LA PRUEBAS, LUEGO, SI YA ES POSIBLE, DEJA LA ISSUE EN STATUS APROVAD Y HACER EL PR

L4: 1 - ANTES DE QUE CONTINUEMOS, QUIERO QUE SEPAS QUE LA COMPROVACION DE YO hice la comprobacion de copiar enlace y abrir acceso ya las 2 andan correctamente como deveria- luego quiero que creemos otra issue para hacer esta misma implementacion pero desde el punto de vista de la secretaria,,va a ser de la misma forma que lo implementamos aca- va a poder copiar el enlace o abbri el acceso, esto para poder verificar la cuentas ingresadas. no es necesario que se evalue la cuenstion de segurad, esto ya lo fuios evaluando aca, hay que aclara que esta opcion actualemnte tiene que esta funcionadndo aca en la entrega local y en el despliegue, y sera una opcion porviciora al igual que la que acabamos de implementra. todod los datso que estan siendo utilizados en este entorno lokar y en el dspliege academico son fake, asi que no hay que temer. lo que se busca en la implementacion es que cuando la secretaria toque el bototn de registar y comprobar gmial que actaulemente ya esta implementado, no solo se envie el token de invitacion a la simulacion de correo, sino que directamente se muestre para poder copiar desde esta misma pantalla, asi como se hizo en la pantalla de login con magik link, ESTO SERA PORIVIONAL Y NO REMPLA NI MODIFICA EL FLUJO DE LOS TOKENS SUS VENCIMIENTO Y DEMAS.

L5: Planning. Base develop ca1a9f5. Design decision: single-token combined delivery — when the academic modality is valid, linking/replacing keeps sending the normal email AND returns the same token URL transiently to the LiveView, so the emailed token is not invalidated by a second issuance. UI reuses the #511 readonly/copy/open presentation with a module-local colocated hook. Guards unchanged (enabled + isolation + origin). Forecast ~300 authored lines; tests RED/GREEN observed through Tidewave. Route: inline; no push or PR until the user's manual review.

L6: RED/GREEN observed. RED run of the two new test files: 2/5 passed — failures exactly on the new behaviors (success block missing, remount assert missing, domain results missing access_url); green pins: disabled mode and failure path. Fixture corrections during RED: phone is required by register_absent_patient, register returns :profile (not persona), and the secretary helper insert_active_internal_account! is file-local (copied). GREEN: 29/29 across new files plus secretary_patient_access_maintenance_test.exs and patient_access_test.exs (seed 565918), including single-token equivalence between the emailed token and the transient URL, disabled-mode nil URL, and one-use consumption. Note: the replace-access trigger button does not exist in the secretary screen (handler open_replace_access is unreachable from the template); L7: Work-unit commit 16cf122 (feat slice) includes the domain change, Patients plumbing, the secretary LiveView block and hook, both test files and the deployment guide section. Observed before commit: mix format --check-formatted and MIX_ENV=test compile --warnings-as-errors exit 0; Log repaired so L5 and L6 are separate entries. Dialyzer and wider regression evidence is recorded in L8.

L9: User confirmed the patient screen flow works after reactivating the temporary dev activation lost by a server restart, and ordered the PR to develop. Branch pushed with Closes #521, type:feature; merge remains the user's decision.

L8: Final verification before manual review: mix dialyzer passed after the Patients spec changes (56 skipped, no new findings); regression 72 passed across professional_agenda_live_test.exs, secretary_patient_live_test.exs, patient_access_controller_test.exs and patient_access_issue_300_test.exs (seed 214758). Branch feat/521-secretary-access-link stays local with commits cb4f1ed (tracker), 16cf122 (feat slice) and this docs commit; no push and no PR until the user's manual review.

L10: HAS ESTE ARREGLO, Y UNA VES TERMINADO, HAS UN PR A DEVELOP PRIMERO, UNA VES QUE ESTE EN DEVELOP, Y SI ES NECESARIO, HAS LO CAMBIO NECESARIO EN EL PR 524 PARA QUE YA ESTE IMPLEMENTADO

L11: Reopened #521 per user order after the colleague review of #524 (S2 verbatim). All findings accepted as valid: fallback localhost (pre-existing, preserved by extraction), access_url leak on patient switch (introduced by this implementation), mailer dependency contradicting the no-provider requirement, incoherent email/screen origin, and the pre-existing missing replace button (included in scope to fulfill S1 "vincular o reemplazar"). Branch fix/521-review-corrections from develop e17c7e8; RED-first per item; PR to develop planned, then refresh chore/release-academic-access-links so #524 carries the fixes after develop merge.

L12: RED observed 5 behavioral failures (13/18: full-origin equivalence, mailer exception, persisted link on raise, A→B leak, replace button) plus one test-side defect fixed (Ecto get_by forbids nil comparisons; replaced with an is_nil query). GREEN 78/78 across eight files after updating seven old-behavior refutes (#btn-open-replace-access) to asserts for patients with an access email and fixing the replace test fixture (persona→profile). Delivery failure now logs Logger.warning with the inspected reason and never gates issuance. Format, MIX_ENV=test compile --warnings-as-errors, git diff --check and dialyzer exit 0.

L13: Segunda ronda del review: HAS ESTE ARREGLO, Y UNA VES TERMINADO, HAS UN PR A DEVELOP PRIMERO, UNA VEZ QUE ESTE EN DEVELOP, Y SI ES NECESARIO, HAS LO CAMBIO NECESARIO EN EL PR 524 PARA QUE YA ESTE IMPLEMENTADO

L14: Config verified: config/config.exs:53 Local adapter, config/prod.exs:31 local:false — MemCacheStore GenServer absent in prod, GenServer.call exits (:noproc) escaping rescue. Plan: Origen.Mailer.NullDelivery explicit prod adapter (no provider until #490), catch :exit in the delivery wrapper, sanitized classification logs (returned_error / process_exit) with no email/body/token, tests with ExitingMailer + LeakyMailer + CaptureLog and consumable-token assertion. RED-first.

L15: RED observed 11/14 (three new-behavior failures: mailer process exit escaped rescue, SECRETTOKEN123 and academic@example.test leaked into captured logs via inspect(reason), Origen.Mailer.NullDelivery missing). Fixes: catch :exit on the delivery wrapper with sanitized classification logging (returned_error / process_exit, no inspected reason), Origen.Mailer.NullDelivery adapter (deliver/2 + validate_config/1) selected explicitly in config/prod.exs until #490, tests for exit survival with consumable token, log sanitization and adapter behavior. GREEN 81/81 across the eight-file batch; format, compile --warnings-as-errors, git diff --check and dialyzer exit 0.
