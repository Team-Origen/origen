defmodule Mix.Tasks.Origen.Appointments.Expire do
  @shortdoc "Expire requested appointments that reached their start"

  use Mix.Task

  alias Origen.Booking.Expiry

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    case Expiry.sweep() do
      {:ok, %{expired_count: count}} ->
        Mix.shell().info("Expired #{count} appointment(s).")

      {:error, reason} ->
        Mix.raise("Appointment expiry failed: #{inspect(reason)}")
    end
  end
end
