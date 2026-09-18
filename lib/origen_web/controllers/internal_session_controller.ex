defmodule OrigenWeb.InternalSessionController do
  use OrigenWeb, :controller

  alias Origen.Accounts
  alias Origen.Sessions

  @session_key :internal_session_token

  def new(conn, _params) do
    with :ok <- require_tls(conn) do
      render_login(conn, nil)
    else
      _denied -> unavailable(conn)
    end
  end

  def create(conn, params) do
    with :ok <- require_tls(conn),
         {:ok, %{token: token}} <-
           Accounts.authenticate_internal_account(
             Map.get(params, "identifier"),
             Map.get(params, "password"),
             Map.get(params, "totp_code"),
             []
           ) do
      conn
      |> configure_session(renew: true)
      |> clear_session()
      |> put_session(@session_key, token)
      |> secure_headers()
      |> redirect(to: ~p"/")
    else
      {:error, :tls_required} -> unavailable(conn)
      _unauthenticated -> invalid_credentials(conn)
    end
  end

  def delete(conn, _params) do
    with :ok <- require_tls(conn) do
      conn
      |> get_session(@session_key)
      |> Sessions.terminate_session()

      conn
      |> clear_session()
      |> configure_session(drop: true)
      |> secure_headers()
      |> redirect(to: ~p"/login")
    else
      _denied -> unavailable(conn)
    end
  end

  defp render_login(conn, error) do
    conn
    |> secure_headers()
    |> render(:new, error: error, csrf_token: get_csrf_token())
  end

  defp invalid_credentials(conn) do
    conn
    |> delete_session(@session_key)
    |> put_status(:unprocessable_entity)
    |> render_login("Sign-in details are invalid")
  end

  defp require_tls(%Plug.Conn{scheme: :https}), do: :ok

  defp require_tls(_conn) do
    if Application.get_env(:origen, :allow_insecure_http_activation, false) do
      :ok
    else
      {:error, :tls_required}
    end
  end

  defp unavailable(conn) do
    conn
    |> delete_session(@session_key)
    |> secure_headers()
    |> send_resp(:not_found, "Authentication unavailable")
  end

  defp secure_headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end
end
