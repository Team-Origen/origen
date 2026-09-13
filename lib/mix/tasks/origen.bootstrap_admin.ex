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
      :ok -> execute(args, :source_checkout)
      {:error, :bootstrap_disabled} -> Mix.raise("Bootstrap admin is disabled")
    end
  end

  @doc false
  def execute(args, channel \\ :source_checkout, options \\ command_options()) do
    command_runner = Keyword.get(options, :command_runner, &Command.run/3)

    case command_runner.(args, channel, options) do
      {:ok, references} ->
        print_references(references)
        maybe_wait_for_local_activation(channel, options)

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

  defp print_references(references) do
    Mix.shell().info(
      "Bootstrap admin invitation delivered; account reference: #{references.account_id}; " <>
        "invitation reference: #{references.invitation_id}; " <>
        "provider reference: #{references.correlation_ref}"
    )
  end

  defp maybe_wait_for_local_activation(:source_checkout, options) do
    if Application.get_env(:origen, :bootstrap_admin_profile) == :local do
      endpoint = Keyword.get(options, :local_endpoint, Origen.BootstrapAdmin.Local.Endpoint)
      config = Application.get_env(:origen, :bootstrap_admin_local, %{})
      endpoint_options = Keyword.get(options, :local_endpoint_options, [])

      try do
        case endpoint.start_session(config, endpoint_options) do
          :ok -> endpoint.await()
          {:error, _safe_reason} -> Mix.raise("Bootstrap admin local endpoint was rejected")
        end
      after
        endpoint.cleanup()
      end
    end
  end

  defp maybe_wait_for_local_activation(_channel, _options), do: :ok

  if Mix.env() == :test do
    defp command_options,
      do: Application.get_env(:origen, :bootstrap_admin_command_options, [])
  else
    defp command_options, do: []
  end
end
