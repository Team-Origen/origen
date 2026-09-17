defmodule Origen.BootstrapAdmin.Local.Secrets do
  @moduledoc false
  alias Origen.BootstrapAdmin.Local.Readiness

  def get_verifier_key(source \\ canonical_ready()), do: load(source, :verifier_key_file)

  def get_totp_keyring(source \\ canonical_ready()) do
    with {:ok, key} <- load(source, :totp_key_file),
         {:ok, tag} <- fetch(source, :totp_key_tag) do
      {:ok, %{active: %{tag: tag, key: key}, retired: []}}
    else
      _ -> {:error, :secrets_unavailable}
    end
  end

  defp canonical_ready do
    case Readiness.inspect(Application.get_env(:origen, :bootstrap_admin_local, %{})) do
      {:ok, ready} -> ready
      _ -> nil
    end
  end

  defp load(source, key) do
    with {:ok, path} <- fetch(source, key),
         {:ok, content} <- safe_read(path),
         {:ok, decoded} <- safe_decode(content, 32),
         do: {:ok, decoded},
         else: (_ -> {:error, :secrets_unavailable})
  end

  defp fetch(%{} = source, key) do
    case Map.fetch(source, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      _ -> {:error, :missing_config}
    end
  end

  defp fetch(_, _), do: {:error, :missing_config}

  defp safe_read(path) do
    with {:ok, %{type: :regular, size: size, mode: mode} = stat} when size in 1..4096 <-
           File.lstat(path),
         true <- Bitwise.band(mode, 0o077) == 0,
         true <- not Map.has_key?(stat, :links) or stat.links == 1,
         do: File.read(path),
         else: (_ -> {:error, :invalid_file})
  rescue
    _ -> {:error, :invalid_file}
  end

  defp safe_decode(content, expected_bytes) do
    content = String.trim(content)

    decoded =
      case Base.decode64(content, padding: false) do
        :error -> Base.decode64(content)
        result -> result
      end

    case decoded do
      {:ok, bytes} when byte_size(bytes) >= expected_bytes ->
        {:ok, binary_part(bytes, 0, expected_bytes)}

      _ ->
        {:error, :invalid_encoding}
    end
  end
end
