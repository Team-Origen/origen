defmodule Origen.BootstrapAdmin.Origin do
  @moduledoc "Pure validation for an exact staging activation origin."

  @enforce_keys [:uri]
  defstruct @enforce_keys

  @type t :: %__MODULE__{uri: URI.t()}
  @type safe_reason :: :invalid_origin | :production_denied | :unapproved_host

  @spec validate(term(), map()) :: {:ok, t()} | {:error, safe_reason()}
  def validate(value, %{environment: environment, approved_hosts: hosts})
      when is_binary(value) and is_list(hosts) do
    with :ok <- staging(environment),
         {:ok, uri} <- parse(value),
         :ok <- approved_host(uri.host, hosts) do
      {:ok, %__MODULE__{uri: uri}}
    end
  end

  def validate(_value, _config), do: {:error, :invalid_origin}

  @spec to_uri(t()) :: String.t()
  def to_uri(%__MODULE__{uri: uri}), do: URI.to_string(uri)

  defp staging(environment) when environment in ["staging", :staging], do: :ok
  defp staging(_environment), do: {:error, :production_denied}

  defp parse(value) do
    uri = URI.parse(value)

    if uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and
         uri.port in [nil, 443] and is_nil(uri.userinfo) and is_nil(uri.query) and
         is_nil(uri.fragment) and uri.path == "/admin/activate" and safe_raw?(value),
       do: {:ok, uri},
       else: {:error, :invalid_origin}
  rescue
    _error -> {:error, :invalid_origin}
  end

  defp safe_raw?(value) do
    String.valid?(value) and value == String.trim(value) and
      not Regex.match?(~r/%(?:00|0a|0d|2e|2f|5c)/i, value) and
      not Regex.match?(~r/[\\\x00-\x1F\x7F]/u, value)
  end

  defp approved_host(host, hosts) do
    canonical = String.downcase(host)

    if host == canonical and canonical in hosts and
         Enum.all?(hosts, &(is_binary(&1) and &1 == String.downcase(&1))),
       do: :ok,
       else: {:error, :unapproved_host}
  end
end
