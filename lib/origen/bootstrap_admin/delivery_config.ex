defmodule Origen.BootstrapAdmin.DeliveryConfig do
  @moduledoc "Pure fail-closed validation for staging delivery capabilities."

  alias Origen.BootstrapAdmin.Origin

  @enforce_keys [
    :environment,
    :origin,
    :from,
    :adapter,
    :provider_account,
    :retention_ttl_seconds,
    :access_audit_ref,
    :correlation
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          environment: String.t(),
          origin: Origin.t(),
          from: String.t(),
          adapter: module(),
          provider_account: String.t(),
          retention_ttl_seconds: pos_integer(),
          access_audit_ref: String.t(),
          correlation: map()
        }
  @type safe_reason :: :delivery_disabled | :invalid_delivery_config | Origin.safe_reason()

  @spec validate(map()) :: {:ok, t()} | {:error, safe_reason()}
  def validate(%{enabled: true} = config) do
    with {:ok, origin} <- Origin.validate(config[:activation_origin], config),
         :ok <- validate_adapter(config),
         :ok <- validate_capabilities(config),
         :ok <- validate_references(config) do
      {:ok,
       struct!(__MODULE__, %{
         environment: config.environment,
         origin: origin,
         from: config.from,
         adapter: config.adapter,
         provider_account: config.provider_account,
         retention_ttl_seconds: config.retention_ttl_seconds,
         access_audit_ref: config.access_audit_ref,
         correlation: config.correlation
       })}
    end
  end

  def validate(%{enabled: false}), do: {:error, :delivery_disabled}
  def validate(_config), do: {:error, :invalid_delivery_config}

  defp validate_adapter(config) do
    forbidden = [Swoosh.Adapters.Local, Swoosh.Adapters.Test]

    if is_atom(config[:adapter]) and is_list(config[:allowed_adapters]) and
         config.adapter in config.allowed_adapters and config.adapter not in forbidden,
       do: :ok,
       else: {:error, :invalid_delivery_config}
  end

  defp validate_capabilities(config) do
    valid_ttl =
      is_integer(config[:retention_ttl_seconds]) and
        is_integer(config[:max_retention_ttl_seconds]) and config.retention_ttl_seconds > 0 and
        config.retention_ttl_seconds <= config.max_retention_ttl_seconds

    if config[:encrypted_retention] == true and config[:access_audit] == true and
         config[:least_privilege_access] == true and config[:retries] == :disabled and valid_ttl,
       do: :ok,
       else: {:error, :invalid_delivery_config}
  end

  defp validate_references(config) do
    correlation = config[:correlation]

    if safe_ref?(config[:provider_account]) and safe_ref?(config[:access_audit_ref]) and
         is_binary(config[:from]) and config.from != "" and is_map(correlation) and
         valid_correlation?(correlation),
       do: :ok,
       else: {:error, :invalid_delivery_config}
  end

  defp valid_correlation?(%{pattern: %Regex{source: source}, max_length: max_length}),
    do: source == "^[A-Za-z0-9_-]+$" and is_integer(max_length) and max_length in 1..128

  defp valid_correlation?(_correlation), do: false

  defp safe_ref?(value) when is_binary(value),
    do: Regex.match?(~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/, value)

  defp safe_ref?(_value), do: false
end
