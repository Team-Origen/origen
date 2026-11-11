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

  @tag :timezone_integrity
  test "daily agenda and history show the same organization-local appointment time", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    previous_timezone = Application.fetch_env!(:origen, :organization_timezone)
    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous_timezone) end)

    agenda_date = ~D[2026-11-10]
    stored_start = ~U[2026-11-10 15:30:00Z]

    appointment =
      Fixtures.appointment!(fixture,
        start_time: stored_start,
        status: "requested"
      )

    assert {:ok, before_history} = Booking.list_appointment_history(principal)
    assert [%{id: appointment_id, start_time: persisted_start}] = before_history
    assert appointment_id == appointment.id
    assert DateTime.compare(persisted_start, stored_start) == :eq

    for {timezone, expected_start, expected_end} <- [
          {"Etc/UTC", "15:30", "16:00"},
          {"America/Argentina/Buenos_Aires", "12:30", "13:00"}
        ] do
      Application.put_env(:origen, :organization_timezone, timezone)

      {:ok, view, _html} =
        live(conn, ~p"/profesional/agenda?date=#{Date.to_iso8601(agenda_date)}")

      daily_card = view |> element("#appointment-#{appointment.id}") |> render()

      history_card =
        view |> element("#professional-history-appointment-#{appointment.id}") |> render()

      assert daily_card =~ "#{expected_start} - #{expected_end}"
      assert history_card =~ expected_start
      assert history_card =~ expected_end

      if timezone == "America/Argentina/Buenos_Aires" do
        refute daily_card =~ "15:30 - 16:00"
        refute history_card =~ "15:30"
      end
    end

    assert {:ok, after_history} = Booking.list_appointment_history(principal)
    assert after_history == before_history
  end

  @tag :cancellation_details_contrast
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

    {:ok, view, html} = live(conn, ~p"/profesional/agenda")

    for text <- ["Origen:", "Profesional", "Motivo:", "Guardia reprogramada"] do
      assert has_element?(
               view,
               "#professional-history-appointment-#{cancelled.id} > div.text-stone-900",
               text
             )
    end

    assert html =~ "Historial operativo"
    assert html =~ "Vencido"
    assert html =~ "Cancelado"
    assert html =~ "Origen:"
    assert html =~ "Profesional"
    assert html =~ "Motivo:"
    assert html =~ "Guardia reprogramada"
    assert has_element?(view, "#professional-history-appointment-#{expired.id}", "Vencido")
    assert has_element?(view, "#professional-history-appointment-#{cancelled.id}", "Cancelado")

    refute element(view, "#professional-history-appointment-#{expired.id}") |> render() =~
             "Turno #{expired.id}"

    refute element(view, "#professional-history-appointment-#{cancelled.id}") |> render() =~
             "Turno #{cancelled.id}"

    assert {:ok, history} = Booking.list_appointment_history(principal)
    assert Enum.map(history, & &1.id) == [expired.id, cancelled.id]
  end

  test "requires a reason and preserves history when staff cancellation is rejected", %{
    fixture: fixture,
    conn: conn,
    principal: principal
  } do
    agenda_date = ~D[2099-01-15]
    appointment_start = DateTime.new!(agenda_date, ~T[09:00:00], "Etc/UTC")

    appointment =
      Fixtures.appointment!(fixture,
        start_time: appointment_start,
        status: "requested"
      )

    {:ok, view, _html} =
      live(conn, ~p"/profesional/agenda?date=#{Date.to_iso8601(agenda_date)}")

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
    agenda_date = ~D[2099-01-15]
    requested_start = DateTime.new!(agenda_date, ~T[09:00:00], "Etc/UTC")
    confirmed_start = DateTime.new!(agenda_date, ~T[10:00:00], "Etc/UTC")

    requested =
      Fixtures.appointment!(fixture,
        start_time: requested_start,
        status: "requested"
      )

    confirmed =
      Fixtures.appointment!(fixture,
        patient_profile_id: fixture.other_patient_id,
        start_time: confirmed_start,
        status: "confirmed"
      )

    {:ok, view, _html} =
      live(conn, ~p"/profesional/agenda?date=#{Date.to_iso8601(agenda_date)}")

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

  test "renders cancellation reasons with explicit light control colors for professional and secretary",
       %{
         fixture: fixture,
         conn: conn
       } do
    professional_date = Date.utc_today()

    professional_appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.new!(professional_date, ~T[09:00:00], "Etc/UTC"),
        status: "requested"
      )

    {:ok, professional_view, _html} = live(conn, "/profesional/agenda")

    professional_view
    |> element("#cancel-appointment-#{professional_appointment.id}")
    |> render_click()

    professional_html = render(professional_view)

    assert professional_html =~
             ~r/id="cancellation-reason-#{professional_appointment.id}"[^>]*class="[^\"]*bg-white[^\"]*text-stone-900[^\"]*placeholder:text-stone-500/s

    secretary_date =
      DateTime.now!(Application.fetch_env!(:origen, :organization_timezone)) |> DateTime.to_date()

    secretary_appointment =
      Fixtures.appointment!(fixture,
        start_time:
          DateTime.new!(
            secretary_date,
            ~T[11:00:00],
            Application.fetch_env!(:origen, :organization_timezone)
          ),
        status: "requested"
      )

    secretary = Fixtures.secretary_principal(fixture)

    secretary_conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:internal_session_token, secretary.token)

    {:ok, secretary_view, _html} = live(secretary_conn, "/secretaria/agenda")

    secretary_view
    |> element("#cancel-appointment-#{secretary_appointment.id}")
    |> render_click()

    secretary_html = render(secretary_view)

    assert secretary_html =~
             ~r/id="cancellation-reason-#{secretary_appointment.id}"[^>]*class="[^\"]*bg-white[^\"]*text-stone-900[^\"]*placeholder:text-stone-500/s
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

    {:ok, view, _html} = live(conn, ~p"/profesional/agenda")
    refute has_element?(view, "#appointment-#{foreign.id}")
    refute has_element?(view, "#professional-history-appointment-#{foreign.id}")
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
