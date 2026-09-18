defmodule OrigenWeb.Plugs.AuthenticateInternalSession do
  @moduledoc """
  Authenticates an internal account from a server-managed session token.

  A bearer token takes precedence over the browser session. Invalid, expired,
  revoked, or otherwise unauthorized sessions fail closed.
  """

  import Plug.Conn

  alias Origen.Sessions

  @behaviour Plug
  @session_key :internal_session_token

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, token} <- session_token(conn),
         {:ok, session} <- Sessions.touch_session(token) do
      conn
      |> assign(:current_internal_session, session)
      |> assign(:current_account_id, session.account_id)
      |> assign(:current_role, session.role)
    else
      _unauthenticated -> reject(conn)
    end
  end

  defp session_token(conn) do
    case get_req_header(conn, "authorization") do
      [] -> valid_token(get_session(conn, @session_key))
      [authorization] -> bearer_token(authorization)
      _multiple_headers -> {:error, :unauthenticated}
    end
  end

  defp bearer_token(authorization) do
    case String.split(authorization, ~r/\s+/, parts: 2, trim: true) do
      [scheme, token] ->
        if String.downcase(scheme) == "bearer" do
          valid_token(token)
        else
          {:error, :unauthenticated}
        end

      _invalid ->
        {:error, :unauthenticated}
    end
  end

  defp valid_token(token) when is_binary(token) and byte_size(token) > 0, do: {:ok, token}
  defp valid_token(_token), do: {:error, :unauthenticated}

  defp reject(conn) do
    conn
    |> delete_session(@session_key)
    |> send_resp(:unauthorized, "Unauthorized")
    |> halt()
  end
end
