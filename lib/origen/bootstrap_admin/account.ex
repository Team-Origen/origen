defmodule Origen.BootstrapAdmin.Account do
  @moduledoc "Account-side orchestration for the first-administrator lifecycle."

  alias Origen.BootstrapAdmin.Delivery
  alias Origen.Repo

  @spec issue_first(map()) :: {:ok, map()} | {:error, atom()}
  def issue_first(%{verifier_key: key} = options) when is_binary(key) do
    issued_by_ref = Map.get(options, :issued_by_ref)

    Repo.transaction(fn ->
      Repo.query!("SELECT id FROM admin_bootstrap_controls WHERE id = 1 FOR UPDATE")

      if administrator_exists?(), do: Repo.rollback(:administrator_exists)

      Delivery.create_invitation(nil, key, issued_by_ref, :bootstrap_admin)
    end)
    |> unwrap_transaction()
  end

  def issue_first(_options), do: {:error, :invalid_verifier_key}

  @spec reissue_first(integer(), map()) :: {:ok, map()} | {:error, atom()}
  def reissue_first(account_id, %{verifier_key: key} = options)
      when is_integer(account_id) and is_binary(key) do
    issued_by_ref = Map.get(options, :issued_by_ref)

    Repo.transaction(fn ->
      Repo.query!("SELECT id, state FROM internal_accounts WHERE id = $1 FOR UPDATE", [account_id])

      case Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [account_id]).rows do
        [["pending_activation"]] ->
          Repo.query!(
            """
            UPDATE internal_account_invitations
            SET revoked_at = clock_timestamp()
            WHERE account_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL
            """,
            [account_id]
          )

          Delivery.create_invitation(account_id, key, issued_by_ref, :invitation_reissue)

        [["active"]] ->
          Repo.rollback(:administrator_active)

        [] ->
          Repo.rollback(:account_not_found)
      end
    end)
    |> unwrap_transaction()
  end

  def reissue_first(_account_id, _options), do: {:error, :invalid_request}

  defp administrator_exists? do
    Repo.query!("SELECT 1 FROM internal_accounts WHERE role = 'administrator' LIMIT 1").rows != []
  end

  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
