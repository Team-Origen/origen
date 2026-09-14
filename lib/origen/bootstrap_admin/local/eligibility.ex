defmodule Origen.BootstrapAdmin.Local.Eligibility do
  @moduledoc "Fail-closed eligibility boundary for source-checkout local bootstrap."

  alias Origen.BootstrapAdmin.Gate

  @compiled_env Mix.env()
  @denied {:error, :local_bootstrap_ineligible}

  @spec check(term()) :: :ok | {:error, :local_bootstrap_ineligible}
  def check(channel) do
    with :ok <- Gate.check() do
      local = Application.get_env(:origen, :bootstrap_admin_local, %{})

      evaluate(%{
        environment: @compiled_env,
        shared_enabled: Application.get_env(:origen, :bootstrap_admin_enabled),
        profile: Application.get_env(:origen, :bootstrap_admin_profile),
        local_enabled: Application.get_env(:origen, :bootstrap_admin_local_enabled),
        local_config_enabled: local_enabled(local),
        channel: channel
      })
    else
      {:error, :bootstrap_disabled} -> @denied
    end
  end

  @doc false
  @spec evaluate(term()) :: :ok | {:error, :local_bootstrap_ineligible}
  def evaluate(%{
        environment: :dev,
        shared_enabled: true,
        profile: :local,
        local_enabled: true,
        local_config_enabled: true,
        channel: :source_checkout
      }),
      do: :ok

  def evaluate(_facts), do: @denied

  defp local_enabled(%{enabled: enabled}), do: enabled
  defp local_enabled(_local), do: nil
end
