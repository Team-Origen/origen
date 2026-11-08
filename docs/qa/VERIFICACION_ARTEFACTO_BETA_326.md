# #326 — Verificación de la definición de aceptación beta

**Objeto:** contrastar el [contrato aprobado en #325](ACEPTACION_ENTREGA_BETA.md) con los criterios de [#290](https://github.com/Team-Origen/origen/issues/290), [#266](https://github.com/Team-Origen/origen/issues/266), la [proposal](../../openspec/changes/health-center-beta-core/proposal.md), el [diseño](../../openspec/changes/health-center-beta-core/design.md), [beta-boundaries](../../openspec/changes/health-center-beta-core/specs/beta-boundaries/spec.md) y la [guía](../sprints/GUIA_TRABAJO_BETA.md).

**Frontera:** se verifica la *definición* de criterios y recibos, no su ejecución ni la aceptación final de la beta. Las exclusiones normativas no se transforman en funcionalidades y las decisiones pendientes no se inventan. La proposal describe código histórico; su diagnóstico inicial no prevalece sobre implementaciones posteriores.

## Matriz de cobertura documental

| Criterio de #290 / fuente | Sección del contrato | Control de definición y resultado observado | Ejecución de entrega |
| --- | --- | --- | --- |
| Manual de usuario | Resultado 1 | Roles, acceso, recorridos, errores, versión y lectura guiada tienen criterio y recibo previstos. Referencia visual reconciliada con #274 (H1). | No ejecutada. |
| Datos ficticios por flujos reales | Resultado 2 | Exige creación por producto, alias sanitizados y consulta posterior tras recarga/reingreso; prohíbe acreditar con SQL, mocks o fixtures. Definición presente. | No ejecutada. |
| Funcionalidad y permisos | Resultado 3 | Matriz de capacidades beta, rechazos de backend, sesiones inválidas, privacidad entre roles, no parciales y evidencia versionada. Definición presente. | No ejecutada. |
| Acceso en nube, exigido por #266/proposal | Resultado 4 | Entorno, versión, acceso remoto, autenticación y persistencia con recibo previsto. Fecha #275 diferenciada de decisiones y ejecución #292 (H2). | No ejecutada. |
| Condiciones docentes | Resultado 5 | Acuerdo, autoría, versión, condiciones y comprobaciones futuras previstos; #275 sólo resuelve fecha, sin inventar hosting o condiciones (H2). | No ejecutada. |
| Estabilización de dos semanas | Resultado 6 | Ventana acordada, incidencias, regresiones, observación y evaluación final previstos; planificarla no equivale a cumplirla. Definición presente. | No ejecutada. |
| Separación definición/ejecución | Encabezado, estados de evidencia, recibo y aprobación | Seis estados iniciales «no ejecutado», formato de recibo y distinción entre aprobación de contrato y entrega final. Definición presente. | No ejecutada. |

## Hallazgos reconciliados en esta entrega

- **H1 — Identidad visual:** el contrato trataba [#274](https://github.com/Team-Origen/origen/issues/274#issuecomment-6691979001) como decisión abierta, aunque la decisión quedó registrada y [sus recursos entraron en `develop` por #416](https://github.com/Team-Origen/origen/issues/274#issuecomment-6693530572). Se actualizó la referencia; #291 sigue abierta y no se afirma que el manual final ni la aplicación estén aceptados.
- **H2 — Fecha frente a infraestructura:** el contrato trataba [#275](https://github.com/Team-Origen/origen/issues/275#issuecomment-6691042373) como abierta y le atribuía hosting, presupuesto y condiciones docentes. Se corrigió para representar sólo la consulta cerrada de fecha de primera entrega académica (sin agregar año); [#292](https://github.com/Team-Origen/origen/issues/292) conserva decisiones técnicas, despliegue y aceptación de acceso. No se presume proveedor, presupuesto ni entrega ejecutada.

**Control documental:** se resolvieron 15 enlaces relativos del contrato y cinco de esta matriz; se encontraron seis resultados y seis estados iniciales «no ejecutado». Las fuentes históricas de OpenSpec conservan su fecha y no se reescriben retroactivamente. No se ejecutaron recorridos de producto ni pruebas funcionales de la beta. La aprobación explícita de la definición de #290 y el cierre de #326 requieren decisión posterior.
