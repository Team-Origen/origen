# Backend #385: pagos simples y corrección

La implementación de dominio está disponible en la cadena local de ramas indicada abajo. **Las pruebas focalizadas, la suite completa y la verificación independiente pasaron.** Este documento registra evidencia técnica, no aprobación del backend, integración de UI ni cierre de #287 o #385.

## Alcance y contrato

- Padre: [#287](https://github.com/Team-Origen/origen/issues/287).
- Backend: [#385](https://github.com/Team-Origen/origen/issues/385).
- Contrato aprobado: [#384](../contracts/384-pagos-simples-correccion.md).
- OpenSpec: `health-center-beta-core`, `openspec/changes/health-center-beta-core/`, slice 12 de 17.
- API, errores y persistencia: [SIMPLE_PAYMENTS.md](../../booking/SIMPLE_PAYMENTS.md).
- Autorización: [AUTHORIZATION_MATRIX.md](../../security/AUTHORIZATION_MATRIX.md), PAY-01 a PAY-05.

## Comportamiento implementado

| Criterio | Implementación y evidencia focalizada |
| --- | --- |
| Un pago total, efectivo o transferencia, sólo confirmado/asistido | `Booking.record_payment/3,4`; precio, actor y fecha derivados del servidor. Rechaza otros estados y segundos pagos sin reemplazar la marca. |
| Profesional propio; Secretaría todos | Sesiones revalidadas y alcance por turno. Paciente sólo consulta precio final/estado; Administrador sin acceso financiero. |
| Precio individual editable antes del pago | `Booking.update_final_price/3`; decimal finito no negativo, incluido cero. Snapshot y catálogo no cambian. Se bloquea al pagar. |
| Reversión confirmada sin motivo | `Booking.revert_payment/3,4`; exige confirmación aceptada. Devuelve a pendiente, libera precio y conserva acciones previas con importe, método, actor y fecha. |
| Cancelación y ausencia conservan pago | Probadas con operaciones reales de ciclo. Permite corregir la marca conservada, pero no pagar nuevamente en cancelado/ausente. |
| Secuencia corregir/editar/pagar | Un único pago vigente y secuencia append-only. No devolución, crédito ni traslado. |
| Atomicidad y concurrencia | Pago/acción/auditoría transaccionales; bloqueo del turno antes del pago. Conexiones PostgreSQL distintas y barreras para pago/pago, pago/precio y reversión/reversión. |
| Compatibilidad de persistencia | Campo generado leído tras escritura; limpieza de turnos sin historia financiera compatible. Acciones de pago conservan restricción de borrado y protección append-only. |

## Resultados observados

Todos los comandos usan las variables locales documentadas de test, sin persistir credenciales ni configurar servicios. El runner crea una base única y elimina sólo la base que acaba de crear. No se borraron los fixtures ni la auditoría que dejó un intento anterior en la base normal de test.

| Comprobación | Resultado |
| --- | --- |
| Comparación diferencial de reserva/cancelación contra `0f92d37` | Ambas versiones exit 0; stdout/stderr idénticos. |
| Focalizadas finales: pagos, persistencia, autorización, ciclo, concurrencia y registro profesional | 105 aprobadas, 2 omitidas; seed `691777`. Concurrencia financiera habilitada. |
| Suite completa: `bash scripts/test_payment_concurrency.sh test/` con entorno local de test | 1118 aprobadas, 35 omitidas, 8 excluidas; seed `741097`; exit 0. |
| Concurrencia financiera dentro de la suite general | Tres casos omitidos deliberadamente: se ejecutan y aprueban por separado en el bloque focalizado para no contaminar el estado compartido de otros tests. |
| Verificación independiente sobre `7d7fae7` | GREEN: compilación con advertencias como errores exit 0 (146 archivos) y runner aislado exit 0, 88 aprobadas, seed `683139`. Incluye los tres casos de concurrencia real y revisión de fuente por S1–S9/P1–P15; sin bloqueos reproducidos. |
| Preparaciones independientes previas | Dos fallas antes de ejecutar pruebas de producto, conservadas como antecedentes. El intento final usó directamente la copia aislada completa; no hubo reconstrucción ni reintentos dentro de ese intento. |

Las 35 omisiones de la suite general incluyen 32 existentes y los tres casos financieros separados. La exclusión existente `postgres_security` no fue levantada: no se afirma prueba de permisos de producción con rol PostgreSQL restringido. Se observaron advertencias de OTP 28.0/regex, uso de helper deprecado, redefinición de módulo de migración y ownership de Sandbox del worker de vencimiento; no produjeron fallas en el último run.

La revisión independiente verificó inicialización fresca mediante el runner y revisó estáticamente backfill y protección de rollback; no ejecutó una migración sobre una base existente poblada ni un rollback destructivo. La copia aislada era del snapshot `7d7fae7`; la base normal de test no se modificó.

Los fallos anteriores se conservan en el registro de trabajo; no se presentan como aprobaciones ni se sustituyen por los resultados posteriores.

## Cadena local y pendientes

| Rama | Commit de comportamiento |
| --- | --- |
| `feat/385-payment-pricing` | `7b92183` |
| `feat/385-payment-registration` | `f7fdb03` |
| `feat/385-payment-correction` | `af5b361` |
| `feat/385-payment-compatibility` | `7d7fae7` |

La cadena parte de `feat/385-simple-payments-backend` en `0f92d37`. No se realizó push, creación de PR ni merge. Los primeros bloques superan la orientación de 400 líneas para conservar juntos comportamiento, pruebas, migración y documentación; el registro detalla su carga de revisión.

La implementación y las verificaciones técnicas del backend están completas. **La aprobación explícita del backend queda a cargo del responsable y no se infiere de los resultados.** La integración de UI y el resumen económico #288 no forman parte de esta entrega. No se publicaron comentarios ni se cerraron issues.
