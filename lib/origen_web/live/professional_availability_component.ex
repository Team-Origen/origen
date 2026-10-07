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
       copy_source: :monday,
       copy_targets: [],
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
       copy_source: nil,
       copy_targets: [],
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
  def handle_event("change_availability", %{"availability" => params} = all_params, socket) do
    {copy_source, copy_targets} = copy_selection(Map.get(all_params, "copy", %{}), socket)

    {:noreply,
     assign(socket,
       draft: params_to_draft(params),
       local_errors:
         params |> params_to_draft() |> local_time_errors(socket.assigns.configuration),
       copy_source: copy_source,
       copy_targets: copy_targets,
       validation_errors: nil
     )}
  end

  @impl true
  def handle_event("copy_availability_day", _params, socket) do
    source_windows =
      Map.fetch!(socket.assigns.draft.weekly_availability, socket.assigns.copy_source)

    week =
      Enum.reduce(socket.assigns.copy_targets, socket.assigns.draft.weekly_availability, fn day,
                                                                                            week ->
        Map.put(week, day, source_windows)
      end)

    {:noreply,
     assign(socket,
       draft: %{socket.assigns.draft | weekly_availability: week},
       local_errors:
         local_time_errors(
           %{socket.assigns.draft | weekly_availability: week},
           socket.assigns.configuration
         ),
       validation_errors: nil
     )}
  end

  @impl true
  def handle_event("save_availability", %{"availability" => params}, socket) do
    draft = params_to_draft(params)
    local_errors = local_time_errors(draft, socket.assigns.configuration)

    if map_size(local_errors) > 0 do
      {:noreply,
       assign(socket,
         editing: true,
         draft: draft,
         local_errors: local_errors,
         validation_errors: nil
       )}
    else
      save_valid_draft(socket, draft)
    end
  end

  defp save_valid_draft(socket, draft) do
    case socket.assigns.availability_context.replace_own_configuration(
           socket.assigns.principal,
           draft_to_attributes(draft)
         ) do
      {:ok, configuration} ->
        {:noreply,
         assign(socket,
           configuration: configuration,
           editing: false,
           draft: nil,
           local_errors: %{},
           copy_source: nil,
           copy_targets: [],
           feedback: :saved,
           validation_errors: nil
         )}

      {:error, {:validation, errors}} ->
        {:noreply,
         assign(socket,
           editing: true,
           draft: draft,
           feedback: nil,
           validation_errors: errors
         )}

      {:error, _reason} ->
        {:noreply,
         assign(socket,
           feedback: :unavailable,
           editing: true,
           draft: draft,
           local_errors: %{}
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

      <.alert
        :if={@feedback == :saved}
        id="availability-save-success"
        color="success"
        variant="callout"
        with_icon
      >
        <%= if @persistence_mode == :preview do %>
          <strong>Vista previa actualizada.</strong> Los cambios no se guardan.
        <% else %>
          La disponibilidad se guardó correctamente.
        <% end %>
      </.alert>

      <.alert
        :if={@feedback == :unavailable}
        id="availability-save-error"
        color="danger"
        variant="callout"
        with_icon
      >
        <strong>No se pudo guardar la disponibilidad.</strong>
        El borrador se conserva para que pueda intentarlo nuevamente.
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
                  aria-expanded="false"
                  aria-controls="availability-editor-region"
                >
                  Editar disponibilidad
                </.button>
              </:action>
            </.card_header>
            <.card_content>
              <div id="availability-summary">
                <.day_carousel
                  id="availability-summary-carousel"
                  viewport_id="availability-summary-days"
                >
                  <article
                    :for={{day, label} <- @days}
                    id={"availability-summary-#{day}"}
                    class="w-[85%] shrink-0 snap-start rounded-lg border border-border bg-surface-muted p-4 dark:border-gray-700 dark:bg-gray-800 sm:w-[55%] lg:w-auto"
                    role="listitem"
                  >
                    <h3 class="font-semibold">{label}</h3>
                    <p class="mt-2 text-sm text-text-muted dark:text-gray-300">
                      {windows_summary(Map.fetch!(@configuration.weekly_availability, day))}
                    </p>
                  </article>
                </.day_carousel>
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
          <form
            :if={@editing}
            id="availability-form"
            phx-change="change_availability"
            phx-submit="save_availability"
            phx-target={@myself}
            class="flex flex-col gap-6"
          >
            <.alert
              :if={@validation_errors}
              id="availability-validation-error"
              color="danger"
              variant="callout"
              with_icon
            >
              <strong>No se guardaron los cambios.</strong>
              Revise los siguientes datos:
              <ul class="mt-2 list-disc pl-5">
                <li :for={message <- validation_messages(@validation_errors)}>{message}</li>
              </ul>
            </.alert>

            <section id="availability-section" aria-labelledby="weekly-availability-heading">
              <.card variant="basic">
                <.card_header>
                  <.h2 id="weekly-availability-heading" no_margin>Disponibilidad semanal</.h2>
                  <.text_muted>
                    Cada horario debe respetar el intervalo de Agenda de {@configuration.agenda_interval_minutes} minutos.
                  </.text_muted>
                  <:action>
                    <.button
                      id="edit-availability-button"
                      type="button"
                      color="gray"
                      variant="outline"
                      size="sm"
                      phx-click="cancel_availability"
                      phx-target={@myself}
                      aria-expanded="true"
                      aria-controls="availability-editor-region"
                    >
                      Cerrar edición
                    </.button>
                  </:action>
                </.card_header>
                <.card_content>
                  <.day_carousel
                    id="availability-editor-carousel"
                    viewport_id="availability-editor-days"
                  >
                    <fieldset
                      :for={{day, label} <- @days}
                      id={"availability-day-#{day}"}
                      class="w-[90%] shrink-0 snap-start rounded-lg border border-border bg-surface-muted p-4 dark:border-gray-700 dark:bg-gray-800 sm:w-[60%] lg:w-auto"
                      role="listitem"
                    >
                      <legend class="px-1 font-semibold">{label}</legend>
                      <input
                        type="hidden"
                        name={"availability[weekly_availability][#{day}][_present]"}
                        value="true"
                      />
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
                          <label
                            class="text-sm font-medium"
                            for={"availability-#{day}-#{index}-start"}
                          >
                            Desde
                            <input
                              id={"availability-#{day}-#{index}-start"}
                              class={[
                                "pc-input mt-1",
                                local_time_error?(@local_errors, day, index, :start) &&
                                  "border-danger-500"
                              ]}
                              type="time"
                              step={@configuration.agenda_interval_minutes * 60}
                              name={"availability[weekly_availability][#{day}][#{index}][start]"}
                              value={window.start}
                              aria-invalid={
                                time_input_invalid?(
                                  @local_errors,
                                  @validation_errors,
                                  day,
                                  index,
                                  :start
                                ) && "true"
                              }
                              aria-describedby={
                                time_input_described_by(
                                  @local_errors,
                                  @validation_errors,
                                  day,
                                  index,
                                  :start
                                )
                              }
                              required
                            />
                            <p
                              :if={message = local_time_error(@local_errors, day, index, :start)}
                              id={"availability-#{day}-#{index}-start-error"}
                              class="mt-1 text-sm text-danger-600 dark:text-danger-400"
                            >
                              {message}
                            </p>
                          </label>
                          <label class="text-sm font-medium" for={"availability-#{day}-#{index}-end"}>
                            Hasta
                            <input
                              id={"availability-#{day}-#{index}-end"}
                              class={[
                                "pc-input mt-1",
                                local_time_error?(@local_errors, day, index, :end) &&
                                  "border-danger-500"
                              ]}
                              type="time"
                              step={@configuration.agenda_interval_minutes * 60}
                              name={"availability[weekly_availability][#{day}][#{index}][end]"}
                              value={window.end}
                              aria-invalid={
                                time_input_invalid?(
                                  @local_errors,
                                  @validation_errors,
                                  day,
                                  index,
                                  :end
                                ) && "true"
                              }
                              aria-describedby={
                                time_input_described_by(
                                  @local_errors,
                                  @validation_errors,
                                  day,
                                  index,
                                  :end
                                )
                              }
                              required
                            />
                            <p
                              :if={message = local_time_error(@local_errors, day, index, :end)}
                              id={"availability-#{day}-#{index}-end-error"}
                              class="mt-1 text-sm text-danger-600 dark:text-danger-400"
                            >
                              {message}
                            </p>
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
                              aria-label={"Eliminar horario #{index + 1} de #{label}"}
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
                  </.day_carousel>

                  <fieldset
                    id="availability-copy-action"
                    class="mt-6 rounded-lg border border-border bg-surface-muted p-4 dark:border-gray-700 dark:bg-gray-800"
                  >
                    <legend class="px-1 font-semibold">Copiar horarios</legend>
                    <p class="mb-4 text-sm text-text-muted dark:text-gray-300">
                      Copia todos los horarios de un día a los días seleccionados. Esta selección no se guarda como grupo.
                    </p>
                    <div class="grid gap-4 md:grid-cols-[minmax(12rem,16rem)_1fr]">
                      <label class="font-medium" for="availability-copy-source">
                        Día de origen
                        <select
                          id="availability-copy-source"
                          class="pc-select mt-1"
                          name="copy[source]"
                        >
                          <option
                            :for={{day, label} <- @days}
                            value={day}
                            selected={day == @copy_source}
                          >
                            {label}
                          </option>
                        </select>
                      </label>
                      <fieldset>
                        <legend class="font-medium">Días de destino</legend>
                        <div class="mt-2 flex flex-wrap gap-x-5 gap-y-3">
                          <label
                            :for={{day, label} <- @days}
                            :if={day != @copy_source}
                            class="inline-flex items-center gap-2"
                            for={"availability-copy-#{day}"}
                          >
                            <input
                              id={"availability-copy-#{day}"}
                              type="checkbox"
                              name="copy[targets][]"
                              value={day}
                              checked={day in @copy_targets}
                            />
                            {label}
                          </label>
                        </div>
                      </fieldset>
                    </div>
                    <div class="mt-4">
                      <.button
                        type="button"
                        color="secondary"
                        variant="outline"
                        phx-click="copy_availability_day"
                        phx-target={@myself}
                        disabled={@copy_targets == []}
                      >
                        Copiar horarios
                      </.button>
                    </div>
                  </fieldset>

                  <div id="booking-rules-editor" class="mt-6 border-t border-border pt-6">
                    <h3 class="font-semibold text-text dark:text-gray-100">Período de reserva</h3>
                    <div class="mt-4 grid gap-5 sm:grid-cols-2">
                      <label class="font-medium" for="booking-horizon-days">
                        Anticipación máxima en días
                        <input
                          id="booking-horizon-days"
                          class="pc-input mt-1"
                          type="number"
                          min="7"
                          max="90"
                          step="1"
                          name="availability[booking_horizon_days]"
                          value={@draft.booking_horizon_days}
                          aria-invalid={
                            invalid_field?(@validation_errors, :booking_horizon_days) && "true"
                          }
                          aria-describedby={
                            invalid_field?(@validation_errors, :booking_horizon_days) &&
                              "availability-validation-error"
                          }
                          required
                        />
                      </label>
                      <label class="font-medium" for="minimum-lead-minutes">
                        Anticipación mínima en minutos
                        <input
                          id="minimum-lead-minutes"
                          class="pc-input mt-1"
                          type="number"
                          min="0"
                          max="1440"
                          step="5"
                          name="availability[minimum_lead_minutes]"
                          value={@draft.minimum_lead_minutes}
                          aria-invalid={
                            invalid_field?(@validation_errors, :minimum_lead_minutes) && "true"
                          }
                          aria-describedby={
                            invalid_field?(@validation_errors, :minimum_lead_minutes) &&
                              "availability-validation-error"
                          }
                          required
                        />
                      </label>
                    </div>
                  </div>
                </.card_content>
                <.card_footer>
                  <div id="availability-form-actions" class="flex w-full flex-wrap justify-end gap-3">
                    <.button
                      type="button"
                      color="gray"
                      variant="outline"
                      phx-click="cancel_availability"
                      phx-target={@myself}
                    >
                      Cancelar
                    </.button>
                    <.button
                      id="availability-save-button"
                      type="submit"
                      color="primary"
                      disabled={map_size(@local_errors) > 0}
                    >
                      Guardar disponibilidad
                    </.button>
                  </div>
                </.card_footer>
              </.card>
            </section>
          </form>
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

      <script :type={Phoenix.LiveView.ColocatedHook} name=".AvailabilityCarousel">
        export default {
          mounted() {
            this.viewport = this.el.querySelector("[data-carousel-viewport]")
            this.handlers = []

            this.el.querySelectorAll("[data-carousel-direction]").forEach(button => {
              const handler = () => this.move(button.dataset.carouselDirection)
              button.addEventListener("click", handler)
              this.handlers.push([button, handler])
            })
          },

          destroyed() {
            this.handlers.forEach(([button, handler]) => button.removeEventListener("click", handler))
          },

          move(direction) {
            const cards = Array.from(this.viewport.children)
            if (cards.length === 0) return

            const currentIndex = cards.reduce((closestIndex, card, index) => {
              const currentDistance = Math.abs(cards[closestIndex].offsetLeft - this.viewport.scrollLeft)
              const candidateDistance = Math.abs(card.offsetLeft - this.viewport.scrollLeft)
              return candidateDistance < currentDistance ? index : closestIndex
            }, 0)

            const delta = direction === "next" ? 1 : -1
            const targetIndex = Math.min(Math.max(currentIndex + delta, 0), cards.length - 1)

            cards[targetIndex].scrollIntoView({behavior: "smooth", block: "nearest", inline: "start"})
          }
        }
      </script>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :viewport_id, :string, required: true
  slot :inner_block, required: true

  defp day_carousel(assigns) do
    ~H"""
    <div id={@id} phx-hook=".AvailabilityCarousel">
      <div class="mb-3 flex justify-end gap-2 lg:hidden" aria-label="Navegación por días">
        <button
          type="button"
          class="inline-flex size-10 items-center justify-center rounded-md border border-border bg-surface text-lg font-semibold text-text-muted dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300"
          data-carousel-direction="previous"
          aria-label="Ver día anterior"
          aria-controls={@viewport_id}
        >
          <span aria-hidden="true">←</span>
        </button>
        <button
          type="button"
          class="inline-flex size-10 items-center justify-center rounded-md border border-border bg-surface text-lg font-semibold text-text-muted dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300"
          data-carousel-direction="next"
          aria-label="Ver día siguiente"
          aria-controls={@viewport_id}
        >
          <span aria-hidden="true">→</span>
        </button>
      </div>
      <div
        id={@viewport_id}
        data-carousel-viewport
        role="list"
        class="flex touch-pan-x snap-x snap-mandatory gap-4 overflow-x-auto pb-3 lg:grid lg:grid-cols-2 lg:overflow-visible lg:pb-0 xl:grid-cols-3"
      >
        {render_slot(@inner_block)}
      </div>
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

  defp params_to_draft(params) do
    week_params = Map.get(params, "weekly_availability", %{})

    week =
      Map.new(@days, fn {day, _label} ->
        day_params = Map.get(week_params, Atom.to_string(day), %{})

        windows =
          day_params
          |> Enum.reject(fn {key, _value} -> key == "_present" end)
          |> Enum.sort_by(fn {key, _value} -> parse_index(key) end)
          |> Enum.map(fn {_key, window} ->
            %{start: Map.get(window, "start", ""), end: Map.get(window, "end", "")}
          end)

        {day, windows}
      end)

    %{
      weekly_availability: week,
      booking_horizon_days: Map.get(params, "booking_horizon_days", ""),
      minimum_lead_minutes: Map.get(params, "minimum_lead_minutes", "")
    }
  end

  defp draft_to_attributes(draft) do
    %{
      weekly_availability: draft.weekly_availability,
      booking_horizon_days: parse_integer(draft.booking_horizon_days),
      minimum_lead_minutes: parse_integer(draft.minimum_lead_minutes)
    }
  end

  defp update_draft_day(socket, day, update_windows) do
    draft = socket.assigns.draft
    windows = draft.weekly_availability |> Map.fetch!(day) |> update_windows.()
    week = Map.put(draft.weekly_availability, day, windows)
    updated_draft = %{draft | weekly_availability: week}

    assign(socket,
      draft: updated_draft,
      local_errors: local_time_errors(updated_draft, socket.assigns.configuration)
    )
  end

  defp day_atom(day_name) do
    case Enum.find(@days, fn {day, _label} -> Atom.to_string(day) == day_name end) do
      {day, _label} -> {:ok, day}
      nil -> :error
    end
  end

  defp copy_selection(params, socket) do
    source =
      case day_atom(Map.get(params, "source", "")) do
        {:ok, day} -> day
        :error -> socket.assigns.copy_source
      end

    targets =
      params
      |> Map.get("targets", [])
      |> List.wrap()
      |> Enum.flat_map(fn day_name ->
        case day_atom(day_name) do
          {:ok, ^source} -> []
          {:ok, day} -> [day]
          :error -> []
        end
      end)
      |> Enum.uniq()

    {source, targets}
  end

  defp format_minutes(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    String.pad_leading(Integer.to_string(hours), 2, "0") <>
      ":" <>
      String.pad_leading(Integer.to_string(remaining_minutes), 2, "0")
  end

  defp parse_index(value) do
    case Integer.parse(value) do
      {index, ""} -> index
      _invalid -> 1_000_000
    end
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _invalid -> value
    end
  end

  defp parse_integer(value), do: value

  defp availability do
    Application.get_env(:origen, :availability_context, Availability)
  end

  defp invalid_day?(%{weekly_availability: day_errors}, day) when is_map(day_errors),
    do: Map.has_key?(day_errors, day)

  defp invalid_day?(_errors, _day), do: false

  defp invalid_field?(errors, field) when is_map(errors), do: Map.has_key?(errors, field)
  defp invalid_field?(_errors, _field), do: false

  defp local_time_errors(draft, configuration) do
    interval = configuration.agenda_interval_minutes

    Enum.reduce(@days, %{}, fn {day, _label}, errors ->
      draft.weekly_availability
      |> Map.fetch!(day)
      |> Enum.with_index()
      |> Enum.reduce(errors, fn {window, index}, field_errors ->
        validate_local_window(field_errors, day, index, window, interval)
      end)
    end)
  end

  defp validate_local_window(errors, day, index, window, interval) do
    start_result = validate_time_boundary(window.start, interval)
    end_result = validate_time_boundary(window.end, interval)

    errors
    |> put_time_error(day, index, :start, start_result, interval)
    |> put_time_error(day, index, :end, end_result, interval)
    |> put_window_order_error(day, index, start_result, end_result, interval)
  end

  defp validate_time_boundary(value, interval) do
    case parse_time_minutes(value) do
      {:ok, minutes} when rem(minutes, interval) == 0 -> {:ok, minutes}
      {:ok, _minutes} -> :misaligned
      :error -> :invalid
    end
  end

  defp parse_time_minutes(value) when is_binary(value) do
    case Regex.run(~r/\A([01]\d|2[0-3]):([0-5]\d)\z/, value) do
      [_, hours, minutes] ->
        {:ok, String.to_integer(hours) * 60 + String.to_integer(minutes)}

      nil ->
        :error
    end
  end

  defp parse_time_minutes(_value), do: :error

  defp put_time_error(errors, _day, _index, _boundary, {:ok, _minutes}, _interval),
    do: errors

  defp put_time_error(errors, day, index, boundary, :misaligned, interval) do
    Map.put(
      errors,
      {day, index, boundary},
      "Debe coincidir con intervalos de #{interval} minutos."
    )
  end

  defp put_time_error(errors, day, index, boundary, :invalid, _interval) do
    Map.put(errors, {day, index, boundary}, "Ingrese una hora válida.")
  end

  defp put_window_order_error(errors, day, index, {:ok, start}, {:ok, finish}, interval) do
    cond do
      finish <= start ->
        Map.put(errors, {day, index, :end}, "Debe ser posterior a la hora de inicio.")

      finish - start < interval ->
        Map.put(errors, {day, index, :end}, "Debe abarcar al menos un intervalo de Agenda.")

      true ->
        errors
    end
  end

  defp put_window_order_error(errors, _day, _index, _start, _finish, _interval), do: errors

  defp local_time_error(errors, day, index, boundary),
    do: Map.get(errors, {day, index, boundary})

  defp local_time_error?(errors, day, index, boundary),
    do: Map.has_key?(errors, {day, index, boundary})

  defp time_input_invalid?(local_errors, validation_errors, day, index, boundary) do
    local_time_error?(local_errors, day, index, boundary) ||
      invalid_day?(validation_errors, day)
  end

  defp time_input_described_by(local_errors, validation_errors, day, index, boundary) do
    cond do
      local_time_error?(local_errors, day, index, boundary) ->
        "availability-#{day}-#{index}-#{boundary}-error"

      invalid_day?(validation_errors, day) ->
        "availability-validation-error"

      true ->
        nil
    end
  end

  defp validation_messages(errors) do
    day_messages =
      case Map.get(errors, :weekly_availability) do
        day_errors when is_map(day_errors) ->
          Enum.flat_map(@days, fn {day, label} ->
            case Map.fetch(day_errors, day) do
              {:ok, reason} -> [day_validation_message(label, reason)]
              :error -> []
            end
          end)

        nil ->
          []

        _reason ->
          ["Disponibilidad semanal: revise los siete días."]
      end

    day_messages
    |> maybe_add_message(
      errors,
      :booking_horizon_days,
      "Período de reserva: ingrese entre 7 y 90 días."
    )
    |> maybe_add_message(
      errors,
      :minimum_lead_minutes,
      "Anticipación mínima: ingrese entre 0 y 1.440 minutos, en pasos de 5."
    )
  end

  defp maybe_add_message(messages, errors, field, message) do
    if Map.has_key?(errors, field), do: messages ++ [message], else: messages
  end

  defp day_validation_message(label, :overlap),
    do: "#{label}: los horarios se superponen."

  defp day_validation_message(label, reason)
       when reason in [:invalid_time, :invalid_window, :invalid_windows],
       do: "#{label}: ingrese horarios válidos en formato HH:MM."

  defp day_validation_message(label, :overnight_or_empty),
    do: "#{label}: el horario de fin debe ser posterior al inicio y dentro del mismo día."

  defp day_validation_message(label, :misaligned),
    do: "#{label}: los límites deben coincidir con el intervalo de Agenda."

  defp day_validation_message(label, :too_short),
    do: "#{label}: cada horario debe durar al menos un intervalo de Agenda."

  defp day_validation_message(label, _reason), do: "#{label}: revise los horarios."
end
