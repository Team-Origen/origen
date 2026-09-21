defmodule OrigenWeb.PatientAccessLiveTest do
  use OrigenWeb.ConnCase
  import Phoenix.LiveViewTest

  @moduletag :skip_db

  describe "mount/3 and initial rendering" do
    test "renders the access form with email input and submit button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/access")

      assert html =~ "Acceso para Pacientes"
      assert html =~ "Correo electrónico"
      assert html =~ "Enviar enlace de acceso"
      assert html =~ ~s(type="email")
    end
  end

  describe "real-time validation (phx-change)" do
    test "shows validation error when email is blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      html =
        view
        |> form("#patient-access-form", access: %{email: ""})
        |> render_change()

      assert html =~ "no puede estar en blanco"
    end

    test "shows validation error when email format is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      html =
        view
        |> form("#patient-access-form", access: %{email: "paciente-invalido"})
        |> render_change()

      assert html =~ "debe ser un correo electrónico válido"
    end

    test "shows validation error when email contains whitespace", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      html =
        view
        |> form("#patient-access-form", access: %{email: "paciente @example.com"})
        |> render_change()

      assert html =~ "debe ser un correo electrónico válido"
    end

    test "clears validation error when valid email is provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      # First trigger invalid
      view
      |> form("#patient-access-form", access: %{email: "invalido"})
      |> render_change()

      # Then provide valid
      html =
        view
        |> form("#patient-access-form", access: %{email: "paciente@example.test"})
        |> render_change()

      refute html =~ "debe ser un correo electrónico válido"
    end
  end

  describe "form submission (phx-submit)" do
    test "does not submit when email is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      html =
        view
        |> form("#patient-access-form", access: %{email: "invalido"})
        |> render_submit()

      assert html =~ "debe ser un correo electrónico válido"
      refute html =~ "Revisá tu casilla de correo"
    end

    test "shows non-enumerating confirmation message on valid submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      html =
        view
        |> form("#patient-access-form", access: %{email: "paciente@example.test"})
        |> render_submit()

      # Security: Non-enumerating response
      assert html =~ "Revisá tu casilla de correo"
      assert html =~ "Si el correo ingresado corresponde a un paciente registrado"
      assert html =~ "enviamos un enlace de acceso"
      # Option to return or re-enter email
      assert html =~ "Ingresar otro correo"
    end

    test "allows returning to the form to enter another email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/access")

      # Submit valid email
      view
      |> form("#patient-access-form", access: %{email: "paciente@example.test"})
      |> render_submit()

      # Click to enter another email / reset
      html =
        view
        |> element("#reset-access-button")
        |> render_click()

      # Form is visible again
      assert html =~ "Acceso para Pacientes"
      assert html =~ "Enviar enlace de acceso"
      refute html =~ "Revisá tu casilla de correo"
    end
  end
end
