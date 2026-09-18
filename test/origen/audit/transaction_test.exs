defmodule Origen.Audit.TransactionTest do
  use Origen.DataCase, async: false

  alias Ecto.Multi
  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.Audit.{Events, Writer}

  setup do
    Ecto.Adapters.SQL.query!(
      Repo,
      "CREATE TEMP TABLE audit_business_probe (value text) ON COMMIT DELETE ROWS"
    )

    :ok
  end

  test "an allowed business write and required audit append commit atomically" do
    baseline_count = audit_event_count()
    {:ok, event} = Events.succeeded({:system, nil}, {:account, "account-1"})

    multi =
      Multi.new()
      |> Multi.run(:business, fn repo, _ ->
        {:ok,
         Ecto.Adapters.SQL.query!(repo, "INSERT INTO audit_business_probe VALUES ('created')")}
      end)
      |> Writer.append_to_multi(event, {:allow, :sys_01})

    assert {:ok, %{audit_event: %{result: "succeeded"}}} = Repo.transaction(multi)
    assert scalar("SELECT count(*) FROM audit_business_probe") == 1
    assert audit_event_count() == baseline_count + 1
  end

  test "an unavailable required audit rolls back the business write" do
    reject_audit_inserts()
    {:ok, event} = Events.succeeded({:system, nil}, {:account, "account-1"})

    multi =
      Multi.new()
      |> Multi.run(:business, fn repo, _ ->
        {:ok,
         Ecto.Adapters.SQL.query!(repo, "INSERT INTO audit_business_probe VALUES ('created')")}
      end)
      |> Writer.append_to_multi(event, {:allow, :sys_01})

    assert {:error, :audit_event, :audit_unavailable, _} = Repo.transaction(multi)
    assert scalar("SELECT count(*) FROM audit_business_probe") == 0
  end

  test "business failure rolls back before a sanitized failure append" do
    {:ok, event} = Events.failed({:system, nil}, {:account, "account-1"})

    multi =
      Multi.new()
      |> Multi.run(:business, fn repo, _ ->
        Ecto.Adapters.SQL.query!(repo, "INSERT INTO audit_business_probe VALUES ('partial')")
        {:error, :business_failed}
      end)

    assert {:error, :business, :business_failed, _} = Repo.transaction(multi)
    assert scalar("SELECT count(*) FROM audit_business_probe") == 0
    assert {:ok, %{result: "failed"}} = Writer.append(event, {:allow, :sys_01})
  end

  test "policy denial causes no business effect and appends separately" do
    {:ok, event} = Events.denied({:anonymous, nil}, nil)

    decision =
      Authorization.decide(
        Request.new(
          operation: Fact.known(:create_secretary_account),
          subject: Fact.known({:role, :patient}),
          account_state: Fact.known(:active),
          target: :not_applicable,
          scope: :not_applicable
        )
      )

    assert {:deny, :no_matching_rule} = decision
    assert scalar("SELECT count(*) FROM audit_business_probe") == 0
    assert {:ok, %{result: "denied"}} = Writer.append(event, {:allow, :sys_01})
  end

  test "a required fresh audit failure returns audit_unavailable" do
    reject_audit_inserts()
    {:ok, event} = Events.failed({:system, nil}, nil)

    assert {:error, :observed} =
             Repo.transaction(fn ->
               assert {:error, :audit_unavailable} = Writer.append(event, {:allow, :sys_01})
               Repo.rollback(:observed)
             end)
  end

  defp scalar(sql), do: Ecto.Adapters.SQL.query!(Repo, sql).rows |> hd() |> hd()

  defp audit_event_count, do: Repo.aggregate("audit_events", :count)

  defp reject_audit_inserts do
    Ecto.Adapters.SQL.query!(Repo, """
    CREATE OR REPLACE FUNCTION pg_temp.reject_audit_insert() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'audit unavailable' USING ERRCODE = '55000'; END $$;
    """)

    Ecto.Adapters.SQL.query!(Repo, """
    CREATE TRIGGER reject_audit_insert BEFORE INSERT ON audit_events
    FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_audit_insert()
    """)
  end
end
