defmodule Origen.Appointments.AvailabilityTest do
  use ExUnit.Case, async: true

  alias Origen.Appointments.Availability

  @date ~D[2026-09-25]
  @fixed_now ~U[2026-09-25 08:45:00Z]

  describe "calculate_slots/4 - basic window and duration fitting" do
    test "generates aligned slots within shift boundaries" do
      windows = [{~T[08:00:00], ~T[10:00:00]}]

      slots =
        Availability.calculate_slots(@date, windows, [],
          now: @fixed_now,
          agenda_interval_minutes: 30,
          duration_minutes: 30
        )

      assert Enum.map(slots, & &1.start_formatted) == ["09:30"]
      assert hd(slots).end_formatted == "10:00"
    end

    test "refutes slot starts that would exceed the end of a window" do
      windows = [{~T[08:00:00], ~T[10:00:00]}]
      # Future date so lead time does not filter out 08:00-09:00
      future_date = ~D[2026-09-28]

      # 45-minute consultation on a 15-minute grid
      slots =
        Availability.calculate_slots(future_date, windows, [],
          now: @fixed_now,
          agenda_interval_minutes: 15,
          duration_minutes: 45
        )

      starts = Enum.map(slots, & &1.start_formatted)

      assert "09:00" in starts
      assert "09:15" in starts
      # 09:30 would end at 10:15 (past 10:00), must be rejected
      refute "09:30" in starts
      refute "09:45" in starts
    end
  end

  describe "calculate_slots/4 - collision detection against occupancies" do
    test "filters out slots overlapping with active appointments" do
      future_date = ~D[2026-09-28]
      windows = [{~T[08:00:00], ~T[12:00:00]}]
      # Occupancy at 09:00 to 09:30
      occupancies = [{~T[09:00:00], ~T[09:30:00]}]

      slots =
        Availability.calculate_slots(future_date, windows, occupancies,
          now: @fixed_now,
          agenda_interval_minutes: 30,
          duration_minutes: 30
        )

      starts = Enum.map(slots, & &1.start_formatted)

      assert "08:30" in starts
      refute "09:00" in starts
      assert "09:30" in starts
    end

    test "correctly rejects multi-interval slots overlapping a partial appointment" do
      future_date = ~D[2026-09-28]
      windows = [{~T[08:00:00], ~T[12:00:00]}]
      # 15-minute appointment from 09:15 to 09:30
      occupancies = [{~T[09:15:00], ~T[09:30:00]}]

      # 45-minute consultation on a 15-minute grid
      slots =
        Availability.calculate_slots(future_date, windows, occupancies,
          now: @fixed_now,
          agenda_interval_minutes: 15,
          duration_minutes: 45
        )

      starts = Enum.map(slots, & &1.start_formatted)

      # 08:30 - 09:15 touches 09:15 (allowed)
      assert "08:30" in starts
      # 08:45 - 09:30 overlaps 09:15 - 09:30 (rejected)
      refute "08:45" in starts
      # 09:00 - 09:45 overlaps 09:15 - 09:30 (rejected)
      refute "09:00" in starts
      # 09:15 - 10:00 overlaps 09:15 - 09:30 (rejected)
      refute "09:15" in starts
      # 09:30 - 10:15 starts at 09:30 (allowed)
      assert "09:30" in starts
    end
  end

  describe "calculate_slots/4 - window merging and continuity" do
    test "merges touching windows into a single continuous period" do
      future_date = ~D[2026-09-28]
      # 08:00-10:00 and 10:00-12:00 are touching
      windows = [{~T[08:00:00], ~T[10:00:00]}, {~T[10:00:00], ~T[12:00:00]}]

      # 60-minute consultation
      slots =
        Availability.calculate_slots(future_date, windows, [],
          now: @fixed_now,
          agenda_interval_minutes: 30,
          duration_minutes: 60
        )

      starts = Enum.map(slots, & &1.start_formatted)

      # 09:30 to 10:30 crosses the boundary of the two windows smoothly
      assert "09:30" in starts
    end
  end

  describe "calculate_slots/4 - lead time and horizon boundaries" do
    test "enforces minimum lead time for same-day booking" do
      # now is 08:45, min lead time is 30m -> earliest allowed is 09:15
      windows = [{~T[08:00:00], ~T[12:00:00]}]

      slots =
        Availability.calculate_slots(@date, windows, [],
          now: @fixed_now,
          agenda_interval_minutes: 30,
          duration_minutes: 30,
          min_lead_time_minutes: 30
        )

      starts = Enum.map(slots, & &1.start_formatted)

      refute "08:00" in starts
      refute "08:30" in starts
      refute "09:00" in starts
      assert "09:30" in starts
    end

    test "returns empty for past dates and dates beyond horizon" do
      windows = [{~T[08:00:00], ~T[12:00:00]}]

      # Yesterday
      yesterday = Date.add(@date, -1)
      assert Availability.calculate_slots(yesterday, windows, [], now: @fixed_now) == []

      # Beyond 30 days horizon
      day_32 = Date.add(@date, 32)

      assert Availability.calculate_slots(day_32, windows, [],
               now: @fixed_now,
               booking_horizon_days: 30
             ) == []
    end
  end
end
