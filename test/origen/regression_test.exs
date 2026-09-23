defmodule Origen.RegressionTest do
  @moduledoc """
  Regression tests to ensure existing functionality still works after booking implementation.
  """

  use Origen.DataCase, async: false

  alias Origen.Repo
  alias Origen.Accounts
  alias Origen.Sessions
  alias Origen.ConsultationTypes.MockCatalog
  alias Origen.Audit.{Events, Writer}

  setup_all do
    :ok
  end

  describe "Internal account sessions (regression)" do
    test "can create and validate session for active account" do
      # Create professional account
      email = "regression_prof_#{:rand.uniform(1_000_000)}@test.com"
      {:ok, %{id: prof_id}} = Origen.TestSupport.BookingFactory.professional(email: email)
      
      # Authenticate
      {:ok, %{session: session}} = Accounts.authenticate_internal_account(email, "password123", "123456")
      
      assert session.account_id == prof_id
      assert session.role == :professional
      
      # Validate session
      {:ok, validated} = Sessions.fetch_session(session.token)
      assert validated.account_id == prof_id
    end

    test "session expires after idle timeout" do
      email = "regression_prof_#{:rand.uniform(1_000_000)}@test.com"
      {:ok, %{id: prof_id}} = Origen.TestSupport.BookingFactory.professional(email: email)
      
      {:ok, %{token: token}} = Accounts.authenticate_internal_account(email, "password123", "123456")
      
      # Should be valid initially
      assert Sessions.valid_session?(token)
      
      # Fast-forward past idle timeout (900 seconds default)
      future = DateTime.add(DateTime.utc_now(), 1000)
      refute Sessions.valid_session?(token, now: future)
    end

    test "session expires after max duration" do
      email = "regression_prof_#{:rand.uniform(1_000_000)}@test.com"
      {:ok, %{id: prof_id}} = Origen.TestSupport.BookingFactory.professional(email: email)
      
      {:ok, %{token: token}} = Accounts.authenticate_internal_account(email, "password123", "123456")
      
      # Fast-forward past max duration (43200 seconds default)
      future = DateTime.add(DateTime.utc_now(), 50_000)
      refute Sessions.valid_session?(token, now: future)
    end
  end

  describe "Consultation type catalog (regression)" do
    test "mock catalog returns expected types for PRO-DEMO-001" do
      Application.put_env(:origen, :consultation_catalog_demo_enabled, true)
      
      {:ok, result} = MockCatalog.execute({:list, %{professional_reference: "PRO-DEMO-001"}})
      
      assert result.source == :demo
      assert result.professional_reference == "PRO-DEMO-001"
      assert result.agenda_interval_minutes == 15
      assert length(result.consultation_types) == 6
      
      # Verify structure
      Enum.each(result.consultation_types, fn ct ->
        assert ct.id != nil
        assert ct.reference != nil
        assert ct.name != nil
        assert ct.interval_count >= 1
        assert ct.exact_price_ars != nil
        assert ct.color != nil
        assert ct.status in [:active, :inactive]
      end)
    end

    test "mock catalog returns error for unknown professional" do
      Application.put_env(:origen, :consultation_catalog_demo_enabled, true)
      
      assert {:error, :unavailable} = MockCatalog.execute({:list, %{professional_reference: "UNKNOWN"}})
    end
  end

  describe "Authorization bootstrap operations (regression)" do
    test "bootstrap rules still work" do
      # Test bootstrap local first administrator
      request = %Origen.Authorization.Request{
        operation: {:known, :bootstrap_local_first_administrator},
        subject: {:known, {:channel, :local_profile}},
        account_state: :not_applicable,
        target: {:known, %{administrator_exists: false}},
        scope: {:known, %{profile: :dev, readiness: :ready, destination: :example_test, database: :isolated, account: :none}}
      }
      
      assert Origen.Authorization.Rules.decide(request) == {:allow, :loc_01}
    end

    test "internal account activation still works" do
      request = %Origen.Authorization.Request{
        operation: {:known, :activate_internal_account},
        subject: {:known, {:role, :professional}},
        account_state: :pending_activation,
        target: {:known, %{role: :professional}},
        scope: {:known, %{account_matches: true, password_defined: true, token_valid: true, totp_enrolled: true}}
      }
      
      assert Origen.Authorization.Rules.decide(request) == {:allow, :inv_01}
    end

    test "administrator cannot create booking (default deny)" do
      request = %Origen.Authorization.Request{
        operation: {:known, :create_booking},
        subject: {:known, {:role, :administrator}},
        account_state: :active,
        target: {:known, %{professional_id: 1, patient_id: 1, consultation_type_id: "test", starts_at: DateTime.utc_now()}},
        scope: {:known, %{profile_complete: true, phone_verified: true, own_profile: true, consultation_type: :active_owned, availability: :valid, overlap: :none, d1_window: :valid}}
      }
      
      assert Origen.Authorization.Rules.decide(request) == {:deny, :no_matching_rule}
    end
  end

  describe "Audit append-only (regression)" do
    test "audit events can be appended" do
      actor = {:system, "test"}
      entity = {:account, "123"}
      
      {:ok, event} = Events.succeeded(actor, entity)
      {:ok, _} = Writer.append(event, {:allow, :sys_01})
      
      # Verify event was created
      assert event.actor_kind == "system"
      assert event.event == "operation_succeeded"
      assert event.result == "succeeded"
    end

    test "audit events are immutable (no update/delete)" do
      # This is enforced at DB level - we just verify the writer doesn't support update/delete
      assert not function_exported?(Writer, :update, 2)
      assert not function_exported?(Writer, :delete, 2)
    end
  end

  describe "Patient PAT-01 authentication (regression)" do
    test "patient schema supports auth_subject and provider" do
      {:ok, patient} = Origen.TestSupport.BookingFactory.patient(
        auth_subject: "google-oauth2|test123",
        auth_provider: :google
      )
      
      assert patient.auth_subject == "google-oauth2|test123"
      assert patient.auth_provider == :google
      assert patient.profile_complete == true
      assert patient.phone_verified == true
    end
  end
end