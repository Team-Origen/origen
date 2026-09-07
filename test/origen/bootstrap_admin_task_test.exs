defmodule Origen.BootstrapAdminTaskTest do
  use Origen.DataCase, async: false

  import ExUnit.CaptureIO
  import Swoosh.TestAssertions

  alias Mix.Tasks.Origen.BootstrapAdmin

  @verifier_key String.duplicate("k", 32)

  defmodule FailingMailer do
    def deliver(_email), do: {:error, :transport_unavailable}
  end

  setup do
    previous = Application.get_env(:origen, :bootstrap_admin_enabled)
    previous_mailer = Application.get_env(:origen, :bootstrap_admin_mailer)
    Application.put_env(:origen, :bootstrap_admin_enabled, false)
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")

    on_exit(fn ->
      Application.put_env(:origen, :bootstrap_admin_enabled, previous)
      Application.put_env(:origen, :bootstrap_admin_mailer, previous_mailer)
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

  test "enabled task delivers a reference-only invitation through the task path" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Mix.Task.reenable("origen.bootstrap_admin")

    output =
      capture_io(fn ->
        Mix.Task.run("origen.bootstrap_admin", [
          "--email",
          "enabled@example.test",
          "--verifier-key",
          @verifier_key
        ])
      end)

    assert output =~ "Bootstrap admin invitation delivered"

    assert_receive {:email, email}
    assert email.to == [{"", "enabled@example.test"}]
    assert email.text_body =~ "Account reference:"
    assert email.text_body =~ "Invitation reference:"
    refute email.text_body =~ "https://"
    refute email.text_body =~ "token"
  end

  test "rejects invalid switches and positional arguments without changing state" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Mix.Task.reenable("origen.bootstrap_admin")

    output = capture_io(:stderr, fn -> Mix.Task.run("origen.bootstrap_admin", ["--unknown"]) end)

    assert output =~ "invalid command-line arguments"
    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0

    Mix.Task.reenable("origen.bootstrap_admin")
    output = capture_io(:stderr, fn -> Mix.Task.run("origen.bootstrap_admin", ["unexpected"]) end)

    assert output =~ "invalid command-line arguments"
    assert Repo.aggregate("internal_accounts", :count) == 0
  end

  test "rejects a blank recipient before changing state" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Mix.Task.reenable("origen.bootstrap_admin")

    output =
      capture_io(:stderr, fn ->
        Mix.Task.run("origen.bootstrap_admin", ["--email", "   ", "--verifier-key", @verifier_key])
      end)

    assert output =~ "requires a non-blank email and verifier key"
    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
  end

  test "preserves failed delivery state and recovers by reissuing the account" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_mailer, FailingMailer)
    Mix.Task.reenable("origen.bootstrap_admin")

    failed_output =
      capture_io(:stderr, fn ->
        Mix.Task.run("origen.bootstrap_admin", [
          "--email",
          "failed@example.test",
          "--verifier-key",
          @verifier_key
        ])
      end)

    assert failed_output =~ "delivery failed"
    refute failed_output =~ "failed@example.test"
    refute failed_output =~ "transport_unavailable"
    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 1
    [[account_id]] = Repo.query!("SELECT id FROM internal_accounts").rows
    assert failed_output =~ "--account-id #{account_id}"

    Application.put_env(:origen, :bootstrap_admin_mailer, Origen.Mailer)
    Mix.Task.reenable("origen.bootstrap_admin")

    recovery_output =
      capture_io(fn ->
        Mix.Task.run("origen.bootstrap_admin", [
          "--account-id",
          to_string(account_id),
          "--email",
          "recovered@example.test",
          "--verifier-key",
          @verifier_key
        ])
      end)

    assert recovery_output =~ "invitation delivered"
    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 2

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_invitations WHERE revoked_at IS NULL"
           ).rows == [[1]]
  end
end
