defmodule OrigenWeb.PatientSessionAuthLive do
  @moduledoc """
  LiveView authorization hooks for passwordless patient sessions.

  Patient access is granted only after a Magic Link has established both the
  patient email and its authentication timestamp in the browser session.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]

  alias Origen.Patients

  def on_mount(:ensure_authenticated, _params, session, socket) do
    email = Map.get(session, "patient_email") || Map.get(session, :patient_email)

    authenticated_at =
      Map.get(session, "patient_authenticated_at") ||
        Map.get(session, :patient_authenticated_at)

    case Patients.verify_patient_session(email, authenticated_at) do
      {:ok, profile} ->
        {:cont, assign(socket, :current_patient_profile, Origen.Repo.preload(profile, :persona))}

      {:error, _reason} ->
        {:halt, redirect(socket, to: "/paciente/acceso")}
    end
  end

  def on_mount(:deny_self_edit, _params, _session, socket) do
    socket = put_flash(socket, :error, "La edición autónoma del perfil no está habilitada.")
    {:halt, redirect(socket, to: "/")}
  end
end
