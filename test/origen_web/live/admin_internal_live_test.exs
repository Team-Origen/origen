defmodule OrigenWeb.AdminInternalLiveTest do
  @moduledoc """
  Tests for the AdminInternalLive LiveView.

  Tests cover:
  - Mount with current_user
  - Form validation (real-time)
  - Form submission (save)
  - Role-based access control
  """

  use OrigenWeb.LiveViewCase

  describe "mount/3" do
    test "renders the form with role and email fields", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/admin/internal")

      assert html =~ "Crear Cuenta Demo"
      assert html =~ "Rol"
      assert html =~ "Correo electrónico"
      assert html =~ "Crear Cuenta"
    end

    test "shows both professional and secretary options for administrator", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/admin/internal")

      assert html =~ "Profesional"
      assert html =~ "Secretaria"
    end

    test "shows only secretary option for non-administrator", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 2, role: :secretary})

      {:ok, _view, html} = live(conn, ~p"/admin/internal")

      assert html =~ "Secretaria"
      refute html =~ "Profesional"
    end
  end

  describe "authorization" do
    test "redirects away without rendering the screen when there is no session", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/internal")
    end

    test "redirects away for a role that is neither administrator nor secretary", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 3, role: :professional})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/internal")
    end

    test "redirects away for a patient session", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 4, role: :patient})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/internal")
    end
  end

  describe "validate event" do
    test "shows validation error for invalid email", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_change()

      assert html =~ "must be a valid email address without spaces"
    end

    test "shows validation error for missing role", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "", email: "test@example.com"})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation error for missing email", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "clears validation errors when input is corrected", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_change()

      assert html =~ "must be a valid email address without spaces"

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "valid@example.com"})
        |> render_change()

      refute html =~ "must be a valid email address without spaces"
    end
  end

  describe "save event" do
    test "shows success result on valid submission", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "demo@example.com"})
        |> render_submit()

      assert html =~ "Cuenta creada exitosamente"
      assert html =~ "demo@example.com"
      assert html =~ "Profesional"
    end

    test "shows validation errors on invalid submission", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "", email: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation error for invalid email on submission", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_submit()

      assert html =~ "must be a valid email address without spaces"
    end
  end

  describe "teclado y foco" do
    # LiveView solo preserva el foco del navegador entre re-renders si el DOM
    # patchea el mismo nodo (mismo id) en vez de reemplazarlo. Verificar la
    # verificación real de foco en el navegador requeriría una herramienta de
    # pruebas end-to-end (Wallaby/Playwright) que este proyecto todavía no
    # tiene configurada; estos tests son la evidencia disponible sin esa
    # infraestructura: los inputs no cambian de id y el valor ya tipeado no
    # se pierde cuando otro campo es inválido.
    test "role and email inputs keep stable DOM ids across a validation re-render", %{
      conn: conn
    } do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, html} = live(conn, ~p"/admin/internal")
      assert html =~ ~s(id="form_role")
      assert html =~ ~s(id="form_email")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_change()

      assert html =~ ~s(id="form_role")
      assert html =~ ~s(id="form_email")
    end

    test "keeps the typed email value visible when the role selection is what fails validation",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/admin/internal")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "", email: "person@example.com"})
        |> render_change()

      assert html =~ "person@example.com"
    end
  end

  describe "styling" do
    test "form container has specified styling", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/admin/internal")

      assert html =~ "bg-white"
      assert html =~ "border-[#E2E8F0]"
      assert html =~ "shadow-[0px_4px_12px_rgba(23,75,99,0.05)]"
      assert html =~ "font-inter"
    end

    test "inputs have specified styling", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/admin/internal")

      assert html =~ "py-[12px]"
      assert html =~ "px-[16px]"
      assert html =~ "rounded-md"
      assert html =~ "focus:ring-2"
      assert html =~ "focus:ring-[#174B63]"
      assert html =~ "focus:border-[#174B63]"
    end

    test "submit button has specified styling", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/admin/internal")

      assert html =~ "bg-[#174B63]"
      assert html =~ "text-white"
      assert html =~ "h-[44px]"
      assert html =~ "px-6"
      assert html =~ "rounded-md"
    end
  end

  defp put_user_in_session(conn, user) do
    session_user = Map.new(user, fn {k, v} -> {to_string(k), v} end)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user, session_user)
  end
end
