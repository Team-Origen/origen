defmodule Origen.BootstrapAdmin.Local.Readiness do
  import Kernel, except: [inspect: 1, inspect: 2]

  @moduledoc "Aggregate, metadata-only readiness validation for the local profile."

  alias Origen.BootstrapAdmin.Local.{Destination, Origin}

  defmodule Ready do
    @enforce_keys [:destination, :origin]
    defstruct @enforce_keys

    @type t :: %__MODULE__{destination: Destination.t(), origin: Origin.t()}
  end

  @type result :: {:ok, Ready.t()} | {:error, {:local_not_ready, [atom()]}}

  @spec inspect(map()) :: result()
  def inspect(config) when is_map(config), do: inspect(config, %{lstat: &File.lstat/1})
  def inspect(_config), do: {:error, {:local_not_ready, [:profile_invalid]}}

  @spec inspect(map(), map()) :: result()
  def inspect(config, probes) when is_map(config) and is_map(probes) do
    destination = Destination.parse(config[:destination])
    origin = Origin.validate(config[:activation_origin], config[:endpoint])

    findings =
      [
        unless(config[:profile] == :local and config[:enabled] == true, do: :profile_invalid),
        unless(config[:channel] == :source_checkout, do: :command_channel_invalid),
        endpoint_findings(config[:endpoint], config[:activation_origin]),
        unless(match?({:ok, _}, origin), do: :activation_origin_invalid),
        unless(sources_available?(config, probes, [:certificate_path, :certificate_key_path]),
          do: :certificate_source_unavailable
        ),
        unless(mailbox_stack?(config), do: :mailbox_adapter_invalid),
        unless(config[:preview] == Plug.Swoosh.MailboxPreview, do: :mailbox_preview_unavailable),
        unless(retention?(config), do: :mailbox_retention_invalid),
        unless(match?({:ok, _}, destination), do: :destination_invalid),
        unless(source_available?(config[:verifier_key_path], probes),
          do: :verifier_source_unavailable
        ),
        unless(
          source_available?(config[:totp_key_path], probes) and safe_tag?(config[:totp_key_tag]),
          do: :totp_source_unavailable
        ),
        unless(database?(config), do: :database_isolation_unconfigured)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    case {findings, destination, origin} do
      {[], {:ok, destination}, {:ok, origin}} ->
        {:ok, %Ready{destination: destination, origin: origin}}

      _ ->
        {:error, {:local_not_ready, findings}}
    end
  end

  def inspect(_config, _probes), do: {:error, {:local_not_ready, [:profile_invalid]}}

  defp endpoint_findings(endpoint, origin) when is_map(endpoint) do
    [
      unless(endpoint[:scheme] == :https, do: :endpoint_https_invalid),
      unless(endpoint[:http] == false and not Map.has_key?(endpoint, :http_port),
        do: :endpoint_http_enabled
      ),
      unless(endpoint[:ip] == {127, 0, 0, 1}, do: :endpoint_not_ipv4_loopback),
      unless(port_matches?(origin, endpoint[:port]), do: :endpoint_port_mismatch)
    ]
  end

  defp endpoint_findings(_endpoint, _origin),
    do: [
      :endpoint_https_invalid,
      :endpoint_http_enabled,
      :endpoint_not_ipv4_loopback,
      :endpoint_port_mismatch
    ]

  defp port_matches?(value, port) when is_binary(value) and is_integer(port) do
    case URI.parse(value) do
      %URI{port: ^port} -> true
      _ -> false
    end
  rescue
    _exception -> false
  end

  defp port_matches?(_value, _port), do: false

  defp mailbox_stack?(config) do
    config[:mailer] == Origen.Mailer and config[:adapter] == Swoosh.Adapters.Local and
      config[:storage] == Swoosh.Adapters.Local.Storage.Memory and
      config[:retention_owner] == Origen.BootstrapAdmin.Local.Mailbox
  end

  defp retention?(config),
    do:
      is_integer(config[:retention_ttl_seconds]) and config.retention_ttl_seconds in 1..900 and
        config[:max_messages] == 1

  defp sources_available?(config, probes, keys),
    do: Enum.all?(keys, &source_available?(config[&1], probes))

  defp source_available?(path, %{lstat: lstat}) when is_binary(path) and is_function(lstat, 1) do
    case safely(lstat, path) do
      {:ok, metadata} -> regular_owner_only?(metadata)
      _ -> false
    end
  end

  defp source_available?(_path, _probes), do: false

  defp safely(probe, path) do
    probe.(path)
  rescue
    _exception -> :error
  catch
    _kind, _reason -> :error
  end

  defp regular_owner_only?(%{type: :regular, size: size, mode: mode, owner: :current_user})
       when is_integer(size) and size in 1..65_536 and is_integer(mode),
       do: Bitwise.band(mode, 0o077) == 0

  defp regular_owner_only?(%File.Stat{type: :regular, size: size, mode: mode, uid: uid})
       when is_integer(size) and size in 1..65_536 and is_integer(mode) and is_integer(uid),
       do: uid == current_directory_uid() and Bitwise.band(mode, 0o077) == 0

  defp regular_owner_only?(_metadata), do: false

  defp current_directory_uid do
    case File.stat(File.cwd!()) do
      {:ok, %File.Stat{uid: uid}} -> uid
      _ -> nil
    end
  rescue
    _exception -> nil
  end

  defp safe_tag?(tag) when is_binary(tag), do: Regex.match?(~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/, tag)
  defp safe_tag?(_tag), do: false

  defp database?(config) do
    config[:database_scope] == :isolated_workstation and is_binary(config[:database_name]) and
      Regex.match?(~r/\Aorigen_[a-z0-9_]{1,63}\z/, config.database_name)
  end
end

defimpl Inspect, for: Origen.BootstrapAdmin.Local.Readiness.Ready do
  import Inspect.Algebra

  def inspect(_ready, _options), do: concat(["#LocalReadiness.Ready<redacted>"])
end
