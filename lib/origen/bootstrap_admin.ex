defmodule Origen.BootstrapAdmin do
  @moduledoc "Transactional first-administrator account and invitation lifecycle."

  alias Origen.Audit.{Events, Writer}
  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}

  alias Origen.BootstrapAdmin.{
    Account,
    ApprovalVerifier,
    DeliveryConfig,
    Invitation,
    InvitationEmail,
    Provider
  }

  defdelegate issue_first(options), to: Account
  defdelegate reissue_first(account_id, options), to: Account
  defdelegate exchange(invitation_id, token, key), to: Invitation
  defdelegate consume(invitation_id, token, key), to: Invitation
  defdelegate activate(invitation_id, token, key, credentials), to: Invitation
  defdelegate activate_bound(invitation_id, account_id, credentials), to: Invitation

  def revoke_delivery_failure(invitation_id, context),
    do: Origen.BootstrapAdmin.Delivery.revoke_delivery_failure(invitation_id, context)

  def issue_and_deliver(request, adapters \\ []) when is_map(request) do
    gate = Keyword.get(adapters, :gate, &Origen.BootstrapAdmin.Gate.check/0)
    config_validator = Keyword.get(adapters, :delivery_config, &DeliveryConfig.validate/1)
    approval_verifier = Keyword.get(adapters, :approval_verifier, &ApprovalVerifier.verify/3)
    authorize = Keyword.get(adapters, :authorize, &authorize_delivery/2)
    provider = Keyword.fetch!(adapters, :provider)

    with :ok <- gate.(),
         {:ok, config} <- config_validator.(request.delivery_config),
         {:ok, approval} <-
           approval_verifier.(request.approval_assertion, request, request.approval_config),
         :ok <- authorize.(approval, request),
         {:ok, invitation} <- issue(Map.put(request, :approval, approval)) do
      handoff(invitation, approval, config, provider)
    else
      {:error, reason} -> {:error, reason, nil}
    end
  end

  defp issue(%{operation: :issue} = request),
    do: Account.issue_first(Map.take(request, [:verifier_key, :issued_by_ref, :approval]))

  defp issue(%{operation: :reissue, account_ref: id} = request) when is_integer(id),
    do: Account.reissue_first(id, Map.take(request, [:verifier_key, :issued_by_ref, :approval]))

  defp issue(_request), do: {:error, :invalid_request}

  defp authorize_delivery(approval, request) do
    approval_request =
      Request.new(
        operation: Fact.known(:approve_bootstrap_invitation),
        subject: Fact.known({:channel, :deployment_approval}),
        account_state: :not_applicable,
        target:
          Fact.known(%{distinct_principals: approval.requester_ref != approval.confirmer_ref}),
        scope:
          Fact.known(%{
            destination_matches: approval.destination == request.destination,
            environment_matches: approval.environment == request.environment,
            operation_matches: approval.operation == request.operation,
            account_matches: approval.account_ref == request.account_ref,
            non_production: request.environment == "staging",
            assertion_valid: true,
            confirmer_authorized: true
          })
      )

    with {:allow, :apr_01} <- Authorization.decide(approval_request),
         {:allow, _rule} <- Authorization.decide(issue_request(request)) do
      :ok
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp issue_request(%{operation: :issue}) do
    authorization_request(:bootstrap_first_administrator, %{administrator_exists: false})
  end

  defp issue_request(%{operation: :reissue}) do
    authorization_request(:reissue_internal_invitation, %{
      role: :administrator,
      state: :pending_activation
    })
  end

  defp authorization_request(operation, target) do
    Request.new(
      operation: Fact.known(operation),
      subject: Fact.known({:channel, :deployment}),
      account_state: :not_applicable,
      target: Fact.known(target),
      scope:
        Fact.known(%{
          approved_command: true,
          assigned_operator: true,
          approval_authorized: true,
          active_administrator_exists: false
        })
    )
  end

  defp handoff(invitation, approval, config, provider) do
    transient = %{reference: to_string(invitation.invitation_id), token: invitation.token}

    with {:ok, email} <- InvitationEmail.build(transient, approval, config.origin, config),
         {:ok, %{correlation_ref: ref}} <-
           deliver_safely(provider, email, invitation.invitation_id, config),
         :ok <- append_handoff(invitation.invitation_id, ref) do
      {:ok,
       %{
         account_id: invitation.account_id,
         invitation_id: invitation.invitation_id,
         correlation_ref: ref,
         outcome: :delivered
       }}
    else
      _safe_failure -> compensate(invitation)
    end
  end

  defp deliver_safely(provider, email, invitation_id, config) do
    Provider.deliver(provider, email, %{invitation_id: invitation_id}, config)
  rescue
    _exception -> {:error, :provider_handoff_failed}
  catch
    _kind, _reason -> {:error, :provider_handoff_failed}
  end

  defp append_handoff(invitation_id, ref) do
    with {:ok, event} <-
           Events.invitation_delivery_handoff({:provider, ref}, to_string(invitation_id)),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}),
         do: :ok,
         else: (_ -> {:error, :audit_unavailable})
  end

  defp compensate(invitation) do
    case revoke_delivery_failure(invitation.invitation_id, %{account_id: invitation.account_id}) do
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
