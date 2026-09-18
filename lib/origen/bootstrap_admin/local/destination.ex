defmodule Origen.BootstrapAdmin.Local.Destination do
  @moduledoc "Exact synthetic local destination type."

  @enforce_keys [:address]
  defstruct @enforce_keys

  @type t :: %__MODULE__{address: String.t()}
  @type safe_reason :: :invalid_destination

  @spec parse(term()) :: {:ok, t()} | {:error, safe_reason()}
  def parse(value) when is_binary(value) do
    if valid?(value), do: {:ok, %__MODULE__{address: value}}, else: {:error, :invalid_destination}
  end

  def parse(_value), do: {:error, :invalid_destination}

  @spec address(t()) :: String.t()
  def address(%__MODULE__{address: address}), do: address

  defp valid?(value) do
    String.valid?(value) and byte_size(value) <= 254 and ascii?(value) and
      value == String.downcase(value) and value == String.trim(value) and
      not Regex.match?(~r/[\s\x00-\x1F\x7F"<>\\:,]/, value) and local?(value)
  end

  defp ascii?(value), do: Enum.all?(:binary.bin_to_list(value), &(&1 <= 127))

  defp local?(value) do
    case String.split(value, "@", parts: 3) do
      [local, "example.test"] ->
        Regex.match?(~r/\A[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?\z/, local) and
          not String.contains?(local, "..")

      _ ->
        false
    end
  end
end

defimpl Inspect, for: Origen.BootstrapAdmin.Local.Destination do
  import Inspect.Algebra

  def inspect(_destination, _options), do: concat(["#LocalDestination<redacted>"])
end
