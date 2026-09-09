defmodule Origen.BootstrapAdmin.DeliverySecurityTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  alias Origen.BootstrapAdmin.Provider
  alias Origen.TestSupport.BootstrapAdmin.RecordingProvider

  test "secrets remain absent from logs, telemetry, errors, results, metadata, and support output" do
    secrets = [
      "token-canary-01",
      "private-address@example.test",
      "message-body-canary",
      "https://approved-host/admin/activate#invitation_id=inv-1&token=token-canary-01"
    ]

    email =
      Swoosh.Email.new()
      |> Swoosh.Email.to(Enum.at(secrets, 1))
      |> Swoosh.Email.from("from@example.test")
      |> Swoosh.Email.text_body(Enum.at(secrets, 2) <> " " <> Enum.at(secrets, 3))

    handler = "provider-security-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach(
      handler,
      [:origen, :bootstrap_admin, :provider],
      fn name, measurements, metadata, _ ->
        send(parent, {:telemetry, name, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    log =
      capture_log(fn ->
        assert {:error, :provider_handoff_failed} =
                 Provider.deliver(RecordingProvider, email, %{invitation_ref: "inv-1"}, %{
                   test_pid: self(),
                   result: {:error, %{response_body: Enum.at(secrets, 2)}}
                 })
      end)

    assert_receive {:provider_submission, ^email, %{invitation_ref: "inv-1"}}
    refute_receive {:telemetry, _, _, _}

    safe_surfaces = [
      log,
      inspect({:error, :provider_handoff_failed}),
      inspect(%{result: :failed, invitation_ref: "inv-1"}),
      RecordingProvider.support_summary()
    ]

    Enum.each(secrets, fn secret ->
      refute Enum.any?(safe_surfaces, &String.contains?(&1, secret))
    end)
  end

  test "variant failures submit once and always return the same safe reason" do
    for {token, raw_result} <- [
          {"token-A", {:error, :timeout}},
          {"token-B", {:error, :transport_closed}},
          {"token-C", {:error, {:rejected, "private-address@example.test"}}},
          {"token-D", {:ok, %{correlation_ref: "bad/ref"}}}
        ] do
      email = Swoosh.Email.new() |> Swoosh.Email.text_body(token)

      assert {:error, :provider_handoff_failed} =
               Provider.deliver(RecordingProvider, email, %{invitation_ref: "safe-ref"}, %{
                 test_pid: self(),
                 result: raw_result
               })

      assert_receive {:provider_submission, ^email, %{invitation_ref: "safe-ref"}}
      refute_receive {:provider_submission, _, _}
    end
  end
end
