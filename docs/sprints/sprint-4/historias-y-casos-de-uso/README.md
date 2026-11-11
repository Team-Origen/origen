# Historias de usuario y casos de uso — entrega Sprint 4

Entregable documental de la issue #466. Complementa el manual de usuario de #405 sin duplicarlo: aquí se describe **qué puede hacer cada rol y con qué reglas**, no cómo se recorre cada pantalla.

## Contenido

| Archivo | Qué contiene |
| --- | --- |
| [historias-de-usuario.md](./historias-de-usuario.md) | Historias «Como [rol], quiero…, para…» de lo implementado hasta Sprint 4, con criterios de aceptación y referencias. Al final, lo pendiente y lo excluido. |
| [casos-de-uso.md](./casos-de-uso.md) | Criterio de selección y organización de los diagramas, y los diagramas de casos de uso (Mermaid) general y por rol. |
| [discrepancias.md](./discrepancias.md) | Diferencias detectadas entre contratos, documentación e implementación, registradas sin resolver. |

Los diagramas están escritos en Mermaid y GitHub los renderiza al abrir el archivo. Para exportarlos como imagen se puede usar [Mermaid Live](https://mermaid.live) o `mmdc` (Mermaid CLI).

## Versión y fecha de corte

- **Referencia evaluada:** rama `develop` en el commit `0c38d8a` (merge de la PR #485), del **2026-11-11**.
- Se considera **implementado** lo que tiene contrato o especificación vigente, código en `develop` y evidencia de integración o pruebas. Una issue cerrada como *mock* de interfaz no cuenta como funcionalidad disponible.
- No se ejecutaron pruebas ni se recorrió la aplicación en navegador para este relevamiento; las cifras de pruebas citadas en las referencias son las que declaran los documentos de integración.

## Método de relevamiento

1. **Sprint de cada funcionalidad:** se usó el *milestone* de GitHub de la issue que la entrega (`Sprint 0 - Foundations` … `Sprint 4 — Operación y beta integrada`). No existen etiquetas `sprint:N`. En Sprint 3 y 4 cada funcionalidad tiene una issue padre `[Plan]: …` y cuatro hijas (Contrato, Backend, Interfaz, Integración y verificación).
2. **Fuentes, en orden de autoridad:** contratos (`docs/sprints/contracts/`, `docs/sprints/sprint-3/`, `docs/sprints/sprint-4/`), especificaciones OpenSpec (`openspec/specs/`, `openspec/changes/health-center-beta-core/`), documentos de integración y evidencia (`docs/sprints/integration/`, `docs/sprints/evidence/`), código (`lib/`) y estado de las issues.
3. **Punto de partida de las historias:** `docs/Origen_Documentacion.md` (sección «Historias de Usuario»). Se reescribieron las historias para que describan el comportamiento vigente de la beta; cuando el documento original especifica algo distinto (Google OAuth, D-1, WhatsApp, multas, representación, etc.) se registró en [discrepancias.md](./discrepancias.md) en lugar de presentarlo como disponible.
4. **Diagramas:** se elaboraron desde cero sobre la base de las historias; no se localizó en el repositorio material histórico de diagramas de casos de uso.

## Revisión de consistencia con el manual de usuario (#405)

Al corte, #405 sigue abierta y el manual no está disponible, por lo que la comprobación de consistencia queda **pendiente**. Cuando el manual exista, verificar que:

- los roles, nombres de secciones de la navegación y estados del turno coincidan con los de estas historias;
- el manual no presente como disponibles el resumen económico ni los pagos (hoy son maquetas con datos ficticios, ver HU pendientes);
- las reglas de cancelación, aprobación de solicitudes y asistencia coincidan con los criterios de aceptación.

## Cobertura de los criterios de aceptación de #466

| Criterio | Dónde se cubre |
| --- | --- |
| Historias de lo implementado hasta Sprint 4 por rol | [historias-de-usuario.md](./historias-de-usuario.md), secciones 1 a 5 |
| Rol, capacidad, objetivo y criterios por historia | Cada historia |
| Criterio de selección y organización de los diagramas | [casos-de-uso.md](./casos-de-uso.md), sección 1 |
| Diagramas con actores y el mismo alcance que las historias | [casos-de-uso.md](./casos-de-uso.md), secciones 2 a 7 y tabla de trazabilidad |
| Diagramas enfocados en interacciones, no en pantallas | [casos-de-uso.md](./casos-de-uso.md), sección 1 |
| Consistencia con reglas de negocio y permisos | Criterios de aceptación y reglas transversales |
| Referencias a issues y contratos | Columna «Referencias» de cada historia |
| Pendiente o excluido no presentado como disponible | [historias-de-usuario.md](./historias-de-usuario.md), sección 6 |
| Discrepancias registradas sin resolver | [discrepancias.md](./discrepancias.md) |
| Versión o fecha de corte | Este archivo, «Versión y fecha de corte» |
| Formato y dónde consultar | Este archivo |
| Word fuera del repositorio | No se generó Word |
| Consistencia con #405 | Este archivo, revisión pendiente hasta que exista el manual |
