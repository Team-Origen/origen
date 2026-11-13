defmodule Origen.Mailer.NullDelivery do
  @moduledoc """
  Production delivery adapter for environments without a configured email
  provider (#490 pending). Delivery succeeds without sending anything, so
  token issuance never depends on a mailer process being alive.
  """

  @behaviour Swoosh.Adapter

  @impl Swoosh.Adapter
  def deliver(_email, _config), do: {:ok, %{}}

  @impl Swoosh.Adapter
  def validate_config(_config), do: :ok
end
