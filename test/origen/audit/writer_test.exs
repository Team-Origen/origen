defmodule Origen.Audit.WriterTest do
  use Origen.DataCase, async: false

  alias Origen.Audit.{Events, Writer}

  test "only constructor events with an audit allow decision append" do
    {:ok, event} = Events.denied({:anonymous, nil}, nil)

    assert {:error, :unauthorized} = Writer.append(event, {:deny, :no_matching_rule})
    assert Repo.aggregate("audit_events", :count) == 0
    assert {:ok, %{event: "operation_denied"}} = Writer.append(event, {:allow, :a_01})
    assert Repo.aggregate("audit_events", :count) == 1
  end

  test "no generic mutation or read boundary is exposed" do
    refute function_exported?(Writer, :all, 0)
    refute function_exported?(Writer, :get, 1)
    refute function_exported?(Writer, :update, 2)
    refute function_exported?(Writer, :delete, 1)
  end
end
