defmodule Origen.BootstrapAdminSchemaTest do
  use ExUnit.Case, async: false

  @tables ~w(internal_accounts admin_bootstrap_controls internal_account_invitations)

  setup_all do
    Code.require_file(
      Path.expand(
        "../../priv/repo/migrations/20260906190000_create_first_admin_bootstrap.exs",
        __DIR__
      )
    )

    config = Application.get_env(:origen, Origen.Repo)

    {:ok, connection} =
      Postgrex.start_link(
        Keyword.take(config, [:hostname, :port, :username, :password, :database])
      )

    on_exit(fn -> GenServer.stop(connection) end)
    {:ok, connection: connection}
  end

  setup %{connection: connection} do
    Ecto.Adapters.SQL.Sandbox.mode(Origen.Repo, {:shared, self()})

    query!(connection, "DELETE FROM internal_account_invitations")
    query!(connection, "DELETE FROM internal_accounts")
    :ok
  end

  test "creates the durable first-admin tables with integrity constraints", %{
    connection: connection
  } do
    for table <- @tables do
      assert query!(connection, "SELECT to_regclass($1)::text", ["public.#{table}"]).rows == [
               [table]
             ]
    end

    columns =
      query!(
        connection,
        """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = ANY($1)
        ORDER BY table_name, ordinal_position
        """,
        [@tables]
      ).rows

    assert ["internal_account_invitations", "token"] not in columns
    assert ["internal_account_invitations", "token_digest"] not in columns
    assert ["internal_account_invitations", "verifier_digest"] in columns

    constraints =
      query!(connection, """
      SELECT conname
      FROM pg_constraint
      WHERE conrelid IN ('internal_accounts'::regclass,
                         'admin_bootstrap_controls'::regclass,
                         'internal_account_invitations'::regclass)
        AND contype IN ('f', 'c')
      """).rows

    assert length(constraints) >= 6
  end

  test "only one unconsumed and unrevoked invitation can exist per account", %{
    connection: connection
  } do
    account_id = insert_pending_account(connection)
    insert_invitation(connection, account_id, "first")

    assert_raise Postgrex.Error, fn -> insert_invitation(connection, account_id, "second") end
  end

  test "down refuses to remove populated bootstrap history", %{connection: connection} do
    account_id = insert_pending_account(connection)
    insert_invitation(connection, account_id, "rollback")

    assert_raise Postgrex.Error, fn ->
      query!(
        connection,
        apply(Origen.Repo.Migrations.CreateFirstAdminBootstrap, :rollback_guard_sql, [])
      )
    end

    assert query!(connection, "SELECT count(*) FROM internal_accounts").rows == [[1]]
    assert query!(connection, "SELECT count(*) FROM internal_account_invitations").rows == [[1]]
  end

  defp query!(connection, sql, params \\ []), do: Postgrex.query!(connection, sql, params)

  defp insert_pending_account(connection) do
    %{rows: [[id]]} =
      query!(connection, """
      INSERT INTO internal_accounts (role, state)
      VALUES ('administrator', 'pending_activation')
      RETURNING id
      """)

    id
  end

  defp insert_invitation(connection, account_id, suffix) do
    query!(
      connection,
      """
      INSERT INTO internal_account_invitations
        (account_id, verifier_version, verifier_digest, issued_by_ref)
      VALUES ($1, 'v1', decode($2, 'hex'), 'test-#{suffix}')
      """,
      [account_id, String.duplicate("a", 64)]
    )
  end
end
