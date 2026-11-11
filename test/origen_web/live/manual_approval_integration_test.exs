defmodule OrigenWeb.ManualApprovalIntegrationTest do
  @moduledoc """
  Pruebas end-to-end de integración y verificación para #324 (padre #284):
  Resolución de solicitudes con aprobación manual integrando los tres canales
  reales (Paciente autónomo #280, Secretaría asistida #281, Profesional propio
  con paciente existente #282 e inexistente #283) sin dobles de calendario ni
  catálogo.
  """

  use OrigenWeb.LiveViewCase, async: false

  alias Ecto.Adapters.SQL

  alias Origen.{
    Availability,
    Booking,
    ConsultationTypes,
    PatientAccess,
    Patients,
    Repo,
    Sessions
  }

  alias Origen.Appointments.{AssistedBooking, BookingService, Calendar, DatabaseCalendar}
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship, RequestResolution}
  alias Origen.ConsultationTypes.DatabaseCatalog
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Sessions.InternalSession

  setup do
    previous_calendar = Application.get_env(:origen, :appointments_calendar_adapter)
    previous_catalog = Application.get_env(:origen, :consultation_type_catalog_adapter)
    previous_selector = Application.get_env(:origen, :professional_patient_selector)

    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)
    Application.put_env(:origen, :consultation_type_catalog_adapter, DatabaseCatalog)
    Application.delete_env(:origen, :professional_patient_selector)

    on_exit(fn ->
      Application.put_env(:origen, :appointments_calendar_adapter, previous_calendar)
      Application.put_env(:origen, :consultation_type_catalog_adapter, previous_catalog)

      if is_nil(previous_selector) do
        Application.delete_env(:origen, :professional_patient_selector)
      else
        Application.put_env(:origen, :professional_patient_selector, previous_selector)
      end
    end)

    Repo.delete_all(ProfessionalPatientRelationship)
    Repo.delete_all(Appointment)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    suffix = System.unique_integer([:positive])

    prof_owner =
      setup_bookable_professional!(suffix, "Sofía", "Martínez", "Cardiología",
        approval_mode: "manual",
        secretary_approval_mode: "confirmed",
        consultation_name: "Consulta Cardiológica",
        price: "20000.00"
      )

    prof_other =
      setup_bookable_professional!(suffix + 1000, "Lucas", "Gómez", "Dermatología",
        approval_mode: "automatic",
        secretary_approval_mode: "confirmed",
        consultation_name: "Consulta Dermatológica",
        price: "18000.00"
      )

    secretary = insert_staff_account!("secretary-#{suffix}@example.test", "secretary")
    admin = insert_staff_account!("admin-#{suffix}@example.test", "administrator")

    patient_1 =
      complete_patient!(
        "paciente1-#{suffix}@example.test",
        "41#{rem(suffix, 100_000) |> Integer.to_string() |> String.pad_leading(6, "0")}",
        "Ana",
        "Pérez"
      )

    patient_2 =
      complete_patient!(
        "paciente2-#{suffix}@example.test",
        "42#{rem(suffix, 100_000) |> Integer.to_string() |> String.pad_leading(6, "0")}",
        "Bruno",
        "Díaz"
      )

    patient_3 =
      complete_patient!(
        "paciente3-#{suffix}@example.test",
        "43#{rem(suffix, 100_000) |> Integer.to_string() |> String.pad_leading(6, "0")}",
        "Carla",
        "Herrera"
      )

    future_date = Date.add(next_weekday(Date.utc_today()), 7)

    %{
      suffix: suffix,
      prof_owner: prof_owner,
      prof_other: prof_other,
      secretary: secretary,
      admin: admin,
      patient_1: patient_1,
      patient_2: patient_2,
      patient_3: patient_3,
      future_date: future_date
    }
  end

  describe "navbar y matriz normativa en los 3 canales reales (#284 / #324)" do
    test "verifica navbar y matriz completa con Paciente, Secretaría y Profesional",
         ctx do
      date = ctx.future_date
      date_iso = Date.to_iso8601(date)

      # 0. Verificar acceso desde la navbar de Profesional, Secretaría y Paciente
      {:ok, prof_agenda_view, _} =
        live(internal_conn(ctx.conn, ctx.prof_owner.token), ~p"/profesional/agenda")

      assert has_element?(
               prof_agenda_view,
               "#role-navigation #nav-agenda[href='/profesional/agenda'][aria-current='page']",
               "Agenda"
             )

      refute has_element?(prof_agenda_view, "#approval-config-panel")

      {:ok, prof_settings_view, _} =
        live(internal_conn(ctx.conn, ctx.prof_owner.token), ~p"/profesional/ajustes")

      assert has_element?(prof_settings_view, "#approval-config-panel")

      assert has_element?(
               prof_agenda_view,
               "#create-professional-appointment[href='/profesional/agenda/crear']"
             )

      {:ok, sec_view, _} =
        live(internal_conn(ctx.conn, ctx.secretary.token), ~p"/secretaria/pacientes")

      assert has_element?(
               sec_view,
               "#role-navigation #nav-patients[href='/secretaria/pacientes'][aria-current='page']",
               "Pacientes"
             )

      patient_conn_1 = magic_link_patient_conn!(ctx.patient_1.email)
      {:ok, pat_view, _} = live(patient_conn_1, ~p"/paciente/turnos/reservar")

      assert has_element?(
               pat_view,
               "#role-navigation #nav-book[href='/paciente/turnos/reservar'][aria-current='page']",
               "Reservar turno"
             )

      # =========================================================================
      # COMBINACIÓN 1: Modalidad AUTOMÁTICA (Paciente -> confirmed, Secretaría -> confirmed, Profesional -> confirmed)
      # =========================================================================
      prof_settings_view
      |> form("#approval-config-form", %{
        "approval_mode" => "automatic",
        "secretary_approval_mode" => "confirmed"
      })
      |> render_change()

      assert {:ok, %{approval_mode: :automatic, secretary_approval_mode: :confirmed}} =
               Booking.get_approval_configuration(ctx.prof_owner.id)

      # 1a. Paciente autónomo reserva a las 08:00 -> nace confirmed
      appt_auto_patient =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "08:00",
          "confirmed"
        )

      assert appt_auto_patient.status == "confirmed"

      # 1b. Secretaría asistida reserva a las 08:30 -> nace confirmed
      appt_auto_sec =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "08:30",
          "confirmed"
        )

      assert appt_auto_sec.status == "confirmed"

      # 1c. Profesional propio (paciente existente) reserva a las 09:00 -> nace confirmed
      appt_auto_prof =
        book_as_professional_existing_live!(
          ctx.prof_owner,
          ctx.patient_3,
          date,
          "09:00"
        )

      assert appt_auto_prof.status == "confirmed"

      # 1d. En modo automático, aunque secretary_approval_mode quede en requested,
      # Secretaría y Paciente siguen confirmando directamente.
      prof_settings_view
      |> form("#approval-config-form", %{
        "approval_mode" => "automatic",
        "secretary_approval_mode" => "requested"
      })
      |> render_change()

      appt_auto_sec_with_req_sub =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "09:30",
          "confirmed"
        )

      assert appt_auto_sec_with_req_sub.status == "confirmed"

      # =========================================================================
      # COMBINACIÓN 2: Modalidad MANUAL + Secretaría CONFIRMED (C1, C9)
      # Paciente -> requested, Secretaría -> confirmed, Profesional -> confirmed
      # =========================================================================
      prof_settings_view
      |> form("#approval-config-form", %{
        "approval_mode" => "manual",
        "secretary_approval_mode" => "confirmed"
      })
      |> render_change()

      assert {:ok, %{approval_mode: :manual, secretary_approval_mode: :confirmed}} =
               Booking.get_approval_configuration(ctx.prof_owner.id)

      # 2a. Paciente autónomo reserva a las 10:00 -> nace requested y crea relación (C1)
      appt_man_conf_patient =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "10:00",
          "requested"
        )

      assert appt_man_conf_patient.status == "requested"

      assert Repo.get_by(ProfessionalPatientRelationship,
               professional_account_id: ctx.prof_owner.id,
               patient_profile_id: ctx.patient_1.id
             ) != nil

      # 2b. Secretaría asistida reserva a las 10:30 -> nace confirmed (C9)
      appt_man_conf_sec =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "10:30",
          "confirmed"
        )

      assert appt_man_conf_sec.status == "confirmed"

      # 2c. Profesional propio (paciente relacionado en Mis pacientes) reserva a las 11:00 -> nace confirmed
      appt_man_conf_prof =
        book_as_professional_related_live!(
          ctx.prof_owner,
          ctx.patient_3,
          date,
          "11:00"
        )

      assert appt_man_conf_prof.status == "confirmed"

      # =========================================================================
      # COMBINACIÓN 3: Modalidad MANUAL + Secretaría REQUESTED (C1, C10)
      # Paciente -> requested, Secretaría -> requested, Profesional (existente e inexistente) -> confirmed
      # =========================================================================
      prof_settings_view
      |> form("#approval-config-form", %{
        "approval_mode" => "manual",
        "secretary_approval_mode" => "requested"
      })
      |> render_change()

      assert {:ok, %{approval_mode: :manual, secretary_approval_mode: :requested}} =
               Booking.get_approval_configuration(ctx.prof_owner.id)

      # 3a. Paciente autónomo reserva a las 11:30 -> nace requested
      appt_man_req_patient =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "11:30",
          "requested"
        )

      assert appt_man_req_patient.status == "requested"

      # 3b. Secretaría asistida reserva a las 12:00 -> nace requested (C10)
      appt_man_req_sec =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "12:00",
          "requested"
        )

      assert appt_man_req_sec.status == "requested"

      # 3c. Profesional propio registra y agenda paciente INEXISTENTE (#283) a las 12:30 -> nace confirmed
      absent_dni =
        "49#{rem(ctx.suffix, 100_000) |> Integer.to_string() |> String.pad_leading(6, "0")}"

      appt_man_req_prof_absent =
        book_as_professional_absent_live!(
          ctx.prof_owner,
          absent_dni,
          date,
          "12:30"
        )

      assert appt_man_req_prof_absent.status == "confirmed"

      # Verificar en la agenda del profesional que requested y confirmed se distinguen (C11)
      {:ok, agenda_day_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/agenda?date=#{date_iso}"
        )

      {:ok, requests_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/solicitudes?date=#{date_iso}"
        )

      for req_id <- [
            appt_man_conf_patient.id,
            appt_man_req_patient.id,
            appt_man_req_sec.id
          ] do
        assert has_element?(agenda_day_view, "#appointment-#{req_id}", "Solicitado")
        refute has_element?(agenda_day_view, "#accept-request-#{req_id}")
        refute has_element?(agenda_day_view, "#reject-request-#{req_id}")
        assert has_element?(requests_view, "#accept-request-#{req_id}", "Aceptar")
        assert has_element?(requests_view, "#reject-request-#{req_id}", "Rechazar")
      end

      for conf_id <- [
            appt_auto_patient.id,
            appt_auto_sec.id,
            appt_auto_prof.id,
            appt_auto_sec_with_req_sub.id,
            appt_man_conf_sec.id,
            appt_man_conf_prof.id,
            appt_man_req_prof_absent.id
          ] do
        assert has_element?(agenda_day_view, "#appointment-#{conf_id}", "Confirmado")
        refute has_element?(agenda_day_view, "#accept-request-#{conf_id}")
        refute has_element?(agenda_day_view, "#reject-request-#{conf_id}")
      end
    end
  end

  describe "ocupación, resolución exclusiva y liberación (C1–C7, C11–C12)" do
    test "requested ocupa los 3 canales; aceptar confirma y rechazar libera el horario",
         ctx do
      date = ctx.future_date
      date_iso = Date.to_iso8601(date)

      # Configurar modo manual con secretaría en requested
      assert {:ok, _} =
               Booking.update_approval_configuration(ctx.prof_owner.id, %{
                 approval_mode: :manual,
                 secretary_approval_mode: :requested
               })

      patient_conn_1 = magic_link_patient_conn!(ctx.patient_1.email)

      # 1. Paciente 1 crea solicitud a las 09:00 y Secretaría crea solicitud a las 10:00 (ambas requested)
      req_0900 =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "09:00",
          "requested"
        )

      req_1000 =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "10:00",
          "requested"
        )

      slot_0900_dt = DateTime.new!(date, ~T[09:00:00], "Etc/UTC")
      slot_1000_dt = DateTime.new!(date, ~T[10:00:00], "Etc/UTC")

      # 2. C1: Verificar que los slots 09:00 y 10:00 están ocupados e impiden reservas en los 3 canales
      # - Canal Paciente: no aparecen en grilla y BookingService rechaza con :overlap_detected
      {:ok, pat_schedule} =
        Calendar.get_daily_schedule(to_string(ctx.prof_owner.id), date, duration_minutes: 30)

      refute Enum.any?(pat_schedule.slots, &(&1.start_formatted in ["09:00", "10:00"]))

      assert {:error, :overlap_detected} =
               BookingService.reserve(ctx.patient_3, %{
                 professional_id: ctx.prof_owner.id,
                 consultation_type_id: ctx.prof_owner.type_id,
                 date: date,
                 slot: %{start_time: ~T[09:00:00], start_formatted: "09:00"}
               })

      # - Canal Secretaría: no aparecen en grilla y AssistedBooking rechaza con :slot_already_booked
      {:ok, sec_schedule} =
        AssistedBooking.get_daily_schedule(ctx.prof_owner.id, date, duration_minutes: 30)

      refute Enum.any?(sec_schedule.slots, &(&1.start_formatted in ["09:00", "10:00"]))

      assert {:error, :slot_already_booked} =
               AssistedBooking.reserve(ctx.secretary.id, ctx.patient_3.id, %{
                 professional_id: ctx.prof_owner.id,
                 consultation_type_id: ctx.prof_owner.type_id,
                 start_time: slot_1000_dt
               })

      # - Canal Profesional (existente e inexistente): no aparecen en grilla y rechaza colisión
      {:ok, prof_schedule} =
        Booking.get_professional_booking_schedule(
          ctx.prof_owner.session,
          ctx.prof_owner.type_id,
          date
        )

      refute Enum.any?(prof_schedule.slots, &(&1.start_formatted in ["09:00", "10:00"]))

      assert {:error, :slot_already_booked} =
               Booking.reserve_professional_appointment(ctx.prof_owner.session, %{
                 patient_id: ctx.patient_3.id,
                 patient_document_number: ctx.patient_3.persona.document_number,
                 consultation_type_id: ctx.prof_owner.type_id,
                 start_time: slot_0900_dt
               })

      assert {:error, {:appointment, :slot_already_booked}} =
               Booking.register_and_reserve_professional_appointment(ctx.prof_owner.session, %{
                 first_name: "Nuevo",
                 last_name: "Paciente",
                 document_number: "48999888",
                 birthdate: ~D[1992-03-15],
                 phone: "+5491155556666",
                 email: nil,
                 consultation_type_id: ctx.prof_owner.type_id,
                 start_time: slot_1000_dt
               })

      # 3. C5 & C6: Verificar denegación (:unauthorized) a otros Profesionales, Secretaría, Admin y Paciente
      for unauthorized_actor <- [
            ctx.prof_other.id,
            ctx.prof_other.session,
            ctx.secretary.id,
            ctx.secretary.session,
            ctx.admin.id,
            ctx.admin.session,
            ctx.patient_1,
            %{role: :patient, id: ctx.patient_1.id}
          ] do
        assert {:error, :unauthorized} =
                 Booking.accept_request(unauthorized_actor, req_0900.id)

        assert {:error, :unauthorized} =
                 Booking.reject_request(unauthorized_actor, req_1000.id)
      end

      for non_prof_actor <- [
            ctx.secretary.id,
            ctx.secretary.session,
            ctx.admin.id,
            ctx.admin.session,
            ctx.patient_1,
            %{role: :patient, id: ctx.patient_1.id}
          ] do
        assert {:error, :unauthorized} =
                 Booking.update_approval_configuration(non_prof_actor, %{
                   approval_mode: :automatic
                 })
      end

      # También si Profesional B dispara el evento LiveView forjado desde su propia agenda
      {:ok, other_prof_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_other.token),
          ~p"/profesional/solicitudes?date=#{date_iso}"
        )

      refute has_element?(other_prof_view, "#appointment-#{req_0900.id}")

      html_forged =
        render_click(other_prof_view, "accept_request", %{"id" => to_string(req_0900.id)})

      assert html_forged =~ "No tenés permiso para resolver esta solicitud."
      assert Repo.get!(Appointment, req_0900.id).status == "requested"

      # 4. C2 & C12: Profesional dueño acepta req_0900 desde su vista de agenda LiveView
      {:ok, owner_agenda_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/solicitudes?date=#{date_iso}"
        )

      owner_agenda_view
      |> element("#accept-request-#{req_0900.id}")
      |> render_click()

      assert has_element?(
               owner_agenda_view,
               "#requests-flash-info",
               "Solicitud aceptada y turno confirmado."
             )

      refute has_element?(owner_agenda_view, "#appointment-#{req_0900.id}")

      {:ok, refreshed_agenda, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/agenda?date=#{date_iso}"
        )

      assert has_element?(refreshed_agenda, "#appointment-#{req_0900.id}", "Confirmado")
      refute has_element?(owner_agenda_view, "#accept-request-#{req_0900.id}")
      refute has_element?(owner_agenda_view, "#reject-request-#{req_0900.id}")
      assert Repo.get!(Appointment, req_0900.id).status == "confirmed"
      assert has_resolution_audit_event?(ctx.prof_owner.id, req_0900.id, "appointment_confirmed")

      # El slot 09:00 continúa ocupado tras aceptar
      assert {:error, :slot_already_booked} =
               AssistedBooking.reserve(ctx.secretary.id, ctx.patient_3.id, %{
                 professional_id: ctx.prof_owner.id,
                 consultation_type_id: ctx.prof_owner.type_id,
                 start_time: slot_0900_dt
               })

      # C7: Volver a aceptar o rechazar el turno ya confirmado devuelve transición inválida sin mutar datos
      assert {:error, :invalid_status_transition} =
               Booking.accept_request(ctx.prof_owner.id, req_0900.id)

      assert {:error, :invalid_status_transition} =
               Booking.reject_request(ctx.prof_owner.id, req_0900.id)

      # 5. C3, C4 & C12: Profesional dueño rechaza req_1000 desde su vista de agenda LiveView
      owner_agenda_view
      |> element("#reject-request-#{req_1000.id}")
      |> render_click()

      assert has_element?(
               owner_agenda_view,
               "#requests-flash-info",
               "Solicitud rechazada y horario liberado."
             )

      refute has_element?(owner_agenda_view, "#appointment-#{req_1000.id}")

      {:ok, refreshed_agenda, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/agenda?date=#{date_iso}"
        )

      assert render(refreshed_agenda) =~ "Cancelado"
      refute has_element?(owner_agenda_view, "#accept-request-#{req_1000.id}")
      refute has_element?(owner_agenda_view, "#reject-request-#{req_1000.id}")
      assert Repo.get!(Appointment, req_1000.id).status == "cancelled"
      assert has_resolution_audit_event?(ctx.prof_owner.id, req_1000.id, "appointment_cancelled")

      # C7: Intentar aceptar o rechazar el turno ya cancelado devuelve transición inválida
      assert {:error, :invalid_status_transition} =
               Booking.accept_request(ctx.prof_owner.id, req_1000.id)

      assert {:error, :invalid_status_transition} =
               Booking.reject_request(ctx.prof_owner.id, req_1000.id)

      # C4: El horario 10:00 queda libre inmediatamente en los 3 canales y otro canal puede reservarlo
      for {:ok, refreshed_sched} <- [
            Calendar.get_daily_schedule(to_string(ctx.prof_owner.id), date, duration_minutes: 30),
            AssistedBooking.get_daily_schedule(ctx.prof_owner.id, date, duration_minutes: 30),
            Booking.get_professional_booking_schedule(
              ctx.prof_owner.session,
              ctx.prof_owner.type_id,
              date
            )
          ] do
        assert Enum.any?(refreshed_sched.slots, &(&1.start_formatted == "10:00"))
      end

      # Paciente 3 reserva exitosamente en el mismo slot 10:00 recién liberado
      patient_conn_3 = magic_link_patient_conn!(ctx.patient_3.email)

      rebooked_1000 =
        book_as_patient_live!(
          patient_conn_3,
          ctx.prof_owner,
          ctx.patient_3,
          date,
          "10:00",
          "requested"
        )

      assert rebooked_1000.id != req_1000.id
      assert rebooked_1000.status == "requested"
    end

    test "sesión revocada del profesional falla cerrado al resolver o cambiar modalidad",
         ctx do
      date = ctx.future_date
      date_iso = Date.to_iso8601(date)

      patient_conn_1 = magic_link_patient_conn!(ctx.patient_1.email)

      req =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "14:00",
          "requested"
        )

      {:ok, view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/solicitudes?date=#{date_iso}"
        )

      {:ok, settings_view, _} =
        live(internal_conn(ctx.conn, ctx.prof_owner.token), ~p"/profesional/ajustes")

      # Revocar la sesión activa del profesional mientras la vista está abierta
      SQL.query!(
        Repo,
        "UPDATE internal_account_sessions SET revoked_at = NOW() WHERE id = $1",
        [ctx.prof_owner.session.session_id]
      )

      html_accept = render_click(view, "accept_request", %{"id" => to_string(req.id)})
      assert html_accept =~ "No tenés permiso para resolver esta solicitud."
      assert Repo.get!(Appointment, req.id).status == "requested"

      html_reject = render_click(view, "reject_request", %{"id" => to_string(req.id)})
      assert html_reject =~ "No tenés permiso para resolver esta solicitud."
      assert Repo.get!(Appointment, req.id).status == "requested"

      html_cfg =
        render_change(settings_view, "update_approval_config", %{
          "approval_mode" => "automatic",
          "secretary_approval_mode" => "confirmed"
        })

      assert html_cfg =~ "No tenés permiso para resolver esta solicitud."

      assert {:ok, %{approval_mode: :manual, secretary_approval_mode: :confirmed}} =
               Booking.get_approval_configuration(ctx.prof_owner.id)
    end
  end

  describe "inmutabilidad de pendientes ante cambio de modalidad (C8)" do
    test "cambiar modalidad o regla de Secretaría afecta sólo reservas nuevas",
         ctx do
      date = ctx.future_date

      {:ok, prof_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/ajustes"
        )

      # 1. En modo manual + secretaría requested, crear solicitud de Paciente (15:00) y Secretaría (15:30)
      prof_view
      |> form("#approval-config-form", %{
        "approval_mode" => "manual",
        "secretary_approval_mode" => "requested"
      })
      |> render_change()

      patient_conn_1 = magic_link_patient_conn!(ctx.patient_1.email)

      pending_pat =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "15:00",
          "requested"
        )

      pending_sec =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "15:30",
          "requested"
        )

      # 2. Cambiar a modo automático desde la UI del profesional
      {:ok, prof_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/ajustes"
        )

      html_change =
        prof_view
        |> form("#approval-config-form", %{
          "approval_mode" => "automatic",
          "secretary_approval_mode" => "confirmed"
        })
        |> render_change()

      assert html_change =~
               "Configuración de aprobación actualizada. Las solicitudes pendientes existentes conservan su estado."

      # Las solicitudes previas permanecen intactas en requested y siguen ocupando sus horarios
      assert Repo.get!(Appointment, pending_pat.id).status == "requested"
      assert Repo.get!(Appointment, pending_sec.id).status == "requested"

      {:ok, prof_view, _} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/solicitudes?date=#{Date.to_iso8601(date)}"
        )

      assert has_element?(prof_view, "#appointment-#{pending_pat.id}", "Solicitado")
      assert has_element?(prof_view, "#appointment-#{pending_sec.id}", "Solicitado")
      assert has_element?(prof_view, "#accept-request-#{pending_pat.id}")
      assert has_element?(prof_view, "#accept-request-#{pending_sec.id}")

      # Las nuevas reservas de Paciente (16:00) y Secretaría (16:30) nacen como confirmed
      new_pat_conf =
        book_as_patient_live!(
          patient_conn_1,
          ctx.prof_owner,
          ctx.patient_1,
          date,
          "16:00",
          "confirmed"
        )

      new_sec_conf =
        book_as_secretary_live!(
          ctx.secretary,
          ctx.prof_owner,
          ctx.patient_2,
          date,
          "16:30",
          "confirmed"
        )

      assert new_pat_conf.status == "confirmed"
      assert new_sec_conf.status == "confirmed"

      # Y las solicitudes anteriores siguen en requested hasta decisión explícita del profesional dueño
      assert Repo.get!(Appointment, pending_pat.id).status == "requested"
      assert Repo.get!(Appointment, pending_sec.id).status == "requested"
    end
  end

  describe "sondas de regresión adversarias (DOM IDs únicos, sesión forjada y multi-intervalo)" do
    test "mismo paciente con múltiples turnos en el día mantiene IDs DOM únicos y formulario único en tarjeta primaria",
         ctx do
      date = ctx.future_date
      date_iso = Date.to_iso8601(date)

      {:ok, _r1} =
        AssistedBooking.reserve(ctx.secretary.id, ctx.patient_1.id, %{
          professional_id: ctx.prof_owner.id,
          consultation_type_id: ctx.prof_owner.type_id,
          start_time: DateTime.new!(date, ~T[08:00:00], "Etc/UTC")
        })

      {:ok, r2} =
        AssistedBooking.reserve(ctx.secretary.id, ctx.patient_1.id, %{
          professional_id: ctx.prof_owner.id,
          consultation_type_id: ctx.prof_owner.type_id,
          start_time: DateTime.new!(date, ~T[09:00:00], "Etc/UTC")
        })

      {:ok, view, _html} =
        live(
          internal_conn(ctx.conn, ctx.prof_owner.token),
          ~p"/profesional/agenda?date=#{date_iso}"
        )

      assert has_element?(view, "#patient-access-status-#{ctx.patient_1.id}")
      assert has_element?(view, "#patient-access-status-#{ctx.patient_1.id}-#{r2.appointment_id}")
      assert has_element?(view, "#btn-open-replace-access-#{ctx.patient_1.id}")

      assert has_element?(
               view,
               "#btn-open-replace-access-#{ctx.patient_1.id}-#{r2.appointment_id}"
             )

      view
      |> element("#btn-open-replace-access-#{ctx.patient_1.id}-#{r2.appointment_id}")
      |> render_click()

      assert has_element?(view, "#patient-access-form-#{ctx.patient_1.id}")
      refute has_element?(view, "#patient-access-form-#{ctx.patient_1.id}-#{r2.appointment_id}")
    end

    test "principales forjados, entradas malformadas y anti-IDOR fallan cerrado sin mutar datos, y acepta struct InternalSession válido",
         ctx do
      assert {:ok, _} =
               Booking.update_approval_configuration(ctx.prof_owner.session, %{
                 approval_mode: :manual,
                 secretary_approval_mode: :requested
               })

      date = ctx.future_date
      start_dt = DateTime.new!(date, ~T[10:00:00], "Etc/UTC")

      {:ok, req} =
        AssistedBooking.reserve(ctx.secretary.id, ctx.patient_1.id, %{
          professional_id: ctx.prof_owner.id,
          consultation_type_id: ctx.prof_owner.type_id,
          start_time: start_dt
        })

      before_appt = Repo.get!(Appointment, req.appointment_id)
      {:ok, before_cfg} = Booking.get_approval_configuration(ctx.prof_owner.id)
      before_audit_count = count_audit_events(req.appointment_id)

      # Principal forjado combinando session_id de Secretaría con account_id del Profesional
      forged_principal = %{
        session_id: ctx.secretary.session.session_id,
        account_id: ctx.prof_owner.id
      }

      assert {:error, :unauthorized} =
               Booking.accept_request(forged_principal, req.appointment_id)

      assert {:error, :unauthorized} =
               Booking.reject_request(forged_principal, req.appointment_id)

      assert {:error, :unauthorized} =
               Booking.update_approval_configuration(forged_principal, %{
                 approval_mode: :automatic
               })

      for bad_actor <- [
            nil,
            "prof",
            -1,
            0,
            %{},
            %{session_id: "1", account_id: ctx.prof_owner.id}
          ] do
        assert {:error, :unauthorized} = Booking.accept_request(bad_actor, req.appointment_id)
        assert {:error, :unauthorized} = Booking.reject_request(bad_actor, req.appointment_id)

        assert {:error, :unauthorized} =
                 Booking.update_approval_configuration(bad_actor, %{approval_mode: :automatic})
      end

      assert {:error, :unauthorized} = Booking.accept_request(ctx.secretary.session, 999_999_999)
      assert {:error, :unauthorized} = Booking.reject_request(ctx.admin.session, 999_999_999)

      assert {:error, :appointment_not_found} =
               Booking.accept_request(ctx.prof_owner.session, 999_999_999)

      assert Repo.get!(Appointment, req.appointment_id) == before_appt
      assert Booking.get_approval_configuration(ctx.prof_owner.id) == {:ok, before_cfg}
      assert count_audit_events(req.appointment_id) == before_audit_count

      internal_session_struct = %InternalSession{
        id: ctx.prof_owner.session.session_id,
        account_id: ctx.prof_owner.id
      }

      assert {:ok, ^before_cfg} =
               Booking.update_approval_configuration(internal_session_struct, %{})

      assert {:ok, accepted} =
               Booking.accept_request(internal_session_struct, req.appointment_id)

      assert accepted.status == "confirmed"
    end

    test "solicitud multi-intervalo (60m) ocupa ambos sub-bloques y solapamiento de paciente entre agendas hasta que el rechazo los libera",
         ctx do
      {:ok, type_60m} =
        ConsultationTypes.create_type(ctx.prof_owner.session, %{
          name: "Evaluación Extendida 60m",
          exact_price_ars: "35000.00",
          color: "#12566B",
          interval_count: 2
        })

      assert {:ok, _} =
               Booking.update_approval_configuration(ctx.prof_owner.session, %{
                 approval_mode: :manual,
                 secretary_approval_mode: :requested
               })

      date = ctx.future_date
      slot_1000 = DateTime.new!(date, ~T[10:00:00], "Etc/UTC")
      slot_1030 = DateTime.new!(date, ~T[10:30:00], "Etc/UTC")

      assert {:ok, req_60m} =
               AssistedBooking.reserve(ctx.secretary.id, ctx.patient_1.id, %{
                 professional_id: ctx.prof_owner.id,
                 consultation_type_id: type_60m.id,
                 start_time: slot_1000
               })

      assert req_60m.status == :requested

      {:ok, pat_sched} =
        Calendar.get_daily_schedule(to_string(ctx.prof_owner.id), date, duration_minutes: 30)

      refute Enum.any?(pat_sched.slots, &(&1.start_formatted in ["10:00", "10:30"]))

      assert {:error, :patient_schedule_conflict} =
               Booking.check_overlaps(%{
                 professional_id: ctx.prof_other.id,
                 patient_id: ctx.patient_1.id,
                 start_time: slot_1030,
                 end_time: DateTime.add(slot_1030, 30, :minute)
               })

      assert {:ok, rejected} =
               Booking.reject_request(ctx.prof_owner.session, req_60m.appointment_id)

      assert rejected.status == "cancelled"

      {:ok, pat_sched_after} =
        Calendar.get_daily_schedule(to_string(ctx.prof_owner.id), date, duration_minutes: 30)

      assert Enum.any?(pat_sched_after.slots, &(&1.start_formatted == "10:00"))
      assert Enum.any?(pat_sched_after.slots, &(&1.start_formatted == "10:30"))

      assert {:ok, :no_conflict} =
               Booking.check_overlaps(%{
                 professional_id: ctx.prof_other.id,
                 patient_id: ctx.patient_1.id,
                 start_time: slot_1030,
                 end_time: DateTime.add(slot_1030, 30, :minute)
               })
    end
  end

  # ===========================================================================
  # Helpers de canales reales
  # ===========================================================================

  defp book_as_patient_live!(patient_conn, prof, patient, date, time_str, expected_status) do
    {:ok, view, _html} = live(patient_conn, ~p"/paciente/turnos/reservar")

    render_change(view, "change_prof", %{"prof_id" => to_string(prof.id)})
    render_change(view, "change_type", %{"type_id" => prof.type_id})
    render_change(view, "change_date", %{"date" => Date.to_iso8601(date)})

    slot_id = "SLOT-#{Date.to_iso8601(date)}-#{String.replace(time_str, ":", "")}"

    view
    |> element(~s(button[phx-value-slot_id="#{slot_id}"]))
    |> render_click()

    html = render_click(view, "confirm_booking")

    case expected_status do
      "confirmed" ->
        assert html =~ "Turno confirmado"

      "requested" ->
        assert html =~ "Solicitud enviada"
        assert html =~ "Pendiente de aprobación"
    end

    start_dt = DateTime.new!(date, Time.from_iso8601!(time_str <> ":00"), "Etc/UTC")

    Repo.get_by!(Appointment,
      patient_profile_id: patient.id,
      professional_account_id: prof.id,
      start_time: start_dt
    )
  end

  defp book_as_secretary_live!(secretary, prof, patient, date, time_str, expected_status) do
    {:ok, view, _html} =
      live(internal_conn(build_conn(), secretary.token), ~p"/secretaria/pacientes")

    view
    |> form("#persona-search-form",
      search: %{
        "document_type" => "dni",
        "document_number" => patient.persona.document_number
      }
    )
    |> render_submit()

    view |> element("#start-assisted-booking") |> render_click()

    render_change(view, "update_booking_selection", %{
      "professional_id" => to_string(prof.id),
      "consultation_type_id" => prof.type_id,
      "date" => Date.to_iso8601(date)
    })

    view
    |> element(~s(button[phx-click="select_slot"][phx-value-time="#{time_str}"]))
    |> render_click()

    view |> element("#confirm-assisted-booking") |> render_click()

    assert has_element?(
             view,
             "#booking-success-message",
             String.capitalize(expected_status)
           )

    start_dt = DateTime.new!(date, Time.from_iso8601!(time_str <> ":00"), "Etc/UTC")

    Repo.get_by!(Appointment,
      patient_profile_id: patient.id,
      professional_account_id: prof.id,
      start_time: start_dt
    )
  end

  defp book_as_professional_existing_live!(prof, patient, date, time_str) do
    {:ok, view, _html} =
      live(internal_conn(build_conn(), prof.token), ~p"/profesional/agenda/crear")

    view |> element("#tab-dni") |> render_click()

    view
    |> form("#patient-dni-form", %{dni: patient.persona.document_number})
    |> render_submit()

    view |> element("#patient-#{patient.id}") |> render_click()
    view |> element("#patient-selection-next") |> render_click()
    view |> element("#consultation-#{prof.type_id}") |> render_click()
    view |> element("#consultation-next") |> render_click()
    view |> form("#booking-date-form", %{date: Date.to_iso8601(date)}) |> render_change()

    slot_dom_id = "#slot-#{String.replace(time_str, ":", "")}"
    view |> element(slot_dom_id) |> render_click()
    view |> element("#slot-next") |> render_click()

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "Turno confirmado"

    start_dt = DateTime.new!(date, Time.from_iso8601!(time_str <> ":00"), "Etc/UTC")

    Repo.get_by!(Appointment,
      patient_profile_id: patient.id,
      professional_account_id: prof.id,
      start_time: start_dt
    )
  end

  defp book_as_professional_related_live!(prof, patient, date, time_str) do
    {:ok, view, _html} =
      live(internal_conn(build_conn(), prof.token), ~p"/profesional/agenda/crear")

    view |> element("#patient-#{patient.id}") |> render_click()
    view |> element("#patient-selection-next") |> render_click()
    view |> element("#consultation-#{prof.type_id}") |> render_click()
    view |> element("#consultation-next") |> render_click()
    view |> form("#booking-date-form", %{date: Date.to_iso8601(date)}) |> render_change()

    slot_dom_id = "#slot-#{String.replace(time_str, ":", "")}"
    view |> element(slot_dom_id) |> render_click()
    view |> element("#slot-next") |> render_click()

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "Turno confirmado"

    start_dt = DateTime.new!(date, Time.from_iso8601!(time_str <> ":00"), "Etc/UTC")

    Repo.get_by!(Appointment,
      patient_profile_id: patient.id,
      professional_account_id: prof.id,
      start_time: start_dt
    )
  end

  defp has_resolution_audit_event?(prof_id, appt_id, event_name) do
    {:ok, %{rows: rows}} =
      SQL.query(
        Repo,
        """
        SELECT 1 FROM public.audit_events
        WHERE actor_kind = 'professional'
          AND actor_ref = $1
          AND event = $2
          AND entity_kind = 'appointment'
          AND entity_ref = $3
          AND result = 'succeeded'
        """,
        ["internal_account:#{prof_id}", event_name, "appointment:#{appt_id}"]
      )

    rows != []
  end

  defp count_audit_events(appt_id) do
    {:ok, %{rows: [[count]]}} =
      SQL.query(
        Repo,
        "SELECT COUNT(*) FROM public.audit_events WHERE entity_ref = $1",
        ["appointment:#{appt_id}"]
      )

    count
  end

  defp book_as_professional_absent_live!(prof, absent_dni, date, time_str) do
    {:ok, view, _html} =
      live(internal_conn(build_conn(), prof.token), ~p"/profesional/agenda/crear")

    view |> element("#tab-dni") |> render_click()
    view |> form("#patient-dni-form", %{dni: absent_dni}) |> render_submit()

    view
    |> form("#assisted-patient-form", %{
      "patient" => %{
        "first_name" => "Lucía",
        "last_name" => "Ausente",
        "birthdate" => "1991-06-15",
        "phone" => "+5491177778888",
        "email" => ""
      }
    })
    |> render_submit()

    view |> element("#patient-selection-next") |> render_click()
    view |> element("#consultation-#{prof.type_id}") |> render_click()
    view |> element("#consultation-next") |> render_click()
    view |> form("#booking-date-form", %{date: Date.to_iso8601(date)}) |> render_change()

    slot_dom_id = "#slot-#{String.replace(time_str, ":", "")}"
    view |> element(slot_dom_id) |> render_click()
    view |> element("#slot-next") |> render_click()

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "Turno confirmado"

    start_dt = DateTime.new!(date, Time.from_iso8601!(time_str <> ":00"), "Etc/UTC")

    Repo.get_by!(Appointment,
      professional_account_id: prof.id,
      start_time: start_dt
    )
  end

  defp setup_bookable_professional!(suffix, first_name, last_name, specialty, opts) do
    staff = insert_staff_account!("prof-#{suffix}@example.test", "professional")

    assert {:ok, _profile} =
             Origen.ProfessionalProfiles.save_own_profile(staff.session, %{
               first_name: first_name,
               last_name: last_name,
               specialty: specialty,
               license_type: "Nacional",
               license_number: "MN-#{suffix}"
             })

    assert {:ok, _cfg} =
             Availability.replace_own_configuration(staff.session, %{
               weekly_availability: weekday_availability(),
               booking_horizon_days: 30,
               minimum_lead_minutes: 0
             })

    assert {:ok, type} =
             ConsultationTypes.create_type(staff.session, %{
               name: Keyword.fetch!(opts, :consultation_name),
               exact_price_ars: Keyword.fetch!(opts, :price),
               color: "#0A3847",
               interval_count: 1
             })

    assert {:ok, _} =
             RequestResolution.update_approval_configuration(staff.id, %{
               approval_mode: Keyword.fetch!(opts, :approval_mode),
               secretary_approval_mode: Keyword.fetch!(opts, :secretary_approval_mode)
             })

    Map.merge(staff, %{
      name: "#{first_name} #{last_name}",
      specialty: specialty,
      type_id: type.id
    })
  end

  defp insert_staff_account!(email, role) do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ($1, 'active', $2, 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        [role, email]
      )

    {:ok, %{session: session, token: token}} = Sessions.create_session(id)
    %{id: id, role: role, session: session, token: token}
  end

  defp complete_patient!(email, document_number, first_name, last_name) do
    {:ok, %{persona: persona, profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: first_name,
        last_name: last_name,
        document_type: "dni",
        document_number: document_number,
        birthdate: ~D[1990-05-10],
        phone: "+5491133445566"
      })

    %{profile | persona: persona}
  end

  defp magic_link_patient_conn!(email) do
    assert {:ok, :delivered} = PatientAccess.request_magic_link(email)

    token =
      receive do
        {:email, msg} ->
          [_, encoded] = Regex.run(~r{/paciente/acceso/verificar\?token=([^"&]+)}, msg.html_body)
          URI.decode_www_form(encoded)
      after
        1_000 -> flunk("Expected magic link email for #{email}")
      end

    conn = get(build_conn(), ~p"/paciente/acceso/verificar?token=#{token}")
    assert redirected_to(conn) == ~p"/paciente/turnos/reservar"
    conn
  end

  defp internal_conn(conn, token) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp weekday_availability do
    Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
      {day, [%{"start" => "08:00", "end" => "18:00"}]}
    end)
  end

  defp next_weekday(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, 2)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end
end
