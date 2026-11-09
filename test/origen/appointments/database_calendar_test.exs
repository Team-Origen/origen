defmodule Origen.Appointments.DatabaseCalendarTest do
  use Origen.DataCase

  alias Origen.Appointments.DatabaseCalendar
  alias Origen.{ProfessionalProfiles, Repo, Sessions}

  @fixed_now ~U[2026-09-25 08:00:00Z]

  setup do
    Repo.query!("DELETE FROM professional_patient_relationships")
    Repo.query!("DELETE FROM appointments")
    Repo.query!("DELETE FROM consultation_types")
    Repo.query!("DELETE FROM agenda_settings")
    Repo.query!("DELETE FROM professional_profiles")
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
    test "lists only active complete profiles, projecting declared identity without private fields",
         %{account_id: id} do
      {:ok, %{session: owner}} = Sessions.create_session(id)
      assert {:ok, []} = DatabaseCalendar.list_professionals()

      attrs = %{
        first_name: "Ana",
        last_name: "Pérez",
        specialty: "Cardiología",
        license_type: "Libre",
        license_number: "AB/001"
      }

      for field <- Map.keys(attrs) do
        assert {:ok, _} =
                 ProfessionalProfiles.save_own_profile(owner, Map.put(attrs, field, " \t "))

        assert {:ok, []} = DatabaseCalendar.list_professionals()
      end

      assert {:ok, saved} = ProfessionalProfiles.save_own_profile(owner, attrs)

      assert {:ok, [%{id: public_id, name: "Ana Pérez", specialty: "Cardiología"} = public]} =
               DatabaseCalendar.list_professionals()

      assert public_id == to_string(id)
      assert Map.keys(public) |> Enum.sort() == [:id, :name, :specialty]
      assert {:ok, ^saved} = ProfessionalProfiles.get_own_profile(owner)

      Repo.query!(
        "UPDATE internal_accounts SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1",
        [id]
      )

      assert {:ok, []} = DatabaseCalendar.list_professionals()
    end

    test "list eligibility does not require catalog or available slots and does not erase settings",
         %{account_id: id} do
      {:ok, %{session: owner}} = Sessions.create_session(id)

      assert {:ok, before} =
               DatabaseCalendar.get_daily_schedule(id, ~D[2026-09-25], now: @fixed_now)

      assert {:ok, _} =
               ProfessionalProfiles.save_own_profile(owner, %{
                 first_name: "Ana",
                 last_name: "Pérez",
                 specialty: "Cardiología",
                 license_type: "Libre",
                 license_number: "AB/001"
               })

      assert {:ok, [_]} = DatabaseCalendar.list_professionals()

      assert {:ok, %{slots: []}} =
               DatabaseCalendar.get_daily_schedule(id, ~D[2026-09-29], now: @fixed_now)

      assert {:ok, _} = ProfessionalProfiles.save_own_profile(owner, %{first_name: nil})
      assert {:ok, []} = DatabaseCalendar.list_professionals()

      assert {:ok, after_profile} =
               DatabaseCalendar.get_daily_schedule(id, ~D[2026-09-25], now: @fixed_now)

      assert after_profile.date == before.date
      assert after_profile.slots == before.slots
      assert after_profile.specialty == "Cardiología"
    end
  end

  describe "get_daily_schedule/3" do
    for status <- ["requested", "confirmed", "reserved", "cancelled"] do
      @status status
      test "persisted #{@status} appointments have the expected calendar occupancy", %{
        account_id: account_id
      } do
        [[patient_id]] =
          Repo.query!("""
          INSERT INTO patient_profiles (email, state)
          VALUES ('calendar-occupancy@example.test', 'completed') RETURNING id
          """).rows

        type_id = Ecto.UUID.generate()

        Repo.query!(
          """
          INSERT INTO consultation_types
            (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
          VALUES ($1, $2, 'Calendar Consultation', 100.00, '#123456', 1, 'active')
          """,
          [Ecto.UUID.dump!(type_id), account_id]
        )

        assert {:ok, _appointment} =
                 Origen.Booking.persist_appointment(
                   %{
                     patient_profile_id: patient_id,
                     professional_account_id: account_id,
                     consultation_type_id: type_id,
                     start_time: ~U[2026-09-25 14:00:00Z],
                     status: @status
                   },
                   %{
                     name: "Calendar Consultation",
                     duration_minutes: 30,
                     exact_price_ars: Decimal.new("100.00")
                   }
                 )

        assert {:ok, schedule} =
                 DatabaseCalendar.get_daily_schedule(account_id, ~D[2026-09-25],
                   now: @fixed_now,
                   duration_minutes: 30
                 )

        expected = ["14:00", "14:30", "15:00", "15:30", "16:00", "16:30"]
        expected = if @status == "cancelled", do: expected, else: tl(expected)
        assert Enum.map(schedule.slots, & &1.start_formatted) == expected
      end
    end

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

    test "uses the persisted non-default interval independently from consultation duration", %{
      account_id: account_id
    } do
      Repo.query!(
        "UPDATE agenda_settings SET interval_minutes = 15 WHERE owner_account_id = $1",
        [account_id]
      )

      assert {:ok, schedule} =
               DatabaseCalendar.get_daily_schedule(account_id, ~D[2026-09-25],
                 now: @fixed_now,
                 duration_minutes: 45,
                 agenda_interval_minutes: 45
               )

      starts = Enum.map(schedule.slots, & &1.start_formatted)
      assert "14:15" in starts
      assert "16:15" in starts
      refute "16:30" in starts
      assert Enum.all?(schedule.slots, &(Time.diff(&1.end_time, &1.start_time, :minute) == 45))
    end

    test "handles unknown or unconfigured professional gracefully" do
      friday = ~D[2026-09-25]

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule(999_999, friday)

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule("invalid_id", friday)
    end

    test "rejects the schedule of a deactivated professional (contract #372, #373)", %{
      account_id: account_id
    } do
      Repo.query!(
        "UPDATE internal_accounts SET state = 'deactivated' WHERE id = $1",
        [account_id]
      )

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule(account_id, ~D[2026-09-25], now: @fixed_now)

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule(to_string(account_id), ~D[2026-09-25],
                 now: @fixed_now
               )
    end

    test "rejects the schedule of a pending_activation professional", %{
      account_id: account_id
    } do
      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL
        WHERE id = $1
        """,
        [account_id]
      )

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule(account_id, ~D[2026-09-25], now: @fixed_now)
    end

    test "restores the schedule after reactivation without erasing settings", %{
      account_id: account_id
    } do
      Repo.query!(
        "UPDATE internal_accounts SET state = 'deactivated' WHERE id = $1",
        [account_id]
      )

      assert {:error, :invalid_professional} =
               DatabaseCalendar.get_daily_schedule(account_id, ~D[2026-09-25], now: @fixed_now)

      Repo.query!("UPDATE internal_accounts SET state = 'active' WHERE id = $1", [account_id])

      assert {:ok, schedule} =
               DatabaseCalendar.get_daily_schedule(account_id, ~D[2026-09-25],
                 now: @fixed_now,
                 duration_minutes: 30
               )

      assert Enum.map(schedule.slots, & &1.start_formatted) ==
               ["14:00", "14:30", "15:00", "15:30", "16:00", "16:30"]
    end
  end
end
