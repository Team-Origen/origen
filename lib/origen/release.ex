defmodule Origen.Release do
  @moduledoc "Packaged-release entry points for bounded operational commands."

  alias Origen.BootstrapAdmin.Gate

  @environment Mix.env()

  @spec bootstrap_admin([String.t()]) :: :ok | no_return()
  def bootstrap_admin(args \\ System.argv()) do
    enabled = Application.get_env(:origen, :bootstrap_admin_enabled)

    if Gate.allowed?(enabled, @environment) do
      {:ok, _applications} = Application.ensure_all_started(:mix)
      Mix.Tasks.Origen.BootstrapAdmin.run(args)
    else
      raise "Bootstrap admin is disabled"
    end
  end
end
