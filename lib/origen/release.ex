defmodule Origen.Release do
  @moduledoc "Packaged-release entry points for bounded operational commands."

  alias Origen.BootstrapAdmin.Gate

  @app :origen

  @doc """
  Runs every pending migration for the given repos (the configured
  `:ecto_repos` by default).

  It is invoked by `bin/migrate`, which Render runs as the preDeployCommand,
  separately from `bin/server`. Starting the server never migrates: a failed
  migration must stop the deploy before the new version goes live.

  Raises with the repo and the reason when a repo cannot start, so the
  pre-deploy log says what failed and the command exits non-zero.
  """
  @spec migrate([module()] | nil) :: :ok
  def migrate(repos \\ nil) do
    load_app()

    for repo <- repos || configured_repos() do
      case Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true)) do
        {:ok, _migrated, _apps} ->
          :ok

        {:error, reason} ->
          raise "Could not run migrations for #{inspect(repo)}: #{inspect(reason)}"
      end
    end

    :ok
  end

  defp configured_repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end

  @spec bootstrap_admin([String.t()]) :: :ok | no_return()
  def bootstrap_admin(args \\ System.argv()) do
    case Gate.check() do
      :ok ->
        {:ok, _applications} = Application.ensure_all_started(:mix)
        Mix.Tasks.Origen.BootstrapAdmin.execute(args, :packaged_release, [])

      {:error, :bootstrap_disabled} ->
        raise "Bootstrap admin is disabled"
    end
  end
end
