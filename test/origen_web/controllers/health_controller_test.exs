defmodule OrigenWeb.HealthControllerTest do
  use OrigenWeb.ConnCase

  test "GET /health returns a minimal healthy response without authentication", %{conn: conn} do
    conn = get(conn, "/health")

    assert response(conn, 200) == "ok"
  end

  @tag :skip_db
  test "GET /health returns a generic 503 when database checkout has no sandbox owner", %{
    conn: conn
  } do
    conn = get(conn, "/health")

    assert response(conn, 503) == "unavailable"
  end
end
