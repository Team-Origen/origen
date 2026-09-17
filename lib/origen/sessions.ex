defmodule Origen.Sessions do
  @moduledoc """
  Core context for server-side internal account session management.

  Handles:
  - Session creation for authenticated, active internal accounts.
  - Expiration enforcement by maximum absolute duration and idle inactivity.
  - Server-side session invalidation and revocation.
  - Opaque, fail-closed error responses preventing account enumeration.
  """

  alias Origen.Repo
  alias Origen.Sessions.InternalSession

  @default_idle_timeout 900
  @default_max_duration 43_200

  @type session_data :: %{
          session_id: integer(),
          account_id: integer(),
          role: atom(),
          issued_at: DateTime.t(),
          last_activity_at: DateTime.t(),
          idle_timeout_seconds: integer(),
          max_duration_seconds: integer()
        }

  @doc """
  Returns the active policy defaults for internal sessions.
  RNF-09 normative bounds:
  - idle_timeout_seconds: default 900s (15 min), configurable 300..1800s.
  - max_duration_seconds: default 43200s (12 hours), configurable 14400..43200s.
  """
  @spec policy() :: %{idle_timeout_seconds: integer(), max_duration_seconds: integer()}
  def policy do
    config = Application.get_env(:origen, :internal_sessions, [])

    %{
      idle_timeout_seconds: Keyword.get(config, :idle_timeout_seconds, @default_idle_timeout),
      max_duration_seconds: Keyword.get(config, :max_duration_seconds, @default_max_duration)
    }
  end

  @doc """
  Creates a new internal server session for an active internal account.
  Fails closed with `{:error, :unauthenticated}` if the account is missing or not active.
  """
  @spec create_session(integer() | map(), keyword()) ::
          {:ok, %{token: String.t(), session: session_data()}} | {:error, :unauthenticated}
  def create_session(account_or_id, opts \\ [])

  def create_session(account_id, opts) when is_integer(account_id) do
    case Repo.query(
           "SELECT id, role, state FROM internal_accounts WHERE id = $1 AND state = 'active'",
           [account_id]
         ) do
      {:ok, %{rows: [[id, role, "active"]]}}
      when role in ~w(administrator professional secretary) ->
        do_create_session(id, role, opts)

      _ ->
        {:error, :unauthenticated}
    end
  end

  def create_session(%{id: id}, opts) when is_integer(id) do
    create_session(id, opts)
  end

  def create_session(_invalid, _opts), do: {:error, :unauthenticated}

  defp do_create_session(account_id, role, opts) do
    current_policy = policy()

    idle_timeout =
      Keyword.get(opts, :idle_timeout_seconds, current_policy.idle_timeout_seconds)

    max_duration =
      Keyword.get(opts, :max_duration_seconds, current_policy.max_duration_seconds)

    now = Keyword.get(opts, :now, DateTime.utc_now())

    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    token_digest = :crypto.hash(:sha256, raw_token)

    attrs = %{
      account_id: account_id,
      token_digest: token_digest,
      issued_at: now,
      last_activity_at: now,
      idle_timeout_seconds: idle_timeout,
      max_duration_seconds: max_duration
    }

    case %InternalSession{} |> InternalSession.changeset(attrs) |> Repo.insert() do
      {:ok, session} ->
        session_info = %{
          session_id: session.id,
          account_id: account_id,
          role: String.to_atom(role),
          issued_at: session.issued_at,
          last_activity_at: session.last_activity_at,
          idle_timeout_seconds: session.idle_timeout_seconds,
          max_duration_seconds: session.max_duration_seconds
        }

        {:ok, %{token: raw_token, session: session_info}}

      _error ->
        {:error, :unauthenticated}
    end
  end

  @doc """
  Validates a session token and returns session and account data if valid and active.
  Enforces idle expiration and max absolute duration.
  If expired or revoked, marks the session revoked and returns `{:error, :unauthenticated}`.
  """
  @spec fetch_session(String.t(), keyword()) :: {:ok, session_data()} | {:error, :unauthenticated}
  def fetch_session(raw_token, opts \\ [])

  def fetch_session(raw_token, opts) when is_binary(raw_token) and byte_size(raw_token) >= 16 do
    token_digest = :crypto.hash(:sha256, raw_token)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    query = """
    SELECT s.id, s.account_id, s.issued_at, s.last_activity_at,
           s.idle_timeout_seconds, s.max_duration_seconds, s.revoked_at,
           a.role, a.state
    FROM internal_account_sessions s
    JOIN internal_accounts a ON a.id = s.account_id
    WHERE s.token_digest = $1
    """

    case Repo.query(query, [token_digest]) do
      {:ok,
       %{
         rows: [
           [
             session_id,
             account_id,
             issued_at,
             last_activity_at,
             idle_timeout,
             max_duration,
             revoked_at,
             role,
             "active"
           ]
         ]
       }} ->
        cond do
          not is_nil(revoked_at) ->
            {:error, :unauthenticated}

          # Check maximum absolute duration
          DateTime.diff(now, issued_at, :second) > max_duration ->
            revoke_by_digest(token_digest, now)
            {:error, :unauthenticated}

          # Check inactivity (idle timeout)
          DateTime.diff(now, last_activity_at, :second) > idle_timeout ->
            revoke_by_digest(token_digest, now)
            {:error, :unauthenticated}

          true ->
            {:ok,
             %{
               session_id: session_id,
               account_id: account_id,
               role: String.to_atom(role),
               issued_at: issued_at,
               last_activity_at: last_activity_at,
               idle_timeout_seconds: idle_timeout,
               max_duration_seconds: max_duration
             }}
        end

      _ ->
        {:error, :unauthenticated}
    end
  end

  def fetch_session(_invalid, _opts), do: {:error, :unauthenticated}

  @doc """
  Updates `last_activity_at` for an active session to prevent idle timeout.
  Fails if the session has already expired or been revoked.
  """
  @spec touch_session(String.t(), keyword()) :: {:ok, session_data()} | {:error, :unauthenticated}
  def touch_session(raw_token, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    with {:ok, session_info} <- fetch_session(raw_token, opts) do
      token_digest = :crypto.hash(:sha256, raw_token)

      Repo.query!(
        """
        UPDATE internal_account_sessions
        SET last_activity_at = $1, updated_at = clock_timestamp()
        WHERE token_digest = $2 AND revoked_at IS NULL
        """,
        [now, token_digest]
      )

      {:ok, %{session_info | last_activity_at: now}}
    end
  end

  @doc """
  Invalidates a session on the server, preventing its reuse.
  Always returns `:ok` regardless of whether the token existed.
  """
  @spec terminate_session(String.t(), keyword()) :: :ok
  def terminate_session(raw_token, opts \\ [])

  def terminate_session(raw_token, opts)
      when is_binary(raw_token) and byte_size(raw_token) >= 16 do
    token_digest = :crypto.hash(:sha256, raw_token)
    now = Keyword.get(opts, :now, DateTime.utc_now())
    revoke_by_digest(token_digest, now)
    :ok
  end

  def terminate_session(_invalid, _opts), do: :ok

  @doc """
  Invalidates all active sessions belonging to an account.
  Used on credential change, account suspension, or forced logout.
  """
  @spec terminate_all_sessions(integer(), keyword()) :: :ok
  def terminate_all_sessions(account_id, opts \\ [])

  def terminate_all_sessions(account_id, opts) when is_integer(account_id) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    Repo.query!(
      """
      UPDATE internal_account_sessions
      SET revoked_at = $1, updated_at = clock_timestamp()
      WHERE account_id = $2 AND revoked_at IS NULL
      """,
      [now, account_id]
    )

    :ok
  end

  def terminate_all_sessions(_invalid, _opts), do: :ok

  @doc """
  Quick boolean check for session validity.
  """
  @spec valid_session?(String.t(), keyword()) :: boolean()
  def valid_session?(raw_token, opts \\ []) do
    case fetch_session(raw_token, opts) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp revoke_by_digest(token_digest, now) do
    Repo.query(
      """
      UPDATE internal_account_sessions
      SET revoked_at = $1, updated_at = clock_timestamp()
      WHERE token_digest = $2 AND revoked_at IS NULL
      """,
      [now, token_digest]
    )
  end
end
