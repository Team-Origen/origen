defmodule Origen.Release do
  @moduledoc "Packaged-release entry points for bounded operational commands."

  alias Origen.BootstrapAdmin.{Gate, OperatorInvitation}

  @app :origen

  @doc """
  Runs every pending migration for the configured `:ecto_repos`.

  Invoked by `rel/overlays/bin/migrate`, which `rel/overlays/bin/server` runs
  before starting the web server. A failed migration makes the script exit
  before the server starts, so the new version never goes live.
  """
  @spec migrate() :: :ok
  def migrate do
    load_app()
    migrate(configured_repos())
  end

  @doc """
  Runs every pending migration for the given repos.

  Raises with the repo and the reason when a repo cannot start, so the deploy
  log says what failed and the release command exits non-zero.
  """
  @spec migrate([module()]) :: :ok
  def migrate(repos) when is_list(repos) do
    load_app()

    for repo <- repos do
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

  @doc """
  Creates the first pending Administrator and prints its activation link.

  Invoked by `rel/overlays/bin/issue_admin_invitation`. Refuses unless
  `ORIGEN_OPERATOR_INVITATION_ENABLED=true`; see
  `Origen.BootstrapAdmin.OperatorInvitation` and `docs/deployment/RENDER.md`.
  Errors raise with a safe reason only, never the token or the key.
  """
  @spec issue_admin_invitation([String.t()]) :: :ok | no_return()
  def issue_admin_invitation(args) when is_list(args) do
    load_app()
    # `bin/origen eval '...' -- args` keeps the separator in System.argv().
    args = with ["--" | rest] <- args, do: rest

    case Ecto.Migrator.with_repo(Origen.Repo, fn _repo -> OperatorInvitation.run(args) end) do
      {:ok, {:ok, result}, _apps} ->
        IO.puts("""
        Pending Administrator created.
        Login identifier (account id): #{result.account_id}
        Expires at: #{DateTime.to_iso8601(result.expires_at)}
        Activation link (single use, give it only to the account holder):
        #{result.link}
        """)

        :ok

      {:ok, {:error, reason}, _apps} ->
        raise "Admin invitation refused: #{reason}"

      {:error, reason} ->
        raise "Admin invitation refused: database unavailable (#{inspect(reason)})"
    end
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
