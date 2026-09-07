defmodule Origen.BootstrapAdmin.Redaction do
  @moduledoc "Strict allowlist applied before every bootstrap sink."

  @allowed ~w(event result actor_kind actor_ref account_ref invitation_ref timestamp)a
  @sensitive ~w(password password_confirmation token raw_token url activation_url totp_seed otp qr_payload recovery_code session cookie digest key)a

  def sanitize(payload) when is_map(payload) do
    normalized_keys = Map.keys(payload) |> Enum.map(&normalize_key/1)

    cond do
      Enum.any?(normalized_keys, &(&1 in @sensitive)) ->
        {:error, :sensitive_field}

      Enum.any?(normalized_keys, &(&1 not in @allowed)) ->
        {:error, :unapproved_field}

      Enum.any?(payload, fn {key, value} ->
        normalize_key(key) in [:actor_ref, :account_ref, :invitation_ref] and
            token_like?(value)
      end) ->
        {:error, :sensitive_reference}

      true ->
        {:ok, payload}
    end
  end

  def sanitize(_), do: {:error, :invalid_payload}

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp normalize_key(_), do: nil

  defp token_like?(value) when is_binary(value),
    do: Regex.match?(~r/(https?:\/\/|token|secret|password|otp|session|digest|key)/i, value)

  defp token_like?(_), do: true
end
