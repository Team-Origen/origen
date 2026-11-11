# Registro de decisiones de pantallas y navegación

Este documento registra lo conversado y aprobado durante el diseño de las navbars de [#369](https://github.com/Team-Origen/origen/issues/369). Es una referencia de diseño para el equipo, no un reglamento ni un menú definitivo: los accesos pueden evolucionar al implementar funcionalidades existentes o nuevas.

La [convención de URLs](URL_CONVENTIONS.md) sigue siendo la referencia canónica de rutas, compatibilidad e inventario. Este registro no la reemplaza, no concede permisos y no implementa pantallas, autenticación ni redirecciones productivas.

## Resumen de lo acordado

| Tema | Decisión registrada |
| --- | --- |
| Diseño visual | Se eligió la opción **B** del comparador: navbar con fondo azul petróleo. También se aprobó el borrador del Administrador con la misma estructura. |
| Distribución | Logo a la izquierda; accesos de navegación a la derecha y menú de usuario al extremo derecho. No se reabre aquí la elección o inclusión del logo. |
| Cantidad de ítems | Orientativamente tres o cuatro, sin forzar una cantidad fija ni inventar secciones para alcanzarla. Administrador tiene una sola sección. |
| Evolución | Las confirmaciones son una base de diseño, no congelan la navbar. Un ítem puede agregarse o reorganizarse si una funcionalidad lo necesita. Una pantalla nueva no implica automáticamente un ítem principal. |
| Cuenta y salida | «Cerrar sesión» queda dentro del menú desplegable, no como ítem principal ni como control inaccesible. En el prototipo la salida es simulada. |
| Implementación | La implementación productiva de navegación se contempla en [#371](https://github.com/Team-Origen/origen/issues/371), después de la migración de URLs de [#370](https://github.com/Team-Origen/origen/issues/370). El prototipo no sustituye esas entregas. |

## Pantallas iniciales aprobadas

Estos son los destinos predeterminados acordados después del ingreso. En la integración de #371 se implementan los destinos existentes y las alternativas transitorias de esta tabla. No reemplazan una navegación directa a otra URL autorizada.

| Rol | Pantalla inicial objetivo | URL prevista | Alternativa transitoria mientras no exista |
| --- | --- | --- | --- |
| Paciente | Mis turnos, después del acceso por magic link | `/paciente/turnos` | Reserva existente: `/patient/calendar`, o su destino `/paciente/turnos/reservar` cuando esté migrado. |
| Profesional | Agenda propia | `/profesional/agenda` | No requiere una pantalla alternativa. |
| Secretaría | Agenda | `/secretaria/agenda` | Pacientes, en `/secretaria/pacientes`. |
| Administrador | Cuentas, sin crear una pantalla de inicio adicional | `/administrador/cuentas` | Ubicación actual de la sección: `/admin/internal`. |

## Secciones y recorridos de referencia

Las tablas siguientes describen la base discutida y lo que permite evaluar el mock. No fijan exhaustivamente la organización futura de cada funcionalidad. El detalle de URLs actuales y previstas permanece en el inventario canónico.

### Paciente

Base propuesta y representada: **Mis turnos · Reservar turno**.

| Sección | Pantalla o recorrido de referencia | Situación |
| --- | --- | --- |
| Mis turnos | Consulta de turnos propios, estados, precio final y estado de pago; acceso a cancelación cuando corresponda. Desde allí se propone acceder a Reservar turno. | Pantalla pendiente, representada con datos ficticios. |
| Reservar turno | Recorrido existente de elección de Profesional, tipo de consulta y horario. El mock permite regresar a Mis turnos. | Reserva existente; el retorno a la futura lista es parte del borrador. |

No se propuso una sección independiente de pagos ni habilitar la autoedición del perfil bloqueado. El lugar de la verificación telefónica sigue pendiente: no se resolvió convirtiéndola en requisito para reservar. El botón de salida del mock no define el mecanismo real de cierre de sesión del Paciente.

### Profesional

El mock muestra **Agenda · Solicitudes · Resumen económico · Ajustes**. Se aprobó agregar únicamente el botón **Solicitudes**, con el mismo estilo de los otros ítems, que abre una vista del mock con el texto «Próximo en implementar». Esta última decisión reemplaza el estado deshabilitado considerado inicialmente; no define una pantalla ni URL productiva. No se toman decisiones de diseño funcional de #284/#323 dentro de esta planificación. Este acuerdo no congela el menú: la ubicación y el destino final se evaluarán con la implementación correspondiente.

| Sección | Pantalla o recorrido de referencia | Situación |
| --- | --- | --- |
| Agenda | Agenda propia → Crear turno → regreso a Agenda. La creación conserva Agenda como sección activa. | Recorrido existente, representado de forma simplificada. |
| Solicitudes | Acceso a pendientes y resolución por el Profesional dueño, según [#284](https://github.com/Team-Origen/origen/issues/284) y su frontend [#323](https://github.com/Team-Origen/origen/issues/323). | Acceso a un marcador del mock: «Próximo en implementar». Pantalla funcional y URL productiva no definidas por este registro; se resolverán con las issues correspondientes. |
| Resumen económico | Consulta del resumen propio por período. | Pendiente de [#288](https://github.com/Team-Origen/origen/issues/288); vista ficticia en el mock. |
| Ajustes | Ajustes → Mi perfil → regreso a Ajustes. Mi perfil pertenece a Ajustes y no necesita un ítem propio. Agenda y Ajustes quedan accesibles desde la navbar. | Recorrido de perfil existente; configuración de aprobación de #284 todavía no representada en el mock. |

El ejemplo previo de Agenda conserva una solicitud con «Resolver solicitud», pero la acción sólo da feedback. La decisión posterior fue limitar la incorporación a la navbar: no diseñar aquí lista de pendientes, configuración automática/manual, regla de Secretaría ni acciones de aceptar/rechazar. Esos recorridos pertenecen a #284/#323 y al contrato de [#321](https://github.com/Team-Origen/origen/issues/321); completarlos no es una condición añadida para terminar el diseño de la navbar. No se deduce una URL nueva del botón.

### Secretaría

Base propuesta y representada: **Agenda · Pacientes · Resumen económico**.

| Sección | Pantalla o recorrido de referencia | Situación |
| --- | --- | --- |
| Agenda | Selección de Profesional dentro de la pantalla. La acción propuesta «Agendar paciente» lleva a Pacientes para reutilizar la reserva asistida. | Agenda y conexión propuestas, no implementadas en producción. |
| Pacientes | Búsqueda, registro, gestión del acceso por correo y reserva asistida dentro del recorrido existente. | Pantalla existente; acciones ficticias en el mock. |
| Resumen económico | Selección de un Profesional por vez dentro de la sección. | Pantalla pendiente de #288; datos ficticios en el mock. |

El borrador no agrega una sección independiente «Profesionales», una ruta `/secretaria/agenda/crear` ni una segunda reserva asistida. La selección vive dentro de Agenda y Resumen; el recorrido productivo final sigue pendiente. Secretaría puede observar solicitudes, pero aceptar o rechazar corresponde sólo al Profesional dueño. No se incluyeron ajustes profesionales ni administración de cuentas para este rol.

### Administrador

Borrador textual y visual aprobado: **Cuentas**, con **Cerrar sesión** dentro del menú de usuario. No se forzaron más ítems.

| Dentro de Cuentas | Referencia para el borrador |
| --- | --- |
| Crear cuenta / emitir invitación | Representa la pantalla existente para cuentas de Profesional y Secretaría. |
| Editar cuenta, incluido correo | Acción prevista en [#279](https://github.com/Team-Origen/origen/issues/279), ilustrada sin guardar cambios. |
| Desactivar | Se muestra un contador ficticio de turnos futuros afectados. #279 contempla cortar acceso y nuevas reservas, preservando historia y turnos existentes, sin cancelarlos automáticamente. |
| Reactivar | Se ilustra la acción sin restaurar turnos cancelados. |

Las acciones se agruparon dentro de Cuentas para evaluar la navbar; no se acordaron URLs independientes por acción. El Administrador no recibe accesos a pacientes, agendas, pagos, resumen económico ni ajustes profesionales. El contador de afectados no expone pacientes o detalles de agendas.

## Comportamiento de navegación conversado

Se aprobó conservar el comportamiento existente al abrir URLs directamente, recargar y usar Atrás/Adelante, incluyendo parámetros, sesión y autorización. No se busca forzar el regreso al inicio del rol ni agregar filtros a URLs que hoy no los tienen; Agenda profesional conserva `date`.

Para los usuarios internos, la referencia existente de cierre de sesión es `POST /logout`, con retorno a `/login`. La ubicación visual elegida es el menú de usuario. El mock no ejecuta esa operación ni verifica terminación de sesiones. No se equipara el acceso por magic link del Paciente con el ingreso interno.

El destino del logo se dejó sin definir en esta etapa porque el usuario indicó que no era necesario resolverlo. El enlace de inicio presente en el prototipo es una facilidad de demostración, no una decisión productiva aprobada. Este punto sigue abierto respecto del criterio correspondiente de #369.

## Integración productiva de la navbar (#371)

La implementación conecta únicamente las pantallas ya existentes; no traslada las vistas ficticias del prototipo al producto ni implementa funcionalidades pendientes. La navbar permanece visible en el borde superior durante el desplazamiento, en el flujo del documento para no superponer el contenido.

| Rol | Enlaces reales | Botones con aviso «Próximo en implementar» |
| --- | --- | --- |
| Paciente | Reservar turno → `/paciente/turnos/reservar` | Mis turnos |
| Profesional | Agenda → `/profesional/agenda`; Ajustes → `/profesional/ajustes` | Solicitudes; Resumen económico |
| Secretaría | Pacientes → `/secretaria/pacientes` | Agenda; Resumen económico |
| Administrador | Cuentas → `/administrador/cuentas` | Ninguno |

Los botones pendientes muestran solamente un aviso descartable, sin navegación, datos simulados ni rutas nuevas. Crear turno conserva Agenda como sección activa y Mi perfil conserva Ajustes. La verificación telefónica del Paciente también incluye la navbar, sin introducir un requisito de reserva ni una sección principal adicional.

El logo aprobado para fondos oscuros se integra sobre azul petróleo usando `priv/static/images/origen-logo-dark.png`, ya entregado en #274/#411 mediante el PR #416. La marca permanece sin enlace: no se inventa un destino mientras siga sin acordarse. Esto no declara resuelto el criterio pendiente del destino del logo.

«Cerrar sesión» se presenta en el menú «Mi cuenta» para usuarios internos y envía el formulario existente a `POST /logout` con CSRF. La discrepancia preexistente que permite a Secretaría abrir Cuentas no se corrige ni se convierte en un enlace de su menú; en esa pantalla se conserva la navegación de Secretaría.

La aclaración posterior del usuario para #371 incorpora el menú del Paciente con nombre, apellido y correo, sin DNI ni teléfono. Su acción «Cerrar sesión» utiliza `POST /paciente/cerrar-sesion`, protegido por CSRF, elimina sólo su autenticación del navegador y vuelve a `/paciente/acceso`; no termina una sesión interna coexistente. No agrega revocación global de cookies ni desconexión de otras pestañas ya conectadas. Al ingresar mediante magic link se abre la pantalla real `/paciente/turnos/reservar`, mientras Mis turnos continúa pendiente. Estas decisiones productivas posteriores sustituyen la ausencia de definición del flujo del Paciente en el mock; no implementan pantallas ficticias ni cambian permisos.

El menú del Profesional utiliza su nombre y apellido reales, avatar de iniciales y etiqueta «Profesional», siguiendo la composición del borrador #369. El desplegable muestra el correo de su propia cuenta y conserva el cierre de sesión interno. Los datos se obtienen con la sesión del Profesional revalidada, nunca desde un identificador enviado por el cliente; no se muestra la matrícula. Si aún no guardó su nombre, la etiqueta es «Profesional», sin datos ficticios. Al guardar Mi perfil, el nombre de la navbar se actualiza de inmediato. Mi perfil continúa dentro de Ajustes, sin convertirse en una sección principal adicional.

Paciente y Secretaría reutilizan la misma composición del botón de cuenta que el Profesional: avatar de iniciales, nombre o etiqueta disponible y rol. Paciente utiliza su nombre real y la etiqueta «Paciente». La cuenta de Secretaría sólo almacena correo y rol: muestra «Secretaría» con inicial «S» y su correo real en el desplegable, sin inventar nombre ni agregar campos de perfil. Ese correo se obtiene exclusivamente desde su sesión interna revalidada, también al abrir la pantalla de Cuentas a la que conserva acceso preexistente; un usuario sintético sin sesión válida no se usa para recuperar datos de una cuenta. El texto del desplegable sigue negro y los mecanismos de salida no cambian.

El acceso a Agenda se conserva en la navbar compartida; se elimina el antiguo botón deshabilitado «Volver a Agenda» del contenido de Ajustes para no duplicar esa navegación.

Después del login interno exitoso, el rol de la sesión autenticada determina el destino: Profesional → `/profesional/agenda`; Secretaría → `/secretaria/pacientes` (su Agenda sigue pendiente); Administrador → `/administrador/cuentas`. No se toman el rol ni el destino desde parámetros del formulario. La portada `/` y el acceso directo a URLs autorizadas permanecen disponibles sin cambios; no se crean pantallas de inicio ni destinos ficticios. El ingreso del Paciente por magic link conserva la alternativa real `/paciente/turnos/reservar` mientras Mis turnos esté pendiente.

## Prototipo y mapa de referencia

El [prototipo aislado](../../prototypes/navigation/README.md) permite cambiar de rol y recorrer vistas con datos ficticios sin iniciar sesión. El selector de rol y el comparador inferior son herramientas del prototipo, no elementos del producto.

Con el servidor local iniciado según su README:

- [Paciente · diseño B](http://localhost:4173/prototypes/navigation/?variant=B#role=paciente&page=turns).
- [Profesional · diseño B](http://localhost:4173/prototypes/navigation/?variant=B#role=profesional&page=agenda).
- [Secretaría · diseño B](http://localhost:4173/prototypes/navigation/?variant=B#role=secretaria&page=agenda).
- [Administrador · diseño B](http://localhost:4173/prototypes/navigation/?variant=B#role=administrador&page=accounts).

Estos enlaces son locales: no constituyen un despliegue público ni estarán disponibles sin el servidor. La base de rutas y permisos se relevó desde el código; los enlaces propuestos se distinguen de los existentes.

También se creó el archivo editable `Origen - Mapa de navegacion actual y Sprint 4.excalidraw`, en la carpeta local indicada por el usuario. Ese mapa refleja el relevamiento inicial, no se sincroniza automáticamente con decisiones posteriores y no reemplaza el registro actual.

## Pendientes y límites de este registro

- Definir con las funcionalidades correspondientes si Solicitudes necesita una pantalla independiente, su URL y su acceso final. El mock de navbar no completa #284/#323 ni sus pruebas.
- Concretar los recorridos productivos de las pantallas pendientes, incluida la relación entre Agenda de Secretaría y la reserva asistida, sin duplicarla.
- Mantener explícitos los pendientes del inventario de URLs: verificación telefónica, compatibilidad de magic links/activaciones y discrepancia del acceso actual de Secretaría a cuentas internas. El prototipo no corrige ni aprueba permisos nuevos.
- El destino del logo quedó sin resolver; este registro no declara satisfecho ese criterio de #369 ni cierra la issue.
- Las comprobaciones realizadas sobre el mock cubrieron sintaxis, selección de estados, eventos con DOM simulado y carga local. La apariencia, foco nativo, zoom y funcionamiento real en navegador no fueron verificados por el agente. La aprobación visual del usuario no equivale a una prueba funcional productiva.
- Las decisiones aquí registradas provienen de la conversación. No fueron publicadas en GitHub ni notificadas al equipo mediante comentarios en #369/#371.

El diseño de la navbar y las vistas de ejemplo sirve para orientar la siguiente implementación. No representa la entrega de las funciones pendientes de Sprint 3 o Sprint 4 ni habilita por sí mismo su cierre.
