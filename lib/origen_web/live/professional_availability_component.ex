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
