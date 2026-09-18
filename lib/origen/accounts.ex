defmodule Origen.Accounts do
  @moduledoc """
  Authentication and account lifecycle operations for internal users.
  """

  alias Origen.Audit.{Events, Writer}
  alias Origen.BootstrapAdmin.Credentials
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
