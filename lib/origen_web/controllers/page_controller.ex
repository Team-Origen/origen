defmodule OrigenWeb.PageController do
  use OrigenWeb, :controller

  def home(conn, _params) do
    patient_email = get_session(conn, :patient_email)
    render(conn, :home, current_patient: patient_email)
  end

  def dev_login_secretary(conn, _params) do
    query = """
    SELECT id FROM internal_accounts WHERE role = 'secretary' AND state = 'active' LIMIT 1
    """

    case Origen.Repo.query(query, []) do
      {:ok, %{rows: [[id]]}} ->
        {:ok, _session, token} = Origen.Sessions.create_session(id)

        conn
        |> put_session(:internal_session_token, token)
        |> redirect(to: ~p"/secretaria/pacientes")

      _ ->
        conn
        |> put_flash(:error, "No se encontró cuenta de secretaría activa.")
        |> redirect(to: ~p"/")
    end
  end
end
