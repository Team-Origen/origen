defmodule OrigenWeb.TimeGridTest do
  use ExUnit.Case, async: true

  alias OrigenWeb.TimeGrid

  test "builds start and end options from the requested interval" do
    assert hd(TimeGrid.options(30, :start)) == "00:00"
    assert Enum.at(TimeGrid.options(30, :start), 1) == "00:30"
    refute "24:00" in TimeGrid.options(30, :start)
    assert List.last(TimeGrid.options(30, :end)) == "24:00"
  end

  test "does not append midnight when it is outside the interval grid" do
    refute "24:00" in TimeGrid.options(50, :end)
    assert TimeGrid.format(8 * 60 + 5) == "08:05"
  end
end
