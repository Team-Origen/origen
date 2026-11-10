defmodule OrigenWeb.AppointmentLifecycleIntegrationTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Ecto.Adapters.SQL
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

    assert has_element?(professional_view, "#accept-request-#{appointment.id}", "Aceptar")

    professional_view
    |> element("#accept-request-#{appointment.id}")
    |> render_click()

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
