defmodule Origen.Appointments.MockCalendarTest do
  use ExUnit.Case, async: false

  alias Origen.Appointments.Calendar
  alias Origen.Appointments.MockCalendar

  describe "list_professionals/0" do
    test "returns list of active mock professionals" do
      assert {:ok, professionals} = Calendar.list_professionals()
      assert is_list(professionals)
      assert length(professionals) >= 2

      sofia = Enum.find(professionals, &(&1.id == "PRO-DEMO-001"))
      assert sofia.name == "Dra. Sofía Martínez"
      assert sofia.specialty == "Medicina General"
    end
  end

  describe "get_daily_schedule/2" do
    test "returns available slots and cancellation policy for weekdays" do
      # 2026-09-25 is a Friday
      date = ~D[2026-09-25]
      assert {:ok, schedule} = Calendar.get_daily_schedule("PRO-DEMO-001", date)

      assert schedule.date == date
      assert schedule.professional_id == "PRO-DEMO-001"
      assert schedule.professional_name == "Dra. Sofía Martínez"
      assert length(schedule.slots) == 22

      first_slot = hd(schedule.slots)
      assert first_slot.start_formatted == "09:00"
      assert first_slot.end_formatted == "09:30"
      assert first_slot.status == :available
      assert Enum.at(schedule.slots, 1).start_formatted == "09:15"

      assert schedule.cancellation_policy.penalty_percentage == 50
      assert schedule.cancellation_policy.cutoff_description =~ "18:00"
    end

    test "returns empty slots for weekends" do
      # 2026-09-26 is a Saturday
      saturday = ~D[2026-09-26]
      assert {:ok, schedule} = Calendar.get_daily_schedule("PRO-DEMO-001", saturday)
      assert schedule.slots == []

      # 2026-09-27 is a Sunday
      sunday = ~D[2026-09-27]
      assert {:ok, schedule} = Calendar.get_daily_schedule("PRO-DEMO-001", sunday)
      assert schedule.slots == []
    end

    test "simulates temporary schedule unavailability on day 31" do
      date = ~D[2026-10-31]

      assert {:error, :schedule_temporarily_unavailable} =
               Calendar.get_daily_schedule("PRO-DEMO-001", date)
    end

    test "returns error for unknown professional" do
      date = ~D[2026-09-25]

      assert {:error, :invalid_professional} =
               Calendar.get_daily_schedule("PRO-UNKNOWN", date)
    end
  end

  describe "Calendar boundary fail-closed behavior" do
    test "returns {:error, :unavailable} when adapter is not configured" do
      assert {:ok, _} = MockCalendar.list_professionals()

      original = Application.get_env(:origen, :appointments_calendar_adapter)

      try do
        Application.put_env(:origen, :appointments_calendar_adapter, nil)
        assert {:error, :unavailable} = Calendar.list_professionals()

        assert {:error, :unavailable} =
                 Calendar.get_daily_schedule("PRO-DEMO-001", ~D[2026-09-25])
      after
        Application.put_env(:origen, :appointments_calendar_adapter, original)
      end
    end
  end
end
