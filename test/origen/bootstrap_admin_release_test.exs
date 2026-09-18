defmodule Origen.BootstrapAdminReleaseTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Origen.Release

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

    :ok
  end

  test "release boundary denies through the shared gate before inspecting arguments" do
    Application.put_env(:origen, :bootstrap_admin_enabled, false)
    secret = "verifier-key-must-not-appear"

    output =
      capture_io(:stderr, fn ->
        error =
          assert_raise RuntimeError, "Bootstrap admin is disabled", fn ->
            Release.bootstrap_admin(["--verifier-key", secret])
          end

        refute Exception.message(error) =~ secret
      end)

    refute output =~ secret
  end

  test "release boundary denies malformed gate configuration" do
    Application.put_env(:origen, :bootstrap_admin_enabled, "true")

    assert_raise RuntimeError, "Bootstrap admin is disabled", fn ->
      Release.bootstrap_admin([])
    end
  end

  test "enabled release boundary delegates to the existing parser without accepting verifier keys" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    secret = "argv-verifier-key-must-not-appear"

    error =
      assert_raise Mix.Error, "Bootstrap admin received invalid command-line arguments", fn ->
        Release.bootstrap_admin(["--verifier-key", secret])
      end

    refute Exception.message(error) =~ secret
  end

  test "packaged release denies copied local-looking configuration before parsing or seams" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_profile, :local)
    Application.put_env(:origen, :bootstrap_admin_local_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_local, %{enabled: true})

    Application.put_env(:origen, :bootstrap_admin_command_options,
      local_parser: fn _ -> flunk("local parser called") end,
      local_command: fn _ -> flunk("local command called") end,
      approval_reader: fn _ -> flunk("staging fallback called") end,
      orchestrator: fn _, _ -> flunk("Repo/token/delivery seam called") end
    )

    secret = "release-local-secret-canary"

    error =
      assert_raise Mix.Error, "Bootstrap admin request was rejected", fn ->
        Release.bootstrap_admin(["--token", secret])
      end

    refute Exception.message(error) =~ secret
  end

  test "packaged command delegates arguments without printing or interpolating them" do
    script = File.read!("rel/overlays/bin/origen_bootstrap_admin")

    assert script =~ "Origen.Release.bootstrap_admin(System.argv())"
    assert script =~ ~s(exec "$RELEASE_ROOT/origen" eval)
    assert script =~ ~s(-- "$@")
    refute script =~ "echo"
  end
end
