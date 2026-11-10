defmodule OrigenWeb.PatientAppointmentsLiveTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    fixture = Fixtures.create!()
    authenticated_at = DateTime.utc_now()

    email =
      Repo.query!("SELECT email FROM patient_profiles WHERE id = $1", [fixture.patient_id]).rows
      |> hd()
      |> hd()

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, email)
      |> Plug.Conn.put_session(:patient_authenticated_at, DateTime.to_iso8601(authenticated_at))

    %{
      fixture: fixture,
      conn: conn,
      principal: %{patient_email: email, patient_authenticated_at: authenticated_at}
    }
  end

  test "loads the patient's persisted history on re-entry and hides foreign appointments", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    now = DateTime.utc_now()

    own_expired =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, -7200, :second),
        status: "expired"
      )

    own_cancelled = Fixtures.appointment!(fixture, start_time: DateTime.add(now, -3600, :second))

    foreign =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, 3600, :second),
        patient_profile_id: fixture.other_patient_id
      )

    assert {:ok, _cancelled} =
             Booking.cancel_appointment(
               Fixtures.professional_principal(fixture),
               own_cancelled.id,
               reason: "Guardia reprogramada",
               now: now
             )

    {:ok, view, html} = live(conn, ~p"/paciente/turnos")

    assert html =~ "Mis turnos"

    assert has_element?(
             view,
             "#nav-turns[href='/paciente/turnos'][aria-current='page']",
             "Mis turnos"
           )

    assert has_element?(view, "#nav-book[href='/paciente/turnos/reservar']", "Reservar turno")
    assert has_element?(view, "#navigation-patient-email", principal.patient_email)

    assert has_element?(
             view,
             "#navigation-account-menu form[action='/paciente/cerrar-sesion'][method='post']"
           )

    refute has_element?(view, "#navigation-account-menu form[action='/logout']")
    assert html =~ "Vencido"
    assert html =~ "Cancelado"
    assert html =~ "Profesional"
    assert html =~ "Guardia reprogramada"
    refute has_element?(view, "#patient-appointment-#{foreign.id}")
    assert has_element?(view, "#patient-appointment-#{own_expired.id}")

    assert {:ok, history} = Booking.list_appointment_history(principal)
    assert Enum.map(history, & &1.id) == [own_expired.id, own_cancelled.id]
  end

  test "cancels a requested appointment through the real backend and refreshes public history", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    appointment =
      Fixtures.appointment!(fixture, start_time: DateTime.add(DateTime.utc_now(), 3600, :second))

    {:ok, view, html} = live(conn, ~p"/paciente/turnos")
    assert html =~ "Pendiente de aprobación"

    assert has_element?(
             view,
             "button[phx-click='cancel_appointment'][phx-value-appointment_id='#{appointment.id}']"
           )

    html =
      render_click(view, "cancel_appointment", %{"appointment_id" => to_string(appointment.id)})

    assert html =~ "Turno cancelado"
    assert html =~ "Cancelado"

    assert {:ok,
            [
              %{
                id: id,
                status: "cancelled",
                cancellation_origin: "patient",
                cancellation_reason: nil
              }
            ]} =
             Booking.list_appointment_history(principal)

    assert id == appointment.id
  end

  test "cancels a confirmed appointment before start without requiring a reason", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), 7200, :second),
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/paciente/turnos")
    assert has_element?(view, "button[phx-value-appointment_id='#{appointment.id}']")

    render_click(view, "cancel_appointment", %{"appointment_id" => to_string(appointment.id)})

    assert {:ok,
            [
              %{
                id: id,
                status: "cancelled",
                cancellation_origin: "patient",
                cancellation_reason: nil
              }
            ]} =
             Booking.list_appointment_history(principal)

    assert id == appointment.id
  end

  test "rejects foreign cancellation and unknown attendance events without changing public history",
       %{
         fixture: fixture,
         conn: conn,
         principal: principal
       } do
    own =
      Fixtures.appointment!(fixture, start_time: DateTime.add(DateTime.utc_now(), 3600, :second))

    foreign =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), 7200, :second),
        patient_profile_id: fixture.other_patient_id,
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/paciente/turnos")
    {:ok, before} = Booking.list_appointment_history(principal)

    html = render_click(view, "cancel_appointment", %{"appointment_id" => to_string(foreign.id)})
    assert html =~ "No se pudo cancelar"
    assert {:ok, after_foreign_attempt} = Booking.list_appointment_history(principal)
    assert after_foreign_attempt == before

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(own.id),
      "outcome" => "attended"
    })

    assert {:ok, after_unknown_event} = Booking.list_appointment_history(principal)
    assert after_unknown_event == before
  end

  test "does not offer or bypass patient cancellation after start", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), -60, :second),
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/paciente/turnos")
    refute has_element?(view, "button[phx-value-appointment_id='#{appointment.id}']")

    {:ok, before} = Booking.list_appointment_history(principal)

    html =
      render_click(view, "cancel_appointment", %{"appointment_id" => to_string(appointment.id)})

    assert html =~ "No se puede cancelar"
    assert {:ok, after_attempt} = Booking.list_appointment_history(principal)
    assert after_attempt == before
  end
end
