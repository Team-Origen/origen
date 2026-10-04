defmodule OrigenWeb.PageControllerTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Public routes" do
    @tag :skip_db
    test "GET / is publicly accessible", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200)
    end

    @tag :skip_db
    test "GET /login requires TLS and renders form over HTTPS", %{conn: conn} do
      conn = get(conn, https("/login"))
      assert html_response(conn, 200) =~ "Iniciar sesión"
    end

    @tag :skip_db
    test "GET /login over insecure HTTP fails closed with 404", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert response(conn, 404) =~ "Authentication unavailable"
    end
  end

  describe "Protected pipelines: /profesional" do
    test "rejects unauthenticated requests with 401 Unauthorized", %{conn: conn} do
      conn = get(conn, ~p"/profesional/agenda")
      assert response(conn, 401) =~ "Unauthorized"
    end

    test "rejects authenticated non-professional accounts with 403 Forbidden", %{conn: conn} do
      conn =
        conn
        |> log_in_internal_account(insert_active_internal_account!(:secretary))
        |> get(~p"/profesional/agenda")

      assert response(conn, 403) =~ "Forbidden"
    end

    test "admits authenticated professional accounts", %{conn: conn} do
      conn =
        conn
        |> log_in_internal_account(insert_active_internal_account!(:professional))
        |> get(~p"/profesional/agenda")

      assert html_response(conn, 200) =~ "Agenda Diaria"
    end
  end

  describe "Internal LiveView authentication gating" do
    test "unauthenticated access to /secretaria/pacientes redirects to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/secretaria/pacientes")
    end

    test "unauthenticated access to /admin/internal redirects to /", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/internal")
    end
  end

  defp https(path), do: "https://www.example.com" <> path

  defp insert_active_internal_account!(role) do
    %{rows: [[account_id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: account_id, role: role, state: :active}
  end
end
