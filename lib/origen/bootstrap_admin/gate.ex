defmodule Origen.BootstrapAdmin.Gate do
  @moduledoc "Fail-closed boundary for first-admin bootstrap operations."

  @spec allowed?(term(), atom()) :: boolean()
  def allowed?(enabled, environment), do: enabled === true and environment != :prod

  @spec check() :: :ok | {:error, atom()}
  def check do
    enabled = Application.get_env(:origen, :bootstrap_admin_enabled)

    if allowed?(enabled, Mix.env()), do: :ok, else: {:error, :bootstrap_disabled}
  end
end
