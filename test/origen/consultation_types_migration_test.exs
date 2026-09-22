defmodule Origen.ConsultationTypesMigrationTestRepo do
  use Ecto.Repo,
    otp_app: :origen,
    adapter: Ecto.Adapters.Postgres
end

defmodule Origen.ConsultationTypesMigrationTest do
  use ExUnit.Case, async: false

  alias Origen.ConsultationTypesMigrationTestRepo, as: MigrationRepo

  @foundational_version 20_260_919_235_000
  @grapheme_version 20_260_920_030_000

  setup_all do
    Enum.each(migrations(), fn {_version, module} ->
      unless Code.ensure_loaded?(module), do: Code.require_file(migration_file(module))
    end)

    :ok
  end

  setup do
    source_config = Origen.Repo.config()

    database =
      "origen_migration_test_#{System.unique_integer([:positive])}_#{System.system_time(:microsecond)}"

    create_database!(source_config, database)

    on_exit(fn -> drop_database!(source_config, database) end)

    {:ok, _repo_pid} = MigrationRepo.start_link(isolated_repo_config(source_config, database))
    migrate!(:up, all: true)

    :ok
  end

  test "foundational rollback refuses populated configuration and preserves its data" do
    migrate!(:down, step: 1)
    account_id = insert_professional!()

    query!(
      "INSERT INTO agenda_settings (owner_account_id, interval_minutes) VALUES ($1, 30)",
      [account_id]
    )

    error = assert_raise Postgrex.Error, fn -> migrate!(:down, step: 2) end
    assert error.postgres.code == :object_not_in_prerequisite_state

    assert query!("SELECT to_regclass('public.agenda_settings')::text").rows == [
             ["agenda_settings"]
           ]

    assert query!("SELECT interval_minutes FROM agenda_settings").rows == [[30]]
    assert @foundational_version in migrated_versions()
    refute @grapheme_version in migrated_versions()
  end

  test "empty configuration rolls back completely and remigrates" do
    migrate!(:down, step: 2)

    assert query!("SELECT to_regclass('public.consultation_types')::text").rows == [[nil]]
    assert query!("SELECT to_regclass('public.agenda_settings')::text").rows == [[nil]]

    assert query!("SELECT to_regprocedure('public.reject_account_owned_identity_change()')::text").rows ==
             [[nil]]

    refute @foundational_version in migrated_versions()
    refute @grapheme_version in migrated_versions()

    migrate!(:up, all: true)

    assert query!("SELECT to_regclass('public.consultation_types')::text").rows == [
             ["consultation_types"]
           ]

    assert query!("SELECT to_regclass('public.agenda_settings')::text").rows == [
             ["agenda_settings"]
           ]

    assert name_column_type() == ["text", nil]
    assert @foundational_version in migrated_versions()
    assert @grapheme_version in migrated_versions()
  end

  test "grapheme-name migration rolls back and reapplies compatible persisted names" do
    account_id = insert_professional!()
    name = String.duplicate("é", 32)
    consultation_type_id = insert_consultation_type!(account_id, name)

    migrate!(:down, step: 1)

    assert name_column_type() == ["character varying", 32]

    assert query!("SELECT name FROM consultation_types WHERE id = $1", [consultation_type_id]).rows ==
             [
               [name]
             ]

    refute @grapheme_version in migrated_versions()

    migrate!(:up, all: true)

    assert name_column_type() == ["text", nil]

    assert query!("SELECT name FROM consultation_types WHERE id = $1", [consultation_type_id]).rows ==
             [
               [name]
             ]

    assert @grapheme_version in migrated_versions()
  end

  test "grapheme-name rollback refuses narrowing names over 32 characters" do
    account_id = insert_professional!()
    name = String.duplicate("a", 33)
    consultation_type_id = insert_consultation_type!(account_id, name)

    error = assert_raise Postgrex.Error, fn -> migrate!(:down, step: 1) end
    assert error.postgres.code == :string_data_right_truncation

    assert name_column_type() == ["text", nil]

    assert query!("SELECT name FROM consultation_types WHERE id = $1", [consultation_type_id]).rows ==
             [
               [name]
             ]

    assert @grapheme_version in migrated_versions()
  end

  defp migrate!(direction, options) do
    Ecto.Migrator.run(MigrationRepo, migrations(), direction, [{:log, false} | options])
  end

  defp migrations do
    [
      {20_260_902_190_000, Origen.Repo.Migrations.CreateAuditEvents},
      {20_260_906_190_000, Origen.Repo.Migrations.CreateFirstAdminBootstrap},
      {20_260_918_120_000, Origen.Repo.Migrations.CreateInternalAccountSessions},
      {20_260_918_130_000, Origen.Repo.Migrations.AddEmailToInternalAccounts},
      {20_260_918_140_000, Origen.Repo.Migrations.ExpandInternalAccountsRoles},
      {@foundational_version, Origen.Repo.Migrations.CreateConsultationConfiguration},
      {@grapheme_version, Origen.Repo.Migrations.SupportConsultationTypeGraphemeNames}
    ]
  end

  defp migration_file(module) do
    filename =
      migrations()
      |> Enum.find_value(fn
        {version, ^module} ->
          "#{version}_#{module |> Module.split() |> List.last() |> Macro.underscore()}.exs"

        _migration ->
          nil
      end)

    Path.expand("../../priv/repo/migrations/#{filename}", __DIR__)
  end

  defp create_database!(source_config, database) do
    with_admin_connection!(source_config, fn connection ->
      Postgrex.query!(connection, ~s(CREATE DATABASE "#{database}"), [])
    end)
  end

  defp drop_database!(source_config, database) do
    with_admin_connection!(source_config, fn connection ->
      Postgrex.query!(connection, "DROP DATABASE IF EXISTS \"#{database}\" WITH (FORCE)", [])
    end)
  end

  defp with_admin_connection!(source_config, operation) do
    {:ok, connection} = Postgrex.start_link(admin_connection_config(source_config))

    try do
      operation.(connection)
    after
      GenServer.stop(connection)
    end
  end

  defp admin_connection_config(source_config) do
    source_config
    |> connection_config()
    |> Keyword.put(:database, "postgres")
  end

  defp isolated_repo_config(source_config, database) do
    source_config
    |> connection_config()
    |> Keyword.merge(
      database: database,
      pool: DBConnection.ConnectionPool,
      pool_size: 2,
      priv: "priv/repo"
    )
  end

  defp connection_config(config) do
    Keyword.take(config, [
      :hostname,
      :port,
      :username,
      :password,
      :socket,
      :socket_options,
      :ssl,
      :ssl_opts,
      :parameters,
      :timeout,
      :connect_timeout
    ])
  end

  defp insert_professional! do
    query!("""
    INSERT INTO internal_accounts
      (role, state, password_hash, totp_secret, activated_at)
    VALUES
      ('professional', 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
    RETURNING id
    """).rows
    |> hd()
    |> hd()
  end

  defp insert_consultation_type!(account_id, name) do
    consultation_type_id = Ecto.UUID.generate()

    query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count)
      VALUES
        ($1, $2, $3, 18000.50, '#0A7C86', 2)
      """,
      [Ecto.UUID.dump!(consultation_type_id), account_id, name]
    )

    Ecto.UUID.dump!(consultation_type_id)
  end

  defp name_column_type do
    query!("""
    SELECT data_type, character_maximum_length
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'consultation_types'
      AND column_name = 'name'
    """).rows
    |> List.first()
  end

  defp migrated_versions do
    query!("SELECT version FROM schema_migrations").rows
    |> List.flatten()
  end

  defp query!(sql, params \\ []) do
    Ecto.Adapters.SQL.query!(MigrationRepo, sql, params, log: false)
  end
end
