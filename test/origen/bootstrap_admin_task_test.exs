defmodule Origen.BootstrapAdminTaskTest do
  use Origen.DataCase, async: false

  import ExUnit.CaptureIO
  import Swoosh.TestAssertions

  alias Mix.Tasks.Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin, as: BootstrapService

  @verifier_key String.duplicate("k", 32)

  defmodule FailingMailer do
    def deliver(_email), do: {:error, :transport_unavailable}
  end

  setup do
    previous = Application.get_env(:origen, :bootstrap_admin_enabled)
    previous_mailer = Application.get_env(:origen, :bootstrap_admin_mailer)
    previous_email = System.get_env("ORIGEN_BOOTSTRAP_ADMIN_EMAIL")
    previous_verifier_key = System.get_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY")
    Application.put_env(:origen, :bootstrap_admin_enabled, false)
    System.delete_env("ORIGEN_BOOTSTRAP_ADMIN_EMAIL")
    System.put_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY", @verifier_key)
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")

    on_exit(fn ->
      Application.put_env(:origen, :bootstrap_admin_enabled, previous)
      Application.put_env(:origen, :bootstrap_admin_mailer, previous_mailer)

      if previous_email do
        System.put_env("ORIGEN_BOOTSTRAP_ADMIN_EMAIL", previous_email)
      else
        System.delete_env("ORIGEN_BOOTSTRAP_ADMIN_EMAIL")
      end

      if previous_verifier_key do
        System.put_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY", previous_verifier_key)
      else
        System.delete_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY")
      end
    end)

    :ok
  end

  test "denies before parsing or touching bootstrap state when the shared gate is closed" do
    Mix.Task.reenable("origen.bootstrap_admin")

    assert_task_failure([], "Bootstrap admin is disabled")
    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
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
          "enabled@example.test"
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

  test "rejects verifier-key, invalid switches, and positional arguments without changing state" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)

    for args <- [
          ["--verifier-key", @verifier_key],
          ["--unknown"],
          ["unexpected"]
        ] do
      assert_task_failure(args, "Bootstrap admin received invalid command-line arguments")
      assert Repo.aggregate("internal_accounts", :count) == 0
      assert Repo.aggregate("internal_account_invitations", :count) == 0
    end
  end

  test "rejects a blank recipient before changing state" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)

    assert_task_failure(["--email", "   "], "Bootstrap admin requires a non-blank email")
    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
  end

  test "rejects a missing recipient before changing state" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)

    assert_task_failure([], "Bootstrap admin requires a non-blank email")
    assert Repo.aggregate("internal_accounts", :count) == 0
    assert Repo.aggregate("internal_account_invitations", :count) == 0
  end

  test "rejects missing and short verifier keys before changing state" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)

    for verifier_key <- [nil, String.duplicate("k", 31)] do
      if verifier_key do
        System.put_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY", verifier_key)
      else
        System.delete_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY")
      end

      assert_task_failure(
        ["--email", "key-check@example.test"],
        "Bootstrap admin requires a verifier key of at least 32 bytes"
      )

      assert Repo.aggregate("internal_accounts", :count) == 0
      assert Repo.aggregate("internal_account_invitations", :count) == 0
    end
  end

  test "raises a sanitized failure when the domain request is rejected" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    assert {:ok, _invitation} = BootstrapService.issue_first(%{verifier_key: @verifier_key})

    assert_task_failure(
      ["--email", "duplicate@example.test"],
      "Bootstrap admin request was rejected"
    )

    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 1
  end

  test "preserves failed delivery state and recovers by reissuing the account" do
    Application.put_env(:origen, :bootstrap_admin_enabled, true)
    Application.put_env(:origen, :bootstrap_admin_mailer, FailingMailer)
    Mix.Task.reenable("origen.bootstrap_admin")

    error = assert_task_failure(["--email", "failed@example.test"], nil)

    assert error.message =~ "delivery failed"
    refute error.message =~ "failed@example.test"
    refute error.message =~ "transport_unavailable"
    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 1
    [[account_id]] = Repo.query!("SELECT id FROM internal_accounts").rows
    assert error.message =~ "--account-id #{account_id}"

    Application.put_env(:origen, :bootstrap_admin_mailer, Origen.Mailer)
    Mix.Task.reenable("origen.bootstrap_admin")

    recovery_output =
      capture_io(fn ->
        Mix.Task.run("origen.bootstrap_admin", [
          "--account-id",
          to_string(account_id),
          "--email",
          "recovered@example.test"
        ])
      end)

    assert recovery_output =~ "invitation delivered"
    assert Repo.aggregate("internal_accounts", :count) == 1
    assert Repo.aggregate("internal_account_invitations", :count) == 2

    assert Repo.query!(
             "SELECT count(*) FROM internal_account_invitations WHERE revoked_at IS NULL"
           ).rows == [[1]]
  end

  defp assert_task_failure(args, message) do
    Mix.Task.reenable("origen.bootstrap_admin")

    error =
      assert_raise Mix.Error, fn ->
        Mix.Task.run("origen.bootstrap_admin", args)
      end

    if message, do: assert(error.message == message)
    error
  end
end
