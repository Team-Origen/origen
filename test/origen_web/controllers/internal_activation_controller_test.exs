defmodule OrigenWeb.InternalActivationControllerTest do
  use OrigenWeb.ConnCase, async: false

  alias Origen.Accounts
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo
  alias OrigenWeb.InternalActivationSessionStore

  @verifier_key String.duplicate("v", 32)
  @totp_key String.duplicate("t", 32)

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    InternalActivationSessionStore.clear()

    previous = %{
      verifier_key: Application.get_env(:origen, :bootstrap_admin_verifier_key),
      keyring: Application.get_env(:origen, :totp_keyring),
      ttl: Application.get_env(:origen, :internal_activation_session_ttl_seconds)
    }

    Application.put_env(:origen, :bootstrap_admin_verifier_key, @verifier_key)

    Application.put_env(:origen, :totp_keyring, %{
      active: %{tag: "seed.test.v1", key: @totp_key},
      retired: []
    })

    Application.put_env(:origen, :internal_activation_session_ttl_seconds, 600)

    on_exit(fn ->
      restore_env(:bootstrap_admin_verifier_key, previous.verifier_key)
      restore_env(:totp_keyring, previous.keyring)
      restore_env(:internal_activation_session_ttl_seconds, previous.ttl)
      InternalActivationSessionStore.clear()
    end)

    :ok
  end

  @tag :runtime_harness
  test "uses a fragment exchange shell at the general route and keeps admin activation isolated",
       %{
         conn: conn
       } do
    body = conn |> get(https(~p"/activate")) |> html_response(200)

    assert body =~ "window.location.hash"
    assert body =~ "history.replaceState"
    assert body =~ ~s(action="/activate/exchange")
    refute body =~ ~s(type="password")

    {replace_index, _} = :binary.match(body, "history.replaceState")
    {submit_index, _} = :binary.match(body, "form.submit")
    assert replace_index < submit_index

    admin_body = build_conn() |> get(https(~p"/admin/activate")) |> html_response(200)
    assert admin_body =~ "Administrator activation"
    refute admin_body =~ ~s(action="/activate/exchange")
  end

  test "fails closed over non-TLS transport and for invalid exchanges", %{conn: conn} do
    invitation = issue_staff_invitation(:professional)

    assert response(get(conn, ~p"/activate"), 404) == "Activation unavailable"

    assert response(
             post(build_conn(), ~p"/activate/exchange", %{
               "invitation_id" => to_string(invitation.invitation_id),
               "token" => invitation.token
             }),
             404
           ) == "Activation unavailable"

    conn =
      post(build_conn(), https(~p"/activate/exchange"), %{
        "invitation_id" => to_string(invitation.invitation_id),
        "token" => "invalid-token"
      })

    assert response(conn, 404) == "Activation unavailable"
    assert pending_state(invitation) == [["pending_activation", nil, nil, nil]]
  end

  @tag :runtime_harness
  test "activates staff with password confirmation and verified TOTP, then redirects to login", %{
    conn: conn
  } do
    invitation = issue_staff_invitation(:secretary)
    exchange_conn = exchange(conn, invitation)

    assert redirected_to(exchange_conn) == ~p"/activate"
    refute redirected_to(exchange_conn) =~ invitation.token

    page_conn = exchange_conn |> recycle() |> get(https(~p"/activate"))
    body = html_response(page_conn, 200)
    seed = totp_seed_from_page(body)

    assert body =~ "Secure internal account"
    assert body =~ ~s(type="password")
    refute body =~ invitation.token

    success_conn =
      page_conn
      |> recycle()
      |> post(https(~p"/activate"), %{
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password",
        "totp_code" => NimbleTOTP.verification_code(seed)
      })

    assert redirected_to(success_conn) == "/login"

    [["active", password_hash, encrypted_seed, consumed_at]] = pending_state(invitation)
    assert Credentials.verify_password("a-secure-password", password_hash)
    assert {:ok, ^seed} = Credentials.decrypt_seed(encrypted_seed, keyring())
    assert not is_nil(consumed_at)

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_sessions WHERE account_id = $1",
             [invitation.account_id]
           ).rows == [[0]]
  end

  test "keeps invitation and account pending when password or TOTP validation fails", %{
    conn: conn
  } do
    invitation = issue_staff_invitation(:professional)
    exchange_conn = exchange(conn, invitation)
    page_conn = exchange_conn |> recycle() |> get(https(~p"/activate"))
    seed = page_conn |> html_response(200) |> totp_seed_from_page()

    conn =
      page_conn
      |> recycle()
      |> post(https(~p"/activate"), %{
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password",
        "totp_code" => wrong_totp_code(seed)
      })

    assert html_response(conn, 422) =~ "Activation details are invalid"
    assert pending_state(invitation) == [["pending_activation", nil, nil, nil]]

    audit_dump =
      Repo.query!(
        "SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result FROM audit_events WHERE event = 'account_activation'"
      ).rows
      |> inspect()

    refute audit_dump =~ invitation.token
    refute audit_dump =~ "a-secure-password"
    refute audit_dump =~ Base.encode32(seed, padding: false)
  end

  test "returns unavailable when totp_keyring is not configured or invalid", %{conn: conn} do
    invitation = issue_staff_invitation(:secretary)
    exchange_conn = exchange(conn, invitation)
    page_conn = exchange_conn |> recycle() |> get(https(~p"/activate"))
    seed = page_conn |> html_response(200) |> totp_seed_from_page()

    previous_keyring = Application.get_env(:origen, :totp_keyring)
    Application.delete_env(:origen, :totp_keyring)

    try do
      conn =
        page_conn
        |> recycle()
        |> post(https(~p"/activate"), %{
          "password" => "a-secure-password",
          "password_confirmation" => "a-secure-password",
          "totp_code" => NimbleTOTP.verification_code(seed)
        })

      assert response(conn, 404) == "Activation unavailable"
      assert pending_state(invitation) == [["pending_activation", nil, nil, nil]]
    after
      Application.put_env(:origen, :totp_keyring, previous_keyring)
    end
  end

  test "preserves session on page reload / multiple GET requests and completes activation", %{
    conn: conn
  } do
    invitation = issue_staff_invitation(:professional)
    exchange_conn = exchange(conn, invitation)

    # First GET
    page_conn1 = exchange_conn |> recycle() |> get(https(~p"/activate"))
    assert html_response(page_conn1, 200) =~ "Secure internal account"

    # Second GET (reload / F5)
    page_conn2 = page_conn1 |> recycle() |> get(https(~p"/activate"))
    body = html_response(page_conn2, 200)
    assert body =~ "Secure internal account"
    seed = totp_seed_from_page(body)

    # Submit activation POST
    success_conn =
      page_conn2
      |> recycle()
      |> post(https(~p"/activate"), %{
        "password" => "a-secure-password",
        "password_confirmation" => "a-secure-password",
        "totp_code" => NimbleTOTP.verification_code(seed)
      })

    assert redirected_to(success_conn) == "/login"
    assert [["active", _hash, _seed, _consumed_at]] = pending_state(invitation)
  end

  defp issue_staff_invitation(role) do
    password_hash = Credentials.hash_password("administrator-password")
    seed = NimbleTOTP.secret()
    {:ok, encrypted_seed} = Credentials.encrypt_seed(seed, keyring())

    %{rows: [[administrator_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, 'administrator', 'active', $2, $3, clock_timestamp())
        RETURNING id
        """,
        [
          "admin-#{System.unique_integer([:positive])}@clinicaorigen.com",
          password_hash,
          encrypted_seed
        ]
      )

    assert {:ok, invitation} =
             Accounts.create_and_invite_internal_account(
               administrator_id,
               %{
                 email: "staff-#{System.unique_integer([:positive])}@clinicaorigen.com",
                 role: role
               },
               verifier_key: @verifier_key
             )

    invitation
  end

  defp exchange(conn, invitation) do
    conn
    |> post(https(~p"/activate/exchange"), %{
      "invitation_id" => to_string(invitation.invitation_id),
      "token" => invitation.token
    })
  end

  defp pending_state(invitation) do
    Repo.query!(
      """
      SELECT a.state, a.password_hash, a.totp_secret, i.consumed_at
      FROM internal_accounts AS a
      JOIN internal_account_invitations AS i ON i.account_id = a.id
      WHERE a.id = $1 AND i.id = $2
      """,
      [invitation.account_id, invitation.invitation_id]
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

  defp https(path), do: "https://www.example.com" <> path

  defp restore_env(key, nil), do: Application.delete_env(:origen, key)
  defp restore_env(key, value), do: Application.put_env(:origen, key, value)
end
