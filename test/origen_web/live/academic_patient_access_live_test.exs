defmodule OrigenWeb.AcademicPatientAccessLiveTest do
  use OrigenWeb.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  setup do
    old = Application.get_env(:origen, :academic_patient_access)
    on_exit(fn -> Application.put_env(:origen, :academic_patient_access, old) end)

    Application.put_env(:origen, :academic_patient_access,
      enabled: true,
      isolated_fictional_data_confirmed: true,
      public_origin: "https://evaluation.example.test"
    )

    {:ok, _} = Origen.Patients.get_or_create_profile("academic-ui@example.test")
    :ok
  end

  test "registered patient gets transient readonly copy/open result", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/paciente/acceso")
    refute has_element?(view, "#academic-access")

    view
    |> form("#patient-access-form", access: %{email: "academic-ui@example.test"})
    |> render_submit()

    assert has_element?(view, "#academic-access-url[readonly][autocomplete=off]")
    assert has_element?(view, "#copy-academic-access", "Copiar enlace")

    assert has_element?(
             view,
             "#academic-access-link[target=_blank][rel='noopener noreferrer']",
             "Abrir acceso"
           )

    url =
      view
      |> element("#academic-access-url")
      |> render()
      |> LazyHTML.from_document()
      |> LazyHTML.query("input")
      |> LazyHTML.attribute("value")
      |> hd()

    assert String.starts_with?(
             url,
             "https://evaluation.example.test/paciente/acceso/verificar?token="
           )

    refute_email_sent()
    token = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("token")
    response = get(build_conn(), ~p"/paciente/acceso/verificar", token: token)
    assert get_session(response, :patient_email) == "academic-ui@example.test"
    view |> element("#reset-access-button") |> render_click()
    refute has_element?(view, "#academic-access")
    {:ok, reloaded, _} = live(conn, ~p"/paciente/acceso")
    refute has_element?(reloaded, "#academic-access")
  end

  test "unknown email produces no link or patient", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/paciente/acceso")

    view
    |> form("#patient-access-form", access: %{email: "unknown-ui@example.test"})
    |> render_submit()

    refute has_element?(view, "#academic-access")
    refute Origen.Repo.get_by(Origen.Patients.PatientProfile, email: "unknown-ui@example.test")
    refute_email_sent()
  end

  test "disabled mode preserves opaque email flow for registered and unknown", %{conn: conn} do
    Application.put_env(:origen, :academic_patient_access, enabled: false)

    for email <- ["academic-ui@example.test", "unknown-ui@example.test"] do
      {:ok, view, _} = live(conn, ~p"/paciente/acceso")
      view |> form("#patient-access-form", access: %{email: email}) |> render_submit()
      assert has_element?(view, "h2", "Revisá tu casilla de correo")
      refute has_element?(view, "#academic-access")
    end

    assert_email_sent()
  end
end
