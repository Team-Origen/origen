defmodule OrigenWeb.InternalAuthLive do
  @moduledoc """
  Server-side authentication and authorization hooks for internal LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  alias Origen.Sessions

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case authenticate(session, socket) do
      {:ok, authenticated_socket} -> {:cont, authenticated_socket}
      {:error, unauthenticated_socket} -> deny(unauthenticated_socket)
    end
  end

  def on_mount(:ensure_professional, _params, session, socket) do
    case authenticate(session, socket) do
      {:ok, %{assigns: %{current_role: :professional}} = authenticated_socket} ->
        {:cont, authenticated_socket}

      {:ok, authenticated_socket} ->
        deny(authenticated_socket)

      {:error, unauthenticated_socket} ->
        deny(unauthenticated_socket)
    end
  end

  defp authenticate(session, socket) do
    with token when is_binary(token) <- session_token(session),
         {:ok, internal_session} <- Sessions.touch_session(token) do
      {:ok,
       socket
       |> assign(:current_internal_session, internal_session)
       |> assign(:current_account_id, internal_session.account_id)
       |> assign(:current_role, internal_session.role)}
    else
      _unauthenticated -> {:error, socket}
    end
  end

  defp session_token(session) when is_map(session) do
    Map.get(session, "internal_session_token") || Map.get(session, :internal_session_token)
  end

  defp session_token(_session), do: nil

  defp deny(socket), do: {:halt, redirect(socket, to: "/")}
end
