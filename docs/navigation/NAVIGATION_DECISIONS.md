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

Estos son destinos predeterminados después del ingreso. No reemplazan una navegación directa a otra URL autorizada ni significan que las redirecciones ya estén implementadas.

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

El mock actual muestra **Agenda · Resumen económico · Ajustes**. Durante la conversación se confirmó contemplar **Solicitudes** como cuarto acceso, con orden de referencia **Agenda · Solicitudes · Resumen económico · Ajustes**. Después se aclaró que este acuerdo no congela el menú: la necesidad y ubicación final se evaluarán con la implementación funcional.

| Sección | Pantalla o recorrido de referencia | Situación |
| --- | --- | --- |
| Agenda | Agenda propia → Crear turno → regreso a Agenda. La creación conserva Agenda como sección activa. | Recorrido existente, representado de forma simplificada. |
| Solicitudes | Acceso a pendientes y resolución por el Profesional dueño, según [#284](https://github.com/Team-Origen/origen/issues/284) y su frontend [#323](https://github.com/Team-Origen/origen/issues/323). | Ítem contemplado para #371; todavía no incorporado al mock. Pantalla independiente y URL no definidas por este registro. |
| Resumen económico | Consulta del resumen propio por período. | Pendiente de [#288](https://github.com/Team-Origen/origen/issues/288); vista ficticia en el mock. |
| Ajustes | Ajustes → Mi perfil → regreso a Ajustes. Mi perfil pertenece a Ajustes y no necesita un ítem propio. Agenda y Ajustes quedan accesibles desde la navbar. | Recorrido de perfil existente; configuración de aprobación de #284 todavía no representada en el mock. |

El mock muestra una solicitud con «Resolver solicitud», pero la acción sólo da feedback. No demuestra la cobertura de #323: falta representar configuración automática/manual, regla para reservas de Secretaría, lista de pendientes, aceptar/rechazar, estados y errores. Su diseño funcional debe coordinarse con el contrato de [#321](https://github.com/Team-Origen/origen/issues/321). No se deduce una URL nueva del acuerdo sobre la navbar.

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
