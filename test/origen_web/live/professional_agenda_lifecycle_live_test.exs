defmodule OrigenWeb.ProfessionalAgendaLifecycleLiveTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    fixture = Fixtures.create!()
    professional = Fixtures.professional_principal(fixture)

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:internal_session_token, professional.token)

    %{fixture: fixture, conn: conn, principal: professional}
  end

  test "renders own lifecycle history with expiry, origin and reason", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    now = DateTime.utc_now()

    expired =
      Fixtures.appointment!(fixture,
        patient_profile_id: fixture.other_patient_id,
        start_time: DateTime.add(now, -7200, :second),
        status: "expired"
      )

    cancelled =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(now, -3600, :second),
        status: "requested"
      )

    assert {:ok, _} =
             Booking.cancel_appointment(principal, cancelled.id,
               reason: "Guardia reprogramada",
               now: now
             )

    {:ok, _view, html} = live(conn, ~p"/profesional/agenda")

    assert html =~ "Historial operativo"
    assert html =~ "Vencido"
    assert html =~ "Cancelado"
    assert html =~ "Origen:"
    assert html =~ "Profesional"
    assert html =~ "Motivo:"
    assert html =~ "Guardia reprogramada"
    assert html =~ "##{expired.id}"
    assert html =~ "##{cancelled.id}"

    assert {:ok, history} = Booking.list_appointment_history(principal)
    assert Enum.map(history, & &1.id) == [expired.id, cancelled.id]
  end

  test "requires a reason and preserves history when staff cancellation is rejected", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "requested"
      )

    {:ok, view, _html} = live(conn, ~p"/profesional/agenda")
    {:ok, before} = Booking.list_appointment_history(principal)

    view |> element("#cancel-appointment-#{appointment.id}") |> render_click()

    html =
      view
      |> form("#appointment-cancellation-form-#{appointment.id}",
        cancellation: %{reason: "   "}
      )
      |> render_submit()

    assert html =~ "Indicá un motivo para cancelar el turno."
    assert Repo.get!(Appointment, appointment.id).status == "requested"
    assert {:ok, after_rejection} = Booking.list_appointment_history(principal)
    assert after_rejection == before
  end

  test "cancels requested and confirmed appointments with a visible reason", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    requested =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), 1800, :second),
        status: "requested"
      )

    confirmed =
      Fixtures.appointment!(fixture,
        patient_profile_id: fixture.other_patient_id,
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

    for {appointment, reason} <- [{requested, "Paciente reubicado"}, {confirmed, "Corte de luz"}] do
      view |> element("#cancel-appointment-#{appointment.id}") |> render_click()

      view
      |> form("#appointment-cancellation-form-#{appointment.id}",
        cancellation: %{reason: reason}
      )
      |> render_submit()
    end

    assert Repo.get!(Appointment, requested.id).status == "cancelled"
    assert Repo.get!(Appointment, confirmed.id).status == "cancelled"

    assert {:ok, history} = Booking.list_appointment_history(principal)

    assert Enum.map(history, &{&1.id, &1.cancellation_origin, &1.cancellation_reason}) == [
             {requested.id, "professional", "Paciente reubicado"},
             {confirmed.id, "professional", "Corte de luz"}
           ]
  end

  test "records attended and no-show only for confirmed appointments", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    attended =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "confirmed"
      )

    no_show =
      Fixtures.appointment!(fixture,
        patient_profile_id: fixture.other_patient_id,
        start_time: DateTime.add(DateTime.utc_now(), 7200, :second),
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(attended.id),
      "outcome" => "attended"
    })

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(no_show.id),
      "outcome" => "no_show"
    })

    assert Repo.get!(Appointment, attended.id).status == "attended"
    assert Repo.get!(Appointment, no_show.id).status == "no_show"

    assert {:ok, history} = Booking.list_appointment_history(principal)
    assert Enum.map(history, & &1.status) == ["attended", "no_show"]
  end

  test "rejects attendance for requested and expired appointments without mutation", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    requested =
      Fixtures.appointment!(fixture,
        patient_profile_id: fixture.other_patient_id,
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "requested"
      )

    expired =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
        status: "expired"
      )

    {:ok, view, _html} = live(conn, ~p"/profesional/agenda")
    {:ok, before} = Booking.list_appointment_history(principal)

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(requested.id),
      "outcome" => "attended"
    })

    render_click(view, "record_attendance", %{
      "appointment_id" => to_string(expired.id),
      "outcome" => "no_show"
    })

    assert Repo.get!(Appointment, requested.id).status == "requested"
    assert Repo.get!(Appointment, expired.id).status == "expired"
    assert {:ok, after_attempts} = Booking.list_appointment_history(principal)
    assert after_attempts == before
  end

  test "forged foreign appointment id cannot mutate or leak another agenda history", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    own =
      Fixtures.appointment!(fixture,
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "confirmed"
      )

    foreign =
      Fixtures.appointment!(fixture,
        professional_account_id: fixture.other_professional_id,
        start_time: DateTime.add(DateTime.utc_now(), 7200, :second),
        status: "confirmed"
      )

    {:ok, view, html} = live(conn, ~p"/profesional/agenda")
    refute html =~ "##{foreign.id}"
    {:ok, before} = Booking.list_appointment_history(principal)

    html =
      render_click(view, "submit_cancellation", %{
        "appointment_id" => to_string(foreign.id),
        "cancellation" => %{"reason" => "Motivo forjado"}
      })

    assert html =~ "No tenés permiso para operar este turno."
    assert Repo.get!(Appointment, foreign.id).status == "confirmed"
    assert Repo.get!(Appointment, own.id).status == "confirmed"
    assert {:ok, after_attempt} = Booking.list_appointment_history(principal)
    assert after_attempt == before
    refute render(view) =~ "Motivo forjado"
  end
end
