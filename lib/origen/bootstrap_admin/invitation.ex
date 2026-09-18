defmodule Origen.BootstrapAdmin.Invitation do
  @moduledoc "Locked invitation consumption and account activation."

  alias Origen.Audit.{Events, Writer}
  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.BootstrapAdmin.Verifier
  alias Origen.Repo

  @spec exchange(integer(), binary(), binary()) :: {:ok, map()} | {:error, atom()}
  def exchange(invitation_id, token, key)
      when is_integer(invitation_id) and is_binary(token) and is_binary(key) do
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
      when role in ["administrator", "professional", "secretary"] ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt and
             Verifier.verify(token, version, digest, key) do
          {:ok, %{account_id: account_id, invitation_id: invitation_id}}
        else
          {:error, :invalid_invitation}
        end

      _invalid ->
        {:error, :invalid_invitation}
    end
  end

  def exchange(_invitation_id, _token, _key), do: {:error, :invalid_request}

  @spec consume(integer(), binary(), binary()) :: {:ok, map()} | {:error, atom()}
  def consume(invitation_id, token, key)
      when is_integer(invitation_id) and is_binary(token) and is_binary(key) do
    Repo.transaction(fn ->
      rows =
        Repo.query!(
          """
            SELECT id, account_id, verifier_version, verifier_digest, expires_at,
                   consumed_at, revoked_at
            FROM internal_account_invitations WHERE id = $1 FOR UPDATE
          """,
          [invitation_id]
        ).rows

      case rows do
        [[id, account_id, version, digest, expires_at, consumed_at, revoked_at]] ->
          consume_locked(
            id,
            account_id,
            version,
            digest,
            expires_at,
            consumed_at,
            revoked_at,
            token,
            key
          )

        [] ->
          Repo.rollback(:invitation_not_found)
      end
    end)
    |> unwrap_transaction()
  end

  def consume(_invitation_id, _token, _key), do: {:error, :invalid_request}

  @spec activate(integer(), binary(), binary(), map()) :: {:ok, map()} | {:error, atom()}
  def activate(invitation_id, token, key, %{
        password_hash: password_hash,
        totp_secret: totp_secret
      })
      when is_integer(invitation_id) and is_binary(token) and is_binary(key) and
             is_binary(password_hash) and is_binary(totp_secret) do
    Repo.transaction(fn ->
      case Repo.query!(
             "SELECT account_id FROM internal_account_invitations WHERE id = $1",
             [invitation_id]
           ).rows do
        [[account_id]] ->
          account =
            Repo.query!(
              "SELECT role, state FROM internal_accounts WHERE id = $1 FOR UPDATE",
              [account_id]
            ).rows

          invitation =
            Repo.query!(
              """
              SELECT account_id, verifier_version, verifier_digest, expires_at, consumed_at, revoked_at
              FROM internal_account_invitations WHERE id = $1 FOR UPDATE
              """,
              [invitation_id]
            ).rows

          activate_locked!(
            account,
            invitation,
            account_id,
            invitation_id,
            token,
            key,
            password_hash,
            totp_secret
          )

        [] ->
          Repo.rollback(:invitation_not_found)
      end
    end)
    |> unwrap_transaction()
  end

  def activate(_invitation_id, _token, _key, _credentials), do: {:error, :invalid_request}

  @spec activate_bound(integer(), integer(), map()) :: {:ok, map()} | {:error, atom()}
  def activate_bound(invitation_id, account_id, %{
        password_hash: password_hash,
        totp_secret: totp_secret
      })
      when is_integer(invitation_id) and is_integer(account_id) and is_binary(password_hash) and
             is_binary(totp_secret) do
    Repo.transaction(fn ->
      account =
        Repo.query!(
          "SELECT role, state FROM internal_accounts WHERE id = $1 FOR UPDATE",
          [account_id]
        ).rows

      invitation =
        Repo.query!(
          """
            SELECT account_id, expires_at, consumed_at, revoked_at
            FROM internal_account_invitations WHERE id = $1 FOR UPDATE
          """,
          [invitation_id]
        ).rows

      case {account, invitation} do
        {[[role, "pending_activation"]], [[^account_id, expires_at, consumed_at, revoked_at]]}
        when role in ["administrator", "professional", "secretary"] ->
          ensure_usable!(expires_at, consumed_at, revoked_at)
          authorize_activation!(role)

          Repo.query!(
            "UPDATE internal_account_invitations SET consumed_at = clock_timestamp() WHERE id = $1",
            [invitation_id]
          )

          persist_activation!(account_id, invitation_id, password_hash, totp_secret)

        _invalid ->
          Repo.rollback(:invalid_session_binding)
      end
    end)
    |> unwrap_transaction()
  end

  def activate_bound(_invitation_id, _account_id, _credentials), do: {:error, :invalid_request}

  defp activate_locked!(
         [[role, state]],
         [[account_id, version, digest, expires_at, consumed_at, revoked_at]],
         account_id,
         invitation_id,
         token,
         key,
         password_hash,
         totp_secret
       )
       when role in ["administrator", "professional", "secretary"] do
    ensure_usable!(expires_at, consumed_at, revoked_at)
    if state != "pending_activation", do: Repo.rollback(:account_not_pending)
    unless Verifier.verify(token, version, digest, key), do: Repo.rollback(:invalid_token)

    Repo.query!(
      "UPDATE internal_account_invitations SET consumed_at = clock_timestamp() WHERE id = $1",
      [invitation_id]
    )

    authorize_activation!(role)
    persist_activation!(account_id, invitation_id, password_hash, totp_secret)
  end

  defp activate_locked!(_account, [], _account_id, _id, _token, _key, _hash, _secret),
    do: Repo.rollback(:invitation_not_found)

  defp activate_locked!(_account, _invitation, _account_id, _id, _token, _key, _hash, _secret),
    do: Repo.rollback(:account_not_pending)

  defp consume_locked(_, _, _, _, _, consumed, _, _, _) when not is_nil(consumed),
    do: Repo.rollback(:already_consumed)

  defp consume_locked(_, _, _, _, _, _, revoked, _, _) when not is_nil(revoked),
    do: Repo.rollback(:revoked)

  defp consume_locked(id, account_id, version, digest, expires_at, nil, nil, token, key) do
    if DateTime.compare(expires_at, DateTime.utc_now()) != :gt, do: Repo.rollback(:expired)

    if Verifier.verify(token, version, digest, key) do
      Repo.query!(
        "UPDATE internal_account_invitations SET consumed_at = clock_timestamp() WHERE id = $1",
        [id]
      )

      {:ok, event} = Events.invitation_consumed({:system, nil}, to_string(account_id))

      case Writer.append(event, {:allow, :sys_01}) do
        {:ok, _audit} -> %{account_id: account_id, invitation_id: id}
        {:error, reason} -> Repo.rollback(reason)
      end
    else
      Repo.rollback(:invalid_token)
    end
  end

  defp ensure_usable!(_, consumed, _) when not is_nil(consumed),
    do: Repo.rollback(:already_consumed)

  defp ensure_usable!(_, _, revoked) when not is_nil(revoked), do: Repo.rollback(:revoked)

  defp ensure_usable!(expires_at, nil, nil) do
    if DateTime.compare(expires_at, DateTime.utc_now()) != :gt, do: Repo.rollback(:expired)
  end

  defp authorize_activation!(role) do
    request =
      Request.new(
        operation: Fact.known(:activate_internal_account),
        subject: Fact.known({:channel, :invitation}),
        account_state: Fact.known(:pending_activation),
        target: Fact.known(%{role: String.to_existing_atom(role)}),
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
      _denied -> Repo.rollback(:unauthorized)
    end
  end

  defp persist_activation!(account_id, invitation_id, password_hash, totp_secret) do
    case Repo.query!(
           """
             UPDATE internal_accounts
             SET state = 'active', password_hash = $2, totp_secret = $3,
                 activated_at = clock_timestamp(), updated_at = clock_timestamp()
             WHERE id = $1 AND state = 'pending_activation' RETURNING id
           """,
           [account_id, password_hash, totp_secret]
         ).rows do
      [[^account_id]] ->
        {:ok, event} = Events.activation_succeeded({:system, nil}, to_string(account_id))

        case Writer.append(event, {:allow, :sys_01}) do
          {:ok, _audit} -> %{account_id: account_id, invitation_id: invitation_id}
          {:error, reason} -> Repo.rollback(reason)
        end

      [] ->
        Repo.rollback(:account_not_pending)
    end
  end

  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
