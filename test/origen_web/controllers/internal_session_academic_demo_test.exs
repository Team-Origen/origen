defmodule OrigenWeb.InternalSessionAcademicDemoTest do
  # The academic demo flag is global application config, so these tests must not
  # run concurrently with the async sign-in tests that expect TOTP to be required.
  use OrigenWeb.ConnCase, async: false

  alias Origen.BootstrapAdmin.Credentials
  alias Origen.Repo
  alias Origen.Sessions

  @session_key :internal_session_token
  @keyring %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  }

  setup do
    previous = Application.get_env(:origen, :academic_demo_password_only)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:origen, :academic_demo_password_only),
        else: Application.put_env(:origen, :academic_demo_password_only, previous)
    end)

    :ok
  end

  describe "with the academic demo flag on" do
    setup do
      Application.put_env(:origen, :academic_demo_password_only, true)
      :ok
    end

    test "GET /login asks only for email and password", %{conn: conn} do
      body = conn |> get(https("/login")) |> html_response(200)
      document = LazyHTML.from_document(body)

      assert LazyHTML.query(document, ~s(form#internal-login-form input#identifier[required]))
             |> Enum.count() == 1

      assert LazyHTML.query(
               document,
               ~s(form#internal-login-form input#password[type="password"][required])
             )
             |> Enum.count() == 1

      assert Enum.empty?(LazyHTML.query(document, ~s(input[name="totp_code"])))
      refute body =~ "Código del autenticador"
      refute body =~ "aplicación autenticadora"

      assert body =~
               "Ingresá con el email (o el ID de cuenta) y la contraseña de tu cuenta interna."
    end

    for {role, destination} <- [
          professional: "/profesional/agenda",
          secretary: "/secretaria/pacientes",
          administrator: "/administrador/cuentas"
        ] do
      test "POST /login signs a #{role} in with email and password only", %{conn: conn} do
        account = create_activated_account(unquote(role))

        conn =
          conn
          |> init_test_session(%{session_fixation_marker: "discard-me"})
          |> post(https("/login"), %{
            "identifier" => account.email,
            "password" => account.password
          })

        assert redirected_to(conn) == unquote(destination)
        assert get_session(conn, :session_fixation_marker) == nil

        assert {:ok, %{account_id: id, role: role}} =
                 Sessions.fetch_session(get_session(conn, @session_key))

        assert id == account.id
        assert role == unquote(role)
        assert last_login_audit(account.id) == ["internal_login", "succeeded"]
      end
    end

    test "POST /login still rejects a wrong password and audits the failure", %{conn: conn} do
      account = create_activated_account(:professional)

      conn =
        post(conn, https("/login"), %{
          "identifier" => account.email,
          "password" => "incorrect-password"
        })

      assert html_response(conn, 422) =~ "Sign-in details are invalid"
      assert get_session(conn, @session_key) == nil
      assert session_count(account.id) == 0
      assert last_login_audit(account.id) == ["internal_login", "failed"]
    end

    test "POST /login still rejects a deactivated account", %{conn: conn} do
      account = create_activated_account(:secretary)

      Repo.query!("UPDATE internal_accounts SET state = 'deactivated' WHERE id = $1", [
        account.id
      ])

      conn =
        post(conn, https("/login"), %{
          "identifier" => account.email,
          "password" => account.password
        })

      assert html_response(conn, 422) =~ "Sign-in details are invalid"
      assert session_count(account.id) == 0
    end
  end

  describe "with the academic demo flag off" do
    test "POST /login without a TOTP code is rejected exactly as before", %{conn: conn} do
      Application.put_env(:origen, :academic_demo_password_only, false)
      account = create_activated_account(:professional)

      conn =
        post(conn, https("/login"), %{
          "identifier" => account.email,
          "password" => account.password
        })

      assert html_response(conn, 422) =~ "Sign-in details are invalid"
      assert session_count(account.id) == 0
    end

    test "an unset flag keeps the TOTP field on the sign-in form", %{conn: conn} do
      Application.delete_env(:origen, :academic_demo_password_only)

      body = conn |> get(https("/login")) |> html_response(200)

      assert body =~ ~s(name="totp_code")
      assert body =~ "Código del autenticador"
    end
  end

  defp create_activated_account(role) do
    email = "staff-#{System.unique_integer([:positive])}@clinicaorigen.com"
    password = "a-secure-password"
    {:ok, encrypted_seed} = Credentials.encrypt_seed(NimbleTOTP.secret(), @keyring)

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', $3, $4, clock_timestamp())
        RETURNING id
        """,
        [email, Atom.to_string(role), Credentials.hash_password(password), encrypted_seed]
      )

    %{id: id, email: email, password: password}
  end

  defp session_count(account_id) do
    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM internal_account_sessions WHERE account_id = $1",
        [account_id]
      )

    count
  end

  defp last_login_audit(account_id) do
    %{rows: [row]} =
      Repo.query!(
        "SELECT event, result FROM audit_events WHERE event = 'internal_login' AND entity_ref = $1 ORDER BY id DESC LIMIT 1",
        [to_string(account_id)]
      )

    row
  end

  defp https(path), do: "https://www.example.com" <> path
end
