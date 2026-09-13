defmodule Origen.Release do
  @moduledoc "Packaged-release entry points for bounded operational commands."

  alias Origen.BootstrapAdmin.Gate

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
