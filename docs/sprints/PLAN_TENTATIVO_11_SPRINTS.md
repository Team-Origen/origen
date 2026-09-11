# Plan tentativo revisado: primera reserva autónoma en dos semanas

> **Borrador local para ordenar la lista de trabajo pendiente.** Esta revisión reemplaza los identificadores y supuestos del borrador local anterior. No afirma que existan tareas en GitHub, no asigna estados reales y no autoriza publicación, implementación, creación inicial de cuentas ni uso de datos reales.

## 1. Resultado que queremos demostrar

El recorrido principal es corto y atraviesa el sistema completo:

1. Un Profesional activo configura un tipo de consulta y su disponibilidad regular.
2. Un Paciente entra de forma segura sin contraseña, completa su perfil y verifica el teléfono requerido.
3. Ese Paciente reserva **su primera cita**, aunque todavía no tenga relación con el Profesional.
4. La reserva válida se guarda con sus copias históricas de horario, duración y precio.
5. El Profesional ve el turno solamente en su propia agenda.

La ayuda de Secretaría es un camino alternativo para quien no puede usar el sitio; **no es una condición previa** para la reserva autónoma. Secretaría crea o reutiliza la Persona y el perfil de Paciente y realiza la reserva mediante la misma operación de turnos, con permisos diferentes.

La corrección acordada ya se aplicó directamente a RF-05 y a la matriz de autorización: un Paciente autenticado y listo puede reservar su primera cita sin Secretaría ni relación previa. Esta corrección documental no es una tarea futura de GitHub y no requiere una tarea o subtarea de reemplazo.

## 2. Límites que no se negocian para la demo

- Persona, cuenta de acceso y perfiles son conceptos distintos. Una Persona puede tener más de un rol sin duplicarse.
- La demo usa solo el perfil propio del Paciente. La representación de otro Paciente queda para una etapa futura.
- No se omiten la preparación del perfil, el teléfono verificado, la privacidad ni la disponibilidad real.
- **Decidido:** el **enlace de acceso por correo** es el único método sin contraseña de esta etapa; Google OAuth queda postergado y no se implementa ahora.
- **Decidido:** el canal de correo de desarrollo es el buzón local de Swoosh (`Swoosh.Adapters.Local`, visible en `/dev/mailbox`), sin credenciales ni proveedor real. El validador fail-closed `Origen.BootstrapAdmin.DeliveryConfig` **no se relaja** para permitir `Local` ni `Test`: sigue prohibiéndolos para entrega real, y la demo usa un camino de desarrollo separado.
- **Decidido:** el código de verificación telefónica de desarrollo viaja por ese mismo buzón local. Se almacena únicamente su hash, con vencimiento, un solo uso y límite de intentos; la auditoría registra envío, validación y cada fallo sin guardar el código ni el número completo. No se usan códigos fijos hardcodeados en el dominio ni paneles que muestren el secreto en la interfaz.
- Postergar WhatsApp no permite postergar la verificación obligatoria del teléfono. `PLN-15` entrega y prueba ese flujo, aunque todavía no haya recordatorios.
- La agenda del Profesional es privada. El servidor obtiene el alcance desde la identidad autenticada, no desde un identificador enviado por la pantalla.
- Tipo, duración, precio y horario se validan al reservar; nombre, duración y dinero se guardan como copias históricas válidas. El dinero no usa decimales imprecisos.
- La relación Profesional–Paciente nace únicamente cuando se almacena con éxito una primera reserva válida. Nunca nace por mirar, hacer clic, iniciar sesión ni enviar una solicitud fallida o denegada.
- **Decidido:** una solicitud en estado `Solicitado` todavía no es una reserva válida. La relación y la entrada en la lista permitida nacen cuando esa solicitud se **aprueba** y se persiste el turno, no cuando se crea. Un rechazo no deja relación ni visibilidad: deja solo el evento auditado.
- La primera reserva, su relación, sus copias históricas y su auditoría se guardan en una transacción: todo o nada. La misma operación de reserva sirve a todos los roles; cambian la autorización y las reglas de entrada, no el núcleo.
- **Decidido:** los perfiles profesionales de la demo usan **aprobación automática** para reservas antes de D-1. D-1 es el día anterior: para una cita del viernes, el jueves es D-1. Según RF-10, esa reserva autónoma inicial nace **Reservado**, no Confirmado, y `Reservado` es el estado final visible de la demo. Secretaría puede elegir Reservado o Confirmado antes de D-1 y debe usar Confirmado durante D-1; el Profesional solo opera sobre Pacientes propios y sigue sus reglas por fecha.
- **Decidido:** como no hay WhatsApp en esta etapa, no existen mensajes D-2/D-1 ni evidencia de `delivered`. Por lo tanto la cancelación automática de RF-16 a las 18:00 de D-1 **queda fuera del alcance de la demo** y no se implementa; un turno `Reservado` no se cancela solo. La interfaz de aprobación manual y el ciclo completo de solicitudes rechazadas quedan para el sprint correspondiente del roadmap.
- **Decidido:** el rechazo de una solicitud manual se representa con el estado `Cancelado` más motivo obligatorio, actor y fecha, sin multa. No se agrega un estado `Rechazado` a la máquina de RF-14.
- No se usan secretos sembrados, selector libre de rol, seguridad desactivada ni datos reales del cliente.

## 3. Capacidad y corte honesto

Los cuatro estudiantes confirmaron al menos 20 h por semana cada uno. Para dos semanas:

- capacidad bruta: `4 × 20 × 2 = 160 h-equipo`;
- presupuesto objetivo de trabajo: **128 h**;
- reserva para bloqueos y correcciones no previstos: **32 h**. La integración planificada, la revisión de cada tarea y el ensayo ya están dentro de las estimaciones. Esta reserva **ya no está libre**: al comprometer `PLN-12` y `PLN-13` dentro de Sprint 1, el detalle comprometido la consume (secciones 3.2 y 6).

La antigua regla histórica de 64 h no es el límite de este horizonte. El borrador anterior de 128 h tampoco incluía acceso y reserva del Paciente, por lo que no se conserva su estimación artificialmente.

### 3.1 Reestimación tras resolver las decisiones de la sección 8

Resolver las decisiones permitió bajar cinco estimaciones, porque parte del trabajo ya existe en el repositorio: la mix task `origen.bootstrap_admin` con su flujo de invitación y activación, `authorization/rules`, `audit`, `nimble_totp`, `cloak_ecto` y el stack de correo Swoosh con buzón local.

| Tarea | Rango anterior | Rango vigente | Motivo |
| --- | ---: | ---: | --- |
| `PLN-02` | 10–16 h | **6–8 h** | La mix task de bootstrap ya está implementada y testeada; queda documentar y verificar las cuatro cuentas locales. |
| `PLN-03` | 14–22 h | **10–16 h** | Reglas de autorización, auditoría, TOTP y cifrado ya existen; falta la sesión web. |
| `PLN-05` | 18–28 h | **16–24 h** | El canal de correo y la disciplina de redaction ya existen; el dominio del perfil es nuevo. |
| `PLN-08` | 18–28 h | **18–26 h** | Sigue siendo el trabajo más nuevo: transacción, concurrencia, snapshots, relación y auditoría. No se recorta. |
| `PLN-15` | 10–16 h | **10–16 h** | Sin cambio: el flujo de verificación es nuevo por completo. |

### 3.2 Alcance comprometido y sobre-compromiso explícito

| Alcance | Rango vigente | Lectura |
| --- | ---: | --- |
| Núcleo de la demo (`PLN-02` a `PLN-11`, `PLN-14` y `PLN-15`) | **126–192 h** | En el extremo inferior entra apenas en las 128 h; en el superior las excede por 64 h. |
| Alternativa asistida (`PLN-12`) | **16–24 h** | Se mantiene dentro de Sprint 1 por decisión explícita, aunque el plan la marcaba condicional. |
| Reserva por Profesional (`PLN-13`) | **8–14 h** | Se mantiene dentro de Sprint 1 por decisión explícita, aunque el plan la marcaba como alcance adicional. |
| Total comprometido | **150–230 h** | Supera la capacidad bruta de 160 h en su extremo superior y consume la reserva de 32 h incluso en el inferior. |

**Registro honesto:** se decidió **no aplicar el corte** de `PLN-12` y `PLN-13`. Sprint 1 queda sobre-comprometido: 150–230 h de detalle contra 128 h de presupuesto objetivo y 160 h de capacidad bruta. La reserva de 32 h deja de estar disponible para bloqueos y pasa a estar comprometida por alcance.

**Consecuencia aceptada:** si durante el sprint el núcleo se acerca al extremo superior, el ajuste se hace reduciendo presentación visual y mostrando evidencia parcial, o moviendo `PLN-13` y luego `PLN-12` fuera del milestone. Nunca se resuelve quitando autenticación, autorización, verificación telefónica, privacidad de agenda, concurrencia, transacción ni auditoría.

## 4. Cuatro frentes desde el día 1

Los frentes pueden producir ejemplos y pantallas desde el primer día, pero eso no significa que estén terminados. Los contratos compartidos se escriben una vez y se integran temprano; no se espera al último día para unirlos.

| Frente | Responsable | Trabajo temprano independiente | Resultado del rol |
| --- | --- | --- | --- |
| **Administrador** | Lucca | tabla de permisos, estados de cuenta, ejemplos de invitación y sesión | camino autorizado para cuentas internas y controles compartidos |
| **Secretaría** | Said | casos de reutilización de Persona, errores de identidad y guion asistido | alternativa asistida comprometida en Sprint 1 (`PLN-12`); primera en salir si el núcleo se atrasa |
| **Profesional** | Santiago | bocetos de tipo, disponibilidad y agenda privada | configura agenda y ve sus turnos |
| **Paciente** | Samuel | ejemplos de Magic Link, perfil, teléfono y reserva | entra, completa datos y reserva su primera cita |

Lucca coordina contratos y partes compartidas, pero no “termina el servidor” antes que el resto. Said implementa el motor compartido de reservas: los frentes describen el foco de cada rol, no silos técnicos. Cada cambio pequeño se revisa e integra cuando su predecesor está listo.

## 5. Lista local de tareas lista para reconciliar

Todos los estados iniciales son **Propuesto / Por hacer**. Las horas incluyen implementación, pruebas y la revisión inmediata de cada tarea. El ensayo integrado de `PLN-14` sí tiene estimación propia. “Revisor” no implica aprobación ya realizada.

`PLN-12` y `PLN-13` conservan en su título las marcas históricas “condicional” y “alcance adicional”, y así están nombradas en GitHub, pero por decisión de la sección 8 **están comprometidas dentro de Sprint 1**. La reserva de 32 h deja de estar libre: el total comprometido la consume, según las secciones 3.2 y 6.

### `PLN-02` — Entregar cuentas locales seguras para desarrollo

- **Propósito/resultado:** documentar y verificar cómo cada integrante obtiene una cuenta local de Administrador y una base separada de producción, reutilizando el camino ya implementado.
- **Responsable / revisor / horas:** Lucca / Said / **6–8 h**.
- **Aceptación:** se reutiliza el procedimiento operativo existente (`mix origen.bootstrap_admin` con buzón local), sin crear una herramienta exclusiva de desarrollo ni un segundo camino de alta sin auditoría; usa datos ficticios; los cuatro integrantes pueden obtener la cuenta siguiendo la guía; no guarda secretos prearmados, no permite elegir rol y no desactiva controles. La configuración inicial real del cliente sigue fuera de alcance.
- **Predecesores:** ninguno.

### `PLN-03` — Autenticación y autorización compartidas

- **Propósito/resultado:** sesiones internas reforzadas y límites comunes para páginas y operaciones.
- **Responsable / revisor / horas:** Lucca / Samuel / **10–16 h**.
- **Aceptación:** cuentas internas Activas usan contraseña y TOTP (código temporal de una aplicación autenticadora); sesiones vencidas o roles ajenos se deniegan en el servidor; errores no revelan si una cuenta existe ni registran secretos.
- **Predecesores:** `PLN-02`.

### `PLN-04` — Crear y activar cuentas internas de la demo

- **Propósito/resultado:** un Administrador activo crea cuentas pendientes de Secretaría y Profesional; cada titular las activa por invitación.
- **Responsable / revisor / horas:** Lucca / Said / **10–16 h**.
- **Aceptación:** invitación vinculada, vencible y de un uso; contraseña y TOTP pertenecen al titular; no se supone bootstrap real ejecutado.
- **Predecesores:** `PLN-03`.

### `PLN-05` — Acceso sin contraseña y perfil propio del Paciente

- **Propósito/resultado:** acceso por Magic Link y preparación del perfil propio para reservar.
- **Responsable / revisor / horas:** Samuel / Lucca / **16–24 h**.
- **Aceptación:** enlace opaco, vencible, de un uso y respuesta no enumeradora, entregado por el buzón local de Swoosh sin registrar el enlace en logs ni auditoría; identidad documental no se duplica ni se vincula automáticamente por coincidencia; perfil incompleto no reserva; representación queda explícitamente fuera.
- **Predecesores:** `PLN-02`.

### `PLN-06` — Tipo de consulta con snapshot válido

- **Propósito/resultado:** el Profesional crea un tipo propio con nombre, duración y precio base.
- **Responsable / revisor / horas:** Santiago / Said / **8–12 h**.
- **Aceptación:** rechaza valores inválidos; otro Profesional no modifica el tipo; define la copia histórica que consumirá la reserva.
- **Predecesores:** `PLN-03`, `PLN-04`.

### `PLN-07` — Disponibilidad regular privada

- **Propósito/resultado:** el Profesional configura intervalos semanales y ventana reservable.
- **Responsable / revisor / horas:** Santiago / Lucca / **12–18 h**.
- **Aceptación:** intervalos inválidos o superpuestos fallan; se prueban zona horaria y bordes; nadie modifica disponibilidad ajena.
- **Predecesores:** `PLN-03`, `PLN-04`.

### `PLN-08` — Operación única y transaccional de reserva

- **Propósito/resultado:** crear el motor compartido de reserva para Paciente, Secretaría y Profesional, con reglas según actor y fecha.
- **Responsable / revisor / horas:** Said / Santiago / **18–26 h**.
- **Aceptación:** para autogestión exige perfil listo y `PLN-15` cumplido; Secretaría puede asistir a perfiles incompletos según RF-02; Profesional solo opera sobre Pacientes propios. Aplica RF-10: la propuesta acotada del Paciente usa aprobación automática antes de D-1 y nace Reservado; Secretaría y Profesional conservan sus estados por actor y fecha. Valida disponibilidad, evita superposiciones aun con pedidos simultáneos y guarda turno, relación aprobada, copias históricas y auditoría en una sola transacción.
- **Predecesores:** `PLN-05`, `PLN-06`, `PLN-07`, `PLN-15`.

### `PLN-09` — Calendario y reserva del Paciente

- **Propósito/resultado:** el Paciente ve solo horarios disponibles y reserva su primera cita.
- **Responsable / revisor / horas:** Samuel / Said / **10–16 h**.
- **Aceptación:** muestra contexto del perfil propio, estados vacío/error/éxito y política propuesta antes de confirmar; funciona con teclado y pantalla angosta; usa `PLN-08`, no datos simulados.
- **Predecesores:** `PLN-08`.

### `PLN-10` — Agenda diaria del Profesional

- **Propósito/resultado:** mostrar los turnos del Profesional autenticado.
- **Responsable / revisor / horas:** Santiago / Samuel / **6–10 h**.
- **Aceptación:** el servidor filtra por identidad; no expone agendas ajenas; muestra vacío y la reserva creada con horario, Paciente, tipo y estado.
- **Predecesores:** `PLN-03`, `PLN-08`.

### `PLN-11` — Pantalla mínima de administración interna

- **Propósito/resultado:** permitir el alta autorizada de cuentas de la demo sin ampliar permisos.
- **Responsable / revisor / horas:** Said / Lucca / **8–12 h**.
- **Aceptación:** solo Administrador puede crear Profesional o Secretaría; conserva errores útiles, teclado y foco; Secretaría no puede crear Profesionales.
- **Predecesores:** `PLN-04`.

### `PLN-12` — Alternativa asistida por Secretaría — condicional

- **Propósito/resultado:** Secretaría crea o reutiliza un Paciente que no puede usar el sitio y reserva por él.
- **Responsable / revisor / horas:** Said / Lucca / **16–24 h**.
- **Aceptación:** identidad mínima y unicidad documental; no fusiona coincidencias; usa `PLN-08`; registra actor y Paciente; no vuelve obligatoria esta vía para la primera reserva autónoma.
- **Predecesores:** `PLN-03`, `PLN-04`, `PLN-08`.

### `PLN-13` — Reserva del Profesional para Paciente propio — alcance adicional

- **Propósito/resultado:** preservar la regla de que un Profesional reserva únicamente para Pacientes ya relacionados.
- **Responsable / revisor / horas:** Santiago / Said / **8–14 h**.
- **Aceptación:** no navega el registro global; solo elige Pacientes propios; antes de D-1 crea Reservado mediante `PLN-08`; deniega cualquier Paciente ajeno.
- **Predecesores:** `PLN-08`, `PLN-10`.

### `PLN-14` — Integración temprana y ensayo seguro

- **Propósito/resultado:** integrar por incrementos y demostrar el recorrido principal con datos ficticios.
- **Responsable / revisor / horas:** Said / Santiago / **12–18 h**.
- **Aceptación:** hay integración comprobable antes del último día; se prueba teclado, pantalla angosta, denegaciones, concurrencia y reversión completa cuando falla una transacción; el ensayo muestra Profesional → Paciente → agenda sin datos ni servicios de producción.
- **Predecesores:** `PLN-09`, `PLN-10`, `PLN-11`.

### `PLN-15` — Verificar el teléfono del Paciente

- **Propósito/resultado:** entregar un flujo real de verificación del número requerido para la reserva autónoma, independiente de los recordatorios de WhatsApp.
- **Responsable / revisor / horas:** Samuel / Said / **10–16 h**.
- **Aceptación:** el canal de desarrollo es el buzón local de Swoosh y no se relaja `DeliveryConfig`; se almacena solo el hash del código; un desafío opaco y un código correctos verifican una sola vez la misma cuenta y número; códigos o desafíos incorrectos, vencidos, consumidos, reutilizados o fuera del límite de intentos fallan sin marcar el teléfono; reenvíos y resultados se auditan sin guardar código ni número completo.
- **Predecesores:** `PLN-02`, `PLN-05`.

## 6. Dependencias y carga por responsable

Cadena compartida principal:

```text
PLN-02 -> PLN-03 -> PLN-04
PLN-02 -> PLN-05 -> PLN-15
PLN-03 + PLN-04 -> PLN-06 + PLN-07
PLN-05 + PLN-06 + PLN-07 + PLN-15 -> PLN-08
PLN-08 -> PLN-09 + PLN-10 -> PLN-14
PLN-04 -> PLN-11 -> PLN-14
PLN-08 -> PLN-12 (dentro de Sprint 1)
PLN-08 + PLN-10 -> PLN-13 (dentro de Sprint 1)
```

Cargas recalculadas con las estimaciones vigentes de la sección 3.1. `PLN-12` y `PLN-13` ya no se tratan como alcance opcional: están comprometidas dentro de Sprint 1.

| Responsable | Núcleo | `PLN-12` / `PLN-13` | Total Sprint 1 |
| --- | ---: | ---: | ---: |
| Lucca | 26–40 h | — | 26–40 h |
| Said | 38–56 h | 16–24 h | 54–80 h |
| Santiago | 26–40 h | 8–14 h | 34–54 h |
| Samuel | 36–56 h | — | 36–56 h |
| **Total** | **126–192 h** | **24–38 h** | **150–230 h** |

La persona responsable no trabaja aislada: los frentes describen foco de rol, mientras revisión y colaboración ya están incluidas en los rangos de cada tarea.

<<<<<<< Updated upstream
**La reserva de 32 h ya no está libre.** Al comprometer `PLN-12` y `PLN-13` dentro de Sprint 1, el total comprometido (150–230 h) supera el presupuesto objetivo de 128 h y consume la reserva incluso en su extremo inferior. Cualquier bloqueo o corrección no prevista se absorbe entonces reduciendo presentación o moviendo esos dos alcances, según la sección 3.2.

=======
>>>>>>> Stashed changes
## 7. Tablero y jerarquía publicada en GitHub

Estados simples:

- **Por hacer:** propuesta todavía no lista o sin comenzar.
- **Bloqueada:** una decisión o tarea anterior impide avanzar.
- **En trabajo:** trabajo activo; una tarea principal por persona.
- **En revisión:** resultado completo esperando lectura y evidencia.
- **Terminada:** aceptación cumplida, integrada y revisada; no significa producción.

La jerarquía fue publicada como 14 issues padre y 45 subissues ejecutables. Los grupos Lucca, Said, Santiago y Samuel indican responsabilidad; no son issues adicionales. `PLN-01.1`, `PLN-01.2` y `PLN-01.3` no se recrearon porque sus reglas quedaron resueltas mediante [#33](https://github.com/Team-Origen/origen/issues/33) y el PR [#34](https://github.com/Team-Origen/origen/pull/34).

| ID local | Issue padre | Subissues publicadas |
| --- | --- | --- |
| `PLN-02` | [#35](https://github.com/Team-Origen/origen/issues/35) | [#49](https://github.com/Team-Origen/origen/issues/49), [#50](https://github.com/Team-Origen/origen/issues/50), [#51](https://github.com/Team-Origen/origen/issues/51) |
| `PLN-03` | [#36](https://github.com/Team-Origen/origen/issues/36) | [#52](https://github.com/Team-Origen/origen/issues/52), [#53](https://github.com/Team-Origen/origen/issues/53), [#54](https://github.com/Team-Origen/origen/issues/54) |
| `PLN-04` | [#37](https://github.com/Team-Origen/origen/issues/37) | [#55](https://github.com/Team-Origen/origen/issues/55), [#56](https://github.com/Team-Origen/origen/issues/56), [#57](https://github.com/Team-Origen/origen/issues/57) |
| `PLN-05` | [#38](https://github.com/Team-Origen/origen/issues/38) | [#85](https://github.com/Team-Origen/origen/issues/85), [#86](https://github.com/Team-Origen/origen/issues/86), [#87](https://github.com/Team-Origen/origen/issues/87) |
| `PLN-06` | [#39](https://github.com/Team-Origen/origen/issues/39) | [#73](https://github.com/Team-Origen/origen/issues/73), [#74](https://github.com/Team-Origen/origen/issues/74), [#75](https://github.com/Team-Origen/origen/issues/75) |
| `PLN-07` | [#40](https://github.com/Team-Origen/origen/issues/40) | [#76](https://github.com/Team-Origen/origen/issues/76), [#77](https://github.com/Team-Origen/origen/issues/77), [#78](https://github.com/Team-Origen/origen/issues/78) |
| `PLN-08` | [#41](https://github.com/Team-Origen/origen/issues/41) | [#61](https://github.com/Team-Origen/origen/issues/61), [#62](https://github.com/Team-Origen/origen/issues/62), [#63](https://github.com/Team-Origen/origen/issues/63), [#64](https://github.com/Team-Origen/origen/issues/64), [#65](https://github.com/Team-Origen/origen/issues/65), [#66](https://github.com/Team-Origen/origen/issues/66) |
| `PLN-09` | [#42](https://github.com/Team-Origen/origen/issues/42) | [#91](https://github.com/Team-Origen/origen/issues/91), [#92](https://github.com/Team-Origen/origen/issues/92), [#93](https://github.com/Team-Origen/origen/issues/93) |
| `PLN-10` | [#43](https://github.com/Team-Origen/origen/issues/43) | [#79](https://github.com/Team-Origen/origen/issues/79), [#80](https://github.com/Team-Origen/origen/issues/80), [#81](https://github.com/Team-Origen/origen/issues/81) |
| `PLN-11` | [#44](https://github.com/Team-Origen/origen/issues/44) | [#58](https://github.com/Team-Origen/origen/issues/58), [#59](https://github.com/Team-Origen/origen/issues/59), [#60](https://github.com/Team-Origen/origen/issues/60) |
| `PLN-12` | [#45](https://github.com/Team-Origen/origen/issues/45) | [#67](https://github.com/Team-Origen/origen/issues/67), [#68](https://github.com/Team-Origen/origen/issues/68), [#69](https://github.com/Team-Origen/origen/issues/69) |
| `PLN-13` | [#46](https://github.com/Team-Origen/origen/issues/46) | [#82](https://github.com/Team-Origen/origen/issues/82), [#83](https://github.com/Team-Origen/origen/issues/83), [#84](https://github.com/Team-Origen/origen/issues/84) |
| `PLN-14` | [#47](https://github.com/Team-Origen/origen/issues/47) | [#70](https://github.com/Team-Origen/origen/issues/70), [#71](https://github.com/Team-Origen/origen/issues/71), [#72](https://github.com/Team-Origen/origen/issues/72) |
| `PLN-15` | [#48](https://github.com/Team-Origen/origen/issues/48) | [#88](https://github.com/Team-Origen/origen/issues/88), [#89](https://github.com/Team-Origen/origen/issues/89), [#90](https://github.com/Team-Origen/origen/issues/90) |

Las relaciones `blocked-by` del diagrama también quedaron registradas en GitHub. Cada solicitud de revisión debe enlazar una subissue ejecutable y mantenerse pequeña; si deja de ser revisable, se divide. Publicar la jerarquía no declara las tareas listas ni aprobadas.

## 8. Decisiones resueltas

Las seis decisiones pendientes quedaron resueltas. Ninguna habilita por sí sola `status:approved`: cada tarea sigue necesitando su propia revisión.

1. **Ciclo de una solicitud manual rechazada.** Se representa con el estado `Cancelado` más motivo obligatorio, actor y fecha, sin multa; no se agrega un estado `Rechazado` a la máquina de RF-14. Regla nueva explícita: una solicitud en `Solicitado` no crea relación Profesional–Paciente ni entrada en la lista permitida; la relación nace al **aprobar** y persistir el turno. Un rechazo no deja relación ni visibilidad, solo el evento auditado. La interfaz de aprobación manual y su ciclo completo quedan fuera de esta demo.
2. **Acceso sin contraseña y canal de correo.** El enlace por correo es el único método sin contraseña de la etapa; Google OAuth queda postergado. El canal de desarrollo es el buzón local de Swoosh (`Swoosh.Adapters.Local`, `/dev/mailbox`), sin credenciales ni proveedor real. `Origen.BootstrapAdmin.DeliveryConfig` no se modifica: sigue prohibiendo `Local` y `Test` para entrega real.
3. **Canal del código telefónico.** El código de verificación viaja por el mismo buzón local. Se guarda solo su hash, con vencimiento, un uso y límite de intentos; la auditoría registra envío, validación y fallos sin código ni número completo. Quedan descartados los códigos fijos hardcodeados en el dominio y cualquier panel que exponga el secreto en la interfaz.
4. **Aprobación en la demo.** Los perfiles profesionales de la demo usan aprobación automática antes de D-1, así la reserva autónoma nace `Reservado` y ese es su estado final visible. Sin WhatsApp no hay mensajes D-2/D-1 ni evidencia de `delivered`, por lo que la cancelación automática de RF-16 a las 18:00 de D-1 no se implementa en esta etapa y un turno `Reservado` no se cancela solo.
5. **Cuentas iniciales locales.** Se reutiliza el procedimiento operativo existente (`mix origen.bootstrap_admin`) con datos ficticios y buzón local. No se crea una herramienta exclusiva de desarrollo, para no abrir un segundo camino de alta sin auditoría que después diverja de producción.
6. **Reestimación y corte.** Reestimadas `PLN-02`, `PLN-03`, `PLN-05`, `PLN-08` y `PLN-15` según la sección 3.1: el núcleo pasa de 136–212 h a **126–192 h**. Se decidió **no** aplicar el corte de `PLN-12` ni `PLN-13`, que permanecen en Sprint 1; el total comprometido es **150–230 h** y el sobre-compromiso queda registrado en la sección 3.2, con la regla de que el ajuste se hace sobre presentación o sobre esos dos alcances, nunca sobre seguridad.

## 9. Mañana

1. Las seis decisiones de la sección 8 están resueltas; no se reabren salvo que aparezca un bloqueo real.
2. Dibujar juntos la operación única de reserva y sus permisos; no crear todavía otra implementación paralela por rol.
3. Lucca prepara casos de autorización; Said, casos de identidad asistida; Santiago, ejemplos de disponibilidad; Samuel, ejemplos de perfil y reserva.
4. Refinar rangos, dividir cualquier tarea mayor a dos o tres días y confirmar el corte.
5. Integrar contratos y pruebas pequeñas durante la semana; reservar el último día para ensayo, no para una gran fusión.

## 10. Hitos condicionales de las dos semanas

| Momento | Si las condiciones están cumplidas | Si no están cumplidas |
| --- | --- | --- |
| Fin de semana 1 | `PLN-02` revisada; sesión interna, acceso del Paciente, teléfono, tipo y disponibilidad avanzan con contratos integrados. | Registrar el bloqueo, mantener ejemplos y pruebas aisladas, y mover `PLN-13` y luego `PLN-12` fuera del milestone; no inventar cuentas ni permisos. |
| Mitad de semana 2 | Integrar `PLN-08` apenas estén listos perfil, teléfono, tipo y disponibilidad; probar una reserva real local. | Mostrar qué predecesor falta y reducir presentación; no saltear teléfono, seguridad ni transacción. |
| Fin de semana 2 | Ejecutar `PLN-14`: Profesional configura, Paciente entra y reserva, Profesional ve su agenda. | Demostrar resultados parciales verificados y volver a estimar; no declarar completo el recorrido. |

## 11. Camino tentativo de 11 sprints

| Sprint | Resultado tentativo |
| ---: | --- |
| 1 | Acceso básico del Paciente, perfil propio, teléfono verificado, primera reserva autónoma, agenda regular y vista diaria; alternativa asistida solo si cabe. |
| 2 | Completar identidad interna, altas administrativas y flujo asistido desplazado; endurecer permisos y sesiones. |
| 3 | Agenda completa: ausencias, feriados, cambios con conflictos y ventanas de reserva. |
| 4 | Ampliar portal del Paciente: historial, edición segura y recuperación; representación todavía separada. |
| 5 | Aprobación manual, reglas D-1, cancelación y ciclo completo de solicitudes rechazadas. |
| 6 | WhatsApp, confirmación, estados de entrega y revisión urgente. |
| 7 | Reprogramación, cancelación unificada, cierres, sobreturnos y multas. |
| 8 | Lista de espera con retención y asignación segura ante concurrencia. |
| 9 | Representación completa, gestión de personas, bajas lógicas y correcciones reforzadas. |
| 10 | Registro financiero, comprobantes privados, saldos y devoluciones externas. |
| 11 | Notas no clínicas, reportes, auditoría consultable, recuperación y controles obligatorios antes de producción. |

Este roadmap mueve los básicos del Paciente al sprint actual y los amplía después. Es una secuencia para revisar, no once promesas cerradas.

## 12. Glosario corto

| Término | Explicación simple |
| --- | --- |
| Enlace de acceso / Magic Link | Enlace enviado por correo, de uso único y duración limitada; evita una contraseña del Paciente. |
| TOTP | Código temporal de una aplicación autenticadora, usado como segundo control para cuentas internas. |
| D-1 | Día anterior a la cita; si la cita es el viernes, D-1 es el jueves. |
| Perfil listo | Perfil con los datos obligatorios completos y el teléfono del destinatario verificado para autogestión. |
| Relación | Vínculo de alcance entre Profesional y Paciente; no es una cuenta ni nace por navegar. |
| Reservado | Turno activo pendiente del flujo posterior de confirmación cuando corresponde. No equivale a Confirmado. |
| Snapshot | Copia histórica de valores del tipo de consulta dentro del turno. |
| Transacción | Regla de todo o nada para guardar turno, relación, snapshots y auditoría. |
| Predecesor | Tarea que debe entregar su resultado antes de comenzar o completar otra. |
| Tarea / issue | Unidad pequeña de trabajo con resultado, aceptación, responsable y dependencias. |
| Solicitud de revisión / PR | Propuesta de cambios para que otra persona la revise antes de integrarla. |
| Lista pendiente / backlog | Conjunto de tareas todavía no comprometidas. |
| Sprint | Período corto de trabajo; en este plan dura dos semanas. |
| Creación inicial / bootstrap | Camino excepcional y autorizado para obtener la primera cuenta de Administrador. |
| Alcance adicional | Trabajo valioso que se intenta solo después del núcleo. En Sprint 1 la reserva ya no está protegida: `PLN-12` y `PLN-13` quedaron comprometidas y el sobre-compromiso está registrado en la sección 3.2. |

## Fuentes para reconciliar

- [Requisitos y alcance](../Origen_Documentacion.md)
- [Términos y estado del bootstrap](../CONTEXT.md)
- [Matriz de autorización](../security/AUTHORIZATION_MATRIX.md)
- [Roadmap histórico](../PLAN_DE_SPRINTS.md)
- [Sprint 0 histórico](./SPRINT_00.md)
- [Guía inicial para estudiantes](../development/GUIA_INICIAL_ESTUDIANTES.md)
- [Guía técnica para crear el primer Administrador](../deployment/FIRST_ADMIN_BOOTSTRAP.md)
