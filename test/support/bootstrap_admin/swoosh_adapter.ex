defmodule Origen.TestSupport.BootstrapAdmin.SwooshAdapter do
  @moduledoc false

  def deliver(email, credentials) do
    test_pid = Process.get(:bootstrap_admin_test_pid)
    result = Process.get(:bootstrap_admin_swoosh_result)
    send(test_pid, {:swoosh_submission, email, credentials})
    result
  end
end
