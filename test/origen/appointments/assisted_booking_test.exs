defmodule Origen.Appointments.AssistedBookingTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Appointments.AssistedBooking
  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Repo

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"
  @fixed_now ~U[2026-10-10 10:00:00Z]

  setup do
    :ok = Sandbox.checkout(Repo)

    professional_id = insert_internal_account!("dr.smith@example.com", "professional", "active")
    secretary_id = insert_internal_account!("secretary@example.com", "secretary", "active")
    patient_profile_id = insert_patient_profile!("Juan", "Perez", "35000111")

    insert_agenda_settings!(professional_id)
    insert_consultation_type!(professional_id, @consultation_type_id, "Consulta General", "15000.00")

    %{
      professional_id: professional_id,
      secretary_id: secretary_id,
      patient_profile_id: patient_profile_id
    }
  end

  describe "reserve/4" do
    test "C1: agendamiento asistido exitoso crea turno y relación Profesional-Paciente", ctx do
      start_time = ~U[2026-10-15 09:00:00Z]

      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: start_time
      }

      assert {:ok, result} =
               AssistedBooking.reserve(ctx.secretary_id, ctx.patient_profile_id, params, now: @fixed_now)

      assert result.status == :confirmed
      assert result.patient_id == ctx.patient_profile_id
      assert result.professional_id == ctx.professional_id
      assert result.consultation_type_name == "Consulta General"
      assert result.relationship_created? == true

      # Verifica ocupación en base de datos
      appt = Repo.get!(Appointment, result.appointment_id)
      assert appt.status == "confirmed"

      # Verifica relación Profesional-Paciente
      rel =
        Repo.get_by(ProfessionalPatientRelationship,
          professional_account_id: ctx.professional_id,
          patient_profile_id: ctx.patient_profile_id
        )

      assert rel != nil
      assert rel.first_appointment_id == appt.id
    end

    test "C2: modo de aprobación automática confirma el turno directamente", ctx do
      start_time = ~U[2026-10-15 10:00:00Z]

      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: start_time,
        approval_mode: :automatic
      }

      assert {:ok, result} =
               AssistedBooking.reserve(ctx.secretary_id, ctx.patient_profile_id, params, now: @fixed_now)

      assert result.status == :confirmed
    end

    test "C3: modo de aprobación manual genera turno en estado requested y crea relación", ctx do
      start_time = ~U[2026-10-15 11:00:00Z]

      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: start_time,
        approval_mode: :manual
      }

      assert {:ok, result} =
               AssistedBooking.reserve(ctx.secretary_id, ctx.patient_profile_id, params, now: @fixed_now)

      assert result.status == :requested
      assert result.relationship_created? == true

      # Verifica persistencia
      appt = Repo.get!(Appointment, result.appointment_id)
      assert appt.status == "requested"

      rel =
        Repo.get_by(ProfessionalPatientRelationship,
          professional_account_id: ctx.professional_id,
          patient_profile_id: ctx.patient_profile_id
        )

      assert rel != nil
    end

    test "C4: horario ya ocupado por otro turno rechaza con :slot_already_booked", ctx do
      start_time = ~U[2026-10-15 14:00:00Z]

      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: start_time
      }

      assert {:ok, _first} =
               AssistedBooking.reserve(ctx.secretary_id, ctx.patient_profile_id, params, now: @fixed_now)

      other_patient_id = insert_patient_profile!("Maria", "Gomez", "36000222")

      assert {:error, :slot_already_booked} =
               AssistedBooking.reserve(ctx.secretary_id, other_patient_id, params, now: @fixed_now)
    end

    test "C5: paciente no encontrado rechaza con :patient_not_found", ctx do
      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: ~U[2026-10-15 15:00:00Z]
      }

      assert {:error, :patient_not_found} =
               AssistedBooking.reserve(ctx.secretary_id, 999_999, params, now: @fixed_now)
    end

    test "C6: no requiere patient_agreed_schedule para agendar asistido", ctx do
      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: ~U[2026-10-15 16:00:00Z],
        patient_agreed_schedule: false
      }

      assert {:ok, result} =
               AssistedBooking.reserve(ctx.secretary_id, ctx.patient_profile_id, params, now: @fixed_now)

      assert result.status == :confirmed
    end

    test "C7: Secretaría tiene denegada la resolución de solicitudes (aprobación/rechazo)", ctx do
      assert {:error, :unauthorized} =
               AssistedBooking.approve_request(ctx.secretary_id, 123)

      assert {:error, :unauthorized} =
               AssistedBooking.reject_request(ctx.secretary_id, 123)
    end

    test "C8: actor no autorizado (profesional o paciente) no puede operar reserva asistida", ctx do
      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: ~U[2026-10-15 17:00:00Z]
      }

      assert {:error, :unauthorized} =
               AssistedBooking.reserve(ctx.professional_id, ctx.patient_profile_id, params, now: @fixed_now)
    end

    test "C9: cuenta inexistente rechaza con :unauthorized", ctx do
      params = %{
        professional_id: ctx.professional_id,
        consultation_type_id: @consultation_type_id,
        start_time: ~U[2026-10-15 17:00:00Z]
      }

      assert {:error, :unauthorized} =
               AssistedBooking.reserve(888_888, ctx.patient_profile_id, params, now: @fixed_now)
    end

    test "C10: profesional inactivo rechaza con :invalid_professional", ctx do
      inactive_prof_id = insert_internal_account!("inactive.dr@example.com", "professional", "pending_activation")

      params = %{
        professional_id: inactive_prof_id,
        consultation_type_id: @consultation_type_id,
        start_time: ~U[2026-10-15 17:00:00Z]
      }

      assert {:error, :invalid_professional} =
               AssistedBooking.reserve(ctx.secretary_id, ctx.patient_profile_id, params, now: @fixed_now)
    end
  end

  describe "consultas auxiliares de catálogo y agenda" do
    test "list_consultation_types/1 lista tipos activos del profesional", ctx do
      assert {:ok, types} = AssistedBooking.list_consultation_types(ctx.professional_id)
      assert length(types) == 1
      [type] = types
      assert type.name == "Consulta General"
      assert type.status == :active
    end

    test "get_daily_schedule/3 consulta slots con el calendario", ctx do
      assert {:ok, schedule} =
               AssistedBooking.get_daily_schedule(ctx.professional_id, ~D[2026-10-15],
                 duration_minutes: 30,
                 calendar_adapter: Origen.Appointments.DatabaseCalendar
               )

      assert is_list(schedule.slots)
    end
  end

  # Helpers privados de inserción

  defp insert_internal_account!(email, role, "active") do
    query = """
    INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
    VALUES ($1, $2, 'active', 'hash', decode('0102', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
    RETURNING id
    """

    {:ok, %{rows: [[id]]}} = SQL.query(Repo, query, [email, role])
    id
  end

  defp insert_internal_account!(email, role, "pending_activation") do
    query = """
    INSERT INTO public.internal_accounts (email, role, state, created_at, updated_at)
    VALUES ($1, $2, 'pending_activation', clock_timestamp(), clock_timestamp())
    RETURNING id
    """

    {:ok, %{rows: [[id]]}} = SQL.query(Repo, query, [email, role])
    id
  end

  defp insert_agenda_settings!(owner_account_id) do
    query = """
    INSERT INTO public.agenda_settings (owner_account_id, interval_minutes, created_at, updated_at)
    VALUES ($1, 30, clock_timestamp(), clock_timestamp())
    """

    {:ok, _} = SQL.query(Repo, query, [owner_account_id])
    :ok
  end

  defp insert_consultation_type!(owner_account_id, uuid_str, name, price_str) do
    query = """
    INSERT INTO public.consultation_types (
      id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at
    ) VALUES (
      $1, $2, $3, $4, '#112233', 1, 'active', clock_timestamp(), clock_timestamp()
    )
    """

    {:ok, _} =
      SQL.query(Repo, query, [
        Ecto.UUID.dump!(uuid_str),
        owner_account_id,
        name,
        Decimal.new(price_str)
      ])

    :ok
  end

  defp insert_patient_profile!(first_name, last_name, document_number) do
    unique = System.unique_integer([:positive])

    query_persona = """
    INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
    VALUES ($1, $2, 'dni', $3, '1990-01-01', clock_timestamp(), clock_timestamp())
    RETURNING id
    """

    {:ok, %{rows: [[persona_id]]}} =
      SQL.query(Repo, query_persona, [first_name, last_name, document_number])

    query_profile = """
    INSERT INTO public.patient_profiles (persona_id, email, state, phone, phone_verified, created_at, updated_at)
    VALUES ($1, $2, 'completed', '+5491100001111', true, clock_timestamp(), clock_timestamp())
    RETURNING id
    """

    {:ok, %{rows: [[profile_id]]}} =
      SQL.query(Repo, query_profile, [persona_id, "paciente#{unique}@example.com"])

    profile_id
  end
end
