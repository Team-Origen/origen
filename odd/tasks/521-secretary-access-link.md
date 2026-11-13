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


## Tasks

- T1 [S1] DONE: request_magic_link_details/2 on PatientAccess with single-token combined delivery (email delivery preserved, URL only in the return value); Patients.link/replace return access_url and specs updated. Route: inline. Commit: feat slice of this branch.
- T2 [S1] DONE: Secretary LiveView transient block (readonly/copy/open, module-local colocated hook .SecretaryAccessCopy), cleared on mount/open/cancel and each new submission; success and failure paths assign it. Route: inline. Commit: feat slice of this branch.
- T3 [S1] DONE: guide section "Secretaría: enlace al vincular o reemplazar correo" added (usage, single token, transient behavior, unchanged disabled path); final verification evidence in Log L6 and task 13. Route: inline. Commit: docs slice of this branch.

## Log

L1: una ves aprovado el pr y mergeriado- quiero que vuelvas a develop Y actualices CON LA NUEVAS IMPLEMENTACION DE REPO. mires que siga la funcionalidad y des por cerrada la issue 511. UNA VES HECHO ESTO, quiero que te HAGAS UNA RAMA NUEVA PARA LA ISSUE 521, Y PONTE A TRABAJAR EN ELLA, UNA VES FINALIZADO, YO HARE LA REVICION MANUAL

L2: hya algo importate tambien, cuando la secretaria o el profecional quiere hacer la verificacion de correo, el correo se manda al pero, tampococ se va a poder acceder en el despliegue. que recomiendas, que subamos lo que tenemo y luego haga otra issue para implementar lo de verificacion de correo?

L3: AL FUNCIONAMIENTO ANCTUAL ANDA, HAS LA PRUEBAS, LUEGO, SI YA ES POSIBLE, DEJA LA ISSUE EN STATUS APROVAD Y HACER EL PR

L4: 1 - ANTES DE QUE CONTINUEMOS, QUIERO QUE SEPAS QUE LA COMPROVACION DE YO hice la comprobacion de copiar enlace y abrir acceso ya las 2 andan correctamente como deveria- luego quiero que creemos otra issue para hacer esta misma implementacion pero desde el punto de vista de la secretaria,,va a ser de la misma forma que lo implementamos aca- va a poder copiar el enlace o abbri el acceso, esto para poder verificar la cuentas ingresadas. no es necesario que se evalue la cuenstion de segurad, esto ya lo fuios evaluando aca, hay que aclara que esta opcion actualemnte tiene que esta funcionadndo aca en la entrega local y en el despliegue, y sera una opcion porviciora al igual que la que acabamos de implementra. todod los datso que estan siendo utilizados en este entorno lokar y en el dspliege academico son fake, asi que no hay que temer. lo que se busca en la implementacion es que cuando la secretaria toque el bototn de registar y comprobar gmial que actaulemente ya esta implementado, no solo se envie el token de invitacion a la simulacion de correo, sino que directamente se muestre para poder copiar desde esta misma pantalla, asi como se hizo en la pantalla de login con magik link, ESTO SERA PORIVIONAL Y NO REMPLA NI MODIFICA EL FLUJO DE LOS TOKENS SUS VENCIMIENTO Y DEMAS.

L5: Planning. Base develop ca1a9f5. Design decision: single-token combined delivery — when the academic modality is valid, linking/replacing keeps sending the normal email AND returns the same token URL transiently to the LiveView, so the emailed token is not invalidated by a second issuance. UI reuses the #511 readonly/copy/open presentation with a module-local colocated hook. Guards unchanged (enabled + isolation + origin). Forecast ~300 authored lines; tests RED/GREEN observed through Tidewave. Route: inline; no push or PR until the user's manual review.

L6: RED/GREEN observed. RED run of the two new test files: 2/5 passed — failures exactly on the new behaviors (success block missing, remount assert missing, domain results missing access_url); green pins: disabled mode and failure path. Fixture corrections during RED: phone is required by register_absent_patient, register returns :profile (not persona), and the secretary helper insert_active_internal_account! is file-local (copied). GREEN: 29/29 across new files plus secretary_patient_access_maintenance_test.exs and patient_access_test.exs (seed 565918), including single-token equivalence between the emailed token and the transient URL, disabled-mode nil URL, and one-use consumption. Note: the replace-access trigger button does not exist in the secretary screen (handler open_replace_access is unreachable from the template); L7: Work-unit commit 16cf122 (feat slice) includes the domain change, Patients plumbing, the secretary LiveView block and hook, both test files and the deployment guide section. Observed before commit: mix format --check-formatted and MIX_ENV=test compile --warnings-as-errors exit 0; Log repaired so L5 and L6 are separate entries. Dialyzer and wider regression evidence is recorded in L8.

L8: Final verification before manual review: mix dialyzer passed after the Patients spec changes (56 skipped, no new findings); regression 72 passed across professional_agenda_live_test.exs, secretary_patient_live_test.exs, patient_access_controller_test.exs and patient_access_issue_300_test.exs (seed 214758). Branch feat/521-secretary-access-link stays local with commits cb4f1ed (tracker), 16cf122 (feat slice) and this docs commit; no push and no PR until the user's manual review.
