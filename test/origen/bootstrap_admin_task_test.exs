defmodule Origen.BootstrapAdminTaskTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Swoosh.TestAssertions

  alias Mix.Tasks.Origen.BootstrapAdmin

  setup do
    previous = Application.get_env(:origen, :bootstrap_admin_enabled)
    Application.put_env(:origen, :bootstrap_admin_enabled, false)

    on_exit(fn ->
      Application.put_env(:origen, :bootstrap_admin_enabled, previous)
    end)

    :ok
  end

  test "denies before parsing or touching bootstrap state when the shared gate is closed" do
    Mix.Task.reenable("origen.bootstrap_admin")

    output = capture_io(:stderr, fn -> Mix.Task.run("origen.bootstrap_admin", []) end)

    assert output =~ "Bootstrap admin is disabled"
    refute output =~ "token"
    refute output =~ "invitation_url"
  end

  test "builds and delivers references without the opaque activation token" do
    email =
      BootstrapAdmin.build_invitation_email(%{
        recipient: "admin@example.test",
        account_id: 17,
        invitation_id: 23,
        token: "opaque-token"
      })

    assert {:ok, _email} = Origen.Mailer.deliver(email)
    assert_email_sent(to: [{"", "admin@example.test"}])

    assert email.text_body =~ "Account reference: 17"
    assert email.text_body =~ "Invitation reference: 23"
    refute email.text_body =~ "opaque-token"

    for sensitive <- [
          "plain-password",
          "totp-seed",
          "otp-code",
          "qr-payload",
          "recovery-code",
          "session-cookie",
          "verifier-digest",
          "encryption-key"
        ] do
      refute email.text_body =~ sensitive
    end
  end

  test "keeps alternate invitation references while suppressing token-like input" do
    email =
      BootstrapAdmin.build_invitation_email(%{
        recipient: "second-admin@example.test",
        account_id: 88,
        invitation_id: 144,
        token: "another-opaque-token"
      })

    assert email.text_body =~ "Account reference: 88"
    assert email.text_body =~ "Invitation reference: 144"
    refute email.text_body =~ "another-opaque-token"
  end
end
