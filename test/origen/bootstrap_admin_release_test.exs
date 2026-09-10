defmodule Origen.BootstrapAdminReleaseTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Origen.Release

  setup do
    previous = Application.get_env(:origen, :bootstrap_admin_enabled)

    on_exit(fn ->
      Application.put_env(:origen, :bootstrap_admin_enabled, previous)
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

  test "packaged command delegates arguments without printing or interpolating them" do
    script = File.read!("rel/overlays/bin/origen_bootstrap_admin")

    assert script =~ "Origen.Release.bootstrap_admin(System.argv())"
    assert script =~ ~s(exec "$RELEASE_ROOT/origen" eval)
    assert script =~ ~s(-- "$@")
    refute script =~ "echo"
  end
end
