defmodule OrigenWeb.InternalSessionControllerTest do
  use OrigenWeb.ConnCase, async: true

  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo
  alias Origen.Sessions

  @session_key :internal_session_token
  @keyring %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  }

  test "GET /login renders a TLS-only, CSRF-protected sign-in form", %{conn: conn} do
    conn = get(conn, https("/login"))
    body = html_response(conn, 200)

    assert body =~ "Sign in"
    assert body =~ ~s(action="/login")
    assert body =~ ~s(name="_csrf_token")
    assert body =~ ~s(name="identifier")
    assert body =~ ~s(name="password")
    assert body =~ ~s(name="totp_code")
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]

    insecure_conn = build_conn() |> get("/login")
    assert response(insecure_conn, 404) == "Authentication unavailable"
    assert get_resp_header(insecure_conn, "cache-control") == ["no-store"]
    assert get_resp_header(insecure_conn, "referrer-policy") == ["no-referrer"]
  end

  test "POST /login authenticates an activated account and renews the browser session", %{
    conn: conn
  } do
    account = create_activated_account(:professional)
    code = NimbleTOTP.verification_code(account.seed)

    conn =
      conn
      |> init_test_session(%{session_fixation_marker: "discard-me"})
      |> post(https("/login"), %{
        "identifier" => account.email,
        "password" => account.password,
        "totp_code" => code
      })

    assert redirected_to(conn) == "/"
    token = get_session(conn, @session_key)
    assert is_binary(token)
    assert get_session(conn, :session_fixation_marker) == nil
    assert {:ok, %{account_id: account_id}} = Sessions.fetch_session(token)
    assert account_id == account.id

    protected_conn = conn |> recycle() |> get("/configuracion/profesional")
    assert html_response(protected_conn, 200)
  end

  test "POST /login fails opaquely without creating or storing a session", %{conn: conn} do
    account = create_activated_account(:professional)
    code = NimbleTOTP.verification_code(account.seed)

    conn =
      conn
      |> init_test_session(%{unrelated: "discard-on-failure"})
      |> post(https("/login"), %{
        "identifier" => account.email,
        "password" => "incorrect-password",
        "totp_code" => code
      })

    body = html_response(conn, 422)
    assert body =~ "Sign-in details are invalid"
    refute body =~ account.email
    refute body =~ "incorrect-password"
    refute body =~ code
    assert get_session(conn, @session_key) == nil

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_sessions WHERE account_id = $1",
             [account.id]
           ).rows == [[0]]
  end

  test "POST /login rejects non-TLS credentials without creating a session", %{conn: conn} do
    account = create_activated_account(:professional)

    conn =
      post(conn, "/login", %{
        "identifier" => account.email,
        "password" => account.password,
        "totp_code" => NimbleTOTP.verification_code(account.seed)
      })

    assert response(conn, 404) == "Authentication unavailable"
    assert get_session(conn, @session_key) == nil

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_sessions WHERE account_id = $1",
             [account.id]
           ).rows == [[0]]
  end

  test "POST /logout terminates the server session and clears the browser session", %{conn: conn} do
    account = create_activated_account(:professional)
    {:ok, %{token: token}} = Sessions.create_session(account.id)

    conn =
      conn
      |> init_test_session(%{@session_key => token, unrelated: "clear-me"})
      |> post(https("/logout"))

    assert redirected_to(conn) == "/login"
    assert get_session(conn, @session_key) == nil
    assert get_session(conn, :unrelated) == nil
    assert {:error, :unauthenticated} = Sessions.fetch_session(token)
  end

  test "POST /logout is idempotent when no internal session exists", %{conn: conn} do
    conn = conn |> init_test_session(%{unrelated: "clear-me"}) |> post(https("/logout"))

    assert redirected_to(conn) == "/login"
    assert get_session(conn, @session_key) == nil
    assert get_session(conn, :unrelated) == nil
  end

  defp create_activated_account(role) do
    email = "staff-#{System.unique_integer([:positive])}@clinicaorigen.com"
    password = "a-secure-password"
    seed = NimbleTOTP.secret()
    password_hash = Credentials.hash_password(password)
    {:ok, encrypted_seed} = Credentials.encrypt_seed(seed, @keyring)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', $3, $4, clock_timestamp())
        RETURNING id
        """,
        [email, Atom.to_string(role), password_hash, encrypted_seed]
      )

    %{id: id, email: email, password: password, seed: seed}
  end

  defp https(path), do: "https://www.example.com" <> path
end
