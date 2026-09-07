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
