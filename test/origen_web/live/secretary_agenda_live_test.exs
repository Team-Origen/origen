defmodule OrigenWeb.SecretaryAgendaLiveTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  @path "/secretaria/agenda"

  setup do
    fixture = Fixtures.create!()
    principal = Fixtures.secretary_principal(fixture)

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:internal_session_token, principal.token)

    %{fixture: fixture, principal: principal, conn: conn}
  end

  test "requires an active secretary session and rejects other internal roles", %{
    fixture: fixture
  } do
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), @path)

    for role <- [:professional, :administrator] do
      principal = principal_for(fixture, role)
      conn = internal_conn(principal.token)
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, @path)
    end

    secretary = Fixtures.secretary_principal(fixture)
    Sessions.terminate_session(secretary.token)
    assert {:error, {:redirect, %{to: "/"}}} = live(internal_conn(secretary.token), @path)
  end

  test "renders all operational states and does not expose request resolution", %{
    fixture: fixture,
    conn: conn
  } do
    now = DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC")

    for {status, offset, professional_id} <- [
          {"requested", 3600, fixture.professional_id},
          {"confirmed", 7200, fixture.other_professional_id},
          {"expired", -1800, fixture.professional_id},
          {"cancelled", -3600, fixture.other_professional_id},
          {"attended", -5400, fixture.professional_id},
          {"no_show", -7200, fixture.other_professional_id}
        ] do
      Fixtures.appointment!(fixture,
        status: status,
        professional_account_id: professional_id,
        start_time: DateTime.add(now, offset, :second)
      )
    end

    {:ok, view, html} = live(conn, @path)

    for label <- [
          "Pendiente de aprobación",
          "Confirmado",
          "Vencido",
          "Cancelado",
          "Asistió",
          "No asistió"
        ] do
      assert html =~ label
    end

    refute html =~ "Aceptar solicitud"
    refute html =~ "Rechazar solicitud"
    assert has_element?(view, "#role-navigation[data-role='secretary']")

    assert has_element?(
             view,
             "#nav-agenda[href='/secretaria/agenda'][aria-current='page']",
             "Agenda"
           )

    assert has_element?(view, "#nav-patients[href='/secretaria/pacientes']", "Pacientes")
    assert has_element?(view, "#navigation-secretary-avatar", "S")
    assert has_element?(view, "#navigation-secretary-role", "Secretaría")
    assert has_element?(view, "#navigation-secretary-name", "Secretaría")
    assert has_element?(view, "#navigation-secretary-email")
    assert has_element?(view, "#navigation-account-menu form[action='/logout'][method='post']")
  end

  test "cancels requested and confirmed appointments across agendas with a mandatory reason", %{
    fixture: fixture,
    principal: principal,
    conn: conn
  } do
    now = DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC")
    requested = Fixtures.appointment!(fixture, start_time: DateTime.add(now, 3600, :second))

    confirmed =
      Fixtures.appointment!(fixture,
        patient_profile_id: fixture.other_patient_id,
        professional_account_id: fixture.other_professional_id,
        start_time: DateTime.add(now, 7200, :second),
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, @path)
    {:ok, before} = Booking.list_appointment_history(principal)

    view |> element("#cancel-appointment-#{requested.id}") |> render_click()

    html =
      view
      |> form("#appointment-cancellation-form-#{requested.id}", cancellation: %{reason: "   "})
      |> render_submit()

    assert html =~ "Indicá un motivo para cancelar el turno."
    assert Repo.get!(Appointment, requested.id).status == "requested"
    assert {:ok, ^before} = Booking.list_appointment_history(principal)

    for {appointment, reason} <- [
          {requested, "Paciente reubicado"},
          {confirmed, "Equipo no disponible"}
        ] do
      view
      |> element("#cancel-appointment-#{appointment.id}")
      |> render_click()

      view
      |> form("#appointment-cancellation-form-#{appointment.id}", cancellation: %{reason: reason})
      |> render_submit()
    end

    assert Repo.get!(Appointment, requested.id).status == "cancelled"
    assert Repo.get!(Appointment, confirmed.id).status == "cancelled"

    assert {:ok, history} = Booking.list_appointment_history(principal)

    assert Enum.map(history, &{&1.id, &1.cancellation_origin, &1.cancellation_reason}) == [
             {requested.id, "secretary", "Paciente reubicado"},
             {confirmed.id, "secretary", "Equipo no disponible"}
           ]
  end

  test "records attendance only for confirmed appointments and rejects expired or requested", %{
    fixture: fixture,
    principal: principal,
    conn: conn
  } do
    now = DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC")

    attended =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, 3600, :second),
        status: "confirmed"
      )

    no_show =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, 7200, :second),
        status: "confirmed"
      )

    requested =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, 10800, :second),
        status: "requested"
      )

    expired =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, -1800, :second),
        status: "expired"
      )

    {:ok, view, _html} = live(conn, @path)

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(attended.id),
      "outcome" => "attended"
    })

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(no_show.id),
      "outcome" => "no_show"
    })

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(requested.id),
      "outcome" => "attended"
    })

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(expired.id),
      "outcome" => "no_show"
    })

    assert Repo.get!(Appointment, attended.id).status == "attended"
    assert Repo.get!(Appointment, no_show.id).status == "no_show"
    assert Repo.get!(Appointment, requested.id).status == "requested"
    assert Repo.get!(Appointment, expired.id).status == "expired"
    assert {:ok, history} = Booking.list_appointment_history(principal)
    assert Enum.map(history, & &1.status) == ["expired", "attended", "no_show", "requested"]
  end

  test "forged ids do not leak or mutate appointments outside the rendered history", %{
    fixture: fixture,
    conn: conn
  } do
    foreign =
      Fixtures.appointment!(fixture,
        professional_account_id: fixture.other_professional_id,
        start_time: DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC"),
        status: "confirmed"
      )

    {:ok, view, html} = live(conn, @path)
    assert html =~ "Historial operativo del centro"
    assert html =~ "##{foreign.id}"

    html =
      render_click(view, "submit_cancellation", %{
        "appointment_id" => "not-an-id",
        "cancellation" => %{"reason" => "Motivo forjado"}
      })

    assert html =~ "El identificador del turno no es válido."
    assert Repo.get!(Appointment, foreign.id).status == "confirmed"
    refute render(view) =~ "Motivo forjado"
  end

  test "secretary cancellation origin is visible in the patient's public history", %{
    fixture: fixture,
    principal: principal,
    conn: conn
  } do
    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC")
      )

    {:ok, view, _html} = live(conn, @path)
    view |> element("#cancel-appointment-#{appointment.id}") |> render_click()

    view
    |> form("#appointment-cancellation-form-#{appointment.id}",
      cancellation: %{reason: "Cierre del centro"}
    )
    |> render_submit()

    assert {:ok, history} = Booking.list_appointment_history(principal)

    assert [%{cancellation_origin: "secretary", cancellation_reason: "Cierre del centro"}] =
             history

    patient = Fixtures.patient_principal(fixture)

    patient_conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, patient.patient_email)
      |> Plug.Conn.put_session(:patient_authenticated_at, patient.patient_authenticated_at)

    {:ok, _patient_view, html} = live(patient_conn, "/paciente/turnos")
    assert html =~ "Secretaría"
    assert html =~ "Cierre del centro"
  end

  defp principal_for(fixture, :professional), do: Fixtures.professional_principal(fixture)
  defp principal_for(fixture, :administrator), do: Fixtures.admin_principal(fixture)

  defp internal_conn(token) do
    build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end
end
