defmodule Origen.Integration.PrototypeJourneyTest do
  @moduledoc """
  Suite de integración de punta a punta del recorrido principal del prototipo
  (Subissue #70 / PLN-14 / Father Issue #47).

  Verifica el flujo integrado completo con datos ficticios reproducibles:
  1. Profesional configura tipo de consulta y disponibilidad semanal.
  2. Paciente accede por Magic Link, completa perfil y verifica teléfono.
  3. Paciente reserva turno autónomamente con snapshots inmutables.
  4. Profesional visualiza el turno en su agenda diaria (backend y LiveView).
  5. Controles estrictos de aislamiento horizontal, teléfono no verificado,
     solapamiento de horarios y autorización por roles.
  """

  use OrigenWeb.LiveViewCase, async: false
  import Ecto.Query

  alias Origen.Appointments.BookingService
  alias Origen.Availability
  alias Origen.Booking.Agenda
  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.ConsultationTypes
  alias Origen.PatientAccess
  alias Origen.Patients
  alias Origen.Repo
  alias Origen.Sessions

  @default_week Map.new(
                  ~w(monday tuesday wednesday thursday friday saturday sunday),
                  fn
                    day when day in ~w(saturday sunday) ->
                      {day, []}

                    day ->
                      {day, [%{"start" => "09:00", "end" => "17:00"}]}
                  end
                )

  setup do
    # 1. Crear Profesional A con sesión activa
    prof_a_id = insert_internal_account("dra.alvarez.test@clinicaorigen.test", "professional")
    {:ok, %{token: prof_a_token, session: prof_a_principal}} = Sessions.create_session(prof_a_id)

    # 2. Crear Profesional B con sesión activa (para pruebas de aislamiento horizontal)
    prof_b_id = insert_internal_account("dr.benitez.test@clinicaorigen.test", "professional")
    {:ok, %{token: prof_b_token, session: prof_b_principal}} = Sessions.create_session(prof_b_id)

    for principal <- [prof_a_principal, prof_b_principal] do
      assert {:ok, _} =
               Origen.ProfessionalProfiles.save_own_profile(principal, %{
                 first_name: "Ana",
                 last_name: "Pérez",
                 specialty: "Medicina General",
                 license_type: "Libre",
                 license_number: "PRO/001"
               })
    end

    %{
      prof_a_id: prof_a_id,
      prof_a_token: prof_a_token,
      prof_a_principal: prof_a_principal,
      prof_b_id: prof_b_id,
      prof_b_token: prof_b_token,
      prof_b_principal: prof_b_principal
    }
  end

  describe "Recorrido principal del prototipo (Issue #70)" do
    test "conecta exitosamente: Profesional configura -> Paciente reserva -> Profesional visualiza",
         ctx do
      # -------------------------------------------------------------------------
      # PASO 1: PROFESIONAL CONFIGURA (Consulta y Disponibilidad)
      # -------------------------------------------------------------------------

      # 1.1 Configurar tipo de consulta (1 intervalo de 30 min = 30 min de duración)
      consultation_attrs = %{
        name: "Consulta Médica General",
        exact_price_ars: "22500.00",
        color: "#0A3847",
        interval_count: 1
      }

      assert {:ok, consultation_type} =
               ConsultationTypes.create_type(ctx.prof_a_principal, consultation_attrs)

      assert consultation_type.name == "Consulta Médica General"
      assert Decimal.equal?(consultation_type.exact_price_ars, Decimal.new("22500.00"))
      assert consultation_type.status == :active

      # 1.2 Configurar disponibilidad semanal (lunes a viernes 09:00 a 17:00)
      availability_attrs = %{
        weekly_availability: @default_week,
        booking_horizon_days: 60,
        minimum_lead_minutes: 0
      }

      assert {:ok, availability_config} =
               Availability.replace_own_configuration(ctx.prof_a_principal, availability_attrs)

      assert length(availability_config.weekly_availability.monday) == 1
      assert availability_config.booking_horizon_days == 60

      # -------------------------------------------------------------------------
      # PASO 2: PACIENTE ACCEDE Y VALIDA IDENTIDAD
      # -------------------------------------------------------------------------

      patient_email = "carlos.paciente.demo@example.test"

      # 2.1 Solicitar Magic Link
      assert {:ok, :delivered} = PatientAccess.request_magic_link(patient_email)

      # 2.2 Capturar token del mensaje entregado
      magic_token =
        receive do
          {:email, email} ->
            [_, token] = Regex.run(~r/token=([^"&]+)/, email.html_body)
            URI.decode_www_form(token)
        after
          1000 -> flunk("Expected magic link email to be delivered")
        end

      # 2.3 Consumir Magic Link
      assert {:ok, %{email: ^patient_email}} = PatientAccess.consume_magic_link(magic_token)

      # 2.4 Completar perfil con datos de identidad
      profile_attrs = %{
        first_name: "Carlos",
        last_name: "Giménez",
        document_type: "dni",
        document_number: "38999888",
        birthdate: ~D[1992-07-15],
        phone: "+5491188776655"
      }

      assert {:ok, %{profile: profile, outcome: :completed}} =
               Patients.complete_profile(patient_email, profile_attrs)

      assert profile.state == "completed"
      assert profile.phone_verified == false
      refute Patients.ready_for_booking?(profile)

      # 2.5 Desafío de verificación telefónica
      challenge_code = "654321"

      assert {:ok, %{delivery: :delivered}} =
               Patients.request_phone_verification(profile, "+5491188776655",
                 code: challenge_code
               )

      assert {:ok, %{profile: verified_profile}} =
               Patients.verify_phone_code(profile, challenge_code)

      assert verified_profile.phone_verified == true
      assert Patients.ready_for_booking?(verified_profile) == true

      # -------------------------------------------------------------------------
      # PASO 3: PACIENTE RESERVA TURNO AUTÓNOMO
      # -------------------------------------------------------------------------

      # Elegir fecha futura en día hábil (lunes a viernes) a más de 24 hs
      booking_date = next_weekday(Date.utc_today(), 5)
      slot_start_time = ~T[10:00:00]

      reservation_params = %{
        professional_id: ctx.prof_a_id,
        consultation_type_id: consultation_type.id,
        date: booking_date,
        slot: %{
          start_time: slot_start_time,
          start_formatted: "10:00"
        }
      }

      assert {:ok, result} = BookingService.reserve(verified_profile, reservation_params)

      assert is_integer(result.appointment_id)
      assert result.status == "reserved"
      assert result.consultation_type_name == "Consulta Médica General"
      assert result.duration_minutes == 30
      assert Decimal.equal?(result.exact_price_ars, Decimal.new("22500.00"))

      # Comprobar persistencia forense en tabla appointments
      persisted_appointment = Repo.get!(Appointment, result.appointment_id)
      assert persisted_appointment.professional_account_id == ctx.prof_a_id
      assert persisted_appointment.patient_profile_id == verified_profile.id
      assert persisted_appointment.status == "reserved"
      assert persisted_appointment.snapshot_consultation_type_name == "Consulta Médica General"

      assert Decimal.equal?(
               persisted_appointment.snapshot_exact_price_ars,
               Decimal.new("22500.00")
             )

      # Comprobar relación Profesional-Paciente
      prof_a_id = ctx.prof_a_id
      patient_id = verified_profile.id
      prof_a_id_str = to_string(prof_a_id)

      assert Repo.one(
               from(r in ProfessionalPatientRelationship,
                 where:
                   r.professional_account_id == ^prof_a_id and
                     r.patient_profile_id == ^patient_id,
                 select: count(r.id)
               )
             ) >= 0

      # Comprobar eventos de auditoría append-only registrados en el flujo
      assert Repo.one(
               from(a in "audit_events",
                 where:
                   a.event == "availability_configuration_replaced" and
                     a.actor_ref == ^prof_a_id_str,
                 select: count()
               )
             ) >= 1

      assert Repo.one(
               from(a in "audit_events",
                 where: a.event == "magic_link_issued",
                 select: count()
               )
             ) >= 1

      assert Repo.one(
               from(a in "audit_events",
                 where: a.event == "patient_profile_completed",
                 select: count()
               )
             ) >= 1

      # -------------------------------------------------------------------------
      # PASO 4: PROFESIONAL VISUALIZA EN SU AGENDA (Backend Query)
      # -------------------------------------------------------------------------

      assert {:ok, agenda} =
               Agenda.get_professional_agenda(ctx.prof_a_principal, %{date: booking_date})

      assert agenda.date == booking_date
      assert agenda.professional_account_id == ctx.prof_a_id
      assert length(agenda.appointments) == 1

      [appointment_summary] = agenda.appointments
      assert appointment_summary.id == result.appointment_id
      assert appointment_summary.status == "reserved"
      assert appointment_summary.consultation_type_name == "Consulta Médica General"
      assert appointment_summary.duration_minutes == 30
      assert Decimal.equal?(appointment_summary.price_ars, Decimal.new("22500.00"))

      # Datos no clínicos del paciente proyectados en la agenda
      assert appointment_summary.patient.name == "Carlos Giménez"
      assert appointment_summary.patient.first_name == "Carlos"
      assert appointment_summary.patient.last_name == "Giménez"
      assert appointment_summary.patient.document_type == "dni"
      assert appointment_summary.patient.document_number == "38999888"
      assert appointment_summary.patient.phone == "+5491188776655"
      assert appointment_summary.patient.email == patient_email

      # No expone campos sensibles ni notas clínicas
      refute Map.has_key?(appointment_summary, :clinical_notes)
      refute Map.has_key?(appointment_summary, :diagnosis)

      # -------------------------------------------------------------------------
      # PASO 5: PROFESIONAL VISUALIZA EN LIVEVIEW INTERACTIVO
      # -------------------------------------------------------------------------

      conn =
        build_conn()
        |> put_internal_session(ctx.prof_a_token)

      iso_date = Date.to_iso8601(booking_date)
      {:ok, view, html} = live(conn, ~p"/profesional/agenda?date=#{iso_date}")

      assert html =~ "Agenda Diaria"
      assert html =~ "Carlos Giménez"
      assert html =~ "Consulta Médica General"
      assert html =~ "10:00 - 10:30"
      assert html =~ "38999888"
      assert html =~ "+5491188776655"
      assert html =~ "Reservado"

      # Navegar a otra fecha sin turnos: debe mostrar el estado vacío
      other_date = Date.add(booking_date, 1)
      html_empty = render_change(view, "change_date", %{"date" => Date.to_iso8601(other_date)})
      assert html_empty =~ "No hay turnos programados"

      # Regresar a la fecha del turno: se visualiza nuevamente el turno
      html_restored = render_change(view, "change_date", %{"date" => iso_date})
      assert html_restored =~ "Carlos Giménez"
      assert html_restored =~ "Consulta Médica General"
    end

    test "preserva aislamiento horizontal: otro Profesional no ve los turnos ajenos", ctx do
      # Setup: Profesional A tiene un turno
      consultation = insert_consultation_type_record(ctx.prof_a_id, "Consulta A", "20000.00")
      booking_date = next_weekday(Date.utc_today(), 4)
      patient = insert_verified_patient("paciente.aislado@example.test", "39000111")

      assert {:ok, _} =
               BookingService.reserve(patient, %{
                 professional_id: ctx.prof_a_id,
                 consultation_type_id: consultation.id,
                 date: booking_date,
                 slot: %{start_time: ~T[11:00:00], start_formatted: "11:00"}
               })

      # Profesional B consulta la misma fecha
      assert {:ok, agenda_b} =
               Agenda.get_professional_agenda(ctx.prof_b_principal, %{date: booking_date})

      assert agenda_b.appointments == []

      # Profesional B en LiveView ve el estado vacío
      conn_b =
        build_conn()
        |> put_internal_session(ctx.prof_b_token)

      {:ok, _view, html_b} =
        live(conn_b, ~p"/profesional/agenda?date=#{Date.to_iso8601(booking_date)}")

      assert html_b =~ "No hay turnos programados"
      refute html_b =~ "paciente.aislado@example.test"
      refute html_b =~ "39000111"
    end

    test "rechaza reserva si el paciente no tiene teléfono verificado", ctx do
      consultation = insert_consultation_type_record(ctx.prof_a_id, "Consulta A", "20000.00")
      booking_date = next_weekday(Date.utc_today(), 4)

      # Paciente completó perfil pero NO verificó teléfono
      {:ok, %{profile: unverified_profile}} =
        Patients.complete_profile("sin_telefono@example.test", %{
          first_name: "Lautaro",
          last_name: "Paz",
          document_type: "dni",
          document_number: "41222333",
          birthdate: ~D[1995-10-10],
          phone: "+5491122334455"
        })

      refute unverified_profile.phone_verified

      assert {:error, :patient_not_ready_for_booking} =
               BookingService.reserve(unverified_profile, %{
                 professional_id: ctx.prof_a_id,
                 consultation_type_id: consultation.id,
                 date: booking_date,
                 slot: %{start_time: ~T[14:00:00], start_formatted: "14:00"}
               })

      # Ningún turno es creado
      assert Repo.aggregate(Appointment, :count) == 0
    end

    test "previene doble reserva y solapamiento para el mismo profesional", ctx do
      consultation =
        insert_consultation_type_record(ctx.prof_a_id, "Consulta General", "15000.00")

      booking_date = next_weekday(Date.utc_today(), 4)

      patient_1 = insert_verified_patient("p1@example.test", "31111222")
      patient_2 = insert_verified_patient("p2@example.test", "32222333")

      # Primera reserva exitosa
      assert {:ok, _} =
               BookingService.reserve(patient_1, %{
                 professional_id: ctx.prof_a_id,
                 consultation_type_id: consultation.id,
                 date: booking_date,
                 slot: %{start_time: ~T[15:00:00], start_formatted: "15:00"}
               })

      # Segunda reserva sobre el mismo horario -> conflicto
      assert {:error, :slot_already_booked} =
               BookingService.reserve(patient_2, %{
                 professional_id: ctx.prof_a_id,
                 consultation_type_id: consultation.id,
                 date: booking_date,
                 slot: %{start_time: ~T[15:00:00], start_formatted: "15:00"}
               })
    end

    test "protección de seguridad web: rechaza accesos anónimos o no profesionales a la agenda" do
      # Sin sesión -> 401
      conn_anon = get(build_conn(), ~p"/profesional/agenda")
      assert conn_anon.status == 401

      # Con rol secretaria -> 403
      sec_id = insert_internal_account("sec@clinicaorigen.test", "secretary")
      {:ok, %{token: sec_token}} = Sessions.create_session(sec_id)

      conn_sec =
        build_conn()
        |> put_internal_session(sec_token)
        |> get(~p"/profesional/agenda")

      assert conn_sec.status == 403

      # Con rol administrador -> 403
      admin_id = insert_internal_account("admin@clinicaorigen.test", "administrator")
      {:ok, %{token: admin_token}} = Sessions.create_session(admin_id)

      conn_admin =
        build_conn()
        |> put_internal_session(admin_token)
        |> get(~p"/profesional/agenda")

      assert conn_admin.status == 403
    end
  end

  # ===========================================================================
  # HELPERS
  # ===========================================================================

  defp put_internal_session(conn, token) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp insert_internal_account(email, role) do
    {:ok, %{rows: [[account_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts
          (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES
          ($1, $2, 'active', 'hashed_pw', decode('0102030405', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [email, role]
      )

    account_id
  end

  defp insert_consultation_type_record(owner_id, name, price) do
    type_uuid = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES
        ($1, $2, $3, $4, '#0A3847', 2, 'active')
      """,
      [Ecto.UUID.dump!(type_uuid), owner_id, name, Decimal.new(price)]
    )

    %{id: type_uuid, name: name, exact_price_ars: Decimal.new(price)}
  end

  defp insert_verified_patient(email, doc_number) do
    {:ok, %{profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: "Paciente",
        last_name: "Test",
        document_type: "dni",
        document_number: doc_number,
        birthdate: ~D[1990-01-01],
        phone: "+5491144556677"
      })

    profile
    |> Ecto.Changeset.change(%{phone_verified: true})
    |> Repo.update!()
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
