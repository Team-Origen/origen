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

  require Logger

  alias Origen.AcademicDemo
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
      |> redirect(to: ~p"/administrador/activar")
    else
      _denied -> unavailable(conn)
    end
  end

  def exchange(conn, _params), do: unavailable(conn)

  def create(conn, params) do
    nonce = get_session(conn, @session_key)

    with :ok <- require_tls(conn),
         true <- is_binary(nonce),
         {:ok, session} <- AdminActivationSessionStore.fetch(nonce) do
      case build_credentials(params, session.seed, AcademicDemo.password_only?()) do
        {:ok, credentials} -> activate(conn, nonce, session, credentials)
        {:error, reason} -> reject(conn, reason)
      end
    else
      _denied -> unavailable(conn)
    end
  end

  defp activate(conn, nonce, session, credentials) do
    case BootstrapAdmin.activate_bound(session.invitation_id, session.account_id, credentials) do
      {:ok, _result} ->
        AdminActivationSessionStore.delete(nonce)
        notify_local_activation()

        conn
        |> delete_session(@session_key)
        |> put_flash(:info, "Cuenta activada. Ingresá con tu email y tu contraseña.")
        |> secure_headers()
        |> redirect(to: ~p"/login")

      {:error, reason} when reason in [:invalid_email, :email_taken] ->
        reject(conn, reason)

      _denied ->
        unavailable(conn)
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
        password_only = AcademicDemo.password_only?()

        totp_uri =
          unless password_only do
            NimbleTOTP.otpauth_uri(
              "Origen:administrator-#{session.account_id}",
              session.seed,
              issuer: "Origen"
            )
          end

        conn
        |> secure_headers()
        |> render(:enrollment,
          totp_uri: totp_uri,
          error: nil,
          csrf_token: get_csrf_token(),
          password_only: password_only
        )

      {:error, :invalid_session} ->
        unavailable(conn)
    end
  end

  @server_reasons [:totp_keyring_invalid, :seed_encryption_failed]

  # Logs only the reason atom: never the submitted password, the code or the key.
  defp reject(conn, reason) do
    Logger.warning("admin activation rejected reason=#{reason}")

    status = if reason in @server_reasons, do: :service_unavailable, else: :unprocessable_entity

    conn
    |> secure_headers()
    |> put_status(status)
    |> render(:enrollment,
      totp_uri: nil,
      error: rejection_message(reason),
      csrf_token: get_csrf_token(),
      password_only: AcademicDemo.password_only?()
    )
  end

  @invalid_prefix "Los datos de activación no son válidos."

  defp rejection_message(:missing_fields), do: "#{@invalid_prefix} Completá todos los campos."

  defp rejection_message(:invalid_email),
    do: "#{@invalid_prefix} El email no tiene un formato válido."

  defp rejection_message(:email_taken),
    do: "#{@invalid_prefix} Ese email ya lo usa otra cuenta interna."

  defp rejection_message(:password_mismatch),
    do: "#{@invalid_prefix} Las contraseñas no coinciden."

  defp rejection_message(:password_length),
    do: "#{@invalid_prefix} La contraseña tiene que tener al menos 12 caracteres."

  defp rejection_message(:invalid_totp_code),
    do: "#{@invalid_prefix} El código del autenticador no es válido o ya venció."

  defp rejection_message(_server_reason),
    do:
      "La activación no está disponible por un problema de configuración del servidor. " <>
        "Avisale al equipo técnico."

  # In academic demo mode the TOTP code is not requested or checked, but the seed is
  # still encrypted and stored because active accounts must carry a TOTP secret.
  defp build_credentials(
         %{"email" => email, "password" => password, "password_confirmation" => confirmation} =
           params,
         seed,
         password_only
       )
       when is_binary(email) and is_binary(password) and is_binary(confirmation) do
    size = byte_size(password)

    with {:match, true} <- {:match, password == confirmation},
         {:length, true} <-
           {:length, size >= @minimum_password_bytes and size <= @maximum_password_bytes},
         {:totp, true} <-
           {:totp, password_only or valid_totp_code?(seed, Map.get(params, "totp_code"))},
         {:keyring, {:ok, keyring}} <- {:keyring, totp_keyring()},
         {:encrypt, {:ok, encrypted_seed}} <-
           {:encrypt, Credentials.encrypt_seed(seed, keyring)} do
      {:ok,
       %{
         email: email,
         password_hash: Credentials.hash_password(password),
         totp_secret: encrypted_seed
       }}
    else
      {:match, _} -> {:error, :password_mismatch}
      {:length, _} -> {:error, :password_length}
      {:totp, _} -> {:error, :invalid_totp_code}
      {:keyring, _} -> {:error, :totp_keyring_invalid}
      {:encrypt, _} -> {:error, :seed_encryption_failed}
    end
  end

  defp build_credentials(_params, _seed, _password_only), do: {:error, :missing_fields}

  defp valid_totp_code?(seed, code) when is_binary(code), do: NimbleTOTP.valid?(seed, code)
  defp valid_totp_code?(_seed, _code), do: false

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

  # Outside the local profile, resolve the keyring in the same order as
  # Origen.Accounts (:totp_keyring first, which config/runtime.exs sets in :prod),
  # so the seed is encrypted with the key that login later decrypts with.
  defp totp_keyring do
    keyring =
      if Application.get_env(:origen, :bootstrap_admin_profile) == :local,
        do: activation_secret(:totp_keyring, :bootstrap_admin_totp_keyring),
        else:
          Application.get_env(:origen, :totp_keyring) ||
            Application.get_env(:origen, :bootstrap_admin_totp_keyring)

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
