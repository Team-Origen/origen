defmodule OrigenWeb.ProfessionalAvailabilityPreviewLive do
  use OrigenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Vista previa de disponibilidad")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-page py-6 text-text dark:bg-gray-950 dark:text-gray-100 sm:py-10">
      <.container max_width="xl">
        <div class="flex flex-col gap-6 sm:gap-8">
          <div id="availability-development-preview" role="note">
            <.alert color="warning" variant="callout" with_icon>
              <strong>Vista previa de desarrollo.</strong>
              Utiliza datos locales de muestra y los cambios no se guardan. Esta pantalla no reemplaza la configuración profesional autenticada.
            </.alert>
          </div>

          <.live_component
            module={OrigenWeb.ProfessionalAvailabilityComponent}
            id="professional-availability"
            principal={:development_preview}
            availability_context={__MODULE__.PreviewAvailability}
            persistence_mode={:preview}
          />
        </div>
      </.container>
    </main>
    """
  end

  defmodule PreviewAvailability do
    @empty_days [:saturday, :sunday]
    @working_days [:monday, :tuesday, :wednesday, :thursday, :friday]

    def get_own_configuration(:development_preview) do
      {:ok, configuration(default_week(), 30, 30)}
    end

    def replace_own_configuration(:development_preview, attributes) do
      {:ok,
       configuration(
         attributes.weekly_availability,
         attributes.booking_horizon_days,
         attributes.minimum_lead_minutes
       )}
    end

    defp default_week do
      working_windows = [%{start: "08:00", end: "12:00"}, %{start: "14:00", end: "18:00"}]

      Map.new(@working_days, &{&1, working_windows})
      |> Map.merge(Map.new(@empty_days, &{&1, []}))
    end

    defp configuration(week, horizon, lead) do
      %{
        weekly_availability: week,
        booking_horizon_days: horizon,
        minimum_lead_minutes: lead,
        agenda_interval_minutes: 30,
        timezone: "America/Argentina/Buenos_Aires"
      }
    end
  end
end
