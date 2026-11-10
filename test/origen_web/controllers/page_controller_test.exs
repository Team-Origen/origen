defmodule OrigenWeb.PageControllerTest do
  use OrigenWeb.ConnCase
  @moduletag :skip_db

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
  end

  test "the authenticated patient home links to the functional appointments page", %{conn: conn} do
    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, "patient@example.test")

    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(href="/paciente/turnos")
    assert html =~ "Mis turnos"
    refute html =~ "sección pendiente"
  end
end
