defmodule OrigenWeb.PatientPhoneVerificationLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona, PhoneVerificationChallenge}
  alias Origen.Repo

  @valid_email "paciente_live@example.test"
  @valid_phone "+5491133445566"
  @fixed_code "849201"

  setup %{conn: conn} do
    Repo.delete_all(PhoneVerificationChallenge)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    {:ok, %{profile: profile}} =
      Patients.complete_profile(@valid_email, %{
        first_name: "Mariana",
        last_name: "Pérez",
        document_type: "dni",
        document_number: "36123456",
        birthdate: ~D[1992-04-15],
        phone: @valid_phone
      })

    # Autenticar la sesión con el email del paciente
    authed_conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, @valid_email)

    %{conn: authed_conn, profile: profile}
  end

  describe "mount/3 and rendering" do
    test "renders phone verification screen with masked phone and input", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/patient/phone/verify")

      assert html =~ "Verificar Teléfono"
      assert html =~ "+54...5566"
      assert html =~ "Código de 6 dígitos"
      assert html =~ "Verificar Código"
      assert html =~ "Reenviar nuevo código a mi correo"
    end
  end

  describe "real-time validation (phx-change)" do
    test "filters out non-numeric characters and limits to 6 digits", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/phone/verify")

      html =
        view
        |> form("#phone-verification-form", verification: %{"code" => "12ab34cd5678"})
        |> render_change()

      assert html =~ "value=\"123456\""
    end
  end

  describe "verification submission (phx-submit)" do
    test "submits correct code, consumes challenge, and displays success state", %{
      conn: conn,
      profile: profile
    } do
      {:ok, _} = Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)

      {:ok, view, _html} = live(conn, ~p"/patient/phone/verify")

      html =
        view
        |> form("#phone-verification-form", verification: %{"code" => @fixed_code})
        |> render_submit()

      assert html =~ "¡Teléfono Verificado!"
      assert html =~ "Perfil Habilitado para Reservas"
      assert html =~ "Volver a Mi Perfil"

      # Corroborar en base de datos
      updated_profile = Repo.get!(PatientProfile, profile.id)
      assert updated_profile.phone_verified == true
    end

    test "shows friendly error when code is incorrect", %{conn: conn, profile: profile} do
      {:ok, _} = Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)

      {:ok, view, _html} = live(conn, ~p"/patient/phone/verify")

      html =
        view
        |> form("#phone-verification-form", verification: %{"code" => "000000"})
        |> render_submit()

      assert html =~ "El código ingresado es incorrecto"
    end

    test "locks the form when maximum 3 attempts are exceeded", %{
      conn: conn,
      profile: profile
    } do
      {:ok, _} = Patients.request_phone_verification(profile, @valid_phone, code: @fixed_code)

      {:ok, view, _html} = live(conn, ~p"/patient/phone/verify")

      view
      |> form("#phone-verification-form", verification: %{"code" => "111111"})
      |> render_submit()

      view
      |> form("#phone-verification-form", verification: %{"code" => "222222"})
      |> render_submit()

      html =
        view
        |> form("#phone-verification-form", verification: %{"code" => "333333"})
        |> render_submit()

      assert html =~ "Superaste el límite de 3 intentos fallidos"
      assert html =~ "disabled"
    end
  end

  describe "resend code (phx-click)" do
    test "requests a new challenge and displays info message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/phone/verify")

      html = view |> element("button", "Reenviar nuevo código a mi correo") |> render_click()

      assert html =~ "Nuevo código de 6 dígitos enviado a tu correo"
    end
  end
end
