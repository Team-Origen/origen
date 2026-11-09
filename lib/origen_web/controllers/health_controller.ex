defmodule OrigenWeb.HealthController do
  use OrigenWeb, :controller

  def index(conn, _params) do
    if database_available?() do
      send_resp(conn, 200, "ok")
    else
      send_resp(conn, 503, "unavailable")
    end
  end

  defp database_available? do
    try do
      case Ecto.Adapters.SQL.query(Origen.Repo, "SELECT 1", [], timeout: 1_000, log: false) do
        {:ok, _result} -> true
        {:error, _reason} -> false
      end
    catch
      :exit, {_reason, {DBConnection.Holder, :checkout, [_pool, _opts]}} -> false
    end
  end
end
