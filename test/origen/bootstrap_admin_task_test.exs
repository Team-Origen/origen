defmodule Origen.BootstrapAdminTaskTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  setup do
    keys = [
      :bootstrap_admin_enabled,
      :bootstrap_admin_profile,
      :bootstrap_admin_local_enabled,
      :bootstrap_admin_local,
      :bootstrap_admin_command_options
    ]

    previous = Map.new(keys, &{&1, Application.fetch_env(:origen, &1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:origen, key, value)
        {key, :error} -> Application.delete_env(:origen, key)
      end)
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

  test "local selection in compiled test denies before parser and every downstream seam" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_profile, :local)
    Application.put_env(:origen, :bootstrap_admin_local_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_local, %{enabled: true})

    Application.put_env(:origen, :bootstrap_admin_command_options,
      local_parser: fn _ -> flunk("local parser called") end,
      local_command: fn _ -> flunk("local command called") end,
      approval_reader: fn _ -> flunk("staging protected input called") end,
      orchestrator: fn _, _ -> flunk("Repo/token/delivery seam called") end
    )

    secret = "local-secret-argv-canary"
    output = capture_task_error(["--token", secret], "Bootstrap admin request was rejected")
    refute output =~ secret
  end

  test "unknown trusted selector denies without trying staging" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_profile, :unknown)

    Application.put_env(:origen, :bootstrap_admin_command_options,
      approval_reader: fn _ -> flunk("staging fallback called") end,
      orchestrator: fn _, _ -> flunk("staging fallback called") end
    )

    assert capture_task_error([], "Bootstrap admin request was rejected") == ""
  end

  test "profile and delivery selection cannot be supplied in argv" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_profile, :staging)

    Application.put_env(:origen, :bootstrap_admin_command_options,
      approval_reader: fn _ -> flunk("protected input read") end
    )

    for argv <- [
          ["--profile", "local"],
          ["--destination", "student@example.test"],
          ["--adapter", "Elixir.Swoosh.Adapters.Local"]
        ] do
      capture_task_error(argv, "Bootstrap admin received invalid command-line arguments")
    end
  end

  test "local reference-only parser accepts only empty argv or one positive account id" do
    alias Origen.BootstrapAdmin.Command

    assert Command.parse_local_args([]) == {:ok, %{account_id: nil}}
    assert Command.parse_local_args(["--account-id", "17"]) == {:ok, %{account_id: 17}}
    assert Command.parse_local_args(["--account-id=19"]) == {:ok, %{account_id: 19}}

    for argv <- [
          ["--account-id", "0"],
          ["--account-id", "1", "--account-id", "2"],
          ["--account-id=1", "--account-id=2"],
          ["--profile", "local"],
          ["--token", "secret-canary"],
          ["--url", "https://127.0.0.1/secret-canary"],
          ["extra"]
        ] do
      assert Command.parse_local_args(argv) == {:error, :invalid_arguments}
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
