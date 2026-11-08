defmodule Origen.BootstrapAdmin.OriginTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Origin

  test "accepts only the exact approved HTTPS staging activation location" do
    assert {:ok, origin} =
             Origin.validate("https://approved-host/administrador/activar", %{
               environment: "staging",
               approved_hosts: ["approved-host"]
             })

    assert Origin.to_uri(origin) == "https://approved-host/administrador/activar"
  end

  test "rejects ambiguous, spoofed, encoded, and non-staging locations" do
    unsafe = [
      "http://approved-host/administrador/activar",
      "https://user@approved-host/administrador/activar",
      "https://approved-host/administrador/activar?next=x",
      "https://approved-host/administrador/activar#fragment",
      "https://approved-host/administrador/activar/",
      "https://approved-host.evil/administrador/activar",
      "https://%61pproved-host/administrador/activar",
      "https://approved-host%2eevil/administrador/activar",
      "https://approved-host:444/administrador/activar",
      "https://evil-approved-host/administrador/activar",
      "https://*.approved-host/administrador/activar",
      "https://approved-host/admin/%2e%2e/activar",
      "https://approved-host/admin%2Factivate",
      "https://approved-host/admin\\activate",
      "https://approved-host/administrador/activar\n"
    ]

    for uri <- unsafe do
      assert {:error, reason} =
               Origin.validate(uri, %{environment: "staging", approved_hosts: ["approved-host"]})

      refute inspect(reason) =~ uri
    end

    assert {:error, :production_denied} =
             Origin.validate("https://approved-host/administrador/activar", %{
               environment: "production",
               approved_hosts: ["approved-host"]
             })
  end

  test "rejects malformed origins without performing I/O or raising" do
    for value <- [nil, "", "not a uri", <<0, 255>>, "https://APPROVED-HOST/administrador/activar"] do
      assert {:error, _safe_reason} =
               Origin.validate(value, %{environment: "staging", approved_hosts: ["approved-host"]})
    end
  end
end
