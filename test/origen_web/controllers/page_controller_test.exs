defmodule OrigenWeb.PageControllerTest do
  use OrigenWeb.ConnCase
  @moduletag :skip_db

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
  end
end
