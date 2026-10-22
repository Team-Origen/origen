defmodule Origen.Appointments.BookingServiceTest do
  use Origen.DataCase

  alias Origen.Appointments.BookingService
  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Patients
  alias Origen.Repo

  @fixed_now ~U[2026-09-25 10:00:00Z]

  setup do
    Repo.query!("DELETE FROM appointments")
    Repo.query!("DELETE FROM patient_profiles")
    Repo.query!("DELETE FROM personas")
    Repo.query!("DELETE FROM internal_accounts")

    # Insert verified patient
    {:ok, %{profile: profile}} =
      Patients.complete_profile("paciente_reserva@example.test", %{
        first_name: "Ana",
        last_name: "Gómez",
        document_type: "dni",
        document_number: "38123456",
        birthdate: ~D[1994-05-20],
        phone: "+5491133445566"
      })

    # Verify phone
    verified_profile =
      profile
      |> Ecto.Changeset.change(%{phone_verified: true})
      |> Repo.update!()

    # Insert active professional
    res =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'prof_booking@example.test', 'hash', decode('0102030405', 'hex'), clock_timestamp())
      RETURNING id
      """)

    prof_id = hd(res.rows) |> hd()
    {:ok, %{session: principal}} = Origen.Sessions.create_session(prof_id)
    assert {:ok, _} = Origen.ProfessionalProfiles.save_own_profile(principal, complete_profile())
    type_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Consulta general', 18000.00, '#0A7C86', 2, 'active')
      """,
      [Ecto.UUID.dump!(type_id), prof_id]
    )

    %{
      profile: verified_profile,
      prof_id: prof_id,
      type_id: type_id,
      principal: principal
    }
  end

  describe "reserve/2 - autonomous booking execution" do
    test "rejects every incomplete profile and inactive account without writing reservations",
         ctx do
      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: ctx.type_id,
        date: ~D[2026-09-28],
        slot: %{start_time: ~T[10:00:00]},
        snapshot_override: %{
          name: "Consulta general",
          duration_minutes: 30,
          exact_price_ars: Decimal.new("18000.00")
        },
        now: @fixed_now
      }

      before = Repo.all(Appointment)

      for field <- Map.keys(complete_profile()) do
        assert {:ok, _} =
                 Origen.ProfessionalProfiles.save_own_profile(ctx.principal, %{field => nil})

        assert {:error, :professional_not_eligible} = BookingService.reserve(ctx.profile, params)
        assert Repo.all(Appointment) == before

        assert {:ok, _} =
                 Origen.ProfessionalProfiles.save_own_profile(ctx.principal, complete_profile())
      end

      Repo.query!(
        "UPDATE internal_accounts SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1",
        [ctx.prof_id]
      )

      assert {:error, :professional_not_eligible} = BookingService.reserve(ctx.profile, params)
      assert Repo.all(Appointment) == before
    end

    test "rejects a professional without a profile even when their catalog exists", ctx do
      [[other_id]] =
        Repo.query!(
          "INSERT INTO internal_accounts (role,state,password_hash,totp_secret,activated_at) VALUES ('professional','active','hash',decode('0102','hex'),NOW()) RETURNING id"
        ).rows

      other_type = Ecto.UUID.generate()

      Repo.query!(
        """
        INSERT INTO consultation_types
          (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
        VALUES ($1, $2, 'Consulta general', 18000.00, '#0A7C86', 2, 'active')
        """,
        [Ecto.UUID.dump!(other_type), other_id]
      )

      params = %{
        professional_id: other_id,
        consultation_type_id: other_type,
        date: ~D[2026-09-28],
        slot: %{start_time: ~T[10:00:00]},
        now: @fixed_now
      }

      assert {:error, :professional_not_eligible} = BookingService.reserve(ctx.profile, params)
      assert Repo.all(Appointment) == []
    end

    test "successfully reserves appointment and persists historical snapshots", ctx do
      # 3 days ahead -> RF-10 'reserved'
      future_date = ~D[2026-09-28]

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: ctx.type_id,
        date: future_date,
        slot: %{start_time: ~T[10:00:00], start_formatted: "10:00"},
        snapshot_override: %{
          name: "Consulta general",
          duration_minutes: 30,
          exact_price_ars: Decimal.new("18000.00")
        },
        now: @fixed_now
      }

      assert {:ok, res} = BookingService.reserve(ctx.profile, params)

      assert res.status == "reserved"
      assert res.consultation_type_name == "Consulta general"
      assert res.duration_minutes == 30
      assert res.exact_price_ars == Decimal.new("18000.00")
      assert DateTime.compare(res.start_time, ~U[2026-09-28 10:00:00Z]) == :eq
      assert DateTime.compare(res.end_time, ~U[2026-09-28 10:30:00Z]) == :eq

      # Verify persisted appointment in PostgreSQL
      persisted = Repo.get!(Appointment, res.appointment_id)
      assert persisted.status == "reserved"
      assert persisted.snapshot_consultation_type_name == "Consulta general"
      assert persisted.snapshot_exact_price_ars == Decimal.new("18000.00")
      assert persisted.snapshot_duration_minutes == 30
    end

    test "determines 'confirmed' status when booked on D-1 or D per RF-10", ctx do
      # Tomorrow (D-1 relative to @fixed_now which is 2026-09-25)
      tomorrow = ~D[2026-09-26]

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: ctx.type_id,
        date: tomorrow,
        slot: %{start_time: ~T[11:00:00]},
        snapshot_override: %{
          name: "Control",
          duration_minutes: 15,
          exact_price_ars: Decimal.new("12000.00")
        },
        now: @fixed_now
      }

      assert {:ok, res} = BookingService.reserve(ctx.profile, params)
      assert res.status == "confirmed"
    end

    test "manual approval mode books as 'requested' regardless of date proximity and establishes the relationship (Contract #321)",
         ctx do
      Repo.query!(
        """
        INSERT INTO agenda_settings (owner_account_id, interval_minutes, approval_mode, secretary_approval_mode)
        VALUES ($1, 30, 'manual', 'confirmed')
        """,
        [ctx.prof_id]
      )

      # 3 days ahead would normally start in 'reserved' (RF-10); manual approval wins.
      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: ctx.type_id,
        date: ~D[2026-09-28],
        slot: %{start_time: ~T[15:00:00]},
        snapshot_override: %{
          name: "Consulta general",
          duration_minutes: 30,
          exact_price_ars: Decimal.new("18000.00")
        },
        now: @fixed_now
      }

      assert {:ok, res} = BookingService.reserve(ctx.profile, params)
      assert res.status == "requested"

      persisted = Repo.get!(Appointment, res.appointment_id)
      assert persisted.status == "requested"

      relationship =
        Repo.get_by(ProfessionalPatientRelationship,
          professional_account_id: ctx.prof_id,
          patient_profile_id: ctx.profile.id
        )

      assert relationship != nil
      assert relationship.first_appointment_id == persisted.id
    end

    test "refutes booking when patient phone is not verified", ctx do
      unverified =
        ctx.profile
        |> Ecto.Changeset.change(%{phone_verified: false})
        |> Repo.update!()

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: ctx.type_id,
        date: ~D[2026-09-28],
        slot: %{start_time: ~T[10:00:00]},
        snapshot_override: %{
          name: "Control",
          duration_minutes: 15,
          exact_price_ars: Decimal.new("12000.00")
        },
        now: @fixed_now
      }

      assert {:error, :patient_not_ready_for_booking} = BookingService.reserve(unverified, params)
      assert Repo.all(Appointment) == []
    end

    test "rejects unauthenticated caller", ctx do
      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: ctx.type_id,
        date: ~D[2026-09-28],
        slot: %{start_time: ~T[10:00:00]}
      }

      assert {:error, :unauthenticated} = BookingService.reserve(nil, params)
    end

    test "rejects invalid professional id", ctx do
      params = %{
        professional_id: "not_a_number",
        consultation_type_id: ctx.type_id,
        date: ~D[2026-09-28],
        slot: %{start_time: ~T[10:00:00]},
        now: @fixed_now
      }

      assert {:error, :invalid_professional_id} = BookingService.reserve(ctx.profile, params)
    end
  end

  defp complete_profile do
    %{
      first_name: "Ana",
      last_name: "Pérez",
      specialty: "Cardiología",
      license_type: "Libre",
      license_number: "AB/001"
    }
  end
end
