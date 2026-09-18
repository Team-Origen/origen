defmodule Origen.Accounts do
  @moduledoc """
  Authentication and account lifecycle operations for internal users.
  """

  alias Origen.Audit.{Events, Writer}
  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.BootstrapAdmin.{Credentials, Verifier}
  alias Origen.Repo
  alias Origen.Sessions

  @allowed_roles ~w(administrator professional secretary)

  @type account_summary :: %{
          id: integer(),
          email: String.t() | nil,
          role: String.t(),
          state: String.t()
        }

  @type auth_result ::
          {:ok,
           %{
             account: account_summary(),
             token: String.t(),
             session: Sessions.session_data()
           }}
          | {:error, :unauthenticated}

  @type invitation_result :: %{
          account: %{
            id: integer(),
            email: String.t(),
            role: :professional | :secretary,
            state: atom()
          },
          account_id: integer(),
          invitation_id: integer(),
          token: String.t(),
          issued_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @doc """
  Creates a pending professional or secretary account and its first invitation atomically.

  The raw invitation token exists only in the successful return value. Persistence stores the
  versioned verifier digest, and audit records contain identifiers only.
  """
  @spec create_and_invite_internal_account(integer(), map(), keyword()) ::
          {:ok, invitation_result()} | {:error, atom()}
  def create_and_invite_internal_account(actor_id, attrs, opts \\ [])

  def create_and_invite_internal_account(
        actor_id,
        %{email: email, role: role},
        opts
      )
      when is_integer(actor_id) and is_binary(email) and role in [:professional, :secretary] and
             is_list(opts) do
    with {:ok, key} <- verifier_key(opts),
         {:ok, ttl_seconds} <- invitation_ttl_seconds(),
         {:ok, clean_email} <- normalize_email(email) do
      Repo.transaction(fn ->
        authorize_create!(actor_id, role)
        account_id = insert_pending_account!(clean_email, role)

        issue_internal_invitation!(
          actor_id,
          %{id: account_id, email: clean_email, role: role, state: :pending_activation},
          key,
          ttl_seconds,
          :issue
        )
      end)
      |> unwrap_invitation_transaction()
    end
  end

  def create_and_invite_internal_account(_actor_id, _attrs, _opts),
    do: {:error, :unauthorized}

  @doc """
  Atomically revokes the active invitation for a pending professional or secretary and issues a
  replacement. Only an active administrator may perform the operation.
  """
  @spec reissue_internal_invitation(integer(), integer(), keyword()) ::
          {:ok, invitation_result()} | {:error, atom()}
  def reissue_internal_invitation(actor_id, account_id, opts \\ [])

  def reissue_internal_invitation(actor_id, account_id, opts)
      when is_integer(actor_id) and is_integer(account_id) and is_list(opts) do
    with {:ok, key} <- verifier_key(opts),
         {:ok, ttl_seconds} <- invitation_ttl_seconds() do
      Repo.transaction(fn ->
        actor = lock_account!(actor_id, "FOR SHARE")
        target = lock_account!(account_id, "FOR UPDATE")
        authorize_reissue!(actor, target)
        revoke_active_invitation!(account_id)

        issue_internal_invitation!(
          actor_id,
          %{
            id: account_id,
            email: target.email,
            role: role_atom(target.role),
            state: :pending_activation
          },
          key,
          ttl_seconds,
          :reissue
        )
      end)
      |> unwrap_invitation_transaction()
    end
  end

  def reissue_internal_invitation(_actor_id, _account_id, _opts),
    do: {:error, :unauthorized}

  @doc """
  Verifies a pending professional or secretary invitation and returns its activation binding.

  This preparation step does not consume the invitation or modify the account. All rejected inputs
  return the same error and emit an opaque audit failure without account or invitation references.
  """
  @spec prepare_internal_account_activation(integer(), String.t(), keyword()) ::
          {:ok, %{account_id: integer(), invitation_id: integer()}}
          | {:error, :activation_failed}
  def prepare_internal_account_activation(invitation_id, token, opts)
      when is_integer(invitation_id) and is_binary(token) and is_list(opts) do
    with {:ok, key} <- verifier_key(opts),
         {:ok, binding} <- verify_staff_activation_invitation(invitation_id, token, key) do
      {:ok, binding}
    else
      _invalid -> activation_preparation_failed()
    end
  end

  def prepare_internal_account_activation(_invitation_id, _token, _opts),
    do: activation_preparation_failed()

  @doc """
  Authenticates an internal account using an identifier (email or id), password, and TOTP code.

  ## Options
    * `:create_session` - boolean, defaults to true. When true, creates an internal session.
    * `:time` - optional unix timestamp in seconds used for TOTP validation.
    * `:keyring` - optional explicit keyring map for decrypting TOTP secrets.
    * `:session_opts` - keyword options passed to `Origen.Sessions.create_session/2`.

  ## Security properties
    * Fail-closed with `{:error, :unauthenticated}` on any failure.
    * Constant-time password verification on missing/inactive accounts to prevent enumeration.
    * Replay protection for TOTP codes using `totp_last_period`.
    * Audits both success and failures without storing secrets.
  """
  @spec authenticate_internal_account(String.t() | integer(), String.t(), String.t(), keyword()) ::
          auth_result()
  def authenticate_internal_account(identifier, password, totp_code, opts \\ [])

  def authenticate_internal_account(identifier, password, totp_code, opts)
      when (is_binary(identifier) or is_integer(identifier)) and is_binary(password) and
             is_binary(totp_code) do
    case authenticate_credentials(identifier, password, totp_code, opts) do
      {:ok, account} ->
        if Keyword.get(opts, :create_session, true) do
          session_opts = Keyword.get(opts, :session_opts, [])

          case Sessions.create_session(account.id, session_opts) do
            {:ok, %{token: token, session: session}} ->
              {:ok, %{account: account, token: token, session: session}}

            {:error, _reason} ->
              {:error, :unauthenticated}
          end
        else
          {:ok, %{account: account}}
        end

      {:error, {:unauthenticated, maybe_account_id}} ->
        record_audit_failure(maybe_account_id)
        {:error, :unauthenticated}
    end
  end

  def authenticate_internal_account(_identifier, _password, _totp_code, _opts) do
    Argon2.no_user_verify()
    record_audit_failure(nil)
    {:error, :unauthenticated}
  end

  defp authenticate_credentials(identifier, password, totp_code, opts) do
    Repo.transaction(fn ->
      case lock_and_fetch_account(identifier) do
        {:ok, account} ->
          validate_account(account, password, totp_code, opts)

        {:error, :not_found} ->
          Argon2.no_user_verify()
          Repo.rollback({:unauthenticated, nil})
      end
    end)
    |> case do
      {:ok, account} -> {:ok, account}
      {:error, {:unauthenticated, maybe_id}} -> {:error, {:unauthenticated, maybe_id}}
      _ -> {:error, {:unauthenticated, nil}}
    end
  end

  defp validate_account(account, password, totp_code, opts) do
    is_active = account.state == "active"
    role_allowed = account.role in @allowed_roles

    pwd_valid =
      is_binary(account.password_hash) and
        Credentials.verify_password(password, account.password_hash)

    if is_active and role_allowed and pwd_valid do
      validate_totp_and_complete(account, totp_code, opts)
    else
      unless pwd_valid do
        if is_nil(account.password_hash), do: Argon2.no_user_verify()
      end

      Repo.rollback({:unauthenticated, account.id})
    end
  end

  defp validate_totp_and_complete(account, totp_code, opts) do
    keyring = resolve_totp_keyring(opts)
    time = Keyword.get(opts, :time, System.os_time(:second))
    period_index = div(time, 30)

    with {:ok, seed} <- resolve_seed(account.totp_secret, keyring),
         true <- valid_totp_code?(seed, totp_code, account.totp_last_period, period_index, time) do
      Repo.query!(
        "UPDATE internal_accounts SET totp_last_period = $1, updated_at = clock_timestamp() WHERE id = $2",
        [period_index, account.id]
      )

      record_audit_success(account)

      %{
        id: account.id,
        email: account.email,
        role: account.role,
        state: account.state
      }
    else
      _ ->
        Repo.rollback({:unauthenticated, account.id})
    end
  end

  defp lock_and_fetch_account(identifier) when is_integer(identifier) do
    query = """
    SELECT id, email, role, state, password_hash, totp_secret, totp_last_period
    FROM internal_accounts
    WHERE id = $1
    FOR UPDATE
    """

    case Repo.query(query, [identifier]) do
      {:ok, %{rows: [row]}} -> {:ok, row_to_account(row)}
      _ -> {:error, :not_found}
    end
  end

  defp lock_and_fetch_account(identifier) when is_binary(identifier) do
    trimmed = String.trim(identifier)

    case Repo.query(
           """
           SELECT id, email, role, state, password_hash, totp_secret, totp_last_period
           FROM internal_accounts
           WHERE lower(email) = lower($1)
           FOR UPDATE
           """,
           [trimmed]
         ) do
      {:ok, %{rows: [row]}} ->
        {:ok, row_to_account(row)}

      _ ->
        case Integer.parse(trimmed) do
          {id, ""} -> lock_and_fetch_account(id)
          _ -> {:error, :not_found}
        end
    end
  end

  defp row_to_account([id, email, role, state, password_hash, totp_secret, totp_last_period]) do
    %{
      id: id,
      email: email,
      role: role,
      state: state,
      password_hash: password_hash,
      totp_secret: totp_secret,
      totp_last_period: totp_last_period
    }
  end

  defp resolve_totp_keyring(opts) do
    cond do
      keyring = opts[:keyring] ->
        keyring

      keyring = Application.get_env(:origen, :totp_keyring) ->
        keyring

      keyring = Application.get_env(:origen, :bootstrap_admin_totp_keyring) ->
        keyring

      true ->
        nil
    end
  end

  defp resolve_seed(secret, keyring) when is_binary(secret) do
    cond do
      is_map(keyring) or is_binary(keyring) ->
        case Credentials.decrypt_seed(secret, keyring) do
          {:ok, seed} ->
            {:ok, seed}

          _ ->
            if byte_size(secret) in [20, 32], do: {:ok, secret}, else: {:error, :invalid_seed}
        end

      byte_size(secret) in [20, 32] ->
        {:ok, secret}

      true ->
        {:error, :invalid_seed}
    end
  end

  defp resolve_seed(_secret, _keyring), do: {:error, :invalid_seed}

  defp valid_totp_code?(seed, code, last_period, period_index, current_time) do
    clean_code = String.trim(code)

    cond do
      not Regex.match?(~r/^\d{6}$/, clean_code) ->
        false

      is_integer(last_period) and period_index <= last_period ->
        false

      true ->
        NimbleTOTP.valid?(seed, clean_code, time: current_time)
    end
  end

  defp authorize_create!(actor_id, role) do
    actor = lock_account!(actor_id, "FOR SHARE")

    operation =
      case role do
        :professional -> :create_professional_account
        :secretary -> :create_secretary_account
      end

    request =
      Request.new(
        operation: Fact.known(operation),
        subject: Fact.known({:role, role_atom(actor.role)}),
        account_state: Fact.known(state_atom(actor.state)),
        target: Fact.known(%{role: role, state: :pending_activation}),
        scope: :not_applicable
      )

    case Authorization.decide(request) do
      {:allow, rule} when rule in [:s1_02, :s1_03] -> :ok
      _denied -> Repo.rollback(:unauthorized)
    end
  end

  defp authorize_reissue!(actor, target) do
    request =
      Request.new(
        operation: Fact.known(:reissue_internal_invitation),
        subject: Fact.known({:role, role_atom(actor.role)}),
        account_state: Fact.known(state_atom(actor.state)),
        target:
          Fact.known(%{
            role: role_atom(target.role),
            state: state_atom(target.state)
          }),
        scope: Fact.known(%{authenticated: true})
      )

    case Authorization.decide(request) do
      {:allow, :rei_02} -> :ok
      _denied -> Repo.rollback(:unauthorized)
    end
  end

  defp lock_account!(account_id, lock) when lock in ["FOR SHARE", "FOR UPDATE"] do
    case Repo.query!(
           "SELECT id, email, role, state FROM internal_accounts WHERE id = $1 #{lock}",
           [account_id]
         ).rows do
      [[id, email, role, state]] -> %{id: id, email: email, role: role, state: state}
      [] -> Repo.rollback(:unauthorized)
    end
  end

  defp insert_pending_account!(email, role) do
    case Repo.query!(
           """
           INSERT INTO internal_accounts (email, role, state)
           VALUES ($1, $2, 'pending_activation')
           ON CONFLICT DO NOTHING
           RETURNING id
           """,
           [email, Atom.to_string(role)]
         ).rows do
      [[account_id]] -> account_id
      [] -> Repo.rollback(:invalid_request)
    end
  end

  defp revoke_active_invitation!(account_id) do
    case Repo.query!(
           """
           SELECT id
           FROM internal_account_invitations
           WHERE account_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL
           FOR UPDATE
           """,
           [account_id]
         ).rows do
      [[invitation_id]] ->
        Repo.query!(
          "UPDATE internal_account_invitations SET revoked_at = clock_timestamp() WHERE id = $1",
          [invitation_id]
        )

      _missing_or_invalid ->
        Repo.rollback(:unauthorized)
    end
  end

  defp issue_internal_invitation!(actor_id, account, key, ttl_seconds, operation) do
    %{token: token, verifier_version: version, verifier_digest: digest} = Verifier.issue(key)

    %{rows: [[invitation_id, issued_at, expires_at]]} =
      Repo.query!(
        """
        INSERT INTO internal_account_invitations
          (account_id, verifier_version, verifier_digest, issued_by_ref, expires_at)
        VALUES ($1, $2, $3, $4, clock_timestamp() + ($5 * interval '1 second'))
        RETURNING id, issued_at, expires_at
        """,
        [account.id, version, digest, to_string(actor_id), ttl_seconds]
      )

    event =
      case operation do
        :issue ->
          Events.internal_invitation_issued(
            {:administrator, to_string(actor_id)},
            to_string(invitation_id)
          )

        :reissue ->
          Events.internal_invitation_reissued(
            {:administrator, to_string(actor_id)},
            to_string(invitation_id)
          )
      end

    with {:ok, audit_event} <- event,
         {:ok, _audit} <- Writer.append(audit_event, {:allow, :sys_01}) do
      %{
        account: account,
        account_id: account.id,
        invitation_id: invitation_id,
        token: token,
        issued_at: issued_at,
        expires_at: expires_at
      }
    else
      _audit_failure -> Repo.rollback(:audit_unavailable)
    end
  end

  defp verify_staff_activation_invitation(invitation_id, token, key) do
    case Repo.query!(
           """
           SELECT i.account_id, i.verifier_version, i.verifier_digest, i.expires_at,
                  i.consumed_at, i.revoked_at, a.role, a.state
           FROM internal_account_invitations AS i
           JOIN internal_accounts AS a ON a.id = i.account_id
           WHERE i.id = $1
           """,
           [invitation_id]
         ).rows do
      [[account_id, version, digest, expires_at, nil, nil, role, "pending_activation"]]
      when role in ["professional", "secretary"] ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt and
             Verifier.verify(token, version, digest, key) do
          {:ok, %{account_id: account_id, invitation_id: invitation_id}}
        else
          {:error, :activation_failed}
        end

      _invalid ->
        {:error, :activation_failed}
    end
  end

  defp activation_preparation_failed do
    with {:ok, event} <- Events.activation_failed({:anonymous, nil}, nil),
         {:ok, _audit} <- Writer.append(event, {:allow, :sys_01}) do
      {:error, :activation_failed}
    else
      _audit_unavailable -> {:error, :activation_failed}
    end
  rescue
    _audit_unavailable -> {:error, :activation_failed}
  end

  defp verifier_key(opts) do
    case Keyword.get(opts, :verifier_key) do
      key when is_binary(key) and byte_size(key) >= 32 -> {:ok, key}
      _invalid -> {:error, :invalid_verifier_key}
    end
  end

  defp invitation_ttl_seconds do
    case Application.get_env(:origen, :internal_invitation_ttl_seconds) do
      seconds when is_integer(seconds) and seconds > 0 -> {:ok, seconds}
      _invalid -> {:error, :invalid_configuration}
    end
  end

  defp normalize_email(email) do
    case String.trim(email) do
      "" -> {:error, :invalid_request}
      clean_email -> {:ok, clean_email}
    end
  end

  defp role_atom("administrator"), do: :administrator
  defp role_atom("professional"), do: :professional
  defp role_atom("secretary"), do: :secretary
  defp role_atom(_unknown), do: :unknown

  defp state_atom("active"), do: :active
  defp state_atom("pending_activation"), do: :pending_activation
  defp state_atom(_unknown), do: :unknown

  defp unwrap_invitation_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_invitation_transaction({:error, reason}), do: {:error, reason}

  defp record_audit_success(account) do
    role_atom =
      case account.role do
        "administrator" -> :administrator
        "professional" -> :professional
        "secretary" -> :secretary
        _ -> :anonymous
      end

    with {:ok, event} <-
           Events.internal_login_succeeded(
             {role_atom, to_string(account.id)},
             to_string(account.id)
           ),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  defp record_audit_failure(account_id) do
    ref = if is_integer(account_id), do: to_string(account_id), else: nil

    with {:ok, event} <- Events.internal_login_failed({:anonymous, nil}, ref),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  rescue
    _ -> :ok
  end
end
