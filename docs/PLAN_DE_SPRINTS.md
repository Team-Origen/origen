# Plan de sprints de Origen

## Resumen ejecutivo

Este documento organiza el alcance funcional de **Origen** en doce ciclos base de dos semanas para un equipo de cuatro estudiantes. Cada ciclo se ejecuta mediante varias issues verticales, demostrables y revisables; las pruebas, permisos, auditoría y criterios de terminación forman parte de cada slice, no una etapa final separada.

La capacidad bruta es de 80 h-equipo por sprint (4 integrantes × 10 h semanales × 2 semanas). La capacidad máxima planificable es **≤64 h-equipo**: el 20 % restante se reserva para integración, reuniones, revisión y contingencias. Esta es una regla de planificación, no una promesa de entrega. La capacidad se recalibrará con evidencia al terminar el Sprint 0 y cada sprint posterior.

**Convención de numeración.** `Sprint 0` es el primer ciclo preparatorio; `Sprint 1` a `Sprint 11` completan los doce ciclos base. `Sprint 12` sería el decimotercer ciclo, opcional y exclusivo de contingencia. Esta convención evita denominarlo “Sprint 13” cuando la numeración comienza en cero.

La fuente funcional es [Origen_Documentacion.md](./Origen_Documentacion.md); este plan la referencia y no reemplaza sus reglas detalladas. Los estados y términos se interpretan según [CONTEXT.md](./CONTEXT.md).

## Alcance y no alcance

| Dentro del roadmap base | Fuera del alcance comprometido |
|---|---|
| Identidad, roles, agenda, turnos, portal de Paciente, WhatsApp, lista de espera, administración financiera, reportes y gates de preproducción documentados. | Historia clínica, diagnósticos, notas clínicas y seguimiento clínico. |
| Registros administrativos de pagos, multas, saldos, compensaciones y devoluciones externas. | Procesar, cobrar, transferir o devolver dinero real; pasarelas de pago, bancos y conciliación bancaria. |
| Comprobantes privados para validación manual. | Factura, recibo fiscal o contabilidad legal. |
| Preparación de seguridad, backups y restauración antes de producción o datos reales. | El módulo futuro de notas profesionales cifradas. |

**Límites de dominio.** `Sobreturno` es una modalidad de turno, no un estado. El cierre operativo (por ejemplo, **Asistió**, **No asistió** o **Cancelado**) es distinto del cierre administrativo (**Abierto**/**Cerrado**) y del estado financiero (**Pendiente**, **En revisión**, **Pagado**, **Rechazado** o **No corresponde**). Las transiciones aplicables permanecen definidas en RF-14, RF-16 bis y RF-20.

## Reglas de capacidad y planificación

- Sprints de 2 semanas; dedicación asumida: 10 h semanales por integrante.
- Capacidad bruta: 80 h-equipo por sprint. Capacidad máxima comprometible: **≤64 h-equipo**.
- La reserva del 20 % absorbe integración, coordinación, revisión, correcciones y contingencias; no se reasigna anticipadamente a alcance nuevo.
- Cada sprint se selecciona por dependencia y riesgo, no por reparto fijo de horas individuales.
- Cada slice se estima antes de entrar en `Ready`; si supera el margen del sprint, se divide o se desplaza. No se inventan estimaciones precisas en este mapa.
- Las integraciones externas, aprobaciones humanas y gates no se consideran capacidad garantizada.
- Tras el Sprint 0 se ajustará la previsión con velocidad observada, trabajo no planificado, bloqueos y calidad; se repite al cierre de cada sprint.

## Flujo de tablero y unidades de entrega

`Backlog -> Ready -> In Progress -> Review -> Validation -> Done`

- **Backlog:** slice aún no refinado o bloqueado.
- **Ready:** objetivo, criterios de aceptación, dependencias, permisos, auditoría y prueba enfocada definidos.
- **In Progress:** trabajo activo. WIP limitado: como norma inicial, una issue activa por integrante y ningún trabajo nuevo si `Review` o `Validation` se acumulan.
- **Review:** revisión de código y de requisitos; no se aprueba ocultando permisos solo en la interfaz.
- **Validation:** demostración funcional y evidencia de pruebas; las dependencias externas se registran explícitamente.
- **Done:** cumple la Definition of Done y no deja una condición crítica pendiente fuera de la issue.

La regla ideal es **una issue vertical por PR**. Los commits se organizan por *work unit*: cada commit entrega un comportamiento coherente, incorpora sus pruebas y permite una reversión acotada. Si un PR crece hasta dificultar la revisión, se divide en slices/PRs encadenados antes de mezclar capas inconexas.

## Definition of Done transversal por slice

Una slice alcanza `Done` únicamente si:

- entrega el comportamiento completo a través de las capas necesarias y puede demostrarse de forma independiente;
- sus criterios de aceptación y pruebas enfocadas cubren camino positivo, errores relevantes y reglas de dominio aplicables;
- el backend aplica autorización por defecto-denegar conforme a la matriz; los permisos críticos tienen prueba automatizada;
- registra los eventos de auditoría exigidos por RF-23, sin almacenar evidencia o datos prohibidos por el requisito funcional;
- conserva los términos y estados canónicos de `CONTEXT.md` y no mezcla cierre operativo, administrativo ni financiero;
- protege datos y secretos conforme a RNF-07; si utiliza mensajería o comprobantes, cumple las restricciones de minimización y privacidad;
- pasa revisión, validación y la verificación de accesibilidad, navegadores, rendimiento o integración que corresponda al riesgo de la slice;
- documenta límites, evidencia y cualquier desviación aceptada en la issue/PR.

## Redistribución del Sprint 1 histórico

El Sprint 1 histórico declaraba **176 h base**, más la reestimación pendiente de T1.2. No se ejecutará como una unidad única porque excede ampliamente la capacidad máxima planificable de 64 h-equipo y concentraba dependencias y validación al final.

| Bloque histórico | Nuevo destino principal |
|---|---|
| T1.1, T1.3 y bootstrap | Sprint 1 |
| T1.2, incluidos teléfono y alertas internas | Sprint 1, con reestimación explícita |
| T1.5, T1.5.1 y T1.6.1 | Sprint 2 |
| T1.6 y T1.7 | Sprint 3 |
| T1.8 y automatización real de WhatsApp | Sprint 6 |
| T1.4, T1.9 y T1.10 | Listados en Sprint 9; calidad y DoD dentro de todas las slices desde Sprint 0 |

La redistribución preserva la cadena funcional: primer turno interno antes de que el Profesional pueda crear turnos posteriores; el flujo de WhatsApp se completa cuando existan los estados, cortes y revisiones que requiere.

## Roadmap base

### Sprint 0 — Fundaciones verificables

El detalle de ejecución y el cierre histórico de este ciclo se conservan en [sprints/SPRINT_00.md](./sprints/SPRINT_00.md); este roadmap mantiene el alcance y las dependencias.

**Objetivo demostrable.** Repositorios, arquitectura mínima, CI, auditoría transversal y matriz de autorización permiten iniciar slices sensibles con controles revisables.

**Slices candidatos**

1. **[HITL] Acordar stack, repositorios y reglas de entrega:** decisión registrada, ramas/reglas y secretos fuera del repositorio.
2. **[AFK] Inicializar esqueleto web, API, base de datos y pipeline de integración.**
3. **[AFK] Implementar auditoría inmutable mínima:** actor, operación, fecha y hora del servidor para una operación de referencia.
4. **[HITL] Aprobar matriz única de autorización y denegación por defecto.**
5. **[AFK] Preparar bootstrap del primer Administrador con invitación de un solo uso y auditoría.**

**HU/RF principales.** RF-01, RF-04, RF-23; RNF-07, RNF-08; RD-01.  
**Dependencias clave.** Decisiones de equipo y acceso a repositorios.  
**Condición de salida.** Existe un camino demostrable de despliegue local/integración, una matriz aprobada para operaciones sensibles y evidencia de auditoría del bootstrap.  
**Capacidad.** **≤64 h-equipo**. Reestimar CI y alcance del armazón tras elegir el stack.

### Sprint 1 — Identidad interna y altas administrativas

**Objetivo demostrable.** Un Administrador activa y autentica Usuarios Internos, da de alta un Profesional y Secretaría registra un Paciente con teléfono pendiente o verificado, respetando permisos y auditoría.

**Slices candidatos**

1. **[AFK] Activar cuenta interna por invitación:** contraseña, enrolamiento TOTP, transición de **Pendiente de activación** a **Activa** y auditoría.
2. **[AFK] Iniciar sesión interna y gestionar sesión:** credenciales, TOTP, expiración, inactividad y reautenticación para acciones sensibles.
3. **[AFK] Alta administrativa de Profesional:** unicidad, estado **Pendiente de activación** e invitación de un solo uso.
4. **[AFK] Alta administrativa de Paciente:** datos obligatorios, unicidad, teléfono no verificado y advertencia operativa.
5. **[AFK] Verificar teléfono del Paciente:** código, fallos auditados y habilitación de automatizaciones/autogestión al validar.

**HU/RF principales.** HU 7, HU 4.2, HU 1.1; RF-01, RF-02, RF-04, RF-06, RF-23; RNF-08, RNF-09.  
**Dependencias clave.** Sprint 0; servicio o mecanismo de envío de códigos definido para el entorno.  
**Condición de salida.** Las cuentas internas solo acceden cuando están **Activas** y un Paciente dado de alta puede permanecer gestionable internamente con teléfono no verificado.  
**Capacidad.** **≤64 h-equipo**. **T1.2 (alta y verificación telefónica) conserva reestimación obligatoria**: proveedor, reintentos, límites y auditoría pueden alterar el tamaño real.

### Sprint 2 — Configuración de agenda y primer turno interno

**Objetivo demostrable.** Un Profesional configura tipos de consulta y disponibilidad; Secretaría crea el primer turno válido para un Paciente y establece la relación Profesional–Paciente.

**Slices candidatos**

1. **[AFK] Gestionar tipos de consulta:** nombre, duración y precio base; snapshot inmutable al crear un turno.
2. **[AFK] Configurar disponibilidad y editar la ventana de reserva:** horarios, ausencias, bloqueos y período disponible para reservas futuras, sin alterar turnos automáticamente.
3. **[AFK] Detectar conflictos de disponibilidad:** impedir guardar cambios que afecten turnos futuros activos hasta resolverlos individualmente.
4. **[AFK] Crear primer turno por Secretaría:** Paciente, Profesional, tipo y horario sin superposiciones; estado explícito y auditoría.
5. **[AFK] Crear la relación Profesional–Paciente desde el primer turno y exponer agenda diaria mínima.**

**HU/RF principales.** HU 3.1, HU 3.2, HU 3.3, HU 2.5.2, HU 2.1; RF-05, RF-07, RF-08, RF-10, RF-14, RF-18, RF-23.  
**Dependencias clave.** Sprint 1; matriz de autorización.  
**Condición de salida.** Secretaría puede generar una reserva estándar válida y el Profesional visualiza ese turno; el tipo queda preservado como snapshot.  
**Capacidad.** **≤64 h-equipo**. Reestimar detección de conflictos, duración de bloques y comportamiento D-1 antes de comprometer slices adicionales.

### Sprint 3 — Operación del Profesional y cierre operativo básico

**Objetivo demostrable.** El Profesional opera solo sobre Pacientes vinculados, crea turnos posteriores en su agenda, consulta sus turnos y registra un cierre operativo básico auditado.

**Slices candidatos**

1. **[AFK] Crear turno posterior por Profesional para Paciente vinculado:** disponibilidad, no superposición y estado inicial según D-1.
2. **[AFK] Denegar selección y navegación global de Pacientes al Profesional.**
3. **[AFK] Consultar agenda diaria con estados operativos y datos permitidos.**
4. **[AFK] Listar turnos propios por Paciente/rango sin exponer relaciones ajenas.**
5. **[AFK] Registrar cierre operativo básico:** **Asistió** o **No asistió** tras el horario, con confirmación humana y auditoría; sin multa automática.

**HU/RF principales.** HU 2.1, HU 2.2, HU 2.5.3, HU 2.8; RF-05, RF-10, RF-14, RF-23.  
**Dependencias clave.** Sprint 2 y relación Profesional–Paciente existente.  
**Condición de salida.** El Profesional no puede operar fuera de su alcance y puede cerrar operativamente un turno elegible sin confundirlo con cierre administrativo o financiero.  
**Capacidad.** **≤64 h-equipo**. Reestimar correcciones de cierre y reglas D-1 si se incluyen en el mismo ciclo.

### Sprint 4 — Acceso y perfil del Paciente

**Objetivo demostrable.** Un Paciente accede por Google OAuth o Magic Link, completa su cuenta y solo queda **Activa** para autogestión al validar los datos y el teléfono requeridos.

**Slices candidatos**

1. **[AFK] Acceder con Google OAuth para Paciente nuevo:** configurar el proveedor y su sandbox como parte de esta primera slice consumidora, detrás de un límite o adaptador y con credenciales fuera del repositorio; crear cuenta **Pendiente de completar** sin habilitar reserva.
2. **[AFK] Vincular Google con ficha existente:** validar DNI y fecha de nacimiento, sin duplicados ante discrepancia.
3. **[AFK] Acceder con Magic Link:** emisión, expiración, uso único y respuesta no enumeradora.
4. **[AFK] Completar y editar perfil de Paciente:** validaciones, cambio de correo verificado y permisos de Secretaría.
5. **[AFK] Cambiar teléfono de forma segura:** suspender mensajes al número anterior, señalizar turnos próximos y reactivar solo tras validar.
6. **[AFK] Consultar Mis Turnos:** mostrar al Paciente sus turnos próximos y pasados con fecha, horario, Profesional y estado operativo/administrativo/financiero permitido.

**HU/RF principales.** HU 8.1, HU 8.2, HU 1.3, HU 2.9; RF-01, RF-02, RF-03, RF-06, RF-13, RF-23; RNF-10.  
**Dependencias clave.** Sprint 1 y mecanismo de correo; la configuración y el sandbox de Google se resuelven dentro de la primera slice de Google OAuth, no como dependencia entregada por Sprint 0.  
**Condición de salida.** No se crean duplicados por OAuth; una cuenta **Pendiente de completar** no puede reservar hasta estar **Activa** y tener teléfono verificado, y un Paciente autenticado consulta su historial operativo y administrativo sin contenido clínico.  
**Capacidad.** **≤64 h-equipo**. Reestimar integración de Google, correo transaccional y cambio de teléfono según límites de proveedor.

### Sprint 5 — Reserva autónoma y aprobación

**Objetivo demostrable.** Un Paciente activo reserva desde el calendario solo un horario elegible; el estado inicial respeta D-1 y la modalidad de aprobación del Profesional.

**Slices candidatos**

1. **[AFK] Mostrar calendario de disponibilidad real para Paciente.**
2. **[AFK] Reservar turno autónomamente:** bloqueo por teléfono no verificado, superposición y horario ocupado.
3. **[AFK] Aplicar corte D-1 y estado inicial:** **Solicitado**, **Reservado** o **Confirmado** según la regla aplicable.
4. **[AFK] Aprobar solicitud manual del Profesional:** transición correcta antes y durante D-1.
5. **[AFK] Mostrar límite de cancelación y política de multa antes de confirmar.**

**HU/RF principales.** HU 2.5.1, HU 2.7; RF-10, RF-10 bis, RF-11, RF-12, RF-14, RF-18.  
**Dependencias clave.** Sprints 2 y 4; configuración de disponibilidad y cuenta de Paciente **Activa**.  
**Condición de salida.** Una reserva autónoma no vulnera disponibilidad ni reglas D-1 y deja el turno en el estado canónico correspondiente.  
**Capacidad.** **≤64 h-equipo**. Reestimar concurrencia de reserva y la interacción entre aprobación, disponibilidad y liberación de agenda.

### Sprint 6 — Confirmación y WhatsApp

**Objetivo demostrable.** Las reservas sujetas al flujo reciben recordatorios D-2/D-1 y su confirmación, cancelación automática o revisión urgente se resuelve usando evidencia `delivered`.

**Slices candidatos**

1. **[AFK] Encolar recordatorios D-2/D-1 con contenido minimizado y exclusión de teléfonos no verificados.**
2. **[AFK] Registrar callbacks `sent`, `delivered` y `failed`; tratar estado desconocido como entrega no comprobada.**
3. **[AFK] Confirmar asistencia desde el flujo de WhatsApp y transicionar a `Confirmado`.**
4. **[AFK] Cancelar automáticamente a las 18:00 D-1 solo con al menos una entrega `delivered`, liberando agenda.**
5. **[AFK] Gestionar revisión urgente:** contacto manual declarado, transición a **Confirmado**/**Cancelado**, o permanencia en **Reservado** sin resolución automática.

**HU/RF principales.** HU 2.10; RF-16, RF-17, RF-18, RF-23; RNF-11; Rend-03.  
**Dependencias clave.** Sprints 1, 2 y 5; cuenta/proveedor WhatsApp, webhooks y plantillas aprobadas si aplican.  
**Condición de salida.** La cancelación automática nunca se basa solo en `sent`; los casos sin entrega comprobada quedan visibles para revisión urgente y auditados.  
**Capacidad.** **≤64 h-equipo**. Reestimar aprobaciones de WhatsApp, webhooks, pruebas de tiempo y diferencias sandbox/producción.

### Sprint 7 — Reprogramación, cancelación y consecuencias administrativas

**Objetivo demostrable.** El equipo puede reprogramar o cancelar sin perder trazabilidad, cerrar asistencia/ausencia y administrar multas, descuentos y sobreturnos sin afirmar un cierre financiero completo.

**Slices candidatos**

1. **[AFK] Reprogramar turno confirmado:** decisión “Acordado con el paciente” o “Requiere confirmación” con regla de 24 horas.
2. **[AFK] Cancelar turno de forma unificada:** motivo, estado previo, liberación inmediata y auditoría.
3. **[AFK] Corregir `Asistió`/`No asistió`:** motivo obligatorio, conservación del cierre original y anulación de multa pendiente cuando corresponda.
4. **[AFK] Decidir aplicar o perdonar multa elegible:** cálculo por porcentaje configurado, sin monto manual ni aplicación automática.
5. **[AFK] Aplicar descuento o propuesta de aumento de precio en turno no Pagado.**
6. **[AFK] Crear sobreturno manual compatible con el ciclo de vida del turno.**

**HU/RF principales.** HU 2.3, HU 2.4, HU 3.4; RF-09, RF-14, RF-15, RF-16 bis, RF-18, RF-23.  
**Dependencias clave.** Sprints 3, 5 y 6.  
**Condición de salida.** Los motivos, transiciones y elegibilidad de multa se conservan; `Sobreturno` no se representa como estado. El cierre administrativo/financiero completo queda para Sprint 10.  
**Capacidad.** **≤64 h-equipo**. Reestimar combinaciones de cancelación, multa, pago previo y reprogramación antes de comprometer todas las variantes.

### Sprint 8 — Lista de espera: camino positivo

**Objetivo demostrable.** Un Paciente elegible se inscribe con preferencias y recibe una única oferta compatible; la retención se convierte en turno tras aceptación.

**Slices candidatos**

1. **[AFK] Inscribir en lista de espera por Profesional con tipo, días y franjas o “Cualquier horario”.**
2. **[AFK] Aplicar permisos de alta/edición inicial para Paciente, Secretaría y Profesional vinculado.**
3. **[AFK] Evaluar elegibilidad y seleccionar el Paciente compatible más antiguo sin alterar la cola.**
4. **[AFK] Retener un único cupo durante 30 minutos y excluirlo de otras reservas/ofertas.**
5. **[AFK] Aceptar oferta y convertir retención en turno según el flujo aplicable.**

**HU/RF principales.** RF-19, RF-23; RF-14 y RF-17 cuando la conversión exige sus flujos.  
**Dependencias clave.** Sprints 5 y 6; liberación de agenda confiable.  
**Condición de salida.** Nunca se ofrecen simultáneamente el mismo cupo a dos Pacientes y la aceptación no pierde preferencia, trazabilidad ni reglas de turno.  
**Capacidad.** **≤64 h-equipo**. Reestimar temporizadores, concurrencia de retención y canal de oferta.

### Sprint 9 — Lista de espera completa y gestión de personas

**Objetivo demostrable.** La lista de espera resuelve rechazo, vencimiento, pausa y reactivación; los roles autorizados completan ediciones, bajas, listados y búsquedas de Pacientes y Profesionales dentro del alcance documentado.

**Slices candidatos**

1. **[AFK] Rechazar o vencer una oferta:** liberar retención y continuar con el siguiente elegible sin penalización.
2. **[AFK] Pausar al tercer vencimiento consecutivo y reactivar con nueva antigüedad/posición.**
3. **[AFK] Editar preferencias:** preservar antigüedad salvo cambio de tipo de consulta, con advertencia y confirmación.
4. **[AFK] Gestionar baja lógica y modificación de Paciente sin eliminación/anonimización automática.**
5. **[AFK] Listar y buscar Pacientes para Secretaría; listar Profesionales activos para Administrador.**
6. **[AFK] Gestionar perfiles de Profesional:** Administrador modifica, reactiva o da de baja con restricciones por turnos futuros; el propio Profesional solo modifica sus campos autorizados.

**HU/RF principales.** HU 1.2, HU 1.3, HU 1.4, HU 4.1, HU 4.3.1, HU 4.3.2, HU 4.4; RF-03, RF-05, RF-06, RF-19, RF-23; RNF-06.  
**Dependencias clave.** Sprints 1, 4 y 8; política de autorización vigente.  
**Condición de salida.** La cola conserva correctamente antigüedad, preferencias y pausas; las bajas son lógicas y no eliminan automáticamente registros protegidos.  
**Capacidad.** **≤64 h-equipo**. Reestimar filtros/listados, restricciones de baja y transiciones de lista de espera antes de seleccionar la ola.

### Sprint 10 — Circuito financiero administrativo

**Objetivo demostrable.** Se registran pagos y comprobantes privados; se validan/rechazan estados financieros y se administran saldos, compensaciones y devoluciones externas como registros, sin movimiento de dinero.

**Slices candidatos**

1. **[AFK] Registrar pago directo y estados financieros de consulta sin modificar el estado operativo.**
2. **[AFK] Cargar comprobante privado:** formatos permitidos, tamaño, validación real, análisis de malware y acceso autorizado.
3. **[AFK] Validar o rechazar comprobante y auditar carga, análisis, accesos y decisión.**
4. **[AFK] Generar saldo a favor tras cancelación sin penalización de consulta Pagada.**
5. **[AFK] Compensar administrativamente multa contra saldo o perdonarla, manteniendo trazabilidad separada.**
6. **[AFK] Registrar devolución externa por Secretaría y actualizar cierre administrativo cuando no queden obligaciones.**

**HU/RF principales.** HU 5.1, HU 5.2, HU 5.4, HU 5.5; RF-20, RF-21, RF-23; RNF-01, RNF-02.  
**Dependencias clave.** Sprint 7, almacenamiento privado, análisis de malware y validación legal/contable pendiente.  
**Condición de salida.** Cada estado financiero, multa, saldo y devolución queda separado y auditado; no existe integración que mueva dinero ni URL pública permanente para comprobantes.  
**Capacidad.** **≤64 h-equipo**. Reestimar análisis de malware, almacenamiento seguro, retención y casos de cancelación de pagos previos.

### Sprint 11 — Reportes y gates de preproducción

**Objetivo demostrable.** El producto ofrece reportes y auditoría consultable con permisos, y reúne evidencia de calidad, seguridad, recuperación y compatibilidad necesaria para evaluar preproducción.

**Slices candidatos**

1. **[AFK] Generar reportes administrativos de importes `Pagado` por mes/año, sin presentarlos como documentos fiscales.**
2. **[AFK] Consultar auditoría con alcance por rol y auditar la propia consulta.**
3. **[AFK] Cerrar brechas de accesibilidad WCAG 2.2 AA en pantallas principales y flujos críticos.**
4. **[AFK] Ejecutar matriz de navegadores, rendimiento y carga definida para preproducción.**
5. **[HITL] Validar cifrado, secretos, rotación y evidencia de backups/restauración.**
6. **[HITL] Aprobar gates legales/contables de retención, eliminación o anonimización y retención de auditoría/comprobantes.**

**HU/RF principales.** HU 5.3; RF-22, RF-23; Rend-01, Rend-02, Rend-03; RD-01, RD-02; RNF-03 a RNF-07.  
**Dependencias clave.** Sprints 0 a 10 y decisiones externas/legal-contables.  
**Condición de salida.** Existe evidencia consultable de los gates aplicables; la salida a producción sigue bloqueada si faltan aprobación legal/contable, cifrado, backups o restauración probada.  
**Capacidad.** **≤64 h-equipo**. Reestimar correcciones de accesibilidad/rendimiento, infraestructura de backup y tiempos de validación externa.

### Sprint 12 opcional — Contingencia sin alcance nuevo

**Objetivo demostrable.** Absorber trabajo desplazado, defectos o riesgos externos priorizados sin incorporar funcionalidades nuevas.

**Slices candidatos.** Solo slices ya aprobadas y desplazadas de Sprints 0–11, correcciones derivadas de gates, endurecimiento de integración externa o evidencia pendiente de validación.  
**HU/RF principales.** Los de las slices arrastradas; no crea cobertura nueva.  
**Dependencias clave.** Evidencia de cierre de los sprints base y priorización explícita.  
**Condición de salida.** Se reduce riesgo pendiente o se documenta formalmente el bloqueo restante; no se amplía el alcance.  
**Capacidad.** **≤64 h-equipo**. Se determina después de medir la capacidad real de los sprints base.

## Mapa de dependencias entre sprints

```text
S0 Fundaciones
 └─> S1 Identidad interna y altas
      ├─> S2 Agenda y primer turno interno ─> S3 Operación Profesional
      │                                      └─> S7 Reprogramación/cancelación/multas
      └─> S4 Acceso y perfil Paciente ─> S5 Reserva autónoma ─> S6 WhatsApp
                                            └─> S8 Lista de espera positiva ─> S9 Lista completa
S7 + S9 ─> S10 Administración financiera ─> S11 Reportes y gates
S0–S11 ─> S12 contingencia opcional
```

Las dependencias representan el orden preferente de capacidad y riesgo; una slice puede adelantarse solo si conserva sus precondiciones, autorización y criterios de Done.

## Trazabilidad de módulos y HU/RF

| Módulo | HU principales | RF/RNF principales | Sprint(s) |
|---|---|---|---|
| Fundaciones, seguridad y auditoría | — | RF-23, RNF-07, RNF-08 | 0, transversal, 11 |
| Usuarios internos y Profesionales | HU 7, 4.2 | RF-01, RF-04, RNF-09 | 1 |
| Pacientes y teléfono | HU 1.1 | RF-02, RF-06 | 1 |
| Agenda y primer turno interno | HU 3.1, 3.2, 3.3, 2.5.2, 2.1 | RF-05, RF-07, RF-08, RF-10, RF-14 | 2 |
| Operación del Profesional | HU 2.1, 2.2, 2.5.3, 2.8 | RF-05, RF-14 | 3 |
| Acceso, perfil e historial del Paciente | HU 8.1, 8.2, 1.3, 2.9 | RF-01, RF-02, RF-03, RF-13, RNF-10 | 4 |
| Reserva autónoma y aprobación | HU 2.5.1, 2.7 | RF-10, RF-10 bis, RF-11, RF-12 | 5 |
| WhatsApp y confirmación | HU 2.10 | RF-16, RF-17, RF-18, RNF-11 | 6 |
| Cambios de turno y multas | HU 2.3, 2.4, 3.4 | RF-09, RF-14, RF-15, RF-16 bis | 7 |
| Lista de espera | — | RF-19, RF-23 | 8–9 |
| Gestión de personas y listados | HU 1.2, 1.3, 1.4, 4.1, 4.3.1, 4.3.2, 4.4 | RF-03, RF-06, RNF-06 | 9 |
| Finanzas y comprobantes | HU 5.1, 5.2, 5.4, 5.5 | RF-20, RF-21, RNF-01, RNF-02 | 10 |
| Reportes y preproducción | HU 5.3 | RF-22, Rend-01..03, RD-01..02, RNF-03..07 | 11 |

## Riesgos y gates

| Riesgo o gate | Tratamiento y punto de control |
|---|---|
| **T1.2: verificación telefónica** | Reestimar explícitamente en Sprint 1 con evidencia de proveedor, límites, reintentos, fallos y auditoría; no absorber el incremento sin desplazar alcance. |
| Google OAuth y Magic Link | Al comenzar la primera slice consumidora de Google OAuth en Sprint 4, configurar proveedor y sandbox detrás de un límite o adaptador y con credenciales fuera del repositorio; probar allí errores, vinculación de cuenta existente y dependencias de correo. |
| WhatsApp | Validar cuenta, webhooks, estados y plantillas; `delivered`, no `sent`, es la evidencia mínima para la regla de cancelación. Riesgo principal de Sprint 6. |
| Comprobantes | Confirmar almacenamiento privado, validación de contenido, análisis de malware, acceso temporal autorizado y auditoría antes de comprometer carga real. |
| Cifrado y secretos | Gate de preproducción: TLS, cifrado en reposo de base, backups y comprobantes; hashes de contraseñas; secretos fuera del código y capacidad de rotación. |
| Backups/restauración | Antes de producción o datos reales: backups cifrados, retención de 30 días, RPO 1 h, RTO 4 h y restauración mensual probada. |
| Retención/eliminación | Validación legal y contable obligatoria para datos personales, log de auditoría y comprobantes. Hasta aprobarla no hay eliminación/anonimización automática y producción queda bloqueada. |
| Carga académica | La disponibilidad real puede variar por exámenes y entregas. Proteger el 20 %, limitar WIP, dividir slices y usar Sprint 12 solo para arrastre/riesgo. |
| Permisos y privacidad | Revisar matriz antes de módulos sensibles; el backend es autoridad y cada denegación relevante debe poder probarse. |

## Recalibración al finalizar cada sprint

1. Comparar slices comprometidas, terminadas, desplazadas y descartadas; registrar causa de cada desvío.
2. Medir horas reales, tiempo de revisión/validación, bloqueos externos, defectos y trabajo no planificado.
3. Revisar calidad: pruebas fallidas, cobertura de permisos/auditoría, deuda y evidencia faltante.
4. Ajustar la capacidad máxima del siguiente sprint sin superar **64 h-equipo** hasta que la evidencia justifique otro límite.
5. Reordenar el backlog por dependencia y riesgo; dividir slices demasiado grandes y confirmar que el Sprint 12 no absorba alcance nuevo.
6. Comunicar la previsión revisada y los gates pendientes antes de mover slices a `Ready`.

## Siguiente paso

1. Aprobar la granularidad de las slices y sus dependencias.
2. Redactar las issues por olas, empezando por Sprint 0 y Sprint 1, con criterios de aceptación, bloqueos y evidencia de Done.
3. Publicarlas únicamente después de esa aprobación; **este documento no publica issues ni las deja creadas**.
