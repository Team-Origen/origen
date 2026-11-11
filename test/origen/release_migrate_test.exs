defmodule Origen.ReleaseMigrateTest do
  use Origen.DataCase, async: false

  alias Origen.Release

  test "migrate/0 runs every configured repo and leaves no migration pending" do
    assert :ok = Release.migrate()

    for repo <- Application.fetch_env!(:origen, :ecto_repos) do
      pending =
        repo
        |> Ecto.Migrator.migrations()
        |> Enum.filter(fn {status, _version, _name} -> status == :down end)

      assert pending == []
    end
  end

  test "migrate/0 is idempotent when the schema is already current" do
    assert :ok = Release.migrate()
    assert :ok = Release.migrate()
  end
end
