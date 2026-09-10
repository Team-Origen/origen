defmodule Origen.Audit.EventsTest do
  use Origen.DataCase, async: false

  alias Origen.Audit.{Events, Writer}

  @columns ~w(id actor_kind actor_ref event entity_kind entity_ref result recorded_at)

  test "the physical schema is minimized and server-timestamped" do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(Repo, """
      SELECT column_name, data_type, character_maximum_length, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'audit_events'
      ORDER BY ordinal_position
      """)

    assert Enum.map(rows, &hd/1) == @columns
    assert Enum.at(rows, 0) |> Enum.at(1) == "bigint"
    assert Enum.map(Enum.slice(rows, 1, 6), &Enum.at(&1, 2)) == [32, 128, 64, 32, 128, 32]
    assert List.last(rows) |> Enum.at(1) == "timestamp with time zone"
    assert List.last(rows) |> Enum.at(3) =~ "clock_timestamp()"
  end

  test "named constructors enforce allowlists and conditional references" do
    assert {:ok, _} = Events.allowed({:system, nil}, nil)
    assert {:ok, _} = Events.failed({:anonymous, nil}, {:account, "account-1"})
    assert {:error, :invalid_event} = Events.denied({:administrator, nil}, nil)
    assert {:error, :invalid_event} = Events.succeeded({:unknown, "actor-1"}, nil)
    assert {:error, :invalid_event} = Events.allowed({:system, nil}, {:account, " "})
    refute function_exported?(Events, :new, 1)
  end

  test "database checks reject malformed values and invalid combinations" do
    valid = ["system", nil, "operation_allowed", nil, nil, "allowed"]

    invalid_rows = [
      {List.replace_at(valid, 0, "Not_Snake"), :check_violation},
      {List.replace_at(valid, 2, String.duplicate("e", 65)), :string_data_right_truncation},
      {List.replace_at(valid, 5, "unknown"), :check_violation},
      {["administrator", nil, "operation_denied", nil, nil, "denied"], :check_violation},
      {["system", nil, "operation_failed", "account", nil, "failed"], :check_violation}
    ]

    for {values, code} <- invalid_rows do
      assert {:error, :rejected} =
               Repo.transaction(fn ->
                 assert {:error, %Postgrex.Error{postgres: %{code: ^code}}} = insert(values)
                 Repo.rollback(:rejected)
               end)
    end
  end

  test "all four outcomes use a server time and corrections preserve history" do
    baseline_count = audit_event_count()
    before_insert = database_time()

    events = [
      Events.allowed({:system, nil}, nil),
      Events.denied({:anonymous, nil}, nil),
      Events.succeeded({:administrator, "admin-1"}, {:account, "account-1"}),
      Events.failed({:administrator, "admin-1"}, {:account, "account-1"})
    ]

    rows =
      Enum.map(events, fn {:ok, event} ->
        assert {:ok, row} = Writer.append(event, {:allow, :sys_01})
        row
      end)

    after_insert = database_time()
    assert Enum.map(rows, & &1.result) == ~w(allowed denied succeeded failed)
    assert Enum.all?(rows, &(DateTime.compare(&1.recorded_at, before_insert) != :lt))
    assert Enum.all?(rows, &(DateTime.compare(&1.recorded_at, after_insert) != :gt))
    assert Enum.map(rows, & &1.id) |> Enum.uniq() |> length() == 4
    assert audit_event_count() == baseline_count + 4
  end

  test "row mutation and statement truncation triggers reject with 55000" do
    baseline_count = audit_event_count()
    {:ok, event} = Events.allowed({:system, nil}, nil)
    assert {:ok, original} = Writer.append(event, {:allow, :sys_01})

    for sql <- [
          "UPDATE audit_events SET result = 'failed' WHERE id = #{original.id}",
          "DELETE FROM audit_events WHERE id = #{original.id}",
          "TRUNCATE audit_events"
        ] do
      assert {:error, :immutable} =
               Repo.transaction(fn ->
                 assert {:error,
                         %Postgrex.Error{postgres: %{code: :object_not_in_prerequisite_state}}} =
                          Ecto.Adapters.SQL.query(Repo, sql)

                 Repo.rollback(:immutable)
               end)
    end

    assert audit_event_count() == baseline_count + 1
  end

  defp insert(values) do
    Ecto.Adapters.SQL.query(
      Repo,
      "INSERT INTO audit_events (actor_kind, actor_ref, event, entity_kind, entity_ref, result) VALUES ($1, $2, $3, $4, $5, $6)",
      values
    )
  end

  defp database_time,
    do: Ecto.Adapters.SQL.query!(Repo, "SELECT clock_timestamp()").rows |> hd() |> hd()

  defp audit_event_count, do: Repo.aggregate("audit_events", :count)
end
