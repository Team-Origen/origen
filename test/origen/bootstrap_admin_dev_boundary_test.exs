# Run under real dev compilation without loading the SQL Sandbox test helper.
# ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true MIX_ENV=dev mix run --no-start -e 'ExUnit.start(autorun: false); Code.require_file("test/origen/bootstrap_admin_dev_boundary_test.exs"); %{failures: failures} = ExUnit.run(); System.halt(if(failures == 0, do: 0, else: 1))'
if Mix.env() == :dev do
  defmodule Origen.BootstrapAdminDevBoundaryTest do
    use ExUnit.Case, async: false

    import ExUnit.CaptureIO
    import ExUnit.CaptureLog

    defmodule RejectingSession do
      def start_session(_config, _options) do
        send(test_process(), :startup_attempted)
        {:error, :local_endpoint_invalid}
      end

      def await, do: flunk("lifecycle must not await after rejected startup")

      def cleanup do
        send(test_process(), :cleanup_attempted)
        :ok
      end

      defp test_process, do: Application.fetch_env!(:origen, :bootstrap_admin_test_process)
    end

    defmodule RecordingSession do
      def start_session(_config, _options) do
        send(test_process(), :unexpected_startup)
        :ok
      end

      def await, do: send(test_process(), :unexpected_await)
      def cleanup, do: send(test_process(), :cleanup_attempted)
      defp test_process, do: Application.fetch_env!(:origen, :bootstrap_admin_test_process)
    end

    setup do
      keys = [
        :bootstrap_admin_enabled,
        :bootstrap_admin_profile,
        :bootstrap_admin_local_enabled,
        :bootstrap_admin_local,
        :bootstrap_admin_test_process
      ]

      previous = Map.new(keys, &{&1, Application.fetch_env(:origen, &1)})

      directory =
        Path.join(System.tmp_dir!(), "origen-bootstrap-#{System.unique_integer([:positive])}")

      File.mkdir_p!(directory)

      files =
        for name <- ["certificate", "certificate-key", "verifier-key", "totp-key"] do
          path = Path.join(directory, name)
          File.write!(path, "fixture")
          File.chmod!(path, 0o600)
          path
        end

      [certificate, certificate_key, verifier_key, totp_key] = files
      Application.put_env(:origen, :bootstrap_admin_enabled, true)
      Application.put_env(:origen, :bootstrap_admin_profile, :local)
      Application.put_env(:origen, :bootstrap_admin_local_enabled, true)
      Application.put_env(:origen, :bootstrap_admin_test_process, self())

      complete_config = %{
        enabled: true,
        profile: :local,
        channel: :source_checkout,
        destination: "public-boundary-canary@example.test",
        activation_origin: "https://127.0.0.1:4443/admin/activate",
        endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false},
        mailer: Origen.Mailer,
        adapter: Swoosh.Adapters.Local,
        storage: Swoosh.Adapters.Local.Storage.Memory,
        preview: Plug.Swoosh.MailboxPreview,
        retention_owner: Origen.BootstrapAdmin.Local.Mailbox,
        retention_ttl_seconds: 60,
        max_messages: 1,
        certificate_file: certificate,
        certificate_key_file: certificate_key,
        verifier_key_file: verifier_key,
        totp_key_file: totp_key,
        totp_key_tag: "local-totp",
        database_name: "origen_dev",
        database_scope: :isolated_workstation
      }

      Application.put_env(:origen, :bootstrap_admin_local, complete_config)

      on_exit(fn ->
        Enum.each(previous, fn
          {key, {:ok, value}} -> Application.put_env(:origen, key, value)
          {key, :error} -> Application.delete_env(:origen, key)
        end)

        File.rm_rf!(directory)
      end)

      {:ok, complete_config: complete_config}
    end

    test "public task starts the application before calling the supervised local endpoint" do
      Application.stop(:origen)
      assert Process.whereis(Origen.BootstrapAdmin.Local.Endpoint) == nil

      task =
        spawn(fn ->
          Mix.Task.reenable("origen.bootstrap_admin")
          Mix.Task.run("origen.bootstrap_admin", [])
        end)

      on_exit(fn -> if Process.alive?(task), do: Process.exit(task, :kill) end)

      assert eventually(fn -> Process.whereis(Origen.BootstrapAdmin.Local.Endpoint) != nil end)
    end

    test "forbidden local argv is rejected before startup and downstream boundaries" do
      secret = "forbidden-local-argv-canary"

      output =
        capture_rejection(
          RecordingSession,
          fn _args, _channel, _options ->
            flunk("command runner, Repo, mailbox, secrets, or lifecycle called")
          end,
          "Bootstrap admin received invalid command-line arguments",
          ["--token", secret]
        )

      refute_receive :unexpected_startup
      refute_receive :unexpected_await
      refute_receive :cleanup_attempted
      refute output =~ secret
    end

    test "eligible command rejects startup without lifecycle execution or canary disclosure" do
      output =
        capture_rejection(RejectingSession, fn _args, _channel, _options ->
          flunk("command runner called")
        end)

      assert_receive :startup_attempted
      assert_receive :cleanup_attempted
      refute output =~ "public-boundary-canary"
    end

    test "incomplete readiness denies before startup and command execution", %{
      complete_config: config
    } do
      Application.put_env(:origen, :bootstrap_admin_local, Map.delete(config, :verifier_key_file))

      output =
        capture_rejection(
          RecordingSession,
          fn _args, _channel, _options -> flunk("command runner called") end,
          "Bootstrap admin request was rejected"
        )

      refute_receive :unexpected_startup
      refute_receive :unexpected_await
      refute output =~ "public-boundary-canary"
    end

    defp eventually(predicate, attempts \\ 50)
    defp eventually(predicate, 0), do: predicate.()

    defp eventually(predicate, attempts) do
      if predicate.() do
        true
      else
        Process.sleep(10)
        eventually(predicate, attempts - 1)
      end
    end

    defp capture_rejection(
           session,
           runner,
           message \\ "Bootstrap admin local endpoint was rejected",
           args \\ []
         ) do
      parent = self()

      log =
        capture_log(fn ->
          stdout =
            capture_io(fn ->
              stderr =
                capture_io(:stderr, fn ->
                  error =
                    assert_raise Mix.Error, message, fn ->
                      Mix.Tasks.Origen.BootstrapAdmin.execute(args, :source_checkout,
                        local_endpoint: session,
                        command_runner: runner
                      )
                    end

                  send(parent, {:exception_message, Exception.message(error)})
                end)

              send(parent, {:stderr, stderr})
            end)

          send(parent, {:stdout, stdout})
        end)

      assert_receive {:stdout, stdout}
      assert_receive {:stderr, stderr}
      assert_receive {:exception_message, exception_message}
      Enum.join([stdout, stderr, log, exception_message])
    end
  end
end
