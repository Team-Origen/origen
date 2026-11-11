defmodule Origen.Booking.EconomicSummaryPeriod do
  @moduledoc """
  Valida períodos del resumen económico y traduce sus días locales a límites UTC.

  La entrada sigue la forma de los filtros públicos del resumen: un mes calendario
  (`%{"mode" => "month", "month" => "YYYY-MM"}`) o un rango inclusivo
  (`%{"mode" => "range", "from" => "YYYY-MM-DD", "to" => "YYYY-MM-DD"}`).
  Los límites devueltos son semiabiertos: `start_at` incluye el inicio del
  primer día local y `end_at` excluye el inicio del día siguiente al último.
  """

  @enforce_keys [:mode, :from, :to, :start_at, :end_at, :timezone]
  defstruct [:mode, :from, :to, :start_at, :end_at, :timezone]

  @type mode :: :month | :range
  @type t :: %__MODULE__{
          mode: mode(),
          from: Date.t(),
          to: Date.t(),
          start_at: DateTime.t(),
          end_at: DateTime.t(),
          timezone: String.t()
        }

  @type error ::
          :invalid_period
          | :range_reversed
          | :invalid_timezone
          | :ambiguous_period_boundary
          | :nonexistent_period_boundary

  @month_pattern ~r/\A\d{4}-(?:0[1-9]|1[0-2])\z/
  @date_pattern ~r/\A\d{4}-\d{2}-\d{2}\z/

  @doc """
  Validates a calendar month or inclusive date range.

  The organization timezone is read from `:origen, :organization_timezone`, as
  in the existing booking calendar. Invalid, incomplete, or extra input fields
  return `{:error, :invalid_period}`. An inverted range returns
  `{:error, :range_reversed}`. A valid result contains local `from`/`to` dates
  and UTC half-open bounds in `start_at`/`end_at`.
  """
  @spec validate(map()) :: {:ok, t()} | {:error, error()}
  def validate(%{"mode" => "month", "month" => month} = params)
      when map_size(params) == 2 do
    with {:ok, first_day} <- parse_month(month) do
      build(:month, first_day, Date.end_of_month(first_day))
    end
  end

  def validate(%{"mode" => "range", "from" => from, "to" => to} = params)
      when map_size(params) == 3 do
    with {:ok, first_day} <- parse_date(from),
         {:ok, last_day} <- parse_date(to),
         :ok <- compare_range(first_day, last_day) do
      build(:range, first_day, last_day)
    end
  end

  def validate(_params), do: {:error, :invalid_period}

  defp parse_month(month) when is_binary(month) do
    if Regex.match?(@month_pattern, month) do
      case Date.from_iso8601(month <> "-01") do
        {:ok, date} -> {:ok, date}
        {:error, _reason} -> {:error, :invalid_period}
      end
    else
      {:error, :invalid_period}
    end
  end

  defp parse_month(_month), do: {:error, :invalid_period}

  defp parse_date(date) when is_binary(date) do
    if Regex.match?(@date_pattern, date) do
      case Date.from_iso8601(date) do
        {:ok, parsed} -> {:ok, parsed}
        {:error, _reason} -> {:error, :invalid_period}
      end
    else
      {:error, :invalid_period}
    end
  end

  defp parse_date(_date), do: {:error, :invalid_period}

  defp compare_range(first_day, last_day) do
    case Date.compare(last_day, first_day) do
      :lt -> {:error, :range_reversed}
      _ -> :ok
    end
  end

  defp build(mode, first_day, last_day) do
    timezone = Application.fetch_env!(:origen, :organization_timezone)

    next_day = Date.add(last_day, 1)

    with {:ok, start_local} <- local_midnight(first_day, timezone),
         {:ok, end_local} <- local_midnight(next_day, timezone) do
      {:ok,
       %__MODULE__{
         mode: mode,
         from: first_day,
         to: last_day,
         start_at: DateTime.shift_zone!(start_local, "Etc/UTC"),
         end_at: DateTime.shift_zone!(end_local, "Etc/UTC"),
         timezone: timezone
       }}
    else
      {:error, reason} when reason in [:invalid_time_zone, :time_zone_not_found] ->
        {:error, :invalid_timezone}

      {:ambiguous, _first, _second} ->
        {:error, :ambiguous_period_boundary}

      {:gap, _before, _after} ->
        {:error, :nonexistent_period_boundary}
    end
  end

  defp local_midnight(date, timezone), do: DateTime.new(date, ~T[00:00:00], timezone)
end
