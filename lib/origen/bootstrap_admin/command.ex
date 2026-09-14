defmodule Origen.BootstrapAdmin.Command do
  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.Gate
  alias Origen.BootstrapAdmin.Local.Eligibility
  alias Origen.BootstrapAdmin.Providers.Resend

  @staging_switches [account_id: :integer, issued_by_ref: :string, approval_input_ref: :string]
  @local_switches [account_id: :integer]
  @safe_ref ~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,127}\z/

  def run(args, options \\ []) when is_list(args),
    do: run(args, :source_checkout, options)

  def run(args, channel, options) when is_list(args) do
    with :ok <- Gate.check() do
      case Application.get_env(:origen, :bootstrap_admin_profile) do
        :staging -> run_staging(args, options)
        :local -> run_local(args, channel, options)
        _unknown -> {:error, :bootstrap_profile_invalid}
      end
    end
  end

  @doc false
  def parse_local_args(args) when is_list(args) do
    {options, rest, invalid} = OptionParser.parse(args, strict: @local_switches)
    parsed = Map.new(options)
    switches = option_names(args)

    if rest == [] and invalid == [] and Enum.uniq(switches) == switches and
         positive?(parsed[:account_id]) do
      {:ok, %{account_id: parsed[:account_id]}}
    else
      {:error, :invalid_arguments}
    end
  end

  defp run_staging(args, options) do
    with {:ok, parsed} <- parse_staging(args),
         {:ok, protected} <- reader(options).(parsed.approval_input_ref),
         {:ok, request} <- request(parsed, protected, options),
         do: orchestrator(options).(request, adapters(options))
  end

  defp run_local(args, channel, options) do
    with :ok <- apply(Eligibility, :check, [channel]),
         {:ok, parsed} <- local_parser(options).(args),
         do: local_command(options).(parsed)
  end

  defp parse_staging(args) do
    {options, rest, invalid} = OptionParser.parse(args, strict: @staging_switches)
    parsed = Map.new(options)

    switches = Enum.filter(args, &String.starts_with?(&1, "--"))

    if rest == [] and invalid == [] and Enum.uniq(switches) == switches and
         safe_ref?(parsed[:approval_input_ref]) and
         safe_ref?(parsed[:issued_by_ref], nil) and positive?(parsed[:account_id]) do
      {:ok, parsed}
    else
      {:error, :invalid_arguments}
    end
  end

  defp request(parsed, protected, options) when is_map(protected) do
    required = [:approval_assertion, :approval_config, :destination, :environment, :verifier_key]

    if Enum.all?(required, &Map.has_key?(protected, &1)) do
      {:ok,
       protected
       |> Map.take(required)
       |> Map.merge(%{
         operation: if(parsed[:account_id], do: :reissue, else: :issue),
         account_ref: parsed[:account_id],
         issued_by_ref: parsed[:issued_by_ref],
         delivery_config: Keyword.get(options, :delivery_config, delivery_config())
       })}
    else
      {:error, :invalid_protected_input}
    end
  end

  defp request(_, _, _), do: {:error, :invalid_protected_input}

  defp adapters(options),
    do: [provider: Keyword.get(options, :provider, Resend), gate: fn -> :ok end]

  defp reader(options),
    do:
      Keyword.get(
        options,
        :approval_reader,
        Application.get_env(:origen, :bootstrap_admin_approval_input_resolver, fn _ ->
          {:error, :invalid_protected_input}
        end)
      )

  defp orchestrator(options),
    do: Keyword.get(options, :orchestrator, &BootstrapAdmin.issue_and_deliver/2)

  if Mix.env() == :test do
    defp local_parser(options),
      do: Keyword.get(options, :local_parser, &parse_local_args/1)

    defp local_command(options),
      do: Keyword.get(options, :local_command, &local_unavailable/1)

    defp local_unavailable(_parsed), do: {:error, :local_bootstrap_not_ready}
  else
    defp local_parser(_options), do: &parse_local_args/1
    defp local_command(_options), do: &Origen.BootstrapAdmin.Local.Command.run/1
  end

  defp option_names(args) do
    args
    |> Enum.filter(&String.starts_with?(&1, "--"))
    |> Enum.map(fn option ->
      option |> String.trim_leading("--") |> String.split("=", parts: 2) |> hd()
    end)
  end

  defp delivery_config, do: Application.get_env(:origen, :bootstrap_admin_delivery, %{})
  defp safe_ref?(value) when is_binary(value), do: Regex.match?(@safe_ref, value)
  defp safe_ref?(_), do: false
  defp safe_ref?(nil, nil), do: true
  defp safe_ref?(value, _), do: safe_ref?(value)
  defp positive?(nil), do: true
  defp positive?(value), do: is_integer(value) and value > 0
end
