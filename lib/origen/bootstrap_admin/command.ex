defmodule Origen.BootstrapAdmin.Command do
  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.Providers.Resend
  @switches [account_id: :integer, issued_by_ref: :string, approval_input_ref: :string]
  @safe_ref ~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,127}\z/
  def run(args, options \\ []) when is_list(args) do
    with {:ok, parsed} <- parse(args),
         {:ok, protected} <- reader(options).(parsed.approval_input_ref),
         {:ok, request} <- request(parsed, protected, options),
         do: orchestrator(options).(request, adapters(options))
  end

  defp parse(args) do
    {options, rest, invalid} = OptionParser.parse(args, strict: @switches)
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

  defp delivery_config, do: Application.get_env(:origen, :bootstrap_admin_delivery, %{})
  defp safe_ref?(value) when is_binary(value), do: Regex.match?(@safe_ref, value)
  defp safe_ref?(_), do: false
  defp safe_ref?(nil, nil), do: true
  defp safe_ref?(value, _), do: safe_ref?(value)
  defp positive?(nil), do: true
  defp positive?(value), do: is_integer(value) and value > 0
end
