defmodule Origen.Authorization.Rules do
  @moduledoc false

  alias Origen.Authorization.Request

  @roles [:administrator, :professional, :secretary, :patient]
  @channels [
    :deployment,
    :deployment_approval,
    :invitation,
    :system,
    :public_possession,
    :local_profile
  ]
  @subjects Enum.map(@roles, &{:role, &1}) ++ Enum.map(@channels, &{:channel, &1})
  @bootstrap_operations [
    :bootstrap_local_first_administrator,
    :reissue_local_first_administrator,
    :approve_bootstrap_invitation,
    :bootstrap_first_administrator,
    :reissue_internal_invitation,
    :activate_internal_account
  ]

  @rules [
           {:loc_01, :bootstrap_local_first_administrator, {:channel, :local_profile},
            :not_applicable, %{administrator_exists: false},
            %{
              profile: :dev,
              readiness: :ready,
              destination: :example_test,
              database: :isolated,
              account: :none
            }},
           {:loc_02, :reissue_local_first_administrator, {:channel, :local_profile},
            :not_applicable, %{role: :administrator, state: :pending_activation},
            %{
              profile: :dev,
              readiness: :ready,
              destination: :example_test,
              database: :isolated,
              active_administrator_exists: false,
              account: :sole_pending
            }},
           {:apr_01, :approve_bootstrap_invitation, {:channel, :deployment_approval},
            :not_applicable, %{distinct_principals: true},
            %{
              destination_matches: true,
              environment_matches: true,
              operation_matches: true,
              account_matches: true,
              non_production: true,
              assertion_valid: true,
              confirmer_authorized: true
            }},
           {:dep_01, :bootstrap_first_administrator, {:channel, :deployment}, :not_applicable,
            %{administrator_exists: false},
            %{approved_command: true, assigned_operator: true, approval_authorized: true}},
           {:rei_01, :reissue_internal_invitation, {:channel, :deployment}, :not_applicable,
            %{role: :administrator, state: :pending_activation},
            %{
              active_administrator_exists: false,
              approved_command: true,
              assigned_operator: true,
              approval_authorized: true
            }},
           {:sys_01, :append_audit_event, {:channel, :system}, :not_applicable,
            %{event: :constructor_produced}, %{internal_path: true}},
           {:tel_02, :verify_patient_phone, {:channel, :public_possession}, :not_applicable,
            %{phone_verified: false},
            %{account_and_phone_match: true, challenge_valid: true, rate_limit_satisfied: true}},
           {:tel_01, :register_patient, {:role, :secretary}, :active, %{phone_verified: false},
            %{account_and_phone_match: true, rate_limit_satisfied: true}},
           {:own_02, :read_own_availability, {:role, :professional}, :active,
            %{owner_matches_actor: true}, %{authenticated: true}},
           {:own_02, :replace_own_availability, {:role, :professional}, :active,
            %{owner_matches_actor: true}, %{authenticated: true}},
           {:s1_02, :create_professional_account, {:role, :administrator}, :active,
            %{role: :professional, state: :pending_activation}, :not_applicable},
           {:s1_03, :create_secretary_account, {:role, :administrator}, :active,
            %{role: :secretary, state: :pending_activation}, :not_applicable}
         ] ++
           for(
             role <- [:administrator, :professional, :secretary],
             do:
               {:inv_01, :activate_internal_account, {:channel, :invitation}, :pending_activation,
                %{role: role},
                %{
                  account_matches: true,
                  password_defined: true,
                  token_valid: true,
                  totp_enrolled: true
                }}
           ) ++
           for(
             role <- [:administrator, :professional, :secretary],
             do:
               {:auth_01, :start_internal_session, {:role, role}, :active, :not_applicable,
                %{credentials_valid: true, session_policy_satisfied: true}}
           ) ++
           for(
             role <- [:professional, :secretary],
             do:
               {:rei_02, :reissue_internal_invitation, {:role, :administrator}, :active,
                %{role: role, state: :pending_activation}, %{authenticated: true}}
           )

  @operations @rules
              |> Enum.map(&elem(&1, 1))
              |> Enum.uniq()
              |> Kernel.++([:read_audit_log, :mutate_audit_event])

  def operations, do: @operations
  def subjects, do: @subjects
  def bootstrap_operations, do: @bootstrap_operations

  @spec decide(Request.t()) :: Origen.Authorization.Decision.t()
  def decide(%Request{} = request) do
    Enum.find_value(@rules, {:deny, :no_matching_rule}, fn
      {id, operation, subject, state, target, scope} ->
        if request.operation == {:known, operation} and request.subject == {:known, subject} and
             fact_matches?(id, request.account_state, state) and
             fact_matches?(id, request.target, target) and
             fact_matches?(id, request.scope, scope),
           do: {:allow, id}
    end)
  end

  defp fact_matches?(_id, :not_applicable, :not_applicable), do: true

  defp fact_matches?(_id, {:known, value}, expected) when not is_map(expected),
    do: value == expected

  defp fact_matches?(id, {:known, facts}, required)
       when id in [:loc_01, :loc_02] and is_map(facts) and is_map(required),
       do: facts == required

  defp fact_matches?(_id, {:known, facts}, required) when is_map(facts) and is_map(required),
    do: Map.take(facts, Map.keys(required)) == required

  defp fact_matches?(_id, _fact, _expected), do: false
end
