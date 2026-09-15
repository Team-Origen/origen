defmodule OrigenWeb.AdminActivationSessionStore do
  @moduledoc false
  use GenServer

  @name __MODULE__
  @maximum_ttl_seconds 900

  def start_link(_options), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  def create(invitation_id, account_id) do
    GenServer.call(@name, {:create, invitation_id, account_id})
  end

  def take_for_render(nonce), do: GenServer.call(@name, {:take_for_render, nonce})
  def fetch(nonce), do: GenServer.call(@name, {:fetch, nonce})
  def delete(nonce), do: GenServer.call(@name, {:delete, nonce})

  @doc false
  def clear, do: GenServer.call(@name, :clear)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:create, invitation_id, account_id}, _from, sessions) do
    ttl = Application.get_env(:origen, :bootstrap_admin_session_ttl_seconds, 600)

    if is_integer(ttl) and ttl > 0 and ttl <= @maximum_ttl_seconds do
      nonce = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      session = %{
        invitation_id: invitation_id,
        account_id: account_id,
        seed: NimbleTOTP.secret(),
        expires_at: System.monotonic_time(:second) + ttl,
        rendered?: false
      }

      {:reply, {:ok, nonce}, Map.put(purge(sessions), nonce, session)}
    else
      {:reply, {:error, :invalid_configuration}, purge(sessions)}
    end
  end

  def handle_call({:take_for_render, nonce}, _from, sessions) do
    sessions = purge(sessions)

    case Map.fetch(sessions, nonce) do
      {:ok, %{rendered?: false} = session} ->
        {:reply, {:ok, session}, put_in(sessions, [nonce, :rendered?], true)}

      _missing_or_rendered ->
        {:reply, {:error, :invalid_session}, Map.delete(sessions, nonce)}
    end
  end

  def handle_call({:fetch, nonce}, _from, sessions) do
    sessions = purge(sessions)

    case Map.fetch(sessions, nonce) do
      {:ok, %{rendered?: true} = session} -> {:reply, {:ok, session}, sessions}
      _missing -> {:reply, {:error, :invalid_session}, sessions}
    end
  end

  def handle_call(:clear, _from, _sessions), do: {:reply, :ok, %{}}

  def handle_call({:delete, nonce}, _from, sessions),
    do: {:reply, :ok, Map.delete(sessions, nonce)}

  defp purge(sessions) do
    now = System.monotonic_time(:second)
    Map.reject(sessions, fn {_nonce, session} -> session.expires_at <= now end)
  end
end

defmodule OrigenWeb.AdminActivationController do
  use OrigenWeb, :controller

  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.Credentials
  alias Origen.BootstrapAdmin.Local.Endpoint, as: LocalEndpoint
  alias OrigenWeb.AdminActivationSessionStore

  @session_key :admin_activation_nonce
  @minimum_password_bytes 12
  @maximum_password_bytes 1_024

  def new(conn, _params) do
    with :ok <- require_tls(conn) do
      case get_session(conn, @session_key) do
        nonce when is_binary(nonce) -> render_enrollment(conn, nonce)
        _missing -> render_exchange(conn)
      end
    else
      _denied -> unavailable(conn)
    end
  end

  def exchange(conn, %{"invitation_id" => invitation_id, "token" => token}) do
    with :ok <- require_tls(conn),
         {:ok, parsed_id} <- parse_invitation_id(invitation_id),
         true <- is_binary(token) and token != "",
         {:ok, verifier_key} <- verifier_key(),
         {:ok, binding} <- BootstrapAdmin.exchange(parsed_id, token, verifier_key),
         {:ok, nonce} <-
           AdminActivationSessionStore.create(binding.invitation_id, binding.account_id) do
      conn
      |> configure_session(renew: true)
      |> put_session(@session_key, nonce)
      |> secure_headers()
      |> redirect(to: ~p"/admin/activate")
    else
      _denied -> unavailable(conn)
    end
  end

  def exchange(conn, _params), do: unavailable(conn)

  def create(conn, params) do
    nonce = get_session(conn, @session_key)

    with :ok <- require_tls(conn),
         true <- is_binary(nonce),
         {:ok, session} <- AdminActivationSessionStore.fetch(nonce),
         {:ok, credentials} <- build_credentials(params, session.seed),
         {:ok, _result} <-
           BootstrapAdmin.activate_bound(
             session.invitation_id,
             session.account_id,
             credentials
           ) do
      AdminActivationSessionStore.delete(nonce)
      notify_local_activation()

      conn
      |> delete_session(@session_key)
      |> put_flash(:info, "Administrator activation completed")
      |> secure_headers()
      |> redirect(to: ~p"/")
    else
      {:error, :invalid_credentials} -> invalid_credentials(conn)
      _denied -> unavailable(conn)
    end
  end

  defp render_exchange(conn) do
    conn
    |> secure_headers()
    |> render(:exchange, csrf_token: get_csrf_token())
  end

  defp render_enrollment(conn, nonce) do
    case AdminActivationSessionStore.take_for_render(nonce) do
      {:ok, session} ->
        totp_uri =
          NimbleTOTP.otpauth_uri(
            "Origen:administrator-#{session.account_id}",
            session.seed,
            issuer: "Origen"
          )

        conn
        |> secure_headers()
        |> render(:enrollment, totp_uri: totp_uri, error: nil, csrf_token: get_csrf_token())

      {:error, :invalid_session} ->
        unavailable(conn)
    end
  end

  defp invalid_credentials(conn) do
    conn
    |> secure_headers()
    |> put_status(:unprocessable_entity)
    |> render(:enrollment,
      totp_uri: nil,
      error: "Activation details are invalid",
      csrf_token: get_csrf_token()
    )
  end

  defp build_credentials(
         %{
           "password" => password,
           "password_confirmation" => confirmation,
           "totp_code" => code
         },
         seed
       )
       when is_binary(password) and is_binary(confirmation) and is_binary(code) do
    size = byte_size(password)

    with true <- password == confirmation,
         true <- size >= @minimum_password_bytes and size <= @maximum_password_bytes,
         true <- NimbleTOTP.valid?(seed, code),
         {:ok, keyring} <- totp_keyring(),
         {:ok, encrypted_seed} <- Credentials.encrypt_seed(seed, keyring) do
      {:ok,
       %{
         password_hash: Credentials.hash_password(password),
         totp_secret: encrypted_seed
       }}
    else
      _invalid -> {:error, :invalid_credentials}
    end
  end

  defp build_credentials(_params, _seed), do: {:error, :invalid_credentials}

  defp verifier_key do
    case activation_secret(:verifier_key, :bootstrap_admin_verifier_key) do
      key when is_binary(key) and byte_size(key) >= 32 -> {:ok, key}
      _invalid -> {:error, :invalid_configuration}
    end
  end

  defp parse_invitation_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _invalid -> {:error, :invalid_request}
    end
  end

  defp parse_invitation_id(_value), do: {:error, :invalid_request}

  defp totp_keyring do
    keyring = activation_secret(:totp_keyring, :bootstrap_admin_totp_keyring)

    case Credentials.validate_keyring(keyring) do
      :ok -> {:ok, keyring}
      _invalid -> {:error, :invalid_configuration}
    end
  end

  defp activation_secret(local_name, staging_name) do
    if Application.get_env(:origen, :bootstrap_admin_profile) == :local do
      case LocalEndpoint.fetch_secret(local_name) do
        {:ok, value} -> value
        _ -> nil
      end
    else
      Application.get_env(:origen, staging_name)
    end
  end

  defp notify_local_activation do
    if Application.get_env(:origen, :bootstrap_admin_profile) == :local,
      do: LocalEndpoint.activation_complete()
  end

  defp require_tls(%Plug.Conn{scheme: :https}), do: :ok
  defp require_tls(_conn), do: {:error, :tls_required}

  defp unavailable(conn) do
    conn
    |> delete_session(@session_key)
    |> secure_headers()
    |> send_resp(:not_found, "Activation unavailable")
  end

  defp secure_headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end
end
