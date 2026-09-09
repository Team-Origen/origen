defmodule Origen.BootstrapAdminTaskTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  setup do
    enabled = Application.get_env(:origen, :bootstrap_admin_enabled)
    command_options = Application.get_env(:origen, :bootstrap_admin_command_options)

    on_exit(fn ->
      restore(:bootstrap_admin_enabled, enabled)
      restore(:bootstrap_admin_command_options, command_options)
    end)
  end

  test "closed and malformed gates stop before parsing, protected input, and output" do
    secret = "argv-secret-canary"

    for enabled <- [false, "true", nil] do
      restore(:bootstrap_admin_enabled, enabled)

      Application.put_env(:origen, :bootstrap_admin_command_options,
        approval_reader: fn _ -> flunk("later seam called") end,
        orchestrator: fn _, _ -> flunk("later seam called") end
      )

      output = capture_task_error(["--token", secret], "Bootstrap admin is disabled")

      refute output =~ secret
    end
  end

  test "rejects secret-bearing argv with sanitized output and no protected-input read" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)

    Application.put_env(:origen, :bootstrap_admin_command_options,
      approval_reader: fn ref ->
        if ref == "safe", do: {:ok, :invalid}, else: flunk("protected input read")
      end
    )

    for argv <- [
          ["--email", "private@example.test"],
          ["--verifier-key", "key-canary"],
          ["--approval-assertion", "assertion-canary"],
          ["--token", "token-canary"],
          ["--url", "https://example.test/#token-canary"],
          ["--approval-input-ref", "safe", "--issued-by-ref", "bad ref"],
          ["--approval-input-ref", "safe", "--approval-input-ref", "other"],
          ["--approval-input-ref", "safe", "--account-id", "0"]
        ] do
      output =
        capture_task_error(argv, "Bootstrap admin received invalid command-line arguments")

      Enum.each(argv, &refute(output =~ &1))
    end

    assert_raise Mix.Error, "Bootstrap admin request was rejected", fn ->
      run_task(["--approval-input-ref", "safe"])
    end
  end

  test "prints only safe references for success and compensated failure" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    parent = self()

    for {result, expected} <- [
          {{:ok, %{account_id: 7, invitation_id: 9, correlation_ref: "handoff-42"}},
           "delivered; account reference: 7; invitation reference: 9; provider reference: handoff-42"},
          {{:error, :delivery_failed, %{account_id: 7, invitation_id: 9}},
           "Bootstrap admin delivery failed; account reference: 7; invitation reference: 9; obtain fresh approval and issue a fresh invitation"}
        ] do
      Application.put_env(:origen, :bootstrap_admin_command_options,
        approval_reader: fn "approval-ref-1" ->
          {:ok,
           %{
             approval_assertion: %{secret: "assertion-canary"},
             approval_config: %{secret: "verifier-canary"},
             destination: "private@example.test",
             environment: "staging",
             verifier_key: String.duplicate("v", 32)
           }}
        end,
        orchestrator: fn request, _ ->
          send(parent, {:protected_request, request})
          result
        end,
        delivery_config: %{},
        provider: SyntheticProvider
      )

      args = ["--approval-input-ref", "approval-ref-1"]

      output =
        if match?({:ok, _}, result),
          do: capture_task(args),
          else: capture_task_error(args, expected)

      if match?({:ok, _}, result), do: assert(output =~ expected)
      assert_receive {:protected_request, %{destination: "private@example.test"}}
      refute_receive {:protected_request, _}

      for secret <- ["assertion-canary", "verifier-canary", "private@example.test"] do
        refute output =~ secret
      end
    end
  end

  defp capture_task(args), do: capture_io(fn -> run_task(args) end)

  defp capture_task_error(args, message) do
    capture_io(:stderr, fn -> assert_raise Mix.Error, message, fn -> run_task(args) end end)
  end

  defp run_task(args) do
    Mix.Task.reenable("origen.bootstrap_admin")
    Mix.Task.run("origen.bootstrap_admin", args)
  end

  defp restore(key, nil), do: Application.delete_env(:origen, key)
  defp restore(key, value), do: Application.put_env(:origen, key, value)
end
