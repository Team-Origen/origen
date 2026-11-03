defmodule OrigenWeb.SecretaryBookingIntegrationTest do
  @moduledoc """
  Pruebas end-to-end de integración y verificación para #312 (padre #281):
  Agenda de paciente existente desde Secretaría.
  """

  use OrigenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Origen.Appointments.{AssistedBooking, DatabaseCalendar}
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship, RequestResolution}
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @path "/secretaria/pacientes"

  setup do
    previous_adapter = Application.get_env(:origen, :appointments_calendar_adapter)

    on_exit(fn ->
      Application.put_env(:origen, :appointments_calendar_adapter, previous_adapter)
    end)

    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)

    Repo.delete_all(ProfessionalPatientRelationship)
    Repo.delete_all(Appointment)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    secretary = insert_active_internal_account!(:secretary)
    admin = insert_active_internal_account!(:administrator)

    prof_auto =
      insert_bookable_professional!("Sofía", "Martínez", "Cardiología", "MN-10101",
        approval_mode: "automatic",
        secretary_approval_mode: "confirmed",
        consultation_name: "Consulta Cardiológica",
        price: 22_000,
        interval_minutes: 30,
        interval_count: 1
      )

    prof_manual_req =
      insert_bookable_professional!("Lucas", "Gómez", "Dermatología", "MN-20202",
        approval_mode: "manual",
        secretary_approval_mode: "requested",
        consultation_name: "Consulta Dermatológica",
        price: 18_500,
        interval_minutes: 30,
        interval_count: 1
      )

    prof_manual_conf =
      insert_bookable_professional!("Valeria", "Ruiz", "Clínica Médica", "MN-30303",
        approval_mode: "manual",
        secretary_approval_mode: "confirmed",
        consultation_name: "Consulta Clínica",
        price: 16_000,
        interval_minutes: 30,
        interval_count: 1
      )

    {:ok, %{persona: persona, profile: patient}} =
      Patients.complete_profile("paciente.existente@example.test", %{
        first_name: "Martín",
        last_name: "Herrera",
        document_type: "dni",
        document_number: "34.111.222",
        birthdate: ~D[1985-04-12],
        phone: "+5491166778899"
      })

    future_date = Date.add(next_weekday(Date.utc_today()), 7)

    %{
      secretary: secretary,
      admin: admin,
      prof_auto: prof_auto,
      prof_manual_req: prof_manual_req,
      prof_manual_conf: prof_manual_conf,
      persona: persona,
      patient: patient,
      future_date: future_date
    }
  end

  describe "recorrido real completo desde Secretaría (#281 / #312)" do
    test "opera agendas del centro, confirma en modo automático, ocupa el slot y refresca la grilla",
         ctx do
      {:ok, view, _html} = live(conn_for(ctx.secretary), @path)

      # 1. Localiza paciente existente por DNI
      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "34.111.222"}
      )
      |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert has_element?(view, "#patient-summary-full-name", "Martín Herrera")
      assert has_element?(view, "#patient-summary-document", "DNI 34111222")
      # Teléfono no verificado no impide reservar en la beta
      assert has_element?(view, "#patient-summary-phone-verified", "Teléfono no verificado")

      # 2. Inicia reserva asistida y visualiza las agendas del centro
      view
      |> element("#start-assisted-booking")
      |> render_click()

      assert has_element?(view, "#assisted-booking-section")

      for prof <- [ctx.prof_auto, ctx.prof_manual_req, ctx.prof_manual_conf] do
        assert has_element?(
                 view,
                 "#booking-professional-select option[value='#{prof.id}']",
                 prof.name
               )
      end

      # 3. Selecciona profesional con modo automático y fecha futura
      render_change(view, "update_booking_selection", %{
        "professional_id" => to_string(ctx.prof_auto.id),
        "consultation_type_id" => ctx.prof_auto.type_id,
        "date" => Date.to_iso8601(ctx.future_date)
      })

      assert has_element?(
               view,
               "#prof-approval-mode-badge",
               "Aprobación automática (confirmación directa)"
             )

      assert has_element?(view, ~s(button[phx-click="select_slot"][phx-value-time="09:00"]))

      # 4. Selecciona slot 09:00 y confirma
      view
      |> element(~s(button[phx-click="select_slot"][phx-value-time="09:00"]))
      |> render_click()

      view |> element("#confirm-assisted-booking") |> render_click()

      assert has_element?(view, "#booking-success-message")
      assert has_element?(view, "#booking-success-message", "Confirmed")
      assert has_element?(view, "#booking-success-message", "Consulta Cardiológica")

      # 5. Verifica persistencia real, snapshot, relación y exclusión inmediata del slot 09:00
      appt =
        Repo.get_by!(Appointment,
          patient_profile_id: ctx.patient.id,
          professional_account_id: ctx.prof_auto.id
        )

      assert appt.status == "confirmed"
      assert appt.snapshot_consultation_type_name == "Consulta Cardiológica"
      assert appt.snapshot_duration_minutes == 30
      assert Decimal.equal?(appt.snapshot_exact_price_ars, Decimal.new("22000"))

      rel =
        Repo.get_by!(ProfessionalPatientRelationship,
          professional_account_id: ctx.prof_auto.id,
          patient_profile_id: ctx.patient.id
        )

      assert rel.first_appointment_id == appt.id

      # El slot 09:00 ya no se ofrece en la grilla reactiva ni en una nueva consulta al calendario
      refute has_element?(view, ~s(button[phx-click="select_slot"][phx-value-time="09:00"]))
      assert has_element?(view, ~s(button[phx-click="select_slot"][phx-value-time="09:30"]))
    end

    test "respeta modalidad manual (requested vs confirmed según subconfiguración) y crea relación sin habilitar aprobación/rechazo a Secretaría",
         ctx do
      {:ok, view, _html} = live(conn_for(ctx.secretary), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "34111222"}
      )
      |> render_submit()

      view |> element("#start-assisted-booking") |> render_click()

      # Caso A: Profesional en modo manual con subconfiguración secretary_approval_mode = requested
      render_change(view, "update_booking_selection", %{
        "professional_id" => to_string(ctx.prof_manual_req.id),
        "consultation_type_id" => ctx.prof_manual_req.type_id,
        "date" => Date.to_iso8601(ctx.future_date)
      })

      assert has_element?(
               view,
               "#prof-approval-mode-badge",
               "Aprobación manual requerida (nacerá como Solicitud)"
             )

      view
      |> element(~s(button[phx-click="select_slot"][phx-value-time="10:00"]))
      |> render_click()

      view |> element("#confirm-assisted-booking") |> render_click()

      assert has_element?(view, "#booking-success-message", "Requested")

      req_appt =
        Repo.get_by!(Appointment,
          patient_profile_id: ctx.patient.id,
          professional_account_id: ctx.prof_manual_req.id
        )

      assert req_appt.status == "requested"

      # La solicitud ocupa el horario inmediatamente y crea la relación Profesional-Paciente
      refute has_element?(view, ~s(button[phx-click="select_slot"][phx-value-time="10:00"]))

      assert Repo.get_by(ProfessionalPatientRelationship,
               professional_account_id: ctx.prof_manual_req.id,
               patient_profile_id: ctx.patient.id
             ) != nil

      # Secretaría NO puede aceptar ni rechazar la solicitud creada (ni en UI ni en servidor)
      refute render(view) =~ "Aceptar solicitud"
      refute render(view) =~ "Rechazar solicitud"

      assert {:error, :unauthorized} =
               AssistedBooking.approve_request(ctx.secretary.id, req_appt.id)

      assert {:error, :unauthorized} =
               AssistedBooking.reject_request(ctx.secretary.id, req_appt.id)

      assert {:error, :unauthorized} =
               RequestResolution.accept_request(ctx.secretary.id, req_appt.id)

      assert {:error, :unauthorized} =
               RequestResolution.reject_request(ctx.secretary.id, req_appt.id)

      assert Repo.get!(Appointment, req_appt.id).status == "requested"

      # Caso B: Profesional en modo manual con subconfiguración secretary_approval_mode = confirmed
      render_change(view, "update_booking_selection", %{
        "professional_id" => to_string(ctx.prof_manual_conf.id),
        "consultation_type_id" => ctx.prof_manual_conf.type_id,
        "date" => Date.to_iso8601(ctx.future_date)
      })

      assert has_element?(
               view,
               "#prof-approval-mode-badge",
               "Aprobación automática (confirmación directa)"
             )

      view
      |> element(~s(button[phx-click="select_slot"][phx-value-time="11:00"]))
      |> render_click()

      view |> element("#confirm-assisted-booking") |> render_click()

      assert has_element?(view, "#booking-success-message", "Confirmed")

      conf_appt =
        Repo.get_by!(Appointment,
          patient_profile_id: ctx.patient.id,
          professional_account_id: ctx.prof_manual_conf.id
        )

      assert conf_appt.status == "confirmed"
    end

    test "detecta colisión cuando un slot se ocupa antes de confirmar, informa el error sin efectos parciales y refresca los horarios",
         ctx do
      {:ok, other_patient} =
        Patients.complete_profile("otro.paciente@example.test", %{
          first_name: "Lucía",
          last_name: "Paz",
          document_type: "dni",
          document_number: "39.888.777",
          birthdate: ~D[1992-11-03],
          phone: "+5491133221100"
        })

      {:ok, view, _html} = live(conn_for(ctx.secretary), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "34111222"}
      )
      |> render_submit()

      view |> element("#start-assisted-booking") |> render_click()

      render_change(view, "update_booking_selection", %{
        "professional_id" => to_string(ctx.prof_auto.id),
        "consultation_type_id" => ctx.prof_auto.type_id,
        "date" => Date.to_iso8601(ctx.future_date)
      })

      view
      |> element(~s(button[phx-click="select_slot"][phx-value-time="09:00"]))
      |> render_click()

      # Otra reserva ocupa las 09:00 antes de que Secretaría confirme
      occupied_start = DateTime.new!(ctx.future_date, ~T[09:00:00], "Etc/UTC")

      assert {:ok, _} =
               AssistedBooking.reserve(ctx.secretary.id, other_patient.profile.id, %{
                 professional_id: ctx.prof_auto.id,
                 consultation_type_id: ctx.prof_auto.type_id,
                 start_time: occupied_start
               })

      # Al confirmar el slot tomado, falla limpiamente y refresca la grilla
      view |> element("#confirm-assisted-booking") |> render_click()

      assert has_element?(
               view,
               "#booking-error-message",
               "El horario seleccionado ya no está disponible. Por favor seleccioná otro."
             )

      refute has_element?(view, "#booking-success-message")
      refute has_element?(view, ~s(button[phx-click="select_slot"][phx-value-time="09:00"]))

      # No se creó turno ni relación para el paciente de esta vista
      assert Repo.get_by(Appointment,
               patient_profile_id: ctx.patient.id,
               professional_account_id: ctx.prof_auto.id
             ) == nil

      assert Repo.get_by(ProfessionalPatientRelationship,
               professional_account_id: ctx.prof_auto.id,
               patient_profile_id: ctx.patient.id
             ) == nil
    end

    test "deniega el montaje y la reserva asistida a Administrador y Profesional (exclusivo de Secretaría)",
         ctx do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn_for(ctx.admin), @path)

      assert {:error, :unauthorized} =
               AssistedBooking.reserve(ctx.admin.id, ctx.patient.id, %{
                 professional_id: ctx.prof_auto.id,
                 consultation_type_id: ctx.prof_auto.type_id,
                 start_time: DateTime.new!(ctx.future_date, ~T[09:00:00], "Etc/UTC")
               })

      assert Repo.aggregate(Appointment, :count) == 0
    end

    test "valida duración multi-intervalo, anticipación mínima, horizonte, conflicto de paciente entre agendas y rechazos de seguridad en servidor",
         ctx do
      prof_extended =
        insert_bookable_professional!("Ana", "Silva", "Pediatría", "MN-50001",
          approval_mode: "manual",
          secretary_approval_mode: "requested",
          consultation_name: "Consulta Pediátrica Extendida",
          price: 25_000,
          interval_minutes: 30,
          interval_count: 2
        )

      Repo.query!(
        "UPDATE agenda_settings SET booking_horizon_days = 7, minimum_lead_minutes = 120 WHERE owner_account_id = $1",
        [prof_extended.id]
      )

      fixed_now = DateTime.new!(ctx.future_date, ~T[08:30:00], "Etc/UTC")

      # Violación de minimum_lead_minutes (09:00 está a 30 min de las 08:30, requiere 120 min)
      assert {:error, :slot_unavailable} =
               AssistedBooking.reserve(
                 ctx.secretary.id,
                 ctx.patient.id,
                 %{
                   professional_id: prof_extended.id,
                   consultation_type_id: prof_extended.type_id,
                   start_time: DateTime.new!(ctx.future_date, ~T[09:00:00], "Etc/UTC")
                 },
                 now: fixed_now
               )

      # Violación de booking_horizon_days (> 7 días desde fixed_now)
      beyond_horizon_date = Date.add(ctx.future_date, 10)

      assert {:error, :slot_unavailable} =
               AssistedBooking.reserve(
                 ctx.secretary.id,
                 ctx.patient.id,
                 %{
                   professional_id: prof_extended.id,
                   consultation_type_id: prof_extended.type_id,
                   start_time: DateTime.new!(beyond_horizon_date, ~T[11:00:00], "Etc/UTC")
                 },
                 now: fixed_now
               )

      # Reserva válida de 60 min (14:00 a 15:00)
      slot_1400 = DateTime.new!(ctx.future_date, ~T[14:00:00], "Etc/UTC")

      assert {:ok, ext_res} =
               AssistedBooking.reserve(
                 ctx.secretary.id,
                 ctx.patient.id,
                 %{
                   professional_id: prof_extended.id,
                   consultation_type_id: prof_extended.type_id,
                   start_time: slot_1400
                 },
                 now: fixed_now
               )

      assert ext_res.status == :requested
      assert ext_res.duration_minutes == 60

      assert DateTime.compare(
               ext_res.end_time,
               DateTime.new!(ctx.future_date, ~T[15:00:00], "Etc/UTC")
             ) == :eq

      # El bloque 14:00-15:00 impide iniciar un turno de 60 min a las 13:30, 14:00 o 14:30
      assert {:ok, schedule} =
               AssistedBooking.get_daily_schedule(prof_extended.id, ctx.future_date,
                 duration_minutes: 60,
                 now: fixed_now,
                 calendar_adapter: DatabaseCalendar
               )

      refute Enum.any?(schedule.slots, &(&1.start_formatted in ["13:30", "14:00", "14:30"]))

      # En LiveView: intentar reservar al mismo paciente con otro profesional a las 14:30 falla por conflicto de paciente
      {:ok, view, _html} = live(conn_for(ctx.secretary), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "34111222"}
      )
      |> render_submit()

      view |> element("#start-assisted-booking") |> render_click()

      render_change(view, "update_booking_selection", %{
        "professional_id" => to_string(ctx.prof_auto.id),
        "consultation_type_id" => ctx.prof_auto.type_id,
        "date" => Date.to_iso8601(ctx.future_date)
      })

      view
      |> element(~s(button[phx-click="select_slot"][phx-value-time="14:30"]))
      |> render_click()

      view |> element("#confirm-assisted-booking") |> render_click()

      assert has_element?(
               view,
               "#booking-error-message",
               "El paciente ya posee otro turno superpuesto con este horario."
             )

      # Horario forjado fuera de ventana ("22:00") es rechazado en servidor
      render_click(view, "select_slot", %{"time" => "22:00"})
      view |> element("#confirm-assisted-booking") |> render_click()

      assert has_element?(
               view,
               "#booking-error-message",
               "El horario seleccionado no se encuentra dentro de la disponibilidad del profesional."
             )

      # Si el profesional dueño rechaza la solicitud, el horario 14:00 vuelve a liberarse
      assert {:ok, _} = RequestResolution.reject_request(prof_extended.id, ext_res.appointment_id)

      assert {:ok, schedule_after} =
               AssistedBooking.get_daily_schedule(prof_extended.id, ctx.future_date,
                 duration_minutes: 60,
                 now: fixed_now,
                 calendar_adapter: DatabaseCalendar
               )

      assert Enum.any?(schedule_after.slots, &(&1.start_formatted == "14:00"))
    end
  end

  # Helpers

  defp conn_for(account) do
    build_conn()
    |> log_in_internal_account(account)
  end

  defp insert_active_internal_account!(role) do
    %{rows: [[account_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: account_id, role: role, state: :active}
  end

  defp insert_bookable_professional!(first_name, last_name, specialty, license_number, opts) do
    prof = insert_active_internal_account!(:professional)

    Repo.query!(
      """
      INSERT INTO professional_profiles
        (owner_account_id, first_name, last_name, specialty, license_type, license_number)
      VALUES ($1, $2, $3, $4, 'Nacional', $5)
      """,
      [prof.id, first_name, last_name, specialty, license_number]
    )

    week =
      Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
        {day, [%{"start" => "08:00", "end" => "18:00"}]}
      end)

    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, approval_mode, secretary_approval_mode, weekly_availability, booking_horizon_days, minimum_lead_minutes)
      VALUES ($1, $2, $3, $4, $5, 30, 0)
      """,
      [
        prof.id,
        Keyword.fetch!(opts, :interval_minutes),
        Keyword.fetch!(opts, :approval_mode),
        Keyword.fetch!(opts, :secretary_approval_mode),
        week
      ]
    )

    type_uuid = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, $4, '#0A3847', $5, 'active')
      """,
      [
        Ecto.UUID.dump!(type_uuid),
        prof.id,
        Keyword.fetch!(opts, :consultation_name),
        Keyword.fetch!(opts, :price),
        Keyword.fetch!(opts, :interval_count)
      ]
    )

    %{
      id: prof.id,
      name: "#{first_name} #{last_name}",
      specialty: specialty,
      type_id: type_uuid
    }
  end

  defp next_weekday(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, 2)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end
end
