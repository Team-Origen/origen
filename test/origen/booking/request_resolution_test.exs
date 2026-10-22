defmodule Origen.Booking.RequestResolutionTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Appointments.AssistedBooking
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Booking.RequestResolution
  alias Origen.Repo

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"
  @fixed_now ~U[2026-10-10 10:00:00Z]

  setup do
    :ok = Sandbox.checkout(Repo)

    prof_a_id = insert_internal_account!("prof.a@example.com", "professional", "active")
    prof_b_id = insert_internal_account!("prof.b@example.com", "professional", "active")
    secretary_id = insert_internal_account!("secre@example.com", "secretary", "active")
    admin_id = insert_internal_account!("admin@example.com", "administrator", "active")
    patient_id = insert_patient_profile!("Carlos", "Gomez", "34000111")

    insert_agenda_settings!(prof_a_id, "manual", "confirmed")
    insert_agenda_settings!(prof_b_id, "automatic", "confirmed")
    insert_consultation_type!(prof_a_id, @consultation_type_id, "Consulta A", "15000.00")

    %{
      prof_a_id: prof_a_id,
      prof_b_id: prof_b_id,
      secretary_id: secretary_id,
      admin_id: admin_id,
      patient_id: patient_id
    }
  end

  describe "accept_request/2 y reject_request/2" do
    test "C1: solicitud en estado requested ocupa el slot", ctx do
      start_time = ~U[2026-10-15 09:00:00Z]

      appt = insert_appointment!(ctx.patient_id, ctx.prof_a_id, start_time, "requested")

      # Comprobar que Booking.check_overlaps detecta el conflicto
      assert {:error, :professional_schedule_conflict} =
               Booking.check_overlaps(%{
                 professional_id: ctx.prof_a_id,
                 patient_id: insert_patient_profile!("Maria", "Lopez", "35000222"),
                 start_time: start_time,
                 end_time: DateTime.add(start_time, 30, :minute)
               })

      assert appt.status == "requested"
    end

    test "C2: profesional dueño acepta solicitud, pasando a confirmed y manteniendo el slot ocupado",
         ctx do
      start_time = ~U[2026-10-15 10:00:00Z]
      appt = insert_appointment!(ctx.patient_id, ctx.prof_a_id, start_time, "requested")

      assert {:ok, updated} = RequestResolution.accept_request(ctx.prof_a_id, appt.id)
      assert updated.status == "confirmed"

      persisted = Repo.get!(Appointment, appt.id)
      assert persisted.status == "confirmed"

      # El slot sigue ocupado
      assert {:error, :professional_schedule_conflict} =
               Booking.check_overlaps(%{
                 professional_id: ctx.prof_a_id,
                 patient_id: insert_patient_profile!("Maria", "Lopez", "35000222"),
                 start_time: start_time,
                 end_time: DateTime.add(start_time, 30, :minute)
               })
    end

    test "C3 & C4: profesional dueño rechaza solicitud pasando a cancelled y liberando el slot",
         ctx do
      start_time = ~U[2026-10-15 11:00:00Z]
      appt = insert_appointment!(ctx.patient_id, ctx.prof_a_id, start_time, "requested")

      assert {:ok, updated} = RequestResolution.reject_request(ctx.prof_a_id, appt.id)
      assert updated.status == "cancelled"

      persisted = Repo.get!(Appointment, appt.id)
      assert persisted.status == "cancelled"

      # C4: El slot queda libre para una nueva reserva
      other_patient_id = insert_patient_profile!("Pedro", "Sanchez", "36000333")

      assert {:ok, :no_conflict} =
               Booking.check_overlaps(%{
                 professional_id: ctx.prof_a_id,
                 patient_id: other_patient_id,
                 start_time: start_time,
                 end_time: DateTime.add(start_time, 30, :minute)
               })
    end

    test "C5: Secretaría y Administrador tienen denegada la aceptación o rechazo", ctx do
      appt =
        insert_appointment!(ctx.patient_id, ctx.prof_a_id, ~U[2026-10-15 14:00:00Z], "requested")

      assert {:error, :unauthorized} = RequestResolution.accept_request(ctx.secretary_id, appt.id)
      assert {:error, :unauthorized} = RequestResolution.reject_request(ctx.secretary_id, appt.id)
      assert {:error, :unauthorized} = RequestResolution.accept_request(ctx.admin_id, appt.id)
      assert {:error, :unauthorized} = RequestResolution.reject_request(ctx.admin_id, appt.id)

      persisted = Repo.get!(Appointment, appt.id)
      assert persisted.status == "requested"
    end

    test "C6: Profesional A no puede aceptar o rechazar solicitudes de Profesional B", ctx do
      appt =
        insert_appointment!(ctx.patient_id, ctx.prof_b_id, ~U[2026-10-15 15:00:00Z], "requested")

      assert {:error, :unauthorized} = RequestResolution.accept_request(ctx.prof_a_id, appt.id)
      assert {:error, :unauthorized} = RequestResolution.reject_request(ctx.prof_a_id, appt.id)

      persisted = Repo.get!(Appointment, appt.id)
      assert persisted.status == "requested"
    end

    test "C7: rechaza transición inválida sobre turnos ya confirmados o cancelados", ctx do
      confirmed_appt =
        insert_appointment!(ctx.patient_id, ctx.prof_a_id, ~U[2026-10-15 16:00:00Z], "confirmed")

      assert {:error, :invalid_status_transition} =
               RequestResolution.accept_request(ctx.prof_a_id, confirmed_appt.id)

      assert {:error, :invalid_status_transition} =
               RequestResolution.reject_request(ctx.prof_a_id, confirmed_appt.id)
    end

    test "C7a: aceptar una solicitud registra el evento de auditoría append-only appointment_confirmed",
         ctx do
      appt =
        insert_appointment!(ctx.patient_id, ctx.prof_a_id, ~U[2026-10-15 16:30:00Z], "requested")

      assert {:ok, _updated} = RequestResolution.accept_request(ctx.prof_a_id, appt.id)

      prof_ref = "internal_account:#{ctx.prof_a_id}"
      entity_ref = "appointment:#{appt.id}"

      assert [
               %{
                 actor_kind: "professional",
                 actor_ref: ^prof_ref,
                 event: "appointment_confirmed",
                 entity_kind: "appointment",
                 entity_ref: ^entity_ref,
                 result: "succeeded"
               }
             ] = audit_events_for(appt.id)
    end

    test "C7b: rechazar una solicitud registra el evento de auditoría append-only appointment_cancelled",
         ctx do
      appt =
        insert_appointment!(ctx.patient_id, ctx.prof_a_id, ~U[2026-10-15 16:45:00Z], "requested")

      assert {:ok, _updated} = RequestResolution.reject_request(ctx.prof_a_id, appt.id)

      prof_ref = "internal_account:#{ctx.prof_a_id}"
      entity_ref = "appointment:#{appt.id}"

      assert [
               %{
                 actor_kind: "professional",
                 actor_ref: ^prof_ref,
                 event: "appointment_cancelled",
                 entity_kind: "appointment",
                 entity_ref: ^entity_ref,
                 result: "succeeded"
               }
             ] = audit_events_for(appt.id)
    end

    test "C7c: actor no autorizado con turno inexistente recibe :unauthorized y no :appointment_not_found",
         ctx do
      assert {:error, :unauthorized} =
               RequestResolution.accept_request(ctx.secretary_id, 999_999)

      assert {:error, :unauthorized} =
               RequestResolution.reject_request(ctx.admin_id, 999_999)

      inactive_prof_id =
        insert_internal_account!("prof.inactive@example.com", "professional", "active")

      # Inactivar sin violar internal_accounts_state_fields_check (debe perder credenciales).
      {:ok, _} =
        SQL.query(
          Repo,
          """
          UPDATE public.internal_accounts
          SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL
          WHERE id = $1
          """,
          [inactive_prof_id]
        )

      assert {:error, :unauthorized} =
               RequestResolution.accept_request(inactive_prof_id, 999_999)

      # Un profesional activo válido sí distingue el turno inexistente.
      assert {:error, :appointment_not_found} =
               RequestResolution.accept_request(ctx.prof_a_id, 999_999)
    end
  end

  describe "configuración de aprobación y subconfiguración de secretaría" do
    test "C8: cambio de modalidad de aprobación afecta sólo a nuevas reservas", ctx do
      # Solicitud creada previamente en modo manual
      appt =
        insert_appointment!(ctx.patient_id, ctx.prof_a_id, ~U[2026-10-15 08:00:00Z], "requested")

      # Profesional cambia su modalidad a automática
      assert {:ok, cfg} =
               RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
                 approval_mode: :automatic,
                 secretary_approval_mode: :confirmed
               })

      assert cfg.approval_mode == :automatic

      # La solicitud existente permanece en requested
      persisted = Repo.get!(Appointment, appt.id)
      assert persisted.status == "requested"

      # Las nuevas reservas asistidas ahora nacen confirmadas
      new_time = ~U[2026-10-16 09:00:00Z]

      assert {:ok, new_result} =
               AssistedBooking.reserve(
                 ctx.secretary_id,
                 ctx.patient_id,
                 %{
                   professional_id: ctx.prof_a_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: new_time
                 },
                 now: @fixed_now
               )

      assert new_result.status == :confirmed
    end

    test "C9: modo manual con subconfiguración de secretaría en confirmed confirma directamente",
         ctx do
      RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
        approval_mode: :manual,
        secretary_approval_mode: :confirmed
      })

      assert {:ok, result} =
               AssistedBooking.reserve(
                 ctx.secretary_id,
                 ctx.patient_id,
                 %{
                   professional_id: ctx.prof_a_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-17 10:00:00Z]
                 },
                 now: @fixed_now
               )

      assert result.status == :confirmed
    end

    test "C10: modo manual con subconfiguración de secretaría en requested genera turno requested",
         ctx do
      RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
        approval_mode: :manual,
        secretary_approval_mode: :requested
      })

      assert {:ok, result} =
               AssistedBooking.reserve(
                 ctx.secretary_id,
                 ctx.patient_id,
                 %{
                   professional_id: ctx.prof_a_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-17 11:00:00Z]
                 },
                 now: @fixed_now
               )

      assert result.status == :requested
    end

    test "C11: actualizar sólo approval_mode preserva secretary_approval_mode existente y viceversa",
         ctx do
      # Estado inicial: manual + requested
      assert {:ok, _} =
               RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
                 approval_mode: :manual,
                 secretary_approval_mode: "requested"
               })

      # Actualizar sólo approval_mode: la subconfiguración se preserva
      assert {:ok, cfg} =
               RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
                 approval_mode: :manual
               })

      assert cfg.approval_mode == :manual
      assert cfg.secretary_approval_mode == :requested

      # Actualizar sólo secretary_approval_mode: la modalidad se preserva
      assert {:ok, cfg2} =
               RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
                 secretary_approval_mode: :confirmed
               })

      assert cfg2.approval_mode == :manual
      assert cfg2.secretary_approval_mode == :confirmed

      # Una clave provista con valor inválido sigue siendo error explícito
      assert {:error, :invalid_approval_mode} =
               RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
                 approval_mode: :bogus
               })

      assert {:error, :invalid_secretary_approval_mode} =
               RequestResolution.update_approval_configuration(ctx.prof_a_id, %{
                 secretary_approval_mode: "bogus"
               })
    end
  end

  # Helpers privados de inserción

  defp audit_events_for(appointment_id) do
    {:ok, %{rows: rows}} =
      SQL.query(
        Repo,
        """
        SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result
        FROM public.audit_events
        WHERE entity_ref = $1
        """,
        ["appointment:#{appointment_id}"]
      )

    Enum.map(rows, fn [actor_kind, actor_ref, event, entity_kind, entity_ref, result] ->
      %{
        actor_kind: actor_kind,
        actor_ref: actor_ref,
        event: event,
        entity_kind: entity_kind,
        entity_ref: entity_ref,
        result: result
      }
    end)
  end

  defp insert_internal_account!(email, role, state) do
    query = """
    INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
    VALUES ($1, $2, $3, 'hash', decode('0102', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
    RETURNING id
    """

    {:ok, %{rows: [[id]]}} = SQL.query(Repo, query, [email, role, state])
    id
  end

  defp insert_agenda_settings!(owner_account_id, approval_mode, secretary_mode) do
    query = """
    INSERT INTO public.agenda_settings (owner_account_id, interval_minutes, approval_mode, secretary_approval_mode, created_at, updated_at)
    VALUES ($1, 30, $2, $3, clock_timestamp(), clock_timestamp())
    """

    {:ok, _} = SQL.query(Repo, query, [owner_account_id, approval_mode, secretary_mode])
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

  defp insert_appointment!(patient_id, professional_id, start_time, status) do
    end_time = DateTime.add(start_time, 30, :minute)

    %Appointment{}
    |> Appointment.changeset(%{
      patient_profile_id: patient_id,
      professional_account_id: professional_id,
      consultation_type_id: @consultation_type_id,
      start_time: start_time,
      end_time: end_time,
      status: status,
      snapshot_consultation_type_name: "Consulta A",
      snapshot_duration_minutes: 30,
      snapshot_exact_price_ars: Decimal.new("15000.00")
    })
    |> Repo.insert!()
  end
end
