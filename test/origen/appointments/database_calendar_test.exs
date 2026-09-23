defmodule Origen.Appointments.DatabaseCalendarTest do
  use Origen.DataCase

  alias Origen.Appointments.DatabaseCalendar
  alias Origen.Repo

  @fixed_now ~U[2026-09-25 08:00:00Z]

  setup do
    Repo.query!("DELETE FROM agenda_settings")
    Repo.query!("DELETE FROM internal_accounts")

    # Insert an active professional
    res =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'prof_db@example.test', 'hash', decode('0102030405', 'hex'), clock_timestamp())
      RETURNING id
      """)

    account_id = hd(res.rows) |> hd()

    # Insert agenda_settings for this professional with custom availability
    week_json = ~s({
      "monday": [{"start": "09:00", "end": "12:00"}],
      "tuesday": [],
      "wednesday": [],
      "thursday": [],
      "friday": [{"start": "14:00", "end": "17:00"}],
      "saturday": [],
      "sunday": []
    })

    Repo.query!(
      """
      INSERT INTO agenda_settings (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days, minimum_lead_minutes)
      VALUES ($1, 30, $2::jsonb, 30, 30)
      """,
      [account_id, week_json]
    )

    %{account_id: account_id}
  end

  describe "list_professionals/0" do
    test "returns list of active professionals from internal_accounts" do
      assert {:ok, professionals} = DatabaseCalendar.list_professionals()
      assert is_list(professionals)
      assert length(professionals) == 1

      prof = hd(professionals)
      assert prof.name =~ "prof_db@example.test"
      assert prof.specialty == "Medicina General"
    end
  end

  describe "get_daily_schedule/3" do
    test "calculates slots from real persisted agenda_settings for Friday", %{
      account_id: account_id
    } do
      # 2026-09-25 is a Friday -> 14:00 to 17:00
      friday = ~D[2026-09-25]

      assert {:ok, schedule} =
               DatabaseCalendar.get_daily_schedule(account_id, friday,
                 now: @fixed_now,
                 duration_minutes: 30
               )

      assert schedule.date == friday
      assert schedule.professional_id == to_string(account_id)
      starts = Enum.map(schedule.slots, & &1.start_formatted)

      assert starts == ["14:00", "14:30", "15:00", "15:30", "16:00", "16:30"]
      assert hd(schedule.slots).end_formatted == "14:30"
    end

    test "returns empty slots for day with no availability (Tuesday)", %{account_id: account_id} do
      # 2026-09-29 is Tuesday -> empty in agenda_settings
      tuesday = ~D[2026-09-29]

      assert {:ok, schedule} =
               DatabaseCalendar.get_daily_schedule(account_id, tuesday,
                 now: @fixed_now,
                 duration_minutes: 30
               )

      assert schedule.slots == []
    end

    test "handles unknown or unconfigured professional gracefully" do
      friday = ~D[2026-09-25]

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule(999_999, friday)

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule("invalid_id", friday)
    end
  end
end
