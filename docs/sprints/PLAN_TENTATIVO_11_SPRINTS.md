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
- Se propone un **enlace de acceso por correo** como único método sin contraseña de esta etapa. Es una propuesta pendiente de validar; no hace falta implementar también Google OAuth.
- Postergar WhatsApp no permite postergar la verificación obligatoria del teléfono. `PLN-15` entrega y prueba ese flujo, aunque todavía no haya recordatorios.
- La agenda del Profesional es privada. El servidor obtiene el alcance desde la identidad autenticada, no desde un identificador enviado por la pantalla.
- Tipo, duración, precio y horario se validan al reservar; nombre, duración y dinero se guardan como copias históricas válidas. El dinero no usa decimales imprecisos.
- La relación Profesional–Paciente nace únicamente cuando se almacena con éxito una primera reserva válida. Nunca nace por mirar, hacer clic, iniciar sesión ni enviar una solicitud fallida o denegada.
- La primera reserva, su relación, sus copias históricas y su auditoría se guardan en una transacción: todo o nada. La misma operación de reserva sirve a todos los roles; cambian la autorización y las reglas de entrada, no el núcleo.
- Para esta demo se **propone**, sujeto a decisión de negocio, configurar aprobación automática para el Paciente y reservar antes de D-1. D-1 es el día anterior: para una cita del viernes, el jueves es D-1. Según RF-10, esa reserva autónoma inicial sería **Reservado**, no Confirmado. Secretaría puede elegir Reservado o Confirmado antes de D-1 y debe usar Confirmado durante D-1; el Profesional solo opera sobre Pacientes propios y sigue sus reglas por fecha. Aprobación manual y solicitudes rechazadas quedan fuera hasta aclarar su ciclo.
- No se usan secretos sembrados, selector libre de rol, seguridad desactivada ni datos reales del cliente.

## 3. Capacidad y corte honesto

Los cuatro estudiantes confirmaron al menos 20 h por semana cada uno. Para dos semanas:

- capacidad bruta: `4 × 20 × 2 = 160 h-equipo`;
- presupuesto objetivo de trabajo: **128 h**;
- reserva para bloqueos y correcciones no previstos: **32 h**. La integración planificada, la revisión de cada tarea y el ensayo ya están dentro de las estimaciones.

La antigua regla histórica de 64 h no es el límite de este horizonte. El borrador anterior de 128 h tampoco incluía acceso y reserva del Paciente, por lo que no se conserva su estimación artificialmente.

| Alcance | Rango inicial | Lectura |
| --- | ---: | --- |
| Núcleo de la demo (`PLN-02` a `PLN-11`, `PLN-14` y `PLN-15`) | **136–212 h** | Ya excede 128 h incluso en el extremo optimista. Debe dividirse o reducir presentación antes de comprometerlo. |
| Alternativa asistida (`PLN-12`) | **16–24 h** | Condicional; se corta primero si amenaza el recorrido autónomo. |
| Reserva por Profesional (`PLN-13`) | **8–14 h** | Alcance adicional; preserva el requisito futuro, no forma parte de la demo principal. |
| Total detallado | **160–250 h** | Excede el presupuesto objetivo; no se prometen cuatro roles completos en dos semanas. |

**Corte explícito:** primero sale `PLN-13`, luego `PLN-12`. Si el núcleo refinado supera 128 h, no se consume silenciosamente la reserva: se reduce presentación visual y se muestra evidencia parcial, sin quitar autenticación, autorización, teléfono, privacidad, concurrencia, transacción ni auditoría.

## 4. Cuatro frentes desde el día 1

Los frentes pueden producir ejemplos y pantallas desde el primer día, pero eso no significa que estén terminados. Los contratos compartidos se escriben una vez y se integran temprano; no se espera al último día para unirlos.

| Frente | Responsable | Trabajo temprano independiente | Resultado del rol |
| --- | --- | --- | --- |
| **Administrador** | Lucca | tabla de permisos, estados de cuenta, ejemplos de invitación y sesión | camino autorizado para cuentas internas y controles compartidos |
| **Secretaría** | Said | casos de reutilización de Persona, errores de identidad y guion asistido | alternativa asistida, si entra después del núcleo |
| **Profesional** | Santiago | bocetos de tipo, disponibilidad y agenda privada | configura agenda y ve sus turnos |
| **Paciente** | Samuel | ejemplos de Magic Link, perfil, teléfono y reserva | entra, completa datos y reserva su primera cita |

Lucca coordina contratos y partes compartidas, pero no “termina el servidor” antes que el resto. Said implementa el motor compartido de reservas: los frentes describen el foco de cada rol, no silos técnicos. Cada cambio pequeño se revisa e integra cuando su predecesor está listo.

## 5. Lista local de tareas lista para reconciliar

Todos los estados iniciales son **Propuesto / Por hacer**. Las horas incluyen implementación, pruebas y la revisión inmediata de cada tarea; la reserva de 32 h queda solo para correcciones y bloqueos no previstos. El ensayo integrado de `PLN-14` sí tiene estimación propia. “Revisor” no implica aprobación ya realizada.

### `PLN-02` — Entregar cuentas locales seguras para desarrollo

- **Propósito/resultado:** elegir, implementar, documentar y verificar cómo cada integrante obtiene una cuenta local de Administrador y una base separada de producción.
- **Responsable / revisor / horas:** Lucca / Said / **10–16 h**.
- **Aceptación:** la decisión de política queda aprobada antes de implementar; usa datos ficticios; entrega un camino autorizado exclusivo de desarrollo o reutiliza el procedimiento operativo existente; los cuatro integrantes pueden obtener la cuenta siguiendo la guía; no guarda secretos prearmados, no permite elegir rol y no desactiva controles. La configuración inicial real del cliente sigue fuera de alcance.
- **Predecesores:** ninguno.

### `PLN-03` — Autenticación y autorización compartidas

- **Propósito/resultado:** sesiones internas reforzadas y límites comunes para páginas y operaciones.
- **Responsable / revisor / horas:** Lucca / Samuel / **14–22 h**.
- **Aceptación:** cuentas internas Activas usan contraseña y TOTP (código temporal de una aplicación autenticadora); sesiones vencidas o roles ajenos se deniegan en el servidor; errores no revelan si una cuenta existe ni registran secretos.
- **Predecesores:** `PLN-02`.

### `PLN-04` — Crear y activar cuentas internas de la demo

- **Propósito/resultado:** un Administrador activo crea cuentas pendientes de Secretaría y Profesional; cada titular las activa por invitación.
- **Responsable / revisor / horas:** Lucca / Said / **10–16 h**.
- **Aceptación:** invitación vinculada, vencible y de un uso; contraseña y TOTP pertenecen al titular; no se supone bootstrap real ejecutado.
- **Predecesores:** `PLN-03`.

### `PLN-05` — Acceso sin contraseña y perfil propio del Paciente

- **Propósito/resultado:** acceso por Magic Link y preparación del perfil propio para reservar.
- **Responsable / revisor / horas:** Samuel / Lucca / **18–28 h**.
- **Aceptación:** enlace opaco, vencible, de un uso y respuesta no enumeradora; identidad documental no se duplica ni se vincula automáticamente por coincidencia; perfil incompleto no reserva; representación queda explícitamente fuera.
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
- **Responsable / revisor / horas:** Said / Santiago / **18–28 h**.
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
- **Aceptación:** el canal de desarrollo se decide y documenta antes de implementar; un desafío opaco y un código correctos verifican una sola vez la misma cuenta y número; códigos o desafíos incorrectos, vencidos, consumidos, reutilizados o fuera del límite de intentos fallan sin marcar el teléfono; reenvíos y resultados se auditan sin guardar código ni número completo.
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
PLN-08 -> PLN-12 (condicional)
PLN-08 + PLN-10 -> PLN-13 (alcance adicional)
```

| Responsable | Núcleo | Condicional/adicional | Total posible |
| --- | ---: | ---: | ---: |
| Lucca | 34–54 h | — | 34–54 h |
| Said | 38–58 h | 16–24 h | 54–82 h |
| Santiago | 26–40 h | 8–14 h | 34–54 h |
| Samuel | 38–60 h | — | 38–60 h |

La persona responsable no trabaja aislada: los frentes describen foco de rol, mientras revisión y colaboración ya están incluidas en los rangos de cada tarea. La reserva de 32 h se protege para correcciones y bloqueos no previstos; no vuelve a contar revisiones ni el ensayo estimado en `PLN-14`.

## 7. Tablero y preparación futura de GitHub

Estados simples:

- **Por hacer:** propuesta todavía no lista o sin comenzar.
- **Bloqueada:** una decisión o tarea anterior impide avanzar.
- **En trabajo:** trabajo activo; una tarea principal por persona.
- **En revisión:** resultado completo esperando lectura y evidencia.
- **Terminada:** aceptación cumplida, integrada y revisada; no significa producción.

Cuando el usuario autorice trabajar con GitHub:

1. Leer primero las tareas abiertas, cerradas y pendientes actuales.
2. Reutilizar o actualizar lo existente antes de crear duplicados.
3. Crear una tarea agrupadora del objetivo y tareas pequeñas copiables desde `PLN-*`.
4. Registrar enlaces explícitos de bloqueo entre tareas.
5. Entregar una solicitud de revisión pequeña por tarea; dividirla si deja de ser revisable.
6. No publicar, cerrar, reabrir ni cambiar estados automáticamente sin autorización.

Los identificadores `PLN-*` son locales y estables para esta revisión. No son números de GitHub ni prueban que una issue exista.

## 8. Decisiones pendientes antes de declarar una tarea lista

1. Definir el ciclo de una solicitud manual rechazada; la relación ya quedó definida para nacer solo con una primera reserva válida almacenada con éxito.
2. Validar el enlace por correo como único acceso sin contraseña de esta etapa y elegir el servicio/canal de correo de desarrollo.
3. Elegir el canal de desarrollo para enviar el código telefónico; WhatsApp puede esperar, `PLN-15` no.
4. Confirmar aprobación automática antes de D-1 como configuración de demo; sería `Reservado`, no una nueva regla general.
5. Elegir la política autorizada para cuentas iniciales locales: procedimiento operativo existente o herramienta exclusiva de desarrollo revisada.
6. Reestimar `PLN-02`, `PLN-03`, `PLN-05`, `PLN-08` y `PLN-15`; el núcleo ya supera 128 h en su mínimo y necesita un corte visible sin debilitar seguridad.

## 9. Mañana

1. Revisar las seis decisiones pendientes.
2. Dibujar juntos la operación única de reserva y sus permisos; no crear todavía otra implementación paralela por rol.
3. Lucca prepara casos de autorización; Said, casos de identidad asistida; Santiago, ejemplos de disponibilidad; Samuel, ejemplos de perfil y reserva.
4. Refinar rangos, dividir cualquier tarea mayor a dos o tres días y confirmar el corte.
5. Integrar contratos y pruebas pequeñas durante la semana; reservar el último día para ensayo, no para una gran fusión.

## 10. Hitos condicionales de las dos semanas

| Momento | Si las condiciones están cumplidas | Si no están cumplidas |
| --- | --- | --- |
| Fin de semana 1 | `PLN-02` revisada; sesión interna, acceso del Paciente, teléfono, tipo y disponibilidad avanzan con contratos integrados. | Registrar el bloqueo, mantener ejemplos y pruebas aisladas, y recortar `PLN-12`/`PLN-13`; no inventar cuentas ni permisos. |
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
| Alcance adicional | Trabajo valioso que se intenta solo después del núcleo y sin consumir la reserva protegida. |

## Fuentes para reconciliar

- [Requisitos y alcance](../Origen_Documentacion.md)
- [Términos y estado del bootstrap](../CONTEXT.md)
- [Matriz de autorización](../security/AUTHORIZATION_MATRIX.md)
- [Roadmap histórico](../PLAN_DE_SPRINTS.md)
- [Sprint 0 histórico](./SPRINT_00.md)
- [Guía inicial para estudiantes](../development/GUIA_INICIAL_ESTUDIANTES.md)
- [Guía técnica para crear el primer Administrador](../deployment/FIRST_ADMIN_BOOTSTRAP.md)
