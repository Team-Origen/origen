defmodule Origen.Integration.JourneyFailureRegressionTest do
  @moduledoc """
  Suite de regresión de fallos y reversión transaccional del recorrido integrado
  (Subissue #71 / PLN-14 / Father Issue #47).

  Verifica:
  1. Perfiles incompletos: rechazo de usuarios anónimos, perfiles pendientes de completar,
     teléfonos no verificados y colisiones documentales derivadas a secretaría.
  2. Reversión transaccional total: ante fallos forzados o solapamientos, rollback completo
     garantizando 0 turnos huérfanos, 0 relaciones espurias y 0 auditoría inconsistente.
  3. Confidencialidad y no exposición de datos ajenos: errores opacos, no enumerantes,
     inmunidad ante inyección de parámetros cliente y aislamiento estricto entre profesionales.
  """

  use OrigenWeb.LiveViewCase, async: false
  import Ecto.Query

  alias Origen.Appointments.BookingService
  alias Origen.Booking
  alias Origen.Booking.Agenda
  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Booking.ReservationRequest
  alias Origen.Patients
  alias Origen.Repo
  alias Origen.Sessions

  @consultation_type_uuid "e5b8c9d0-1234-4567-89ab-cdef01234567"

  setup do
    prof_id = insert_internal_account("dr.regresion@clinicaorigen.test", "professional")
    {:ok, %{token: prof_token, session: prof_principal}} = Sessions.create_session(prof_id)

    assert {:ok, _} =
             Origen.ProfessionalProfiles.save_own_profile(prof_principal, %{
               first_name: "Ana",
               last_name: "Pérez",
               specialty: "Medicina General",
               license_type: "Libre",
               license_number: "PRO/001"
             })

    insert_agenda_settings(prof_id, 30)
    insert_consultation_type(prof_id, @consultation_type_uuid, "Consulta Integral", "20000.00")

    %{
      prof_id: prof_id,
      prof_token: prof_token,
      prof_principal: prof_principal
    }
  end

  # ===========================================================================
  # 1. PERFILES INCOMPLETOS, TELÉFONO NO VERIFICADO Y COLISIONES
  # ===========================================================================
  describe "perfiles incompletos y barreras de identidad (Issue #71)" do
    test "rechaza intento de reserva anónimo con :unauthenticated", ctx do
      future_date = next_weekday(Date.utc_today(), 5)

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[09:00:00], start_formatted: "09:00"}
      }

      assert {:error, :unauthenticated} = BookingService.reserve(nil, params)
      assert Repo.aggregate(Appointment, :count) == 0
    end

    test "rechaza reserva si el paciente está en pending_completion", ctx do
      email = "incompleto_raw@example.test"
      {:ok, profile} = Patients.get_or_create_profile(email)
      assert profile.state == "pending_completion"
      refute Patients.ready_for_booking?(profile)

      future_date = next_weekday(Date.utc_today(), 5)

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[09:00:00], start_formatted: "09:00"}
      }

      assert {:error, :patient_not_ready_for_booking} = BookingService.reserve(profile, params)
      assert Repo.aggregate(Appointment, :count) == 0
    end

    test "rechaza reserva si el paciente tiene perfil completed pero teléfono sin verificar",
         ctx do
      {:ok, %{profile: profile}} =
        Patients.complete_profile("sin_verificar_tel@example.test", %{
          first_name: "Esteban",
          last_name: "Quito",
          document_type: "dni",
          document_number: "48111222",
          birthdate: ~D[1998-05-10],
          phone: "+5491177889900"
        })

      assert profile.state == "completed"
      assert profile.phone_verified == false
      refute Patients.ready_for_booking?(profile)

      future_date = next_weekday(Date.utc_today(), 5)

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[09:00:00], start_formatted: "09:00"}
      }

      assert {:error, :patient_not_ready_for_booking} = BookingService.reserve(profile, params)
      assert Repo.aggregate(Appointment, :count) == 0
    end

    test "colisión documental: segundo paciente con mismo DNI es derivado a secretaría y no puede reservar",
         ctx do
      dni = "37888999"

      # Primer paciente registra exitosamente su identidad
      {:ok, %{outcome: :completed}} =
        Patients.complete_profile("paciente_legitimo@example.test", %{
          first_name: "Legitimo",
          last_name: "Original",
          document_type: "dni",
          document_number: dni,
          birthdate: ~D[1991-01-01],
          phone: "+5491133334444"
        })

      # Segundo paciente intenta registrarse con el mismo DNI -> colisión
      {:ok, %{outcome: :derived_to_secretary, profile: collided_profile}} =
        Patients.complete_profile("paciente_usurpador@example.test", %{
          first_name: "Intento",
          last_name: "Colision",
          document_type: "dni",
          document_number: dni,
          birthdate: ~D[1995-02-02],
          phone: "+5491155556666"
        })

      assert collided_profile.state == "pending_secretary_review"
      assert is_nil(collided_profile.persona_id)
      refute Patients.ready_for_booking?(collided_profile)

      # Intento de reserva es rechazado de inmediato
      future_date = next_weekday(Date.utc_today(), 5)

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[09:00:00], start_formatted: "09:00"}
      }

      assert {:error, :patient_not_ready_for_booking} =
               BookingService.reserve(collided_profile, params)

      assert Repo.aggregate(Appointment, :count) == 0
    end
  end

  # ===========================================================================
  # 2. REVERSIÓN TRANSACCIONAL Y AUSENCIA DE ORFANDAD
  # ===========================================================================
  describe "reversión transaccional total y ausencia de orfandad (Issue #71)" do
    test "solapamiento de horario revierte transacción y no deja turnos huérfanos", ctx do
      patient_1 = insert_verified_patient("p1_overlap@example.test", "43000111")
      patient_2 = insert_verified_patient("p2_overlap@example.test", "43000222")

      future_date = next_weekday(Date.utc_today(), 5)

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[10:00:00], start_formatted: "10:00"}
      }

      # Primera reserva exitosa
      assert {:ok, _} = BookingService.reserve(patient_1, params)
      assert Repo.aggregate(Appointment, :count) == 1

      # Segunda reserva sobre el mismo horario: rechazada
      assert {:error, :slot_already_booked} = BookingService.reserve(patient_2, params)

      # La base de datos no contiene turnos adicionales ni registros inconsistentes
      assert Repo.aggregate(Appointment, :count) == 1
    end

    test "fallo al insertar relación profesional-paciente revierte atómicamente el turno", ctx do
      patient = insert_verified_patient("fallo_relacion@example.test", "41000111")
      future_date = next_weekday(Date.utc_today(), 5)
      slot_start = DateTime.new!(future_date, ~T[14:00:00], "Etc/UTC")

      request = %ReservationRequest{
        actor: %{role: :patient, id: patient.id},
        patient_id: patient.id,
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        start_time: slot_start
      }

      initial_appts = Repo.aggregate(Appointment, :count)
      initial_rels = Repo.aggregate(ProfessionalPatientRelationship, :count)

      assert {:error, :relationship_insertion_failed} =
               Booking.reserve_appointment(request, fail_at: :relationship)

      # Comprobación de rollback: ni turnos ni relaciones creadas
      assert Repo.aggregate(Appointment, :count) == initial_appts
      assert Repo.aggregate(ProfessionalPatientRelationship, :count) == initial_rels
    end

    test "fallo al insertar auditoría revierte turno y relación", ctx do
      patient = insert_verified_patient("fallo_audit@example.test", "41000222")
      future_date = next_weekday(Date.utc_today(), 5)
      slot_start = DateTime.new!(future_date, ~T[15:00:00], "Etc/UTC")

      request = %ReservationRequest{
        actor: %{role: :patient, id: patient.id},
        patient_id: patient.id,
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        start_time: slot_start
      }

      initial_appts = Repo.aggregate(Appointment, :count)
      initial_rels = Repo.aggregate(ProfessionalPatientRelationship, :count)

      assert {:error, :fallo_auditoria} =
               Booking.reserve_appointment(request, fail_at: :audit_event)

      assert Repo.aggregate(Appointment, :count) == initial_appts
      assert Repo.aggregate(ProfessionalPatientRelationship, :count) == initial_rels
    end

    test "integridad forense: ningún turno huérfano ni relación sin entidades válidas tras fallos",
         ctx do
      # Provocar varios intentos fallidos deliberadamente
      patient_unverified =
        insert_patient_unverified("huerfano_test@example.test", "41000333")

      future_date = next_weekday(Date.utc_today(), 5)

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[16:00:00], start_formatted: "16:00"}
      }

      _ = BookingService.reserve(patient_unverified, params)
      _ = BookingService.reserve(nil, params)

      # Comprobar que en appointments no existen registros huérfanos sin paciente o profesional
      orphan_appointments =
        Repo.all(
          from(a in Appointment,
            where: is_nil(a.patient_profile_id) or is_nil(a.professional_account_id)
          )
        )

      assert orphan_appointments == []

      # Comprobar que en professional_patient_relationships no existen registros huérfanos
      orphan_relationships =
        Repo.all(
          from(r in ProfessionalPatientRelationship,
            where: is_nil(r.patient_profile_id) or is_nil(r.professional_account_id)
          )
        )

      assert orphan_relationships == []
    end
  end

  # ===========================================================================
  # 3. CONFIDENCIALIDAD Y NO EXPOSICIÓN DE DATOS AJENOS
  # ===========================================================================
  describe "confidencialidad médica y no exposición de datos ajenos (Issue #71)" do
    test "mensaje de error ante solapamiento es opaco y no filtra datos del paciente que reservó",
         ctx do
      future_date = next_weekday(Date.utc_today(), 5)

      patient_1 = insert_verified_patient("victor.privado@example.test", "44111222")
      patient_2 = insert_verified_patient("tercero.curioso@example.test", "44333444")

      params = %{
        professional_id: ctx.prof_id,
        consultation_type_id: @consultation_type_uuid,
        date: future_date,
        slot: %{start_time: ~T[12:00:00], start_formatted: "12:00"}
      }

      # Primera reserva exitosa
      assert {:ok, _} = BookingService.reserve(patient_1, params)

      # Segunda reserva sobre el mismo slot
      result = BookingService.reserve(patient_2, params)

      # El error debe ser exactamente :slot_already_booked
      assert result == {:error, :slot_already_booked}

      # Comprobar que no hay exposición de datos del primer paciente
      error_dump = inspect(result)
      refute error_dump =~ "victor.privado@example.test"
      refute error_dump =~ "44111222"
      refute error_dump =~ to_string(patient_1.id)
    end

    test "inmunidad ante manipulación de identificadores (IDOR) en consulta de agenda", ctx do
      # Crear Profesional B con su propio tipo de consulta
      prof_b_id = insert_internal_account("dr.segundo@clinicaorigen.test", "professional")
      {:ok, %{session: prof_b_principal}} = Sessions.create_session(prof_b_id)

      assert {:ok, _} =
               Origen.ProfessionalProfiles.save_own_profile(prof_b_principal, %{
                 first_name: "Bruno",
                 last_name: "Pérez",
                 specialty: "Medicina General",
                 license_type: "Libre",
                 license_number: "PRO/002"
               })

      insert_agenda_settings(prof_b_id, 30)

      type_b_uuid = Ecto.UUID.generate()
      insert_consultation_type(prof_b_id, type_b_uuid, "Consulta B", "18000.00")

      future_date = next_weekday(Date.utc_today(), 5)
      patient = insert_verified_patient("paciente_idor@example.test", "44999888")

      {:ok, _} =
        BookingService.reserve(patient, %{
          professional_id: prof_b_id,
          consultation_type_id: type_b_uuid,
          date: future_date,
          slot: %{start_time: ~T[10:00:00], start_formatted: "10:00"}
        })

      # Profesional A intenta enviar parámetros intentando consultar la agenda del Profesional B
      malicious_params = %{
        date: future_date,
        professional_id: prof_b_id,
        account_id: prof_b_id,
        owner_account_id: prof_b_id
      }

      assert {:ok, agenda_a} =
               Agenda.get_professional_agenda(ctx.prof_principal, malicious_params)

      # La agenda retornada corresponde exclusivamente a Profesional A (vacía)
      assert agenda_a.professional_account_id == ctx.prof_id
      assert agenda_a.appointments == []

      # Profesional B con su propia sesión sí ve su turno
      assert {:ok, agenda_b} =
               Agenda.get_professional_agenda(prof_b_principal, %{date: future_date})

      assert agenda_b.professional_account_id == prof_b_id
      assert length(agenda_b.appointments) == 1
    end

    test "sesión profesional revocada es denegada inmediatamente sin exponer agenda", ctx do
      future_date = next_weekday(Date.utc_today(), 5)

      # Revocar todas las sesiones del profesional
      :ok = Sessions.terminate_all_sessions(ctx.prof_id)

      assert {:error, :unauthorized} =
               Agenda.get_professional_agenda(ctx.prof_principal, %{date: future_date})
    end
  end

  # ===========================================================================
  # HELPERS
  # ===========================================================================

  defp insert_internal_account(email, role) do
    {:ok, %{rows: [[account_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts
          (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES
          ($1, $2, 'active', 'hashed_pass', decode('0102030405', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [email, role]
      )

    account_id
  end

  defp insert_agenda_settings(owner_id, interval) do
    Repo.query!(
      """
      INSERT INTO public.agenda_settings (owner_account_id, interval_minutes, created_at, updated_at)
      VALUES ($1, $2, clock_timestamp(), clock_timestamp())
      ON CONFLICT (owner_account_id) DO NOTHING
      """,
      [owner_id, interval]
    )
  end

  defp insert_consultation_type(owner_id, type_uuid, name, price) do
    Repo.query!(
      """
      INSERT INTO public.consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES
        ($1, $2, $3, $4, '#0A3847', 1, 'active')
      ON CONFLICT (id) DO NOTHING
      """,
      [Ecto.UUID.dump!(type_uuid), owner_id, name, Decimal.new(price)]
    )
  end

  defp insert_verified_patient(email, doc_number) do
    {:ok, %{profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: "Paciente",
        last_name: "Verificado",
        document_type: "dni",
        document_number: doc_number,
        birthdate: ~D[1994-01-01],
        phone: "+5491144556677"
      })

    profile
    |> Ecto.Changeset.change(%{phone_verified: true})
    |> Repo.update!()
  end

  defp insert_patient_unverified(email, doc_number) do
    {:ok, %{profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: "Paciente",
        last_name: "SinVerificar",
        document_type: "dni",
        document_number: doc_number,
        birthdate: ~D[1994-01-01],
        phone: "+5491144556677"
      })

    profile
  end

  defp next_weekday(base_date, days_ahead) do
    target = Date.add(base_date, days_ahead)

    case Date.day_of_week(target) do
      6 -> Date.add(target, 2)
      7 -> Date.add(target, 1)
      _ -> target
    end
  end
end

defmodule Origen.Integration.JourneyConcurrencyRegressionTest do
  @moduledoc """
  Prueba de carrera concurrente real por el mismo slot en conexiones independientes de PostgreSQL.
  """
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo

  @slot_start ~U[2026-11-20 09:00:00Z]
  @slot_end ~U[2026-11-20 09:30:00Z]

  test "múltiples pacientes concurrentes disputan el mismo slot: exactamente 1 gana y las demás revierten" do
    :ok = Sandbox.checkout(Repo, sandbox: false)
    fixture = insert_race_fixture!(3)
    Sandbox.checkin(Repo)

    on_exit(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        cleanup_race_fixture!(fixture)
      after
        Sandbox.checkin(Repo)
      end
    end)

    parent = self()

    tasks =
      for index <- 1..3 do
        patient_id = Enum.at(fixture.patient_ids, index - 1)

        Task.async(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          send(parent, {:ready, index})

          receive do
            :go -> :ok
          after
            10_000 -> exit(:timeout)
          end

          try do
            Booking.persist_appointment(
              %{
                patient_profile_id: patient_id,
                professional_account_id: fixture.professional_id,
                consultation_type_id: fixture.consultation_type_id,
                start_time: @slot_start,
                status: "reserved"
              },
              %{
                name: "Consulta Carrera",
                duration_minutes: 30,
                exact_price_ars: Decimal.new("15000.00")
              }
            )
          after
            Sandbox.checkin(Repo)
          end
        end)
      end

    Enum.each(1..3, fn index ->
      assert_receive {:ready, ^index}, 10_000
    end)

    Enum.each(tasks, fn task -> send(task.pid, :go) end)
    results = Task.await_many(tasks, 15_000)

    {winners, losers} = Enum.split_with(results, &match?({:ok, _}, &1))

    assert length(winners) == 1
    assert [{:ok, %Appointment{} = winner}] = winners
    assert DateTime.compare(winner.start_time, @slot_start) == :eq
    assert DateTime.compare(winner.end_time, @slot_end) == :eq

    assert length(losers) == 2
    assert Enum.all?(losers, &(&1 == {:error, :slot_already_booked}))

    # Comprobación de persistencia con conexión directa
    :ok = Sandbox.checkout(Repo, sandbox: false)

    try do
      [[count_slot]] =
        Repo.query!(
          """
          SELECT count(*) FROM public.appointments
          WHERE professional_account_id = $1
            AND start_time = $2 AND end_time = $3
            AND status NOT IN ('cancelled', 'rejected')
          """,
          [fixture.professional_id, @slot_start, @slot_end]
        ).rows

      assert count_slot == 1
    after
      Sandbox.checkin(Repo)
    end
  end

  defp insert_race_fixture!(racer_count) do
    suffix = System.unique_integer([:positive])

    {:ok, %{rows: [[professional_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts
          (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES
          ($1, 'professional', 'active', 'hash', decode('010203', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        ["dr.carrera_#{suffix}@example.test"]
      )

    consultation_type_id = Ecto.UUID.generate()

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.consultation_types
          (id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at)
        VALUES
          ($1, $2, 'Consulta Carrera', 15000.00, '#0A3847', 1, 'active', clock_timestamp(), clock_timestamp())
        """,
        [Ecto.UUID.dump!(consultation_type_id), professional_id]
      )

    patient_ids =
      Enum.map(1..racer_count, fn index ->
        doc_num = "49#{suffix}#{index}" |> String.slice(0, 8)

        {:ok, %{rows: [[persona_id]]}} =
          Ecto.Adapters.SQL.query(
            Repo,
            """
            INSERT INTO public.personas
              (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
            VALUES
              ('Corredor', $1, 'dni', $2, '1992-01-01', clock_timestamp(), clock_timestamp())
            RETURNING id
            """,
            ["#{index}", doc_num]
          )

        {:ok, %{rows: [[profile_id]]}} =
          Ecto.Adapters.SQL.query(
            Repo,
            """
            INSERT INTO public.patient_profiles
              (persona_id, email, state, phone, phone_verified, created_at, updated_at)
            VALUES
              ($1, $2, 'completed', '+5491100000000', true, clock_timestamp(), clock_timestamp())
            RETURNING id
            """,
            [persona_id, "corredor_#{suffix}_#{index}@example.test"]
          )

        profile_id
      end)

    %{
      professional_id: professional_id,
      consultation_type_id: consultation_type_id,
      patient_ids: patient_ids
    }
  end

  defp cleanup_race_fixture!(fixture) do
    Repo.query!("DELETE FROM public.appointments WHERE professional_account_id = $1", [
      fixture.professional_id
    ])

    Repo.query!("DELETE FROM public.consultation_types WHERE owner_account_id = $1", [
      fixture.professional_id
    ])

    Repo.query!("DELETE FROM public.internal_accounts WHERE id = $1", [fixture.professional_id])

    Repo.query!("DELETE FROM public.patient_profiles WHERE id = ANY($1)", [fixture.patient_ids])
  end
end
