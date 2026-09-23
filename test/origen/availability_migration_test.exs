defmodule Origen.AvailabilityMigrationTestRepo do
  use Ecto.Repo, otp_app: :origen, adapter: Ecto.Adapters.Postgres
end

defmodule Origen.AvailabilityMigrationTest do
  use ExUnit.Case, async: false

  alias Origen.AvailabilityMigrationTestRepo, as: MigrationRepo

  @version 20_260_925_100_000
  @default_week %{
    "monday" => [%{"start" => "08:00", "end" => "12:00"}, %{"start" => "14:00", "end" => "18:00"}],
    "tuesday" => [
      %{"start" => "08:00", "end" => "12:00"},
      %{"start" => "14:00", "end" => "18:00"}
    ],
    "wednesday" => [
      %{"start" => "08:00", "end" => "12:00"},
      %{"start" => "14:00", "end" => "18:00"}
    ],
    "thursday" => [
      %{"start" => "08:00", "end" => "12:00"},
      %{"start" => "14:00", "end" => "18:00"}
    ],
    "friday" => [%{"start" => "08:00", "end" => "12:00"}, %{"start" => "14:00", "end" => "18:00"}],
    "saturday" => [],
    "sunday" => []
  }

  setup_all do
    Enum.each(migrations(), fn {_version, module} ->
      unless Code.ensure_loaded?(module), do: Code.require_file(migration_file(module))
    end)

    :ok
  end

  setup do
    config = Origen.Repo.config()
    database = "origen_availability_#{System.unique_integer([:positive])}"

    with_admin!(config, fn connection ->
      Postgrex.query!(connection, ~s(CREATE DATABASE "#{database}"), [])
    end)

    on_exit(fn ->
      with_admin!(config, fn connection ->
        Postgrex.query!(connection, "DROP DATABASE IF EXISTS \"#{database}\" WITH (FORCE)", [])
      end)
    end)

    {:ok, _pid} = MigrationRepo.start_link(isolated_config(config, database))
    migrate!(:up, to: 20_260_920_030_000)
    :ok
  end

  test "backfills existing settings and applies canonical defaults to new settings" do
    existing = insert_professional!()
    newcomer = insert_professional!()
    query!("INSERT INTO agenda_settings (owner_account_id) VALUES ($1)", [existing])

    migrate!(:up, to: @version)
    query!("INSERT INTO agenda_settings (owner_account_id) VALUES ($1)", [newcomer])

    assert configuration(existing) == [@default_week, 30, 30]
    assert configuration(newcomer) == [@default_week, 30, 30]
  end

  test "accepts an empty week and enforces scalar constraints" do
    owner = insert_professional!()
    migrate!(:up, to: @version)
    query!("INSERT INTO agenda_settings (owner_account_id) VALUES ($1)", [owner])
    empty_week = Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []})

    assert query!(
             """
             UPDATE agenda_settings
             SET weekly_availability = $2, booking_horizon_days = 7, minimum_lead_minutes = 0
             WHERE owner_account_id = $1
             RETURNING weekly_availability, booking_horizon_days, minimum_lead_minutes
             """,
             [owner, empty_week]
           ).rows == [[empty_week, 7, 0]]

    for {column, value} <- [
          {"booking_horizon_days", 6},
          {"booking_horizon_days", 91},
          {"minimum_lead_minutes", -5},
          {"minimum_lead_minutes", 31},
          {"minimum_lead_minutes", 1445}
        ] do
      error =
        assert_raise Postgrex.Error, fn ->
          query!("UPDATE agenda_settings SET #{column} = $2 WHERE owner_account_id = $1", [
            owner,
            value
          ])
        end

      assert error.postgres.code == :check_violation
    end
  end

  test "rollback refuses non-default data and removes default-only columns" do
    owner = insert_professional!()
    migrate!(:up, to: @version)

    query!(
      "INSERT INTO agenda_settings (owner_account_id, booking_horizon_days) VALUES ($1, 60)",
      [owner]
    )

    error = assert_raise Postgrex.Error, fn -> migrate!(:down, step: 1) end
    assert error.postgres.code == :object_not_in_prerequisite_state
    assert configuration(owner) == [@default_week, 60, 30]

    query!("UPDATE agenda_settings SET booking_horizon_days = 30 WHERE owner_account_id = $1", [
      owner
    ])

    migrate!(:down, step: 1)
    assert availability_columns() == []
  end

  defp configuration(owner) do
    query!(
      """
      SELECT weekly_availability, booking_horizon_days, minimum_lead_minutes
      FROM agenda_settings WHERE owner_account_id = $1
      """,
      [owner]
    ).rows
    |> List.first()
  end

  defp availability_columns do
    query!("""
    SELECT column_name FROM information_schema.columns
    WHERE table_name = 'agenda_settings'
      AND column_name IN ('weekly_availability', 'booking_horizon_days', 'minimum_lead_minutes')
    """).rows
  end

  defp migrate!(direction, options),
    do: Ecto.Migrator.run(MigrationRepo, migrations(), direction, [{:log, false} | options])

  defp migrations do
    [
      {20_260_902_190_000, Origen.Repo.Migrations.CreateAuditEvents},
      {20_260_906_190_000, Origen.Repo.Migrations.CreateFirstAdminBootstrap},
      {20_260_918_120_000, Origen.Repo.Migrations.CreateInternalAccountSessions},
      {20_260_918_130_000, Origen.Repo.Migrations.AddEmailToInternalAccounts},
      {20_260_918_140_000, Origen.Repo.Migrations.ExpandInternalAccountsRoles},
      {20_260_919_235_000, Origen.Repo.Migrations.CreateConsultationConfiguration},
      {20_260_920_030_000, Origen.Repo.Migrations.SupportConsultationTypeGraphemeNames},
      {@version, Origen.Repo.Migrations.AddAvailabilityConfiguration}
    ]
  end

  defp migration_file(module) do
    {version, _module} =
      Enum.find(migrations(), fn {_version, candidate} -> candidate == module end)

    name = module |> Module.split() |> List.last() |> Macro.underscore()
    Path.expand("../../priv/repo/migrations/#{version}_#{name}.exs", __DIR__)
  end

  defp insert_professional! do
    query!("""
    INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
    VALUES ('professional', 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
    """).rows
    |> hd()
    |> hd()
  end

  defp with_admin!(config, operation) do
    {:ok, connection} =
      Postgrex.start_link(config |> connection_config() |> Keyword.put(:database, "postgres"))

    try do
      operation.(connection)
    after
      GenServer.stop(connection)
    end
  end

  defp isolated_config(config, database) do
    config
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

  defp query!(sql, params \\ []),
    do: Ecto.Adapters.SQL.query!(MigrationRepo, sql, params, log: false)
end
