defmodule Origen.BootstrapAdmin.ApprovalVerifierTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.{Approval, ApprovalVerifier}
  alias Origen.TestSupport.BootstrapAdmin.ApprovalFixture

  test "accepts a signed, bounded approval from a distinct authorized confirmer" do
    assert {:ok, approval} =
             ApprovalVerifier.verify(
               ApprovalFixture.assertion(),
               ApprovalFixture.request(),
               ApprovalFixture.config()
             )

    assert approval.approval_id == "approval-123"
    assert approval.confirmer_ref == "security-reviewer"
  end

  test "rejects signature, key, time, principal, environment, and request binding failures safely" do
    cases = [
      {ApprovalFixture.assertion(%{signature: "bad"}), ApprovalFixture.request(), %{},
       :invalid_signature},
      {ApprovalFixture.assertion(%{key_id: "unknown"}), ApprovalFixture.request(), %{},
       :unapproved_key},
      {ApprovalFixture.assertion(%{expires_at: ApprovalFixture.now()}), ApprovalFixture.request(),
       %{}, :approval_not_current},
      {ApprovalFixture.assertion(%{issued_at: DateTime.add(ApprovalFixture.now(), 1, :second)}),
       ApprovalFixture.request(), %{}, :approval_not_current},
      {ApprovalFixture.assertion(%{confirmer_ref: "operator-samuel"}), ApprovalFixture.request(),
       %{}, :self_approval},
      {ApprovalFixture.assertion(%{confirmer_ref: "unknown-reviewer"}), ApprovalFixture.request(),
       %{}, :unauthorized_confirmer},
      {ApprovalFixture.assertion(%{environment: "production"}),
       ApprovalFixture.request(%{environment: "production"}), %{}, :production_denied},
      {ApprovalFixture.assertion(), ApprovalFixture.request(%{destination: "other@example.test"}),
       %{}, :approval_mismatch},
      {ApprovalFixture.assertion(), ApprovalFixture.request(%{environment: "preview"}), %{},
       :production_denied},
      {ApprovalFixture.assertion(), ApprovalFixture.request(%{operation: :reissue}), %{},
       :approval_mismatch},
      {ApprovalFixture.assertion(), ApprovalFixture.request(%{account_ref: "account-42"}), %{},
       :approval_mismatch}
    ]

    for {assertion, request, config_overrides, reason} <- cases do
      assert ApprovalVerifier.verify(
               assertion,
               request,
               ApprovalFixture.config(config_overrides)
             ) == {:error, reason}
    end
  end

  test "newline redistribution cannot preserve authorization" do
    assertion =
      ApprovalFixture.assertion(%{
        destination: "line-one\nline-two",
        account_ref: "line-three"
      })

    redistributed = %{
      assertion
      | destination: "line-one",
        account_ref: "line-two\nline-three"
    }

    refute Approval.signing_payload(assertion) == Approval.signing_payload(redistributed)

    request =
      ApprovalFixture.request(%{
        destination: redistributed.destination,
        account_ref: redistributed.account_ref
      })

    assert ApprovalVerifier.verify(redistributed, request, ApprovalFixture.config()) ==
             {:error, :invalid_signature}
  end

  test "only the exact staging environment is approved" do
    for environment <- [
          "production",
          "prod",
          "Production",
          "Staging",
          "stagin",
          "preview",
          "arbitrary"
        ] do
      assertion = ApprovalFixture.assertion(%{environment: environment})
      request = ApprovalFixture.request(%{environment: environment})

      assert ApprovalVerifier.verify(assertion, request, ApprovalFixture.config()) ==
               {:error, :production_denied}
    end
  end

  test "safe failures never echo secret-like assertion references" do
    secret = "https://secret.invalid/assertion?token=canary"
    assertion = ApprovalFixture.assertion(%{approval_id: secret, signature: "bad"})

    assert {:error, reason} =
             ApprovalVerifier.verify(
               assertion,
               ApprovalFixture.request(),
               ApprovalFixture.config()
             )

    refute inspect(reason) =~ secret
  end
end
