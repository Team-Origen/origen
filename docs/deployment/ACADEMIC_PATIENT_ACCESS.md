# Acceso académico de pacientes ficticios (#511)

## Límite de seguridad

Esta modalidad permite ingresar a cualquier paciente registrado conociendo su correo.
**No verifica posesión del correo y no es autenticación válida para pacientes reales.**
Está desactivada por defecto. No habilitarla en el despliegue habitual ni en una base
que contenga datos reales, aunque se llame «beta». No requiere integrar #490 ni
reemplaza el envío normal de correo. No habilita rutas de desarrollo ni MailBox.

## Antes de habilitar (responsable del entorno)

Registrar en el acta de evaluación, sin secretos ni datos personales:

- Responsable, fecha e identificador del despliegue dedicado y de la base separada.
- Evidencia de que la conexión efectiva corresponde a esa base, no a producción.
- Confirmación del origen y revisión de los datos: exclusivamente ficticios,
  incluyendo pacientes, profesionales, turnos y registros relacionados. No copiar
  una base real. Si no se puede comprobar, **no habilitar**.
- Origen público HTTPS aprobado, certificado válido y proxy configurado.
- Correos de pacientes ficticios ya registrados por el recorrido existente.
- Proxy, APM y observabilidad configurados para no registrar query strings con
  credenciales. No capturar cuerpos de LiveView ni valores de campos de acceso.
  El filtrado de Phoenix no sustituye esta comprobación externa.

La aplicación exige una confirmación explícita, pero no puede demostrar mediante
una variable que una base esté aislada o no contenga datos reales.

## Configuración

Solo después de completar el acta, configurar en el despliegue dedicado:

```sh
ORIGEN_ACADEMIC_PATIENT_ACCESS_ENABLED=true
ORIGEN_ACADEMIC_ISOLATED_FICTIONAL_DATA_CONFIRMED=true
ORIGEN_ACADEMIC_PUBLIC_ORIGIN=https://evaluacion.example.org
```

Reiniciar la aplicación para cargar la configuración runtime. El origen debe ser
solo esquema HTTPS y nombre DNS público (puerto opcional), sin credenciales, ruta,
query ni fragmento; no se aceptan localhost, hosts numéricos ni literales IP. Debe coincidir con el origen público aprobado y la
configuración del endpoint. Una configuración incompleta o inválida no permite
mostrar enlaces y conserva el recorrido normal por correo. No usar estas variables
en el entorno con pacientes reales. No poner tokens en configuración.

## Desarrollo local con datos ficticios

Excepción autorizada para probar desde localhost: exclusivamente una compilación
`:dev`, con activación explícita y datos ficticios confirmados. No aplica a
compilaciones `:test` o `:prod`, aunque se configure la bandera local. No cambia
las rutas de desarrollo ni habilita MailBox.

Para conservar la activación al iniciar el servidor local:

```sh
ORIGEN_ACADEMIC_PATIENT_ACCESS_ENABLED=true \
ORIGEN_ACADEMIC_ISOLATED_FICTIONAL_DATA_CONFIRMED=true \
ORIGEN_ACADEMIC_LOCAL_PATIENT_ACCESS_ENABLED=true \
ORIGEN_ACADEMIC_PUBLIC_ORIGIN=http://localhost:4000 \
mix phx.server
```

El puerto debe coincidir con el servidor local. La excepción acepta únicamente
`localhost`, `127.0.0.1` o `::1` (IPv6 entre corchetes en la URL), por HTTP o HTTPS,
sin credenciales, rutas, query ni fragmento. No acepta dominios remotos por HTTP.
No alcanza con declarar la aplicación como `dev` en runtime: la restricción
se fija al compilar. El despliegue continúa requiriendo origen público HTTPS.

Si se habilita temporalmente sobre el servidor local ya iniciado, esa activación
no persiste tras reiniciar. Volver al formulario y enviar el correo de un paciente
ficticio registrado: el resultado debe decir «Acceso de evaluación académica».
Para desactivar, reiniciar sin las variables anteriores. No activar esta opción
si la base local contiene datos reales ni conecta a una base compartida real.

## Instrucciones para profesores

1. Abrir `https://<origen-aprobado>/paciente/acceso`.
2. Ingresar el correo de un paciente ficticio previamente registrado.
3. En el mismo resultado, usar **Copiar enlace** o **Abrir acceso**. No es necesario
   recibir un correo; la emisión académica no llama al proveedor.
4. El enlace mantiene el vencimiento existente de 15 minutos y uso único. Solicitar
   otro invalida los anteriores. No compartirlo ni incluirlo en capturas o informes.
5. Al recargar, volver al formulario o abandonar la pantalla, deja de mostrarse.
   No existe recuperación del token desde la base. Solicitar otro si es necesario.

Un correo desconocido no genera acceso, no crea pacientes ni vincula identidades.
Fuera de esta modalidad, se mantiene la respuesta pública no enumeradora y el envío
normal de correo, sin mostrar tokens.

## Comprobación y evidencia sanitizada

Antes de la demostración, comprobar en el navegador objetivo con pacientes ficticios:

- Copiar y pegar en un destino local no compartido: coincide con el campo; borrar
  luego el portapapeles. Verificar también la selección manual si no hay permiso.
- Abrir acceso: sesión del paciente esperado, HTTPS, uso único; repetir falla.
- Solicitar otro enlace: invalida el anterior; esperar vencimiento y comprobar rechazo.
- Recargar o volver al formulario: no aparece el enlace previo.
- Correo desconocido: ningún enlace ni alta. Proveedor de correo no disponible:
  la emisión académica sigue permitiendo acceso.
- Desactivar la modalidad: no aparece un enlace para ningún correo y se mantiene
  la misma confirmación pública para conocidos y desconocidos.

Redactar por completo el valor del campo y el query string en toda evidencia.
No guardar enlaces utilizables en logs, issues, videos, capturas ni reportes de tests.

## Desactivación

Quitar las tres variables (o poner ambas banderas en `false`) y reiniciar. Cerrar las
pestañas con resultados; la desactivación impide nuevas presentaciones, pero no revoca
por sí sola enlaces ya emitidos ni sesiones abiertas. Esperar el vencimiento de los
últimos enlaces y retirar el despliegue académico según el procedimiento operativo
aprobado. No reutilizar su base para pacientes reales.

## Estado de evidencia de esta implementación

- Rama independiente: `feat/511-academic-patient-magic-link`, desde `origin/develop`.
- Los archivos pendientes preexistentes se preservaron; #490 no se integró ni modificó.
- No se desplegó ni habilitó esta modalidad en ningún despliegue.
- Desarrollo local: el usuario confirmó «solo tine datos ficticios». Se habilitó
  temporalmente en el servidor `:dev` con origen `http://localhost:4000`; no persiste
  tras reiniciar. No se habilitó por defecto en el repositorio.
- Excepción local: prueba RED observada (3 de 4 aprobadas), luego GREEN
  (4 aprobadas) en el servidor de desarrollo mediante Tidewave. Falta comprobar el
  recorrido completo en navegador: no había navegador conectado a Tidewave.
- Pendiente: acta del entorno HTTPS/base aislada exclusivamente ficticia.
- Verificado: compilación con warnings como errores, formato y `git diff --check`.
- Verificado: prueba aislada de configuración sin base (1 test aprobado), con
  RED/GREEN observado y revalidación independiente del rechazo de loopback y URL
  malformada. La revisión independiente no sustituye las pruebas funcionales.
- Verificado en la reanudación: 35 pruebas focalizadas aprobadas (configuración,
  dominio, LiveView, controlador e integración), exit 0. El primer intento tuvo
  34/35 aprobadas por usar Floki, ausente en el proyecto; se corrigió el test a
  LazyHTML y se observó el resultado completo aprobado. La base de pruebas ya
  estuvo disponible; no se alteró la base de desarrollo para estas pruebas.
- Suite general inicial `mix test`: exit 2; 1102/1218 aprobadas, 116 fallidas,
  35 omitidas y 8 excluidas; 103 fallas de clave foránea `agenda_settings`.
- Diagnóstico aislado autorizado: `env -u ORIGEN_DATABASE_URL MIX_ENV=test
  MIX_TEST_PARTITION=_511_candidate_20261113 mix test --seed 511`: exit 0,
  **1218 aprobadas**, 35 omitidas y 8 excluidas. Los fallos anteriores no se
  reprodujeron con una base nueva y esta semilla; no se modificó código ajeno.
- Baseline `78f467a`: el primer intento no ejecutó tests (exit 1 por falta
  de contraseña). Reevaluación autorizada con las mismas credenciales locales
  de pruebas, configuración temporal privada y otra base nueva: **1206 aprobadas**,
  35 omitidas, 8 excluidas, exit 0, semilla 511. La configuración temporal fue
  eliminada al terminar. Ambos árboles pasan en bases nuevas; el fallo histórico
  es compatible con datos residuales en la base anterior, sin reproducción
  determinista en estos ensayos. No fue necesario modificar código ajeno.
- El usuario informó que el funcionamiento local actual anda; eso no documenta
  individualmente todas las comprobaciones de navegador.
- Pendiente: comprobación real de copiar/abrir/recargar en navegador; Tidewave
  informó que no había navegador conectado. La falta inicial de PostgreSQL quedó
  superada para las pruebas focalizadas.
