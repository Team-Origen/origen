defmodule Origen.Mailer.NullDelivery do
  @moduledoc """
  Production delivery adapter for environments without a configured email
  provider (#490 pending). Delivery succeeds without sending anything, so
  token issuance never depends on a mailer process being alive.

  Every skipped delivery logs a warning naming this adapter, so the missing
  provider stays visible instead of silently succeeding. The warning never
  includes email content.
  """

  @behaviour Swoosh.Adapter

  require Logger

  @impl Swoosh.Adapter
  def deliver(_email, _config) do
    Logger.warning(
      "email delivery skipped: no provider configured (NullDelivery adapter)"
    )

    {:ok, %{}}
  end

  @impl Swoosh.Adapter
  def validate_config(_config), do: :ok
end
