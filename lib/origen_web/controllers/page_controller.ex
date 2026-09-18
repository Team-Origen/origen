defmodule OrigenWeb.PageController do
  use OrigenWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
