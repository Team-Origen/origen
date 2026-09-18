defmodule Origen.BootstrapAdmin.IssueAndDeliverTest do
  use Origen.DataCase, async: false

  import ExUnit.CaptureLog
  alias Origen.BootstrapAdmin
  alias Origen.TestSupport.BootstrapAdmin.{ApprovalFixture, RecordingProvider}

  @key String.duplicate("k", 32)

  defmodule ExplodingProvider do
    def deliver(email, metadata, %{test_pid: pid, provider_failure: failure}) do
      send(pid, {:provider_invoked, email, metadata})

      case failure do
        {:raise, reason} -> raise reason
        {:throw, reason} -> throw(reason)
        {:exit, reason} -> exit(reason)
      end
    end
  end

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    :ok
  end

  test "validates and authorizes before committed issuance, then submits exactly once" do
    request = request()
    parent = self()

    provider = %{
      test_pid: parent,
      result: {:ok, %{correlation_ref: "handoff-42"}},
      before_send: fn invitation_id ->
        assert Repo.query!("SELECT id FROM internal_account_invitations WHERE id = $1", [
                 invitation_id
               ]).rows ==
                 [[invitation_id]]

        assert Repo.query!("SELECT event FROM audit_events WHERE event = 'bootstrap_admin'").rows ==
                 [["bootstrap_admin"]]
      end
    }

    assert {:ok, result} =
             BootstrapAdmin.issue_and_deliver(request,
               gate: fn ->
                 send(parent, {:step, :gate})
                 :ok
               end,
               delivery_config: fn _ ->
                 send(parent, {:step, :config})
                 {:ok, delivery_config(provider)}
               end,
               approval_verifier: fn assertion, requested, config ->
                 send(parent, {:step, :approval})
                 Origen.BootstrapAdmin.ApprovalVerifier.verify(assertion, requested, config)
               end,
               authorize: fn _approval, _request ->
                 send(parent, {:step, :authorization})
                 :ok
               end,
               provider: RecordingProvider
             )

    assert result == %{
             account_id: result.account_id,
             invitation_id: result.invitation_id,
             correlation_ref: "handoff-42",
             outcome: :delivered
           }

    assert_receive {:step, :gate}
    assert_receive {:step, :config}
    assert_receive {:step, :approval}
    assert_receive {:step, :authorization}
    assert_receive {:provider_submission, _email, %{invitation_id: invitation_id}}
    refute_receive {:provider_submission, _, _}
    assert invitation_id == result.invitation_id
  end

  test "every validation denial stops before issuance and provider handoff" do
    for {failed_step, expected} <- [
          gate: :bootstrap_disabled,
          config: :invalid_delivery_config,
          approval: :invalid_approval,
          authorization: :unauthorized
        ] do
      parent = self()

      adapters = [
        gate: fn -> step(parent, :gate, failed_step, expected) end,
        delivery_config: fn _ ->
          step(parent, :config, failed_step, expected, {:ok, delivery_config(%{})})
        end,
        approval_verifier: fn _, _, _ ->
          step(parent, :approval, failed_step, expected, {:ok, approval()})
        end,
        authorize: fn _, _ -> step(parent, :authorization, failed_step, expected) end,
        provider: RecordingProvider
      ]

      assert {:error, ^expected, nil} = BootstrapAdmin.issue_and_deliver(request(), adapters)
      assert Repo.aggregate("internal_account_invitations", :count) == 0
      refute_receive {:provider_submission, _, _}
    end
  end

  test "default authorization accepts verified issue facts and denies unknown operation before Repo" do
    common = [
      gate: fn -> :ok end,
      delivery_config: fn _ ->
        {:ok,
         delivery_config(%{test_pid: self(), result: {:ok, %{correlation_ref: "handoff-7"}}})}
      end,
      approval_verifier: fn _, _, _ -> {:ok, approval()} end,
      provider: RecordingProvider
    ]

    assert {:error, :unauthorized, nil} =
             BootstrapAdmin.issue_and_deliver(%{request() | operation: :unknown}, common)

    assert Repo.aggregate("internal_account_invitations", :count) == 0
    refute_receive {:provider_submission, _, _}

    assert {:ok, %{outcome: :delivered}} = BootstrapAdmin.issue_and_deliver(request(), common)
    assert_receive {:provider_submission, _, _}
  end

  test "safe handoff failure revokes and returns references with fresh-invitation guidance" do
    assert {:error, :delivery_failed, result} =
             BootstrapAdmin.issue_and_deliver(request(),
               gate: fn -> :ok end,
               delivery_config: fn _ ->
                 {:ok, delivery_config(%{test_pid: self(), result: {:error, :timeout}})}
               end,
               approval_verifier: fn _, _, _ -> {:ok, approval()} end,
               authorize: fn _, _ -> :ok end,
               provider: RecordingProvider
             )

    assert result.outcome == :revoked
    assert result.next_action == :obtain_fresh_approval_and_issue_fresh_invitation
    refute inspect(result) =~ "retry"

    assert Repo.query!("SELECT revoked_at FROM internal_account_invitations WHERE id = $1", [
             result.invitation_id
           ]).rows != [[nil]]

    assert_receive {:provider_submission, _, _}
    refute_receive {:provider_submission, _, _}
  end

  test "provider exceptions are compensated without leaking and without retry" do
    for failure <- [
          {:raise, "provider-secret"},
          {:throw, "provider-secret"},
          {:exit, "provider-secret"}
        ] do
      Repo.query!("DELETE FROM internal_account_invitations")
      Repo.query!("DELETE FROM internal_accounts")

      assert {:error, :delivery_failed, safe} =
               BootstrapAdmin.issue_and_deliver(request(),
                 gate: fn -> :ok end,
                 delivery_config: fn _ ->
                   {:ok,
                    delivery_config(%{
                      test_pid: self(),
                      provider_failure: failure
                    })}
                 end,
                 approval_verifier: fn _, _, _ -> {:ok, approval()} end,
                 authorize: fn _, _ -> :ok end,
                 provider: ExplodingProvider
               )

      refute inspect(safe) =~ "provider-secret"
      assert_receive {:provider_invoked, email, %{invitation_id: invitation_id}}
      refute_receive {:provider_invoked, _, _}
      [token] = Regex.run(~r/token=([^\s<]+)/, email.text_body, capture: :all_but_first)
      assert {:error, :invalid_invitation} = BootstrapAdmin.exchange(invitation_id, token, @key)
    end
  end

  test "success and failure prohibited sinks contain no token, address, assertion, URL, or body" do
    parent = self()
    handler = "delivery-sql-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler,
      [:origen, :repo, :query],
      fn _, _, metadata, _ ->
        send(parent, {:sql_metadata, inspect(metadata)})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    log =
      capture_log(fn ->
        assert {:error, :delivery_failed, safe} =
                 BootstrapAdmin.issue_and_deliver(request(),
                   gate: fn -> :ok end,
                   delivery_config: fn _ ->
                     {:ok,
                      delivery_config(%{
                        test_pid: self(),
                        result: {:error, %{body: "provider-body-canary"}}
                      })}
                   end,
                   approval_verifier: fn _, _, _ -> {:ok, approval()} end,
                   authorize: fn _, _ -> :ok end,
                   provider: RecordingProvider
                 )

        send(parent, {:safe_result, inspect(safe)})
      end)

    assert_receive {:provider_submission, email, _}
    secrets = ["santiago@example.test", "approval-123", "provider-body-canary", email.text_body]
    assert_receive {:safe_result, safe_result}
    sql = collect_sql([])

    audit =
      Repo.query!("SELECT actor_ref, entity_ref, event, result FROM audit_events").rows
      |> inspect()

    for sink <- [log, safe_result, sql, audit], secret <- secrets do
      refute String.contains?(sink, secret)
    end
  end

  defp collect_sql(messages) do
    receive do
      {:sql_metadata, metadata} -> collect_sql([metadata | messages])
    after
      0 -> Enum.join(messages)
    end
  end

  defp step(parent, name, failed, reason, success \\ :ok) do
    send(parent, {:step, name})
    if name == failed, do: {:error, reason}, else: success
  end

  defp request do
    %{
      operation: :issue,
      verifier_key: @key,
      issued_by_ref: "operator-samuel",
      approval_assertion: ApprovalFixture.assertion(),
      approval_config: ApprovalFixture.config(),
      delivery_config: %{}
    }
    |> Map.merge(ApprovalFixture.request())
  end

  defp approval do
    {:ok, approval} =
      Origen.BootstrapAdmin.ApprovalVerifier.verify(
        ApprovalFixture.assertion(),
        ApprovalFixture.request(),
        ApprovalFixture.config()
      )

    approval
  end

  defp delivery_config(provider_config) do
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

    Map.merge(Map.from_struct(config), provider_config)
  end
end
