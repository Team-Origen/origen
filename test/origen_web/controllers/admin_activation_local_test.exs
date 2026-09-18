defmodule OrigenWeb.AdminActivationLocalTest do
  use OrigenWeb.ConnCase, async: false
  import ExUnit.CaptureLog
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.BootstrapAdmin.Local.{Command, Endpoint, MailboxStore, RegressionTest}
  alias Origen.Repo
  alias OrigenWeb.AdminActivationSessionStore
  @verifier_key String.duplicate("v", 32)
  @totp_key String.duplicate("t", 32)
  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    MailboxStore.clear()
    AdminActivationSessionStore.clear()
    Endpoint.cleanup()
    previous_profile = Application.get_env(:origen, :bootstrap_admin_profile)
    previous_verifier = Application.get_env(:origen, :bootstrap_admin_verifier_key)

    verifier_file =
      Path.join(System.tmp_dir!(), "origen-local-verifier-#{System.unique_integer([:positive])}")

    File.write!(verifier_file, Base.encode64(@verifier_key))
    Application.put_env(:origen, :bootstrap_admin_profile, :local)
    Application.put_env(:origen, :bootstrap_admin_verifier_key, {:file, verifier_file})

    assert :ok =
             Endpoint.start_session(endpoint_config(),
               server_start: fn _ -> {:ok, spawn(fn -> Process.sleep(:infinity) end)} end,
               secret_loader: fn ->
                 {:ok, %{verifier_key: @verifier_key, totp_keyring: keyring()}}
               end
             )

    on_exit(fn ->
      Endpoint.cleanup()
      File.rm(verifier_file)
      restore_env(:bootstrap_admin_profile, previous_profile)
      restore_env(:bootstrap_admin_verifier_key, previous_verifier)
    end)

    :ok
  end

  test "local issuance composes through fragment exchange, credentials, TOTP, and cleanup", %{
    conn: conn
  } do
    parent = self()

    log =
      capture_log(fn ->
        result =
          Command.run(%{account_id: nil},
            config: RegressionTest.config(),
            probes: RegressionTest.probes()
          )

        send(parent, {:public_result, result})
      end)

    assert_receive {:public_result, {:ok, issued}}
    [email] = Swoosh.Adapters.Local.Storage.Memory.all()
    [url] = Regex.run(~r{https://[^\s<]+}, email.text_body, capture: :all)
    fragment = url |> URI.parse() |> Map.fetch!(:fragment) |> URI.decode_query()

    {exchange_conn, exchange_log} =
      capture_result_log(fn ->
        post(conn, https(~p"/admin/activate/exchange"), %{
          "invitation_id" => fragment["invitation_id"],
          "token" => fragment["token"]
        })
      end)

    assert redirected_to(exchange_conn) == ~p"/admin/activate"
    nonce = get_session(exchange_conn, :admin_activation_nonce)

    {page_conn, render_log} =
      capture_result_log(fn -> exchange_conn |> recycle() |> get(https(~p"/admin/activate")) end)

    page_body = html_response(page_conn, 200)
    seed = totp_seed_from_page(page_body)
    password = "a-secure-password"

    {activated_conn, activation_log} =
      capture_result_log(fn ->
        page_conn
        |> recycle()
        |> post(https(~p"/admin/activate"), %{
          "password" => password,
          "password_confirmation" => password,
          "totp_code" => NimbleTOTP.verification_code(seed)
        })
      end)

    assert redirected_to(activated_conn) == ~p"/"
    assert [["active", password_hash, encrypted_seed]] = account_credentials(issued.account_id)

    unless Credentials.verify_password(password, password_hash),
      do: flunk("password verification failed")

    unless Credentials.decrypt_seed(encrypted_seed, keyring()) == {:ok, seed},
      do: flunk("TOTP decryption failed")

    assert [[consumed_at, nil]] = invitation_state(issued.invitation_id)
    assert not is_nil(consumed_at)

    sensitive = [
      email.text_body,
      email.html_body,
      url,
      fragment["token"],
      Base.encode32(seed, padding: false),
      password,
      nonce,
      encrypted_seed,
      @verifier_key,
      @totp_key
    ]

    unless String.contains?(page_body, Base.encode32(seed, padding: false)),
      do: flunk("TOTP enrollment payload missing")

    public_surfaces = [
      log <> exchange_log <> render_log <> activation_log,
      inspect(issued),
      inspect(:sys.get_state(Endpoint)),
      inspect(exchange_conn.resp_headers),
      inspect(page_conn.resp_headers),
      inspect(activated_conn.resp_headers),
      exchange_conn.resp_body,
      activated_conn.resp_body,
      "sensitive value crossed a public surface"
    ]

    assert_no_sensitive_values(public_surfaces, sensitive)
    Endpoint.cleanup()
    assert MailboxStore.count() == 0
    assert Swoosh.Adapters.Local.Storage.Memory.all() == []
    assert {:error, :secrets_unavailable} = Endpoint.fetch_secret(:verifier_key)
  end

  defp endpoint_config do
    %{
      activation_origin: "https://127.0.0.1:4443/admin/activate",
      endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false},
      certificate_file: "cert",
      certificate_key_file: "cert-key",
      retention_ttl_seconds: 60
    }
  end

  defp keyring, do: %{active: %{tag: "local.test.v1", key: @totp_key}, retired: []}
  defp https(path), do: "https://www.example.com" <> path

  defp totp_seed_from_page(body) do
    [uri] = Regex.run(~r/data-totp-uri="([^"]+)"/, body, capture: :all_but_first)
    query = uri |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    Base.decode32!(query["secret"], padding: false)
  end

  defp capture_result_log(fun) do
    key = {__MODULE__, :captured_result}
    log = capture_log(fn -> Process.put(key, fun.()) end)
    {Process.delete(key), log}
  end

  defp assert_no_sensitive_values(surfaces, sensitive) do
    if Enum.any?(surfaces, fn surface ->
         Enum.any?(sensitive, &String.contains?(surface, &1))
       end),
       do: flunk("sensitive value crossed a public surface")
  end

  defp account_credentials(account_id) do
    Repo.query!("SELECT state, password_hash, totp_secret FROM internal_accounts WHERE id = $1", [
      account_id
    ]).rows
  end

  defp invitation_state(invitation_id) do
    Repo.query!(
      "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1",
      [invitation_id]
    ).rows
  end

  defp restore_env(key, nil), do: Application.delete_env(:origen, key)
  defp restore_env(key, value), do: Application.put_env(:origen, key, value)
end
