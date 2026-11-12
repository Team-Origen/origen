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
  @staff_roles ~w(professional secretary)
  @staff_role_atoms [:professional, :secretary]

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

  @doc "Returns only the authenticated Secretary's own email for account navigation."
  @spec get_own_navigation_identity(map()) ::
          {:ok, %{email: String.t() | nil}} | {:error, :unauthenticated | :unavailable}
  def get_own_navigation_identity(%{session_id: session_id, account_id: account_id})
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      with {:ok, %{account_id: owner_id, role: :secretary}} <-
             Sessions.revalidate_principal(session_id, account_id),
           {:ok, %{rows: [[email]]}} <-
             Repo.query("SELECT email FROM internal_accounts WHERE id = $1", [owner_id]) do
        %{email: email}
      else
        _ -> Repo.rollback(:unauthenticated)
      end
    end)
  rescue
    _ -> {:error, :unavailable}
  end

  def get_own_navigation_identity(_), do: {:error, :unauthenticated}

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
  Lists professional and secretary accounts as a sanitized administrative
  projection for an active Administrator (contract #372).

  The projection never exposes credentials, TOTP material, patient identities,
  or agendas; it includes the count of future affected appointments so the
  Administrator can flag Secretary follow-up without opening operational data.
  Accepts an administrator account id, a revalidated session principal
  (`%{session_id: _, account_id: _}`), or an id map as `actor`.
  """
  @spec list_internal_accounts(integer() | map(), keyword()) ::
          {:ok, [map()]} | {:error, :unauthorized}
  def list_internal_accounts(actor, opts \\ [])

  def list_internal_accounts(actor, opts) when is_list(opts) do
    Repo.transaction(fn ->
      administrator = resolve_administrator_actor!(actor)

      authorize_administrator_lifecycle!(
        administrator,
        :list_internal_accounts,
        %{roles: @staff_role_atoms}
      )

      now = Keyword.get(opts, :now, DateTime.utc_now())

      Repo.query!("""
      SELECT id, email, role, state, activated_at, created_at, updated_at
      FROM internal_accounts
      WHERE role IN ('professional', 'secretary')
      ORDER BY id ASC
      """).rows
      |> Enum.map(fn [id, email, role, state, activated_at, created_at, updated_at] ->
        %{
          id: id,
          email: email,
          role: role_atom(role),
          state: state_atom(state),
          activated_at: activated_at,
          created_at: created_at,
          updated_at: updated_at,
          future_affected_appointments_count: future_affected_appointments_count(role, id, now)
        }
      end)
    end)
  end

  def list_internal_accounts(_actor, _opts), do: {:error, :unauthorized}

  @doc """
  Edits the administrative email of a professional or secretary account.

  The email is normalized with `trim + downcase`, validated, and checked for
  case-insensitive uniqueness (`{:error, :invalid_email}` / `{:error,
  :email_taken}`). The account `id`, role, state, credentials, appointments, and
  relationships are preserved. Only an active Administrator may perform the
  operation; every rejection leaves zero mutations and zero audit events.
  """
  @spec update_internal_account(integer() | map(), integer(), map(), keyword()) ::
          {:ok, map()} | {:error, :unauthorized | :invalid_email | :email_taken}
  def update_internal_account(actor, target_account_id, attrs, opts \\ [])

  def update_internal_account(actor, target_account_id, attrs, opts)
      when is_integer(target_account_id) and is_map(attrs) and is_list(opts) do
    Repo.transaction(fn ->
      administrator = resolve_administrator_actor!(actor)
      target = lock_account!(target_account_id, "FOR UPDATE")
      ensure_staff_target!(target)

      authorize_administrator_lifecycle!(
        administrator,
        :update_internal_account,
        %{role: role_atom(target.role), state: state_atom(target.state)}
      )

      clean_email = normalize_update_email!(attrs)
      ensure_email_available!(clean_email, target.id)

      %{rows: [[^target_account_id]]} =
        Repo.query!(
          """
          UPDATE internal_accounts
          SET email = $2, updated_at = clock_timestamp()
          WHERE id = $1
          RETURNING id
          """,
          [target.id, clean_email]
        )

      append_lifecycle_audit!(
        Events.internal_account_updated(
          {:administrator, to_string(administrator.id)},
          to_string(target.id)
        )
      )

      count =
        future_affected_appointments_count(
          target.role,
          target.id,
          Keyword.get(opts, :now, DateTime.utc_now())
        )

      %{
        id: target.id,
        email: clean_email,
        role: role_atom(target.role),
        state: state_atom(target.state),
        future_affected_appointments_count: count
      }
    end)
  end

  def update_internal_account(_actor, _target_account_id, _attrs, _opts),
    do: {:error, :unauthorized}

  @doc "Alias for `update_internal_account/4` using the contract's public verb."
  def update_staff_account_email(actor, target_account_id, attrs),
    do: update_internal_account(actor, target_account_id, attrs)

  @doc """
  Deactivates a professional or secretary account atomically (contract #372).

  Moves the account to `"deactivated"` (credentials and `activated_at` are kept
  when the account had been activated), revokes every active session and any
  pending invitation, preserves all appointments and history untouched, and
  returns the count of future affected appointments (`requested`, `confirmed`,
  or `reserved` starting after `now`; `0` for Secretary accounts) without
  exposing patient identities or agendas.
  """
  @spec deactivate_internal_account(integer() | map(), integer(), keyword()) ::
          {:ok, map()} | {:error, :unauthorized}
  def deactivate_internal_account(actor, target_account_id, opts \\ [])

  def deactivate_internal_account(actor, target_account_id, opts)
      when is_integer(target_account_id) and is_list(opts) do
    Repo.transaction(fn ->
      administrator = resolve_administrator_actor!(actor)
      target = lock_account!(target_account_id, "FOR UPDATE")
      ensure_staff_target!(target)

      authorize_administrator_lifecycle!(
        administrator,
        :deactivate_internal_account,
        %{role: role_atom(target.role), state: state_atom(target.state)}
      )

      now = Keyword.get(opts, :now, DateTime.utc_now())

      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'deactivated', updated_at = clock_timestamp()
        WHERE id = $1
        """,
        [target.id]
      )

      :ok = Sessions.terminate_all_sessions(target.id, now: now)

      Repo.query!(
        """
        UPDATE internal_account_invitations
        SET revoked_at = clock_timestamp()
        WHERE account_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL
        """,
        [target.id]
      )

      count = future_affected_appointments_count(target.role, target.id, now)

      append_lifecycle_audit!(
        Events.internal_account_deactivated(
          {:administrator, to_string(administrator.id)},
          to_string(target.id)
        )
      )

      staff_account_result(target, :deactivated, count)
    end)
  end

  def deactivate_internal_account(_actor, _target_account_id, _opts),
    do: {:error, :unauthorized}

  @doc """
  Reactivates a deactivated professional or secretary account (contract #372).

  Restores `"active"` when the account kept its enrolled credentials, or
  `"pending_activation"` when it was deactivated before activation (allowing a
  fresh invitation). Existing appointments are never modified: cancelled
  appointments stay cancelled and pending requests keep their state.
  """
  @spec reactivate_internal_account(integer() | map(), integer(), keyword()) ::
          {:ok, map()} | {:error, :unauthorized}
  def reactivate_internal_account(actor, target_account_id, opts \\ [])

  def reactivate_internal_account(actor, target_account_id, opts)
      when is_integer(target_account_id) and is_list(opts) do
    Repo.transaction(fn ->
      administrator = resolve_administrator_actor!(actor)
      target = lock_staff_account!(target_account_id)
      ensure_staff_target!(target)

      authorize_administrator_lifecycle!(
        administrator,
        :reactivate_internal_account,
        %{role: role_atom(target.role), state: state_atom(target.state)}
      )

      restored_state =
        if is_binary(target.password_hash) and is_binary(target.totp_secret) and
             not is_nil(target.activated_at) do
          "active"
        else
          "pending_activation"
        end

      Repo.query!(
        "UPDATE internal_accounts SET state = $2, updated_at = clock_timestamp() WHERE id = $1",
        [target.id, restored_state]
      )

      count =
        future_affected_appointments_count(
          target.role,
          target.id,
          Keyword.get(opts, :now, DateTime.utc_now())
        )

      append_lifecycle_audit!(
        Events.internal_account_reactivated(
          {:administrator, to_string(administrator.id)},
          to_string(target.id)
        )
      )

      staff_account_result(target, state_atom(restored_state), count)
    end)
  end

  def reactivate_internal_account(_actor, _target_account_id, _opts),
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
      _invalid -> opaque_activation_failure()
    end
  end

  def prepare_internal_account_activation(_invitation_id, _token, _opts),
    do: opaque_activation_failure()

  @doc """
  Activates a pending professional or secretary account atomically: consumes its invitation,
  stores the Argon2 password hash and the keyring-encrypted TOTP secret, and activates the
  account in one transaction. Every rejection fails closed with `{:error, :activation_failed}`
  and an opaque audit event without account or invitation references.

  ## Options

    * `:verifier_key` - shared invitation verifier key.
    * `:totp_keyring` - explicit keyring used to encrypt the TOTP seed.
    * `:time` - optional unix timestamp in seconds used for TOTP validation.
    * `:password_only` - academic demo mode (see `Origen.AcademicDemo`). When true the TOTP
      code is not checked, but the TOTP seed is still encrypted and stored. Defaults to false.
  """
  @spec activate_internal_account(map(), map(), keyword()) ::
          {:ok, %{account_id: integer(), invitation_id: integer()}}
          | {:error, :activation_failed | :audit_unavailable}
  def activate_internal_account(activation, params, opts \\ [])

  def activate_internal_account(
        %{
          invitation_id: invitation_id,
          account_id: account_id,
          token: token,
          totp_seed: totp_seed
        },
        %{password: password, password_confirmation: password_confirmation, totp_code: totp_code},
        opts
      )
      when is_integer(invitation_id) and is_integer(account_id) and is_binary(token) and
             is_binary(totp_seed) and is_binary(password) and is_binary(password_confirmation) and
             is_binary(totp_code) and is_list(opts) do
    with {:ok, key} <- verifier_key(opts),
         {:ok, keyring} <- activation_totp_keyring(opts) do
      time = Keyword.get(opts, :time, System.os_time(:second))

      Repo.transaction(fn ->
        account = lock_account!(account_id, "FOR UPDATE")

        unless account.role in @staff_roles and account.state == "pending_activation",
          do: Repo.rollback(:activation_failed)

        lock_and_validate_activation_invitation!(invitation_id, account_id, token, key)
        authorize_staff_activation!(account.role)

        ensure_activation_factors!(
          password,
          password_confirmation,
          totp_seed,
          totp_code,
          time,
          Keyword.get(opts, :password_only, false)
        )

        password_hash = Credentials.hash_password(password)
        encrypted_seed = encrypt_activation_seed!(totp_seed, keyring)

        Repo.query!(
          "UPDATE internal_account_invitations SET consumed_at = clock_timestamp() WHERE id = $1",
          [invitation_id]
        )

        activate_staff_account!(account_id, password_hash, encrypted_seed)
        append_activation_success_audit!(account_id, invitation_id)
      end)
      |> case do
        {:ok, result} ->
          {:ok, result}

        {:error, :audit_unavailable} ->
          _ = opaque_activation_failure()
          {:error, :audit_unavailable}

        {:error, _reason} ->
          opaque_activation_failure()
      end
    else
      _invalid -> opaque_activation_failure()
    end
  end

  def activate_internal_account(_activation, _params, _opts), do: opaque_activation_failure()

  @doc """
  Authenticates an internal account using an identifier (email or id), password, and TOTP code.

  ## Options
    * `:create_session` - boolean, defaults to true. When true, creates an internal session.
    * `:time` - optional unix timestamp in seconds used for TOTP validation.
    * `:keyring` - optional explicit keyring map for decrypting TOTP secrets.
    * `:session_opts` - keyword options passed to `Origen.Sessions.create_session/2`.
    * `:password_only` - academic demo mode (see `Origen.AcademicDemo`). When true the TOTP
      code is ignored; password, account state, role, and audit checks still apply.
      Defaults to false.

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

    cond do
      not (is_active and role_allowed and pwd_valid) ->
        reject_authentication(account, pwd_valid)

      Keyword.get(opts, :password_only, false) ->
        complete_authentication(account)

      true ->
        validate_totp_and_complete(account, totp_code, opts)
    end
  end

  defp reject_authentication(account, pwd_valid) do
    unless pwd_valid do
      if is_nil(account.password_hash), do: Argon2.no_user_verify()
    end

    Repo.rollback({:unauthenticated, account.id})
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

      complete_authentication(account)
    else
      _ ->
        Repo.rollback({:unauthenticated, account.id})
    end
  end

  defp complete_authentication(account) do
    record_audit_success(account)

    %{
      id: account.id,
      email: account.email,
      role: account.role,
      state: account.state
    }
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

  defp resolve_administrator_actor!(%{session_id: session_id, account_id: account_id})
       when is_integer(session_id) and is_integer(account_id) do
    case Sessions.revalidate_principal(session_id, account_id) do
      {:ok, _session} -> lock_account!(account_id, "FOR SHARE")
      _stale -> Repo.rollback(:unauthorized)
    end
  end

  defp resolve_administrator_actor!(actor_id) when is_integer(actor_id),
    do: lock_account!(actor_id, "FOR SHARE")

  defp resolve_administrator_actor!(%{id: account_id}) when is_integer(account_id),
    do: lock_account!(account_id, "FOR SHARE")

  defp resolve_administrator_actor!(%{"id" => account_id}) when is_integer(account_id),
    do: lock_account!(account_id, "FOR SHARE")

  defp resolve_administrator_actor!(_invalid), do: Repo.rollback(:unauthorized)

  defp ensure_staff_target!(target) do
    unless target.role in @staff_roles, do: Repo.rollback(:unauthorized)
    :ok
  end

  defp authorize_administrator_lifecycle!(actor, operation, target) do
    request =
      Request.new(
        operation: Fact.known(operation),
        subject: Fact.known({:role, role_atom(actor.role)}),
        account_state: Fact.known(state_atom(actor.state)),
        target: Fact.known(target),
        scope: :not_applicable
      )

    case Authorization.decide(request) do
      {:allow, _rule} -> :ok
      _denied -> Repo.rollback(:unauthorized)
    end
  end

  defp lock_staff_account!(account_id) do
    case Repo.query!(
           """
           SELECT id, email, role, state, password_hash, totp_secret, activated_at
           FROM internal_accounts
           WHERE id = $1
           FOR UPDATE
           """,
           [account_id]
         ).rows do
      [[id, email, role, state, password_hash, totp_secret, activated_at]] ->
        %{
          id: id,
          email: email,
          role: role,
          state: state,
          password_hash: password_hash,
          totp_secret: totp_secret,
          activated_at: activated_at
        }

      [] ->
        Repo.rollback(:unauthorized)
    end
  end

  @doc """
  Normalizes an internal account email (`trim + downcase`) and checks its shape.

  Shared by staff email edits and first-Administrator activation so both apply
  the same rule.
  """
  @spec normalize_internal_email(term()) :: {:ok, String.t()} | {:error, :invalid_email}
  def normalize_internal_email(raw) when is_binary(raw) do
    clean = raw |> String.trim() |> String.downcase()

    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, clean),
      do: {:ok, clean},
      else: {:error, :invalid_email}
  end

  def normalize_internal_email(_raw), do: {:error, :invalid_email}

  @doc """
  Returns `:ok` when no other internal account uses `email` (case-insensitive),
  else `{:error, :email_taken}`. Meant to run inside the caller's transaction.
  """
  @spec internal_email_available(String.t(), integer()) :: :ok | {:error, :email_taken}
  def internal_email_available(email, account_id) do
    case Repo.query!(
           "SELECT 1 FROM internal_accounts WHERE lower(email) = lower($1) AND id != $2",
           [email, account_id]
         ).rows do
      [] -> :ok
      _taken -> {:error, :email_taken}
    end
  end

  defp normalize_update_email!(attrs) do
    raw = Map.get(attrs, :email) || Map.get(attrs, "email")

    case normalize_internal_email(raw) do
      {:ok, clean} -> clean
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp ensure_email_available!(email, account_id) do
    case internal_email_available(email, account_id) do
      :ok -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp future_affected_appointments_count("professional", account_id, %DateTime{} = now) do
    %{rows: [[count]]} =
      Repo.query!(
        """
        SELECT count(*)
        FROM appointments
        WHERE professional_account_id = $1
          AND start_time > $2
          AND status IN ('requested', 'confirmed', 'reserved')
        """,
        [account_id, now]
      )

    count
  end

  defp future_affected_appointments_count(_secretary, _account_id, _now), do: 0

  defp append_lifecycle_audit!(event) do
    with {:ok, audit_event} <- event,
         {:ok, _audit} <- Writer.append(audit_event, {:allow, :sys_01}) do
      :ok
    else
      _audit_failure -> Repo.rollback(:audit_unavailable)
    end
  end

  defp staff_account_result(target, state_atom, count) do
    account = %{
      id: target.id,
      email: target.email,
      role: role_atom(target.role),
      state: state_atom,
      future_affected_appointments_count: count
    }

    Map.put(account, :account, account)
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

      [] ->
        case Repo.query!(
               """
               SELECT id
               FROM internal_account_invitations
               WHERE account_id = $1 AND consumed_at IS NULL AND revoked_at IS NOT NULL
               LIMIT 1
               """,
               [account_id]
             ).rows do
          [[_revoked_id]] -> :ok
          _missing -> Repo.rollback(:unauthorized)
        end

      _invalid ->
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

  defp lock_and_validate_activation_invitation!(invitation_id, account_id, token, key) do
    case Repo.query!(
           """
           SELECT account_id, verifier_version, verifier_digest, expires_at, consumed_at, revoked_at
           FROM internal_account_invitations
           WHERE id = $1
           FOR UPDATE
           """,
           [invitation_id]
         ).rows do
      [[^account_id, version, digest, expires_at, nil, nil]] ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt and
             Verifier.verify(token, version, digest, key) do
          :ok
        else
          Repo.rollback(:activation_failed)
        end

      _invalid ->
        Repo.rollback(:activation_failed)
    end
  end

  defp ensure_activation_factors!(
         password,
         password_confirmation,
         seed,
         code,
         time,
         password_only
       ) do
    clean_code = String.trim(code)

    totp_valid =
      password_only or
        (Regex.match?(~r/^\d{6}$/, clean_code) and NimbleTOTP.valid?(seed, clean_code, time: time))

    factors_valid =
      password == password_confirmation and byte_size(password) in 12..1024 and totp_valid

    if factors_valid, do: :ok, else: Repo.rollback(:activation_failed)
  end

  defp encrypt_activation_seed!(seed, keyring) do
    case Credentials.encrypt_seed(seed, keyring) do
      {:ok, ciphertext} -> ciphertext
      _invalid -> Repo.rollback(:activation_failed)
    end
  end

  defp activate_staff_account!(account_id, password_hash, totp_secret) do
    rows =
      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'active', password_hash = $2, totp_secret = $3,
            activated_at = clock_timestamp(), updated_at = clock_timestamp()
        WHERE id = $1 AND state = 'pending_activation'
        RETURNING id
        """,
        [account_id, password_hash, totp_secret]
      ).rows

    if rows == [[account_id]], do: :ok, else: Repo.rollback(:activation_failed)
  end

  defp append_activation_success_audit!(account_id, invitation_id) do
    with {:ok, event} <- Events.activation_succeeded({:system, nil}, to_string(account_id)),
         {:ok, _audit} <- Writer.append(event, {:allow, :sys_01}) do
      %{account_id: account_id, invitation_id: invitation_id}
    else
      _audit_failure -> Repo.rollback(:audit_unavailable)
    end
  end

  defp authorize_staff_activation!(role) do
    request =
      Request.new(
        operation: Fact.known(:activate_internal_account),
        subject: Fact.known({:channel, :invitation}),
        account_state: Fact.known(:pending_activation),
        target: Fact.known(%{role: role_atom(role)}),
        scope:
          Fact.known(%{
            account_matches: true,
            password_defined: true,
            token_valid: true,
            totp_enrolled: true
          })
      )

    case Authorization.decide(request) do
      {:allow, :inv_01} -> :ok
      _denied -> Repo.rollback(:activation_failed)
    end
  end

  defp activation_totp_keyring(opts) do
    keyring =
      opts[:totp_keyring] || Application.get_env(:origen, :totp_keyring) ||
        Application.get_env(:origen, :bootstrap_admin_totp_keyring)

    case Credentials.validate_keyring(keyring) do
      :ok -> {:ok, keyring}
      _invalid -> {:error, :invalid_configuration}
    end
  end

  defp opaque_activation_failure do
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
    key =
      case Keyword.get(opts, :verifier_key) do
        k when is_binary(k) and byte_size(k) >= 32 ->
          k

        _ ->
          case Application.get_env(:origen, :bootstrap_admin_verifier_key) do
            k when is_binary(k) and byte_size(k) >= 32 ->
              k

            _ ->
              nil
          end
      end

    case key do
      k when is_binary(k) and byte_size(k) >= 32 -> {:ok, k}
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
  defp state_atom("deactivated"), do: :deactivated
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
