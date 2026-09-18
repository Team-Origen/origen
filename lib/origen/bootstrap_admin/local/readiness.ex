defmodule Origen.BootstrapAdmin.Local.Readiness do
  import Kernel, except: [inspect: 1, inspect: 2]

  @moduledoc "Aggregate, metadata-only readiness validation for the local profile."

  alias Origen.BootstrapAdmin.Local.{Destination, Origin}

  @keys ~w(enabled profile channel destination activation_origin endpoint mailer adapter storage preview retention_owner retention_ttl_seconds max_messages certificate_file certificate_key_file verifier_key_file totp_key_file totp_key_tag database_name database_scope)a
  defmodule Ready do
    @moduledoc false
    @enforce_keys [
      :destination,
      :origin,
      :endpoint,
      :mailer,
      :adapter,
      :storage,
      :preview,
      :retention_owner,
      :retention_ttl_seconds,
      :max_messages,
      :certificate_file,
      :certificate_key_file,
      :verifier_key_file,
      :totp_key_file,
      :totp_key_tag,
      :database_name,
      :database_scope
    ]
    defstruct @enforce_keys
  end

  @type result :: {:ok, Ready.t()} | {:error, {:local_not_ready, [atom()]}}

  def inspect(config), do: inspect(config, %{lstat: &File.lstat/1})

  def inspect(config, probes) when is_map(config) and is_map(probes) do
    destination = Destination.parse(config[:destination])
    origin = Origin.validate(config[:activation_origin], config[:endpoint])

    findings =
      [
        unless(Enum.sort(Map.keys(config)) == Enum.sort(@keys), do: :local_config_keys_invalid),
        unless(config[:profile] == :local and config[:enabled] == true, do: :profile_invalid),
        unless(config[:channel] == :source_checkout, do: :command_channel_invalid),
        endpoint_findings(config[:endpoint], config[:activation_origin], probes),
        unless(match?({:ok, _}, origin), do: :activation_origin_invalid),
        unless(sources_available?(config, probes, [:certificate_file, :certificate_key_file]),
          do: :certificate_source_unavailable
        ),
        unless(mailbox_stack?(config), do: :mailbox_adapter_invalid),
        unless(config[:preview] == Plug.Swoosh.MailboxPreview, do: :mailbox_preview_unavailable),
        unless(retention?(config), do: :mailbox_retention_invalid),
        unless(match?({:ok, _}, destination), do: :destination_invalid),
        unless(source_available?(config[:verifier_key_file], probes),
          do: :verifier_source_unavailable
        ),
        unless(
          source_available?(config[:totp_key_file], probes) and safe_tag?(config[:totp_key_tag]),
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
        {:ok,
         struct!(
           Ready,
           Map.merge(
             Map.take(
               config,
               @keys -- [:enabled, :profile, :channel, :destination, :activation_origin]
             ),
             %{destination: destination, origin: origin}
           )
         )}

      _ ->
        {:error, {:local_not_ready, findings}}
    end
  end

  def inspect(_config, _probes), do: {:error, {:local_not_ready, [:local_config_keys_invalid]}}

  defp endpoint_findings(endpoint, origin, probes) when is_map(endpoint) do
    [
      unless(endpoint[:scheme] == :https, do: :endpoint_https_invalid),
      unless(endpoint[:http] == false and not Map.has_key?(endpoint, :http_port),
        do: :endpoint_http_enabled
      ),
      unless(endpoint[:ip] == {127, 0, 0, 1}, do: :endpoint_not_ipv4_loopback),
      unless(port_matches?(origin, endpoint[:port], probes), do: :endpoint_port_mismatch)
    ]
  end

  defp endpoint_findings(_, _, _),
    do: [
      :endpoint_https_invalid,
      :endpoint_http_enabled,
      :endpoint_not_ipv4_loopback,
      :endpoint_port_mismatch
    ]

  defp port_matches?(value, port, probes) when is_binary(value) and is_integer(port) do
    uri_parse = Map.get(probes, :uri_parse, &URI.parse/1)
    is_function(uri_parse, 1) and match?(%URI{port: ^port}, safely(uri_parse, value))
  end

  defp port_matches?(_, _, _), do: false

  defp mailbox_stack?(config),
    do:
      config[:mailer] == Origen.Mailer and config[:adapter] == Swoosh.Adapters.Local and
        config[:storage] == Swoosh.Adapters.Local.Storage.Memory and
        config[:retention_owner] == Origen.BootstrapAdmin.Local.Mailbox

  defp retention?(config),
    do:
      is_integer(config[:retention_ttl_seconds]) and config.retention_ttl_seconds in 1..900 and
        config[:max_messages] == 1

  defp sources_available?(config, probes, keys),
    do: Enum.all?(keys, &source_available?(config[&1], probes))

  defp source_available?(path, %{lstat: lstat} = probes)
       when is_binary(path) and is_function(lstat, 1) do
    case safely(lstat, path) do
      {:ok, metadata} -> regular_owner_only?(metadata, probes)
      _ -> false
    end
  end

  defp source_available?(_, _), do: false

  defp safely(probe), do: safely(fn _ignored -> probe.() end, nil)

  defp safely(probe, path) do
    probe.(path)
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  defp regular_owner_only?(
         %{type: :regular, size: size, mode: mode, owner: :current_user},
         _probes
       )
       when size in 1..65_536 and is_integer(mode), do: Bitwise.band(mode, 0o077) == 0

  defp regular_owner_only?(%File.Stat{type: :regular, size: size, mode: mode, uid: uid}, probes)
       when size in 1..65_536 and is_integer(mode),
       do: current_directory_uid(probes) == {:ok, uid} and Bitwise.band(mode, 0o077) == 0

  defp regular_owner_only?(_, _), do: false

  defp current_directory_uid(probes) do
    probe = Map.get(probes, :current_uid, &current_directory_uid/0)
    if is_function(probe, 0), do: safely(probe), else: :error
  end

  defp current_directory_uid do
    with {:ok, cwd} <- File.cwd(), {:ok, %{uid: uid}} <- File.stat(cwd), do: {:ok, uid}
  end

  defp safe_tag?(tag) when is_binary(tag), do: Regex.match?(~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/, tag)
  defp safe_tag?(_), do: false

  defp database?(config),
    do:
      config[:database_scope] == :isolated_workstation and is_binary(config[:database_name]) and
        Regex.match?(~r/\Aorigen_[a-z0-9_]{1,63}\z/, config.database_name)
end

defimpl Inspect, for: Origen.BootstrapAdmin.Local.Readiness.Ready do
  import Inspect.Algebra
  def inspect(_ready, _options), do: concat(["#LocalReadiness.Ready<redacted>"])
end
