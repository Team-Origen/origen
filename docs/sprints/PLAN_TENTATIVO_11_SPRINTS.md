# Plan de sprints de Origen — Roadmap de 11 sprints y reserva autónoma

> **Documento canónico de planificación de Origen.** Este plan define la organización temporal, capacidad, flujo metodológico y distribución del alcance funcional en 12 ciclos de dos semanas (Sprint 0 a Sprint 11), más un ciclo opcional de contingencia (Sprint 12). Incorpora la reformulación arquitectónica orientada a *Thin Vertical Slices*, estableciendo como hito del Sprint 1 el recorrido troncal de punta a punta: la primera reserva autónoma de un Paciente.

---

## 1. Resumen ejecutivo y marco metodológico

El proyecto **Origen** es una plataforma integral de gestión de turnos, agenda, comunicación y administración para consultorios psicológicos y profesionales de la salud. Su arquitectura está construida sobre **Elixir 1.18**, **Phoenix 1.7 / LiveView** y **PostgreSQL 17**, con estricto énfasis en la seguridad, privacidad por diseño, autorización *default-deny* en el backend y trazabilidad inmutable mediante eventos de auditoría append-only.

La planificación se estructura bajo el marco de **Scrum adaptado a entregas por rebanadas verticales (*thin vertical slices*)**, donde cada slice atraviesa todas las capas de la aplicación (base de datos, reglas de negocio en contextos de dominio, interfaz de usuario en LiveView, autorización, auditoría y pruebas automatizadas). No se concibe la calidad ni la seguridad como etapas finales separadas: cada unidad de entrega incluye sus pruebas unitarias y de integración, validación de permisos y eventos de auditoría como parte de su definición de terminado.

### Parámetros clave de planificación

- **Duración de los sprints:** Ciclos fijos de 2 semanas (10 días hábiles de desarrollo).
- **Equipo de desarrollo:** 4 integrantes con dedicación confirmada de 20 horas semanales por persona.
- **Capacidad bruta por sprint:** `4 integrantes × 20 h/semana × 2 semanas = 160 h-equipo`.
- **Presupuesto planificable objetivo:** **≤128 h-equipo** (80 % de la capacidad bruta).
- **Reserva de contingencia y estabilización:** **32 h-equipo** (20 % restante), destinada a absorber revisiones cruzadas de código, integración de contratos, solución de bloqueos y ensayos integrados.
- **Convención de numeración:** El `Sprint 0` corresponde a la fase de fundaciones técnicas y arquitectura base. Los `Sprint 1` a `Sprint 11` conforman los 11 ciclos de construcción del alcance comprometido. El `Sprint 12` es un ciclo opcional de colchón y contingencia técnica, sin alcance funcional nuevo.
- **Fuentes canónicas:** Este plan instrumenta los requisitos de [Origen_Documentacion.md](../Origen_Documentacion.md), el modelo de términos de [CONTEXT.md](../CONTEXT.md) y las políticas de [security/AUTHORIZATION_MATRIX.md](../security/AUTHORIZATION_MATRIX.md).

---

## 2. Alcance y límites del sistema

| Dentro del roadmap base | Fuera del alcance comprometido |
|---|---|
| Autenticación segura de usuarios internos (contraseña + TOTP obligatorio) y pacientes (Magic Link sin contraseña por email). | Historia clínica, diagnósticos médicos/psicológicos, notas de evolución clínica y seguimiento de tratamientos. |
| Gestión de personas, roles segregados y perfiles vinculados a una misma Persona física sin duplicación de identidad. | Procesamiento, cobro, transferencia o conciliación bancaria de dinero real; pasarelas de pago externas. |
| Configuración de tipos de consulta con copias históricas inmutables (*snapshots*) de nombre, duración y precio. | Emisión de facturas fiscales, recibos oficiales con valor tributario o contabilidad legal formal. |
| Configuración de disponibilidad semanal privada, ventanas de reserva, ausencias, feriados y bloqueos. | Proveedores comerciales de mensajería o email en entornos de desarrollo local (se usan adaptadores locales aislados). |
| Reserva autónoma por el Paciente con verificación previa de teléfono y regla de corte D-1. | Módulo futuro de notas confidenciales cifradas extremo a extremo. |
| Vía asistida por Secretaría para pacientes que no pueden o no desean utilizar el portal web. | Asignación automática de multas sin confirmación humana o con montos arbitrarios no parametrizados. |
| Agenda privada del Profesional filtrada estrictamente por identidad autenticada desde el servidor. | Eliminación física destructiva de registros protegidos o eventos de auditoría. |
| Recordatorios automáticos por WhatsApp D-2/D-1 y cancelación a las 18:00 de D-1 sujeta a evidencia `delivered`. | Integración directa con obras sociales para liquidación automática de prestaciones. |
| Reprogramación, cancelación unificada, sobreturnos manuales y cierres operativos (`Asistió`/`No asistió`). | |
| Lista de espera equitativa por antigüedad con retención atómica de cupos por 30 minutos. | |
| Circuito administrativo de pagos directos, saldos a favor, compensaciones y carga segura de comprobantes privados. | |
| Reportes administrativos, auditoría consultable y gates de preproducción (cifrado, backups probados, WCAG 2.2 AA). | |

### Límites conceptuales de dominio

1. **Modalidad vs. Estado:** `Sobreturno` es una modalidad operativa de un turno que permite excepcionalmente solapar horarios bajo control profesional, no un estado de su ciclo de vida.
2. **Separación de cierres y estados:**
   - **Cierre operativo:** Refleja la asistencia fáctica al consultorio (**Asistió**, **No asistió**, **Cancelado**).
   - **Cierre administrativo:** Refleja el estado del expediente de atención (**Abierto**, **Cerrado**).
   - **Estado financiero:** Refleja la situación del pago de la consulta (**Pendiente**, **En revisión**, **Pagado**, **Rechazado**, **No corresponde**).
   - **Estado del turno:** Máquina de estados formal de RF-14 (**Solicitado**, **Reservado**, **Confirmado**, **Cancelado**, **Sobreturno**).
3. **Autonomía del Paciente (RF-05):** Un Paciente autenticado con perfil completo y teléfono verificado puede reservar de forma autónoma su primera cita sin requerir intervención de Secretaría ni existencia previa de un turno. La relación Profesional–Paciente nace cuando la reserva es persistida en la base de datos dentro de una transacción atómica. Secretaría es un canal alternativo inclusivo, no un cuello de botella.

---

## 3. Reglas de capacidad y planificación

- **Timebox estricto:** Sprints de 2 semanas calendario. Las fechas de fin de sprint son límites fijos (*timeboxes*), no sugerencias extensibles.
- **Capacidad del equipo:** 4 integrantes × 20 h semanales = 80 h semanales = 160 h-equipo por sprint.
- **Techo de compromiso (≤128 h-equipo):** Ningún sprint regular puede comprometer más de 128 horas de trabajo estimadas en su plan inicial. Las 32 horas de reserva (20 %) se protegen deliberadamente para absorber imprevistos técnicos, integración continua y revisiones.
- **Estimación por rangos:** Cada tarea se estima con un rango de esfuerzo (mínimo–máximo) que contempla análisis, codificación, pruebas automatizadas y revisión por pares.
- **Política de sobre-compromiso controlado de Sprint 1:** Para el Sprint 1, el equipo resolvió por consenso incluir voluntariamente la alternativa asistida de Secretaría (`PLN-12`) y la reserva por Profesional (`PLN-13`), elevando el alcance comprometido a **150–230 h**. Esto consume deliberadamente la reserva de 32 h. Como regla de gobernanza inquebrantable, ante cualquier desvío o cuello de botella durante el sprint, el ajuste se realiza exclusivamente reduciendo el pulido visual de la interfaz o postergando `PLN-13` y `PLN-12`; **nunca se recortan la seguridad, la autenticación, la verificación telefónica, la transaccionalidad ACID ni la auditoría inmutable**.

---

## 4. Flujo de tablero y unidades de entrega

El trabajo se gestiona en GitHub Projects (`Origen Development`) mediante un flujo de valor de seis estados bien diferenciados:

$$\text{Backlog} \longrightarrow \text{Por hacer (Ready)} \longrightarrow \text{En trabajo (In Progress)} \longrightarrow \text{En revisión (Review)} \longrightarrow \text{Validación (Validation)} \longrightarrow \text{Terminada (Done)}$$

- **Backlog:** Tarea identificada pero no refinada, con dependencias abiertas o sin criterios de aceptación completos.
- **Por hacer (Ready):** Tarea lista para comenzar: cuenta con objetivo unívoco, criterios de aceptación verificables, dependencias resueltas, controles de permisos/auditoría especificados y diseño de pruebas definido.
- **En trabajo (In Progress):** Trabajo activo. **Límite de WIP estricto:** Máximo 1 tarea principal en progreso por desarrollador en simultáneo. Si una tarea se bloquea en revisión o validación, el equipo prioriza destrabarla antes de iniciar trabajo nuevo.
- **En revisión (Review):** Pull Request abierto. Requiere revisión de código por un par asignado, CI verde (compilación sin warnings, formateo, pruebas unitarias y análisis estático) y verificación de que la autorización se aplica en el servidor (*default-deny*).
- **Validación (Validation):** Demostración funcional del incremento con datos sintéticos, verificación de accesibilidad y confirmación de que no existen efectos colaterales.
- **Terminada (Done):** Cumple íntegramente la *Definition of Done* transversal.

### Entrega por unidades de trabajo (*Work Units*)

Cada Pull Request se compone de commits pequeños y atómicos organizados por unidades de trabajo lógicas. Cada commit entrega un comportamiento coherente, incluye sus pruebas correspondientes y su documentación, facilitando revisiones acotadas y reversiones limpias en caso de fallas.

---

## 5. Definition of Done (DoD) transversal por slice

Una slice o tarea alcanza el estado **Terminada (Done)** única y exclusivamente si cumple todos los siguientes requisitos:

1. **Comportamiento completo de punta a punta:** Entrega la funcionalidad operativa a través de todas las capas necesarias y puede demostrarse de forma autónoma e independiente.
2. **Cobertura de pruebas automatizadas:** Cuenta con pruebas unitarias y de integración que cubren el camino feliz (*happy path*), casos borde relevantes, errores controlados y las reglas de negocio del dominio.
3. **Autorización en el servidor (*default-deny*):** El backend aplica el control de acceso en sus contextos y plugs/LiveViews según la matriz de autorización canónica. Las denegaciones críticas tienen pruebas automatizadas que demuestran que roles no autorizados son rechazados.
4. **Auditoría inmutable append-only:** Registra en la tabla `audit_events` los eventos exigidos por RF-23 (actor, acción, entidad, resultado, timestamp UTC, metadatos saneados), sin almacenar jamás secretos, contraseñas ni datos personales prohibidos.
5. **Apego al glosario de dominio:** Respeta rigurosamente los términos, estados y distinciones conceptuales de `CONTEXT.md` (no mezcla cierre operativo, administrativo ni financiero).
6. **Seguridad y protección de secretos (RNF-07):** Ningún secreto, token, credencial ni dato de conexión se almacena en el repositorio. La información personal sensible viaja saneada en logs y telemetría.
7. **Revisión por pares e integración continua:** El PR cuenta con la aprobación explícita de al menos un revisor del equipo y la suite de GitHub Actions finaliza en verde sin advertencias.
8. **Documentación y trazabilidad:** Los criterios de aceptación, decisiones y evidencias quedan registrados en la issue y en el PR correspondiente.

---

## 6. Organización del equipo en cuatro frentes coordinados

Para maximizar el paralelismo sin caer en la fragmentación de silos técnicos, los cuatro desarrolladores lideran frentes enfocados por rol de usuario desde el primer día, integrando tempranamente contratos compartidos:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        COORDINACIÓN Y CONTRATOS                        │
│                                                                        │
│   [ Lucca ]          [ Said ]           [ Santiago ]      [ Samuel ]   │
│ Administrador       Secretaría          Profesional        Paciente    │
│  y Gobernanza      y Motor Turnos         y Agenda       y Autogestión │
└───────┬──────────────────┬───────────────────┬─────────────────┬───────┘
        │                  │                   │                 │
        ▼                  ▼                   ▼                 ▼
   PLN-02, 03, 04     PLN-08, 11, 12      PLN-06, 07, 10    PLN-05, 09, 15
```

- **Frente Administrador (Lucca):** Lidera las fundaciones de identidad, sesiones web protegidas, tablas de permisos, enrolamiento TOTP y altas iniciales de cuentas internas (`PLN-02`, `PLN-03`, `PLN-04`).
- **Frente Secretaría y Motor de Turnos (Said):** Lidera la implementación del motor transaccional único de reservas (`PLN-08`), la pantalla de administración de cuentas (`PLN-11`), la alternativa asistida (`PLN-12`) y el ensayo integrado (`PLN-14`).
- **Frente Profesional (Santiago):** Lidera la configuración de tipos de consulta con snapshots (`PLN-06`), disponibilidad semanal privada (`PLN-07`), la visualización de la agenda diaria (`PLN-10`) y la reserva por profesional (`PLN-13`).
- **Frente Paciente (Samuel):** Lidera el acceso passwordless por Magic Link (`PLN-05`), el flujo aislado de verificación de número telefónico (`PLN-15`) y la interfaz del calendario de reservas para autogestión (`PLN-09`).

---

## 7. Roadmap detallado: Sprint 0 a Sprint 11

### Sprint 0 — Fundaciones verificables (Cerrado)

> **Estado:** Completado y documentado en detalle en [SPRINT_00.md](./SPRINT_00.md).

- **Objetivo demostrable:** Repositorio público configurado con Phoenix 1.7 / LiveView, PostgreSQL 17, CI en GitHub Actions, registro inmutable de auditoría append-only, matriz de autorización *default-deny* aprobada y bootstrap no productivo del primer Administrador ejecutable.
- **Slices entregados:**
  1. Scaffold Phoenix/LiveView con PostgreSQL 17 local y pipeline de CI en GitHub Actions ([#1](https://github.com/Team-Origen/origen/issues/1)).
  2. Mecanismo de auditoría append-only inmutable (`audit_events`) y módulo de autorización *default-deny* ([#2](https://github.com/Team-Origen/origen/issues/2)).
  3. Tarea administrativa `mix origen.bootstrap_admin` con invitación de un solo uso, enrolamiento TOTP con `NimbleTOTP`, cifrado con `CloakEcto` y auditoría completa ([#3](https://github.com/Team-Origen/origen/issues/3)).
- **HU/RF cubiertos:** RF-01, RF-04, RF-23; RNF-07, RNF-08; RD-01.
- **Condición de salida alcanzada:** Suite de pruebas en verde en CI, migración de base de datos con triggers de inmutabilidad para auditoría y flujo de bootstrap administrativo verificado localmente.
- **Capacidad ejecutada:** 52 h-equipo planificadas / Techo de 64 h-equipo respetado.

---

### Sprint 1 — Primera reserva autónoma de punta a punta (En ejecución)

- **Objetivo demostrable:** Demostrar el recorrido troncal completo del sistema con datos sintéticos en entorno local:
  1. El Administrador activa cuentas internas seguras con TOTP y crea cuentas para Profesional y Secretaría.
  2. El Profesional configura sus tipos de consulta (con precio y duración) y su disponibilidad semanal regular.
  3. Un Paciente nuevo ingresa mediante Magic Link por email (buzón local Swoosh), completa su perfil obligatorio y verifica su número telefónico mediante código OTP.
  4. El Paciente consulta el calendario real y reserva su primera cita de forma autónoma.
  5. La reserva se persiste en una transacción atómica que almacena el turno en estado `Reservado` (aprobación automática antes de D-1), la relación Profesional–Paciente, las copias históricas (*snapshots*) del tipo de consulta y el evento de auditoría.
  6. El Profesional visualiza el turno reservado exclusivamente dentro de su propia agenda diaria privada.
  7. Secretaría cuenta con el flujo asistido alternativo para registrar un paciente y reservar en su nombre.

#### Tareas ejecutables del Sprint 1 (PLN-02 a PLN-15)

| ID Local | Issue GitHub | Subissues | Tarea / Entregable | Responsable / Revisor | Rango Estimado |
|:---:|:---:|:---:|---|:---:|:---:|
| `PLN-02` | [#35](https://github.com/Team-Origen/origen/issues/35) | [#49](https://github.com/Team-Origen/origen/issues/49), [#50](https://github.com/Team-Origen/origen/issues/50), [#51](https://github.com/Team-Origen/origen/issues/51) | **Cuentas locales seguras para desarrollo:** Reutilización de `mix origen.bootstrap_admin` con buzón local para que los 4 desarrolladores configuren sus cuentas locales. | Lucca / Said | 6–8 h |
| `PLN-03` | [#36](https://github.com/Team-Origen/origen/issues/36) | [#52](https://github.com/Team-Origen/origen/issues/52), [#53](https://github.com/Team-Origen/origen/issues/53), [#54](https://github.com/Team-Origen/origen/issues/54) | **Autenticación web y sesiones internas:** Inicio de sesión web para cuentas internas con credenciales, TOTP obligatorio, expiración y control de acceso. | Lucca / Samuel | 10–16 h |
| `PLN-04` | [#37](https://github.com/Team-Origen/origen/issues/37) | [#55](https://github.com/Team-Origen/origen/issues/55), [#56](https://github.com/Team-Origen/origen/issues/56), [#57](https://github.com/Team-Origen/origen/issues/57) | **Alta y activación de cuentas internas:** Administrador invita a Profesional y Secretaría; los usuarios activan su cuenta definiendo contraseña y enrolando TOTP. | Lucca / Said | 10–16 h |
| `PLN-05` | [#38](https://github.com/Team-Origen/origen/issues/38) | [#85](https://github.com/Team-Origen/origen/issues/85), [#86](https://github.com/Team-Origen/origen/issues/86), [#87](https://github.com/Team-Origen/origen/issues/87) | **Acceso sin contraseña y perfil del Paciente:** Magic Link por email vía buzón local Swoosh y formulario para completar perfil propio (DNI, fecha de nacimiento). | Samuel / Lucca | 16–24 h |
| `PLN-06` | [#39](https://github.com/Team-Origen/origen/issues/39) | [#73](https://github.com/Team-Origen/origen/issues/73), [#74](https://github.com/Team-Origen/origen/issues/74), [#75](https://github.com/Team-Origen/origen/issues/75) | **Tipos de consulta y snapshots:** Profesional gestiona sus tipos de consulta con nombre, duración y precio; se valida la inmutabilidad histórica para turnos. | Santiago / Said | 8–12 h |
| `PLN-07` | [#40](https://github.com/Team-Origen/origen/issues/40) | [#76](https://github.com/Team-Origen/origen/issues/76), [#77](https://github.com/Team-Origen/origen/issues/77), [#78](https://github.com/Team-Origen/origen/issues/78) | **Disponibilidad regular privada:** Profesional configura sus franjas horarias semanales de atención y ventana de reserva; validación estricta de solapamientos. | Santiago / Lucca | 12–18 h |
| `PLN-08` | [#41](https://github.com/Team-Origen/origen/issues/41) | [#61](https://github.com/Team-Origen/origen/issues/61) a [#66](https://github.com/Team-Origen/origen/issues/66) | **Motor transaccional único de reserva:** Operación de reserva transaccional ACID que persiste turno, relación Profesional-Paciente, snapshots y auditoría. | Said / Santiago | 18–26 h |
| `PLN-09` | [#42](https://github.com/Team-Origen/origen/issues/42) | [#91](https://github.com/Team-Origen/origen/issues/91), [#92](https://github.com/Team-Origen/origen/issues/92), [#93](https://github.com/Team-Origen/origen/issues/93) | **Calendario y reserva del Paciente:** Interfaz web para que el Paciente consulte horarios libres según disponibilidad real y confirme su reserva. | Samuel / Said | 10–16 h |
| `PLN-10` | [#43](https://github.com/Team-Origen/origen/issues/43) | [#79](https://github.com/Team-Origen/origen/issues/79), [#80](https://github.com/Team-Origen/origen/issues/80), [#81](https://github.com/Team-Origen/origen/issues/81) | **Agenda diaria del Profesional:** Vista privada de turnos del día para el Profesional autenticado, con filtrado estricto desde el backend. | Santiago / Samuel | 6–10 h |
| `PLN-11` | [#44](https://github.com/Team-Origen/origen/issues/44) | [#58](https://github.com/Team-Origen/origen/issues/58), [#59](https://github.com/Team-Origen/origen/issues/59), [#60](https://github.com/Team-Origen/origen/issues/60) | **Pantalla administrativa interna:** LiveView para que el Administrador registre nuevas cuentas internas y gestione invitaciones. | Said / Lucca | 8–12 h |
| `PLN-12` | [#45](https://github.com/Team-Origen/origen/issues/45) | [#67](https://github.com/Team-Origen/origen/issues/67), [#68](https://github.com/Team-Origen/origen/issues/68), [#69](https://github.com/Team-Origen/origen/issues/69) | **Alternativa asistida por Secretaría:** Secretaría registra pacientes y crea turnos en su nombre utilizando el motor unificado de `PLN-08`. | Said / Lucca | 16–24 h |
| `PLN-13` | [#46](https://github.com/Team-Origen/origen/issues/46) | [#82](https://github.com/Team-Origen/origen/issues/82), [#83](https://github.com/Team-Origen/origen/issues/83), [#84](https://github.com/Team-Origen/origen/issues/84) | **Reserva por Profesional para Pacientes vinculados:** El Profesional crea turnos posteriores para pacientes con relación previa establecida. | Santiago / Said | 8–14 h |
| `PLN-14` | [#47](https://github.com/Team-Origen/origen/issues/47) | [#70](https://github.com/Team-Origen/origen/issues/70), [#71](https://github.com/Team-Origen/origen/issues/71), [#72](https://github.com/Team-Origen/origen/issues/72) | **Integración temprana y ensayo seguro:** Ensayos integrados de punta a punta, pruebas de concurrencia en reservas simultáneas y verificación de accesibilidad. | Said / Santiago | 12–18 h |
| `PLN-15` | [#48](https://github.com/Team-Origen/origen/issues/48) | [#88](https://github.com/Team-Origen/origen/issues/88), [#89](https://github.com/Team-Origen/origen/issues/89), [#90](https://github.com/Team-Origen/origen/issues/90) | **Verificación telefónica obligatoria:** Emisión y validación de código OTP mediante buzón local, almacenamiento de hash con TTL y límite de reintentos. | Samuel / Said | 10–16 h |

- **Capacidad y sobre-compromiso:** 150–230 h-equipo comprometidas frente a un objetivo de 128 h y capacidad bruta de 160 h. Se asume el consumo total de la reserva de 32 h.
- **Decisiones arquitectónicas de la demo:**
  1. *Aprobación automática antes de D-1:* La reserva autónoma nace en estado `Reservado`. La aprobación manual del profesional queda para el Sprint 5.
  2. *Desacoplamiento de WhatsApp:* Se verifica el teléfono de forma estricta (`PLN-15`) pero sin enviar mensajes reales; la cancelación automática a las 18:00 de D-1 de RF-16 queda diferida a Sprint 6.
  3. *Rechazo manual:* Si una solicitud fuere rechazada, pasa a `Cancelado` con motivo obligatorio y sin relación generada.
  4. *Aislamiento seguro:* Uso exclusivo de adaptadores locales de Swoosh (`/dev/mailbox`), preservando intacto el validador fail-closed `DeliveryConfig` para producción.

---

### Sprint 2 — Completar identidad interna, sesiones reforzadas y consolidación asistida

- **Objetivo demostrable:** El Administrador gestiona el ciclo de vida completo de usuarios internos (activación, bloqueo preventivo, revocación y reemisión de invitaciones); las sesiones web aplican expiración por inactividad y reautenticación para acciones sensibles; el flujo asistido de Secretaría queda consolidado con validaciones documentales completas y prevención de duplicados de personas.
- **Slices candidatos:**
  1. **[AFK] Ciclo de vida administrativo de cuentas internas:** Administrador lista usuarios, reemite invitaciones vencidas y desactiva cuentas con auditoría completa.
  2. **[AFK] Seguridad de sesiones web reforzadas:** Control estricto de expiración por inactividad (15 min para admin, 30 min para profesionales), cierre de sesión global y reautenticación con contraseña/TOTP para cambios sensibles.
  3. **[AFK] Robustecimiento del alta de Pacientes por Secretaría:** Normalización de documentos (DNI, pasaporte, etc.), validación de unicidad en la entidad `personas` y soporte para pacientes sin correo electrónico.
  4. **[AFK] Manejo de advertencias operativas en Secretaría:** Alerta visible cuando se reserva para un paciente con teléfono no verificado, permitiendo la gestión interna pero bloqueando la autogestión.
- **HU/RF principales:** HU 1.1, HU 4.2, HU 7; RF-01, RF-02, RF-04, RF-06, RF-23; RNF-08, RNF-09.
- **Dependencias clave:** Sprint 1.
- **Condición de salida:** Toda acción administrativa sensible exige reautenticación; no existen duplicados documentales de personas; el Administrador controla plenamente las cuentas internas.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 3 — Agenda avanzada del Profesional y prevención de conflictos

- **Objetivo demostrable:** El Profesional configura ausencias programadas, feriados, bloqueos temporales y ventanas dinámicas de reserva (mínimo y máximo de anticipación para reservar); el motor de agenda detecta colisiones e impide modificaciones que invaliden silenciosamente turnos activos.
- **Slices candidatos:**
  1. **[AFK] Gestión de ausencias y bloqueos:** Profesional declara vacaciones, licencias o bloqueos puntuales en días u horas específicas, excluyéndolos del calendario público.
  2. **[AFK] Ventanas dinámicas de reserva:** Configuración de límites temporales (ej. reserva permitida entre 30 días y 24 horas antes del horario).
  3. **[AFK] Detector de conflictos de disponibilidad:** Impedir guardar modificaciones en la disponibilidad regular si existen turnos confirmados o reservados en las franjas afectadas, exigiendo resolución individual.
  4. **[AFK] Visualización de agenda semanal y mensual:** Interfaz rica para el Profesional con vistas de día, semana y mes, estados de turnos y discriminación visual de ausencias.
- **HU/RF principales:** HU 2.1, HU 3.2, HU 3.3, HU 2.8; RF-05, RF-07, RF-08, RF-10, RF-14, RF-23.
- **Dependencias clave:** Sprints 1 y 2.
- **Condición de salida:** El Profesional no puede dejar turnos en el limbo al cambiar sus horarios; las ausencias y bloqueos se reflejan de inmediato en la oferta del calendario público.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 4 — Portal ampliado del Paciente e historial "Mis Turnos"

- **Objetivo demostrable:** El Paciente autenticado accede a su panel "Mis Turnos" para consultar historial de citas (próximas y pasadas), edita sus datos personales y ejecuta el flujo de cambio seguro de teléfono (con suspensión transitoria de notificaciones y re-verificación obligatoria).
- **Slices candidatos:**
  1. **[AFK] Vista "Mis Turnos" del Paciente:** Consulta de turnos próximos y pasados con estado operativo, fecha, profesional y arancel; prohibición absoluta de exposición de notas clínicas.
  2. **[AFK] Edición de perfil de Paciente:** Modificación de datos de contacto y actualización de correo electrónico con confirmación de enlace de seguridad.
  3. **[AFK] Cambio seguro de número telefónico:** Proceso de actualización telefónica que suspende mensajes al número anterior, emite código de verificación al nuevo y señaliza reservas próximas para revisión.
  4. **[AFK] Cierre de sesión y revocación de Magic Links:** Invalidación inmediata de tokens de acceso al cerrar sesión o ante múltiples intentos fallidos.
- **HU/RF principales:** HU 1.3, HU 2.9, HU 8.1, HU 8.2; RF-01, RF-02, RF-03, RF-06, RF-13, RF-23; RNF-10.
- **Dependencias clave:** Sprints 1 y 2.
- **Condición de salida:** El paciente gestiona sus datos de forma segura; el cambio de número previene el envío de información confidencial a líneas en transición.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 5 — Aprobación manual del Profesional, corte D-1 y solicitudes

- **Objetivo demostrable:** El Profesional gestiona la modalidad de aprobación manual para sus consultas; se implementa la bandeja de solicitudes entrantes, la aprobación (que transiciona a `Confirmado` o `Reservado` según D-1 y genera la relación) y el rechazo formal (transición a `Cancelado` con motivo obligatorio y sin relación); se aplica el corte estricto de las 18:00 de D-1 para solicitudes pendientes.
- **Slices candidatos:**
  1. **[AFK] Configuración de modalidad de aprobación:** Profesional elige entre aprobación automática o manual por tipo de consulta.
  2. **[AFK] Bandeja de solicitudes de reserva:** Interfaz para que el Profesional revise solicitudes pendientes (`Solicitado`) con datos básicos del paciente y horario solicitado.
  3. **[AFK] Aprobación de solicitudes:** Transición controlada a `Reservado` o `Confirmado` y persistencia de la relación Profesional–Paciente en la base de datos.
  4. **[AFK] Rechazo fundamentado de solicitudes:** Transición directa a `Cancelado` con motivo registrado, notificación por correo al paciente y liberación del horario sin generar relación.
  5. **[AFK] Corte automático D-1 para solicitudes:** Job programado a las 18:00 de D-1 que cancela automáticamente solicitudes no resueltas por el Profesional, liberando la agenda.
- **HU/RF principales:** HU 2.2, HU 2.5.1, HU 2.7; RF-10, RF-10 bis, RF-11, RF-12, RF-14, RF-18, RF-23.
- **Dependencias clave:** Sprints 1, 3 y 4.
- **Condición de salida:** Las solicitudes manuales no resueltas a tiempo no bloquean la agenda; los rechazos no dejan registros espurios de acceso a fichas clínicas.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 6 — Integración WhatsApp, confirmaciones automatizadas y revisión urgente

- **Objetivo demostrable:** El sistema envía recordatorios automáticos por WhatsApp a las 08:00 de D-2 y D-1 a teléfonos verificados; procesa webhooks con callbacks de entrega (`sent`, `delivered`, `failed`); permite confirmar asistencia directamente por WhatsApp (transicionando a `Confirmado`); ejecuta la cancelación automática a las 18:00 de D-1 únicamente ante evidencia de entrega comprobada (`delivered`); y canaliza los casos no comprobados a una cola de revisión urgente.
- **Slices candidatos:**
  1. **[AFK] Motor de encolado de recordatorios D-2 y D-1:** Tarea periódica de background que selecciona turnos elegibles y encola mensajes con contenido minimizado (sin datos clínicos ni diagnósticos).
  2. **[AFK] Webhook de recepción de eventos WhatsApp:** Endpoint seguro para recibir estados `sent`, `delivered` y `failed`, registrando la evidencia de entrega en la base de datos.
  3. **[AFK] Confirmación interactiva de asistencia:** Recepción de la respuesta afirmativa del paciente que transiciona el turno de `Reservado` a `Confirmado` de forma automática.
  4. **[AFK] Cancelación automática a las 18:00 de D-1:** Proceso batch que cancela turnos `Reservado` sin confirmación **únicamente si cuentan con al menos un evento `delivered`**, liberando la agenda.
  5. **[AFK] Bandeja de revisión urgente:** Pantalla para Secretaría y Profesional con turnos en estado `Reservado` cuyo mensaje falló o quedó en `sent`, permitiendo contacto telefónico manual y resolución auditada.
- **HU/RF principales:** HU 2.10; RF-16, RF-17, RF-18, RF-23; RNF-11; Rend-03.
- **Dependencias clave:** Sprints 1, 4 y 5; credenciales y plantillas de WhatsApp Business API aprobadas.
- **Condición de salida:** La cancelación automática jamás se dispara con entrega no verificada; ningún mensaje contiene datos sensibles de salud; la cola de revisión urgente alerta incidencias a tiempo.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 7 — Reprogramación, cancelación unificada, cierres operativos y multas

- **Objetivo demostrable:** Pacientes, Profesionales y Secretaría ejecutan reprogramaciones y cancelaciones unificadas con liberación inmediata de cupos y registro de motivos; el Profesional efectúa el cierre operativo post-consulta (`Asistió`/`No asistió`); se gestionan correcciones de cierre auditadas y se calculan y aplican multas por porcentaje parametrizado, sin montos arbitrarios.
- **Slices candidatos:**
  1. **[AFK] Cancelación unificada con motivo:** Operación que permite a Paciente, Secretaría o Profesional cancelar un turno activo, exigiendo motivo, registrando al actor y liberando la agenda al instante.
  2. **[AFK] Reprogramación de turnos:** Flujo para cambiar fecha/horario de turnos confirmados bajo las modalidades "Acordado con el paciente" o "Requiere confirmación" (con regla de caducidad de 24 h).
  3. **[AFK] Cierre operativo post-consulta:** Registro del estado final de atención (**Asistió** o **No asistió**) tras el horario de la consulta, con confirmación obligatoria.
  4. **[AFK] Corrección de cierre operativo:** Posibilidad de corregir un error de cierre (ej. cambiar a `Asistió`), manteniendo el evento original en auditoría y ajustando multas asociadas.
  5. **[AFK] Aplicación o perdón de multas:** Cálculo automático de multas por inasistencia o cancelación fuera de término según porcentaje configurado del valor de la consulta; registro de aplicación o perdón administrativo con fundamentación.
  6. **[AFK] Sobreturnos manuales:** Creación de turnos en modalidad de sobreturno por Secretaría o Profesional, manteniendo todas las reglas de auditoría y ciclo de vida.
- **HU/RF principales:** HU 2.3, HU 2.4, HU 3.4; RF-09, RF-14, RF-15, RF-16 bis, RF-18, RF-23.
- **Dependencias clave:** Sprints 3, 5 y 6.
- **Condición de salida:** No se pueden editar montos de multas de forma libre; el historial de reprogramaciones es trazable; la liberación de cupos es atómica.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 8 — Lista de espera: camino positivo y asignación equitativa

- **Objetivo demostrable:** Un Paciente se inscribe en la lista de espera indicando profesional, tipo de consulta, días y franjas horarias preferidas; cuando un turno se cancela o se abre un cupo compatible, el sistema selecciona automáticamente al paciente más antiguo de la cola, retiene el cupo en exclusiva durante 30 minutos y le ofrece la vacante; al aceptar, la retención se convierte en turno válido.
- **Slices candidatos:**
  1. **[AFK] Inscripción en lista de espera:** Formulario para que el Paciente o Secretaría registren una solicitud en lista de espera con preferencias de días, horarios o "Cualquier horario".
  2. **[AFK] Motor de matching de vacantes:** Algoritmo que se dispara ante liberaciones de agenda, filtra candidatos compatibles y selecciona al más antiguo con estricta equidad FIFO.
  3. **[AFK] Retención atómica de cupo por 30 minutos:** Bloqueo temporal del horario asignado para que ningún otro usuario ni el calendario público puedan reservarlo durante el período de oferta.
  4. **[AFK] Notificación de oferta de turno:** Envío de mensaje inmediato con enlace directo de confirmación y temporizador visible de expiración.
  5. **[AFK] Aceptación y conversión en reserva:** Operación que convierte la retención en un turno confirmado/reservado, actualizando la postulación en la lista de espera.
- **HU/RF principales:** RF-19, RF-23; RF-14, RF-17.
- **Dependencias clave:** Sprints 5, 6 y 7.
- **Condición de salida:** Dos pacientes nunca reciben oferta para el mismo cupo en simultáneo; la aceptación respeta todas las invariantes de creación de turnos.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 9 — Lista de espera completa, representación y gestión de personas

- **Objetivo demostrable:** La lista de espera resuelve el circuito completo de excepciones (rechazo de oferta, vencimiento del temporizador de 30 minutos con pase al siguiente de la cola, pausa automática al 3.er vencimiento y reactivación con pérdida de antigüedad); edición de preferencias; implementación de la representación legal de pacientes (padres/tutores); y gestión de bajas lógicas para Pacientes y Profesionales.
- **Slices candidatos:**
  1. **[AFK] Rechazo y vencimiento de retenciones:** Expiración controlada de ofertas no contestadas o rechazadas, liberación inmediata del cupo y notificación al siguiente candidato compatible.
  2. **[AFK] Pausa automática y reactivación:** Regla de negocio que pausa la inscripción tras tres vencimientos consecutivos; flujo de reactivación que asigna nueva antigüedad al final de la cola.
  3. **[AFK] Modificación de preferencias de espera:** Edición de franjas horarias conservando antigüedad original, o cambio de tipo de consulta con reinicio de posición bajo advertencia.
  4. **[AFK] Representación de Pacientes (HU 8.3):** Capacidad para que un adulto responsable gestione citas y perfiles de menores o personas a cargo desde su propia cuenta.
  5. **[AFK] Bajas lógicas y gestión de personas:** Desactivación lógica de pacientes y profesionales (sin borrado físico de la base de datos), impidiendo la baja de profesionales con turnos futuros asignados.
- **HU/RF principales:** HU 1.2, HU 1.3, HU 1.4, HU 4.1, HU 4.3.1, HU 4.3.2, HU 4.4, HU 8.3; RF-03, RF-05, RF-06, RF-19, RF-23; RNF-06.
- **Dependencias clave:** Sprints 2, 4 y 8.
- **Condición de salida:** Las bajas respetan la integridad referencial histórica; la representación no mezcla expedientes médicos ni accesos indebidos.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 10 — Circuito financiero administrativo y comprobantes privados

- **Objetivo demostrable:** Registro administrativo de pagos directos (efectivo, transferencia externa) sin conexión con entidades bancarias; carga de comprobantes privados con análisis antivirus, validación de tipo MIME y almacenamiento no público; visualización temporal autorizada con URLs firmadas de corta duración; gestión de saldos a favor generados por cancelaciones oportunas, compensación de multas y registro de devoluciones externas.
- **Slices candidatos:**
  1. **[AFK] Registro de pagos directos y estados financieros:** Secretaría registra pagos recibidos y actualiza el estado financiero del turno (**Pendiente**, **En revisión**, **Pagado**, **Rechazado**) sin alterar su estado operativo.
  2. **[AFK] Carga segura de comprobantes de pago:** Formulario de subida con validación estricta de extensiones/MIME, límite de tamaño (hasta 5 MB), escaneo de malware y subida a bucket privado.
  3. **[AFK] Validación y rechazo de comprobantes con auditoría:** Interfaz para que Secretaría o Administrador inspeccionen el comprobante mediante enlace firmado de corta duración y aprueben o rechacen el pago.
  4. **[AFK] Generación y administración de saldos a favor:** Creación automática de crédito a favor del paciente ante cancelación anticipada de una consulta ya pagada.
  5. **[AFK] Compensación de multas y devoluciones externas:** Uso de saldos para cancelar multas pendientes o registro administrativo de devolución monetaria externa con cierre administrativo del caso.
- **HU/RF principales:** HU 5.1, HU 5.2, HU 5.4, HU 5.5; RF-20, RF-21, RF-23; RNF-01, RNF-02.
- **Dependencias clave:** Sprints 7 y 9.
- **Condición de salida:** Ningún archivo o comprobante es accesible mediante URL pública indexable; no se manipula dinero real; toda decisión financiera queda inmutablemente auditada.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 11 — Reportes administrativos, auditoría consultable y gates de preproducción

- **Objetivo demostrable:** Generación de reportes administrativos de ingresos (indicando expresamente la carencia de valor fiscal); módulo de consulta de eventos de auditoría con filtrado por rol y auditoría de la propia consulta; cierre de brechas de accesibilidad WCAG 2.2 nivel AA; pruebas de carga y compatibilidad de navegadores; validación empírica de backups cifrados (RPO ≤ 1 h, RTO ≤ 4 h) con simulacro de restauración exitoso; y verificación de gates legales y de seguridad antes del pase a producción.
- **Slices candidatos:**
  1. **[AFK] Reportes de facturación administrativa:** Informes mensuales y anuales de montos en estado `Pagado` por profesional y totales, con marca de agua "Documento no fiscal".
  2. **[AFK] Visor de auditoría para Administrador:** Pantalla de consulta de logs de `audit_events` con filtros por fecha, actor, operación y entidad, registrando la auditoría del acceso a la consulta.
  3. **[AFK] Auditoría y adecuación de accesibilidad WCAG 2.2 AA:** Pruebas y correcciones de navegación completa por teclado, contraste cromático, etiquetas descriptivas y soporte para lectores de pantalla.
  4. **[AFK] Suite de rendimiento y matriz de navegadores:** Pruebas de estrés y carga según RNF-01..03 y verificación en Chrome, Firefox, Safari y navegadores móviles.
  5. **[HITL] Validación de seguridad, cifrado y rotación de secretos:** Verificación de cifrado TLS en tránsito, cifrado en reposo con Cloak, hashing Argon2id y política de rotación de claves.
  6. **[HITL] Simulacro formal de backups y recuperación ante desastres:** Ejecución y documentación de prueba de restauración completa de base de datos cumpliendo RPO 1 h y RTO 4 h.
  7. **[HITL] Gates legales de retención y consentimiento:** Aprobación formal de políticas de retención de datos personales y confirmación de que la salida a producción cuenta con todos los avales.
- **HU/RF principales:** HU 5.3; RF-22, RF-23; Rend-01..03; RD-01..02; RNF-03..07.
- **Dependencias clave:** Sprints 0 a 10.
- **Condición de salida:** Informe formal de simulacro de recuperación ante desastres verificado; accesibilidad AA aprobada; pase a producción bloqueado si resta cualquier gate legal o de seguridad.
- **Capacidad:** **≤128 h-equipo**.

---

### Sprint 12 (Opcional) — Contingencia técnica y colchón de estabilización

- **Objetivo demostrable:** Espacio de contingencia reservado para absorber deuda técnica no crítica, resolver defectos menores derivados de los gates de preproducción o completar ensayos de despliegue, sin incorporar bajo ninguna circunstancia alcance funcional nuevo.
- **Slices permitidas:** Únicamente tareas que hayan sido formalmente desplazadas de sprints anteriores o parches de estabilización resultantes de las pruebas de carga y accesibilidad del Sprint 11.
- **Capacidad:** **≤128 h-equipo** (sujeta a necesidad real al finalizar Sprint 11).

---

## 8. Mapa integral de dependencias entre sprints

```text
┌─────────────────────────────────────────┐
│ Sprint 0: Fundaciones Verificables     │  (Scaffold, CI, Audit append-only, Matriz v0.4, Bootstrap)
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ Sprint 1: Primera Reserva Autónoma     │  (Magic Link, Teléfono OTP, Disponibilidad, Motor Turnos, Agenda)
└─────────┬─────────────────────┬─────────┘
          │                     │
          ▼                     ▼
┌───────────────────┐ ┌───────────────────────────────────┐
│ Sprint 2:         │ │ Sprint 3:                         │
│ Identidad Interna │ │ Agenda Avanzada y Conflictos      │
│ y Sesiones        │ └─────────┬─────────────────────────┘
└─────────┬─────────┘           │
          │                     │
          ├─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     │
┌───────────────────┐ ┌───────────────────┐           │
│ Sprint 4:         │ │ Sprint 5:         │           │
│ Portal Paciente   │ │ Aprobación Manual │           │
│ e Historial       │ │ y Corte D-1       │           │
└─────────┬─────────┘ └─────────┬─────────┘           │
          │                     │                     │
          │                     ▼                     │
          │           ┌───────────────────┐           │
          │           │ Sprint 6:         │           │
          │           │ WhatsApp y Revisión│          │
          │           └─────────┬─────────┘           │
          │                     │                     │
          │                     ▼                     ▼
          │           ┌───────────────────────────────────┐
          │           │ Sprint 7:                         │
          │           │ Reprogramación, Cancelación y     │
          │           │ Cierres Operativos                │
          │           └─────────┬─────────────────────────┘
          │                     │
          ├─────────────────────┤
          │                     ▼
          │           ┌───────────────────┐
          │           │ Sprint 8:         │
          │           │ Lista de Espera   │
          │           │ Camino Positivo   │
          │           └─────────┬─────────┘
          │                     │
          ▼                     ▼
┌─────────────────────────────────────────┐
│ Sprint 9:                               │
│ Lista de Espera Completa, Representación│
│ y Bajas Lógicas                         │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ Sprint 10:                              │
│ Circuito Financiero Administrativo      │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ Sprint 11:                              │
│ Reportes, Auditoría Consultable y Gates │
└────────────────────┬────────────────────┘
                     │
                     ▼ (opcional)
┌─────────────────────────────────────────┐
│ Sprint 12: Contingencia y Estabilización│
└─────────────────────────────────────────┘
```

---

## 9. Matriz de trazabilidad: Módulos, Requisitos y Sprints

| Módulo del Sistema | Historias de Usuario (HU) | Requisitos Funcionales y No Funcionales | Sprint(s) Asignado(s) |
|---|---|---|:---:|
| **Fundaciones y Arquitectura** | — | RF-23, RNF-07, RNF-08, RD-01 | Sprint 0, Transversal, 11 |
| **Identidad y Acceso Interno** | HU 4.2, HU 7 | RF-01, RF-04, RNF-08, RNF-09 | Sprints 0, 1, 2 |
| **Acceso y Perfil del Paciente** | HU 1.1, HU 1.3, HU 8.1, HU 8.2 | RF-01, RF-02, RF-03, RF-06, RNF-10 | Sprints 1, 4 |
| **Verificación Telefónica** | HU 1.1 | RF-06, RF-17, RNF-11 | Sprints 1, 4, 6 |
| **Configuración de Agenda** | HU 3.1, HU 3.2, HU 3.3 | RF-07, RF-08, RF-10 | Sprints 1, 3 |
| **Reserva Autónoma y Motor Turnos** | HU 2.5.1, HU 2.5.2 | RF-05, RF-10, RF-14, RF-18 | Sprint 1 |
| **Operación Asistida (Secretaría)**| HU 2.1, HU 2.5.2 | RF-02, RF-05, RF-14 | Sprints 1, 2 |
| **Agenda y Turnos del Profesional** | HU 2.1, HU 2.8 | RF-05, RF-10, RF-14 | Sprints 1, 3 |
| **Aprobación Manual y Reglas D-1** | HU 2.2, HU 2.7 | RF-10, RF-10 bis, RF-11, RF-12 | Sprint 5 |
| **WhatsApp, Notificaciones y Avisos** | HU 2.10 | RF-16, RF-17, RF-18, RNF-11, Rend-03 | Sprint 6 |
| **Reprogramación, Cancelación y Cierres** | HU 2.3, HU 2.4, HU 3.4 | RF-09, RF-14, RF-15, RF-16 bis | Sprint 7 |
| **Lista de Espera y Asignación** | — | RF-14, RF-17, RF-19 | Sprints 8, 9 |
| **Gestión de Personas y Bajas Lógicas** | HU 1.2, HU 1.4, HU 4.1, HU 4.3, HU 4.4 | RF-03, RF-05, RF-06, RNF-06 | Sprints 2, 9 |
| **Representación de Pacientes** | HU 8.3 | RF-02, RF-06, RF-13 | Sprints 4, 9 |
| **Administración Financiera y Pagos** | HU 5.1, HU 5.2, HU 5.4, HU 5.5 | RF-20, RF-21, RNF-01, RNF-02 | Sprint 10 |
| **Reportes y Auditoría Consultable** | HU 5.3 | RF-22, RF-23 | Sprint 11 |
| **Gates de Seguridad, Calidad y Backup** | — | Rend-01..03, RD-01..02, RNF-03..07 | Sprint 11 |

---

## 10. Gestión de riesgos y gates de preproducción

| Riesgo Técnico o de Negocio | Impacto | Estrategia de Mitigación y Punto de Control |
|---|:---:|---|
| **Sobre-compromiso en Sprint 1** | Alto | Compromiso explícito de 150–230 h documentado. En caso de atraso, se degrada presentación visual o se desacoplan `PLN-13` y `PLN-12`, manteniendo inalterables la seguridad, verificación telefónica y transaccionalidad. |
| **Dependencia de WhatsApp API** | Alto | El Sprint 1 y los sprints iniciales desacoplan la API comercial mediante adaptadores locales en Swoosh. En Sprint 6 se integra con sandbox y webhooks; la regla de cancelación automática se condiciona estrictamente al evento `delivered`. |
| **Comprobantes de pago maliciosos** | Crítico | En Sprint 10: Validación estricta de extensiones y tipos MIME reales, análisis antivirus, almacenamiento en buckets privados sin acceso web directo y URLs firmadas con expiración de 5 minutos. |
| **Cifrado y exposición de secretos** | Crítico | Base de datos cifrada en reposo, datos sensibles con `CloakEcto`, contraseñas con `Argon2id`, llaves administradas por variables de entorno y escaneo continuo de secretos en CI. Gate evaluado en Sprint 11. |
| **Pérdida de datos / Caída del servidor** | Crítico | Gate obligatorio de Sprint 11: Backups diarios cifrados, retención de 30 días, RPO ≤ 1 h, RTO ≤ 4 h y simulación de restauración probada documentalmente antes de cualquier despliegue con datos reales. |
| **Vulneración de permisos en backend** | Crítico | Matriz de autorización centralizada en código (`security/AUTHORIZATION_MATRIX.md`). Toda acción no concedida explícitamente se deniega por defecto (*default-deny*); pruebas automatizadas de rechazo por rol. |
| **Exclusiones de accesibilidad digital** | Medio | Verificación de contraste, semántica HTML, navegación completa sin ratón y lectores de pantalla en todas las vistas públicas, cerrando brechas con estándar WCAG 2.2 AA en Sprint 11. |

---

## 11. Protocolo de recalibración y retroalimentación ágil

Al finalizar cada sprint (en la reunión de retrospectiva y revisión):

1. **Balance de compromisos:** Se cotejan las tareas planificadas contra las terminadas, desplazadas o descartadas, registrando las causas objetivas de cualquier desvío.
2. **Medición de esfuerzo real:** Se comparan las horas reales insumidas frente a los rangos estimados, alimentando la base de conocimiento para futuros refinamientos.
3. **Calidad y deuda técnica:** Se revisan defectos detectados, cobertura de pruebas, advertencias del compilador y posibles omisiones de auditoría o autorización.
4. **Ajuste de capacidad:** Se recalibra la velocidad esperada para el siguiente sprint, manteniendo el tope máximo de 128 h-equipo planificables.
5. **Reordenamiento del Backlog:** Si una tarea no terminada continúa siendo prioritaria, se refinancian sus dependencias y se replanifica en el sprint inmediato; el Sprint 12 jamás absorbe alcance nuevo.

---

## 12. Glosario de términos canónicos

| Término | Definición y regla de dominio en Origen |
|---|---|
| **Magic Link** | Enlace seguro de un solo uso enviado por correo electrónico con tiempo de expiración corto (15 min), que permite la autenticación del Paciente sin requerir contraseña. |
| **TOTP** | *Time-based One-Time Password*. Código numérico temporal de 6 dígitos generado por una aplicación autenticadora (Google Authenticator, Aegis), obligatorio para usuarios internos. |
| **D-1 / D-2** | D-1 representa el día hábil inmediato anterior a la fecha del turno; D-2 representa dos días antes. En D-1 operan los cortes de reserva y confirmación automática. |
| **Perfil Listo** | Estado del perfil de Paciente que cuenta con los datos de identidad obligatorios completos y su número telefónico verificado para autogestión. |
| **Relación Profesional–Paciente** | Vínculo de acceso en la base de datos que permite a un Profesional ver la ficha de un Paciente; nace únicamente al persistirse con éxito una primera reserva válida. |
| **Reservado** | Estado del turno que representa una reserva válida pero sujeta a confirmación posterior. Es distinto de `Confirmado`. |
| **Snapshot** | Copia histórica inmutable de los valores de un tipo de consulta (nombre, duración, precio) guardada dentro del registro del turno para protegerlo de cambios futuros. |
| **Transacción ACID** | Bloque de ejecución en la base de datos (`Ecto.Multi`) donde la creación del turno, la relación, los snapshots y la auditoría se persisten de forma atómica: todo o nada. |
| **Sobreturno** | Modalidad operativa excepcional de un turno que permite superponer horarios bajo decisión profesional explícita. No es un estado de ciclo de vida. |
| **Cierre Operativo** | Registro fáctico posterior al turno que documenta la asistencia del paciente (**Asistió**, **No asistió**, **Cancelado**). |
| **Bootstrap** | Procedimiento excepcional, seguro y auditable para crear e inicializar la primera cuenta de Administrador en el sistema. |
