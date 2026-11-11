defmodule Origen.Release do
  @moduledoc "Packaged-release entry points for bounded operational commands."

  alias Origen.BootstrapAdmin.Gate

  @app :origen

  @doc """
  Runs every pending migration for the configured repos.

  Used by the release start script before the server boots, so each deploy
  brings the schema up to date without needing Mix in the runtime image.
  """
  @spec migrate() :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

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
