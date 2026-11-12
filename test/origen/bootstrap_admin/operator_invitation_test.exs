defmodule Origen.BootstrapAdmin.OperatorInvitationTest do
  use Origen.DataCase, async: false

  import ExUnit.CaptureIO

  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.OperatorInvitation
  alias Origen.Release

  @key String.duplicate("k", 32)
  @host "origen.example.test"
  @enabled %{"ORIGEN_OPERATOR_INVITATION_ENABLED" => "true"}

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    :ok
  end

  defp run(args, overrides \\ []) do
    OperatorInvitation.run(args, Keyword.merge([env: @enabled, verifier_key: @key], overrides))
  end

  defp count(table), do: Repo.query!("SELECT count(*) FROM #{table}").rows |> hd() |> hd()

  defp fragment(link) do
    %URI{fragment: fragment} = URI.parse(link)
    params = URI.decode_query(fragment)
    {String.to_integer(params["invitation_id"]), params["token"]}
  end

  describe "gate" do
    test "refuses before reading arguments or touching the database when not enabled" do
      for env <- [%{}, %{"ORIGEN_OPERATOR_INVITATION_ENABLED" => "1"}] do
        assert {:error, :operator_invitation_disabled} =
                 run(["--not-an-option"], env: env)
      end

      assert count("internal_accounts") == 0
      assert count("internal_account_invitations") == 0
    end

    test "refuses without a verifier key of at least 32 bytes" do
      for key <- [nil, "short"] do
        assert {:error, :invalid_verifier_key} = run(["--host", @host], verifier_key: key)
      end

      assert count("internal_accounts") == 0
    end
  end

  describe "arguments" do
    test "requires exactly one valid public host and rejects anything else" do
      for args <- [
            [],
            ["--host"],
            ["--host", "https://#{@host}"],
            ["--host", "#{@host}/path"],
            ["--host", "localhost:4000"],
            ["--host", "UPPER.example.test"],
            ["--host", @host, "--host", @host],
            ["--host", @host, "extra"],
            ["--host", @host, "--account-id", "0"],
            ["--host", @host, "--unknown", "x"]
          ] do
        assert {:error, :invalid_arguments} = run(args), "expected rejection for #{inspect(args)}"
      end

      assert count("internal_accounts") == 0
    end
  end

  describe "first issue" do
    test "creates one pending administrator and a link that the activation exchange accepts" do
      assert {:ok, result} = run(["--host", @host])

      assert %{rows: [["administrator", "pending_activation"]]} =
               Repo.query!("SELECT role, state FROM internal_accounts WHERE id = $1", [
                 result.account_id
               ])

      assert String.starts_with?(result.link, "https://#{@host}/administrador/activar#")
      {invitation_id, token} = fragment(result.link)
      assert invitation_id == result.invitation_id
      assert %DateTime{} = result.expires_at

      assert {:ok, binding} = BootstrapAdmin.exchange(invitation_id, token, @key)
      assert binding.account_id == result.account_id
    end

    test "records who issued it and the operator handoff in the audit log" do
      assert {:ok, result} = run(["--host", @host])

      assert %{rows: [["operator_cli"]]} =
               Repo.query!(
                 "SELECT issued_by_ref FROM internal_account_invitations WHERE id = $1",
                 [
                   result.invitation_id
                 ]
               )

      events = Repo.query!("SELECT event, result FROM audit_events ORDER BY id").rows
      assert ["bootstrap_admin", "allowed"] in events
      assert ["invitation_delivery_handoff", "succeeded"] in events
    end

    test "refuses a second first issue once an administrator exists" do
      assert {:ok, _first} = run(["--host", @host])
      assert {:error, :administrator_exists} = run(["--host", @host])
      assert count("internal_accounts") == 1
    end
  end

  describe "handoff audit failure" do
    test "revokes the link and reports the kept pending account so it can be reissued" do
      failing_audit = fn _invitation_id -> {:error, :audit_unavailable} end

      assert {:error, :audit_unavailable, %{account_id: account_id, revoked: true}} =
               run(["--host", @host], audit_handoff: failing_audit)

      assert %{rows: [["pending_activation"]]} =
               Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [account_id])

      assert %{rows: [[revoked_at]]} =
               Repo.query!(
                 "SELECT revoked_at FROM internal_account_invitations WHERE account_id = $1",
                 [account_id]
               )

      refute is_nil(revoked_at)

      assert {:error, :administrator_exists} = run(["--host", @host])

      assert {:ok, reissued} =
               run(["--host", @host, "--account-id", Integer.to_string(account_id)])

      {invitation_id, token} = fragment(reissued.link)
      assert {:ok, _binding} = BootstrapAdmin.exchange(invitation_id, token, @key)
    end

    test "the release entry point names the account id to reissue with" do
      error =
        assert_raise RuntimeError, fn ->
          Release.raise_refusal({:error, :audit_unavailable, %{account_id: 42, revoked: true}})
        end

      assert error.message =~ "audit_unavailable"
      assert error.message =~ "--account-id 42"
    end
  end

  describe "reissue" do
    test "revokes the previous invitation of a pending account and issues a working new one" do
      assert {:ok, first} = run(["--host", @host])
      {old_id, old_token} = fragment(first.link)

      assert {:ok, second} =
               run(["--host", @host, "--account-id", Integer.to_string(first.account_id)])

      assert second.account_id == first.account_id
      assert {:error, :invalid_invitation} = BootstrapAdmin.exchange(old_id, old_token, @key)

      {new_id, new_token} = fragment(second.link)
      assert {:ok, _binding} = BootstrapAdmin.exchange(new_id, new_token, @key)
    end

    test "refuses to reissue for an active or unknown account" do
      assert {:ok, first} = run(["--host", @host])
      {invitation_id, token} = fragment(first.link)

      assert {:ok, _activated} =
               BootstrapAdmin.activate(invitation_id, token, @key, %{
                 password_hash: "argon2id-hash",
                 totp_secret: <<1, 2, 3>>
               })

      assert {:error, :administrator_active} =
               run(["--host", @host, "--account-id", Integer.to_string(first.account_id)])

      assert {:error, :account_not_found} =
               run(["--host", @host, "--account-id", "999999"])
    end
  end

  describe "release entry point" do
    setup do
      previous = System.get_env("ORIGEN_OPERATOR_INVITATION_ENABLED")
      previous_key = Application.get_env(:origen, :bootstrap_admin_verifier_key)
      Application.put_env(:origen, :bootstrap_admin_verifier_key, @key)

      on_exit(fn ->
        if previous,
          do: System.put_env("ORIGEN_OPERATOR_INVITATION_ENABLED", previous),
          else: System.delete_env("ORIGEN_OPERATOR_INVITATION_ENABLED")

        Application.put_env(:origen, :bootstrap_admin_verifier_key, previous_key)
      end)
    end

    test "prints the account id, the expiry and the activation link" do
      System.put_env("ORIGEN_OPERATOR_INVITATION_ENABLED", "true")

      output =
        capture_io(fn -> assert :ok = Release.issue_admin_invitation(["--host", @host]) end)

      [[account_id]] = Repo.query!("SELECT id FROM internal_accounts").rows
      assert output =~ "Account id (for --account-id when reissuing): #{account_id}"
      assert output =~ "Expires at:"
      assert output =~ "https://#{@host}/administrador/activar#invitation_id="
    end

    test "accepts the argv of the release script, which starts with the `--` separator" do
      System.put_env("ORIGEN_OPERATOR_INVITATION_ENABLED", "true")

      output =
        capture_io(fn ->
          assert :ok = Release.issue_admin_invitation(["--", "--host", @host])
        end)

      assert output =~ "Pending Administrator created."
    end

    test "raises a safe message when disabled" do
      System.delete_env("ORIGEN_OPERATOR_INVITATION_ENABLED")

      assert_raise RuntimeError, "Admin invitation refused: operator_invitation_disabled", fn ->
        Release.issue_admin_invitation(["--host", @host])
      end
    end
  end
end
