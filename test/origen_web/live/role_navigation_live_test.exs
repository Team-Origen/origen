defmodule OrigenWeb.RoleNavigationLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Repo, Sessions}

  test "professional navigation connects real sections and keeps subpages active", %{conn: conn} do
    conn = internal_conn(conn, "professional")
    {:ok, principal} = Sessions.fetch_session(get_session(conn, :internal_session_token))

    {:ok, _} =
      Origen.ProfessionalProfiles.save_own_profile(principal, %{
        first_name: "Sofía",
        last_name: "Martínez",
        specialty: "Cardiología",
        license_type: "Nacional",
        license_number: "PRIVATE-371"
      })

    for {path, active} <- [
          {"/profesional/agenda?date=2026-11-09", "agenda"},
          {"/profesional/agenda/crear", "agenda"},
          {"/profesional/ajustes", "settings"},
          {"/profesional/ajustes/perfil", "settings"}
        ] do
      {:ok, view, _html} = live(conn, path)
      assert_sticky_nav(view, "professional")
      assert has_element?(view, "#role-navigation a[href='/profesional/agenda']", "Agenda")
      assert has_element?(view, "#role-navigation a[href='/profesional/ajustes']", "Ajustes")
      assert has_element?(view, "#nav-#{active}[aria-current='page']")
      assert has_element?(view, "#nav-requests[phx-click]", "Solicitudes")
      assert has_element?(view, "#nav-summary[phx-click]", "Resumen económico")
      refute has_element?(view, "#role-navigation a[href*='solicitudes']")

      assert has_element?(
               view,
               "#navigation-account-menu button[data-pc-dropdown-trigger]",
               "Sofía Martínez"
             )

      assert has_element?(view, "#navigation-professional-avatar", "SM")
      assert has_element?(view, "#navigation-professional-role", "Profesional")
      assert has_element?(view, "#navigation-professional-name", "Sofía Martínez")
      assert has_element?(view, "#navigation-professional-email", "nav-professional@example.test")
      refute has_element?(view, "#navigation-account-menu", "PRIVATE-371")
      assert_logout(view, "Sofía Martínez")
    end
  end

  test "professional without a saved name retains a usable account menu", %{conn: conn} do
    {:ok, view, _} = live(internal_conn(conn, "professional"), "/profesional/agenda")
    assert has_element?(view, "#navigation-professional-name", "Profesional")
    assert has_element?(view, "#navigation-professional-email", "nav-professional@example.test")
    assert_logout(view, "Profesional")
  end

  test "navbar logout invalidates the existing session and protected access", %{conn: conn} do
    conn = internal_conn(conn, "professional")
    token = get_session(conn, :internal_session_token)
    {:ok, view, _html} = live(conn, "/profesional/agenda")
    assert_logout(view, "Profesional")

    logged_out = post(conn, "https://www.example.com/logout")
    assert redirected_to(logged_out) == "/login"
    assert get_session(logged_out, :internal_session_token) == nil
    assert {:error, :unauthenticated} = Sessions.fetch_session(token)
    assert response(get(recycle(logged_out), "/profesional/agenda"), 401)

    stale_conn = build_conn() |> init_test_session(%{internal_session_token: token})
    assert response(get(stale_conn, "/profesional/ajustes"), 401)
  end

  test "unauthenticated navigation remains inaccessible", %{conn: conn} do
    assert response(get(conn, "/profesional/agenda"), 401)
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), "/secretaria/pacientes")
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), "/administrador/cuentas")

    assert {:error, {:redirect, %{to: "/paciente/acceso"}}} =
             live(build_conn(), "/paciente/turnos/reservar")
  end

  defp assert_sticky_nav(view, role) do
    assert has_element?(view, "#role-navigation.sticky.top-0[data-role='#{role}']")
    assert has_element?(view, "#role-navigation nav[aria-label='Navegación principal']")
    assert has_element?(view, "#navigation-account-options.text-black")

    assert has_element?(
             view,
             "#navigation-account-options button[type='submit'].text-black",
             "Cerrar sesión"
           )

    assert has_element?(
             view,
             "#role-navigation img[src='/images/origen-logo-dark.png'][alt='Origen']"
           )

    refute has_element?(view, "#role-navigation a[href='/']")
    assert has_element?(view, "#navigation-future-notice[hidden]", "Próximo en implementar")
  end

  defp assert_logout(view, label) do
    assert has_element?(
             view,
             "#navigation-account-menu button[data-pc-dropdown-trigger].pc-button--white",
             label
           )

    assert has_element?(view, "#navigation-account-menu form[action='/logout'][method='post']")
    assert has_element?(view, "#navigation-account-menu input[name='_csrf_token']")
    assert has_element?(view, "#navigation-account-menu button[type='submit']", "Cerrar sesión")
  end

  defp internal_conn(conn, role) do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        ["nav-#{role}@example.test", role]
      )

    {:ok, %{token: token}} = Sessions.create_session(id)
    init_test_session(conn, %{internal_session_token: token})
  end
end
