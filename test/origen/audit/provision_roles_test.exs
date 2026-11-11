defmodule Origen.Audit.ProvisionRolesTest do
  use ExUnit.Case, async: false

  @script "priv/repo/security/provision_roles.sql"

  setup do
    # This integration test must run inside an isolated pg_virtualenv -v 17 cluster.
    port = System.get_env("PGPORT", System.get_env("ORIGEN_TEST_DB_PORT", "5432"))
    host = System.get_env("PGHOST", "localhost")

    admin =
      System.get_env("PGUSER", System.get_env("ORIGEN_TEST_DB_USERNAME", System.get_env("USER")))

    admin_password =
      if System.get_env("PGUSER") do
        System.get_env("PGPASSWORD")
      else
        System.get_env("ORIGEN_TEST_DB_PASSWORD")
      end

    suffix = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    provisioner = "provisioner_#{suffix}"
    database = "provision_#{suffix}"
    password = Base.encode16(:crypto.strong_rand_bytes(24), case: :lower)

    {:ok, connection} =
      Postgrex.start_link(
        hostname: host,
        port: String.to_integer(port),
        username: admin,
        password: admin_password,
        database: "postgres"
      )

    Process.unlink(connection)

    roles = %{
      owner: "owner_#{suffix}",
      migrator: "migrator_#{suffix}",
      runtime: "runtime_#{suffix}",
      verifier: "verifier_#{suffix}"
    }

    elevated_role = "elevated_#{suffix}"

    on_exit(fn ->
      Postgrex.query!(connection, "DROP DATABASE #{database} WITH (FORCE)", [])

      for role <- [roles.migrator, roles.runtime, roles.verifier, roles.owner] do
        if Postgrex.query!(connection, "SELECT 1 FROM pg_roles WHERE rolname = $1", [role]).rows !=
             [] do
          Postgrex.query!(connection, "DROP ROLE #{role}", [])
        end
      end

      if Postgrex.query!(connection, "SELECT 1 FROM pg_roles WHERE rolname = $1", [elevated_role]).rows !=
           [] do
        Postgrex.query!(connection, "DROP ROLE #{elevated_role}", [])
      end

      Postgrex.query!(connection, "DROP ROLE #{provisioner}", [])
      GenServer.stop(connection)
    end)

    Postgrex.query!(
      connection,
      "CREATE ROLE #{provisioner} LOGIN CREATEROLE CREATEDB PASSWORD '#{password}'",
      []
    )

    Postgrex.query!(connection, "CREATE DATABASE #{database} OWNER #{provisioner}", [])

    env = [
      {"PGHOST", host},
      {"PGPORT", port},
      {"PGUSER", provisioner},
      {"PGPASSWORD", password},
      {"ORIGEN_OWNER_ROLE", roles.owner},
      {"ORIGEN_MIGRATOR_ROLE", roles.migrator},
      {"ORIGEN_RUNTIME_ROLE", roles.runtime},
      {"ORIGEN_VERIFIER_ROLE", roles.verifier},
      {"ORIGEN_MIGRATOR_PASSWORD", Base.encode16(:crypto.strong_rand_bytes(24))},
      {"ORIGEN_RUNTIME_PASSWORD", Base.encode16(:crypto.strong_rand_bytes(24))},
      {"ORIGEN_VERIFIER_PASSWORD", Base.encode16(:crypto.strong_rand_bytes(24))}
    ]

    {:ok,
     connection: connection,
     host: host,
     port: port,
     admin: admin,
     admin_password: admin_password,
     database: database,
     provisioner: provisioner,
     elevated_role: elevated_role,
     roles: roles,
     env: env}
  end

  test "a non-superuser database owner provisions roles and can reapply grants", context do
    %{
      connection: connection,
      host: host,
      port: port,
      admin: admin,
      admin_password: admin_password,
      database: database,
      provisioner: provisioner,
      roles: roles,
      env: env
    } = context

    for attempt <- 1..2 do
      status = run_script(database, env)

      assert status == 0,
             "provisioning attempt #{attempt} failed (output withheld to protect credentials)"
    end

    assert [[roles.owner]] ==
             Postgrex.query!(
               connection,
               "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = $1",
               [database]
             ).rows

    {:ok, database_connection} =
      Postgrex.start_link(
        hostname: host,
        port: String.to_integer(port),
        username: admin,
        password: admin_password,
        database: database
      )

    assert [[roles.owner]] ==
             Postgrex.query!(
               database_connection,
               "SELECT nspowner::regrole::text FROM pg_namespace WHERE nspname = 'public'",
               []
             ).rows

    GenServer.stop(database_connection)

    assert [[true, false, false]] ==
             Postgrex.query!(
               connection,
               "SELECT admin_option, inherit_option, set_option FROM pg_auth_members membership JOIN pg_roles parent ON parent.oid = membership.roleid JOIN pg_roles member ON member.oid = membership.member WHERE parent.rolname = $1 AND member.rolname = $2",
               [roles.owner, provisioner]
             ).rows

    assert [
             [false, false, false],
             [false, false, false],
             [false, false, false],
             [false, false, false]
           ] ==
             Postgrex.query!(
               connection,
               "SELECT rolsuper, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = ANY($1) ORDER BY rolname",
               [Map.values(roles)]
             ).rows

    for role <- [roles.runtime, roles.verifier] do
      assert [[false]] ==
               Postgrex.query!(connection, "SELECT pg_has_role($1, $2, 'SET')", [
                 role,
                 roles.owner
               ]).rows

      assert [[false]] ==
               Postgrex.query!(connection, "SELECT pg_has_role($1, $2, 'USAGE')", [
                 role,
                 roles.owner
               ]).rows
    end

    assert [[true]] ==
             Postgrex.query!(connection, "SELECT pg_has_role($1, $2, 'SET')", [
               roles.migrator,
               roles.owner
             ]).rows
  end

  test "unexpected runtime and verifier memberships stop provisioning before mutation", context do
    %{
      connection: connection,
      host: host,
      port: port,
      database: database,
      provisioner: provisioner,
      elevated_role: elevated_role,
      roles: roles,
      env: env
    } = context

    {:ok, provisioner_connection} =
      Postgrex.start_link(
        hostname: host,
        port: String.to_integer(port),
        username: provisioner,
        password: List.keyfind(env, "PGPASSWORD", 0) |> elem(1),
        database: database
      )

    for role <- [roles.runtime, roles.verifier] do
      Postgrex.query!(provisioner_connection, "CREATE ROLE #{role}", [])
    end

    GenServer.stop(provisioner_connection)

    Postgrex.query!(connection, "CREATE ROLE #{elevated_role} CREATEDB", [])

    for role <- [roles.runtime, roles.verifier] do
      Postgrex.query!(connection, "GRANT #{elevated_role} TO #{role} WITH SET TRUE", [])

      assert [[true]] ==
               Postgrex.query!(connection, "SELECT pg_has_role($1, $2, 'SET')", [
                 role,
                 elevated_role
               ]).rows
    end

    assert run_script(database, env) != 0

    assert [] ==
             Postgrex.query!(connection, "SELECT rolname FROM pg_roles WHERE rolname = ANY($1)", [
               [roles.owner, roles.migrator]
             ]).rows

    assert [[provisioner]] ==
             Postgrex.query!(
               connection,
               "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = $1",
               [database]
             ).rows

    for role <- [roles.runtime, roles.verifier] do
      assert [[true]] ==
               Postgrex.query!(connection, "SELECT pg_has_role($1, $2, 'SET')", [
                 role,
                 elevated_role
               ]).rows
    end
  end

  test "an existing elevated runtime role blocks provisioning before any changes", context do
    %{
      connection: connection,
      database: database,
      roles: roles,
      provisioner: provisioner,
      env: env
    } = context

    Postgrex.query!(connection, "CREATE ROLE #{roles.runtime} BYPASSRLS", [])

    Postgrex.query!(
      connection,
      "GRANT #{roles.runtime} TO #{provisioner} WITH ADMIN TRUE, INHERIT FALSE, SET FALSE",
      []
    )

    assert run_script(database, env) != 0

    assert [[true]] ==
             Postgrex.query!(connection, "SELECT rolbypassrls FROM pg_roles WHERE rolname = $1", [
               roles.runtime
             ]).rows

    assert [] ==
             Postgrex.query!(connection, "SELECT rolname FROM pg_roles WHERE rolname = ANY($1)", [
               [roles.owner, roles.migrator, roles.verifier]
             ]).rows

    assert [[provisioner]] ==
             Postgrex.query!(
               connection,
               "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = $1",
               [database]
             ).rows
  end

  test "a late privilege error rolls back role, owner, and membership changes", context do
    %{
      connection: connection,
      host: host,
      port: port,
      admin: admin,
      admin_password: admin_password,
      database: database,
      provisioner: provisioner,
      roles: roles,
      env: env
    } = context

    {:ok, db_connection} =
      Postgrex.start_link(
        hostname: host,
        port: String.to_integer(port),
        username: admin,
        password: admin_password,
        database: database
      )

    # The superuser-owned table cannot be regranted by the newly created owner.
    Postgrex.query!(db_connection, "CREATE TABLE public.audit_events (id integer)", [])
    GenServer.stop(db_connection)

    assert run_script(database, env) != 0

    assert [[provisioner]] ==
             Postgrex.query!(
               connection,
               "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = $1",
               [database]
             ).rows

    assert [] ==
             Postgrex.query!(connection, "SELECT rolname FROM pg_roles WHERE rolname = ANY($1)", [
               Map.values(roles)
             ]).rows

    assert [] ==
             Postgrex.query!(
               connection,
               "SELECT 1 FROM pg_auth_members WHERE member = (SELECT oid FROM pg_roles WHERE rolname = $1) AND roleid IN (SELECT oid FROM pg_roles WHERE rolname = ANY($2))",
               [provisioner, Map.values(roles)]
             ).rows

    {:ok, db_connection} =
      Postgrex.start_link(
        hostname: host,
        port: String.to_integer(port),
        username: admin,
        password: admin_password,
        database: database
      )

    assert [["pg_database_owner"]] ==
             Postgrex.query!(
               db_connection,
               "SELECT nspowner::regrole::text FROM pg_namespace WHERE nspname = 'public'",
               []
             ).rows

    assert [[true, true]] ==
             Postgrex.query!(
               db_connection,
               "SELECT has_database_privilege('public', current_database(), 'CONNECT'), has_schema_privilege('public', 'public', 'USAGE')",
               []
             ).rows

    GenServer.stop(db_connection)
  end

  defp run_script(database, env) do
    {_private_output, status} =
      System.cmd("psql", ["-X", "-v", "ON_ERROR_STOP=1", "-d", database, "-f", @script],
        env: env,
        stderr_to_stdout: true
      )

    status
  end
end
