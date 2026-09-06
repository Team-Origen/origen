defmodule Origen.MigrationRepoTest do
  use ExUnit.Case, async: true

  @tag :postgres_security
  test "migration capability has a dedicated unsupervised repository" do
    assert Code.ensure_loaded?(Origen.MigrationRepo)
    refute Process.whereis(Origen.MigrationRepo)
  end
end

defmodule Origen.Audit.PostgresSecurityTest do
  use Origen.PostgresSecurityCase

  @moduletag :postgres_security

  setup_all context do
    roles = %{
      owner: System.get_env("ORIGEN_OWNER_ROLE", "origen_owner"),
      migrator: System.get_env("ORIGEN_MIGRATOR_ROLE", "origen_migrator"),
      runtime: System.get_env("ORIGEN_RUNTIME_ROLE", "origen_runtime"),
      verifier: System.get_env("ORIGEN_VERIFIER_ROLE", "origen_verifier")
    }

    {:ok, Map.put(context, :roles, roles)}
  end

  test "roles, ownership, membership, and grants are least privileged", context do
    %{runtime: runtime, migrator: migrator, verifier: verifier, roles: roles} = context

    assert scalar!(runtime, "SELECT current_user") == roles.runtime
    assert scalar!(migrator, "SELECT current_user") == roles.migrator
    assert scalar!(verifier, "SELECT current_user") == roles.verifier

    query!(migrator, ~s(SET ROLE "#{roles.owner}"))
    assert scalar!(migrator, "SELECT current_user") == roles.owner
    query!(migrator, "RESET ROLE")

    role_rows =
      query!(
        verifier,
        """
        SELECT rolname, rolcanlogin, rolinherit, rolcreaterole, rolcreatedb, rolsuper,
               rolreplication, rolbypassrls
        FROM pg_roles WHERE rolname = ANY($1) ORDER BY rolname
        """,
        [Map.values(roles)]
      ).rows

    assert length(role_rows) == 4

    assert Enum.find(role_rows, &(hd(&1) == roles.owner)) ==
             [roles.owner, false, true, false, false, false, false, false]

    for role <- [roles.migrator, roles.runtime, roles.verifier] do
      assert Enum.find(role_rows, &(hd(&1) == role)) ==
               [role, true, false, false, false, false, false, false]
    end

    assert query!(
             verifier,
             """
             SELECT member.rolname, parent.rolname, membership.inherit_option,
                    membership.set_option
             FROM pg_auth_members membership
             JOIN pg_roles member ON member.oid = membership.member
             JOIN pg_roles parent ON parent.oid = membership.roleid
             WHERE parent.rolname = $1
             """,
             [roles.owner]
           ).rows == [[roles.migrator, roles.owner, false, true]]

    assert scalar!(
             verifier,
             "SELECT tableowner FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_events'"
           ) == roles.owner

    assert scalar!(
             verifier,
             """
             SELECT owner.rolname FROM pg_proc procedure
             JOIN pg_roles owner ON owner.oid = procedure.proowner
             WHERE procedure.oid = 'public.reject_audit_event_mutation()'::regprocedure
             """
           ) == roles.owner

    assert scalar!(
             verifier,
             """
             SELECT owner.rolname FROM pg_class object
             JOIN pg_roles owner ON owner.oid = object.relowner
             WHERE object.oid = 'public.audit_events_id_seq'::regclass
             """
           ) == roles.owner

    for column <- ~w(actor_kind actor_ref event entity_kind entity_ref result) do
      assert scalar!(
               verifier,
               "SELECT has_column_privilege($1, 'audit_events', $2, 'INSERT')",
               [roles.runtime, column]
             )
    end

    for column <- ~w(id recorded_at) do
      refute scalar!(
               verifier,
               "SELECT has_column_privilege($1, 'audit_events', $2, 'INSERT')",
               [roles.runtime, column]
             )
    end

    for privilege <- ~w(SELECT UPDATE DELETE TRUNCATE) do
      refute scalar!(
               verifier,
               "SELECT has_table_privilege($1, 'audit_events', $2)",
               [roles.runtime, privilege]
             )
    end

    assert scalar!(
             verifier,
             "SELECT has_sequence_privilege($1, 'audit_events_id_seq', 'USAGE')",
             [
               roles.runtime
             ]
           )

    refute scalar!(
             verifier,
             "SELECT has_database_privilege('public', current_database(), 'CONNECT')"
           )

    refute scalar!(verifier, "SELECT has_schema_privilege('public', 'public', 'CREATE')")
  end

  test "runtime can append approved columns but cannot read, mutate, elevate, or perform DDL",
       context do
    %{runtime: runtime, verifier: verifier, roles: roles} = context

    before_rows = query!(verifier, "SELECT * FROM audit_events ORDER BY id").rows

    assert %{num_rows: 1} =
             query!(runtime, """
             INSERT INTO audit_events
               (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
             VALUES ('system', NULL, 'operation_allowed', NULL, NULL, 'allowed')
             """)

    after_insert = query!(verifier, "SELECT * FROM audit_events ORDER BY id").rows
    assert length(after_insert) == length(before_rows) + 1

    denied = [
      "SELECT * FROM audit_events",
      "UPDATE audit_events SET result = 'failed'",
      "DELETE FROM audit_events",
      "TRUNCATE audit_events",
      "ALTER TABLE audit_events ADD COLUMN forbidden text",
      "CREATE TABLE public.runtime_ddl_probe (id integer)",
      "CREATE ROLE runtime_role_probe",
      ~s(SET ROLE "#{roles.owner}")
    ]

    for sql <- denied do
      assert_sqlstate(runtime, sql, :insufficient_privilege)
    end

    assert_sqlstate(
      runtime,
      "INSERT INTO audit_events (actor_kind, event, result, recorded_at) VALUES ('system', 'operation_allowed', 'allowed', now())",
      :insufficient_privilege
    )

    assert query!(verifier, "SELECT * FROM audit_events ORDER BY id").rows == after_insert
  end

  test "runtime can use bootstrap data without ownership or destructive privileges", context do
    %{runtime: runtime, verifier: verifier, roles: roles} = context

    for table <- ~w(internal_accounts admin_bootstrap_controls internal_account_invitations) do
      assert scalar!(verifier, "SELECT has_table_privilege($1, $2, 'SELECT')", [
               roles.runtime,
               table
             ])

      refute scalar!(verifier, "SELECT has_table_privilege($1, $2, 'TRIGGER')", [
               roles.runtime,
               table
             ])

      refute scalar!(verifier, "SELECT has_table_privilege($1, $2, 'REFERENCES')", [
               roles.runtime,
               table
             ])

      assert_sqlstate(
        runtime,
        "ALTER TABLE #{table} ADD COLUMN forbidden text",
        :insufficient_privilege
      )
    end

    assert scalar!(
             verifier,
             "SELECT has_table_privilege($1, 'internal_account_invitations', 'INSERT')",
             [roles.runtime]
           )

    refute scalar!(
             verifier,
             "SELECT has_table_privilege($1, 'internal_account_invitations', 'TRUNCATE')",
             [roles.runtime]
           )

    refute scalar!(
             verifier,
             "SELECT has_table_privilege($1, 'internal_account_invitations', 'DELETE')",
             [roles.runtime]
           )
  end

  test "independent trigger defenses reject every historical mutation", context do
    %{runtime: runtime, verifier: verifier} = context

    query!(runtime, """
    INSERT INTO audit_events
      (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
    VALUES ('system', NULL, 'operation_allowed', NULL, NULL, 'allowed')
    """)

    before_rows = query!(verifier, "SELECT * FROM audit_events ORDER BY id").rows

    trigger_rows =
      query!(verifier, """
      SELECT tgname, tgtype
      FROM pg_trigger
      WHERE tgrelid = 'public.audit_events'::regclass AND NOT tgisinternal
      ORDER BY tgname
      """).rows

    assert trigger_rows == [
             ["audit_events_reject_row_mutation", 27],
             ["audit_events_reject_truncate", 34]
           ]

    for sql <- [
          "UPDATE audit_events SET result = 'failed'",
          "DELETE FROM audit_events",
          "TRUNCATE audit_events"
        ] do
      assert_sqlstate(verifier, sql, :object_not_in_prerequisite_state)
    end

    assert query!(verifier, "SELECT * FROM audit_events ORDER BY id").rows == before_rows
  end
end
