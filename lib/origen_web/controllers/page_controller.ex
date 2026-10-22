defmodule OrigenWeb.PageController do
  use OrigenWeb, :controller

  def home(conn, _params) do
    patient_email = get_session(conn, :patient_email)
    render(conn, :home, current_patient: patient_email)
  end
end
