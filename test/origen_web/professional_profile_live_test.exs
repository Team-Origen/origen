defmodule OrigenWeb.ProfessionalProfileLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Origen.{ProfessionalProfiles, Sessions}

  @path "/configuracion/profesional/perfil"
  @fields ~w(first_name last_name specialty license_type license_number)
  @complete %{
    "first_name" => "Ana",
    "last_name" => "Pérez",
    "specialty" => "Clínica",
    "license_type" => "Provincial / libre",
    "license_number" => "AB-001/26"
  }

  defmodule UnavailableProfiles do
    def get_own_profile(_principal), do: {:error, :unavailable}
    def save_own_profile(_principal, _attrs), do: {:error, :unavailable}
  end

  defmodule RejectingSave do
    def get_own_profile(principal), do: ProfessionalProfiles.get_own_profile(principal)
    def save_own_profile(_principal, _attrs), do: {:error, :unavailable}
  end

  setup %{conn: conn} do
    previous = Application.get_env(:origen, :professional_profiles_context)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:origen, :professional_profiles_context, previous),
        else: Application.delete_env(:origen, :professional_profiles_context)
    end)

    conn = log_in_internal_account(conn, account!(:professional))
    {:ok, principal} = Sessions.touch_session(get_session(conn, :internal_session_token))
    {:ok, conn: conn, principal: principal}
  end

  test "settings loads the owner's empty real profile without replacing existing settings", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/configuracion/profesional?scenario=complete")
    refute has_element?(view, "#professional-profile-entry", "Datos simulados")
    assert has_element?(view, ~s|a[href="#{@path}"]|, "Ver perfil")
    assert has_element?(view, "#profile-patient-name", "Nombre y apellido pendientes")
    assert has_element?(view, "#profile-patient-specialty", "Especialidad pendiente")
    assert has_element?(view, "#profile-entry-status", "Perfil incompleto")
    assert has_element?(view, "#agenda-interval-heading")
    assert has_element?(view, "#weekly-availability-heading")
  end

  test "settings shows private registration beside specialty and opens the same read-only profile",
       %{
         conn: conn,
         principal: principal
       } do
    assert {:ok, _} = ProfessionalProfiles.save_own_profile(principal, @complete)
    {:ok, view, _} = live(conn, "/configuracion/profesional?scenario=empty")
    assert has_element?(view, "#profile-patient-preview", "Ana Pérez")
    assert has_element?(view, "#profile-summary-details", "Clínica")

    assert has_element?(
             view,
             "#profile-summary-details #profile-license-summary",
             "Provincial / libre"
           )

    assert has_element?(view, "#profile-summary-details #profile-license-summary", "AB-001/26")
    assert has_element?(view, "#profile-summary-details #profile-patient-specialty", "Clínica")
    refute has_element?(view, "#profile-patient-preview", "AB-001/26")
    assert has_element?(view, "#profile-entry-status", "Perfil completo")
    assert has_element?(view, ~s|a[href="#{@path}"]|, "Ver perfil")
    refute has_element?(view, "nav[aria-label='Muestras del resumen de perfil']")
    editor = open_profile(conn)
    assert has_element?(editor, ~s|#profile-specialty[value="Clínica"]|)
    assert has_element?(editor, "#profile-status", "Perfil completo")
  end

  test "partial profile remains editable and lists missing requirements without exposing credentials",
       %{conn: conn, principal: principal} do
    assert {:ok, _} = ProfessionalProfiles.save_own_profile(principal, %{"first_name" => "Ana"})
    {:ok, view, _} = live(conn, "/configuracion/profesional")
    assert has_element?(view, "#profile-patient-name", "Ana")
    assert has_element?(view, "#profile-entry-status", "Perfil incompleto")

    for label <- ["Apellido", "Especialidad", "Tipo de matrícula", "Número de matrícula"] do
      assert has_element?(view, "#profile-entry-status", label)
    end

    assert has_element?(view, "#professional-profile-entry a", "Ver perfil")
    refute has_element?(view, "#profile-patient-preview", "Tipo de matrícula")
  end

  test "profile fetch failure hides private projection but keeps settings available", %{
    conn: conn
  } do
    Application.put_env(:origen, :professional_profiles_context, UnavailableProfiles)
    {:ok, view, _} = live(conn, "/configuracion/profesional")
    assert has_element?(view, "#profile-entry-error[role=alert]", "No se pudo cargar")
    refute has_element?(view, "#profile-patient-preview")
    refute has_element?(view, "#profile-entry-action")
    assert has_element?(view, "#weekly-availability-heading")
    assert has_element?(view, "#agenda-interval-heading")
  end

  test "server rejects anonymous and wrong-role access without changing the owner's profile", %{
    principal: principal
  } do
    assert {:ok, before} = ProfessionalProfiles.save_own_profile(principal, @complete)
    assert build_conn() |> get(@path) |> response(401) == "Unauthorized"

    for role <- [:administrator, :secretary] do
      conn = build_conn() |> log_in_internal_account(account!(role)) |> get(@path)
      assert response(conn, 403) == "Forbidden"
    end

    assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(principal)
  end

  test "loads empty real fields and optional photo, ignoring former fixture selectors", %{
    conn: conn
  } do
    {:ok, view, html} = live(conn, @path <> "?scenario=complete")
    assert html =~ "Cargando perfil"
    render_async(view)
    refute has_element?(view, "#profile-preview-notice")
    refute has_element?(view, "nav[aria-label='Escenarios de muestra']")
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    assert has_element?(view, "#profile-status", "seguir preparando tus ajustes")

    refute has_element?(view, "#profile-form")
    assert has_element?(view, "#profile-edit", "Completar perfil")
    view |> element("#profile-edit") |> render_click()

    for field <- @fields do
      assert has_element?(view, ~s|input#profile-#{field}[type="text"][value=""]|)
    end

    assert has_element?(view, "#profile-photo", "opcional")
    refute has_element?(view, ~s|input[type="file"]|)
    refute has_element?(view, "select[name='profile[license_type]']")
    assert has_element?(view, ~s|a[href="/configuracion/profesional"]|, "Volver a Ajustes")
  end

  test "partial saves persist and completeness follows stored values rather than draft", %{
    conn: conn,
    principal: principal
  } do
    view = open_profile(conn)
    form(view, "#profile-form", profile: @complete) |> render_change()
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    assert {:ok, nil} = ProfessionalProfiles.get_own_profile(principal)
    submit(view, @complete)
    assert has_element?(view, "#profile-status", "Perfil completo")
    assert has_element?(view, "#profile-save-success[role=status]", "Cambios guardados")
    assert {:ok, saved} = ProfessionalProfiles.get_own_profile(principal)
    assert saved.complete?
    assert saved.license_type == @complete["license_type"]
    assert saved.license_number == @complete["license_number"]
    submit(view, Map.put(@complete, "specialty", ""))
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    assert has_element?(view, "#profile-missing-specialty")
    refute has_element?(view, "#profile-save-error")
    assert {:ok, partial} = ProfessionalProfiles.get_own_profile(principal)
    refute partial.complete?
    assert partial.specialty == nil
    assert has_element?(open_profile(conn), "#profile-status", "Perfil incompleto")
  end

  for field <- @fields do
    test "blank #{field} persists incompleteness and can be restored without a photo", %{
      conn: conn,
      principal: principal
    } do
      view = open_profile(conn)
      submit(view, Map.put(@complete, unquote(field), "   "))
      assert has_element?(view, "#profile-status", "Perfil incompleto")
      assert has_element?(view, "#profile-missing-#{unquote(field)}")
      assert has_element?(view, "#profile-save-success")
      assert {:ok, profile} = ProfessionalProfiles.get_own_profile(principal)
      refute profile.complete?
      assert Map.fetch!(profile, String.to_existing_atom(unquote(field))) == nil
      submit(view, @complete)
      assert has_element?(view, "#profile-status", "Perfil completo")
      assert has_element?(view, "#profile-status", "no garantiza horarios disponibles")
    end
  end

  test "cancel restores the saved draft and a new visit reads persisted values", %{conn: conn} do
    view = open_profile(conn)
    submit(view, @complete)
    view |> element("#profile-edit") |> render_click()

    form(view, "#profile-form", profile: Map.put(@complete, "first_name", "Sin guardar"))
    |> render_change()

    view |> element("#profile-cancel") |> render_click()
    refute has_element?(view, "#profile-form")
    assert has_element?(view, "#profile-read-first_name", "Ana")
    assert has_element?(view, "#profile-status", "Perfil completo")
    refute has_element?(view, "#profile-save-success")
    new_view = open_profile(conn)
    assert has_element?(new_view, "#profile-status", "Perfil completo")
    assert has_element?(new_view, ~s|#profile-first_name[value="Ana"]|)
  end

  test "load failure hides the form and rejects forged save events", %{
    conn: conn,
    principal: principal
  } do
    Application.put_env(:origen, :professional_profiles_context, UnavailableProfiles)
    view = open_profile(conn)
    assert has_element?(view, "#profile-load-error[role=alert]", "No se pudo cargar")
    refute has_element?(view, "#profile-form")
    assert has_element?(view, ~s|#profile-retry[href="#{@path}"]|)
    render_click(view, "save_profile", %{"profile" => @complete})
    assert {:ok, nil} = ProfessionalProfiles.get_own_profile(principal)
    refute has_element?(view, "#profile-save-success")
  end

  test "save failure preserves draft, saved completeness and stored data", %{
    conn: conn,
    principal: principal
  } do
    assert {:ok, before} =
             ProfessionalProfiles.save_own_profile(principal, %{"first_name" => "Antes"})

    Application.put_env(:origen, :professional_profiles_context, RejectingSave)
    view = open_profile(conn)
    submit(view, @complete)
    assert has_element?(view, "#profile-save-error[role=alert]", "No se pudo guardar")
    assert has_element?(view, ~s|#profile-first_name[value="Ana"]|)
    assert has_element?(view, "#profile-status", "Perfil incompleto")
    refute has_element?(view, "#profile-save-success")
    assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(principal)
    view |> element("#profile-cancel") |> render_click()
    refute has_element?(view, "#profile-form")
    assert has_element?(view, "#profile-read-first_name", "Antes")
  end

  test "revoking the live session rejects saves without changing any owner's data", %{
    conn: conn,
    principal: principal
  } do
    assert {:ok, before} = ProfessionalProfiles.save_own_profile(principal, @complete)
    view = open_profile(conn)
    assert :ok = Sessions.terminate_session(get_session(conn, :internal_session_token))
    submit(view, Map.put(@complete, "first_name", "Rechazado"))
    assert has_element?(view, "#profile-save-error")

    {:ok, %{token: token}} =
      Sessions.create_session(%{id: principal.account_id, role: :professional, state: :active})

    {:ok, fresh} = Sessions.touch_session(token)
    assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(fresh)
  end

  test "malformed profile fields are rejected without clearing stored values or settings", %{
    conn: conn,
    principal: principal
  } do
    assert {:ok, before} = ProfessionalProfiles.save_own_profile(principal, @complete)
    assert {:ok, settings} = Origen.ConsultationTypes.get_own_configuration(principal)
    assert {:ok, availability} = Origen.Availability.get_own_configuration(principal)
    view = open_profile(conn)

    for value <- [%{"invalid" => "shape"}, ["not text"]] do
      render_submit(view, "save_profile", %{"profile" => Map.put(@complete, "first_name", value)})
      assert has_element?(view, "#profile-save-error")
      refute has_element?(view, "#profile-save-success")
      assert has_element?(view, "#profile-status", "Perfil completo")
      assert {:ok, ^before} = ProfessionalProfiles.get_own_profile(principal)
      assert {:ok, ^settings} = Origen.ConsultationTypes.get_own_configuration(principal)
      assert {:ok, ^availability} = Origen.Availability.get_own_configuration(principal)
    end
  end

  test "profile starts in read mode and centralizes editing and saving there", %{
    conn: conn,
    principal: principal
  } do
    assert {:ok, _} = ProfessionalProfiles.save_own_profile(principal, @complete)
    {:ok, view, _} = live(conn, @path)
    render_async(view)
    assert has_element?(view, "#profile-read-first_name", "Ana")
    assert has_element?(view, "#profile-read-specialty", "Clínica")
    assert has_element?(view, "#profile-read-license_type", "Provincial / libre")
    assert has_element?(view, "#profile-read-license_number", "AB-001/26")
    refute has_element?(view, "#profile-form")
    assert has_element?(view, "#profile-edit", "Editar perfil")
    refute has_element?(view, "#profile-edit", "Completar perfil")

    render_submit(view, "save_profile", %{
      "profile" => Map.put(@complete, "specialty", "No guardar")
    })

    assert {:ok, unchanged} = ProfessionalProfiles.get_own_profile(principal)
    assert unchanged.specialty == "Clínica"
    refute has_element?(view, "#profile-save-success")
    view |> element("#profile-edit") |> render_click()
    assert has_element?(view, "#profile-form")
    submit(view, Map.put(@complete, "specialty", "Cardiología"))
    refute has_element?(view, "#profile-form")
    assert has_element?(view, "#profile-read-specialty", "Cardiología")
    assert has_element?(view, "#profile-save-success", "Cambios guardados")
    assert {:ok, profile} = ProfessionalProfiles.get_own_profile(principal)
    assert profile.specialty == "Cardiología"
  end

  test "first registration save never switches an incomplete profile to Editar perfil", %{
    conn: conn,
    principal: principal
  } do
    {:ok, view, _} = live(conn, @path)
    render_async(view)
    assert has_element?(view, "#profile-edit", "Completar perfil")
    view |> element("#profile-edit") |> render_click()

    submit(view, %{
      "first_name" => "",
      "last_name" => "",
      "specialty" => "",
      "license_type" => "Libre",
      "license_number" => "MP-304"
    })

    refute has_element?(view, "#profile-form")
    assert has_element?(view, "#profile-read-license_number", "MP-304")
    assert has_element?(view, "#profile-edit", "Completar perfil")
    refute has_element?(view, "#profile-edit", "Editar perfil")
    assert {:ok, partial} = ProfessionalProfiles.get_own_profile(principal)
    refute partial.complete?
    {:ok, settings, _} = live(conn, "/configuracion/profesional")
    assert has_element?(settings, "#profile-entry-action", "Ver perfil")
    assert has_element?(settings, "#profile-license-summary", "MP-304")
    settings |> element("#profile-entry-action") |> render_click()
    assert_redirect(settings, @path)
    {:ok, revisited, _} = live(conn, @path)
    render_async(revisited)
    assert has_element?(revisited, "#profile-edit", "Completar perfil")
    refute has_element?(revisited, "#profile-form")
    refute has_element?(revisited, "#profile-edit", "Editar perfil")
  end

  for missing <- @fields do
    test "read action stays Completar perfil while #{missing} is missing", %{
      conn: conn,
      principal: principal
    } do
      assert {:ok, _} =
               ProfessionalProfiles.save_own_profile(
                 principal,
                 Map.put(@complete, unquote(missing), "")
               )

      {:ok, view, _} = live(conn, @path)
      render_async(view)
      assert has_element?(view, "#profile-edit", "Completar perfil")
      refute has_element?(view, "#profile-edit", "Editar perfil")
      refute has_element?(view, "#profile-form")
    end
  end

  defp open_profile(conn) do
    {:ok, view, _} = live(conn, @path)
    render_async(view)
    if has_element?(view, "#profile-edit"), do: view |> element("#profile-edit") |> render_click()
    view
  end

  defp submit(view, params) do
    unless has_element?(view, "#profile-form"),
      do: view |> element("#profile-edit") |> render_click()

    view |> form("#profile-form", profile: params) |> render_submit()
  end

  defp account!(role) do
    %{rows: [[id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW()) RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: id, role: role, state: :active}
  end
end
