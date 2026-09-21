defmodule OrigenWeb.PatientProfileCompletionLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @valid_form %{
    "first_name" => "Carlos",
    "last_name" => "López",
    "document_type" => "dni",
    "document_number" => "35.987.654",
    "birthdate" => "1988-07-20",
    "phone" => "+5491144332211"
  }

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)
    :ok
  end

  describe "mount/3 and initial rendering" do
    test "renders the profile completion form with all required fields", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/patient/profile/complete")

      assert html =~ "Completar Perfil"
      assert html =~ "Nombres"
      assert html =~ "Apellidos"
      assert html =~ "Tipo de documento"
      assert html =~ "Número de documento"
      assert html =~ "Fecha de nacimiento"
      assert html =~ "Guardar y Completar Perfil"
    end
  end

  describe "real-time validation (phx-change)" do
    test "validates required fields on blur/change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/profile/complete")

      html =
        view
        |> form("#patient-profile-form", profile: %{"first_name" => ""})
        |> render_change()

      assert html =~ "no puede estar en blanco"
    end

    test "rejects future birthdate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/profile/complete")

      tomorrow = Date.add(Date.utc_today(), 1) |> Date.to_iso8601()

      html =
        view
        |> form("#patient-profile-form", profile: Map.put(@valid_form, "birthdate", tomorrow))
        |> render_change()

      assert html =~ "debe ser una fecha en el pasado"
    end

    test "validates DNI requires numeric format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/profile/complete")

      html =
        view
        |> form("#patient-profile-form",
          profile:
            Map.merge(@valid_form, %{"document_type" => "dni", "document_number" => "38123abc"})
        )
        |> render_change()

      assert html =~ "el DNI debe contener solo números"
    end
  end

  describe "form submission (phx-submit)" do
    test "completes profile successfully and displays completed outcome view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/profile/complete")

      html =
        view
        |> form("#patient-profile-form", profile: @valid_form)
        |> render_submit()

      assert html =~ "¡Perfil Completado!"
      assert html =~ "Datos obligatorios completos"
      assert html =~ "Pendiente de verificación"
      assert html =~ "Ir al inicio"
      refute html =~ "Verificación de Identidad Requerida"
    end

    test "handles document collision gracefully by showing derivation to Secretary", %{conn: conn} do
      # 1. First persona exists in the system
      {:ok, _} =
        Patients.complete_profile("otro_paciente@example.test", %{
          first_name: "Original",
          last_name: "User",
          document_type: "dni",
          document_number: "35987654",
          birthdate: ~D[1985-01-01]
        })

      # 2. Patient in LiveView submits the SAME document
      {:ok, view, _html} = live(conn, ~p"/patient/profile/complete")

      html =
        view
        |> form("#patient-profile-form", profile: @valid_form)
        |> render_submit()

      assert html =~ "Verificación de Identidad Requerida"
      assert html =~ "El documento ingresado ya se encuentra registrado en nuestro sistema"
      assert html =~ "tu solicitud fue derivada al equipo de Secretaría"
      assert html =~ "Volver al inicio"
      refute html =~ "¡Perfil Completado!"
    end
  end
end
