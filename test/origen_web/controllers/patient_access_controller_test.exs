defmodule OrigenWeb.PatientAccessControllerTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Origen.PatientAccess
  alias Origen.PatientAccess.MagicLink
  alias Origen.Patients
  alias Origen.Repo

  @valid_email "paciente_web@example.test"

  setup do
    {:ok, _profile} = Patients.get_or_create_profile(@valid_email)
    :ok
  end

  describe "POST /paciente/cerrar-sesion" do
    test "clears patient authentication, preserves internal session and denies subsequent patient access",
         %{conn: conn} do
      %{rows: [[id]]} =
        Repo.query!("""
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ('patient-logout-staff@example.test', 'professional', 'active', 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """)

      {:ok, %{token: token}} = Origen.Sessions.create_session(id)

      conn =
        init_test_session(conn, %{
          patient_email: @valid_email,
          patient_authenticated_at: DateTime.to_iso8601(DateTime.utc_now()),
          internal_session_token: token,
          unrelated: "preserved"
        })

      conn = post(conn, "/paciente/cerrar-sesion")

      assert redirected_to(conn) == "/paciente/acceso"
      assert get_session(conn, :patient_email) == nil
      assert get_session(conn, :patient_authenticated_at) == nil
      assert get_session(conn, :internal_session_token) == token
      assert get_session(conn, :unrelated) == "preserved"
      assert {:ok, %{account_id: ^id}} = Origen.Sessions.fetch_session(token)

      for path <- ["/paciente/turnos/reservar", "/paciente/telefono/verificar"] do
        assert {:error, {:redirect, %{to: "/paciente/acceso"}}} =
                 live(recycle(conn), path)
      end

      assert html_response(get(recycle(conn), "/profesional/ajustes"), 200)
    end

    test "logout is idempotent when no patient session exists", %{conn: conn} do
      conn =
        conn |> init_test_session(%{unrelated: "preserved"}) |> post("/paciente/cerrar-sesion")

      assert redirected_to(conn) == "/paciente/acceso"
      assert get_session(conn, :patient_email) == nil
      assert get_session(conn, :patient_authenticated_at) == nil
      assert get_session(conn, :unrelated) == "preserved"
    end

    test "logout rejects POST without CSRF and cannot be invoked by GET", %{conn: conn} do
      protected =
        conn
        |> init_test_session(%{patient_email: @valid_email})
        |> put_private(:plug_skip_csrf_protection, false)

      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        post(protected, "/paciente/cerrar-sesion")
      end

      rejected_get =
        conn
        |> init_test_session(%{patient_email: @valid_email})
        |> get("/paciente/cerrar-sesion")

      assert response(rejected_get, 404)
      assert get_session(rejected_get, :patient_email) == @valid_email
    end
  end

  describe "GET /paciente/acceso/verificar" do
    test "authenticates session and redirects to reservation on valid token", %{conn: conn} do
      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)

      raw_token =
        receive do
          {:email, email} ->
            [_, token] = Regex.run(~r/token=([^"&]+)/, email.html_body)
            URI.decode_www_form(token)
        after
          1000 -> flunk("Expected email to be delivered")
        end

      conn = get(conn, ~p"/paciente/acceso/verificar?token=#{raw_token}")

      assert redirected_to(conn) == ~p"/paciente/turnos/reservar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Acceso verificado exitosamente"
      assert get_session(conn, :patient_email) == @valid_email

      # Token is now consumed and cannot be reused
      conn2 = build_conn() |> get(~p"/paciente/acceso/verificar?token=#{raw_token}")
      assert redirected_to(conn2) == ~p"/paciente/acceso"
      assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "inválido o ha expirado"
    end

    test "redirects to /paciente/acceso with error when token is expired", %{conn: conn} do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      digest = :crypto.hash(:sha256, raw_token)

      Repo.insert!(%MagicLink{
        email: @valid_email,
        token_digest: digest,
        expires_at: past,
        consumed_at: nil,
        created_at: past
      })

      conn = get(conn, ~p"/paciente/acceso/verificar?token=#{raw_token}")
      assert redirected_to(conn) == ~p"/paciente/acceso"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválido o ha expirado"
    end

    test "redirects to /paciente/acceso with error when token is missing or invalid", %{
      conn: conn
    } do
      conn1 = get(conn, ~p"/paciente/acceso/verificar")
      assert redirected_to(conn1) == ~p"/paciente/acceso"

      conn2 = get(conn, ~p"/paciente/acceso/verificar?token=token_invalido_total")
      assert redirected_to(conn2) == ~p"/paciente/acceso"
      assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "inválido o ha expirado"
    end
  end
end
