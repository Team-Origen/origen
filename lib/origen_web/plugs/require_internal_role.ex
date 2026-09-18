defmodule OrigenWeb.Plugs.RequireInternalRole do
  @moduledoc """
  Authorizes an authenticated internal account against an explicit role list.

  Unknown configured roles and missing or untrusted assignments fail closed.
  """

  import Plug.Conn

  @behaviour Plug
  @internal_roles [:administrator, :professional, :secretary]

  @impl Plug
  def init(opts) do
    roles =
      opts
      |> Keyword.get(:roles, [])
      |> List.wrap()
      |> Enum.filter(&(&1 in @internal_roles))
      |> Enum.uniq()

    Keyword.put(opts, :roles, roles)
  end

  @impl Plug
  def call(conn, opts) do
    if conn.assigns[:current_role] in Keyword.fetch!(opts, :roles) do
      conn
    else
      conn
      |> send_resp(:forbidden, "Forbidden")
      |> halt()
    end
  end
end
