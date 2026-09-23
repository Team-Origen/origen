defmodule Origen.Booking.AuthorizationTest do
  @moduledoc """
  Pruebas unitarias e integradas de las reglas de autorización por actor para la
  reserva de turnos (Issue #64 / PLN-08, `docs/booking/RESERVATION_CASES.md` §2.1).

  Cubre los tres actores del motor: Paciente autónomo, Secretaría asistida y
  Profesional, validando identidad, elegibilidad de perfil, teléfono verificado,
  acuerdo de horario asistido y lista permitida RF-05.
  """

  use ExUnit.Case, async: false

  alias Origen.Booking
  alias Origen.Booking.Authorization
  alias Origen.Booking.ReservationRequest
  alias Origen.Repo

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    professional_id = insert_internal_account("dr.smith@example.com", "professional", "active")
    secretary_id = insert_internal_account("secretary@example.com", "secretary", "active")

    insert_agenda_settings(professional_id)
    insert_consultation_type(professional_id)

    %{
      professional_id: professional_id,
      secretary_id: secretary_id,
      patient_profile_id: insert_patient_profile("completed", true)
    }
  end

  describe "Paciente autónomo" do
    test "autoriza la reserva con perfil completado y teléfono verificado", ctx do
      params = patient_params(ctx.patient_profile_id, ctx.professional_id)

      assert {:ok, authorization} = Authorization.authorize_reservation(params)

      assert authorization.actor == %{role: :patient, id: ctx.patient_profile_id}
      assert authorization.patient_profile.id == ctx.patient_profile_id
      assert authorization.patient_profile.state == "completed"
      assert authorization.professional_account.id == ctx.professional_id
      assert authorization.professional_account.role == "professional"
      assert authorization.professional_account.state == "active"
    end

    test "rechaza con perfil pendiente de completar (R01)", ctx do
      pending_profile_id = insert_patient_profile("pending_completion", false)

      assert {:error, :perfil_incompleto} =
               Authorization.authorize_reservation(
                 patient_params(pending_profile_id, ctx.professional_id)
               )
    end

    test "rechaza con perfil pendiente de revisión de secretaría (R01)", ctx do
      review_profile_id = insert_patient_profile("pending_secretary_review", false)

      assert {:error, :perfil_incompleto} =
               Authorization.authorize_reservation(
                 patient_params(review_profile_id, ctx.professional_id)
               )
    end

    test "rechaza con teléfono primario no verificado (R02)", ctx do
      unverified_profile_id = insert_patient_profile("completed", false)

      assert {:error, :telefono_no_verificado} =
               Authorization.authorize_reservation(
                 patient_params(unverified_profile_id, ctx.professional_id)
               )
    end

    test "rechaza cuando el actor no es el paciente reservado", ctx do
      other_patient_id = ctx.patient_profile_id + 1

      params = %{
        actor: %{role: :patient, id: other_patient_id},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id
      }

      assert {:error, :forbidden_patient_identity} = Authorization.authorize_reservation(params)
    end

    test "rechaza si el perfil del paciente no existe", ctx do
      assert {:error, :patient_profile_not_found} =
               Authorization.authorize_reservation(patient_params(999_999, ctx.professional_id))
    end

    test "rechaza si el profesional no es una cuenta interna activa", ctx do
      inactive_professional_id =
        insert_internal_account("dr.old@example.com", "professional", "pending_activation")

      assert {:error, :invalid_professional_account} =
               Authorization.authorize_reservation(
                 patient_params(ctx.patient_profile_id, inactive_professional_id)
               )
    end
  end

  describe "Secretaría asistida" do
    test "autoriza la reserva asistida con horario acordado y perfil incompleto (RF-02)", ctx do
      pending_profile_id = insert_patient_profile("pending_completion", false)

      params = %{
        actor: %{role: :secretary, id: ctx.secretary_id},
        patient_id: pending_profile_id,
        professional_id: ctx.professional_id,
        patient_agreed_schedule: true
      }

      assert {:ok, authorization} = Authorization.authorize_reservation(params)

      assert authorization.actor == %{role: :secretary, id: ctx.secretary_id}
      assert authorization.patient_profile.id == pending_profile_id
      assert authorization.patient_profile.state == "pending_completion"
      assert authorization.professional_account.id == ctx.professional_id
    end

    test "autoriza también un perfil completado con teléfono no verificado (RF-02)", ctx do
      unverified_profile_id = insert_patient_profile("completed", false)

      params = %{
        actor: %{role: :secretary, id: ctx.secretary_id},
        patient_id: unverified_profile_id,
        professional_id: ctx.professional_id,
        patient_agreed_schedule: true
      }

      assert {:ok, _authorization} = Authorization.authorize_reservation(params)
    end

    test "rechaza sin declaración de horario acordado con el paciente", ctx do
      params = %{
        actor: %{role: :secretary, id: ctx.secretary_id},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id,
        patient_agreed_schedule: false
      }

      assert {:error, :acuerdo_horario_requerido} = Authorization.authorize_reservation(params)
    end

    test "rechaza con patient_agreed_schedule ausente", ctx do
      params = %{
        actor: %{role: :secretary, id: ctx.secretary_id},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id
      }

      assert {:error, :acuerdo_horario_requerido} = Authorization.authorize_reservation(params)
    end

    test "rechaza si la cuenta de secretaría no existe", ctx do
      params = %{
        actor: %{role: :secretary, id: 999_999},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id,
        patient_agreed_schedule: true
      }

      assert {:error, :invalid_secretary_account} = Authorization.authorize_reservation(params)
    end

    test "rechaza si la cuenta de secretaría está inactiva", ctx do
      pending_secretary_id =
        insert_internal_account(
          "pending.secretary@example.com",
          "secretary",
          "pending_activation"
        )

      params = %{
        actor: %{role: :secretary, id: pending_secretary_id},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id,
        patient_agreed_schedule: true
      }

      assert {:error, :invalid_secretary_account} = Authorization.authorize_reservation(params)
    end

    test "rechaza si la cuenta activa no tiene rol secretary", ctx do
      assert {:error, :invalid_secretary_account} =
               Authorization.authorize_reservation(%{
                 actor: %{role: :secretary, id: ctx.professional_id},
                 patient_id: ctx.patient_profile_id,
                 professional_id: ctx.professional_id,
                 patient_agreed_schedule: true
               })
    end
  end

  describe "Profesional" do
    test "autoriza la reserva para un paciente con turno previo válido (RF-05)", ctx do
      insert_prior_appointment!(ctx.patient_profile_id, ctx.professional_id, "reserved")

      params = professional_params(ctx.patient_profile_id, ctx.professional_id)

      assert {:ok, authorization} = Authorization.authorize_reservation(params)

      assert authorization.actor == %{role: :professional, id: ctx.professional_id}
      assert authorization.patient_profile.id == ctx.patient_profile_id
      assert authorization.professional_account.id == ctx.professional_id
    end

    test "rechaza cuando el actor no opera su propia agenda", ctx do
      other_professional_id = ctx.professional_id + 1

      params = %{
        actor: %{role: :professional, id: ctx.professional_id},
        patient_id: ctx.patient_profile_id,
        professional_id: other_professional_id
      }

      assert {:error, :forbidden_professional_identity} =
               Authorization.authorize_reservation(params)
    end

    test "rechaza a un paciente sin relación previa (R05)", ctx do
      params = professional_params(ctx.patient_profile_id, ctx.professional_id)

      assert {:error, :paciente_no_permitido} = Authorization.authorize_reservation(params)
    end

    test "rechaza cuando la única reserva previa quedó cancelada", ctx do
      insert_prior_appointment!(ctx.patient_profile_id, ctx.professional_id, "cancelled")

      params = professional_params(ctx.patient_profile_id, ctx.professional_id)

      assert {:error, :paciente_no_permitido} = Authorization.authorize_reservation(params)
    end

    test "rechaza cuando la única reserva previa quedó en estado Solicitado (§2.4)", ctx do
      insert_prior_appointment!(ctx.patient_profile_id, ctx.professional_id, "requested")

      params = professional_params(ctx.patient_profile_id, ctx.professional_id)

      assert {:error, :paciente_no_permitido} = Authorization.authorize_reservation(params)
    end

    test "rechaza si la cuenta del profesional no está activa", ctx do
      pending_professional_id =
        insert_internal_account("dr.pending@example.com", "professional", "pending_activation")

      insert_prior_appointment!(ctx.patient_profile_id, pending_professional_id, "reserved")

      params = professional_params(ctx.patient_profile_id, pending_professional_id)

      assert {:error, :invalid_professional_account} =
               Authorization.authorize_reservation(params)
    end

    test "rechaza a un paciente relacionado únicamente con otro profesional", ctx do
      other_professional_id =
        insert_internal_account("dr.jones@example.com", "professional", "active")

      insert_prior_appointment!(ctx.patient_profile_id, other_professional_id, "reserved")

      params = professional_params(ctx.patient_profile_id, ctx.professional_id)

      assert {:error, :paciente_no_permitido} = Authorization.authorize_reservation(params)
    end
  end

  describe "Contrato de entrada y delegación" do
    test "acepta un %ReservationRequest{} validado (paciente válido)", ctx do
      {:ok, request} =
        ReservationRequest.cast_and_validate(%{
          actor: %{role: :patient, id: ctx.patient_profile_id},
          patient_id: ctx.patient_profile_id,
          professional_id: ctx.professional_id,
          consultation_type_id: @consultation_type_id,
          start_time: ~U[2026-10-15 09:00:00Z]
        })

      assert {:ok, authorization} = Authorization.authorize_reservation(request)
      assert authorization.patient_profile.id == ctx.patient_profile_id
    end

    test "delega desde Origen.Booking.authorize_reservation/1 con mapa de parámetros", ctx do
      params = %{
        actor: %{role: :secretary, id: ctx.secretary_id},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id,
        patient_agreed_schedule: true
      }

      assert {:ok, authorization} = Booking.authorize_reservation(params)
      assert authorization.actor.role == :secretary
    end

    test "delega desde Origen.Booking.authorize_reservation/1 con struct", ctx do
      {:ok, request} =
        ReservationRequest.cast_and_validate(%{
          actor: %{role: :patient, id: ctx.patient_profile_id},
          patient_id: ctx.patient_profile_id,
          professional_id: ctx.professional_id,
          consultation_type_id: @consultation_type_id,
          start_time: ~U[2026-10-15 10:00:00Z],
          patient_agreed_schedule: false
        })

      assert {:ok, authorization} = Booking.authorize_reservation(request)
      assert authorization.actor.role == :patient
    end

    test "rechaza por defecto con rol de actor desconocido", ctx do
      params = %{
        actor: %{role: :administrator, id: 1},
        patient_id: ctx.patient_profile_id,
        professional_id: ctx.professional_id
      }

      assert {:error, :unauthorized} = Authorization.authorize_reservation(params)
    end

    test "rechaza por defecto con actor ausente", ctx do
      params = %{patient_id: ctx.patient_profile_id, professional_id: ctx.professional_id}

      assert {:error, :unauthorized} = Authorization.authorize_reservation(params)
    end

    test "rechaza por defecto con payload que no es un mapa", _ctx do
      assert {:error, :unauthorized} = Authorization.authorize_reservation(nil)
      assert {:error, :unauthorized} = Authorization.authorize_reservation("patient")
    end
  end

  # Fixtures y helpers

  defp patient_params(patient_id, professional_id) do
    %{
      actor: %{role: :patient, id: patient_id},
      patient_id: patient_id,
      professional_id: professional_id
    }
  end

  defp professional_params(patient_id, professional_id) do
    %{
      actor: %{role: :professional, id: professional_id},
      patient_id: patient_id,
      professional_id: professional_id
    }
  end

  defp insert_internal_account(email, role, "active") do
    query_internal_account!(
      email,
      role,
      "active",
      "'hashed_pass_placeholder'",
      "decode('010203', 'hex')",
      "clock_timestamp()"
    )
  end

  defp insert_internal_account(email, role, "pending_activation") do
    query_internal_account!(email, role, "pending_activation", "NULL", "NULL", "NULL")
  end

  defp query_internal_account!(email, role, state, password_hash, totp_secret, activated_at) do
    query = """
    INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
    VALUES ($1, $2, $3, #{password_hash}, #{totp_secret}, #{activated_at}, clock_timestamp(), clock_timestamp())
    RETURNING id
    """

    {:ok, %{rows: [[account_id]]}} = Ecto.Adapters.SQL.query(Repo, query, [email, role, state])
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

  defp insert_patient_profile(state, phone_verified) do
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
        VALUES ($1, $2, $3, '+5491100001111', $4, clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [persona_id, "paciente#{unique}@example.com", state, phone_verified]
      )

    profile_id
  end

  defp insert_prior_appointment!(patient_profile_id, professional_id, status) do
    start_time = ~U[2026-10-14 08:00:00Z]

    assert {:ok, _appointment} =
             Booking.persist_appointment(
               %{
                 patient_profile_id: patient_profile_id,
                 professional_account_id: professional_id,
                 consultation_type_id: @consultation_type_id,
                 start_time: start_time,
                 status: status
               },
               %{
                 name: "Consulta General",
                 duration_minutes: 30,
                 exact_price_ars: Decimal.new("15000.50")
               }
             )
  end
end
