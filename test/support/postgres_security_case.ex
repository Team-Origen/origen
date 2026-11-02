defmodule Origen.PostgresSecurityCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Origen.PostgresSecurityCase
    end
  end

  setup_all do
    runtime = connect!("ORIGEN_DATABASE_URL")
    migrator = connect!("ORIGEN_MIGRATION_DATABASE_URL")
    verifier = connect!("ORIGEN_SECURITY_DATABASE_URL")

    on_exit(fn ->
      if Process.alive?(runtime), do: GenServer.stop(runtime)
      if Process.alive?(migrator), do: GenServer.stop(migrator)
      if Process.alive?(verifier), do: GenServer.stop(verifier)
    end)

    {:ok, runtime: runtime, migrator: migrator, verifier: verifier}
  end

  def query!(connection, sql, params \\ []) do
    Postgrex.query!(connection, sql, params)
  end

  def scalar!(connection, sql, params \\ []) do
    query!(connection, sql, params).rows |> hd() |> hd()
  end

  def assert_sqlstate(connection, sql, expected) do
    assert {:error, %Postgrex.Error{postgres: %{code: ^expected}}} =
             Postgrex.query(connection, sql, [])
  end

  defp connect!(variable) do
    url =
      System.get_env(variable) ||
        raise """
        #{variable} is required for PostgreSQL security tests. Local setup uses
        ORIGEN_TEST_DB_USERNAME and ORIGEN_TEST_DB_PASSWORD for provisioning,
        ORIGEN_MIGRATION_DATABASE_URL for migrations, and ORIGEN_SECURITY_DATABASE_URL
        for verification. Credential values are never logged.
        """

    uri = URI.parse(url)
    [username, password] = uri.userinfo |> to_string() |> String.split(":", parts: 2)

    options = [
      hostname: uri.host,
      port: uri.port || 5432,
      username: URI.decode(username),
      password: URI.decode(password),
      database: uri.path |> String.trim_leading("/") |> URI.decode()
    ]

    {:ok, connection} = Postgrex.start_link(options)
    connection
  end
end
