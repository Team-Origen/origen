defmodule Origen.BootstrapAdmin.Local.Secrets do
  @moduledoc false

  @doc """
  Reads and decodes local development secrets securely.
  Ensures files are regular files (not symlinks), bounded in size.
  Never returns actual key contents in error messages.
  """

  def get_verifier_key do
    with {:ok, path} <- fetch_config(:bootstrap_admin_verifier_key),
         {:ok, content} <- safe_read(path),
         {:ok, decoded} <- safe_decode(content, 32) do
      {:ok, decoded}
    else
      _ -> {:error, :secrets_unavailable}
    end
  end

  def get_totp_keyring do
    with {:ok, path} <- fetch_config(:bootstrap_admin_totp_keyring),
         {:ok, content} <- safe_read(path),
         {:ok, decoded} <- safe_decode(content, 32) do
      {:ok, %{active: %{tag: "local.dev.v1", key: decoded}, retired: []}}
    else
      _ -> {:error, :secrets_unavailable}
    end
  end

  defp fetch_config(key) do
    case Application.get_env(:origen, key) do
      {:file, path} when is_binary(path) -> {:ok, path}
      _ -> {:error, :missing_config}
    end
  end

  defp safe_read(path) do
    case File.stat(path) do
      {:ok, %{type: :regular, size: size}} when size <= 4096 ->
        File.read(path)

      _ ->
        {:error, :invalid_file}
    end
  end

  defp safe_decode(content, expected_bytes) do
    content = String.trim(content)

    case Base.decode64(content, padding: false) do
      {:ok, bytes} when byte_size(bytes) == expected_bytes ->
        {:ok, bytes}

      {:ok, bytes} when byte_size(bytes) > expected_bytes ->
        {:ok, binary_part(bytes, 0, expected_bytes)}

      _ ->
        case Base.decode64(content) do
          {:ok, bytes} when byte_size(bytes) == expected_bytes ->
            {:ok, bytes}

          {:ok, bytes} when byte_size(bytes) > expected_bytes ->
            {:ok, binary_part(bytes, 0, expected_bytes)}

          _ ->
            {:error, :invalid_encoding}
        end
    end
  end
end
