defmodule Origen.BootstrapAdmin.Invitation do
  @moduledoc "Locked invitation consumption and account activation."

  alias Origen.Audit.{Events, Writer}
  alias Origen.BootstrapAdmin.Verifier
  alias Origen.Repo

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
          Repo.query!("SELECT id FROM internal_accounts WHERE id = $1 FOR UPDATE", [account_id])

          case Repo.query!(
                 """
                   SELECT account_id, verifier_version, verifier_digest, expires_at, consumed_at, revoked_at
                   FROM internal_account_invitations WHERE id = $1 FOR UPDATE
                 """,
                 [invitation_id]
               ).rows do
            [[^account_id, version, digest, expires_at, consumed_at, revoked_at]] ->
              ensure_usable!(expires_at, consumed_at, revoked_at)

              unless Verifier.verify(token, version, digest, key),
                do: Repo.rollback(:invalid_token)

              Repo.query!(
                "UPDATE internal_account_invitations SET consumed_at = clock_timestamp() WHERE id = $1",
                [invitation_id]
              )

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
                  {:ok, event} =
                    Events.activation_succeeded({:system, nil}, to_string(account_id))

                  case Writer.append(event, {:allow, :sys_01}) do
                    {:ok, _audit} -> %{account_id: account_id, invitation_id: invitation_id}
                    {:error, reason} -> Repo.rollback(reason)
                  end

                [] ->
                  Repo.rollback(:account_not_pending)
              end

            [] ->
              Repo.rollback(:invitation_not_found)
          end

        [] ->
          Repo.rollback(:invitation_not_found)
      end
    end)
    |> unwrap_transaction()
  end

  def activate(_invitation_id, _token, _key, _credentials), do: {:error, :invalid_request}

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

  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
