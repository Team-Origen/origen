defmodule Origen.TestSupport.BootstrapAdmin.ApprovalFixture do
  @moduledoc false

  @key :crypto.hash(:sha256, "approval verifier test key")
  @now ~U[2026-09-02 12:00:00Z]

  def key, do: @key
  def now, do: @now
  def clock, do: fn -> @now end

  def request(overrides \\ %{}) do
    Map.merge(
      %{
        requester_ref: "operator-samuel",
        destination: "santiago@example.test",
        environment: "staging",
        operation: :issue,
        account_ref: nil
      },
      overrides
    )
  end

  def assertion(overrides \\ %{}) do
    fields =
      Map.merge(
        %{
          approval_id: "approval-123",
          requester_ref: "operator-samuel",
          confirmer_ref: "security-reviewer",
          destination: "santiago@example.test",
          environment: "staging",
          operation: :issue,
          account_ref: nil,
          issued_at: DateTime.add(@now, -60, :second),
          expires_at: DateTime.add(@now, 300, :second),
          key_id: "approval-key-1"
        },
        overrides
      )

    Map.put(fields, :signature, Map.get(overrides, :signature, sign(fields)))
  end

  def config(overrides \\ %{}) do
    Map.merge(
      %{
        clock: clock(),
        verifier_keys: %{"approval-key-1" => @key},
        accepted_key_ids: ["approval-key-1"],
        authorized_confirmers: ["security-reviewer"]
      },
      overrides
    )
  end

  def sign(fields) do
    fields
    |> Map.drop([:signature])
    |> Origen.BootstrapAdmin.Approval.signing_payload()
    |> then(&:crypto.mac(:hmac, :sha256, @key, &1))
    |> Base.url_encode64(padding: false)
  end
end
