defmodule Origen.BootstrapAdmin.ApprovalVerifier do
  @moduledoc "Pure verification for bounded deployment approval assertions."

  alias Origen.BootstrapAdmin.Approval

  @type safe_reason ::
          :invalid_approval
          | :invalid_signature
          | :unapproved_key
          | :approval_not_current
          | :self_approval
          | :unauthorized_confirmer
          | :approval_mismatch
          | :production_denied

  @spec verify(map(), map(), map()) :: {:ok, Approval.t()} | {:error, safe_reason()}
  def verify(assertion, request, config)
      when is_map(assertion) and is_map(request) and is_map(config) do
    with :ok <- valid_shape(assertion, request, config),
         :ok <- valid_key(assertion, config),
         :ok <- valid_signature(assertion, config),
         :ok <- current(assertion, config),
         :ok <- distinct_and_authorized(assertion, config),
         :ok <- non_production(assertion, request),
         :ok <- matches_request(assertion, request) do
      {:ok, struct!(Approval, Map.drop(assertion, [:signature]))}
    end
  end

  def verify(_assertion, _request, _config), do: {:error, :invalid_approval}

  defp valid_shape(assertion, request, config) do
    assertion_fields = [
      :approval_id,
      :requester_ref,
      :confirmer_ref,
      :destination,
      :environment,
      :operation,
      :issued_at,
      :expires_at,
      :key_id,
      :signature
    ]

    request_fields = [:requester_ref, :destination, :environment, :operation]

    reference_fields = [:approval_id, :requester_ref, :confirmer_ref, :key_id]

    if Enum.all?(assertion_fields, &valid_value?(Map.get(assertion, &1))) and
         Enum.all?(request_fields, &valid_value?(Map.get(request, &1))) and
         Enum.all?(reference_fields, &safe_ref?(Map.get(assertion, &1))) and
         is_function(config[:clock], 0) and is_map(config[:verifier_keys]) and
         is_list(config[:accepted_key_ids]) and is_list(config[:authorized_confirmers]),
       do: :ok,
       else: {:error, :invalid_approval}
  end

  defp valid_value?(%DateTime{}), do: true
  defp valid_value?(value) when is_binary(value), do: value != "" and byte_size(value) <= 320
  defp valid_value?(value) when value in [:issue, :reissue], do: true
  defp valid_value?(_value), do: false

  defp safe_ref?(value) when is_binary(value),
    do: Regex.match?(~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/, value)

  defp safe_ref?(_value), do: false

  defp valid_key(assertion, config) do
    key = Map.get(config.verifier_keys, assertion.key_id)

    if assertion.key_id in config.accepted_key_ids and is_binary(key) and byte_size(key) >= 32,
      do: :ok,
      else: {:error, :unapproved_key}
  end

  defp valid_signature(assertion, config) do
    expected =
      :crypto.mac(
        :hmac,
        :sha256,
        Map.fetch!(config.verifier_keys, assertion.key_id),
        Approval.signing_payload(assertion)
      )
      |> Base.url_encode64(padding: false)

    if byte_size(expected) == byte_size(assertion.signature) and
         Plug.Crypto.secure_compare(expected, assertion.signature),
       do: :ok,
       else: {:error, :invalid_signature}
  end

  defp current(assertion, config) do
    now = config.clock.()

    if DateTime.compare(assertion.issued_at, now) != :gt and
         DateTime.compare(assertion.expires_at, now) == :gt and
         DateTime.compare(assertion.issued_at, assertion.expires_at) == :lt,
       do: :ok,
       else: {:error, :approval_not_current}
  end

  defp distinct_and_authorized(assertion, config) do
    cond do
      assertion.requester_ref == assertion.confirmer_ref ->
        {:error, :self_approval}

      assertion.confirmer_ref not in config.authorized_confirmers ->
        {:error, :unauthorized_confirmer}

      true ->
        :ok
    end
  end

  defp non_production(assertion, request) do
    if assertion.environment == "staging" and request.environment == "staging",
      do: :ok,
      else: {:error, :production_denied}
  end

  defp matches_request(assertion, request) do
    fields = [:requester_ref, :destination, :environment, :operation, :account_ref]

    if Enum.all?(fields, &(Map.get(assertion, &1) == Map.get(request, &1))),
      do: :ok,
      else: {:error, :approval_mismatch}
  end
end
