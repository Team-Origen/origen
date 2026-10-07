defmodule OrigenWeb.TimeGrid do
  @moduledoc false

  def options(interval, boundary)
      when is_integer(interval) and interval > 0 and boundary in [:start, :end] do
    0
    |> Stream.iterate(&(&1 + interval))
    |> Enum.take_while(&(&1 < 24 * 60))
    |> maybe_append_midnight(boundary, interval)
    |> Enum.map(&format/1)
  end

  def format(minutes) when is_integer(minutes) and minutes >= 0 do
    hours = div(minutes, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    remaining = rem(minutes, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hours}:#{remaining}"
  end

  defp maybe_append_midnight(minutes, :end, interval) when rem(24 * 60, interval) == 0,
    do: minutes ++ [24 * 60]

  defp maybe_append_midnight(minutes, _boundary, _interval), do: minutes
end
