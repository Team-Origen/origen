defmodule Origen.BootstrapAdmin.DeliveryConfigTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.DeliveryConfig

  test "accepts a complete staging-only non-retaining provider capability declaration" do
    assert {:ok, config} = DeliveryConfig.validate(valid_config())
    assert config.environment == "staging"
    assert config.retention_ttl_seconds == 3_600
  end

  test "fails closed for disabled, retaining, unbounded, retrying, and unaudited configuration" do
    invalid = [
      {%{enabled: false}, :delivery_disabled},
      {%{adapter: Swoosh.Adapters.Test}, :invalid_delivery_config},
      {%{allowed_adapters: []}, :invalid_delivery_config},
      {%{retention_ttl_seconds: 7_201}, :invalid_delivery_config},
      {%{retries: 2}, :invalid_delivery_config},
      {%{encrypted_retention: false}, :invalid_delivery_config},
      {%{access_audit: false}, :invalid_delivery_config},
      {%{least_privilege_access: false}, :invalid_delivery_config},
      {%{access_audit_ref: "https://secret.invalid/token"}, :invalid_delivery_config},
      {%{correlation: %{pattern: "arbitrary", max_length: 64}}, :invalid_delivery_config},
      {%{correlation: %{pattern: ~r/.*/, max_length: 129}}, :invalid_delivery_config},
      {%{environment: "production"}, :production_denied}
    ]

    for {overrides, reason} <- invalid do
      assert DeliveryConfig.validate(Map.merge(valid_config(), overrides)) == {:error, reason}
    end

    assert {:error, _safe_reason} =
             DeliveryConfig.validate(%{
               enabled: true,
               environment: "staging",
               activation_origin: "https://approved-host/admin/activate",
               approved_hosts: ["approved-host"]
             })
  end

  test "validation is pure and safe errors do not contain configured references" do
    secret_ref = "https://secret.invalid/config?token=canary"
    config = Map.put(valid_config(), :access_audit_ref, secret_ref)

    assert {:error, reason} = DeliveryConfig.validate(config)
    refute inspect(reason) =~ secret_ref
  end

  defp valid_config do
    %{
      enabled: true,
      environment: "staging",
      activation_origin: "https://approved-host/admin/activate",
      approved_hosts: ["approved-host"],
      from: "bootstrap@approved-host",
      adapter: Origen.TestSupport.BootstrapAdmin.NonRetainingAdapter,
      allowed_adapters: [Origen.TestSupport.BootstrapAdmin.NonRetainingAdapter],
      provider_account: "staging-account",
      encrypted_retention: true,
      retention_ttl_seconds: 3_600,
      max_retention_ttl_seconds: 7_200,
      retries: :disabled,
      access_audit: true,
      access_audit_ref: "audit-control-42",
      least_privilege_access: true,
      correlation: %{pattern: ~r/^[A-Za-z0-9_-]+$/, max_length: 64}
    }
  end
end
