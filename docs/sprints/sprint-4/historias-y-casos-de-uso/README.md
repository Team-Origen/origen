# Documentación del sistema Origen

Descripción del sistema de gestión de turnos Origen mediante su diagrama de casos de uso, sus historias de usuario y su modelo de datos. Es la fuente versionada del documento Word que se presenta en la materia (issue #466).

Origen es una aplicación web para centros de salud que permite a los pacientes reservar y gestionar sus turnos, a los profesionales administrar su agenda y sus solicitudes, a la secretaría operar las agendas del centro y al administrador gestionar las cuentas del personal.

- **Administrador:** gestiona las cuentas de profesionales y secretarias (alta, invitación, modificación, baja y reactivación).
- **Profesional:** configura su perfil y su agenda, resuelve solicitudes de turno, agenda pacientes y registra la asistencia.
- **Secretaria:** registra pacientes, reserva turnos en cualquier agenda del centro, cancela turnos y registra la asistencia.
- **Paciente:** ingresa con un enlace enviado a su correo, reserva turnos, consulta su historial y cancela sus turnos.

## Contenido

| Archivo | Contenido |
| --- | --- |
| [casos-de-uso.md](./casos-de-uso.md) | Diagrama de casos de uso. |
| [historias-de-usuario.md](./historias-de-usuario.md) | Escala de estimación e historias de usuario por módulo. |
| [modelo-de-datos.md](./modelo-de-datos.md) | Diagrama entidad-relación de la base de datos. |

Los diagramas están en SVG ([casos de uso](./diagrama-casos-de-uso.svg), [entidad-relación](./diagrama-entidad-relacion.svg)) y se pueden abrir en el navegador o insertar en el documento Word.
