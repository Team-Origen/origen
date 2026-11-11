defmodule OrigenWeb.AppointmentLifecycleIntegrationTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Ecto.Adapters.SQL
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleIntegrationHelpers, as: Helpers

  setup do
    previous_calendar = Application.get_env(:origen, :appointments_calendar_adapter)
    previous_catalog = Application.get_env(:origen, :consultation_type_catalog_adapter)

    Application.put_env(
      :origen,
      :appointments_calendar_adapter,
      Origen.Appointments.DatabaseCalendar
    )

    Application.put_env(
      :origen,
      :consultation_type_catalog_adapter,
      Origen.ConsultationTypes.DatabaseCatalog
    )

    on_exit(fn ->
      Application.put_env(:origen, :appointments_calendar_adapter, previous_calendar)
      Application.put_env(:origen, :consultation_type_catalog_adapter, previous_catalog)
    end)

    %{ctx: Helpers.context!()}
  end

  test "patient request resolves through the professional UI and survives role reloads", %{
    ctx: ctx
  } do
    patient_conn = Helpers.patient_conn!(ctx.patient.profile.email)
    {:ok, patient_view, _html} = live(patient_conn, "/paciente/turnos")

    assert has_element?(
             patient_view,
             "#nav-turns[href='/paciente/turnos'][aria-current='page']",
             "Mis turnos"
           )

    assert has_element?(
             patient_view,
             "#nav-book[href='/paciente/turnos/reservar']",
             "Reservar turno"
           )

    appointment = Helpers.book_as_patient!(ctx, ctx.patient, ctx.professional, ctx.date, "09:00")
    assert appointment.status == "requested"

    {:ok, professional_view, agenda_html} =
      live(
        Helpers.internal_conn(ctx.professional.token),
        "/profesional/agenda?date=#{Date.to_iso8601(ctx.date)}"
      )

    assert agenda_html =~ "Solicitado"

    assert has_element?(
             professional_view,
             "#nav-agenda[href='/profesional/agenda'][aria-current='page']",
             "Agenda"
           )

    refute has_element?(professional_view, "#accept-request-#{appointment.id}")

    {:ok, requests_view, _} =
      live(
        Helpers.internal_conn(ctx.professional.token),
        "/profesional/solicitudes?date=#{Date.to_iso8601(ctx.date)}"
      )

    assert has_element?(requests_view, "#nav-requests[aria-current='page']", "Solicitudes")
    assert has_element?(requests_view, "#accept-request-#{appointment.id}", "Aceptar")

    requests_view
    |> element("#accept-request-#{appointment.id}")
    |> render_click()

    refute has_element?(requests_view, "#appointment-#{appointment.id}")

    {:ok, professional_view, _} =
      live(
        Helpers.internal_conn(ctx.professional.token),
        "/profesional/agenda?date=#{Date.to_iso8601(ctx.date)}"
      )

    assert has_element?(professional_view, "#appointment-#{appointment.id}", "Confirmado")
    assert Repo.get!(Appointment, appointment.id).status == "confirmed"
    assert audit_count(appointment.id, "appointment_confirmed") == 1

    {:ok, reloaded_patient, reloaded_html} =
      live(Helpers.patient_conn!(ctx.patient.profile.email), "/paciente/turnos")

    assert has_element?(reloaded_patient, "#patient-appointment-#{appointment.id}", "Confirmado")
    assert reloaded_html =~ "Historial de turnos"
    refute reloaded_html =~ "D-1"
    assert reloaded_html =~ "Podés cancelar hasta antes del inicio, sin multa."
  end

  test "professional cancellation requires a reason, preserves rejected state, and replacement is a new booking",
       %{ctx: ctx} do
    original = Helpers.book_as_patient!(ctx, ctx.patient, ctx.professional, ctx.date, "10:00")
    assert original.status == "requested"

    {:ok, professional_view, _html} =
      live(
        Helpers.internal_conn(ctx.professional.token),
        "/profesional/agenda?date=#{Date.to_iso8601(ctx.date)}"
      )

    {:ok, before_history} = Booking.list_appointment_history(ctx.professional.session)
    before_cancel_audit = audit_count(original.id, "appointment_cancelled")

    professional_view
    |> element("#cancel-appointment-#{original.id}")
    |> render_click()

    rejected_html =
      professional_view
      |> form("#appointment-cancellation-form-#{original.id}", cancellation: %{reason: "   "})
      |> render_submit()

    assert rejected_html =~ "Indicá un motivo para cancelar el turno."
    assert Repo.get!(Appointment, original.id).status == "requested"
    assert audit_count(original.id, "appointment_cancelled") == before_cancel_audit
    assert {:ok, ^before_history} = Booking.list_appointment_history(ctx.professional.session)

    professional_view
    |> form("#appointment-cancellation-form-#{original.id}",
      cancellation: %{reason: "Guardia reprogramada"}
    )
    |> render_submit()

    assert Repo.get!(Appointment, original.id).status == "cancelled"
    assert audit_count(original.id, "appointment_cancelled") == before_cancel_audit + 1

    {:ok, patient_after_cancel, patient_html} =
      live(Helpers.patient_conn!(ctx.patient.profile.email), "/paciente/turnos")

    assert has_element?(patient_after_cancel, "#patient-appointment-#{original.id}", "Cancelado")
    assert patient_html =~ "Origen: Profesional"
    assert patient_html =~ "Guardia reprogramada"

    date_replacement =
      Helpers.book_as_patient!(ctx, ctx.patient, ctx.professional, ctx.replacement_date, "10:00")

    assert date_replacement.id != original.id
    assert date_replacement.start_time != original.start_time
    assert date_replacement.consultation_type_id == original.consultation_type_id
    Helpers.cancel_as_patient!(ctx.patient, date_replacement.id)

    hour_replacement =
      Helpers.book_as_patient!(ctx, ctx.patient, ctx.professional, ctx.date, "11:00")

    assert DateTime.to_date(hour_replacement.start_time) == DateTime.to_date(original.start_time)
    assert DateTime.to_time(hour_replacement.start_time) != DateTime.to_time(original.start_time)
    assert hour_replacement.consultation_type_id == original.consultation_type_id
    Helpers.cancel_as_patient!(ctx.patient, hour_replacement.id)

    type_replacement =
      Helpers.book_as_patient!(
        ctx,
        ctx.patient,
        ctx.professional,
        ctx.date,
        "12:00",
        ctx.professional.second_type
      )

    assert DateTime.to_date(type_replacement.start_time) == DateTime.to_date(original.start_time)
    assert DateTime.to_time(type_replacement.start_time) != DateTime.to_time(original.start_time)
    assert type_replacement.consultation_type_id != original.consultation_type_id
    Helpers.cancel_as_patient!(ctx.patient, type_replacement.id)

    assert {:ok, history} =
             Booking.list_appointment_history(%{
               patient_email: ctx.patient.profile.email,
               patient_authenticated_at: DateTime.utc_now()
             })

    assert Enum.sort(Enum.map(history, &{&1.id, &1.status})) ==
             Enum.sort([
               {original.id, "cancelled"},
               {date_replacement.id, "cancelled"},
               {hour_replacement.id, "cancelled"},
               {type_replacement.id, "cancelled"}
             ])
  end

  test "secretary cancellation and attendance use real bookings and remain visible after reload",
       %{ctx: ctx} do
    cancelled =
      Helpers.book_as_secretary!(
        ctx,
        ctx.other_patient,
        ctx.other_professional,
        ctx.date,
        "09:00"
      )

    no_show =
      Helpers.book_as_secretary!(
        ctx,
        ctx.other_patient,
        ctx.other_professional,
        ctx.date,
        "10:00"
      )

    attended =
      Helpers.book_as_patient!(ctx, ctx.patient, ctx.other_professional, ctx.date, "11:00")

    {:ok, secretary_view, secretary_html} =
      live(
        Helpers.internal_conn(ctx.secretary.token),
        "/secretaria/agenda?date=#{Date.to_iso8601(ctx.date)}"
      )

    assert secretary_html =~ "Historial operativo del centro"

    assert has_element?(
             secretary_view,
             "#nav-agenda[href='/secretaria/agenda'][aria-current='page']",
             "Agenda"
           )

    render_change(secretary_view, "change_date", %{"date" => Date.to_iso8601(ctx.date)})
    assert has_element?(secretary_view, "#cancel-appointment-#{cancelled.id}")

    secretary_view
    |> element("#cancel-appointment-#{cancelled.id}")
    |> render_click()

    before = Repo.get!(Appointment, cancelled.id)
    before_audit = audit_count(cancelled.id, "appointment_cancelled")

    rejected_html =
      secretary_view
      |> form("#appointment-cancellation-form-#{cancelled.id}", cancellation: %{reason: ""})
      |> render_submit()

    assert rejected_html =~ "Indicá un motivo para cancelar el turno."
    assert Repo.get!(Appointment, cancelled.id) == before
    assert audit_count(cancelled.id, "appointment_cancelled") == before_audit

    secretary_view
    |> form("#appointment-cancellation-form-#{cancelled.id}",
      cancellation: %{reason: "Cierre del centro"}
    )
    |> render_submit()

    assert Repo.get!(Appointment, cancelled.id).status == "cancelled"
    assert Repo.get!(Appointment, cancelled.id).cancellation_origin == "secretary"
    assert audit_count(cancelled.id, "appointment_cancelled") == before_audit + 1

    render_click(secretary_view, "record_attendance", %{
      "appointment_id" => to_string(no_show.id),
      "outcome" => "no_show"
    })

    {:ok, professional_view, _html} =
      live(
        Helpers.internal_conn(ctx.other_professional.token),
        "/profesional/agenda?date=#{Date.to_iso8601(ctx.date)}"
      )

    render_click(professional_view, "record_attendance", %{
      "appointment_id" => to_string(attended.id),
      "outcome" => "attended"
    })

    assert Repo.get!(Appointment, no_show.id).status == "no_show"
    assert Repo.get!(Appointment, attended.id).status == "attended"
    assert audit_count(no_show.id, "appointment_no_show") == 1
    assert audit_count(attended.id, "appointment_attended") == 1

    {:ok, patient_view, patient_html} =
      live(Helpers.patient_conn!(ctx.other_patient.profile.email), "/paciente/turnos")

    assert has_element?(patient_view, "#patient-appointment-#{cancelled.id}", "Cancelado")
    assert has_element?(patient_view, "#patient-appointment-#{no_show.id}", "No asistió")
    assert patient_html =~ "Origen: Secretaría"
    assert patient_html =~ "Cierre del centro"

    {:ok, patient_history} =
      Booking.list_appointment_history(%{
        patient_email: ctx.other_patient.profile.email,
        patient_authenticated_at: DateTime.utc_now()
      })

    assert Enum.map(patient_history, &{&1.id, &1.status}) == [
             {cancelled.id, "cancelled"},
             {no_show.id, "no_show"}
           ]
  end

  test "public expiry sweep releases the slot and history remains private across roles", %{
    ctx: ctx
  } do
    expired = Helpers.book_as_patient!(ctx, ctx.patient, ctx.professional, ctx.date, "12:00")
    assert expired.status == "requested"

    assert {:ok, %{expired_count: 1, appointment_ids: [id]}} =
             Booking.expire_due_requested(now: DateTime.add(expired.start_time, 1, :second))

    assert id == expired.id
    assert Repo.get!(Appointment, expired.id).status == "expired"

    {:ok, released_schedule} =
      Origen.Appointments.Calendar.get_daily_schedule(
        to_string(ctx.professional.id),
        ctx.date,
        duration_minutes: 30
      )

    assert Enum.any?(released_schedule.slots, &(&1.start_formatted == "12:00"))

    {:ok, professional_view, _html} =
      live(
        Helpers.internal_conn(ctx.professional.token),
        "/profesional/agenda?date=#{Date.to_iso8601(ctx.date)}"
      )

    before_expired_attendance = Booking.list_appointment_history(ctx.professional.session)

    render_click(professional_view, "record_attendance", %{
      "appointment_id" => to_string(expired.id),
      "outcome" => "no_show"
    })

    assert Repo.get!(Appointment, expired.id).status == "expired"
    assert Booking.list_appointment_history(ctx.professional.session) == before_expired_attendance

    confirmed =
      Helpers.book_as_patient!(ctx, ctx.patient, ctx.other_professional, ctx.date, "13:00")

    assert confirmed.status == "confirmed"

    {:ok, patient_view, patient_html} =
      live(Helpers.patient_conn!(ctx.patient.profile.email), "/paciente/turnos")

    assert has_element?(patient_view, "#patient-appointment-#{expired.id}", "Vencido")
    assert has_element?(patient_view, "#patient-appointment-#{confirmed.id}", "Confirmado")

    before_patient_history =
      Booking.list_appointment_history(%{
        patient_email: ctx.patient.profile.email,
        patient_authenticated_at: DateTime.utc_now()
      })

    render_click(patient_view, "record_attendance", %{
      "appointment_id" => to_string(confirmed.id),
      "outcome" => "attended"
    })

    assert Booking.list_appointment_history(%{
             patient_email: ctx.patient.profile.email,
             patient_authenticated_at: DateTime.utc_now()
           }) == before_patient_history

    render_click(patient_view, "cancel_appointment", %{
      "appointment_id" => to_string(confirmed.id)
    })

    assert Repo.get!(Appointment, confirmed.id).status == "cancelled"
    assert Repo.get!(Appointment, confirmed.id).cancellation_origin == "patient"
    assert Repo.get!(Appointment, confirmed.id).cancellation_reason == nil

    {:ok, owner_history} = Booking.list_appointment_history(ctx.professional.session)
    {:ok, other_history} = Booking.list_appointment_history(ctx.other_professional.session)
    {:ok, secretary_history} = Booking.list_appointment_history(ctx.secretary.session)

    assert Enum.map(owner_history, & &1.id) == [expired.id]
    assert Enum.map(other_history, & &1.id) == [confirmed.id]
    assert Enum.map(secretary_history, & &1.id) == [expired.id, confirmed.id]
    assert Booking.list_appointment_history(ctx.administrator.session) == {:error, :unauthorized}

    assert patient_html =~ "Vencido"
    refute patient_html =~ "D-1"
    refute patient_html =~ "WhatsApp"
  end

  defp audit_count(appointment_id, event) do
    %{rows: [[count]]} =
      SQL.query!(
        Repo,
        """
        SELECT COUNT(*)
        FROM public.audit_events
        WHERE entity_ref = $1 AND event = $2 AND result = 'succeeded'
        """,
        ["appointment:#{appointment_id}", event]
      )

    count
  end
end
