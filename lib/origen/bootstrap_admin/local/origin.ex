defmodule Origen.BootstrapAdmin.Local.Origin do
  @moduledoc "Exact loopback HTTPS activation origin type."

  @enforce_keys [:uri]
  defstruct @enforce_keys

  @type t :: %__MODULE__{uri: URI.t()}
  @type safe_reason :: :unsafe_origin

  @spec validate(term(), term()) :: {:ok, t()} | {:error, safe_reason()}
  def validate(value, endpoint) when is_binary(value) do
    with {:ok, port} <- endpoint_port(endpoint),
         expected = "https://127.0.0.1:#{port}/admin/activate",
         true <- value == expected,
         {:ok, uri} <- exact_uri(value, port) do
      {:ok, %__MODULE__{uri: uri}}
    else
      _ -> {:error, :unsafe_origin}
    end
  end

  def validate(_value, _endpoint), do: {:error, :unsafe_origin}

  @spec to_uri(t()) :: String.t()
  def to_uri(%__MODULE__{uri: uri}), do: URI.to_string(uri)

  defp endpoint_port(%{scheme: :https, ip: {127, 0, 0, 1}, port: port, http: false} = endpoint)
       when is_integer(port) and port in 1..65_535 and map_size(endpoint) == 4,
       do: {:ok, port}

  defp endpoint_port(_endpoint), do: :error

  defp exact_uri(value, port) do
    uri = URI.parse(value)

    if uri.scheme == "https" and uri.host == "127.0.0.1" and uri.port == port and
         uri.path == "/admin/activate" and is_nil(uri.userinfo) and is_nil(uri.query) and
         is_nil(uri.fragment) and String.valid?(value),
       do: {:ok, uri},
       else: :error
  rescue
    _exception -> :error
  end
end

defimpl Inspect, for: Origen.BootstrapAdmin.Local.Origin do
  import Inspect.Algebra

  def inspect(_origin, _options), do: concat(["#LocalOrigin<redacted>"])
end
