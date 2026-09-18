defmodule Mix.Tasks.Origen.BootstrapAdmin do
  @moduledoc """
  Creates the first pending administrator and delivers its invitation.

  The task is intentionally narrow: the shared bootstrap gate is checked before
  options, configuration, or repository state are read.
  """

  use Mix.Task

  @requirements ["app.config"]

  alias Origen.BootstrapAdmin.Command
  alias Origen.BootstrapAdmin.Gate
  alias Origen.BootstrapAdmin.Local.{Eligibility, Readiness}

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
    if local_source_checkout?(channel) do
      execute_local(args, channel, options)
    else
      execute_command(args, channel, options)
    end
  end

  defp execute_local(args, channel, options) do
    config = Application.get_env(:origen, :bootstrap_admin_local, %{})

    with :ok <- apply(Eligibility, :check, [channel]),
         {:ok, _parsed} <- Command.parse_local_args(args),
         {:ok, ready} <- Readiness.inspect(config) do
      start_local_session(args, channel, ready, options)
    else
      {:error, :invalid_arguments} ->
        Mix.raise("Bootstrap admin received invalid command-line arguments")

      {:error, _safe_reason} ->
        Mix.raise("Bootstrap admin request was rejected")
    end
  end

  defp start_local_session(args, channel, ready, options) do
    endpoint = Keyword.get(options, :local_endpoint, Origen.BootstrapAdmin.Local.Endpoint)
    endpoint_options = Keyword.get(options, :local_endpoint_options, [])

    case Application.ensure_all_started(:origen) do
      {:ok, _applications} -> :ok
      {:error, _reason} -> Mix.raise("Bootstrap admin request was rejected")
    end

    outcome =
      try do
        result =
          case endpoint.start_session(ready, endpoint_options) do
            :ok ->
              local_options =
                options
                |> Keyword.put(:ready, ready)
                |> Keyword.put_new(:command_runner, &execute_ready_local_command/3)

              execute_command(args, channel, local_options)
              endpoint.await()

            {:error, _safe_reason} ->
              Mix.raise("Bootstrap admin local endpoint was rejected")
          end

        {:ok, result}
      catch
        kind, reason -> {:error, kind, reason, __STACKTRACE__}
      end

    case outcome do
      {:ok, result} ->
        endpoint.cleanup()
        result

      {:error, kind, reason, stacktrace} ->
        safe_cleanup(endpoint)
        :erlang.raise(kind, reason, stacktrace)
    end
  end

  defp safe_cleanup(endpoint) do
    endpoint.cleanup()
  catch
    :exit, _reason -> :ok
  end

  defp execute_ready_local_command(args, channel, options) do
    with :ok <- apply(Eligibility, :check, [channel]),
         {:ok, parsed} <- Command.parse_local_args(args) do
      Origen.BootstrapAdmin.Local.Command.run(parsed, options)
    end
  end

  defp execute_command(args, channel, options) do
    command_runner = Keyword.get(options, :command_runner, &Command.run/3)

    case command_runner.(args, channel, options) do
      {:ok, references} ->
        print_references(references)

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

  defp local_source_checkout?(:source_checkout),
    do: Application.get_env(:origen, :bootstrap_admin_profile) == :local

  defp local_source_checkout?(_channel), do: false

  if Mix.env() == :test do
    defp command_options,
      do: Application.get_env(:origen, :bootstrap_admin_command_options, [])
  else
    defp command_options, do: []
  end
end
