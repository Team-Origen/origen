defmodule OrigenWeb.PatientNavigationTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Repo
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    fixture = Fixtures.create!()

    email =
      Repo.query!("SELECT email FROM patient_profiles WHERE id = $1", [fixture.patient_id]).rows
      |> hd()
      |> hd()

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, email)
      |> Plug.Conn.put_session(:patient_authenticated_at, DateTime.to_iso8601(DateTime.utc_now()))

    %{conn: conn}
  end

  test "patient booking navigation opens the functional appointments screen", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/paciente/turnos/reservar")

    assert html =~ "Mis turnos"
    assert has_element?(view, "#role-navigation")
    assert has_element?(view, "#nav-turns[href='/paciente/turnos']", "Mis turnos")

    assert has_element?(
             view,
             "#navigation-account-menu form[action='/paciente/cerrar-sesion'][method='post']"
           )

    view
    |> element("#nav-turns[href='/paciente/turnos']")
    |> render_click()

    assert_redirect(view, ~p"/paciente/turnos")
    {:ok, _history_view, history_html} = live(conn, ~p"/paciente/turnos")
    assert history_html =~ "Mis turnos"
  end
end
