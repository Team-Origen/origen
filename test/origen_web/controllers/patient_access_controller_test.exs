defmodule OrigenWeb.PatientAccessControllerTest do
  use OrigenWeb.ConnCase

  alias Origen.PatientAccess
  alias Origen.PatientAccess.MagicLink
  alias Origen.Repo

  @valid_email "paciente_web@example.test"

  describe "GET /access/verify" do
    test "authenticates session and redirects to / on valid token", %{conn: conn} do
      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)

      raw_token =
        receive do
          {:email, email} ->
            [_, token] = Regex.run(~r/token=([^"&]+)/, email.html_body)
            URI.decode_www_form(token)
        after
          1000 -> flunk("Expected email to be delivered")
        end

      conn = get(conn, ~p"/access/verify?token=#{raw_token}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Acceso verificado exitosamente"
      assert get_session(conn, :patient_email) == @valid_email

      # Token is now consumed and cannot be reused
      conn2 = build_conn() |> get(~p"/access/verify?token=#{raw_token}")
      assert redirected_to(conn2) == ~p"/access"
      assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "inválido o ha expirado"
    end

    test "redirects to /access with error when token is expired", %{conn: conn} do
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

      conn = get(conn, ~p"/access/verify?token=#{raw_token}")
      assert redirected_to(conn) == ~p"/access"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválido o ha expirado"
    end

    test "redirects to /access with error when token is missing or invalid", %{conn: conn} do
      conn1 = get(conn, ~p"/access/verify")
      assert redirected_to(conn1) == ~p"/access"

      conn2 = get(conn, ~p"/access/verify?token=token_invalido_total")
      assert redirected_to(conn2) == ~p"/access"
      assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "inválido o ha expirado"
    end
  end

  describe "DELETE /patient/session" do
    test "clears only the patient identity and redirects to access", %{conn: conn} do
      conn =
        conn
        |> init_test_session(patient_email: @valid_email, unrelated: "kept")
        |> delete(~p"/patient/session")

      assert redirected_to(conn) == ~p"/access"
      assert get_session(conn, :patient_email) == nil
      assert get_session(conn, :unrelated) == "kept"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Sesión de paciente cerrada"
    end
  end
end
