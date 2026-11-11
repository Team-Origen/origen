# Pagos simples: precio final, registro y corrección

T1 agrega la base persistida y autorizada para pagos simples; T2 agrega el
registro total. Cada turno conserva su snapshot histórico, un precio final
editable independiente y una fila de pago inicialmente `pending`. La corrección
revierte una marca pagada sin representar una devolución ni crear resumen económico.

## Recorrido disponible

1. `Origen.Booking.get_payment/2` devuelve la proyección financiera autorizada.
2. `Origen.Booking.update_final_price/3` cambia el precio final de un turno impago.
3. `Origen.Booking.record_payment/3` registra un único total en efectivo o transferencia para un turno `confirmed` o `attended`.
4. `Origen.Booking.revert_payment/4` revierte una marca pagada sólo con confirmación explícita `true`, conserva su acción y habilita corregir el precio.
5. `Origen.Booking.list_payment_actions/2` devuelve la historia interna sólo a Profesional dentro de su agenda y Secretaría del centro.
6. Profesional opera sólo su agenda; Secretaría opera todas; Paciente sólo lee
   precio final y estado; Administrador no tiene acceso financiero.

## Contrato de la interfaz pública

```elixir
Origen.Booking.get_payment(principal, appointment_id)
# {:ok, %{appointment_id: id, final_price_ars: decimal, payment_status: "pending"}}
# para Paciente; el personal recibe además el estado actual y sus metadatos
# de pago cuando existan.

Origen.Booking.update_final_price(principal, appointment_id, value)
# {:ok, %{appointment_id: id, final_price_ars: decimal, payment_status: "pending"}}

Origen.Booking.record_payment(principal, appointment_id, method)
# method: "cash" | "transfer" (también acepta los átomos :cash | :transfer)
# {:ok, %{payment_status: "paid", paid_amount_ars: decimal,
#         payment_method: method, paid_actor_kind: kind,
#         paid_actor_ref: server_ref, paid_at: server_time}}

Origen.Booking.revert_payment(principal, appointment_id, true)
# {:ok, %{payment_status: "pending", payment_method: nil,
#         paid_amount_ars: nil, paid_actor_ref: nil, paid_at: nil}}
# false, nil o :cancelled retornan {:error, :confirmation_required} sin mutación.
# opts sólo acepta los fail_at de las pruebas transaccionales; no hay motivo escrito.

Origen.Booking.list_payment_actions(principal, appointment_id)
# {:ok, [%{action: "paid" | "reverted", amount_ars: decimal, method: method,
#         actor_kind: kind, actor_ref: server_ref, occurred_at: server_time}]}
```

El precio acepta un Decimal, entero o texto decimal finito y no negativo;
`0` es válido. La representación monetaria conserva la precisión decimal
recibida, sin introducir una restricción de escala adicional en T1. Un precio negativo, no finito o malformado
retorna `{:error, :invalid_final_price}` sin modificar el turno, el pago ni la
auditoría. Una edición sobre un pago `paid` retorna
`{:error, :payment_already_paid}`. El precio se modifica con la fila del turno y
la fila de pago bloqueadas.

La proyección de Paciente contiene exactamente identificador, precio final y
estado de pago. No expone snapshot de catálogo, método, actor, fecha ni
historial de acciones. Las operaciones devuelven `{:error, :unauthorized}` para
sesiones inválidas, roles sin permiso, turnos ajenos o un identificador no
accesible.

Registrar un pago deriva el importe desde `final_price_ars` y el actor y fecha
desde la sesión y el reloj del servidor. No acepta importes, actores ni fechas
suministrados por el cliente. Revertir exige `confirmed == true`, deriva el actor y
la fecha del servidor, limpia sólo la marca vigente y agrega una acción `reverted`
con el importe y método de la marca anterior. Los errores públicos son
`:invalid_payment_method`, `:invalid_payment_options`, `:payment_not_eligible`,
`:payment_already_paid`, `:confirmation_required`, `:payment_not_paid` y
`:audit_unavailable`; cualquier rechazo conserva precio, pago, acciones,
historial operativo, snapshot y catálogo. El pago actual, la acción `paid` y el
evento `appointment_payment_registered` se escriben atómicamente. La reversión
confirma el pago pendiente, la acción `reverted` y el evento
`appointment_payment_reverted` en una única transacción.

## Persistencia y compatibilidad

- `appointments.snapshot_exact_price_ars` sigue siendo inmutable.
- `appointments.final_price_ars` se inicializa desde el snapshot y sólo el
  recorrido autorizado de precio puede modificarlo después.
- `appointment_payments` mantiene una única fila por turno y comienza en
  `pending`; T2 guarda en ella método, importe, actor y fecha al registrar el
  total.
- `payment_actions` es una tabla append-only: T2 agrega la acción `paid` y T3
  agrega la acción `reverted` con la evidencia de la marca anterior. Sus filas no
  se actualizan ni eliminan.
- Un trigger de inserción cubre también reservas creadas por recorridos internos
  existentes, mientras que la migración rellena explícitamente los turnos
  históricos.

## Pruebas con base desechable

Las pruebas que usan conexiones PostgreSQL distintas no deben ejecutarse contra
`origen_test` ni contra otra base existente: crean datos confirmados y eventos
append-only. El runner crea una base nueva con el `MIX_TEST_PARTITION` generado
por él y elimina únicamente esa base si este mismo runner confirmó haberla
creado.

Los dos comandos requeridos son exactamente:

```bash
# Modo enfocado: habilita las tres carreras reales de pago.
bash scripts/test_payment_concurrency.sh

# Suite general: mantiene ORIGEN_PAYMENT_CONCURRENCY=0; las tres pruebas de
# conexiones distintas quedan omitidas para no contaminar sus fixtures.
bash scripts/test_payment_concurrency.sh test/
```

Un archivo seleccionado explícitamente como
`test/origen/booking/payment_concurrency_test.exs` habilita su marcador de
concurrencia. El modo general no debe habilitarlo indirectamente.

Precondiciones: `psql`, `mix`, `deps/`, `_build/`, PostgreSQL local en el puerto
configurado y las variables `ORIGEN_TEST_DB_USERNAME`,
`ORIGEN_TEST_DB_PASSWORD` y opcionalmente `ORIGEN_TEST_DB_PORT`/`ORIGEN_TEST_DB_HOST`.
No se configura `ORIGEN_DATABASE_URL`.

El runner imprime el código de salida de `mix test` antes de limpiar y conserva
stdout/stderr de esa única ejecución. La prueba exige que los workers tengan
PIDs de backend PostgreSQL distintos y que atraviesen una barrera común; para
registro/registro exige exactamente un éxito y un `:payment_already_paid`. Para
registro/edición acepta únicamente que gane la edición y luego se pague el
nuevo precio, o que gane el pago y la edición retorne `:payment_already_paid`;
en ambos casos exige un único `paid` y `paid_amount_ars == final_price_ars`.

La primera preparación intentó usar el sandbox/base normal: el cleanup chocó
con el trigger append-only de `audit_events` y dejó fixtures comprometidos allí.
No se deben borrar, truncar ni modificar esos datos desde este runner; la
prueba corregida usa exclusivamente la base desechable nueva.

La migración `20261026100000_add_appointment_payments.exs` no se modifica. La
migración de seguimiento
`20261026100100_preserve_appointment_payment_history_on_delete.exs` cambia sólo
la FK de `appointment_payments` a `ON DELETE CASCADE`, para que una fila
`pending` sin historia no rompa la limpieza interna. La FK de `payment_actions`
permanece en `ON DELETE RESTRICT` y su trigger append-only no cambia; por eso una
acción `paid` o `reverted` conserva el bloqueo y la historia observable.
Su `down/0` restaura `ON DELETE RESTRICT` sin eliminar datos. No se debe ejecutar
rollback sobre datos humanos: la única reversión segura es sobre una base vacía
y aislada, después de exportar/verificar cualquier evidencia necesaria. No se
ejecutan resets destructivos como parte de T1.

## Fuera de T1 y continuación

- T2 registra un único total `paid` sólo para `confirmed` o `attended`, con
  efectivo o transferencia, y agrega una acción inmutable y auditoría atómica.
- T3 agrega la confirmación breve de reversión y las acciones de corrección,
  conservando la secuencia completa y habilitando nuevamente el precio. Una
  reversión no es devolución, crédito ni traslado; tampoco permite volver a pagar
  un turno cancelado o ausente.
- El ciclo de cancelación/ausencia conserva la fila de pago y no transfiere
  pagos a otro turno.
- No se implementan comprobantes, parciales, créditos, devoluciones ni resumen.

## Cobertura de contrato

T1 cubre S1–S3, S5, S7 y S9; T2 cubre S2, S3, S5 y S7 mediante el registro
atómico, autorización y pruebas de concurrencia preparadas para la base
Desechable. En el contrato #384 T2 cubre P1–P3, P5–P7, P13 y P15. T3 cubre
P8–P12 y P14–P15; P14 se cubre como conservación de fecha del turno y fechas de
acciones, sin implementar el resumen. No se agregan comprobantes, parciales,
créditos, devoluciones ni resumen.
