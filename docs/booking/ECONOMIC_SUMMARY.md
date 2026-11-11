# Resumen económico por fecha de turno

`Origen.Booking.economic_summary/3` devuelve un resumen financiero de sólo lectura para un único Profesional y un período válido. La operación es backend-only; la integración de LiveView y rutas pertenece a #391.

## API pública

```elixir
Origen.Booking.economic_summary(principal, professional_id, period_params)
```

- `principal`: mapa de sesión (`%{session_id: integer(), account_id: integer()}`), `%Origen.Sessions.InternalSession{}` o el mapa producido por `Origen.Sessions.create_session/1`.
- `professional_id`: entero positivo de una cuenta activa con rol `professional`. No acepta listas, mapas, cadenas ni un identificador global.
- `period_params`: la entrada exacta de `Origen.Booking.EconomicSummaryPeriod.validate/1`.

Una consulta válida devuelve:

```elixir
{:ok,
 %{
   professional: %{id: professional_id},
   period: %Origen.Booking.EconomicSummaryPeriod{},
   paid: %Decimal{},
   pending: %Decimal{},
   total: %Decimal{}
 }}
```

`paid`, `pending` y `total` son importes ARS exactos. `total` es siempre `paid + pending`; no representa deuda, caja, ingreso neto ni saldo disponible.

## Períodos

La operación reutiliza `EconomicSummaryPeriod.validate/1` sin reinterpretar sus entradas:

- `%{"mode" => "month", "month" => "YYYY-MM"}`: mes calendario completo.
- `%{"mode" => "range", "from" => "YYYY-MM-DD", "to" => "YYYY-MM-DD"}`: rango inclusivo; fechas iguales representan un día completo.
- Los límites son `[period.start_at, period.end_at)` en UTC y se derivan con `:organization_timezone`.
- Los errores de período son `:invalid_period`, `:range_reversed`, `:invalid_timezone`, `:ambiguous_period_boundary` y `:nonexistent_period_boundary`.

## Cálculo

La agregación filtra exclusivamente `appointments.start_time` dentro de los límites validados y usa una sola consulta agregada sobre el turno y su marca de pago vigente:

| Estado del turno | Marca vigente | Resultado |
| --- | --- | --- |
| `confirmed`, `attended` | `paid` | `paid += final_price_ars` |
| `confirmed`, `attended` | `pending` | `pending += final_price_ars` |
| `cancelled`, `no_show`, `requested`, `reserved`, `expired` | `pending` | Excluido |
| cualquier estado | `paid` | `paid += final_price_ars` |

La fecha del pago no participa. Un pago tardío cambia el resumen del período del turno, no el del mes de cobro. Una reversión elimina el importe de `paid`; sólo un turno que continúe `confirmed` o `attended` vuelve a `pending`. Las acciones históricas revertidas no se suman.

El precio es `appointments.final_price_ars`: refleja las ediciones autorizadas antes del pago y no usa el catálogo ni `snapshot_exact_price_ars`. El precio cero sigue las mismas reglas y aporta `Decimal.new("0")`.

## Autorización y errores

La identidad se revalida en cada llamada mediante `Origen.Sessions.revalidate_principal/2`; no se confían los campos `role` ni una cuenta reclamada por el cliente.

| Situación | Resultado |
| --- | --- |
| Profesional activo y selección propia | Permitido |
| Profesional activo y selección ajena | `{:error, :unauthorized}` |
| Secretaría activa y un Profesional activo existente | Permitido |
| Secretaría con múltiples/todo el centro o selección no entera | `{:error, :invalid_professional_selection}` |
| Selección inexistente, inactiva o que no es Profesional | `{:error, :invalid_professional_selection}` |
| Administrador, Paciente, anónimo, sesión inválida/revocada o cuenta inactiva | `{:error, :unauthorized}` |

La autorización también está declarada en `Origen.Authorization.Rules` como `:read_economic_summary` y se aplica antes de la agregación. Las denegaciones no devuelven importes ni detalles de otros Profesionales.

## Sólo lectura

La operación no escribe turnos, precios, pagos, catálogo ni historial de acciones. Los cambios de estado usados para preparar datos de prueba deben pasar por las operaciones públicas existentes (`record_payment/4`, `revert_payment/4`, `update_final_price/3`, `cancel_appointment/3` y `record_attendance/4`), no por el resumen.
