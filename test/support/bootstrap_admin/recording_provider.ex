defmodule Origen.TestSupport.BootstrapAdmin.RecordingProvider do
  @moduledoc false

  @behaviour Origen.BootstrapAdmin.Provider

  @impl true
  def deliver(email, metadata, %{test_pid: test_pid, result: result} = config)
      when is_pid(test_pid) do
    if before_send = config[:before_send], do: before_send.(metadata.invitation_id)
    send(test_pid, {:provider_submission, email, metadata})

    case result do
      {:raise, exception} -> raise exception
      other -> other
    end
  end

  def support_summary, do: "provider handoff failed"
end
