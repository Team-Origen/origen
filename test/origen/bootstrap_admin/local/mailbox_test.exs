defmodule Origen.BootstrapAdmin.Local.MailboxTest do
  use ExUnit.Case, async: false

  alias Origen.BootstrapAdmin.Local.Mailbox
  alias Origen.BootstrapAdmin.Local.MailboxStore

  setup do
    MailboxStore.clear()
    :ok
  end

  test "bounded storage holds at most one message" do
    assert MailboxStore.count() == 0
    assert :ok = MailboxStore.push(%{id: "msg-1", body: "secret-body-canary"})
    assert MailboxStore.count() == 1

    assert {:error, :mailbox_full} =
             MailboxStore.push(%{id: "msg-2", body: "another-body"})

    assert MailboxStore.count() == 1
  end

  test "bounded storage clears on init/clear" do
    MailboxStore.push(%{id: "msg-1", body: "body"})
    assert MailboxStore.count() == 1
    MailboxStore.clear()
    assert MailboxStore.count() == 0
    assert MailboxStore.get("msg-1") == nil
  end

  test "expires message when TTL is reached" do
    fake_clock = fn -> 1_000 end

    assert :ok =
             MailboxStore.push(%{id: "msg-1", body: "body"}, ttl_seconds: 10, clock: fake_clock)

    assert MailboxStore.get("msg-1", clock: fn -> 1_005 end) != nil
    assert MailboxStore.get("msg-1", clock: fn -> 1_011 end) == nil
    assert MailboxStore.count(clock: fn -> 1_011 end) == 0
  end

  test "deliver through Mailbox coordinates sending, retention and returns safe ref" do
    transient = %{reference: "inv-123", token: "tok-456"}
    opts = [ttl_seconds: 60]

    assert {:ok, %{correlation_ref: ref}} = Mailbox.deliver(transient, opts)
    assert is_binary(ref)
    assert ref =~ ~r/\A[A-Za-z0-9_-]+\z/
    # Ensure sensitive fields are not in the correlation reference
    refute ref =~ "tok-456"
    refute ref =~ "secret"
  end

  test "deliver fails if mailbox already has active message" do
    transient1 = %{reference: "inv-1", token: "tok-1"}
    transient2 = %{reference: "inv-2", token: "tok-2"}

    assert {:ok, _} = Mailbox.deliver(transient1, ttl_seconds: 60)
    assert {:error, :mailbox_retained} = Mailbox.deliver(transient2, ttl_seconds: 60)
  end

  test "security boundary: token and body never leak in mailbox status or error payloads" do
    transient = %{reference: "inv-sec", token: "token-secret-canary-999"}
    assert {:ok, result} = Mailbox.deliver(transient, ttl_seconds: 60)

    inspected = inspect(result)
    refute inspected =~ "token-secret-canary-999"
    refute inspected =~ "example.test"
  end
end
