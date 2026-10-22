defmodule OrigenWeb.ProfessionalProfileLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  @path "/configuracion/profesional/perfil"
  @fields ~w(first_name last_name specialty licence_type licence_number)
  @complete %{
    "first_name" => "Profesional",
    "last_name" => "de muestra",
    "specialty" => "Clínica",
    "licence_type" => "Provincial / ejemplo",
    "licence_number" => "AB-001/26"
  }

  setup %{conn: conn} do
    {:ok, conn: log_in_internal_account(conn, account!(:professional))}
  end

  test "settings links to the explicitly simulated profile without replacing existing settings",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/configuracion/profesional")
    assert has_element?(view, "#professional-profile-entry", "Datos simulados")
    assert has_element?(view, ~s|a[href="#{@path}"]|, "Editar perfil")
    assert has_element?(view, "#profile-patient-name", "Nombre de muestra Apellido de muestra")
    assert has_element?(view, "#profile-patient-specialty", "Especialidad pendiente")
    assert has_element?(view, "#agenda-interval-heading")
    assert has_element?(view, "#weekly-availability-heading")
  end

  test "settings shows a complete patient-facing sample and edits the same data", %{conn: conn} do
    {:ok, view, _} = live(conn, "/configuracion/profesional?scenario=complete")
    assert has_element?(view, "#profile-patient-preview", "Nombre de muestra Apellido de muestra")
    assert has_element?(view, "#profile-patient-preview", "Especialidad de muestra")
    refute has_element?(view, "#profile-patient-preview", "Tipo de muestra")
    refute has_element?(view, "#profile-patient-preview", "DEMO-001")
    assert has_element?(view, "#profile-entry-status", "Perfil completo")
    refute has_element?(view, "#professional-profile-entry a", "Completar perfil")
    assert has_element?(view, ~s|a[href="#{@path}?scenario=complete"]|, "Editar perfil")

    view |> element(~s|a[href="#{@path}?scenario=complete"]|) |> render_click()
    assert_redirect(view, @path <> "?scenario=complete")
    editor = open_profile(conn, "?scenario=complete")
    assert has_element?(editor, ~s|#profile-specialty[value="Especialidad de muestra"]|)
    assert has_element?(editor, "#profile-status", "Perfil completo")
  end

  test "settings shows missing values without inventing patient-facing data", %{conn: conn} do
    {:ok, view, _} = live(conn, "/configuracion/profesional?scenario=empty")
    assert has_element?(view, "#profile-patient-name", "Nombre y apellido pendientes")
    assert has_element?(view, "#profile-patient-specialty", "Especialidad pendiente")
    assert has_element?(view, "#profile-entry-status", "Perfil incompleto")
    assert has_element?(view, "#profile-entry-status", "no aparece")
    assert has_element?(view, ~s|a[href="#{@path}?scenario=empty"]|, "Completar perfil")
    refute has_element?(view, "#professional-profile-entry a", "Editar perfil")
  end

  test "an existing partial profile is editable while its patient projection remains ineligible",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/configuracion/profesional")
    assert has_element?(view, "#profile-entry-status", "Perfil incompleto")
    assert has_element?(view, "#profile-entry-status", "Especialidad")
    assert has_element?(view, "#profile-entry-status", "Tipo de matrícula")
    assert has_element?(view, "#profile-entry-status", "Número de matrícula")
    assert has_element?(view, "#professional-profile-entry a", "Editar perfil")
    refute has_element?(view, "#profile-patient-preview", "Tipo de matrícula")
    refute has_element?(view, "#profile-patient-preview", "Número de matrícula")
  end

  test "a sample load failure does not invent an empty profile or expose an edit action", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/configuracion/profesional?scenario=load-error")
    assert has_element?(view, "#profile-entry-error[role=alert]", "No se pudo cargar")
    refute has_element?(view, "#profile-patient-preview")
    refute has_element?(view, "#professional-profile-entry a", "Editar perfil")
    refute has_element?(view, "#professional-profile-entry a", "Completar perfil")
    assert has_element?(view, "#weekly-availability-heading")
    assert has_element?(view, "#agenda-interval-heading")
  end

  test "server rejects anonymous and wrong-role profile access" do
    assert build_conn() |> get(@path) |> response(401) == "Unauthorized"

    for role <- [:administrator, :secretary] do
      conn = build_conn() |> log_in_internal_account(account!(role)) |> get(@path)
      assert response(conn, 403) == "Forbidden"
    end
  end

  test "loads a fictional incomplete profile, accessible fields and optional photo", %{conn: conn} do
    {:ok, view, html} = live(conn, @path)
    assert html =~ "Cargando perfil"
    render_async(view)
    assert has_element?(view, "#profile-preview-notice", "no se guardan de forma permanente")
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    assert has_element?(view, "#profile-status", "Especialidad")
    assert has_element?(view, "#profile-status", "seguir preparando tus ajustes")

    for field <- @fields do
      assert has_element?(view, ~s|input#profile-#{field}[type="text"]|)
    end

    assert has_element?(view, "#profile-photo", "opcional")
    refute has_element?(view, ~s|input[type="file"]|)
    refute has_element?(view, "select[name='profile[licence_type]']")
    assert has_element?(view, ~s|a[href="/configuracion/profesional"]|, "Volver a Ajustes")
  end

  test "partial saves succeed and completeness follows saved data, not the unsaved draft", %{
    conn: conn
  } do
    view = open_profile(conn)
    form(view, "#profile-form", profile: @complete) |> render_change()
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    submit(view, @complete)
    assert has_element?(view, "#profile-status", "Perfil completo")
    assert has_element?(view, "#profile-save-success[role=status]", "Cambios simulados")
    assert has_element?(view, ~s|#profile-licence_number[value="AB-001/26"]|)

    submit(view, Map.put(@complete, "specialty", ""))
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    assert has_element?(view, "#profile-missing-fields", "Especialidad")
    assert has_element?(view, "#profile-save-success")
    assert has_element?(view, ~s|#profile-specialty[aria-describedby="profile-specialty-help"]|)
    refute has_element?(view, "#profile-save-error")
  end

  for field <- @fields do
    test "a blank #{field} may be saved but keeps the profile incomplete", %{conn: conn} do
      view = open_profile(conn)
      submit(view, Map.put(@complete, unquote(field), "   "))
      assert has_element?(view, "#profile-status", "Perfil incompleto")
      assert has_element?(view, "#profile-missing-#{unquote(field)}")
      assert has_element?(view, "#profile-save-success")
    end
  end

  test "complete fixture without photo does not promise available appointments", %{conn: conn} do
    view = open_profile(conn, "?scenario=complete")
    assert has_element?(view, "#profile-status", "Perfil completo")
    assert has_element?(view, "#profile-status", "no garantiza horarios disponibles")
    refute has_element?(view, "#profile-missing-fields")
  end

  test "cancel restores last saved draft and a new visit restores the initial fixture", %{
    conn: conn
  } do
    view = open_profile(conn)
    submit(view, @complete)

    form(view, "#profile-form", profile: Map.put(@complete, "first_name", "Sin guardar"))
    |> render_change()

    view |> element("#profile-cancel") |> render_click()
    assert has_element?(view, ~s|#profile-first_name[value="Profesional"]|)
    assert has_element?(view, "#profile-status", "Perfil completo")
    refute has_element?(view, "#profile-save-success")

    new_view = open_profile(conn)
    assert has_element?(new_view, "#profile-status", "Perfil incompleto")
    assert has_element?(new_view, ~s|#profile-first_name[value="Nombre de muestra"]|)
  end

  test "load failure hides the form and offers a fresh sample", %{conn: conn} do
    view = open_profile(conn, "?scenario=load-error")
    assert has_element?(view, "#profile-load-error[role=alert]", "No se pudo cargar")
    refute has_element?(view, "#profile-form")
    assert has_element?(view, ~s|#profile-retry[href="#{@path}"]|)
  end

  test "save failure preserves the draft and the previous completeness status", %{conn: conn} do
    view = open_profile(conn, "?scenario=save-error")
    submit(view, @complete)
    assert has_element?(view, "#profile-save-error[role=alert]", "No se pudo guardar")
    assert has_element?(view, ~s|#profile-first_name[value="Profesional"]|)
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    refute has_element?(view, "#profile-save-success")
  end

  defp open_profile(conn, suffix \\ "") do
    {:ok, view, _} = live(conn, @path <> suffix)
    render_async(view)
    view
  end

  defp submit(view, params), do: view |> form("#profile-form", profile: params) |> render_submit()

  defp account!(role) do
    %{rows: [[id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: id, role: role, state: :active}
  end
end
