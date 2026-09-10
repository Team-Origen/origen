defmodule Origen.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OrigenWeb.Telemetry,
      Origen.Repo,
      OrigenWeb.AdminActivationSessionStore,
      OrigenWeb.ProviderEventReplay,
      {DNSCluster, query: Application.get_env(:origen, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Origen.PubSub},
      # Start a worker by calling: Origen.Worker.start_link(arg)
      # {Origen.Worker, arg},
      # Start to serve requests, typically the last entry
      OrigenWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Origen.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OrigenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
