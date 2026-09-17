defmodule Origen.SessionsTest do
  use Origen.DataCase, async: false

  alias Origen.Repo
  alias Origen.Sessions

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_account_sessions")
    Repo.query!("DELETE FROM internal_accounts")

    active_id =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ('administrator', 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
      RETURNING id
      """).rows
      |> hd()
      |> hd()

    pending_id =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state)
      VALUES ('administrator', 'pending_activation')
      RETURNING id
      """).rows
      |> hd()
      |> hd()

    %{active_account_id: active_id, pending_account_id: pending_id}
  end

  describe "create_session/2" do
    test "creates and stores an internal session for an active internal account", %{
      active_account_id: account_id
    } do
      assert {:ok, %{token: token, session: session}} = Sessions.create_session(account_id)

      assert is_binary(token)
      assert byte_size(token) >= 32
      assert session.account_id == account_id
      assert session.role == :administrator
      assert session.idle_timeout_seconds == 900
      assert session.max_duration_seconds == 43_200
      assert session.issued_at != nil
      assert session.last_activity_at != nil

      # Verify stored token is a SHA-256 digest, not the raw token
      digest = :crypto.hash(:sha256, token)

      row =
        Repo.query!(
          "SELECT token_digest, revoked_at FROM internal_account_sessions WHERE id = $1",
          [session.session_id]
        ).rows

      assert [[stored_digest, nil]] = row
      assert stored_digest == digest
    end

    test "creates session from an active account map", %{active_account_id: account_id} do
      account = %{id: account_id, state: "active", role: "administrator"}
      assert {:ok, %{token: _token, session: session}} = Sessions.create_session(account)
      assert session.account_id == account_id
    end

    test "fails closed with :unauthenticated for a pending account", %{
      pending_account_id: pending_id
    } do
      assert {:error, :unauthenticated} = Sessions.create_session(pending_id)
    end

    test "fails closed with :unauthenticated for a non-existent account" do
      assert {:error, :unauthenticated} = Sessions.create_session(999_999)
    end

    test "fails closed for invalid inputs" do
      assert {:error, :unauthenticated} = Sessions.create_session(nil)
      assert {:error, :unauthenticated} = Sessions.create_session("invalid")
    end
  end

  describe "fetch_session/2" do
    test "successfully fetches an active, unexpired session", %{active_account_id: account_id} do
      {:ok, %{token: token, session: created}} = Sessions.create_session(account_id)

      assert {:ok, fetched} = Sessions.fetch_session(token)
      assert fetched.session_id == created.session_id
      assert fetched.account_id == account_id
      assert fetched.role == :administrator
      assert Sessions.valid_session?(token)
    end

    test "returns generic :unauthenticated for non-existent or malformed token" do
      assert {:error, :unauthenticated} = Sessions.fetch_session("non_existent_token_1234567890")
      assert {:error, :unauthenticated} = Sessions.fetch_session("")
      assert {:error, :unauthenticated} = Sessions.fetch_session(nil)
      refute Sessions.valid_session?("invalid_token")
    end

    test "expires session when idle timeout is exceeded", %{active_account_id: account_id} do
      base_time = ~U[2026-09-18 10:00:00Z]

      {:ok, %{token: token}} =
        Sessions.create_session(account_id,
          now: base_time,
          idle_timeout_seconds: 900
        )

      # 14 minutes later: still active
      within_idle = DateTime.add(base_time, 840, :second)
      assert {:ok, _} = Sessions.fetch_session(token, now: within_idle)

      # 16 minutes later: exceeds 15 min (900s) idle timeout
      past_idle = DateTime.add(base_time, 960, :second)
      assert {:error, :unauthenticated} = Sessions.fetch_session(token, now: past_idle)
      refute Sessions.valid_session?(token, now: past_idle)

      # Server invalidation check: session should now be marked revoked
      digest = :crypto.hash(:sha256, token)

      [[revoked_at]] =
        Repo.query!(
          "SELECT revoked_at FROM internal_account_sessions WHERE token_digest = $1",
          [digest]
        ).rows

      assert revoked_at != nil
    end

    test "expires session when absolute maximum duration is reached even with ongoing activity",
         %{active_account_id: account_id} do
      base_time = ~U[2026-09-18 00:00:00Z]

      {:ok, %{token: token}} =
        Sessions.create_session(account_id,
          now: base_time,
          idle_timeout_seconds: 1800,
          max_duration_seconds: 3600
        )

      # Keep idle alive with ongoing activity at 1500s and 3000s (idle timeout is 1800s)
      t_1500 = DateTime.add(base_time, 1500, :second)
      assert {:ok, _} = Sessions.touch_session(token, now: t_1500)

      t_3000 = DateTime.add(base_time, 3000, :second)
      assert {:ok, _} = Sessions.touch_session(token, now: t_3000)

      # 3601 seconds from issued_at: exceeds 1 hour (3600s) max duration even though last touch was only 601s ago!
      past_max = DateTime.add(base_time, 3601, :second)
      assert {:error, :unauthenticated} = Sessions.fetch_session(token, now: past_max)
    end
  end

  describe "touch_session/2" do
    test "updates last_activity_at to prevent idle expiration without altering issued_at", %{
      active_account_id: account_id
    } do
      t0 = ~U[2026-09-18 12:00:00Z]

      {:ok, %{token: token, session: created}} =
        Sessions.create_session(account_id,
          now: t0,
          idle_timeout_seconds: 600,
          max_duration_seconds: 7200
        )

      # Touch at t0 + 8 minutes (before 10 min idle limit)
      t1 = DateTime.add(t0, 480, :second)
      assert {:ok, touched} = Sessions.touch_session(token, now: t1)
      assert DateTime.compare(touched.last_activity_at, t1) == :eq
      assert DateTime.compare(touched.issued_at, created.issued_at) == :eq

      # At t0 + 15 minutes (7 minutes after touch, but 15 minutes after start)
      # Would have expired if not touched, but since last_activity_at was updated, it's valid!
      t2 = DateTime.add(t0, 900, :second)
      assert {:ok, fetched} = Sessions.fetch_session(token, now: t2)
      assert DateTime.compare(fetched.last_activity_at, t1) == :eq
    end

    test "touching an already expired or revoked session fails closed", %{
      active_account_id: account_id
    } do
      t0 = ~U[2026-09-18 12:00:00Z]

      {:ok, %{token: token}} =
        Sessions.create_session(account_id, now: t0, idle_timeout_seconds: 300)

      past_idle = DateTime.add(t0, 400, :second)
      assert {:error, :unauthenticated} = Sessions.touch_session(token, now: past_idle)
    end
  end

  describe "terminate_session/2" do
    test "invalidates the session on the server and prevents reuse", %{
      active_account_id: account_id
    } do
      {:ok, %{token: token}} = Sessions.create_session(account_id)
      assert Sessions.valid_session?(token)

      assert :ok = Sessions.terminate_session(token)

      assert {:error, :unauthenticated} = Sessions.fetch_session(token)
      refute Sessions.valid_session?(token)

      # Subsequent termination attempts are idempotent and safe
      assert :ok = Sessions.terminate_session(token)
    end

    test "terminating non-existent token is safe and reveals nothing" do
      assert :ok = Sessions.terminate_session("non_existent_token_1234567890")
      assert :ok = Sessions.terminate_session(nil)
    end
  end

  describe "terminate_all_sessions/2" do
    test "invalidates all active sessions for the specified account", %{
      active_account_id: account_id
    } do
      {:ok, %{token: token1}} = Sessions.create_session(account_id)
      {:ok, %{token: token2}} = Sessions.create_session(account_id)

      assert Sessions.valid_session?(token1)
      assert Sessions.valid_session?(token2)

      assert :ok = Sessions.terminate_all_sessions(account_id)

      refute Sessions.valid_session?(token1)
      refute Sessions.valid_session?(token2)
      assert {:error, :unauthenticated} = Sessions.fetch_session(token1)
      assert {:error, :unauthenticated} = Sessions.fetch_session(token2)
    end
  end
end
