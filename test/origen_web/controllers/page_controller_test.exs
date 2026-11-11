defmodule OrigenWeb.PageControllerTest do
  use OrigenWeb.ConnCase
  @moduletag :skip_db

  test "staff access is a normal link and preserves both patient home states", %{conn: conn} do
    for email <- [nil, "patient@example.test"] do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{patient_email: email})
        |> get(~p"/")

      document = conn |> html_response(200) |> LazyHTML.from_document()
      link = LazyHTML.query(document, ~s(a#staff-access-link[href="/login"]))
      assert LazyHTML.text(link) =~ "Acceso del personal"
      assert LazyHTML.attribute(link, "data-phx-link") == []
      assert Plug.Conn.get_session(conn, :patient_email) == email

      if email do
        assert LazyHTML.text(document) =~ "Mis turnos"
        assert LazyHTML.text(document) =~ "Solicitar otro enlace o cambiar de cuenta"
      else
        assert LazyHTML.text(document) =~ "Ingresar con mi correo"
      end
    end
  end

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
