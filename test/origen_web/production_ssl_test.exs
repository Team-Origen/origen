defmodule OrigenWeb.ProductionSSLTest do
  use ExUnit.Case, async: true

  test "production HTTP health checks reach the router without a redirect" do
    conn = ssl_request("/health")

    assert conn.status == nil
    refute conn.halted
    assert Plug.Conn.get_resp_header(conn, "location") == []
  end

  test "production HTTP requests to other paths still redirect to HTTPS" do
    conn = ssl_request("/other")

    assert conn.status == 301
    assert conn.halted
    assert Plug.Conn.get_resp_header(conn, "location") == ["https://probe.invalid/other"]
  end

  defp ssl_request(path) do
    config = Config.Reader.read!("config/prod.exs", env: :prod)
    options = config[:origen][OrigenWeb.Endpoint][:force_ssl]

    Plug.Test.conn(:get, "http://probe.invalid" <> path)
    |> Plug.SSL.call(Plug.SSL.init(options))
  end
end
