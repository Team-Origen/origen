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

  # Minimal stand-ins for what Ecto.Migrator.with_repo/3 calls before running
  # migrations: repo config/0 and __adapter__/0, the adapter's
  # ensure_all_started/2, and repo start_link/1. start_link/1 fails as an
  # unreachable database would. If an Ecto upgrade changes with_repo/3, update
  # these stubs to match it.
  defmodule UnreachableAdapter do
    def ensure_all_started(_config, _mode), do: {:ok, []}
  end

  defmodule UnreachableRepo do
    def config, do: []
    def __adapter__, do: UnreachableAdapter
    def start_link(_opts), do: {:error, :database_unreachable}
  end

  test "migrate/1 raises an error naming the repo and the reason when a repo cannot start" do
    error =
      assert_raise RuntimeError, fn ->
        Release.migrate([UnreachableRepo])
      end

    assert error.message =~ inspect(UnreachableRepo)
    assert error.message =~ ":database_unreachable"
  end
end
