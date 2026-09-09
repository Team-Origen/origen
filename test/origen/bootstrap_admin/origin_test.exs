defmodule Origen.BootstrapAdmin.OriginTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Origin

  test "accepts only the exact approved HTTPS staging activation location" do
    assert {:ok, origin} =
             Origin.validate("https://approved-host/admin/activate", %{
               environment: "staging",
               approved_hosts: ["approved-host"]
             })

    assert Origin.to_uri(origin) == "https://approved-host/admin/activate"
  end

  test "rejects ambiguous, spoofed, encoded, and non-staging locations" do
    unsafe = [
      "http://approved-host/admin/activate",
      "https://user@approved-host/admin/activate",
      "https://approved-host/admin/activate?next=x",
      "https://approved-host/admin/activate#fragment",
      "https://approved-host/admin/activate/",
      "https://approved-host.evil/admin/activate",
      "https://%61pproved-host/admin/activate",
      "https://approved-host%2eevil/admin/activate",
      "https://approved-host:444/admin/activate",
      "https://evil-approved-host/admin/activate",
      "https://*.approved-host/admin/activate",
      "https://approved-host/admin/%2e%2e/activate",
      "https://approved-host/admin%2Factivate",
      "https://approved-host/admin\\activate",
      "https://approved-host/admin/activate\n"
    ]

    for uri <- unsafe do
      assert {:error, reason} =
               Origin.validate(uri, %{environment: "staging", approved_hosts: ["approved-host"]})

      refute inspect(reason) =~ uri
    end

    assert {:error, :production_denied} =
             Origin.validate("https://approved-host/admin/activate", %{
               environment: "production",
               approved_hosts: ["approved-host"]
             })
  end

  test "rejects malformed origins without performing I/O or raising" do
    for value <- [nil, "", "not a uri", <<0, 255>>, "https://APPROVED-HOST/admin/activate"] do
      assert {:error, _safe_reason} =
               Origin.validate(value, %{environment: "staging", approved_hosts: ["approved-host"]})
    end
  end
end
