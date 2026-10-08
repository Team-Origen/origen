defmodule OrigenWeb.ProfessionalAvailabilityComponent do
  use OrigenWeb, :live_component

  alias Origen.Availability

  @days [
    {:monday, "Lunes"},
    {:tuesday, "Martes"},
    {:wednesday, "Miércoles"},
    {:thursday, "Jueves"},
    {:friday, "Viernes"},
    {:saturday, "Sábado"},
    {:sunday, "Domingo"}
  ]

  @impl true
  def update(%{principal: principal} = assigns, socket) do
    context = Map.get(assigns, :availability_context, availability())
    persistence_mode = Map.get(assigns, :persistence_mode, :persistent)

    component_assigns =
      assigns
      |> Map.put(:availability_context, context)
      |> Map.put(:persistence_mode, persistence_mode)

    case context.get_own_configuration(principal) do
      {:ok, configuration} ->
        {:ok,
         socket
         |> assign(component_assigns)
         |> assign(
           configuration: configuration,
           editing: false,
           dirty: false,
           draft: nil,
           local_errors: %{},
           feedback: nil,
           validation_errors: nil,
           load_error: false
         )}

      {:error, _reason} ->
        {:ok,
         socket
         |> assign(component_assigns)
         |> assign(
           configuration: nil,
           editing: false,
           dirty: false,
           draft: nil,
           local_errors: %{},
           feedback: nil,
           validation_errors: nil,
           load_error: true
         )}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, days: @days)

    ~H"""
    <div id={@id} class="flex flex-col gap-6 sm:gap-8">
      <.alert
        :if={@load_error}
        id="availability-load-error"
        color="danger"
        variant="callout"
        with_icon
      >
        <strong>No se pudo cargar la disponibilidad.</strong> Intente nuevamente más tarde.
      </.alert>

      <%= if @configuration do %>
        <section id="availability-section" aria-labelledby="weekly-availability-heading">
          <.card variant="basic">
            <.card_header>
              <.h2 id="weekly-availability-heading" no_margin>Disponibilidad semanal</.h2>
            </.card_header>
            <.card_content>
              <div id="availability-summary" class="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
                <article
                  :for={{day, label} <- @days}
                  id={"availability-summary-#{day}"}
                  class="rounded-lg border border-border bg-surface-muted p-4 dark:border-gray-700 dark:bg-gray-800"
                >
                  <h3 class="font-semibold">{label}</h3>
                  <p class="mt-2 text-sm text-text-muted dark:text-gray-300">
                    {windows_summary(Map.fetch!(@configuration.weekly_availability, day))}
                  </p>
                </article>
              </div>
              <div class="mt-6 border-t border-border pt-6">
                <h3 id="booking-rules-heading" class="font-semibold text-text dark:text-gray-100">
                  Período de reserva
                </h3>
                <dl id="booking-rules-summary" class="mt-4 grid gap-4 sm:grid-cols-2">
                  <div>
                    <dt class="font-medium">Anticipación máxima</dt>
                    <dd>{@configuration.booking_horizon_days} días</dd>
                  </div>
                  <div>
                    <dt class="font-medium">Anticipación mínima</dt>
                    <dd>{@configuration.minimum_lead_minutes} minutos</dd>
                  </div>
                </dl>
              </div>
            </.card_content>
          </.card>
        </section>

        <section aria-labelledby="timezone-heading">
          <.card variant="basic">
            <.card_header>
              <.h2 id="timezone-heading" no_margin>Zona horaria</.h2>
            </.card_header>
            <.card_content>
              <p id="timezone-summary">
                Los horarios se interpretan en <strong>{@configuration.timezone}</strong>.
              </p>
            </.card_content>
          </.card>
        </section>
      <% end %>
    </div>
    """
  end

  defp windows_summary([]), do: "Sin disponibilidad"

  defp windows_summary(windows) do
    Enum.map_join(windows, ", ", &"#{&1.start} a #{&1.end}")
  end

  defp availability do
    Application.get_env(:origen, :availability_context, Availability)
  end
end
