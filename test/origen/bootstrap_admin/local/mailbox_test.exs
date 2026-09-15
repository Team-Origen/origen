defmodule Origen.BootstrapAdmin.Local.MailboxTest do
  use ExUnit.Case, async: false

  alias Origen.BootstrapAdmin.Local.Mailbox
  alias Origen.BootstrapAdmin.Local.MailboxStore

  setup do
    MailboxStore.clear()
    Swoosh.Adapters.Local.Storage.Memory.delete_all()
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

  test "successful delivery replaces stale previews with the new invitation" do
    stale_email =
      Swoosh.Email.new()
      |> Swoosh.Email.to("stale@example.test")
      |> Swoosh.Email.from("stale@example.test")
      |> Swoosh.Email.subject("stale")
      |> Swoosh.Email.text_body("stale-token")

    Swoosh.Adapters.Local.Storage.Memory.push(stale_email)
    Swoosh.Adapters.Local.Storage.Memory.push(stale_email)

    assert {:ok, _} =
             Mailbox.deliver(%{reference: "inv-new", token: "new-token-canary"}, ttl_seconds: 60)

    assert [email] = Swoosh.Adapters.Local.Storage.Memory.all()
    assert email.text_body =~ "new-token-canary"
    refute email.text_body =~ "stale-token"
  end

  test "preview storage follows rejection, clear, and expiry retention boundaries" do
    clock = fn -> 1_000 end

    assert {:ok, _} =
             Mailbox.deliver(%{reference: "inv-1", token: "tok-1"},
               ttl_seconds: 10,
               clock: clock
             )

    assert [_email] = Swoosh.Adapters.Local.Storage.Memory.all()

    assert {:error, :mailbox_retained} =
             Mailbox.deliver(%{reference: "inv-2", token: "tok-2"},
               ttl_seconds: 10,
               clock: clock
             )

    assert [_email] = Swoosh.Adapters.Local.Storage.Memory.all()

    assert :ok = MailboxStore.clear()
    assert [] = Swoosh.Adapters.Local.Storage.Memory.all()

    assert {:ok, _} =
             Mailbox.deliver(%{reference: "inv-3", token: "tok-3"},
               ttl_seconds: 10,
               clock: clock
             )

    assert MailboxStore.count(clock: fn -> 1_011 end) == 0
    assert [] = Swoosh.Adapters.Local.Storage.Memory.all()
  end

  test "security boundary: token and body never leak in mailbox status or error payloads" do
    transient = %{reference: "inv-sec", token: "token-secret-canary-999"}
    assert {:ok, result} = Mailbox.deliver(transient, ttl_seconds: 60)

    inspected = inspect(result)
    refute inspected =~ "token-secret-canary-999"
    refute inspected =~ "example.test"
  end
end
