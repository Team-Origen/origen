defmodule OrigenWeb.UrlMigrationTest do
  use OrigenWeb.ConnCase

  @aliases [
    {"/access", "/paciente/acceso"},
    {"/patient/calendar", "/paciente/turnos/reservar"},
    {"/patient/phone/verify", "/paciente/telefono/verificar"},
    {"/admin/internal", "/administrador/cuentas"}
  ]

  for {old, canonical} <- @aliases do
    test "#{old} redirects without losing query parameters", %{conn: conn} do
      query = "?date=2026-04-10&date=&from=legacy%2Fscreen&flag"
      conn = get(conn, unquote(old) <> query)
      assert redirected_to(conn, 302) == unquote(canonical) <> query
    end
  end

  test "old and canonical settings retain the same session requirement", %{conn: conn} do
    for path <- [
          "/configuracion/profesional",
          "/configuracion/profesional/perfil",
          "/profesional/ajustes",
          "/profesional/ajustes/perfil"
        ] do
      assert conn |> recycle() |> get(path) |> response(401) == "Unauthorized"
    end
  end

  test "canonical patient access is available", %{conn: conn} do
    assert get(conn, "/paciente/acceso").status == 200
  end

  test "canonical protected patient screens retain session checks", %{conn: conn} do
    for path <- ["/paciente/turnos/reservar", "/paciente/telefono/verificar"] do
      assert conn |> recycle() |> get(path) |> redirected_to() == "/paciente/acceso"
    end
  end

  test "old and new magic links execute verification without redirecting credentials", %{
    conn: conn
  } do
    for path <- ["/access/verify", "/paciente/acceso/verificar"] do
      response = conn |> recycle() |> get(path <> "?token=invalid")
      assert redirected_to(response) == "/paciente/acceso"
      refute get_session(response, :patient_email)
    end
  end

  test "a previously issued magic link still establishes a patient session", %{conn: conn} do
    email = "legacy-url@example.test"
    {:ok, _} = Origen.Patients.get_or_create_profile(email)
    assert {:ok, :delivered} = Origen.PatientAccess.request_magic_link(email)

    token =
      receive do
        {:email, message} ->
          assert message.html_body =~ "/paciente/acceso/verificar?token="
          [_, token] = Regex.run(~r/token=([^"&]+)/, message.html_body)
          URI.decode_www_form(token)
      after
        1000 -> flunk("Expected magic link email")
      end

    response = get(conn, "/access/verify?" <> URI.encode_query(%{"token" => token}))
    assert redirected_to(response) == "/paciente/turnos/reservar"
    assert get_session(response, :patient_email) == email
    replay = conn |> recycle() |> get("/access/verify?" <> URI.encode_query(%{"token" => token}))
    assert redirected_to(replay) == "/paciente/acceso"
    refute get_session(replay, :patient_email)
  end

  test "legacy origins remain valid but new invitations use canonical paths" do
    assert {:ok, origin} =
             Origen.BootstrapAdmin.Origin.validate(
               "https://approved-host/admin/activate",
               %{environment: "staging", approved_hosts: ["approved-host"]}
             )

    assert Origen.BootstrapAdmin.Origin.to_uri(origin) ==
             "https://approved-host/administrador/activar"

    assert {:ok, local} =
             Origen.BootstrapAdmin.Local.Origin.validate(
               "https://127.0.0.1:4443/admin/activate",
               %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false}
             )

    assert Origen.BootstrapAdmin.Local.Origin.to_uri(local) ==
             "https://127.0.0.1:4443/administrador/activar"
  end

  test "legacy and canonical activation routes use identical handlers" do
    for {old, canonical} <- [
          {"/activate", "/activar"},
          {"/admin/activate", "/administrador/activar"}
        ],
        {method, suffix, action} <- [
          {"GET", "", :new},
          {"POST", "", :create},
          {"POST", "/exchange", :exchange}
        ] do
      canonical_suffix = if suffix == "/exchange", do: "/intercambiar", else: ""
      legacy = Phoenix.Router.route_info(OrigenWeb.Router, method, old <> suffix, "localhost")

      current =
        Phoenix.Router.route_info(
          OrigenWeb.Router,
          method,
          canonical <> canonical_suffix,
          "localhost"
        )

      assert current.plug == legacy.plug
      assert current.plug_opts == action
      assert legacy.plug_opts == action
    end
  end
end
