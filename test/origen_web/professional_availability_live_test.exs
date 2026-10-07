defmodule OrigenWeb.ProfessionalAvailabilityLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  @path "/configuracion/profesional"

  defmodule UnavailableAvailability do
    def get_own_configuration(_principal), do: {:error, :unavailable}
  end

  defmodule RejectingAvailability do
    def get_own_configuration(principal), do: Origen.Availability.get_own_configuration(principal)
    def replace_own_configuration(_principal, _attributes), do: {:error, :unavailable}
  end

  defmodule TrackingAvailability do
    def get_own_configuration(principal), do: Origen.Availability.get_own_configuration(principal)

    def replace_own_configuration(_principal, _attributes) do
      send(Application.fetch_env!(:origen, :availability_test_pid), :replacement_called)
      {:error, :unexpected_replacement}
    end
  end

  setup %{conn: conn} do
    previous_context = Application.get_env(:origen, :availability_context)
