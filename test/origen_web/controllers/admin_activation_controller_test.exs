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
    previous_ttl = Application.get_env(:origen, :bootstrap_admin_session_ttl_seconds)

    Application.put_env(:origen, :bootstrap_admin_verifier_key, @verifier_key)

    Application.put_env(:origen, :bootstrap_admin_totp_keyring, %{
      active: %{tag: "seed.test.v1", key: @totp_key},
      retired: []
    })

    Application.put_env(:origen, :bootstrap_admin_session_ttl_seconds, 600)

    on_exit(fn ->
      restore_env(:bootstrap_admin_verifier_key, previous_verifier_key)
      restore_env(:bootstrap_admin_totp_keyring, previous_keyring)
      restore_env(:bootstrap_admin_session_ttl_seconds, previous_ttl)
      AdminActivationSessionStore.clear()
    end)

    :ok
  end

  @tag :runtime_harness
  test "rejects activation over non-TLS transport without changing invitation state", %{
    conn: conn
  } do
    invitation = issue_invitation()

    assert response(get(conn, ~p"/admin/activate"), 404) == "Activation unavailable"

    conn =
      post(build_conn(), ~p"/admin/activate/exchange", %{
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
    conn = get(conn, https(~p"/admin/activate"))
    body = html_response(conn, 200)

    assert body =~ "window.location.hash"
    assert body =~ "history.replaceState"
    assert body =~ ~s(name="_csrf_token")
    assert body =~ ~s(action="/admin/activate/exchange")
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
      |> post(https(~p"/admin/activate/exchange"), %{
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => invitation.token
      })
    end

    {conn, csrf_token} = csrf_page()

    conn =
      conn
      |> recycle()
      |> enforce_csrf()
      |> post(https(~p"/admin/activate/exchange"), %{
        "_csrf_token" => csrf_token,
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => invitation.token
      })

    assert redirected_to(conn) == ~p"/admin/activate"
    refute redirected_to(conn) =~ invitation.token
    refute redirected_to(conn) =~ to_string(invitation.invitation_id)
  end

  test "rejects invalid exchange input without rendering credentials or changing state", %{
    conn: conn
  } do
    invitation = issue_invitation()

    malformed_conn =
      post(conn, https(~p"/admin/activate/exchange"), %{
        "invitation_id" => [],
        "token" => invitation.token
      })

    assert response(malformed_conn, 404) == "Activation unavailable"

    conn =
      build_conn()
      |> post(https(~p"/admin/activate/exchange"), %{
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

    page_conn = exchange_conn |> recycle() |> get(https(~p"/admin/activate"))
    body = html_response(page_conn, 200)

    assert body =~ ~s(type="password")
    assert body =~ "otpauth://totp/"
    refute body =~ invitation.token

    unrelated_body = build_conn() |> get(https(~p"/admin/activate")) |> html_response(200)
    refute unrelated_body =~ ~s(type="password")

    refreshed = page_conn |> recycle() |> get(https(~p"/admin/activate"))
    assert response(refreshed, 404) == "Activation unavailable"
    refute refreshed.resp_body =~ "otpauth://totp/"
  end

  @tag :runtime_harness
  test "expires the invitation-bound session before credential enrollment", %{conn: conn} do
    Application.put_env(:origen, :bootstrap_admin_session_ttl_seconds, 1)
    invitation = issue_invitation()
    exchange_conn = exchange(conn, invitation)

    Process.sleep(1_100)

    expired_conn = exchange_conn |> recycle() |> get(https(~p"/admin/activate"))
    assert response(expired_conn, 404) == "Activation unavailable"
    assert account_credentials(invitation.account_id) == [["pending_activation", nil, nil]]
  end

  test "rejects an invalid TOTP without persisting either factor", %{conn: conn} do
    invitation = issue_invitation()
    exchange_conn = exchange(conn, invitation)
    page_conn = exchange_conn |> recycle() |> get(https(~p"/admin/activate"))
    seed = page_conn |> html_response(200) |> totp_seed_from_page()

    conn =
      page_conn
      |> recycle()
      |> post(https(~p"/admin/activate"), %{
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password",
        "totp_code" => wrong_totp_code(seed)
      })

    assert html_response(conn, 422) =~ "Activation details are invalid"
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
    page_conn = exchange_conn |> recycle() |> get(https(~p"/admin/activate"))
    seed = page_conn |> html_response(200) |> totp_seed_from_page()
    code = NimbleTOTP.verification_code(seed)

    submission = %{
      "password" => "a-secure-password",
      "password_confirmation" => "a-secure-password",
      "totp_code" => code
    }

    success_conn = page_conn |> recycle() |> post(https(~p"/admin/activate"), submission)
    assert redirected_to(success_conn) == ~p"/"

    [["active", password_hash, encrypted_seed]] = account_credentials(invitation.account_id)
    assert Credentials.verify_password("a-secure-password", password_hash)
    assert {:ok, ^seed} = Credentials.decrypt_seed(encrypted_seed, keyring())
    assert [[consumed_at, nil]] = invitation_state(invitation.invitation_id)
    assert not is_nil(consumed_at)

    replay_conn = page_conn |> recycle() |> post(https(~p"/admin/activate"), submission)
    assert response(replay_conn, 404) == "Activation unavailable"

    assert account_credentials(invitation.account_id) ==
             [["active", password_hash, encrypted_seed]]

    Application.put_env(:origen, :bootstrap_admin_enabled, false)
    assert {:error, :bootstrap_disabled} = Origen.BootstrapAdmin.Gate.check()
  end

  defp issue_invitation do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @verifier_key})
    invitation
  end

  defp exchange(conn, invitation) do
    conn
    |> post(https(~p"/admin/activate/exchange"), %{
      "invitation_id" => to_string(invitation.invitation_id),
      "token" => invitation.token
    })
  end

  defp csrf_page do
    conn = build_conn() |> enforce_csrf() |> get(https(~p"/admin/activate"))

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
