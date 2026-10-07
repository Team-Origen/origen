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
  def handle_event("edit_availability", _params, socket) do
    {:noreply,
     assign(socket,
       editing: true,
       draft: configuration_to_draft(socket.assigns.configuration),
       local_errors: %{},
       feedback: nil,
       validation_errors: nil
     )}
  end

  @impl true
  def handle_event("cancel_availability", _params, socket) do
    {:noreply,
     assign(socket,
       editing: false,
       draft: nil,
       local_errors: %{},
       feedback: nil,
       validation_errors: nil
     )}
  end

  @impl true
  def handle_event("add_availability_window", %{"day" => day_name}, socket) do
    with {:ok, day} <- day_atom(day_name) do
      interval = socket.assigns.configuration.agenda_interval_minutes
      window = %{start: "00:00", end: format_minutes(interval)}

      {:noreply, update_draft_day(socket, day, &(&1 ++ [window]))}
    else
      :error -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "remove_availability_window",
        %{"day" => day_name, "index" => index_text},
        socket
      ) do
    with {:ok, day} <- day_atom(day_name),
         {index, ""} when index >= 0 <- Integer.parse(index_text) do
      {:noreply, update_draft_day(socket, day, &List.delete_at(&1, index))}
    else
      _invalid -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_availability_day", %{"day" => day_name}, socket) do
    with {:ok, day} <- day_atom(day_name) do
      {:noreply, update_draft_day(socket, day, fn _windows -> [] end)}
    else
      :error -> {:noreply, socket}
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
        <section
          :if={not @editing}
          id="availability-section"
          aria-labelledby="weekly-availability-heading"
        >
          <.card variant="basic">
            <.card_header>
              <.h2 id="weekly-availability-heading" no_margin>Disponibilidad semanal</.h2>
              <:action>
                <.button
                  id="edit-availability-button"
                  color="primary"
                  size="sm"
                  phx-click="edit_availability"
                  phx-target={@myself}
                >
                  Editar disponibilidad
                </.button>
              </:action>
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

        <div id="availability-editor-region" hidden={not @editing}>
          <section
            :if={@editing}
            id="availability-section"
            aria-labelledby="weekly-availability-heading"
          >
            <.card variant="basic">
              <.card_header>
                <.h2 id="weekly-availability-heading" no_margin>Disponibilidad semanal</.h2>
                <:action>
                  <.button
                    type="button"
                    color="gray"
                    variant="outline"
                    size="sm"
                    phx-click="cancel_availability"
                    phx-target={@myself}
                  >
                    Cerrar edición
                  </.button>
                </:action>
              </.card_header>
              <.card_content>
                <div class="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
                  <fieldset
                    :for={{day, label} <- @days}
                    id={"availability-day-#{day}"}
                    class="rounded-lg border border-border bg-surface-muted p-4 dark:border-gray-700 dark:bg-gray-800"
                  >
                    <legend class="px-1 font-semibold">{label}</legend>
                    <p
                      :if={Map.fetch!(@draft.weekly_availability, day) == []}
                      class="mb-3 text-sm text-text-muted dark:text-gray-300"
                    >
                      Sin disponibilidad
                    </p>
                    <div class="space-y-3">
                      <div
                        :for={
                          {window, index} <-
                            Enum.with_index(Map.fetch!(@draft.weekly_availability, day))
                        }
                        class="grid grid-cols-2 gap-3 rounded-md border border-border bg-surface p-3 dark:border-gray-700 dark:bg-gray-900"
                      >
                        <label class="text-sm font-medium" for={"availability-#{day}-#{index}-start"}>
                          Desde
                          <input
                            id={"availability-#{day}-#{index}-start"}
                            class="pc-input mt-1"
                            type="time"
                            step={@configuration.agenda_interval_minutes * 60}
                            value={window.start}
                          />
                        </label>
                        <label class="text-sm font-medium" for={"availability-#{day}-#{index}-end"}>
                          Hasta
                          <input
                            id={"availability-#{day}-#{index}-end"}
                            class="pc-input mt-1"
                            type="time"
                            step={@configuration.agenda_interval_minutes * 60}
                            value={window.end}
                          />
                        </label>
                        <div class="col-span-2">
                          <.button
                            type="button"
                            color="danger"
                            variant="outline"
                            size="xs"
                            phx-click="remove_availability_window"
                            phx-value-day={day}
                            phx-value-index={index}
                            phx-target={@myself}
                          >
                            Eliminar horario
                          </.button>
                        </div>
                      </div>
                    </div>
                    <div class="mt-4 flex flex-wrap gap-2">
                      <.button
                        type="button"
                        color="secondary"
                        variant="outline"
                        size="xs"
                        phx-click="add_availability_window"
                        phx-value-day={day}
                        phx-target={@myself}
                      >
                        Agregar horario
                      </.button>
                      <.button
                        type="button"
                        color="gray"
                        variant="outline"
                        size="xs"
                        phx-click="clear_availability_day"
                        phx-value-day={day}
                        phx-target={@myself}
                      >
                        Limpiar día
                      </.button>
                    </div>
                  </fieldset>
                </div>
              </.card_content>
              <.card_footer>
                <.button
                  type="button"
                  color="gray"
                  variant="outline"
                  phx-click="cancel_availability"
                  phx-target={@myself}
                >
                  Cancelar
                </.button>
              </.card_footer>
            </.card>
          </section>
        </div>

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

  defp configuration_to_draft(configuration) do
    %{
      weekly_availability: configuration.weekly_availability,
      booking_horizon_days: Integer.to_string(configuration.booking_horizon_days),
      minimum_lead_minutes: Integer.to_string(configuration.minimum_lead_minutes)
    }
  end

  defp update_draft_day(socket, day, update_windows) do
    draft = socket.assigns.draft
    windows = draft.weekly_availability |> Map.fetch!(day) |> update_windows.()
    week = Map.put(draft.weekly_availability, day, windows)
    assign(socket, draft: %{draft | weekly_availability: week})
  end

  defp day_atom(day_name) do
    case Enum.find(@days, fn {day, _label} -> Atom.to_string(day) == day_name end) do
      {day, _label} -> {:ok, day}
      nil -> :error
    end
  end

  defp format_minutes(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    String.pad_leading(Integer.to_string(hours), 2, "0") <>
      ":" <>
      String.pad_leading(Integer.to_string(remaining_minutes), 2, "0")
  end

  defp availability do
    Application.get_env(:origen, :availability_context, Availability)
  end
end
