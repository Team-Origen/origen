# Pagos simples: precio final y estado pendiente

T1 agrega la base persistida y autorizada para pagos simples: cada turno conserva
su snapshot histórico, un precio final editable independiente y una fila de pago
inicialmente `pending`. Este slice no registra pagos, no revierte marcas y no
crea resumen económico.

## Recorrido disponible

1. `Origen.Booking.get_payment/2` devuelve la proyección financiera autorizada.
2. `Origen.Booking.update_final_price/3` cambia el precio final de un turno impago.
3. Profesional opera sólo su agenda; Secretaría opera todas; Paciente sólo lee
   sus propios turnos; Administrador no tiene acceso financiero.

## Contrato de la interfaz pública

```elixir
Origen.Booking.get_payment(principal, appointment_id)
# {:ok, %{appointment_id: id, final_price_ars: decimal, payment_status: "pending"}}
# para Paciente; el personal recibe además el estado actual y sus metadatos
# de pago cuando existan.

Origen.Booking.update_final_price(principal, appointment_id, value)
# {:ok, %{appointment_id: id, final_price_ars: decimal, payment_status: "pending"}}
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

## Persistencia y compatibilidad

- `appointments.snapshot_exact_price_ars` sigue siendo inmutable.
- `appointments.final_price_ars` se inicializa desde el snapshot y sólo el
  recorrido autorizado de precio puede modificarlo después.
- `appointment_payments` mantiene una única fila por turno y comienza en
  `pending`; la marca pagada futura guardará método, importe, actor y fecha.
- `payment_actions` es una tabla append-only preparada para las marcas y
  correcciones de T2/T3. Sus filas no se actualizan ni eliminan.
- Un trigger de inserción cubre también reservas creadas por recorridos internos
  existentes, mientras que la migración rellena explícitamente los turnos
  históricos.

La migración `20261026100000_add_appointment_payments.exs` no elimina ni cambia
snapshots. Su `down/0` toma locks y se niega a retirar columnas, pagos o historia
si existe cualquier dato poblado. No se debe ejecutar rollback sobre datos
humanos: la única reversión segura es sobre una base vacía y aislada, después de
exportar/verificar cualquier evidencia necesaria. No se ejecutan resets
destructivos como parte de T1.

## Fuera de T1 y continuación

- T2 registrará un único total `paid` sólo para `confirmed` o `attended`, con
  efectivo o transferencia, y agregará una acción inmutable.
- T3 agregará la confirmación breve de reversión y las acciones de corrección,
  conservando la secuencia completa y habilitando nuevamente el precio.
- El ciclo de cancelación/ausencia conserva la fila de pago y no transfiere
  pagos a otro turno.
- No se implementan comprobantes, parciales, créditos, devoluciones ni resumen.

## Cobertura de contrato

T1 cubre S1–S3, S5, S7 y S9; en el contrato #384 cubre la persistencia y precio
independiente de P3–P6, la inicialización pendiente de P13 y la preparación de
P14–P15. P1–P2, P7–P12 y el registro/corrección efectiva quedan para T2/T3.
