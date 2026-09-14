defmodule Origen.BootstrapAdmin.Local.Command do
  @moduledoc """
  Coordinates the local first-administrator lifecycle:
  Readiness -> Authorization -> Secrets -> Account.issue_first / Account.reissue_first -> Mailbox.deliver
  with fail-closed revocation on any post-issuance failure or uncertainty.
  """

  alias Origen.Audit.{Events, Writer}
  alias Origen.BootstrapAdmin.Account
  alias Origen.BootstrapAdmin.Delivery
  alias Origen.BootstrapAdmin.Local.{Authorization, Mailbox, MailboxStore, Secrets}

  @spec run(map(), keyword()) :: {:ok, map()} | {:error, atom()} | {:error, atom(), map()}
  def run(parsed, opts \\ []) do
    store = Keyword.get(opts, :store, MailboxStore)
    account_id = Map.get(parsed, :account_id)

    # Recovery or initial issue requires mailbox to be empty
    if store.count() > 0 do
      {:error, :mailbox_retained}
    else
      with {:ok, destination, target} <- Authorization.authorize(opts),
           :ok <- validate_target_match(target, account_id),
           {:ok, verifier_key} <- Secrets.get_verifier_key(),
           {:ok, invitation} <- issue_or_reissue(target, verifier_key) do
        deliver_and_audit(invitation, destination, opts)
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_target_match(nil, nil), do: :ok
  defp validate_target_match(%{id: target_id}, target_id) when is_integer(target_id), do: :ok
  defp validate_target_match(_target, _account_id), do: {:error, :target_unauthorized}

  defp issue_or_reissue(nil, verifier_key) do
    Account.issue_first(%{verifier_key: verifier_key, issued_by_ref: "local_source_checkout"})
  end

  defp issue_or_reissue(%{id: account_id}, verifier_key) do
    Account.reissue_first(account_id, %{
      verifier_key: verifier_key,
      issued_by_ref: "local_source_checkout"
    })
  end

  defp deliver_and_audit(invitation, destination, opts) do
    transient = %{reference: to_string(invitation.invitation_id), token: invitation.token}
    mailbox = Keyword.get(opts, :mailbox, Mailbox)

    deliver_opts = opts ++ [destination: destination]

    case deliver_safely(mailbox, transient, deliver_opts) do
      {:ok, %{correlation_ref: ref}} ->
        case append_handoff(invitation.invitation_id, ref) do
          :ok ->
            {:ok,
             %{
               account_id: invitation.account_id,
               invitation_id: invitation.invitation_id,
               correlation_ref: ref,
               outcome: :delivered
             }}

          {:error, _audit_reason} ->
            compensate(invitation)
        end

      {:error, _delivery_reason} ->
        compensate(invitation)
    end
  end

  defp deliver_safely(mailbox, transient, deliver_opts) do
    mailbox.deliver(transient, deliver_opts)
  rescue
    _ -> {:error, :mailbox_handoff_failed}
  catch
    _, _ -> {:error, :mailbox_handoff_failed}
  end

  defp append_handoff(invitation_id, ref) do
    with {:ok, event} <-
           Events.invitation_delivery_handoff({:provider, ref}, to_string(invitation_id)),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}),
         do: :ok,
         else: (_ -> {:error, :audit_unavailable})
  end

  defp compensate(invitation) do
    case Delivery.revoke_delivery_failure(invitation.invitation_id, %{
           account_id: invitation.account_id
         }) do
      {:ok, outcome} ->
        {:error, :delivery_failed,
         %{
           account_id: invitation.account_id,
           invitation_id: invitation.invitation_id,
           outcome: outcome,
           next_action: :obtain_fresh_approval_and_issue_fresh_invitation
         }}

      {:error, reason} ->
        {:error, reason,
         %{
           account_id: invitation.account_id,
           invitation_id: invitation.invitation_id,
           outcome: :failed_closed
         }}
    end
  end
end
