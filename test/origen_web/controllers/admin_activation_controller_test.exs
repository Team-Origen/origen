defmodule OrigenWeb.AdminActivationControllerTest do
  use OrigenWeb.ConnCase, async: false

  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo
  alias OrigenWeb.AdminActivationSessionStore

  @verifier_key String.duplicate("v", 32)
  @totp_key String.duplicate("t", 32)

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    AdminActivationSessionStore.clear()

    previous_verifier_key = Application.get_env(:origen, :bootstrap_admin_verifier_key)
    previous_keyring = Application.get_env(:origen, :bootstrap_admin_totp_keyring)
    previous_shared_keyring = Application.get_env(:origen, :totp_keyring)
    previous_ttl = Application.get_env(:origen, :bootstrap_admin_session_ttl_seconds)
    previous_academic_demo = Application.get_env(:origen, :academic_demo_password_only)

    Application.put_env(:origen, :bootstrap_admin_verifier_key, @verifier_key)

    # Activation encrypts with the same keyring login decrypts with; keep both
    # names on one keyring so these tests do not depend on config/test.exs.
    test_keyring = %{active: %{tag: "seed.test.v1", key: @totp_key}, retired: []}
    Application.put_env(:origen, :bootstrap_admin_totp_keyring, test_keyring)
    Application.put_env(:origen, :totp_keyring, test_keyring)

    Application.put_env(:origen, :bootstrap_admin_session_ttl_seconds, 600)

    on_exit(fn ->
      restore_env(:bootstrap_admin_verifier_key, previous_verifier_key)
      restore_env(:bootstrap_admin_totp_keyring, previous_keyring)
      restore_env(:totp_keyring, previous_shared_keyring)
      restore_env(:bootstrap_admin_session_ttl_seconds, previous_ttl)
      restore_env(:academic_demo_password_only, previous_academic_demo)
      AdminActivationSessionStore.clear()
    end)

    :ok
  end

  @tag :runtime_harness
  test "rejects activation over non-TLS transport without changing invitation state", %{
    conn: conn
  } do
    invitation = issue_invitation()

    assert response(get(conn, ~p"/administrador/activar"), 404) == "Activation unavailable"

    conn =
      post(build_conn(), ~p"/administrador/activar/intercambiar", %{
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => invitation.token
      })

    assert response(conn, 404) == "Activation unavailable"
    assert invitation_state(invitation.invitation_id) == [[nil, nil]]
  end

  @tag :runtime_harness
  test "renders only a fragment exchange shell and removes the fragment before POST", %{
    conn: conn
  } do
    conn = get(conn, https(~p"/administrador/activar"))
    body = html_response(conn, 200)

    assert body =~ "window.location.hash"
    assert body =~ "history.replaceState"
    assert body =~ ~s(name="_csrf_token")
    assert body =~ ~s(action="/administrador/activar/intercambiar")
    refute body =~ ~s(type="password")

    {replace_index, _} = :binary.match(body, "history.replaceState")
    {submit_index, _} = :binary.match(body, "form.submit")
    assert replace_index < submit_index
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]

    assert Phoenix.Logger.filter_values(%{
             "token" => "raw-invitation-value",
             "password" => "password-value",
             "invitation_id" => "12"
           }) == %{
             "token" => "[FILTERED]",
             "password" => "[FILTERED]",
             "invitation_id" => "12"
           }

    assert Phoenix.Logger.filter_values(%{"totp_seed" => "seed-value"}) == %{
             "totp_seed" => "[FILTERED]"
           }
  end

  @tag :runtime_harness
  test "requires CSRF for fragment exchange and redirects a valid exchange to a clean URL" do
    invitation = issue_invitation()
    {conn, _csrf_token} = csrf_page()

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> recycle()
      |> enforce_csrf()
      |> post(https(~p"/administrador/activar/intercambiar"), %{
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => invitation.token
      })
    end

    {conn, csrf_token} = csrf_page()

    conn =
      conn
      |> recycle()
      |> enforce_csrf()
      |> post(https(~p"/administrador/activar/intercambiar"), %{
        "_csrf_token" => csrf_token,
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => invitation.token
      })

    assert redirected_to(conn) == ~p"/administrador/activar"
    refute redirected_to(conn) =~ invitation.token
    refute redirected_to(conn) =~ to_string(invitation.invitation_id)
  end

  test "rejects invalid exchange input without rendering credentials or changing state", %{
    conn: conn
  } do
    invitation = issue_invitation()

    malformed_conn =
      post(conn, https(~p"/administrador/activar/intercambiar"), %{
        "invitation_id" => [],
        "token" => invitation.token
      })

    assert response(malformed_conn, 404) == "Activation unavailable"

    conn =
      build_conn()
      |> post(https(~p"/administrador/activar/intercambiar"), %{
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => "invalid-token"
      })

    assert response(conn, 404) == "Activation unavailable"
    refute conn.resp_body =~ ~s(type="password")
    assert invitation_state(invitation.invitation_id) == [[nil, nil]]
    assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
  end

  test "fails closed when the activation session lifetime is malformed", %{conn: conn} do
    Application.put_env(:origen, :bootstrap_admin_session_ttl_seconds, "ten minutes")
    invitation = issue_invitation()

    conn = exchange(conn, invitation)

    assert response(conn, 404) == "Activation unavailable"
    assert invitation_state(invitation.invitation_id) == [[nil, nil]]
  end

  @tag :runtime_harness
  test "binds enrollment to the exchanged session and renders the TOTP payload once", %{
    conn: conn
  } do
    invitation = issue_invitation()
    exchange_conn = exchange(conn, invitation)

    page_conn = exchange_conn |> recycle() |> get(https(~p"/administrador/activar"))
    body = html_response(page_conn, 200)

    assert body =~ ~s(type="password")
    assert body =~ "otpauth://totp/"
    refute body =~ invitation.token

    unrelated_body = build_conn() |> get(https(~p"/administrador/activar")) |> html_response(200)
    refute unrelated_body =~ ~s(type="password")

    refreshed = page_conn |> recycle() |> get(https(~p"/administrador/activar"))
    assert response(refreshed, 404) == "Activation unavailable"
    refute refreshed.resp_body =~ "otpauth://totp/"
  end

  @tag :runtime_harness
  test "expires the invitation-bound session before credential enrollment", %{conn: conn} do
    Application.put_env(:origen, :bootstrap_admin_session_ttl_seconds, 1)
    invitation = issue_invitation()
    exchange_conn = exchange(conn, invitation)

    Process.sleep(1_100)

    expired_conn = exchange_conn |> recycle() |> get(https(~p"/administrador/activar"))
    assert response(expired_conn, 404) == "Activation unavailable"
    assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
  end

  test "rejects an invalid TOTP without persisting either factor", %{conn: conn} do
    invitation = issue_invitation()
    exchange_conn = exchange(conn, invitation)
    page_conn = exchange_conn |> recycle() |> get(https(~p"/administrador/activar"))
    seed = page_conn |> html_response(200) |> totp_seed_from_page()

    conn =
      page_conn
      |> recycle()
      |> post(https(~p"/administrador/activar"), %{
        "email" => "admin@example.test",
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password",
        "totp_code" => wrong_totp_code(seed)
      })

    assert html_response(conn, 422) =~ "Los datos de activación no son válidos"
    assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
    assert invitation_state(invitation.invitation_id) == [[nil, nil]]
  end

  @tag :runtime_harness
  test "synthetic failure, fresh activation, replay denial, and disablement", %{conn: conn} do
    failed = issue_invitation()
    assert {:ok, :revoked} = BootstrapAdmin.revoke_delivery_failure(failed.invitation_id, %{})
    assert response(exchange(conn, failed), 404) == "Activation unavailable"

    invitation =
      elem(BootstrapAdmin.reissue_first(failed.account_id, %{verifier_key: @verifier_key}), 1)

    exchange_conn = exchange(conn, invitation)
    page_conn = exchange_conn |> recycle() |> get(https(~p"/administrador/activar"))
    seed = page_conn |> html_response(200) |> totp_seed_from_page()
    code = NimbleTOTP.verification_code(seed)

    submission = %{
      "email" => "admin@example.test",
      "password" => "a-secure-password",
      "password_confirmation" => "a-secure-password",
      "totp_code" => code
    }

    success_conn = page_conn |> recycle() |> post(https(~p"/administrador/activar"), submission)
    assert redirected_to(success_conn) == ~p"/login"

    [["active", password_hash, encrypted_seed]] = account_credentials(invitation.account_id)
    assert Credentials.verify_password("a-secure-password", password_hash)
    assert {:ok, ^seed} = Credentials.decrypt_seed(encrypted_seed, keyring())
    assert [[consumed_at, nil]] = invitation_state(invitation.invitation_id)
    assert not is_nil(consumed_at)

    replay_conn = page_conn |> recycle() |> post(https(~p"/administrador/activar"), submission)
    assert response(replay_conn, 404) == "Activation unavailable"

    assert account_credentials(invitation.account_id) ==
             [["active", password_hash, encrypted_seed]]

    Application.put_env(:origen, :bootstrap_admin_enabled, false)
    assert {:error, :bootstrap_disabled} = Origen.BootstrapAdmin.Gate.check()
  end

  test "activates with the keyring that config/runtime.exs sets for :prod (:totp_keyring)", %{
    conn: conn
  } do
    # Exactly what config/runtime.exs configures in :prod (setup restores both).
    Application.put_env(:origen, :totp_keyring, keyring())
    Application.delete_env(:origen, :bootstrap_admin_totp_keyring)

    invitation = issue_invitation()

    page_conn =
      conn |> exchange(invitation) |> recycle() |> get(https(~p"/administrador/activar"))

    seed = page_conn |> html_response(200) |> totp_seed_from_page()

    success_conn =
      page_conn
      |> recycle()
      |> post(https(~p"/administrador/activar"), %{
        "email" => "admin@example.test",
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password",
        "totp_code" => NimbleTOTP.verification_code(seed)
      })

    assert redirected_to(success_conn) == ~p"/login"
    [["active", _password_hash, encrypted_seed]] = account_credentials(invitation.account_id)
    assert {:ok, ^seed} = Credentials.decrypt_seed(encrypted_seed, keyring())
  end

  describe "with the academic demo flag on" do
    setup do
      Application.put_env(:origen, :academic_demo_password_only, true)
      :ok
    end

    test "activates the first administrator with password only, storing an encrypted TOTP secret",
         %{conn: conn} do
      invitation = issue_invitation()

      page_conn =
        conn |> exchange(invitation) |> recycle() |> get(https(~p"/administrador/activar"))

      body = html_response(page_conn, 200)
      assert body =~ ~s(type="password")
      refute body =~ "otpauth://"
      refute body =~ ~s(name="totp_code")

      success_conn =
        page_conn
        |> recycle()
        |> post(https(~p"/administrador/activar"), %{
          "email" => " Admin.Demo@Gmail.com ",
          "password" => "a-secure-password",
          "password_confirmation" => "a-secure-password"
        })

      assert redirected_to(success_conn) == ~p"/login"

      assert Repo.query!("SELECT email FROM internal_accounts WHERE id = $1", [
               invitation.account_id
             ]).rows == [["admin.demo@gmail.com"]]

      [["active", password_hash, encrypted_seed]] = account_credentials(invitation.account_id)
      assert Credentials.verify_password("a-secure-password", password_hash)
      assert {:ok, seed} = Credentials.decrypt_seed(encrypted_seed, keyring())
      assert byte_size(seed) > 0
      assert [[consumed_at, nil]] = invitation_state(invitation.invitation_id)
      assert not is_nil(consumed_at)

      # The first Administrator signs in with the email chosen at activation.
      login_conn =
        post(build_conn(), https(~p"/login"), %{
          "identifier" => "admin.demo@gmail.com",
          "password" => "a-secure-password"
        })

      assert redirected_to(login_conn) == "/administrador/cuentas"
    end

    test "labels both password fields, uses the app theme and asks for the sign-in email", %{
      conn: conn
    } do
      invitation = issue_invitation()

      body =
        conn
        |> exchange(invitation)
        |> recycle()
        |> get(https(~p"/administrador/activar"))
        |> html_response(200)

      assert body =~ ~s(data-theme="light")
      assert body =~ ~r/<label[^>]*for="password"[^>]*>\s*Contraseña\s*</
      assert body =~ ~r/<label[^>]*for="password_confirmation"[^>]*>\s*Confirmar contraseña\s*</
      assert body =~ ~r/<label[^>]*for="email"[^>]*>\s*Email\s*</
      assert body =~ ~s(type="email")
      refute body =~ "ID de cuenta"
    end

    test "still rejects a password shorter than 12 bytes without persisting factors", %{
      conn: conn
    } do
      invitation = issue_invitation()

      page_conn =
        conn |> exchange(invitation) |> recycle() |> get(https(~p"/administrador/activar"))

      conn =
        page_conn
        |> recycle()
        |> post(https(~p"/administrador/activar"), %{
          "email" => "admin@example.test",
          "password" => "short",
          "password_confirmation" => "short"
        })

      body = html_response(conn, 422)
      assert body =~ "Los datos de activación no son válidos"
      refute body =~ ~s(name="totp_code")
      assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
    end

    test "names each rejection reason on screen and in the log, without secrets", %{conn: conn} do
      cases = [
        {%{
           "email" => "admin@example.test",
           "password" => "a-secure-password",
           "password_confirmation" => "another-password"
         }, "Las contraseñas no coinciden", "password_mismatch"},
        {%{
           "email" => "admin@example.test",
           "password" => "short",
           "password_confirmation" => "short"
         }, "al menos 12 caracteres", "password_length"},
        {%{"password" => "a-secure-password"}, "Completá todos los campos", "missing_fields"},
        {%{
           "email" => "not-an-email",
           "password" => "a-secure-password",
           "password_confirmation" => "a-secure-password"
         }, "El email no tiene un formato válido", "invalid_email"}
      ]

      for {params, message, reason} <- cases do
        invitation = issue_invitation()

        page_conn =
          conn |> exchange(invitation) |> recycle() |> get(https(~p"/administrador/activar"))

        {post_conn, log} =
          ExUnit.CaptureLog.with_log(fn ->
            page_conn |> recycle() |> post(https(~p"/administrador/activar"), params)
          end)

        body = html_response(post_conn, 422)
        assert body =~ message
        assert log =~ "admin activation rejected reason=#{reason}"
        refute log =~ "a-secure-password"
        refute log =~ "another-password"
        assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]

        Repo.query!("DELETE FROM internal_account_invitations")
        Repo.query!("DELETE FROM internal_accounts")
      end
    end

    test "reports an invalid server TOTP keyring as unavailable, not as a user error", %{
      conn: conn
    } do
      invitation = issue_invitation()

      page_conn =
        conn |> exchange(invitation) |> recycle() |> get(https(~p"/administrador/activar"))

      bad_keyring = %{active: %{tag: "seed.prod.v1", key: "too-short"}, retired: []}
      Application.put_env(:origen, :totp_keyring, bad_keyring)
      Application.put_env(:origen, :bootstrap_admin_totp_keyring, bad_keyring)

      {post_conn, log} =
        ExUnit.CaptureLog.with_log(fn ->
          page_conn
          |> recycle()
          |> post(https(~p"/administrador/activar"), %{
            "email" => "admin@example.test",
            "password" => "a-secure-password",
            "password_confirmation" => "a-secure-password"
          })
        end)

      body = html_response(post_conn, 503)
      assert body =~ "problema de configuración del servidor"
      refute body =~ "Los datos de activación no son válidos"
      assert log =~ "admin activation rejected reason=totp_keyring_invalid"
      refute log =~ "too-short"
      assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
    end
  end

  test "without the academic demo flag, activation without a TOTP code stays rejected", %{
    conn: conn
  } do
    Application.put_env(:origen, :academic_demo_password_only, false)
    invitation = issue_invitation()

    page_conn =
      conn |> exchange(invitation) |> recycle() |> get(https(~p"/administrador/activar"))

    assert html_response(page_conn, 200) =~ "otpauth://"

    conn =
      page_conn
      |> recycle()
      |> post(https(~p"/administrador/activar"), %{
        "email" => "admin@example.test",
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password"
      })

    assert html_response(conn, 422) =~ "Los datos de activación no son válidos"
    assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
  end

  defp issue_invitation do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @verifier_key})
    invitation
  end

  defp exchange(conn, invitation) do
    conn
    |> post(https(~p"/administrador/activar/intercambiar"), %{
      "invitation_id" => to_string(invitation.invitation_id),
      "token" => invitation.token
    })
  end

  defp csrf_page do
    conn = build_conn() |> enforce_csrf() |> get(https(~p"/administrador/activar"))

    [csrf_token] =
      Regex.run(~r/name="_csrf_token" content="([^"]+)"/, conn.resp_body, capture: :all_but_first)

    {conn, csrf_token}
  end

  defp https(path), do: "https://www.example.com" <> path

  defp enforce_csrf(conn) do
    %{conn | private: Map.delete(conn.private, :plug_skip_csrf_protection)}
  end

  defp invitation_state(invitation_id) do
    Repo.query!(
      "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1",
      [invitation_id]
    ).rows
  end

  defp account_credentials(account_id) do
    Repo.query!(
      "SELECT state, password_hash, totp_secret FROM internal_accounts WHERE id = $1",
      [account_id]
    ).rows
  end

  defp totp_seed_from_page(body) do
    [uri] = Regex.run(~r/data-totp-uri="([^"]+)"/, body, capture: :all_but_first)
    query = uri |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    Base.decode32!(query["secret"], padding: false)
  end

  defp keyring do
    %{active: %{tag: "seed.test.v1", key: @totp_key}, retired: []}
  end

  defp wrong_totp_code(seed) do
    <<first, rest::binary>> = NimbleTOTP.verification_code(seed)
    replacement = if first == ?0, do: ?1, else: ?0
    <<replacement, rest::binary>>
  end

  defp restore_env(key, nil), do: Application.delete_env(:origen, key)
  defp restore_env(key, value), do: Application.put_env(:origen, key, value)
end
