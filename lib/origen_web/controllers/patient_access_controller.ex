defmodule OrigenWeb.PatientAccessController do
  @moduledoc """
  Controller to handle patient magic link consumption via /paciente/acceso/verificar.
  """

  use OrigenWeb, :controller

  alias Origen.PatientAccess

  @session_key :patient_email

  @doc """
  Consumes a magic link token passed in query parameters.
  On success, establishes the patient session and redirects.
  On failure, redirects back to /paciente/acceso with a non-enumerating error message.
  """
  def verify(conn, %{"token" => token}) when is_binary(token) and token != "" do
    case PatientAccess.consume_magic_link(token) do
      {:ok, %{email: email}} ->
        conn
        |> configure_session(renew: true)
        |> put_session(@session_key, email)
        |> put_session(:patient_authenticated_at, DateTime.to_iso8601(DateTime.utc_now()))
        |> put_flash(:info, "Acceso verificado exitosamente.")
        |> redirect(to: ~p"/paciente/turnos/reservar")

      {:error, :invalid_or_expired} ->
        conn
        |> put_flash(:error, "El enlace de acceso es inválido o ha expirado.")
        |> redirect(to: ~p"/paciente/acceso")
    end
  end

  def verify(conn, _params) do
    conn
    |> put_flash(:error, "Enlace de acceso no provisto.")
    |> redirect(to: ~p"/paciente/acceso")
  end

  @doc """
  Signs out the current browser's patient session without terminating any
  coexisting internal session. Patient sessions use signed cookies; this does
  not revoke copied cookies or patient sessions on other devices.
  """
  def delete(conn, _params) do
    conn
    |> delete_session(:patient_email)
    |> delete_session(:patient_authenticated_at)
    |> configure_session(renew: true)
    |> redirect(to: ~p"/paciente/acceso")
  end
end
