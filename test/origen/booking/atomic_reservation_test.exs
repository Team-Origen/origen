defmodule Origen.Booking.AtomicReservationTest do
  @moduledoc """
  Pruebas de la operación única y transaccional de reserva (Issue #66 / PLN-08):
  turno + relación Profesional-Paciente + evento de auditoría append-only en una
  sola transacción, con reversión total ante cualquier falla
  (`docs/booking/RESERVATION_CASES.md` §2.4, §3.4).
  """

  use ExUnit.Case, async: false

  alias Origen.Booking
  alias Origen.Booking.ReservationResponse
  alias Origen.Repo

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"
  @before_d1 ~U[2026-09-23 12:00:00Z]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    professional_id = insert_internal_account("dr.smith@example.com")
    secretary_id = insert_internal_account("secretary@example.com", "secretary")

    :ok = insert_agenda_settings(professional_id)
    :ok = insert_consultation_type(professional_id)
    patient_profile_id = insert_patient_profile()

    %{
      professional_id: professional_id,
      secretary_id: secretary_id,
      patient_profile_id: patient_profile_id
    }
  end

  describe "primera reserva válida (V01)" do
    test "crea turno, relación y auditoría atómicamente con relationship_created?: true", ctx do
      assert {:ok, %ReservationResponse{} = response} =
               Booking.reserve_appointment(
                 patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
                 now: @before_d1
               )

      assert response.status == :reserved
      assert response.relationship_created? == true
      assert is_integer(response.appointment_id)
      assert response.patient_id == ctx.patient_profile_id
      assert response.professional_id == ctx.professional_id
      assert response.consultation_type_name == "Consulta General"
      assert response.duration_minutes == 30
      assert Decimal.equal?(response.base_price_amount, Decimal.new("15000.50"))

      assert count("appointments") == 1
      assert count("professional_patient_relationships") == 1
      assert reservation_audit_count() == 1

      assert [[_id, prof_id, pat_id, established_at, first_appt_id]] = relationships()

      assert prof_id == ctx.professional_id
      assert pat_id == ctx.patient_profile_id
      assert %DateTime{} = established_at
      assert first_appt_id == response.appointment_id

      assert [
               [
                 "patient",
                 actor_ref,
                 "appointment_reserved",
                 "appointment",
                 entity_ref,
                 "succeeded"
               ]
             ] =
               audit_events()

      assert actor_ref == "patient:#{ctx.patient_profile_id}"
      assert entity_ref == "appointment:#{response.appointment_id}"
    end
  end

  describe "reserva posterior (V10)" do
    test "no duplica la relación existente y reporta relationship_created?: false", ctx do
      {:ok, first} =
        Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
          now: @before_d1
        )

      assert {:ok, second} =
               Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 10:00:00Z]),
                 now: @before_d1
               )

      assert second.appointment_id != first.appointment_id
      assert second.status == :reserved
      assert second.relationship_created? == false

      assert count("appointments") == 2
      assert count("professional_patient_relationships") == 1
      assert reservation_audit_count() == 2
    end
  end

  describe "turno nacido en :requested (V02, §2.4)" do
    test "no crea relación Profesional-Paciente pero sí audita", ctx do
      assert {:ok, response} =
               Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
                 now: @before_d1,
                 initial_status: :requested
               )

      assert response.status == :requested
      assert response.relationship_created? == false

      assert count("appointments") == 1
      assert count("professional_patient_relationships") == 0

      assert [
               [
                 "patient",
                 _actor_ref,
                 "appointment_created",
                 "appointment",
                 _entity_ref,
                 "succeeded"
               ]
             ] =
               audit_events()
    end
  end

  describe "reversión transaccional total (T02 / T03)" do
    test "fallo al insertar la relación revierte turno y auditoría", ctx do
      assert {:error, :relationship_insertion_failed} =
               Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
                 now: @before_d1,
                 fail_at: :relationship
               )

      assert count("appointments") == 0
      assert count("professional_patient_relationships") == 0
      assert reservation_audit_count() == 0
    end

    test "fallo al insertar la auditoría revierte turno y relación", ctx do
      assert {:error, :fallo_auditoria} =
               Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
                 now: @before_d1,
                 fail_at: :audit_event
               )

      assert count("appointments") == 0
      assert count("professional_patient_relationships") == 0
      assert reservation_audit_count() == 0
    end
  end

  describe "auditoría por actor" do
    test "reserva asistida audita actor secretary con internal_account (V04)", ctx do
      assert {:ok, response} =
               Booking.reserve_appointment(
                 %{
                   actor: %{role: :secretary, id: ctx.secretary_id},
                   patient_id: ctx.patient_profile_id,
                   professional_id: ctx.professional_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-15 09:00:00Z],
                   patient_agreed_schedule: true
                 },
                 now: @before_d1
               )

      assert response.relationship_created? == true

      expected_actor_ref = "internal_account:#{ctx.secretary_id}"
      expected_entity_ref = "appointment:#{response.appointment_id}"

      assert [
               [
                 "secretary",
                 ^expected_actor_ref,
                 "appointment_reserved",
                 "appointment",
                 ^expected_entity_ref,
                 "succeeded"
               ]
             ] = audit_events()
    end

    test "reserva del profesional durante D-1 audita appointment_confirmed (V08)", ctx do
      insert_relationship!(ctx.professional_id, ctx.patient_profile_id)

      assert {:ok, response} =
               Booking.reserve_appointment(
                 %{
                   actor: %{role: :professional, id: ctx.professional_id},
                   patient_id: ctx.patient_profile_id,
                   professional_id: ctx.professional_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-15 09:00:00Z]
                 },
                 now: ~U[2026-10-14 08:00:00Z]
               )

      assert response.status == :confirmed
      assert response.relationship_created? == false
      assert count("professional_patient_relationships") == 1

      expected_actor_ref = "internal_account:#{ctx.professional_id}"
      expected_entity_ref = "appointment:#{response.appointment_id}"

      assert [
               [
                 "professional",
                 ^expected_actor_ref,
                 "appointment_confirmed",
                 "appointment",
                 ^expected_entity_ref,
                 "succeeded"
               ]
             ] =
               audit_events()
    end
  end

  describe "autorización sobre la tabla durable (RF-05)" do
    test "profesional reserva para paciente vinculado sin turnos previos", ctx do
      insert_relationship!(ctx.professional_id, ctx.patient_profile_id)

      assert {:ok, response} =
               Booking.reserve_appointment(
                 %{
                   actor: %{role: :professional, id: ctx.professional_id},
                   patient_id: ctx.patient_profile_id,
                   professional_id: ctx.professional_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-15 09:00:00Z]
                 },
                 now: @before_d1
               )

      assert response.status == :reserved
      assert response.relationship_created? == false
    end

    test "profesional no puede reservar para paciente sin relación ni turnos previos (R05)",
         ctx do
      assert {:error, :paciente_no_permitido} =
               Booking.reserve_appointment(
                 %{
                   actor: %{role: :professional, id: ctx.professional_id},
                   patient_id: ctx.patient_profile_id,
                   professional_id: ctx.professional_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-15 09:00:00Z]
                 },
                 now: @before_d1
               )

      assert count("appointments") == 0
      assert count("professional_patient_relationships") == 0
      assert reservation_audit_count() == 0
    end
  end

  describe "fallos previos a la transacción" do
    test "solicitud mal formada falla rápido sin tocar la base de datos", _ctx do
      assert {:error, {:malformed_request, _errors}} =
               Booking.reserve_appointment(%{actor: %{role: :patient}}, now: @before_d1)

      assert count("appointments") == 0
      assert count("professional_patient_relationships") == 0
      assert reservation_audit_count() == 0
    end

    test "paciente el día D excede el corte de reserva autónoma (R04)", ctx do
      assert {:error, :corte_reserva_cerrado} =
               Booking.reserve_appointment(
                 patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
                 now: ~U[2026-10-15 08:00:00Z]
               )

      assert count("appointments") == 0
      assert count("professional_patient_relationships") == 0
      assert reservation_audit_count() == 0
    end

    test "conflicto de agenda del profesional no crea relación ni auditoría (C01)", ctx do
      {:ok, _first} =
        Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 09:00:00Z]),
          now: @before_d1
        )

      assert {:error, :slot_already_booked} =
               Booking.reserve_appointment(patient_request(ctx, ~U[2026-10-15 09:15:00Z]),
                 now: @before_d1
               )

      assert count("appointments") == 1
      assert count("professional_patient_relationships") == 1
      assert reservation_audit_count() == 1
    end
  end

  # Fixtures y helpers

  defp patient_request(ctx, start_time) do
    %{
      actor: %{role: :patient, id: ctx.patient_profile_id},
      patient_id: ctx.patient_profile_id,
      professional_id: ctx.professional_id,
      consultation_type_id: @consultation_type_id,
      start_time: start_time
    }
  end

  defp count(table) do
    {:ok, %{rows: [[n]]}} =
      Ecto.Adapters.SQL.query(Repo, "SELECT count(*) FROM public.#{table}", [])

    n
  end

  defp relationships do
    {:ok, %{rows: rows}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        SELECT id, professional_account_id, patient_profile_id, established_at, first_appointment_id
        FROM public.professional_patient_relationships
        ORDER BY id
        """,
        []
      )

    rows
  end

  defp audit_events do
    {:ok, %{rows: rows}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result
        FROM public.audit_events
        WHERE entity_kind = 'appointment'
        ORDER BY id
        """,
        []
      )

    rows
  end

  # `audit_events` es append-only y compartida por todo el sistema: el conteo se
  # acota a los eventos de reserva (`entity_kind = 'appointment'`), que ninguna
  # otra suite escribe.
  defp reservation_audit_count, do: length(audit_events())

  defp insert_relationship!(professional_id, patient_profile_id) do
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.professional_patient_relationships (professional_account_id, patient_profile_id)
        VALUES ($1, $2)
        """,
        [professional_id, patient_profile_id]
      )

    :ok
  end

  defp insert_internal_account(email, role \\ "professional") do
    {:ok, %{rows: [[account_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES ($1, $2, 'active', 'hashed_pass_placeholder', decode('010203', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [email, role]
      )

    account_id
  end

  defp insert_agenda_settings(owner_account_id) do
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.agenda_settings (owner_account_id, interval_minutes, created_at, updated_at)
        VALUES ($1, 30, clock_timestamp(), clock_timestamp())
        """,
        [owner_account_id]
      )

    :ok
  end

  defp insert_consultation_type(owner_account_id) do
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
        [Ecto.UUID.dump!(@consultation_type_id), owner_account_id]
      )

    :ok
  end

  defp insert_patient_profile do
    unique = System.unique_integer([:positive])

    {:ok, %{rows: [[persona_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
        VALUES ('Juan', 'Perez', 'dni', $1, '1990-01-01', clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [Integer.to_string(30_000_000 + rem(unique, 60_000_000))]
      )

    {:ok, %{rows: [[profile_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.patient_profiles (persona_id, email, state, phone, phone_verified, created_at, updated_at)
        VALUES ($1, $2, 'completed', '+5491100001111', true, clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [persona_id, "paciente#{unique}@example.com"]
      )

    profile_id
  end
end
