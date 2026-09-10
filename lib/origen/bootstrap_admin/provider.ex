defmodule Origen.BootstrapAdmin.Provider do
  @moduledoc "Provider-neutral, single-attempt invitation handoff boundary."

  alias Swoosh.Email

  @type safe_reason :: :provider_handoff_failed
  @type result :: {:ok, %{correlation_ref: String.t()}} | {:error, safe_reason()}

  @callback deliver(Email.t(), map(), map()) :: term()

  @forbidden_adapters [
    Swoosh.Adapters.Local,
    Swoosh.Adapters.Test,
    Plug.Swoosh.MailboxPreview
  ]
  @correlation_pattern ~r/\A[A-Za-z0-9_-]{1,64}\z/

  @spec deliver(module(), Email.t(), map(), map()) :: result()
  def deliver(provider, %Email{} = email, metadata, config)
      when is_atom(provider) and is_map(metadata) and is_map(config) do
    if provider in @forbidden_adapters do
      {:error, :provider_handoff_failed}
    else
      provider
      |> submit_once(email, metadata, config)
      |> deliver_result()
    end
  end

  def deliver(_provider, _email, _metadata, _config),
    do: {:error, :provider_handoff_failed}

  @spec deliver_result(term()) :: result()
  def deliver_result({:ok, %{correlation_ref: ref}}) when is_binary(ref) do
    if Regex.match?(@correlation_pattern, ref),
      do: {:ok, %{correlation_ref: ref}},
      else: {:error, :provider_handoff_failed}
  end

  def deliver_result(_result), do: {:error, :provider_handoff_failed}

  defp submit_once(provider, email, metadata, config) do
    provider.deliver(email, metadata, config)
  rescue
    _exception -> {:error, :provider_handoff_failed}
  catch
    _kind, _reason -> {:error, :provider_handoff_failed}
  end
end
