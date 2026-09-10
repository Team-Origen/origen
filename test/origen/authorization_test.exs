unless Process.whereis(ExUnit.Server), do: ExUnit.start()

defmodule Origen.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}

  describe "matrix-v0.4 grants" do
    test "allows only fact-complete exact rules" do
      cases = [
        {:bootstrap_first_administrator, {:channel, :deployment}, :not_applicable,
         %{administrator_exists: false},
         %{approved_command: true, assigned_operator: true, approval_authorized: true}, :dep_01},
        {:activate_internal_account, {:channel, :invitation}, {:known, :pending_activation},
         %{role: :professional},
         %{account_matches: true, password_defined: true, token_valid: true, totp_enrolled: true},
         :inv_01},
        {:reissue_internal_invitation, {:role, :administrator}, {:known, :active},
         %{role: :secretary, state: :pending_activation}, %{authenticated: true}, :rei_02},
        {:append_audit_event, {:channel, :system}, :not_applicable,
         %{event: :constructor_produced}, %{internal_path: true}, :sys_01},
        {:start_internal_session, {:role, :professional}, {:known, :active}, :not_applicable,
         %{credentials_valid: true, session_policy_satisfied: true}, :auth_01},
        {:create_professional_account, {:role, :administrator}, {:known, :active},
         %{role: :professional, state: :pending_activation}, :not_applicable, :s1_02},
        {:create_secretary_account, {:role, :administrator}, {:known, :active},
         %{role: :secretary, state: :pending_activation}, :not_applicable, :s1_03},
        {:register_patient, {:role, :secretary}, {:known, :active}, %{phone_verified: false},
         %{account_and_phone_match: true, rate_limit_satisfied: true}, :tel_01},
        {:verify_patient_phone, {:channel, :public_possession}, :not_applicable,
         %{phone_verified: false},
         %{account_and_phone_match: true, challenge_valid: true, rate_limit_satisfied: true},
         :tel_02}
      ]

      for {operation, subject, state, target, scope, rule_id} <- cases do
        request = request(operation, subject, state, fact(target), fact(scope))
        assert Authorization.decide(request) == {:allow, rule_id}
      end
    end

    test "does not treat role names as a hierarchy" do
      request =
        request(
          :register_patient,
          {:role, :administrator},
          {:known, :active},
          fact(%{phone_verified: false}),
          fact(%{account_and_phone_match: true, rate_limit_satisfied: true})
        )

      assert Authorization.decide(request) == {:deny, :no_matching_rule}
    end

    test "keeps every allowed non-role channel within its operation and declared scope" do
      cases = [
        {:bootstrap_first_administrator, {:channel, :deployment}, :not_applicable,
         %{administrator_exists: false},
         %{approved_command: true, assigned_operator: true, approval_authorized: true},
         :approved_command},
        {:activate_internal_account, {:channel, :invitation}, {:known, :pending_activation},
         %{role: :professional},
         %{account_matches: true, password_defined: true, token_valid: true, totp_enrolled: true},
         :token_valid},
        {:append_audit_event, {:channel, :system}, :not_applicable,
         %{event: :constructor_produced}, %{internal_path: true}, :internal_path},
        {:verify_patient_phone, {:channel, :public_possession}, :not_applicable,
         %{phone_verified: false},
         %{account_and_phone_match: true, challenge_valid: true, rate_limit_satisfied: true},
         :challenge_valid}
      ]

      for {operation, subject, state, target, scope, scoped_fact} <- cases do
        other_operation =
          request(:start_internal_session, subject, state, fact(target), fact(scope))

        exceeded_scope =
          request(
            operation,
            subject,
            state,
            fact(target),
            fact(Map.put(scope, scoped_fact, false))
          )

        assert Authorization.decide(other_operation) == {:deny, :no_matching_rule}
        assert Authorization.decide(exceeded_scope) == {:deny, :no_matching_rule}
      end
    end
  end

  describe "default denial" do
    test "denies each unknown dimension with a stable reason" do
      base =
        request(
          :create_professional_account,
          {:role, :administrator},
          {:known, :active},
          fact(%{role: :professional, state: :pending_activation}),
          :not_applicable
        )

      for dimension <- [:operation, :subject, :account_state, :target, :scope] do
        assert base |> Map.put(dimension, :unknown) |> Authorization.decide() ==
                 {:deny, {:unknown_dimension, dimension}}
      end
    end

    test "denies unknown operations and subjects" do
      assert request(:future_operation, {:role, :administrator}) |> Authorization.decide() ==
               {:deny, :unknown_operation}

      assert request(:create_professional_account, {:role, :future_role})
             |> Authorization.decide() ==
               {:deny, :unknown_subject}
    end

    test "denies missing or unmet target and scope facts" do
      missing =
        request(:register_patient, {:role, :secretary}, {:known, :active}, fact(%{}), fact(%{}))

      unmet =
        request(
          :register_patient,
          {:role, :secretary},
          {:known, :active},
          fact(%{phone_verified: true}),
          fact(%{account_and_phone_match: false, rate_limit_satisfied: true})
        )

      assert Authorization.decide(missing) == {:deny, :no_matching_rule}
      assert Authorization.decide(unmet) == {:deny, :no_matching_rule}
    end

    test "denies not-applicable unless an exact rule accepts it" do
      request =
        request(
          :register_patient,
          {:role, :secretary},
          {:known, :active},
          :not_applicable,
          :not_applicable
        )

      assert Authorization.decide(request) == {:deny, :no_matching_rule}
    end

    test "keeps sensitive reads and audit mutation denied" do
      for operation <- [:read_audit_log, :mutate_audit_event] do
        request =
          request(operation, {:role, :administrator}, {:known, :active}, fact(%{}), fact(%{}))

        assert Authorization.decide(request) == {:deny, :no_matching_rule}
      end
    end
  end

  defp request(
         operation,
         subject,
         state \\ {:known, :active},
         target \\ :not_applicable,
         scope \\ :not_applicable
       ) do
    Request.new(
      operation: Fact.known(operation),
      subject: Fact.known(subject),
      account_state: state,
      target: target,
      scope: scope
    )
  end

  defp fact(:not_applicable), do: :not_applicable
  defp fact(value), do: Fact.known(value)
end
