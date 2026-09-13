defmodule Origen.BootstrapAdmin.Local.OriginTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Local.Origin

  @endpoint %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false}
  @origin "https://127.0.0.1:4443/admin/activate"

  test "accepts only the literal loopback HTTPS activation origin" do
    assert {:ok, origin} = Origin.validate(@origin, @endpoint)
    assert Origin.to_uri(origin) == @origin
    refute inspect(origin) =~ @origin
  end

  test "rejects unsafe endpoint binds and an HTTP or second listener" do
    for endpoint <- [
          %{@endpoint | scheme: :http},
          %{@endpoint | ip: {0, 0, 0, 0}},
          %{@endpoint | ip: {127, 0, 0, 2}},
          %{@endpoint | http: true},
          Map.put(@endpoint, :http_port, 4000),
          %{scheme: :https, ip: "127.0.0.1", port: 4443, http: false}
        ] do
      assert Origin.validate(@origin, endpoint) == {:error, :unsafe_origin}
    end
  end

  test "rejects all non-literal origin variants" do
    invalid = [
      "http://127.0.0.1:4443/admin/activate",
      "https://localhost:4443/admin/activate",
      "https://127.0.0.1/admin/activate",
      "https://127.0.0.1:4444/admin/activate",
      "https://user@127.0.0.1:4443/admin/activate",
      "https://127.0.0.1:4443/admin/activate/",
      "https://127.0.0.1:4443/admin/activate?next=x",
      "https://127.0.0.1:4443/admin/activate#fragment",
      "https://127.0.0.1%3A4443/admin/activate",
      "https://127.0.0.1:4443/admin\\activate"
    ]

    for value <- invalid do
      assert Origin.validate(value, @endpoint) == {:error, :unsafe_origin}
    end
  end
end
