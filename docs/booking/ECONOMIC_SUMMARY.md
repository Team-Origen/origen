# Economic summary periods

`Origen.Booking.EconomicSummaryPeriod` is the T1 period boundary API for the
future read-only economic summary. It validates the two contract modalities and
returns UTC bounds that T2 can use for appointment-date filtering.

## Quick path for T2

```elixir
case Origen.Booking.EconomicSummaryPeriod.validate(params) do
  {:ok, period} ->
    # Query start_time >= period.start_at and start_time < period.end_at.
    # Apply the professional scope and payment rules separately in T2.

  {:error, reason} ->
    # Reject the summary request without querying financial data.
end
```

The operation is pure: it does not read or write appointments, payments,
prices, sessions, authorization records, or audit events.

## Input

`validate/1` accepts exactly one of these maps. Values are strings because this
is the shape emitted by the existing period controls.

| Modality | Exact input | Meaning |
| --- | --- | --- |
| Calendar month | `%{"mode" => "month", "month" => "YYYY-MM"}` | The first through last day of that calendar month, inclusive. |
| Inclusive range | `%{"mode" => "range", "from" => "YYYY-MM-DD", "to" => "YYYY-MM-DD"}` | Both dates and every local day between them, inclusive. |

Keys must be complete and unambiguous: extra keys, atom-key maps, unsupported
modes, empty values, malformed ISO strings, and impossible dates are rejected.
`from` equal to `to` is valid and represents one complete local day. There is no
maximum range and no restriction against future dates.

The organization timezone is read from
`Application.fetch_env!(:origen, :organization_timezone)`, matching the
existing `ProfessionalBooking` calendar convention. T2 must not derive the
appointment date from UTC without using these bounds.

## Output

A valid request returns:

```elixir
{:ok,
 %Origen.Booking.EconomicSummaryPeriod{
   mode: :month | :range,
   from: %Date{},
   to: %Date{},
   start_at: %DateTime{},
   end_at: %DateTime{},
   timezone: "configured organization timezone"
 }}
```

`from` and `to` are the validated local dates. `start_at` is the UTC instant at
the start of `from`, included. `end_at` is the UTC instant at the start of the
day after `to`, excluded. This half-open interval includes the final local day
without relying on an artificial `23:59:59` value.

For example, with `organization_timezone: "America/Argentina/Buenos_Aires"`:

```elixir
EconomicSummaryPeriod.validate(%{
  "mode" => "range",
  "from" => "2026-11-30",
  "to" => "2026-11-30"
})
# {:ok, %{from: ~D[2026-11-30], to: ~D[2026-11-30],
#         start_at: ~U[2026-11-30 03:00:00Z],
#         end_at: ~U[2026-12-01 03:00:00Z], ...}}
```

A calendar month and its equivalent range return the same `from`, `to`,
`start_at`, and `end_at` values. Their `mode` records which input modality was
used.

## Errors

The public errors are exact atoms:

| Error | Rejected condition |
| --- | --- |
| `:invalid_period` | Missing or extra fields, unsupported modality, malformed or incomplete input, invalid month/date, or a nonexistent date such as `2026-02-30`. |
| `:range_reversed` | A valid range whose `to` date is before `from`; endpoints are never swapped. |
| `:invalid_timezone` | The configured organization timezone is not known to the timezone database. |
| `:ambiguous_period_boundary` | A local midnight used as a period boundary is ambiguous in the configured timezone. |
| `:nonexistent_period_boundary` | A local midnight used as a period boundary does not exist in the configured timezone. |

T2 should reject every error before aggregation. Error handling must not turn
an invalid period into an empty zero-valued summary.

## Contract coverage in T1

- **R1:** month and equivalent range share identical UTC bounds.
- **R2:** equal range endpoints cover one full local day.
- **R3:** reversed ranges are rejected without correction.
- **R4:** invalid, incomplete, unsupported, and ambiguous input is rejected.
- **R5:** leap February and the December-to-January boundary use the next local
day as the exclusive end.
- **R6:** organization-local dates are converted to UTC; the Buenos Aires
example maps local November 30 to `03:00Z` boundaries.

Authorization, professional selection, appointment eligibility, payment
aggregation, ARS arithmetic, and API transport remain outside T1 and belong to
T2 or later slices.
