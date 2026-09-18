defmodule OrigenWeb.Plugs.AuthenticateInternalSessionTest do
  use OrigenWeb.ConnCase, async: false

  alias Origen.Repo
  alias Origen.Sessions
  alias OrigenWeb.Plugs.AuthenticateInternalSession

  setup do
    %{rows: [[account_id]]} =
      Repo.query!("""
      INSERT INTO internal_accounts
        (role, state, password_hash, totp_secret, activated_at)
      VALUES
        ('professional', 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
      RETURNING id
      """)

    %{account: %{id: account_id}}
  end

  test "missing token returns 401", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> AuthenticateInternalSession.call([])

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body == "Unauthorized"
  end

  test "invalid token returns 401 and clears the browser session", %{conn: conn} do
    conn =
      conn
      |> put_token_in_session("invalid-session-token-123456")
      |> AuthenticateInternalSession.call([])

    assert conn.halted
    assert conn.status == 401
    assert get_session(conn, :internal_session_token) == nil
  end

  test "a revoked token cannot be replayed and clears the browser session", %{
    conn: conn,
    account: account
  } do
    {:ok, %{token: token}} = Sessions.create_session(account)
    :ok = Sessions.terminate_session(token)

    conn =
      conn
      |> put_token_in_session(token)
      |> AuthenticateInternalSession.call([])

    assert conn.halted
    assert conn.status == 401
    assert get_session(conn, :internal_session_token) == nil
  end

  test "a session is rejected when its account is no longer active", %{
    conn: conn,
    account: account
  } do
    {:ok, %{token: token}} = Sessions.create_session(account)

    Repo.query!(
      """
      UPDATE internal_accounts
      SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL,
          activated_at = NULL
      WHERE id = $1
      """,
      [account.id]
    )

    conn =
      conn
      |> put_token_in_session(token)
      |> AuthenticateInternalSession.call([])

    assert conn.halted
    assert conn.status == 401
    assert get_session(conn, :internal_session_token) == nil
  end

  test "valid browser session assigns identity and refreshes last activity", %{
    conn: conn,
    account: account
  } do
    initial_activity = DateTime.add(DateTime.utc_now(), -60, :second)

    {:ok, %{token: token, session: created_session}} =
      Sessions.create_session(account, now: initial_activity)

    conn =
      conn
      |> put_token_in_session(token)
      |> AuthenticateInternalSession.call([])

    refute conn.halted
    assert conn.assigns.current_account_id == account.id
    assert conn.assigns.current_role == :professional
    assert conn.assigns.current_internal_session.session_id == created_session.session_id

    [[last_activity_at]] =
      Repo.query!(
        "SELECT last_activity_at FROM internal_account_sessions WHERE id = $1",
        [created_session.session_id]
      ).rows

    assert DateTime.compare(last_activity_at, initial_activity) == :gt
  end

  test "accepts an Authorization Bearer token", %{conn: conn, account: account} do
    {:ok, %{token: token}} = Sessions.create_session(account)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> put_req_header("authorization", "Bearer #{token}")
      |> AuthenticateInternalSession.call([])

    refute conn.halted
    assert conn.assigns.current_account_id == account.id
    assert conn.assigns.current_role == :professional
  end

  test "accepts a session cookie token", %{conn: conn, account: account} do
    conn = log_in_internal_account(conn, account)
    conn = AuthenticateInternalSession.call(conn, [])

    refute conn.halted
    assert conn.assigns.current_account_id == account.id
    assert conn.assigns.current_role == :professional
  end

  defp put_token_in_session(conn, token) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> put_session(:internal_session_token, token)
  end
end
