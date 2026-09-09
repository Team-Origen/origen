defmodule Mix.Tasks.Origen.BootstrapAdmin do
  @moduledoc """
  Creates the first pending administrator and delivers its invitation.

  The task is intentionally narrow: the shared bootstrap gate is checked before
  options, configuration, or repository state are read.
  """

  use Mix.Task

  alias Origen.BootstrapAdmin.Command
  alias Origen.BootstrapAdmin.Gate

  @shortdoc "Deliver the first administrator invitation"

  @impl Mix.Task
  def run(args) do
    case Gate.check() do
      :ok -> execute(args)
      {:error, :bootstrap_disabled} -> Mix.raise("Bootstrap admin is disabled")
    end
  end

  @doc false
  def execute(args) do
    case Command.run(args, command_options()) do
      {:ok, references} ->
        Mix.shell().info(
          "Bootstrap admin invitation delivered; account reference: #{references.account_id}; " <>
            "invitation reference: #{references.invitation_id}; " <>
            "provider reference: #{references.correlation_ref}"
        )

      {:error, :invalid_arguments} ->
        Mix.raise("Bootstrap admin received invalid command-line arguments")

      {:error, :delivery_failed, references} ->
        Mix.raise(
          "Bootstrap admin delivery failed; account reference: #{references.account_id}; " <>
            "invitation reference: #{references.invitation_id}; " <>
            "obtain fresh approval and issue a fresh invitation"
        )

      {:error, _safe_reason} ->
        Mix.raise("Bootstrap admin request was rejected")

      {:error, _safe_reason, _references} ->
        Mix.raise("Bootstrap admin request failed closed")
    end
  end

  if Mix.env() == :test do
    defp command_options,
      do: Application.get_env(:origen, :bootstrap_admin_command_options, [])
  else
    defp command_options, do: []
  end
end
