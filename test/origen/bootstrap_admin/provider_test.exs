defmodule Origen.BootstrapAdmin.ProviderTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Provider
  alias Origen.BootstrapAdmin.Providers.Resend
  alias Origen.TestSupport.BootstrapAdmin.{RecordingProvider, SwooshAdapter}

  test "submits exactly once and returns only an approved correlation reference" do
    email = sensitive_email()
    config = %{test_pid: self(), result: {:ok, %{correlation_ref: "delivery_A-42"}}}

    assert {:ok, %{correlation_ref: "delivery_A-42"}} =
             Provider.deliver(RecordingProvider, email, %{invitation_ref: "inv-42"}, config)

    assert_receive {:provider_submission, ^email, %{invitation_ref: "inv-42"}}
    refute_receive {:provider_submission, _, _}
  end

  test "normalizes all failures and malformed or unsafe successes without leaking raw results" do
    email = sensitive_email()

    results = [
      {:error, :timeout},
      {:error, %{body: "raw-provider-body-token-canary"}},
      {:ok, %{correlation_ref: "contains space"}},
      {:ok, %{correlation_ref: String.duplicate("a", 65)}},
      {:ok, %{id: "provider-specific"}},
      {:raise, RuntimeError.exception("raw-provider-body-token-canary")}
    ]

    for result <- results do
      config = %{test_pid: self(), result: result}

      assert {:error, :provider_handoff_failed} =
               Provider.deliver(RecordingProvider, email, %{}, config)

      assert_receive {:provider_submission, ^email, %{}}
      refute inspect(Provider.deliver_result(result)) =~ "raw-provider-body-token-canary"
    end
  end

  test "the transactional adapter resolves credentials at handoff and calls Swoosh once" do
    email = sensitive_email()

    Process.put(:bootstrap_admin_test_pid, self())
    Process.put(:bootstrap_admin_swoosh_result, {:ok, %{id: "resend_A-42"}})

    config = %{
      credential_resolver: fn -> {:ok, "synthetic-api-key"} end,
      swoosh_adapter: SwooshAdapter
    }

    assert {:ok, %{correlation_ref: "resend_A-42"}} = Resend.deliver(email, %{}, config)
    assert_receive {:swoosh_submission, ^email, [api_key: "synthetic-api-key"]}
    refute_receive {:swoosh_submission, _, _}
  end

  test "the transactional adapter fails safely without credentials or a valid response" do
    email = sensitive_email()

    assert {:error, :provider_handoff_failed} =
             Resend.deliver(email, %{}, %{
               credential_resolver: fn -> {:error, "credential-canary"} end,
               swoosh_adapter: SwooshAdapter
             })

    refute_receive {:swoosh_submission, _, _}
  end

  test "rejects retaining adapters outside the test-only provider seam" do
    for adapter <- [Swoosh.Adapters.Local, Swoosh.Adapters.Test, Plug.Swoosh.MailboxPreview] do
      assert {:error, :provider_handoff_failed} =
               Provider.deliver(adapter, sensitive_email(), %{}, %{})
    end
  end

  defp sensitive_email do
    Swoosh.Email.new()
    |> Swoosh.Email.to("private-address@example.test")
    |> Swoosh.Email.from("from@example.test")
    |> Swoosh.Email.text_body("https://approved-host/admin/activate#token=token-canary")
  end
end
