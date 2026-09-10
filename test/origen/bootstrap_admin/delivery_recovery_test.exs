defmodule Origen.BootstrapAdmin.DeliveryRecoveryTest do
  use Origen.DataCase, async: false

  alias Origen.BootstrapAdmin
  alias Origen.TestSupport.BootstrapAdmin.{ApprovalFixture, RecordingProvider}

  @key String.duplicate("k", 32)

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    :ok
  end

  test "failed token is never resubmitted and recovery requires fresh approval and token" do
    assert {:error, :delivery_failed, failed} = deliver(issue_request(), {:error, :timeout})
    assert_receive {:provider_submission, failed_email, _}
    refute_receive {:provider_submission, _, _}

    stale_request =
      reissue_request(failed.account_id, ApprovalFixture.assertion(%{operation: :issue}))

    assert {:error, :approval_mismatch, nil} =
             deliver(stale_request, {:ok, %{correlation_ref: "unused"}})

    refute_receive {:provider_submission, _, _}

    fresh_assertion =
      ApprovalFixture.assertion(%{
        approval_id: "approval-456",
        operation: :reissue,
        account_ref: failed.account_id
      })

    assert {:ok, replacement} =
             deliver(
               reissue_request(failed.account_id, fresh_assertion),
               {:ok, %{correlation_ref: "handoff-456"}}
             )

    assert_receive {:provider_submission, replacement_email, _}
    refute failed_email.text_body == replacement_email.text_body
    refute failed.invitation_id == replacement.invitation_id
    assert replacement.outcome == :delivered
  end

  defp deliver(request, result) do
    BootstrapAdmin.issue_and_deliver(request,
      gate: fn -> :ok end,
      delivery_config: fn _ -> {:ok, delivery_config(result)} end,
      approval_verifier: &Origen.BootstrapAdmin.ApprovalVerifier.verify/3,
      authorize: fn _, _ -> :ok end,
      provider: RecordingProvider
    )
  end

  defp issue_request do
    base_request(:issue, nil, ApprovalFixture.assertion())
  end

  defp reissue_request(account_id, assertion) do
    base_request(:reissue, account_id, assertion)
  end

  defp base_request(operation, account_ref, assertion) do
    ApprovalFixture.request(%{operation: operation, account_ref: account_ref})
    |> Map.merge(%{
      verifier_key: @key,
      issued_by_ref: "operator-samuel",
      approval_assertion: assertion,
      approval_config: ApprovalFixture.config(),
      delivery_config: %{}
    })
  end

  defp delivery_config(result) do
    {:ok, config} =
      Origen.BootstrapAdmin.DeliveryConfig.validate(%{
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
      })

    config |> Map.from_struct() |> Map.merge(%{test_pid: self(), result: result})
  end
end
