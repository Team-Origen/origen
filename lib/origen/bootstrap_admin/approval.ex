defmodule Origen.BootstrapAdmin.Approval do
  @moduledoc "Verified in-memory approval for one bootstrap invitation attempt."

  @enforce_keys [
    :approval_id,
    :requester_ref,
    :confirmer_ref,
    :destination,
    :environment,
    :operation,
    :issued_at,
    :expires_at,
    :key_id
  ]
  defstruct @enforce_keys ++ [:account_ref]

  @type t :: %__MODULE__{
          approval_id: String.t(),
          requester_ref: String.t(),
          confirmer_ref: String.t(),
          destination: String.t(),
          environment: String.t(),
          operation: :issue | :reissue,
          account_ref: String.t() | nil,
          issued_at: DateTime.t(),
          expires_at: DateTime.t(),
          key_id: String.t()
        }

  @signed_fields [
    :approval_id,
    :requester_ref,
    :confirmer_ref,
    :destination,
    :environment,
    :operation,
    :account_ref,
    :issued_at,
    :expires_at,
    :key_id
  ]

  @spec signing_payload(map()) :: binary()
  def signing_payload(fields) when is_map(fields) do
    @signed_fields
    |> Enum.map(fn field ->
      value = encode(Map.get(fields, field))
      <<byte_size(value)::unsigned-big-64, value::binary>>
    end)
    |> IO.iodata_to_binary()
  end

  defp encode(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp encode(nil), do: ""
  defp encode(value) when is_atom(value), do: Atom.to_string(value)
  defp encode(value) when is_binary(value), do: value
  defp encode(_value), do: "<invalid>"
end
