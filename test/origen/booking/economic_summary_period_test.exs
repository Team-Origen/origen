defmodule Origen.Booking.EconomicSummaryPeriodTest do
  use ExUnit.Case, async: false

  alias Origen.Booking.EconomicSummaryPeriod

  setup do
    previous_timezone = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "Etc/UTC")

    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous_timezone) end)
    :ok
  end

  test "calendar month and equivalent range produce the same inclusive local-day UTC bounds" do
    month = EconomicSummaryPeriod.validate(%{"mode" => "month", "month" => "2026-11"})

    range =
      EconomicSummaryPeriod.validate(%{
        "mode" => "range",
        "from" => "2026-11-01",
        "to" => "2026-11-30"
      })

    assert {:ok, month_period} = month
    assert {:ok, range_period} = range

    assert period_bounds(month_period) == period_bounds(range_period)
    assert month_period.mode == :month
    assert range_period.mode == :range
  end

  test "equal range endpoints are valid and cover one complete local day" do
    assert {:ok, period} =
             EconomicSummaryPeriod.validate(%{
               "mode" => "range",
               "from" => "2026-11-15",
               "to" => "2026-11-15"
             })

    assert period.from == ~D[2026-11-15]
    assert period.to == ~D[2026-11-15]
    assert period.start_at == ~U[2026-11-15 00:00:00Z]
    assert period.end_at == ~U[2026-11-16 00:00:00Z]
  end

  test "reversed ranges are rejected without swapping their endpoints" do
    assert {:error, :range_reversed} =
             EconomicSummaryPeriod.validate(%{
               "mode" => "range",
               "from" => "2026-11-20",
               "to" => "2026-11-19"
             })
  end

  test "invalid, incomplete, and ambiguous period input is rejected" do
    invalid_inputs = [
      %{"mode" => "month", "month" => "2026-02-30"},
      %{"mode" => "month", "month" => "2026-13"},
      %{"mode" => "range", "from" => "2026-11-01"},
      %{"mode" => "range", "from" => "2026-11-01", "to" => ""},
      %{"mode" => "weekly", "from" => "2026-11-01", "to" => "2026-11-02"},
      %{
        "mode" => "range",
        "from" => "2026-11-01",
        "to" => "2026-11-02",
        "month" => "2026-11"
      },
      %{mode: "range", from: "2026-11-01", to: "2026-11-02"}
    ]

    for input <- invalid_inputs do
      assert {:error, :invalid_period} = EconomicSummaryPeriod.validate(input)
    end
  end

  test "calendar boundaries include leap days and cross the year boundary" do
    assert {:ok, leap_month} =
             EconomicSummaryPeriod.validate(%{"mode" => "month", "month" => "2028-02"})

    assert leap_month.from == ~D[2028-02-01]
    assert leap_month.to == ~D[2028-02-29]
    assert leap_month.end_at == ~U[2028-03-01 00:00:00Z]

    assert {:ok, non_leap_month} =
             EconomicSummaryPeriod.validate(%{"mode" => "month", "month" => "2027-02"})

    assert non_leap_month.to == ~D[2027-02-28]
    assert non_leap_month.end_at == ~U[2027-03-01 00:00:00Z]

    assert {:ok, december} =
             EconomicSummaryPeriod.validate(%{"mode" => "month", "month" => "2026-12"})

    assert december.to == ~D[2026-12-31]
    assert december.end_at == ~U[2027-01-01 00:00:00Z]
  end

  test "bounds use the configured organization timezone rather than UTC calendar dates" do
    Application.put_env(:origen, :organization_timezone, "America/Argentina/Buenos_Aires")

    assert {:ok, period} =
             EconomicSummaryPeriod.validate(%{
               "mode" => "range",
               "from" => "2026-11-30",
               "to" => "2026-11-30"
             })

    assert period.start_at == ~U[2026-11-30 03:00:00Z]
    assert period.end_at == ~U[2026-12-01 03:00:00Z]
  end

  test "rejects an unknown organization timezone" do
    Application.put_env(:origen, :organization_timezone, "Not/AZone")

    assert {:error, :invalid_timezone} =
             EconomicSummaryPeriod.validate(%{"mode" => "month", "month" => "2026-11"})
  end

  test "does not impose a maximum range or future-date restriction" do
    assert {:ok, period} =
             EconomicSummaryPeriod.validate(%{
               "mode" => "range",
               "from" => "2026-01-01",
               "to" => "2099-12-31"
             })

    assert period.from == ~D[2026-01-01]
    assert period.to == ~D[2099-12-31]
  end

  defp period_bounds(period) do
    Map.take(period, [:from, :to, :start_at, :end_at])
  end
end
