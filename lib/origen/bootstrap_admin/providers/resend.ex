defmodule Origen.BootstrapAdmin.Providers.Resend do
  @moduledoc "Single-attempt Swoosh Resend handoff with late credential resolution."

  @behaviour Origen.BootstrapAdmin.Provider

  @impl true
  def deliver(email, _metadata, %{credential_resolver: resolver} = config)
      when is_function(resolver, 0) do
    with {:ok, api_key} when is_binary(api_key) and api_key != "" <- resolver.(),
         {:ok, %{id: correlation_ref}} <- adapter(config).deliver(email, api_key: api_key) do
      {:ok, %{correlation_ref: correlation_ref}}
    else
      _result -> {:error, :provider_handoff_failed}
    end
  rescue
    _exception -> {:error, :provider_handoff_failed}
  catch
    _kind, _reason -> {:error, :provider_handoff_failed}
  end

  def deliver(_email, _metadata, _config), do: {:error, :provider_handoff_failed}

  if Mix.env() == :test do
    defp adapter(%{swoosh_adapter: adapter}) when is_atom(adapter), do: adapter
  end

  defp adapter(_config), do: Swoosh.Adapters.Resend
end
