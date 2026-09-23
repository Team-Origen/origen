defmodule Origen.Booking.PersistenceTest do
  use ExUnit.Case, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Crear profesional en internal_accounts
    {:ok, %{rows: [[professional_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES ('dr.smith@example.com', 'professional', 'active', 'hashed_pass_placeholder', decode('010203', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        []
      )

    # Crear configuración de agenda para el profesional
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.agenda_settings (owner_account_id, interval_minutes, created_at, updated_at)
        VALUES ($1, 30, clock_timestamp(), clock_timestamp())
        """,
        [professional_id]
      )

    # Crear tipo de consulta activo para el profesional
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.consultation_types (
          id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at
        ) VALUES (
          $1, $2, 'Consulta General', 15000.50, '#112233', 1, 'active', clock_timestamp(), clock_timestamp()
        )
        """,
        [Ecto.UUID.dump!(@consultation_type_id), professional_id]
      )

    # Crear persona y patient_profile
    {:ok, %{rows: [[persona_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
        VALUES ('Juan', 'Perez', 'dni', '30111222', '1990-01-01', clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        []
      )

    {:ok, %{rows: [[patient_profile_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.patient_profiles (persona_id, email, state, phone, phone_verified, created_at, updated_at)
        VALUES ($1, 'juan.perez@example.com', 'completed', '+5491100001111', true, clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [persona_id]
      )

    %{
      professional_id: professional_id,
      patient_profile_id: patient_profile_id,
      consultation_type_id: @consultation_type_id
    }
  end

  describe "persist_appointment/2 con resolución real de tipo de consulta" do
    test "persiste el turno copiando nombre, duración y precio exacto como snapshots", ctx do
      start_time = ~U[2026-10-15 09:00:00Z]

      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: start_time,
        status: "reserved"
      }

      assert {:ok, %Appointment{} = appt} = Booking.persist_appointment(attrs)

      assert appt.patient_profile_id == ctx.patient_profile_id
      assert appt.professional_account_id == ctx.professional_id
      assert appt.consultation_type_id == ctx.consultation_type_id
      assert appt.start_time == ~U[2026-10-15 09:00:00.000000Z]
      # 1 intervalo de 30 min -> 30 minutos de duración
      assert appt.snapshot_duration_minutes == 30
      assert appt.end_time == ~U[2026-10-15 09:30:00.000000Z]
      assert appt.snapshot_consultation_type_name == "Consulta General"
      assert Decimal.equal?(appt.snapshot_exact_price_ars, Decimal.new("15000.50"))
      assert appt.status == "reserved"
    end

    test "los cambios posteriores del tipo de consulta no alteran turnos existentes", ctx do
      start_time = ~U[2026-10-15 10:00:00Z]

      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: start_time
      }

      {:ok, %Appointment{id: appt_id}} = Booking.persist_appointment(attrs)

      # Modificar el tipo de consulta en la base de datos (precio, nombre, intervalos)
      {:ok, _} =
        Ecto.Adapters.SQL.query(
          Repo,
          """
          UPDATE public.consultation_types
          SET name = 'Consulta Ultra VIP', exact_price_ars = 99999.99, interval_count = 3
          WHERE id = $1
          """,
          [Ecto.UUID.dump!(ctx.consultation_type_id)]
        )

      # Recargar el turno desde la base de datos
      reloaded_appt = Repo.get!(Appointment, appt_id)

      assert reloaded_appt.snapshot_consultation_type_name == "Consulta General"
      assert reloaded_appt.snapshot_duration_minutes == 30
      assert Decimal.equal?(reloaded_appt.snapshot_exact_price_ars, Decimal.new("15000.50"))
    end

    test "el trigger de base de datos impide mutar directamente los snapshots de un turno", ctx do
      start_time = ~U[2026-10-15 11:00:00Z]

      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: start_time
      }

      {:ok, %Appointment{id: appt_id}} = Booking.persist_appointment(attrs)

      # Intentar actualizar los snapshots debe fallar con excepción 23000
      exception =
        assert_raise Postgrex.Error,
                     ~r/appointment snapshots and core identity are immutable/,
                     fn ->
                       Ecto.Adapters.SQL.query!(
                         Repo,
                         """
                         UPDATE public.appointments
                         SET snapshot_exact_price_ars = 50000.00
                         WHERE id = $1
                         """,
                         [appt_id]
                       )
                     end

      assert exception.postgres.pg_code == "23000"
    end

    test "rechaza persistencia si el tipo de consulta pertenece a otro profesional", ctx do
      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id + 999,
        consultation_type_id: ctx.consultation_type_id,
        start_time: ~U[2026-10-15 12:00:00Z]
      }

      assert {:error, :consultation_type_not_found} = Booking.persist_appointment(attrs)
    end

    test "rechaza persistencia si el tipo de consulta está inactivo", ctx do
      # Desactivar tipo de consulta
      {:ok, _} =
        Ecto.Adapters.SQL.query(
          Repo,
          """
          UPDATE public.consultation_types
          SET status = 'inactive', inactive_duration_minutes = 30
          WHERE id = $1
          """,
          [Ecto.UUID.dump!(ctx.consultation_type_id)]
        )

      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: ~U[2026-10-15 12:00:00Z]
      }

      assert {:error, :consultation_type_inactive} = Booking.persist_appointment(attrs)
    end
  end

  describe "persist_appointment/2 con snapshots simulados" do
    test "persiste con snapshot simulado sin consultar catálogo", ctx do
      simulated_snapshot = %{
        name: "Consulta Simulada",
        duration_minutes: 45,
        exact_price_ars: Decimal.new("12345.67")
      }

      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: ~U[2026-10-15 14:00:00Z]
      }

      assert {:ok, %Appointment{} = appt} =
               Booking.persist_appointment(attrs, simulated_snapshot)

      assert appt.snapshot_consultation_type_name == "Consulta Simulada"
      assert appt.snapshot_duration_minutes == 45
      assert Decimal.equal?(appt.snapshot_exact_price_ars, Decimal.new("12345.67"))
      assert appt.end_time == ~U[2026-10-15 14:45:00.000000Z]
    end

    test "falla de forma atómica ante datos inválidos sin dejar registros parciales", ctx do
      # snapshot con duración inválida (> 240 minutos)
      invalid_snapshot = %{
        name: "Consulta Excesiva",
        duration_minutes: 300,
        exact_price_ars: Decimal.new("10000.00")
      }

      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: ~U[2026-10-15 15:00:00Z]
      }

      assert {:error, {:validation_error, changeset}} =
               Booking.persist_appointment(attrs, invalid_snapshot)

      refute changeset.valid?
      assert :snapshot_duration_minutes in Keyword.keys(changeset.errors)

      # Verificar que la tabla appointments sigue vacía
      {:ok, %{rows: [[count]]}} =
        Ecto.Adapters.SQL.query(Repo, "SELECT count(*) FROM public.appointments", [])

      assert count == 0
    end
  end

  describe "to_response/2" do
    test "transforma appointment persistido a ReservationResponse estructurado", ctx do
      attrs = %{
        patient_profile_id: ctx.patient_profile_id,
        professional_account_id: ctx.professional_id,
        consultation_type_id: ctx.consultation_type_id,
        start_time: ~U[2026-10-15 09:00:00Z]
      }

      {:ok, appt} = Booking.persist_appointment(attrs)
      response = Booking.to_response(appt, true)

      assert response.appointment_id == appt.id
      assert response.patient_id == ctx.patient_profile_id
      assert response.professional_id == ctx.professional_id
      assert response.status == :reserved
      assert response.consultation_type_name == "Consulta General"
      assert response.duration_minutes == 30
      assert Decimal.equal?(response.base_price_amount, Decimal.new("15000.50"))
      assert response.relationship_created? == true
    end
  end
end
