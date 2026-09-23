# Reprogramación del plan de sprints y fundamentación técnica

> **Documento de justificación y control de cambios — Proyecto Origen**  
> **Asignatura / Ámbito:** Entrega de Ingeniería de Software — Planificación y Gestión de Sprints  
> **Equipo de Desarrollo:** Lucca Giordana, Said, Santiago, Samuel  
> **Fecha de Reprogramación:** Septiembre de 2026  
> **Documentos involucrados:**  
> - *Plan Inicial (v1.0):* Antiguo `docs/PLAN_DE_SPRINTS.md` (archivado en historial Git).  
> - *Plan Vigente (v2.0):* [`docs/sprints/PLAN_TENTATIVO_11_SPRINTS.md`](./PLAN_TENTATIVO_11_SPRINTS.md).  
> - *Especificación de Dominio y Requisitos:* [`docs/Origen_Documentacion.md`](../Origen_Documentacion.md).  
> - *Cierre de Sprint 0:* [`docs/sprints/SPRINT_00.md`](./SPRINT_00.md).  

---

## 1. Resumen ejecutivo

Durante la transición entre el **Sprint 0** (fundaciones de arquitectura) y el **Sprint 1**, el equipo de desarrollo de **Origen** realizó una evaluación crítica y retrospectiva sobre la viabilidad, el valor entregado y los riesgos técnicos del plan de sprints original (v1.0).

Como resultado de este análisis, se decidió por consenso unánime **reformular integralmente el plan de sprints**. La modificación principal consistió en abandonar una progresión por silos horizontales basada en roles (donde la reserva de turnos por parte del Paciente quedaba postergada hasta el Sprint 5, semana 10 del proyecto) para adoptar un enfoque de **rebanada vertical delgada (*Thin Vertical Slice*)**. 

Bajo este nuevo paradigma, el **Sprint 1** se redefinió para entregar el **recorrido troncal completo del sistema de punta a punta en dos semanas**: un Profesional configura su agenda, un Paciente accede sin contraseña y verifica su teléfono, el Paciente reserva autónomamente su primera cita en una transacción atómica y el Profesional visualiza el turno en su agenda privada.

Esta decisión fue formalizada en la especificación funcional ([`Origen_Documentacion.md`](../Origen_Documentacion.md)), en la matriz de permisos ([`AUTHORIZATION_MATRIX.md`](../security/AUTHORIZATION_MATRIX.md)) y en el tablero de trabajo de GitHub Projects mediante la publicación de **14 issues padre ([#35](https://github.com/Team-Origen/origen/issues/35) a [#48](https://github.com/Team-Origen/origen/issues/48)) y 45 subissues ejecutables ([#49](https://github.com/Team-Origen/origen/issues/49) a [#93](https://github.com/Team-Origen/origen/issues/93))**, de las cuales un conjunto significativo ya cuenta con Pull Requests integrados en la rama principal de desarrollo (`develop`).

A continuación se fundamentan detalladamente los motivos, principios teóricos, impactos en la capacidad y la comparación sprint por sprint que sustentan esta reprogramación.

---

## 2. Diagnóstico crítico del Plan Inicial v1.0: ¿Por qué fue necesario reprogramar?

El plan original presentaba cuatro debilidades estructurales que ponían en serio riesgo la calidad, los plazos y el valor demostrable del proyecto:

### 2.1. Fragmentación en capas horizontales y riesgo de integración tardía (*Late Integration Risk*)

En el Plan v1.0, el alcance funcional se distribuía de manera estrictamente secuencial por roles y módulos:
- **Sprint 1 histórico:** Usuarios internos, identidad y altas administrativas.
- **Sprint 2 histórico:** Configuración de agenda y primer turno creado por Secretaría.
- **Sprint 3 histórico:** Operación del Profesional y cierre operativo.
- **Sprint 4 histórico:** Acceso y perfil del Paciente.
- **Sprint 5 histórico:** Recién en este ciclo se implementaba la reserva autónoma del Paciente.

**Consecuencia técnica:** El valor central de Origen (que un paciente pueda agendar una consulta de salud mental de forma rápida y autónoma) no existía en el software hasta la semana 10 de trabajo. Construir componentes aislados durante dos meses sin probar la interacción entre el calendario del paciente, el motor transaccional de reservas y la agenda del profesional generaba un **alto riesgo de "integración Big Bang"**. Cualquier discrepancia en el modelo de concurrencia, en las zonas horarias o en las reglas de estado habría obligado a refactorizaciones masivas con un costo exponencial de cambio.

### 2.2. Premisa errónea en el modelo de dominio: Secretaría como cuello de botella artificial

En el análisis inicial se asumió la premisa de que un Paciente requería obligatoriamente una relación previa con el Profesional para poder interactuar en la plataforma, y que esa relación debía nacer necesariamente de un primer turno registrado por Secretaría (antiguo RF-05).

**El hallazgo:** Al modelar los casos de uso reales de consultorios modernos, el equipo descubrió que esta regla contradecía el propósito fundamental del sistema: facilitar la autogestión. Obligar a que Secretaría interviniera antes de que un nuevo paciente pudiera reservar convertía al rol administrativo en un cuello de botella innecesario y acoplaba indebidamente los contextos de identidad con los de agenda.

**La corrección:** Se corrigió formalmente el requisito funcional RF-05 y la matriz de autorización: *un Paciente autenticado con perfil completo y teléfono verificado tiene derecho a reservar su primera cita de manera 100 % autónoma*. La relación Profesional–Paciente nace cuando la reserva es aprobada y persistida en la base de datos dentro de una transacción atómica. La vía de Secretaría no desaparece, sino que se redefine correctamente como un **camino asistido e inclusivo** para personas que no pueden o no desean utilizar la web.

### 2.3. Subestimación de capacidad y madurez acelerada de las fundaciones

El Plan v1.0 se construyó sobre un supuesto extremadamente conservador: 10 horas semanales por integrante (capacidad neta planificable de ≤64 h-equipo por sprint de dos semanas). 

Sin embargo, al iniciar el proyecto:
1. Los cuatro integrantes acordaron y aseguraron una dedicación real de **20 horas semanales por persona**, elevando la capacidad bruta a **160 h-equipo** y el presupuesto objetivo planificable a **128 h-equipo**.
2. Los resultados obtenidos en el **Sprint 0** (ver [`SPRINT_00.md`](./SPRINT_00.md)) fueron contundentes: la arquitectura base de Phoenix 1.7 / LiveView, la integración continua en GitHub Actions, la auditoría inmutable append-only en `audit_events`, el framework de autorización *default-deny* y la mix task de bootstrap de administrador con TOTP (`NimbleTOTP`) y cifrado (`CloakEcto`) quedaron operativas y probadas en solo 52 h-equipo.

Esta aceleración técnica temprana redujo drásticamente la incertidumbre (*uncertainty cone*) en los módulos de identidad y seguridad, permitiendo reestimar tareas a la baja y asumir un incremento de valor mucho mayor en el Sprint 1.

### 2.4. Acoplamiento prematuro a proveedores externos de alta fricción

El Plan v1.0 pretendía integrar tempranamente proveedores externos complejos: Google OAuth en el Sprint 4 y la API comercial de WhatsApp en fases tempranas.

Esto introducía una dependencia externa crítica ajena al control del equipo: tramitación de cuentas comerciales en Meta, aprobación de plantillas de WhatsApp, configuración de credenciales OAuth de producción y riesgos de conectividad en entornos de evaluación. 

---

## 3. Fundamentación metodológica y técnica de la reformulación

La reprogramación no fue una simple reorganización de fechas, sino una decisión arquitectónica fundamentada en los siguientes principios de ingeniería de software:

### 3.1. Adopción del principio *Thin Vertical Slice* (*Walking Skeleton*)

En lugar de construir el sistema por "capas de torta" horizontales (toda la base de datos, luego todas las APIs, luego todas las pantallas), se implementó el concepto de **Walking Skeleton** (*esqueleto caminante*): una rebanada vertical que conecta de extremo a extremo todas las capas tecnológicas de Origen:
- **Base de Datos:** Migraciones en PostgreSQL 17, constraints de unicidad, tablas de tipos de consulta, disponibilidades, turnos, relaciones y auditoría inmutable.
- **Contextos de Dominio (Elixir/Ecto):** Lógica de negocio encapsulada en `Origen.Accounts`, `Origen.Appointments`, `Origen.Schedules` y `Origen.Audit`, utilizando `Ecto.Multi` para garantizar transacciones ACID estrictas.
- **Capa Web (Phoenix LiveView):** Vistas reactivas en tiempo real para configuración de disponibilidad, calendario del paciente y agenda privada del profesional.
- **Seguridad transversal:** Autorización *default-deny* en el servidor y auditoría append-only sin secretos en cada operación sensible.

Al culminar el Sprint 1, el equipo cuenta con una arquitectura probada, integrada y ejecutable sobre la cual iterar con total confianza.

### 3.2. Aislamiento y pragmática en entorno de desarrollo

Para eliminar la dependencia de servicios de terceros sin vulnerar las reglas de seguridad, se establecieron tres decisiones de ingeniería:

1. **Magic Link exclusivo para Pacientes:** Se definió el enlace de acceso por correo electrónico (*Magic Link*) de un solo uso y 15 minutos de expiración como el método passwordless de esta etapa, postergando Google OAuth para cuando el portal se amplíe.
2. **Buzón local de Swoosh (`/dev/mailbox`):** Todos los correos de autenticación se despachan en desarrollo al buzón local en memoria. El validador fail-closed `Origen.BootstrapAdmin.DeliveryConfig` **no se alteró ni se relajó**: sigue bloqueando adaptadores locales para entornos de producción, preservando la disciplina de seguridad.
3. **Verificación telefónica estricta y desacoplada (`PLN-15`):** La regla de negocio exige que ningún paciente reserve sin teléfono verificado. En lugar de bloquear esta regla hasta integrar WhatsApp, se implementó la emisión y validación de códigos OTP mediante el buzón local de desarrollo, almacenando únicamente el hash SHA-256 del código con tiempo de vida (TTL) y límite de reintentos. Esto permitió cumplir con el requisito de seguridad sin depender de la API comercial de mensajería.

### 3.3. Simplificación controlada del modelo de reserva para la demo

Para lograr una integración exitosa en dos semanas sin degradar la arquitectura:
- **Aprobación automática antes de D-1:** Los profesionales de la demo operan con modalidad de aprobación automática; por lo tanto, la reserva autónoma nace válidamente en estado `Reservado`. La aprobación manual y su interfaz quedan planificadas para el Sprint 5.
- **Desacoplamiento temporal de la cancelación automática:** Al no haber envíos reales de WhatsApp en este ciclo, no existe evidencia de entrega (`delivered`). Por lo tanto, la regla de cancelación automática de las 18:00 de D-1 (RF-16) se difirió formalmente al Sprint 6 (cuando se integre WhatsApp), evitando cancelaciones espurias.
- **Tratamiento de rechazos:** Se estableció que si una solicitud es rechazada, pasa a estado `Cancelado` con motivo obligatorio y sin generar relación ni multa, respetando la máquina de estados de RF-14 sin inventar estados no canónicos como "Rechazado".

### 3.4. Organización en cuatro frentes coordinados con integración continua

Para evitar cuellos de botella individuales y maximizar la concurrencia de trabajo, se asignaron cuatro frentes de rol desde el primer día:
- **Lucca (Administrador y Gobernanza):** Sesiones web, autenticación TOTP, bootstrap de cuentas internas y contratos comunes (`PLN-02`, `PLN-03`, `PLN-04`).
- **Said (Secretaría y Motor de Turnos):** Motor transaccional `PLN-08`, pantalla administrativa `PLN-11`, alternativa asistida `PLN-12` y ensayo integrado `PLN-14`.
- **Santiago (Profesional y Agenda):** Tipos de consulta `PLN-06`, disponibilidad semanal `PLN-07`, agenda diaria `PLN-10` y reserva por profesional `PLN-13`.
- **Samuel (Paciente y Autogestión):** Magic Link `PLN-05`, verificación telefónica `PLN-15` y calendario web `PLN-09`.

Cada desarrollador avanza sobre su frente, pero los contratos compartidos (esquemas de datos, APIs de contexto y eventos de auditoría) se acuerdan y prueban continuamente, cerrando con un ensayo integrado (`PLN-14`).

---

## 4. Cuadro comparativo: Plan Inicial v1.0 vs. Plan Reformulado v2.0

La siguiente tabla resume la evolución del roadmap entre ambas versiones, detallando qué cambió y la justificación técnica de cada ajuste:

| Sprint | Plan Inicial (v1.0) | Plan Reformulado (v2.0) | Justificación y Beneficio del Cambio |
|:---:|---|---|---|
| **S0** | Fundaciones, CI, auditoría y matriz básica. | **Fundaciones verificables (Cerrado).** | Se mantuvo idéntico; ejecutado con éxito en 52 h-equipo (ver `SPRINT_00.md`). |
| **S1** | **Solo identidad interna y altas:** Admin activa cuentas, crea Profesional y Secretaría carga Paciente con teléfono pendiente. (176 h base inmanejables). | **Primera reserva autónoma de punta a punta:** Recorrido troncal completo (4 frentes: Admin + Profesional + Paciente + Secretaría asistida) [PLN-02 a PLN-15]. | **Cambio paradigmático:** Entrega una rebanada vertical completa en 2 semanas. Valida la arquitectura transaccional temprana y elimina el riesgo de integración tardía. |
| **S2** | **Agenda y primer turno asistido:** Profesional configura disponibilidad; Secretaría crea el primer turno y genera la relación. | **Consolidar identidad interna y robustecer canal asistido:** Ciclo de vida completo de usuarios internos, sesiones reforzadas (inactividad/TOTP) y validaciones de personas en Secretaría. | La agenda y el primer turno ya fueron abordados verticalmente en S1. S2 se enfoca en la robustez y gobierno del backoffice administrativo. |
| **S3** | **Operación del Profesional:** Profesional consulta turnos y registra asistencia básica. | **Agenda avanzada del Profesional y detección de conflictos:** Ausencias, feriados, bloqueos, ventanas dinámicas de reserva y detector de colisiones que previene invalidar turnos activos. | La consulta básica ya existe en S1 (`PLN-10`). S3 profundiza en la lógica compleja de excepciones temporales y protección de agenda. |
| **S4** | **Acceso y perfil del Paciente:** Google OAuth, Magic Link, completar perfil y teléfono. | **Portal ampliado del Paciente e historial "Mis Turnos":** Vista de historial de turnos pasados y próximos, edición segura de perfil y cambio seguro de teléfono con re-verificación. | El acceso por Magic Link y el alta del perfil se adelantaron a S1. S4 expande la autogestión con historial y gobernanza de datos personales. |
| **S5** | **Reserva autónoma del Paciente:** Calendario de disponibilidad real, reserva autónoma y corte D-1. | **Aprobación manual del Profesional y corte estricto D-1:** Bandeja de solicitudes entrantes, aprobación/rechazo justificado y vencimiento automático a las 18:00 de D-1. | La reserva básica se resolvió en S1. S5 incorpora la complejidad de la aprobación manual humana y sus excepciones operativas. |
| **S6** | **Confirmación y WhatsApp:** Recordatorios D-2/D-1, webhooks, confirmación y cancelación a las 18:00 de D-1 con evidencia `delivered`. | **Integración WhatsApp, confirmación y revisión urgente:** Se mantiene idéntico en alcance, pero ahora se monta sobre un motor de turnos ya probado y maduro. | Se mantiene como el hito de integración de mensajería externa, minimizando riesgos al implementarse sobre reservas ya estables. |
| **S7** | **Reprogramación, cancelación y multas:** Flujo de cambios de turno, multas por inasistencia y sobreturnos. | **Reprogramación, cancelación unificada, cierres operativos y multas:** Cancelación unificada con motivo, reprogramación acordada/por confirmar, cierres `Asistió`/`No asistió`, multas por porcentaje y sobreturnos. | Agrupa todas las operaciones de modificación de turnos y penalidades sobre una base de citas ya confirmadas y notificadas. |
| **S8** | **Lista de espera (camino positivo):** Inscripción, matching por antigüedad, retención de 30 min y aceptación. | **Lista de espera (camino positivo y asignación equitativa):** Se mantiene idéntico en alcance. | Aborda el flujo virtuoso de reasignación automática de vacantes tras cancelaciones de S7. |
| **S9** | **Lista de espera completa y gestión de personas:** Rechazos, pausas al 3.er vencimiento, bajas lógicas y búsquedas. | **Lista de espera completa, representación y gestión de personas:** Excepciones de espera, representación legal de menores (HU 8.3) y bajas lógicas seguras. | Incorpora la representación legal de pacientes que había quedado pendiente de etapas tempranas, consolidando la gestión de personas. |
| **S10**| **Circuito financiero administrativo:** Pagos directos, comprobantes privados, análisis de malware y saldos a favor. | **Circuito financiero administrativo y comprobantes privados:** Pagos registrados sin dinero bancario, almacenamiento privado, URLs firmadas de corta duración y compensaciones. | Se mantiene como el módulo de trazabilidad económica administrativa, sin alterar estados operativos de turnos. |
| **S11**| **Reportes y gates de preproducción:** Reportes de facturación, auditoría consultable, accesibilidad, carga, cifrado y backups probados. | **Reportes, auditoría consultable y gates de preproducción:** Reportes no fiscales, visor de auditoría para Admin, WCAG 2.2 AA, simulacro probado de backups (RPO 1h, RTO 4h). | Gate formal y riguroso de preparación operativa y aseguramiento de calidad antes de considerar cualquier pase a producción. |
| **S12**| **Contingencia opcional:** Absorción de desvíos sin alcance nuevo. | **Contingencia técnica y colchón de estabilización (Opcional):** Buffer exclusivo para contingencias y deuda técnica menor; prohibición absoluta de alcance nuevo. | Se preserva como salvaguarda metodológica para proteger el cierre del proyecto. |

---

## 5. Gestión de la capacidad y tratamiento del sobre-compromiso en Sprint 1

Uno de los aspectos más críticos de la reprogramación es el sinceramiento y la gestión matemática del esfuerzo para el Sprint 1:

### 5.1. Balance de capacidad del equipo

- **Integrantes:** 4 estudiantes (Lucca, Said, Santiago, Samuel).
- **Dedicación semanal individual:** 20 horas.
- **Dedicación quincenal por persona:** 40 horas.
- **Capacidad bruta del equipo:** `4 × 40 = 160 h-equipo`.
- **Presupuesto objetivo planificable (80 %):** **128 h-equipo**.
- **Reserva de contingencia y estabilización (20 %):** **32 h-equipo**.

### 5.2. Análisis del sobre-compromiso de Sprint 1

Al sumar las estimaciones vigentes de las 14 tareas de Sprint 1:
- **Núcleo de la demo (`PLN-02` a `PLN-11`, `PLN-14` y `PLN-15`):** 126–192 h.
- **Alternativa asistida de Secretaría (`PLN-12`):** 16–24 h.
- **Reserva de Profesional para pacientes propios (`PLN-13`):** 8–14 h.
- **Total comprometido en Sprint 1:** **150–230 h-equipo**.

**Lectura honesta:** En su extremo inferior (150 h), el alcance cabe dentro de la capacidad bruta de 160 h pero consume casi la totalidad de la reserva de 32 h. En su extremo superior (230 h), supera la capacidad bruta en 70 horas.

**Criterio de contingencia explícito:** El equipo aceptó conscientemente este sobre-compromiso para intentar incluir la alternativa asistida y la reserva profesional en la primera demo. No obstante, se estableció una **regla de degradación controlada inquebrantable**:
> *Si durante la segunda semana del sprint el esfuerzo real se aproxima al extremo superior de las estimaciones, el ajuste se realizará reduciendo el pulido de diseño visual en LiveView o postergando `PLN-13` y `PLN-12` al Sprint 2. **Bajo ninguna circunstancia se recortará la seguridad, la autenticación TOTP, la verificación telefónica, la transaccionalidad ACID ni la auditoría inmutable**.*

---

## 6. Evidencia empírica de validación: La reprogramación en los hechos

La reprogramación de sprints no quedó como una expresión de deseos en un documento teórico: fue traducida a la infraestructura operativa de desarrollo y se encuentra actualmente en ejecución con resultados verificables:

1. **Jerarquía publicada en GitHub Projects:** Se desglosaron y publicaron las **14 issues padre** vinculadas a los hitos del Sprint 1 ([#35](https://github.com/Team-Origen/origen/issues/35) a [#48](https://github.com/Team-Origen/origen/issues/48)) y sus **45 subissues ejecutables** ([#49](https://github.com/Team-Origen/origen/issues/49) a [#93](https://github.com/Team-Origen/origen/issues/93)), con criterios de aceptación granulares y responsables asignados.
2. **Pull Requests integrados en `develop`:** Durante la ejecución del Sprint 1, el equipo ya integró con éxito múltiples componentes esenciales:
   - **PR [#110](https://github.com/Team-Origen/origen/pull/110):** Pantalla administrativa de altas internas en LiveView (`PLN-11`).
   - **PR [#120](https://github.com/Team-Origen/origen/pull/120):** Ciclo de vida y emisión de invitaciones para cuentas internas (`PLN-04`).
   - **PR [#123](https://github.com/Team-Origen/origen/pull/123) y [#124](https://github.com/Team-Origen/origen/pull/124):** Preparación y activación criptográfica de cuentas internas con enrolamiento TOTP (`PLN-04`).
   - **PR [#125](https://github.com/Team-Origen/origen/pull/125):** Flujo web interactivo de activación para cuentas invitadas (`PLN-04`).
   - **PR [#126](https://github.com/Team-Origen/origen/pull/126):** Autenticación web, gestión de sesiones y denegación *default-deny* (`PLN-03`).
   - **PR [#127](https://github.com/Team-Origen/origen/pull/127):** Pulido de accesibilidad, etiquetas de formulario y renderizado de códigos QR para TOTP (`PLN-03`).

Esta evidencia confirma que la decisión de reprogramar aceleró el ritmo de entrega, unificó el foco del equipo y eliminó los bloqueos que habrían paralizado al proyecto bajo el plan anterior.

---

## 7. Conclusión

La reprogramación del plan de sprints de Origen responde a las mejores prácticas de la ingeniería de software ágil:
1. **Priorización por valor y reducción temprana de riesgo:** Se demostró valor real desde el primer ciclo funcional en lugar de esperar a la mitad del proyecto.
2. **Corrección oportuna del dominio:** Se eliminó un acoplamiento artificial que entorpecía la experiencia de usuario del paciente.
3. **Disciplina y transparencia:** Se expuso el sobre-compromiso con reglas claras de mitigación sin comprometer los atributos de calidad (seguridad, auditoría y pruebas).
4. **Viabilidad técnica comprobada:** Los resultados obtenidos en el código y en los Pull Requests integrados validan que la reformulación fue la decisión correcta para el éxito del proyecto.
