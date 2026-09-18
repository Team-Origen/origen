defmodule OrigenWeb.RawBodyReader do
  @moduledoc false

  def read_body(conn, options) do
    case Plug.Conn.read_body(conn, options) do
      {status, body, conn} when status in [:ok, :more] ->
        accumulated = Map.get(conn.assigns, :raw_body, "") <> body
        {status, body, Plug.Conn.assign(conn, :raw_body, accumulated)}

      other ->
        other
    end
  end
end
