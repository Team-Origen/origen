defmodule Origen.ProtectedOperationTest do
  use Origen.DataCase, async: false

  alias Origen.Authorization.{Fact, Request}
  alias Origen.Audit.{Events, Writer}
  alias Origen.ProtectedOperation

  setup do
    Ecto.Adapters.SQL.query!(
      Repo,
      "CREATE TEMP TABLE protected_business_probe (value text) ON COMMIT DELETE ROWS"
    )

    :ok
  end

  test "a direct backend denial cannot produce a protected business effect" do
    baseline_count = audit_event_count()

    request =
      Request.new(
        operation: Fact.known(:create_secretary_account),
        subject: Fact.known({:role, :patient}),
        account_state: Fact.known(:active),
        target: Fact.known(%{role: :secretary, state: :pending_activation}),
        scope: :not_applicable
      )

    business_write = fn repo, _changes ->
      Ecto.Adapters.SQL.query!(repo, "INSERT INTO protected_business_probe VALUES ('created')")
      {:ok, event} = Events.succeeded({:system, nil}, {:account, "unauthorized"})
      {:ok, _audit_event} = Writer.append(event, {:allow, :sys_01})
      {:ok, :created}
    end

    assert {:error, :no_matching_rule} =
             ProtectedOperation.execute(
               request,
               {:anonymous, nil},
               {:account, "account-1"},
               business_write
             )

    assert scalar("SELECT count(*) FROM protected_business_probe") == 0
    assert [["denied"]] = audit_results_since(baseline_count)
  end

  test "a business rollback is followed by a fresh sanitized failure audit" do
    baseline_count = audit_event_count()

    business_write = fn repo, _changes ->
      Ecto.Adapters.SQL.query!(repo, "INSERT INTO protected_business_probe VALUES ('partial')")
      {:error, :business_failed}
    end

    assert {:error, :business_failed} =
             ProtectedOperation.execute(
               system_request(),
               {:system, nil},
               {:account, "account-2"},
               business_write
             )

    assert scalar("SELECT count(*) FROM protected_business_probe") == 0
    assert [["failed"]] = audit_results_since(baseline_count)
  end

  test "an allowed business effect and success audit commit atomically" do
    baseline_count = audit_event_count()

    business_write = fn repo, _changes ->
      Ecto.Adapters.SQL.query!(repo, "INSERT INTO protected_business_probe VALUES ('created')")
      {:ok, :created}
    end

    assert {:ok, :created} =
             ProtectedOperation.execute(
               system_request(),
               {:system, nil},
               {:account, "account-3"},
               business_write
             )

    assert scalar("SELECT count(*) FROM protected_business_probe") == 1
    assert [["succeeded"]] = audit_results_since(baseline_count)
  end

  test "an unavailable required success audit rolls back the business effect" do
    reject_audit_inserts()

    business_write = fn repo, _changes ->
      Ecto.Adapters.SQL.query!(repo, "INSERT INTO protected_business_probe VALUES ('partial')")
      {:ok, :created}
    end

    assert {:error, :audit_unavailable} =
             ProtectedOperation.execute(system_request(), {:system, nil}, nil, business_write)

    assert scalar("SELECT count(*) FROM protected_business_probe") == 0
  end

  test "an unavailable fresh failure audit is reported after business rollback" do
    reject_audit_inserts()

    business_write = fn repo, _changes ->
      Ecto.Adapters.SQL.query!(repo, "INSERT INTO protected_business_probe VALUES ('partial')")
      {:error, :business_failed}
    end

    assert {:error, :audit_unavailable} =
             ProtectedOperation.execute(system_request(), {:system, nil}, nil, business_write)

    assert scalar("SELECT count(*) FROM protected_business_probe") == 0
  end

  test "an unavailable authoritative denial audit prevents a successful response" do
    reject_audit_inserts()

    request =
      Request.new(
        operation: Fact.known(:create_secretary_account),
        subject: Fact.known({:role, :patient}),
        account_state: Fact.known(:active),
        target: Fact.known(%{role: :secretary, state: :pending_activation}),
        scope: :not_applicable
      )

    assert {:error, :audit_unavailable} =
             ProtectedOperation.execute(request, {:anonymous, nil}, nil, fn _, _ ->
               flunk("denied business operation must not execute")
             end)

    assert scalar("SELECT count(*) FROM protected_business_probe") == 0
  end

  defp scalar(statement), do: sql(statement) |> hd() |> hd()
  defp sql(statement), do: Ecto.Adapters.SQL.query!(Repo, statement).rows
  defp audit_event_count, do: Repo.aggregate("audit_events", :count)

  defp audit_results_since(baseline_count) do
    Ecto.Adapters.SQL.query!(
      Repo,
      "SELECT result FROM audit_events ORDER BY id OFFSET $1",
      [baseline_count]
    ).rows
  end

  defp system_request do
    Request.new(
      operation: Fact.known(:append_audit_event),
      subject: Fact.known({:channel, :system}),
      account_state: :not_applicable,
      target: Fact.known(%{event: :constructor_produced}),
      scope: Fact.known(%{internal_path: true})
    )
  end

  defp reject_audit_inserts do
    Ecto.Adapters.SQL.query!(Repo, """
    CREATE OR REPLACE FUNCTION pg_temp.reject_protected_audit_insert()
    RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'audit unavailable' USING ERRCODE = '55000'; END $$;
    """)

    Ecto.Adapters.SQL.query!(Repo, """
    CREATE TRIGGER reject_protected_audit_insert BEFORE INSERT ON audit_events
    FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_protected_audit_insert()
    """)
  end
end
