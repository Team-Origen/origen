defmodule OrigenWeb.AppointmentSessionIsolationTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking.Appointment
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  test "third-party attendance keeps patient and professional LiveViews authenticated", %{
    conn: base_conn
  } do
    fixture = Fixtures.create!()
    professional = Fixtures.professional_principal(fixture)
    secretary = Fixtures.secretary_principal(fixture)
    patient = Fixtures.patient_principal(fixture)
    organization_timezone = Application.fetch_env!(:origen, :organization_timezone)
    organization_date = DateTime.now!(organization_timezone) |> DateTime.to_date()

    appointment_start = DateTime.new!(organization_date, ~T[10:00:00], organization_timezone)

    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.shift_zone!(appointment_start, "Etc/UTC"),
        status: "confirmed"
      )

    patient_conn =
      base_conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, patient.patient_email)
      |> Plug.Conn.put_session(
        :patient_authenticated_at,
        DateTime.to_iso8601(patient.patient_authenticated_at)
      )

    professional_conn = internal_conn(professional.token)
    secretary_conn = internal_conn(secretary.token)

    {:ok, professional_view, _professional_html} =
      live(
        professional_conn,
        "/profesional/agenda?date=#{Date.to_iso8601(organization_date)}"
      )

    {:ok, patient_view, _patient_html} = live(patient_conn, "/paciente/turnos")
    {:ok, secretary_view, _secretary_html} = live(secretary_conn, "/secretaria/agenda")

    assert has_element?(professional_view, "#appointment-#{appointment.id}")
    assert has_element?(patient_view, "#patient-appointment-#{appointment.id}", "Confirmado")
    assert has_element?(secretary_view, "#secretary-appointment-#{appointment.id}")

    assert has_element?(
             secretary_view,
             "#secretary-appointment-#{appointment.id}",
             "Marcar asistencia"
           )

    secretary_view
    |> element("#secretary-appointment-#{appointment.id} button[phx-value-outcome='attended']")
    |> render_click()

    assert Repo.get!(Appointment, appointment.id).status == "attended"
    assert render(professional_view) =~ "Agenda Diaria"
    assert render(patient_view) =~ "Mis turnos"
    assert render(secretary_view) =~ "Agenda del centro"

    {:ok, remounted_professional, professional_html} =
      live(
        professional_conn,
        "/profesional/agenda?date=#{Date.to_iso8601(organization_date)}"
      )

    {:ok, remounted_patient, patient_html} = live(patient_conn, "/paciente/turnos")
    {:ok, _remounted_secretary, secretary_html} = live(secretary_conn, "/secretaria/agenda")

    assert professional_html =~ "Asistió"
    assert patient_html =~ "Asistió"
    assert secretary_html =~ "Asistió"
    assert render(remounted_professional) =~ "Asistió"
    assert render(remounted_patient) =~ "Asistió"

    assert {:ok, _} = Sessions.fetch_session(professional.token)
    assert {:ok, _} = Sessions.fetch_session(secretary.token)

    assert {:ok, _} =
             Origen.Patients.verify_patient_session(
               patient.patient_email,
               patient.patient_authenticated_at
             )
  end

  defp internal_conn(token) do
    build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end
end
