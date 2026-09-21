defmodule OrigenWeb.PatientAccessController do
  @moduledoc """
  Controller to handle patient magic link consumption via /access/verify.
  """

  use OrigenWeb, :controller

  alias Origen.PatientAccess

  @session_key :patient_email

  @doc """
  Consumes a magic link token passed in query parameters.
  On success, establishes the patient session and redirects.
  On failure, redirects back to /access with a non-enumerating error message.
  """
  def verify(conn, %{"token" => token}) when is_binary(token) and token != "" do
    case PatientAccess.consume_magic_link(token) do
      {:ok, %{email: email}} ->
        conn
        |> configure_session(renew: true)
        |> put_session(@session_key, email)
        |> put_flash(:info, "Acceso verificado exitosamente.")
        |> redirect(to: ~p"/")

      {:error, :invalid_or_expired} ->
        conn
        |> put_flash(:error, "El enlace de acceso es inválido o ha expirado.")
        |> redirect(to: ~p"/access")
    end
  end

  def verify(conn, _params) do
    conn
    |> put_flash(:error, "Enlace de acceso no provisto.")
    |> redirect(to: ~p"/access")
  end
end
