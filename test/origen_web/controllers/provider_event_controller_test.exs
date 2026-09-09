defmodule OrigenWeb.ProviderEventControllerTest do
  use OrigenWeb.ConnCase, async: false
  import ExUnit.CaptureLog
  alias Origen.{BootstrapAdmin, Repo}
  @key :crypto.hash(:sha256, "synthetic callback key")
  @now 1_788_350_400
  @callback_config %{key_id: "callback-key-1", replay_window_seconds: 300}

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    previous = Application.get_env(:origen, :bootstrap_admin_provider_callback)
    configure()
    on_exit(fn -> restore(previous) end)
  end

  test "authenticates, correlates, revokes, and accepts an idempotent duplicate", %{conn: conn} do
    invitation = issue()
    raw = body("delivery.failed", "evt_1", correlation(invitation.invitation_id))
    parent = self()

    configure(fn id, context ->
      send(parent, :revocation)
      BootstrapAdmin.revoke_delivery_failure(id, context)
    end)

    task = Task.async(fn -> post_event(build_conn(), raw) end)
    assert json_response(Task.await(task), 202) == %{"outcome" => "accepted"}
    assert json_response(post_event(conn, raw), 202) == %{"outcome" => "accepted"}
    assert_receive :revocation
    refute_receive :revocation
    other = reissue(invitation.account_id)
    conflicting = body("delivery.failed", "evt_1", correlation(other.invitation_id))
    assert response(post_event(build_conn(), conflicting), 401) == ""
  end

  test "rejects malformed callbacks without logging secrets", %{conn: conn} do
    correlation = correlation(issue().invitation_id)
    signature_canary = Base.url_encode64("signature-header-canary", padding: false)
    key_canary = "key-id-header-canary"

    log =
      capture_log(fn ->
        assert response(post_event(conn, ""), 401) == ""

        for {raw, timestamp, signature, key_id} <- [
              {body("delivery.failed", "bad", correlation), @now, signature_canary,
               "callback-key-1"},
              {body("delivery.failed", "stale", correlation), @now - 301, nil, "callback-key-1"},
              {body("delivery.delivered", "type", correlation), @now, nil, "callback-key-1"},
              {body("delivery.failed", "corr", correlation <> "x"), @now, nil, "callback-key-1"},
              {body("delivery.failed", "evt_key", correlation), @now, nil, key_canary}
            ] do
          assert response(post_event(conn, raw, timestamp, signature, key_id), 401) == ""
        end

        Application.put_env(:origen, :bootstrap_admin_provider_callback, %{})
        assert_unauthorized(post_event(conn, body("delivery.failed", "evt_config", correlation)))
      end)

    for canary <- [signature_canary, key_canary, correlation], do: refute(log =~ canary)
    chunked = Plug.Test.conn(:post, "/", String.duplicate("chunked-callback-body", 4))
    assert {:more, first, chunked} = OrigenWeb.RawBodyReader.read_body(chunked, length: 9)
    assert {:more, second, chunked} = OrigenWeb.RawBodyReader.read_body(chunked, length: 9)
    assert chunked.assigns.raw_body == first <> second
  end

  test "releases replay identity when domain revocation fails closed", %{conn: conn} do
    invitation = issue()
    raw = body("delivery.failed", "evt_transient", correlation(invitation.invitation_id))
    parent = self()

    revoker = fn id, context ->
      send(parent, :revocation)

      case Process.get(:attempt) do
        nil -> Process.put(:attempt, true) || {:error, :audit_unavailable}
        _ -> BootstrapAdmin.revoke_delivery_failure(id, context)
      end
    end

    configure(revoker)
    assert response(post_event(conn, raw), 401) == ""
    assert json_response(post_event(build_conn(), raw), 202) == %{"outcome" => "accepted"}
    for _ <- 1..2, do: assert_receive(:revocation)
  end

  defp configure(revoker \\ nil) do
    config =
      Map.merge(@callback_config, %{
        secret_resolver: fn _ -> {:ok, @key} end,
        clock: fn -> @now end
      })

    config = if revoker, do: Map.put(config, :revoker, revoker), else: config
    Application.put_env(:origen, :bootstrap_admin_provider_callback, config)
  end

  defp restore(nil), do: Application.delete_env(:origen, :bootstrap_admin_provider_callback)
  defp restore(value), do: Application.put_env(:origen, :bootstrap_admin_provider_callback, value)
  defp issue, do: elem(BootstrapAdmin.issue_first(verifier()), 1)
  defp reissue(id), do: elem(BootstrapAdmin.reissue_first(id, verifier()), 1)
  defp verifier, do: %{verifier_key: String.duplicate("v", 32)}

  defp body(type, id, corr),
    do: Jason.encode!(%{"type" => type, "event_id" => id, "correlation" => corr})

  defp correlation(id), do: "#{id}.#{sign(to_string(id))}"

  defp assert_unauthorized(conn), do: assert(response(conn, 401) == "")

  defp post_event(conn, raw, timestamp \\ @now, signature \\ nil, key_id \\ "callback-key-1") do
    signature = signature || sign("#{timestamp}.#{raw}")

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-origen-key-id", key_id)
    |> put_req_header("x-origen-timestamp", to_string(timestamp))
    |> put_req_header("x-origen-signature", signature)
    |> post("/api/bootstrap/provider-events", raw)
  end

  defp sign(value),
    do: Base.url_encode64(:crypto.mac(:hmac, :sha256, @key, value), padding: false)
end
