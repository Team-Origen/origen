defmodule OrigenWeb.InternalActivationController do
  use OrigenWeb, :controller

  alias Origen.Accounts
  alias OrigenWeb.InternalActivationSessionStore

  @session_key :internal_activation_nonce

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
         {:ok, binding} <-
           Accounts.prepare_internal_account_activation(parsed_id, token,
             verifier_key: verifier_key
           ),
         {:ok, nonce} <-
           InternalActivationSessionStore.create(
             binding.invitation_id,
             binding.account_id,
             token
           ) do
      conn
      |> configure_session(renew: true)
      |> put_session(@session_key, nonce)
      |> secure_headers()
      |> redirect(to: ~p"/activate")
    else
      _denied -> unavailable(conn)
    end
  end

  def exchange(conn, _params), do: unavailable(conn)

  def create(conn, params) do
    nonce = get_session(conn, @session_key)

    with :ok <- require_tls(conn),
         true <- is_binary(nonce),
         {:ok, session} <- InternalActivationSessionStore.fetch(nonce),
         {:ok, verifier_key} <- verifier_key(),
         {:ok, activation_params} <- normalize_params(params),
         {:ok, _result} <-
           Accounts.activate_internal_account(
             %{
               invitation_id: session.invitation_id,
               account_id: session.account_id,
               token: session.token,
               totp_seed: session.seed
             },
             activation_params,
             verifier_key: verifier_key
           ) do
      InternalActivationSessionStore.delete(nonce)

      conn
      |> delete_session(@session_key)
      |> put_flash(:info, "Account activation completed")
      |> secure_headers()
      |> redirect(to: "/login")
    else
      {:error, :activation_failed} -> invalid_credentials(conn)
      _denied -> unavailable(conn)
    end
  end

  defp normalize_params(%{"password" => p, "password_confirmation" => c, "totp_code" => t})
       when is_binary(p) and is_binary(c) and is_binary(t) do
    {:ok, %{password: p, password_confirmation: c, totp_code: t}}
  end

  defp normalize_params(%{password: p, password_confirmation: c, totp_code: t})
       when is_binary(p) and is_binary(c) and is_binary(t) do
    {:ok, %{password: p, password_confirmation: c, totp_code: t}}
  end

  defp normalize_params(_other), do: {:error, :activation_failed}

  defp render_exchange(conn) do
    conn
    |> secure_headers()
    |> render(:exchange, csrf_token: get_csrf_token())
  end

  defp render_enrollment(conn, nonce) do
    case InternalActivationSessionStore.take_for_render(nonce) do
      {:ok, session} ->
        totp_uri =
          NimbleTOTP.otpauth_uri(
            "Origen:internal-#{session.account_id}",
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

  defp verifier_key do
    case Application.get_env(:origen, :bootstrap_admin_verifier_key) do
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
