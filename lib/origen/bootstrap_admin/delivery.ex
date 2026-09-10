defmodule Origen.BootstrapAdmin.Delivery do
  @moduledoc "Invitation persistence boundary used by lifecycle operations."

  alias Origen.Audit.{Events, Writer}
  alias Origen.BootstrapAdmin.Verifier
  alias Origen.Repo

  @spec create_invitation(integer() | nil, binary(), binary() | nil, atom()) :: map()
  def create_invitation(account_id, key, issued_by_ref, event) do
    account_id = account_id || insert_account!()
    %{token: token, verifier_version: version, verifier_digest: digest} = Verifier.issue(key)

    %{rows: [[invitation_id, issued_at, expires_at]]} =
      Repo.query!(
        """
        INSERT INTO internal_account_invitations
          (account_id, verifier_version, verifier_digest, issued_by_ref, expires_at)
        VALUES ($1, $2, $3, $4, clock_timestamp() + interval '24 hours')
        RETURNING id, issued_at, expires_at
        """,
        [account_id, version, digest, issued_by_ref]
      )

    audit_event!(event, account_id)

    %{
      account_id: account_id,
      invitation_id: invitation_id,
      token: token,
      issued_at: issued_at,
      expires_at: expires_at
    }
  end

  def append_approval!(invitation_id, %{requester_ref: requester_ref}) do
    append_audit!(
      Events.invitation_approval_confirmed(
        {:administrator, requester_ref},
        to_string(invitation_id)
      )
    )
  end

  @spec revoke_delivery_failure(integer(), map()) ::
          {:ok, :revoked | :already_revoked} | {:error, atom()}
  def revoke_delivery_failure(invitation_id, context)
      when is_integer(invitation_id) and is_map(context) do
    result =
      Repo.transaction(fn ->
        case Repo.query!(
               "SELECT consumed_at, revoked_at FROM internal_account_invitations WHERE id = $1 FOR UPDATE",
               [invitation_id]
             ).rows do
          [[nil, nil]] ->
            Repo.query!(
              "UPDATE internal_account_invitations SET revoked_at = clock_timestamp() WHERE id = $1",
              [invitation_id]
            )

            append_audit!(
              Events.invitation_delivery_failed({:system, nil}, to_string(invitation_id))
            )

            append_audit!(
              Events.invitation_delivery_revoked({:system, nil}, to_string(invitation_id))
            )

            :revoked

          [[nil, revoked_at]] when not is_nil(revoked_at) ->
            :already_revoked

          [[consumed_at, _]] when not is_nil(consumed_at) ->
            Repo.rollback(:invitation_consumed)

          [] ->
            Repo.rollback(:invitation_not_found)
        end
      end)

    case result do
      {:ok, outcome} ->
        {:ok, outcome}

      {:error, reason} ->
        best_effort_revocation_failure(invitation_id)
        {:error, reason}
    end
  rescue
    _exception ->
      best_effort_revocation_failure(invitation_id)
      {:error, :revocation_failed}
  end

  def revoke_delivery_failure(_invitation_id, _context), do: {:error, :invalid_request}

  defp best_effort_revocation_failure(invitation_id) do
    with {:ok, event} <-
           Events.delivery_revocation_failed({:system, nil}, to_string(invitation_id)),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}),
         do: :ok,
         else: (_ -> :error)
  rescue
    _ -> :error
  end

  defp insert_account! do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO internal_accounts (role, state) VALUES ('administrator', 'pending_activation') RETURNING id"
      )

    id
  end

  defp audit_event!(:bootstrap_admin, account_id),
    do: append_audit!(Events.bootstrap_allowed({:system, nil}, to_string(account_id)))

  defp audit_event!(:invitation_reissue, account_id),
    do: append_audit!(Events.reissue_allowed({:system, nil}, to_string(account_id)))

  defp append_audit!({:ok, event}), do: Writer.append(event, {:allow, :sys_01}) |> audit_result()
  defp append_audit!(_event), do: Repo.rollback(:audit_unavailable)

  defp audit_result({:ok, _audit}), do: :ok
  defp audit_result({:error, reason}), do: Repo.rollback(reason)
end
