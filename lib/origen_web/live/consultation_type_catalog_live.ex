defmodule OrigenWeb.ConsultationTypeCatalogLive do
  use OrigenWeb, :live_view

  on_mount {OrigenWeb.InternalAuthLive, :ensure_professional}

  alias Origen.ConsultationTypes
  alias OrigenWeb.TimeGrid

  @interval_options Enum.map(5..240//5, &{"#{&1} minutos", &1})
  @availability_days [
    {:monday, "Lunes"},
    {:tuesday, "Martes"},
    {:wednesday, "Miércoles"},
    {:thursday, "Jueves"},
    {:friday, "Viernes"},
    {:saturday, "Sábado"},
    {:sunday, "Domingo"}
  ]
  @type_form_defaults %{
    "name" => "",
    "currency" => "ARS",
    "exact_price_ars" => "",
    "color" => "#0A7C86",
    "interval_count" => "1"
  }
  @ars_price_pattern ~r/^(?<sign>-?)(?<whole>(?:0|[1-9]\d*|[1-9]\d{0,2}(?:\.\d{3})+))(?:,(?<fraction>\d+))?$/

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Configuración",
        current_interval: nil,
        selected_interval: nil,
        interval_options: @interval_options,
        interval_feedback: nil,
        show_inactive: false,
        type_modal_open: false,
        editing_type_id: nil,
         type_form_params: @type_form_defaults,
         type_form_errors: %{},
         reactivation_feedback: nil,
          interval_review: nil,
          interval_review_copy_source: nil,
          interval_review_copy_targets: [],
          interval_modal_open: false,
          interval_modal_step: :warning,
          availability_editing: false,
          availability_dirty: false
      )

    case consultation_types().get_own_configuration(socket.assigns.current_internal_session) do
      {:ok, configuration} ->
        {:ok,
         assign(socket,
           catalog: configuration.consultation_types,
           current_interval: configuration.agenda_interval_minutes,
           selected_interval: configuration.agenda_interval_minutes,
           catalog_error: nil
         )}

      {:error, _reason} ->
        {:ok, assign(socket, catalog: [], catalog_error: :unavailable)}
    end
  end

  @impl true
  def handle_event("toggle_inactive", %{"show_inactive" => show_inactive}, socket) do
    {:noreply, assign(socket, show_inactive: show_inactive == "true")}
  end

  @impl true
  def handle_event("select_interval", %{"interval_minutes" => interval}, socket) do
    case parse_interval(interval) do
      {:ok, selected_interval} ->
        {:noreply,
         assign(socket,
            selected_interval: selected_interval,
             interval_feedback: nil,
             interval_review: nil,
             interval_review_copy_source: nil,
             interval_review_copy_targets: [],
             interval_modal_open: false,
             interval_modal_step: :warning,
             reactivation_feedback: nil
         )}

      :error ->
        {:noreply, assign(socket, interval_feedback: :invalid)}
    end
  end

  @impl true
  def handle_event("apply_interval", %{"interval_minutes" => interval}, socket) do
    case consultation_types().apply_agenda_interval(
           socket.assigns.current_internal_session,
           interval
         ) do
      {:error, {:confirmation_required, preview}} ->
        {:noreply,
         socket
         |> assign(
           selected_interval:
             parsed_interval_or_current(interval, socket.assigns.current_interval),
           interval_feedback: nil,
           interval_review: preview,
           reactivation_feedback: nil
         )}

      {:error, {:validation, _errors}} ->
        {:noreply, assign(socket, interval_feedback: :invalid)}

      {:error, reason} when reason in [:unauthorized, :unavailable] ->
        {:noreply, assign(socket, interval_feedback: :unavailable)}

      _unexpected ->
        {:noreply, assign(socket, interval_feedback: :unavailable)}
    end
  end

  def handle_event("apply_interval", _params, socket) do
    {:noreply, assign(socket, interval_feedback: :invalid)}
  end

  @impl true
  def handle_event("open_interval_change", _params, socket) do
    if socket.assigns.availability_dirty do
      {:noreply,
       assign(socket,
         interval_feedback: :availability_dirty,
         interval_modal_open: false,
         interval_review: nil
       )}
    else
      {:noreply,
       assign(socket,
         interval_feedback: nil,
         interval_modal_open: true,
         interval_modal_step: :warning,
         interval_review: nil,
         interval_review_copy_source: nil,
         interval_review_copy_targets: []
       )}
    end
  end

  @impl true
  def handle_event("review_agenda_interval", _params, socket) do
    {:noreply,
     socket
     |> load_interval_review(nil)
     |> assign(interval_modal_step: :review)}
  end

  @impl true
  def handle_event("cancel_interval_change", _params, socket) do
    {:noreply,
     assign(socket,
       selected_interval: socket.assigns.current_interval,
       interval_feedback: nil,
       interval_review: nil,
       interval_modal_open: false,
       interval_modal_step: :warning
     )}
  end

  def handle_event("cancel_interval_warning", params, socket),
    do: handle_event("cancel_interval_change", params, socket)

  @impl true
  def handle_event("change_interval_review", %{"interval_review" => params} = all_params, socket)
      when is_map(params) do
    case Map.fetch(all_params, "interval_review_copy") do
      :error ->
        {:noreply, load_interval_review(socket, interval_review_attributes(params, socket))}

      {:ok, copy_params} when is_map(copy_params) ->
        socket = update_interval_review_copy(socket, copy_params)
        {:noreply, load_interval_review(socket, interval_review_attributes(params, socket))}

      _malformed ->
        {:noreply, socket}
    end
  end

  def handle_event("change_interval_review", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("add_interval_review_window", %{"day" => day_name}, socket) do
    with {:ok, day} <- availability_day(day_name),
         %{reviewed_availability: availability} <- socket.assigns.interval_review do
      window = %{start: "00:00", end: format_interval_time(socket.assigns.selected_interval)}
      week = Map.update!(availability.weekly_availability, day, &(&1 ++ [window]))
      {:noreply, load_interval_review(socket, availability_attrs(availability, week))}
    else
      _invalid -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "remove_interval_review_window",
        %{"day" => day_name, "index" => index_text},
        socket
      ) do
    with {:ok, day} <- availability_day(day_name),
         {index, ""} when index >= 0 <- Integer.parse(index_text),
         %{reviewed_availability: availability} <- socket.assigns.interval_review do
      week = Map.update!(availability.weekly_availability, day, &List.delete_at(&1, index))
      {:noreply, load_interval_review(socket, availability_attrs(availability, week))}
    else
      _invalid -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("copy_interval_review_hours", _params, socket) do
    with source when not is_nil(source) <- socket.assigns.interval_review_copy_source,
         %{reviewed_availability: availability} <- socket.assigns.interval_review do
      source_windows = Map.fetch!(availability.weekly_availability, source)

      week =
        Enum.reduce(
          socket.assigns.interval_review_copy_targets,
          availability.weekly_availability,
          &Map.put(&2, &1, source_windows)
        )

      {:noreply, load_interval_review(socket, availability_attrs(availability, week))}
    else
      _invalid -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_interval_review", %{"interval_review" => params}, socket) do
    reviewed_availability = interval_review_attributes(params, socket)

    case consultation_types().confirm_agenda_interval(
           socket.assigns.current_internal_session,
           %{
             proposed_interval_minutes: socket.assigns.selected_interval,
             reviewed_availability: reviewed_availability,
             stale_token: socket.assigns.interval_review.stale_token
           }
         ) do
      {:ok, configuration} ->
        send_update(OrigenWeb.ProfessionalAvailabilityComponent,
          id: "professional-availability",
          refresh_after_interval_change: true
        )

        {:noreply,
         socket
         |> assign_configuration(configuration)
         |> assign(
           interval_feedback: :applied,
           interval_review: nil,
           interval_review_copy_source: nil,
           interval_review_copy_targets: [],
           interval_modal_open: false,
           interval_modal_step: :warning,
           reactivation_feedback: nil,
           availability_editing: false,
           availability_dirty: false
         )}

      {:error, :stale} ->
        {:noreply, assign(socket, interval_feedback: :stale)}

      {:error, {:validation, errors}} ->
        review = Map.put(socket.assigns.interval_review, :availability_validation_errors, errors)
        {:noreply, assign(socket, interval_feedback: :validation, interval_review: review)}

      {:error, {:future_appointment_conflicts, conflicts}} ->
        review = Map.put(socket.assigns.interval_review, :future_appointment_conflicts, conflicts)
        {:noreply, assign(socket, interval_feedback: :future_conflicts, interval_review: review)}

      {:error, {:incompatible, _evidence}} ->
        {:noreply, assign(socket, interval_feedback: :incompatible_review)}

      {:error, _reason} ->
        {:noreply, assign(socket, interval_feedback: :unavailable)}
    end
  end

  def handle_event("confirm_interval_review", _params, socket) do
    {:noreply, assign(socket, interval_feedback: :validation)}
  end

  @impl true
  def handle_event("open_new_type", _params, socket) do
    {:noreply,
     assign(socket,
       type_modal_open: true,
       editing_type_id: nil,
       type_form_params: @type_form_defaults,
       type_form_errors: %{}
     )}
  end

  @impl true
  def handle_event("open_edit_type", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.catalog, &(&1.id == id and &1.status == :active)) do
      nil ->
        {:noreply, socket}

      consultation_type ->
        {:noreply,
         assign(socket,
           type_modal_open: true,
           editing_type_id: consultation_type.id,
           type_form_params: edit_type_form_params(consultation_type),
           type_form_errors: %{}
         )}
    end
  end

  def handle_event("open_edit_type", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("change_type", %{"consultation_type" => params}, socket) do
    {:noreply,
     assign(socket,
       type_form_params: type_form_params(params),
       type_form_errors: %{}
     )}
  end

  @impl true
  def handle_event("save_type", %{"consultation_type" => params}, socket) do
    params = type_form_params(params)

    case validate_type_form(params, socket.assigns.current_interval) do
      {:ok, attributes} ->
        {:noreply, save_type(socket, attributes)}

      {:error, errors} ->
        {:noreply,
         assign(socket,
           type_modal_open: true,
           type_form_params: params,
           type_form_errors: errors
         )}
    end
  end

  @impl true
  def handle_event("cancel_type", _params, socket) do
    {:noreply, reset_type_form(socket)}
  end

  @impl true
  def handle_event("cancel_deactivate_type", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("deactivate_type", %{"id" => id}, socket) when is_binary(id) do
    case consultation_types().deactivate_type(socket.assigns.current_internal_session, id) do
      {:ok, _consultation_type} ->
        {:noreply, reload_configuration(socket)}

      {:error, :not_found} ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, assign(socket, catalog_error: :unavailable)}
    end
  end

  def handle_event("deactivate_type", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("reactivate_type", %{"id" => id}, socket) when is_binary(id) do
    case consultation_types().reactivate_type(socket.assigns.current_internal_session, id) do
      {:ok, _consultation_type} ->
        {:noreply,
         socket
         |> reload_configuration()
         |> assign(reactivation_feedback: nil)}

      {:error, :not_found} ->
        {:noreply, socket}

      {:error, {:incompatible, %{name: name, prospective_duration_minutes: duration_minutes}}} ->
        {:noreply, assign(socket, reactivation_feedback: {:incompatible, name, duration_minutes})}

      {:error, _reason} ->
        {:noreply, assign(socket, catalog_error: :unavailable)}
    end
  end

  def handle_event("reactivate_type", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:availability_editor_state, state}, socket) do
    interval_feedback =
      if not state.dirty and socket.assigns.interval_feedback == :availability_dirty,
        do: nil,
        else: socket.assigns.interval_feedback

    {:noreply,
     assign(socket,
       availability_editing: state.editing,
       availability_dirty: state.dirty,
       interval_feedback: interval_feedback
     )}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, visible_catalog: visible_catalog(assigns))

    ~H"""
    <main data-theme="light" class="min-h-screen bg-page py-6 text-text sm:py-10">
      <.container max_width="xl">
        <div
          id="professional-settings-content"
          class="flex flex-col gap-6 sm:gap-8"
          inert={@interval_modal_open}
        >
          <header
            id="professional-settings-header"
            class="flex items-start justify-between gap-4"
          >
            <div class="space-y-2">
              <.h1 no_margin>Ajustes</.h1>

              <.text_muted>
                Preferencias operativas de la práctica profesional.
              </.text_muted>
            </div>

            <.button
              id="back-to-agenda-button"
              type="button"
              icon="hero-arrow-left"
              color="gray"
              variant="outline"
              disabled
              aria-disabled="true"
            >
              Volver a Agenda
            </.button>
          </header>

          <.alert
            :if={@catalog_error}
            id="configuration-load-error"
            color="danger"
            variant="callout"
            with_icon
          >
            <strong>No se pudo cargar la configuración.</strong>
            No se muestra información parcial. Los datos deben estar disponibles antes de continuar.
          </.alert>

          <div :if={is_nil(@catalog_error)} class="flex flex-col gap-6 sm:gap-8">
            <section aria-labelledby="agenda-interval-heading">
              <.card variant="basic">
                <.card_header>
                  <.h2 id="agenda-interval-heading" no_margin>Intervalo de Agenda</.h2>

                  <.text_muted>
                    Unidad de tiempo utilizada para organizar la agenda profesional.
                  </.text_muted>
                </.card_header>

                <.card_content class="flex flex-col gap-6">
                  <dl class="grid gap-1 sm:grid-cols-[12rem_1fr] sm:items-baseline sm:gap-4">
                    <dt class="font-medium">Intervalo aplicado</dt>

                    <dd id="current-agenda-interval" class="font-semibold">
                      {@current_interval} minutos
                    </dd>
                  </dl>

                  <form
                    id="agenda-interval-form"
                    phx-change="select_interval"
                    class="flex flex-col gap-4 sm:max-w-xl"
                  >
                    <.field
                      id="agenda-interval-select"
                      type="select"
                      name="interval_minutes"
                      label="Nuevo intervalo"
                      value={@selected_interval}
                      options={@interval_options}
                      help_text="Valores permitidos: de 5 a 240 minutos, en pasos de 5."
                      no_margin
                    />
                    <.alert
                      :if={@interval_feedback == :availability_dirty}
                      id="interval-availability-draft-warning"
                      color="warning"
                      variant="callout"
                      with_icon
                    >
                      <strong>Hay cambios de disponibilidad sin guardar.</strong>
                      Guarde o cancele ese borrador antes de cambiar el intervalo de la agenda.
                    </.alert>

                    <.alert
                      :if={@interval_feedback == :applied}
                      id="interval-apply-success"
                      color="success"
                      variant="callout"
                      with_icon
                    >
                      El intervalo se aplicó correctamente. Las cantidades se conservaron y se recalcularon las duraciones de los tipos activos.
                    </.alert>

                    <.alert
                      :if={@interval_feedback == :invalid}
                      id="interval-apply-error"
                      color="danger"
                      variant="callout"
                      with_icon
                    >
                      <strong>No se aplicó el intervalo.</strong>
                      El valor debe estar entre 5 y 240 minutos y ser divisible por 5.
                    </.alert>

                    <div>
                      <.button
                        :if={@selected_interval != @current_interval}
                        id="open-interval-change-modal"
                        type="button"
                        color="primary"
                        phx-click="open_interval_change"
                      >
                        Revisar cambios
                      </.button>
                      <.button
                        :if={@selected_interval == @current_interval}
                        type="button"
                        color="primary"
                        disabled
                      >
                        Revisar cambios
                      </.button>
                    </div>
                  </form>
                </.card_content>
              </.card>
            </section>

            <.live_component
              module={OrigenWeb.ProfessionalAvailabilityComponent}
              id="professional-availability"
              principal={@current_internal_session}
            />

            <section aria-labelledby="consultation-types-heading">
              <.card variant="basic">
                <.card_header>
                  <.h2 id="consultation-types-heading" no_margin>Tipos de consulta</.h2>

                  <:action>
                    <.button
                      color="primary"
                      size="sm"
                      icon="hero-plus"
                      phx-click="open_new_type"
                    >
                      Nuevo tipo de consulta
                    </.button>
                  </:action>
                </.card_header>

                <.card_content class="flex flex-col gap-4">
                  <.reactivation_alert
                    :if={match?({:incompatible, _, _}, @reactivation_feedback)}
                    feedback={@reactivation_feedback}
                  />
                  <form id="consultation-types-filter" phx-change="toggle_inactive">
                    <.field
                      id="show-inactive-consultation-types"
                      type="checkbox"
                      name="show_inactive"
                      label="Mostrar consultas inactivas"
                      checked={@show_inactive}
                      no_margin
                    />
                  </form>

                  <div
                    id="consultation-types-table-view"
                    class="hidden md:block"
                    aria-label="Vista de tabla del catálogo"
                  >
                    <.table
                      rows={@visible_catalog}
                      row_id={&"consultation-type-#{&1.id}"}
                      density="compact"
                      variant="basic"
                      striped
                    >
                      <:col :let={type} label="Nombre">
                        <span class="inline-flex items-center gap-2">
                          <.color_swatch color={type.color} name={type.name} />
                          <span>{type.name}</span>
                        </span>
                      </:col>

                      <:col :let={type} label="Cantidad de intervalos">
                        <span class="sr-only">Cantidad de intervalos </span>{type.interval_count}
                      </:col>

                      <:col :let={type} label="Duración">
                        Duración: {duration_minutes(type, @current_interval)} minutos
                      </:col>

                      <:col :let={type} label="Precio">{format_ars(type.exact_price_ars)}</:col>

                      <:col :let={type} label="Estado">
                        <.status_badge status={type.status} />
                      </:col>

                      <:col :let={type} label="Acciones">
                        <.prepared_actions type={type} presentation="desktop" />
                      </:col>
                    </.table>
                  </div>

                  <div
                    id="consultation-types-mobile-view"
                    class="grid gap-4 md:hidden"
                    role="list"
                    aria-label="Vista móvil del catálogo"
                  >
                    <article
                      :for={type <- @visible_catalog}
                      id={"consultation-type-mobile-#{type.id}"}
                      role="listitem"
                      aria-label={"Tipo de consulta #{type.name}"}
                    >
                      <.card variant="muted">
                        <.card_header>
                          <span class="inline-flex items-center gap-2 font-semibold">
                            <.color_swatch color={type.color} name={type.name} />
                            <span>{type.name}</span>
                          </span>

                          <:action>
                            <.status_badge status={type.status} />
                          </:action>
                        </.card_header>

                        <.card_content>
                          <dl class="grid grid-cols-[1fr_auto] gap-x-4 gap-y-3 text-sm">
                            <dt class="font-medium">Cantidad de intervalos</dt>

                            <dd class="text-right">{type.interval_count}</dd>

                            <dt class="font-medium">Duración</dt>

                            <dd class="text-right">
                              Duración: {duration_minutes(type, @current_interval)} minutos
                            </dd>

                            <dt class="font-medium">Precio</dt>

                            <dd class="text-right font-semibold">
                              {format_ars(type.exact_price_ars)}
                            </dd>
                          </dl>
                        </.card_content>

                        <.card_footer>
                          <.prepared_actions type={type} presentation="mobile" />
                        </.card_footer>
                      </.card>
                    </article>
                  </div>

                  <%= for type <- @catalog do %>
                    <.alert_dialog
                      :if={type.status == :active}
                      id={deactivation_dialog_id(type.id)}
                      title="Desactivar tipo de consulta"
                      description="Los turnos ya reservados con este tipo de consulta se mantendrán sin cambios. Al desactivarlo, dejará de estar disponible únicamente para nuevas reservas."
                      confirm_label="Desactivar"
                      cancel_label="Cancelar"
                      variant="default"
                      on_confirm={JS.push("deactivate_type", value: %{id: type.id})}
                      on_cancel={JS.push("cancel_deactivate_type", value: %{id: type.id})}
                    />
                  <% end %>
                </.card_content>
              </.card>
            </section>
          </div>

          <.modal
            :if={@type_modal_open}
            id="new-consultation-type-modal"
            title={type_modal_title(@editing_type_id)}
            max_width="lg"
            on_cancel={JS.push("cancel_type")}
          >
            <form
              id="new-consultation-type-form"
              phx-change="change_type"
              phx-submit="save_type"
              class="flex flex-col gap-5"
            >
              <.alert
                :if={map_size(@type_form_errors) > 0}
                id="new-consultation-type-errors"
                color="danger"
                variant="callout"
                with_icon
              >
                {type_form_error_summary(@editing_type_id)}
              </.alert>

              <div class="grid gap-5 sm:grid-cols-2">
                <.field
                  id="new-consultation-type-name"
                  type="text"
                  name="consultation_type[name]"
                  label="Nombre"
                  value={@type_form_params["name"]}
                  errors={field_errors(@type_form_errors, :name)}
                  maxlength="32"
                  required
                  aria-invalid={aria_invalid(@type_form_errors, :name)}
                  aria-describedby={error_summary_id(@type_form_errors, :name)}
                  help_text="Máximo de 32 caracteres. Los nombres duplicados están permitidos."
                  no_margin
                />
                <.field_wrapper
                  errors={price_control_errors(@type_form_errors)}
                  name="consultation_type[exact_price_ars]"
                  no_margin
                >
                  <.field_label for="new-consultation-type-price" required>
                    Precio base
                  </.field_label>

                  <.input_group>
                    <:leading>
                      <select
                        id="new-consultation-type-currency"
                        name="consultation_type[currency]"
                        class="pc-select"
                        aria-label="Moneda del precio"
                        aria-invalid={aria_invalid(@type_form_errors, :currency)}
                        aria-describedby={error_summary_id(@type_form_errors, :currency)}
                        required
                      >
                        <option value="ARS" selected={@type_form_params["currency"] == "ARS"}>
                          ARS
                        </option>
                      </select>
                    </:leading>

                    <.input
                      id="new-consultation-type-price"
                      type="text"
                      name="consultation_type[exact_price_ars]"
                      value={@type_form_params["exact_price_ars"]}
                      inputmode="decimal"
                      placeholder="18.000,00"
                      required
                      aria-label="Importe"
                      aria-invalid={aria_invalid(@type_form_errors, :exact_price_ars)}
                      aria-describedby={price_described_by(@type_form_errors, :exact_price_ars)}
                    />
                  </.input_group>

                  <.field_error :for={message <- price_control_errors(@type_form_errors)}>
                    {message}
                  </.field_error>

                  <.field_help_text id="new-consultation-type-price-help">
                    Ingrese un importe no negativo, por ejemplo 18.000,00, con hasta dos decimales.
                  </.field_help_text>
                </.field_wrapper>

                <.field
                  id="new-consultation-type-color"
                  type="color"
                  name="consultation_type[color]"
                  label="Color"
                  value={@type_form_params["color"]}
                  errors={field_errors(@type_form_errors, :color)}
                  required
                  aria-invalid={aria_invalid(@type_form_errors, :color)}
                  aria-describedby={error_summary_id(@type_form_errors, :color)}
                  help_text="Seleccione el color que identificará este tipo de consulta."
                  no_margin
                />
                <.field
                  id="new-consultation-type-count"
                  type="number"
                  name="consultation_type[interval_count]"
                  label="Cantidad de intervalos"
                  value={@type_form_params["interval_count"]}
                  errors={field_errors(@type_form_errors, :interval_count)}
                  min="1"
                  max={effective_maximum(@current_interval)}
                  step="1"
                  inputmode="numeric"
                  required
                  aria-invalid={aria_invalid(@type_form_errors, :interval_count)}
                  aria-describedby={error_summary_id(@type_form_errors, :interval_count)}
                  help_text={
                    "Valores permitidos: de 1 a #{effective_maximum(@current_interval)}."
                  }
                  no_margin
                />
              </div>

              <.field_wrapper no_margin>
                <.field_label for="new-consultation-type-duration">Duración</.field_label>

                <output
                  id="new-consultation-type-duration"
                  for="new-consultation-type-count"
                  class="block rounded-md bg-surface-muted p-4 text-sm font-semibold text-text-muted dark:bg-gray-800 dark:text-gray-200"
                  aria-live="polite"
                >
                  <%= if duration = duration_preview(@type_form_params, @current_interval) do %>
                    {duration} minutos
                  <% else %>
                    —
                  <% end %>
                </output>

                <.field_help_text>
                  Se calcula según la cantidad y el intervalo de Agenda actual de {@current_interval} minutos.
                </.field_help_text>
              </.field_wrapper>
            </form>

            <:footer>
              <.button
                type="button"
                color="gray"
                variant="outline"
                phx-click={JS.push("cancel_type")}
              >
                Cancelar
              </.button>

              <.button type="submit" form="new-consultation-type-form" color="primary">
                {type_submit_label(@editing_type_id)}
              </.button>
            </:footer>
          </.modal>
        </div>

        <.modal
          :if={@interval_modal_open}
          id="agenda-interval-change-modal"
          title="Cambiar el intervalo de la agenda"
          max_width="2xl"
          on_cancel={JS.push("cancel_interval_change")}
          close_on_escape
          close_on_click_away
        >
          <div :if={@interval_modal_step == :warning} id="interval-modal-warning" class="space-y-5">
            <.alert color="warning" variant="callout" with_icon>
              Este cambio afecta las duraciones de los tipos de consulta y la disponibilidad semanal. Nada cambiará antes de la confirmación final.
            </.alert>
            <p class="text-sm text-text-muted dark:text-gray-300">
              Las cantidades de intervalos no cambiarán. Las duraciones de los tipos activos sí se recalcularán. {change_example(
                @catalog,
                @current_interval,
                @selected_interval
              )}
            </p>
            <div class="flex flex-wrap justify-end gap-3">
              <.button
                type="button"
                color="gray"
                variant="outline"
                phx-click="cancel_interval_change"
              >
                Cancelar
              </.button>
              <.button type="button" color="primary" phx-click="review_agenda_interval">
                Revisar cambios
              </.button>
            </div>
          </div>

          <div :if={@interval_modal_step == :review} class="space-y-5">
            <.alert
              :if={@interval_feedback == :stale}
              id="interval-apply-error"
              color="danger"
              variant="callout"
              with_icon
            >
              <strong>No se aplicó el intervalo.</strong>
              La configuración cambió desde la revisión. Vuelva a revisar los efectos antes de confirmar. La configuración cargada continúa visible y no se aplicó ningún efecto de esta propuesta.
            </.alert>

            <.alert
              :if={@interval_feedback in [:validation, :future_conflicts, :incompatible_review]}
              id="interval-apply-error"
              color="danger"
              variant="callout"
              with_icon
            >
              <strong>No se aplicó el intervalo.</strong>
              Revise los bloqueos indicados. La configuración cargada continúa visible y no se aplicó ningún efecto de esta propuesta.
            </.alert>

            <.alert
              :if={@interval_feedback == :unavailable}
              id="interval-apply-error"
              color="danger"
              variant="callout"
              with_icon
            >
              <strong>No se aplicó el intervalo.</strong>
              No se pudo completar la confirmación. La configuración cargada continúa visible y no se aplicó ningún efecto.
            </.alert>

            <.interval_review
              :if={@interval_review}
              review={@interval_review}
              proposed_interval={@selected_interval}
              copy_source={@interval_review_copy_source}
              copy_targets={@interval_review_copy_targets}
            />
            <div class="flex justify-start">
              <.button
                type="button"
                color="gray"
                variant="outline"
                phx-click="cancel_interval_change"
              >
                Cancelar
              </.button>
            </div>
          </div>
        </.modal>
      </.container>
    </main>
    """
  end

  attr :feedback, :any, required: true

  defp reactivation_alert(%{feedback: {:incompatible, name, duration}} = assigns) do
    assigns = assign(assigns, name: name, duration: duration)

    ~H"""
    <.alert id="reactivation-error" color="danger" variant="callout" with_icon>
      <strong>No se reactivó {@name}.</strong>
      Su cantidad preservada produciría una duración de {@duration} minutos, superior al máximo de 240 minutos. El tipo continúa inactivo y no se realizaron cambios.
    </.alert>
    """
  end

  attr :review, :map, required: true
  attr :proposed_interval, :integer, required: true
  attr :copy_source, :atom, default: nil
  attr :copy_targets, :list, default: []

  defp interval_review(assigns) do
    overlap_indexes =
      Map.new(assigns.review.reviewed_availability.weekly_availability, fn {day, windows} ->
        {day, interval_review_overlap_indexes(windows)}
      end)

    assigns = assign(assigns, days: @availability_days, overlap_indexes: overlap_indexes)

    ~H"""
    <section id="agenda-interval-review" class="border-t border-border pt-6" aria-labelledby="agenda-interval-review-heading">
      <.h3 id="agenda-interval-review-heading" no_margin>Revisión del cambio de intervalo</.h3>
      <p class="mt-2 text-sm text-text-muted dark:text-gray-300">
        Revise el resultado completo antes de confirmar. Todavía no se aplicó ningún cambio.
      </p>

      <dl class="mt-4 grid gap-3 sm:grid-cols-2">
        <div><dt class="font-medium">Intervalo actual</dt><dd>{@review.current_interval_minutes} minutos</dd></div>
        <div><dt class="font-medium">Intervalo propuesto</dt><dd>{@review.proposed_interval_minutes} minutos</dd></div>
      </dl>

      <div id="interval-type-effects" class="mt-6">
        <h4 class="font-semibold">Duraciones de tipos de consulta activos</h4>
        <ul class="mt-2 list-disc space-y-1 pl-5">
          <li
            :for={effect <- @review.consultation_type_effects}
            id={"interval-type-effect-#{effect.id}"}
            data-compatible={to_string(effect.compatible)}
            class={not effect.compatible && "text-danger-600 dark:text-danger-400"}
          >
            {effect.name}: {effect.current_duration_minutes} a {effect.proposed_duration_minutes} minutos
            <strong :if={not effect.compatible}>
              Bloqueo: la duración propuesta supera el máximo permitido de 240 minutos.
            </strong>
          </li>
          <li :if={@review.consultation_type_effects == []}>No hay tipos activos afectados.</li>
        </ul>
      </div>

      <div id="interval-boundary-conflicts" class="mt-6">
        <h4 class="font-semibold">Límites semanales incompatibles</h4>
        <ul class="mt-2 list-disc space-y-1 pl-5">
          <li :for={boundary <- @review.incompatible_availability_boundaries}>
            {format_review_boundary(boundary)}
          </li>
          <li :if={@review.incompatible_availability_boundaries == []}>
            Todos los límites coinciden con el intervalo propuesto.
          </li>
        </ul>
      </div>

      <div id="interval-appointment-conflicts" class="mt-6">
        <h4 class="font-semibold">Conflictos con turnos futuros</h4>
        <ul class="mt-2 list-disc space-y-1 pl-5">
          <li :for={conflict <- @review.future_appointment_conflicts}>
            Turno #{conflict.appointment_id}: {Date.to_iso8601(conflict.date)}, {conflict.start_time} a {conflict.end_time}.
          </li>
          <li :if={@review.future_appointment_conflicts == []}>
            No se detectaron conflictos con turnos futuros.
          </li>
        </ul>
      </div>

      <form id="interval-review-form" phx-change="change_interval_review" phx-submit="confirm_interval_review" class="mt-6 space-y-5">
        <input type="hidden" name="interval_review[booking_horizon_days]" value={@review.reviewed_availability.booking_horizon_days} />
        <input type="hidden" name="interval_review[minimum_lead_minutes]" value={@review.reviewed_availability.minimum_lead_minutes} />
        <fieldset id="interval-review-copy-action" class="rounded-lg border border-border p-4 dark:border-gray-700">
          <legend class="px-1 font-semibold">Copiar horarios revisados</legend>
          <p class="mt-1 text-sm text-text-muted dark:text-gray-300">
            Elija un día de origen y uno o más destinos. La copia es temporal hasta la confirmación final.
          </p>
          <div class="mt-3 grid gap-4 lg:grid-cols-2">
            <div>
              <label for="interval-review-copy-source" class="text-sm font-medium">Día de origen</label>
              <select
                id="interval-review-copy-source"
                name="interval_review_copy[source]"
                class="pc-select mt-1"
              >
                <option value="" selected={is_nil(@copy_source)}>Seleccione un día</option>
                <option
                  :for={{day, label} <- @days}
                  value={day}
                  selected={day == @copy_source}
                >
                  {label}
                </option>
              </select>
            </div>
            <fieldset>
              <legend class="text-sm font-medium">Días de destino</legend>
              <div class="mt-2 grid gap-2 sm:grid-cols-2">
                <label :for={{day, label} <- @days} class="flex items-center gap-2 text-sm">
                  <input
                    id={"interval-review-copy-#{day}"}
                    type="checkbox"
                    name="interval_review_copy[targets][]"
                    value={day}
                    checked={day in @copy_targets}
                    disabled={day == @copy_source}
                  />
                  {label}
                </label>
              </div>
            </fieldset>
          </div>
          <div class="mt-4">
            <.button
              id="copy-interval-review-hours"
              type="button"
              color="secondary"
              variant="outline"
              size="sm"
              phx-click="copy_interval_review_hours"
              disabled={is_nil(@copy_source) or @copy_targets == []}
            >
              Copiar horarios revisados
            </.button>
          </div>
        </fieldset>
        <fieldset>
          <legend class="font-semibold">Disponibilidad semanal resultante</legend>
          <p class="mt-1 text-sm text-text-muted dark:text-gray-300">
            Ajuste explícitamente la semana completa en la grilla de {@proposed_interval} minutos. Los horarios no se redondean ni se restablecen automáticamente.
          </p>
          <div class="mt-4 grid gap-4 lg:grid-cols-2">
            <fieldset
              :for={{day, label} <- @days}
              id={"interval-review-day-#{day}"}
              class="rounded-lg border border-border p-4 dark:border-gray-700"
            >
              <legend class="px-1 font-medium">{label}</legend>
              <input type="hidden" name={"interval_review[weekly_availability][#{day}][_present]"} value="true" />
              <p :if={Map.fetch!(@review.reviewed_availability.weekly_availability, day) == []} class="text-sm text-text-muted dark:text-gray-300">
                Sin disponibilidad
              </p>
              <div
                :for={{window, index} <- Enum.with_index(Map.fetch!(@review.reviewed_availability.weekly_availability, day))}
                id={"interval-review-#{day}-#{index}-window"}
                class={[
                  "mb-3 grid grid-cols-2 gap-3 rounded-lg border p-2",
                  if(MapSet.member?(Map.fetch!(@overlap_indexes, day), index),
                    do: "border-danger-500",
                    else: "border-transparent"
                  )
                ]}
                data-overlap-invalid={MapSet.member?(Map.fetch!(@overlap_indexes, day), index) && "true"}
                aria-describedby={MapSet.member?(Map.fetch!(@overlap_indexes, day), index) && "interval-review-#{day}-#{index}-overlap-error"}
              >
                <input
                  type="hidden"
                  name={"interval_review[weekly_availability][#{day}][#{index}][_present]"}
                  value="true"
                />
                <.interval_review_time_select
                  day={day}
                  index={index}
                  boundary={:start}
                  value={window.start}
                  proposed_interval={@proposed_interval}
                  overlap_invalid?={MapSet.member?(Map.fetch!(@overlap_indexes, day), index)}
                />
                <.interval_review_time_select
                  day={day}
                  index={index}
                  boundary={:end}
                  value={window.end}
                  start_value={window.start}
                  proposed_interval={@proposed_interval}
                  overlap_invalid?={MapSet.member?(Map.fetch!(@overlap_indexes, day), index)}
                />
                <p
                  :if={MapSet.member?(Map.fetch!(@overlap_indexes, day), index)}
                  id={"interval-review-#{day}-#{index}-overlap-error"}
                  class="col-span-2 text-sm text-danger-600 dark:text-danger-400"
                >
                  Este horario se superpone con otro horario del {String.downcase(label)}.
                </p>
                <div class="col-span-2">
                  <.button type="button" color="danger" variant="outline" size="xs" phx-click="remove_interval_review_window" phx-value-day={day} phx-value-index={index}>
                    Eliminar horario
                  </.button>
                </div>
              </div>
              <.button type="button" color="secondary" variant="outline" size="xs" phx-click="add_interval_review_window" phx-value-day={day}>
                Agregar horario
              </.button>
            </fieldset>
          </div>
        </fieldset>
        <div class="flex justify-end">
          <.button id="confirm-interval-change" type="submit" color="primary" disabled={interval_review_blocked?(@review)}>
            Confirmar cambio
          </.button>
        </div>
      </form>
    </section>
    """
  end

  attr :day, :atom, required: true
  attr :index, :integer, required: true
  attr :boundary, :atom, values: [:start, :end], required: true
  attr :value, :string, required: true
  attr :start_value, :string, default: nil
  attr :proposed_interval, :integer, required: true
  attr :overlap_invalid?, :boolean, default: false

  defp interval_review_time_select(assigns) do
    options = TimeGrid.options(assigns.proposed_interval, assigns.boundary)
    grid_invalid? = assigns.value not in options
    ordering_invalid? = interval_review_order_invalid?(assigns.start_value, assigns.value)
    invalid? = grid_invalid? or ordering_invalid? or assigns.overlap_invalid?
    id = "interval-review-#{assigns.day}-#{assigns.index}-#{assigns.boundary}"
    label = if(assigns.boundary == :start, do: "Desde", else: "Hasta")
    day_label = Keyword.fetch!(@availability_days, assigns.day)
    grid_error_id = "#{id}-error"
    ordering_error_id = "#{id}-ordering-error"
    overlap_error_id = "interval-review-#{assigns.day}-#{assigns.index}-overlap-error"

    assigns =
      assign(assigns,
        id: id,
        label: label,
        accessible_name:
          "#{day_label}, horario #{assigns.index + 1}, #{String.downcase(label)}",
        options: options,
        grid_invalid?: grid_invalid?,
        ordering_invalid?: ordering_invalid?,
        overlap_invalid?: assigns.overlap_invalid?,
        invalid?: invalid?,
        error_id: grid_error_id,
        ordering_error_id: ordering_error_id,
        overlap_error_id: overlap_error_id,
        described_by:
          interval_review_described_by(
            grid_invalid?,
            grid_error_id,
            ordering_invalid?,
            ordering_error_id,
            assigns.overlap_invalid?,
            overlap_error_id
          )
      )

    ~H"""
    <div>
      <label for={@id} class="text-sm font-medium">{@label}</label>
      <select
        id={@id}
        class={["pc-select mt-1", @invalid? && "border-danger-500"]}
        name={"interval_review[weekly_availability][#{@day}][#{@index}][#{@boundary}]"}
        aria-label={@accessible_name}
        aria-invalid={@invalid? && "true"}
        aria-describedby={@described_by}
        data-order-invalid={@ordering_invalid? && "true"}
        required
      >
        <option :if={@grid_invalid?} value={@value} disabled selected>
          {@value} — incompatible con {@proposed_interval} minutos
        </option>
        <option :for={time <- @options} value={time} selected={time == @value}>{time}</option>
      </select>
      <p
        :if={@grid_invalid?}
        id={@error_id}
        class="mt-1 text-sm text-danger-600 dark:text-danger-400"
      >
        Seleccione un horario compatible con el intervalo propuesto de {@proposed_interval} minutos.
      </p>
      <p
        :if={@ordering_invalid?}
        id={@ordering_error_id}
        class="mt-1 text-sm text-danger-600 dark:text-danger-400"
      >
        La hora de cierre debe ser posterior a la hora de apertura.
      </p>
    </div>
    """
  end

  attr :type, :map, required: true
  attr :presentation, :string, required: true

  defp prepared_actions(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2" aria-label={"Acciones preparadas para #{@type.name}"}>
      <.button
        :if={@type.status == :active}
        color="secondary"
        variant="outline"
        size="xs"
        phx-click="open_edit_type"
        phx-value-id={@type.id}
      >
        Editar
      </.button>

      <.button
        :if={@type.status == :active}
        color="danger"
        variant="outline"
        size="xs"
        id={"deactivate-consultation-type-#{@type.id}-#{@presentation}"}
        aria-controls={deactivation_dialog_id(@type.id)}
        aria-haspopup="dialog"
        phx-click={PetalComponents.AlertDialog.open_alert_dialog(deactivation_dialog_id(@type.id))}
      >
        Desactivar
      </.button>

      <.button
        :if={@type.status == :inactive}
        color="secondary"
        variant="outline"
        size="xs"
        phx-click="reactivate_type"
        phx-value-id={@type.id}
      >
        Reactivar
      </.button>
    </div>
    """
  end

  attr :color, :string, required: true
  attr :name, :string, required: true

  defp color_swatch(assigns) do
    ~H"""
    <span
      role="img"
      aria-label={"Color asignado a #{@name}"}
      title={"Color asignado a #{@name}"}
      class="inline-block size-4 shrink-0 rounded-sm border border-border dark:border-gray-600"
      style={"background-color: #{@color}"}
    />
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <.badge
      color={status_color(@status)}
      variant="soft"
      size="sm"
      dot
      label={status_label(@status)}
      role="status"
    />
    """
  end

  defp parse_interval(interval) when is_binary(interval) do
    with {value, ""} <- Integer.parse(interval),
         true <- value in 5..240 and rem(value, 5) == 0 do
      {:ok, value}
    else
      _invalid -> :error
    end
  end

  defp parse_interval(_interval), do: :error

  defp type_form_params(params) when is_map(params) do
    Map.merge(@type_form_defaults, Map.take(params, Map.keys(@type_form_defaults)))
  end

  defp type_form_params(_params), do: @type_form_defaults

  defp edit_type_form_params(%{
         name: name,
         exact_price_ars: exact_price_ars,
         color: color,
         interval_count: interval_count
       }) do
    %{
      "name" => name,
      "currency" => "ARS",
      "exact_price_ars" => format_localized_price(exact_price_ars),
      "color" => color,
      "interval_count" => Integer.to_string(interval_count)
    }
  end

  defp validate_type_form(params, current_interval) do
    validations = %{
      name: validate_name(params["name"]),
      currency: validate_currency(params["currency"]),
      exact_price_ars: validate_price(params["exact_price_ars"]),
      color: validate_color(params["color"]),
      interval_count: validate_count(params["interval_count"], current_interval)
    }

    errors =
      Enum.reduce(validations, %{}, fn
        {field, {:error, message}}, acc -> Map.put(acc, field, [message])
        {_field, {:ok, _value}}, acc -> acc
      end)

    if map_size(errors) == 0 do
      {:ok,
       %{
         name: validated_value(validations.name),
         exact_price_ars: validated_value(validations.exact_price_ars),
         color: validated_value(validations.color),
         interval_count: validated_value(validations.interval_count)
       }}
    else
      {:error, errors}
    end
  end

  defp validate_name(name) when is_binary(name) do
    normalized_name = String.trim(name)

    cond do
      normalized_name == "" -> {:error, "Ingrese un nombre."}
      String.length(normalized_name) > 32 -> {:error, "El nombre admite hasta 32 caracteres."}
      true -> {:ok, normalized_name}
    end
  end

  defp validate_name(_name), do: {:error, "Ingrese un nombre."}

  defp validate_currency("ARS"), do: {:ok, "ARS"}
  defp validate_currency(_currency), do: {:error, "Seleccione una moneda válida."}

  defp validate_price(price) when is_binary(price) do
    case Regex.named_captures(@ars_price_pattern, String.trim(price)) do
      %{"sign" => sign, "whole" => whole, "fraction" => fraction} ->
        normalized_price =
          sign <> String.replace(whole, ".", "") <> decimal_fraction(fraction)

        case Decimal.parse(normalized_price) do
          {decimal, ""} -> validate_parsed_price(decimal)
          _invalid -> {:error, "Ingrese un precio válido en ARS."}
        end

      _invalid ->
        {:error, "Ingrese un precio válido en ARS."}
    end
  end

  defp validate_price(_price), do: {:error, "Ingrese un precio válido en ARS."}

  defp validate_parsed_price(decimal) do
    cond do
      Decimal.nan?(decimal) or Decimal.inf?(decimal) ->
        {:error, "Ingrese un precio válido en ARS."}

      Decimal.compare(decimal, Decimal.new(0)) == :lt ->
        {:error, "El precio no puede ser negativo."}

      decimal.exp < -2 ->
        {:error, "El precio admite hasta dos decimales."}

      true ->
        {:ok, decimal}
    end
  end

  defp decimal_fraction(""), do: ""
  defp decimal_fraction(fraction), do: "." <> fraction

  defp validate_color(color) when is_binary(color) do
    if Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color) do
      {:ok, String.upcase(color)}
    else
      {:error, "Seleccione un color válido."}
    end
  end

  defp validate_color(_color), do: {:error, "Seleccione un color válido."}

  defp validate_count(count, current_interval) when is_binary(count) do
    maximum = effective_maximum(current_interval)

    case Integer.parse(count) do
      {value, ""} when value >= 1 and value <= maximum -> {:ok, value}
      _invalid -> {:error, "La cantidad debe estar entre 1 y #{maximum}."}
    end
  end

  defp validate_count(_count, current_interval) do
    {:error, "La cantidad debe estar entre 1 y #{effective_maximum(current_interval)}."}
  end

  defp validated_value({:ok, value}), do: value

  defp field_errors(errors, field), do: Map.get(errors, field, [])

  defp price_control_errors(errors),
    do: field_errors(errors, :currency) ++ field_errors(errors, :exact_price_ars)

  defp has_field_error?(errors, field), do: Map.has_key?(errors, field)
  defp aria_invalid(errors, field), do: has_field_error?(errors, field) && "true"

  defp price_described_by(errors, field) do
    if has_field_error?(errors, field) do
      "new-consultation-type-price-help new-consultation-type-errors"
    else
      "new-consultation-type-price-help"
    end
  end

  defp error_summary_id(errors, field) do
    if has_field_error?(errors, field), do: "new-consultation-type-errors"
  end

  defp duration_preview(params, current_interval) do
    with {count, ""} <- Integer.parse(params["interval_count"] || ""),
         true <- count in 1..effective_maximum(current_interval) do
      count * current_interval
    else
      _invalid -> nil
    end
  end

  defp visible_catalog(%{catalog: catalog, show_inactive: true}), do: catalog

  defp visible_catalog(%{catalog: catalog, show_inactive: false}) do
    Enum.filter(catalog, &(&1.status == :active))
  end

  defp effective_maximum(interval), do: min(10, div(240, interval))

  defp change_example(catalog, current_interval, selected_interval) do
    case Enum.find(catalog, &(&1.status == :active)) do
      nil ->
        ""

      type ->
        "Por ejemplo, #{type.name} pasará de #{duration_minutes(type, current_interval)} a #{duration_minutes(type, selected_interval)} minutos."
    end
  end

  defp deactivation_dialog_id(id), do: "deactivate-consultation-type-#{id}"

  defp duration_minutes(
         %{status: :inactive, inactive_duration_minutes: duration_minutes},
         _interval
       ),
       do: duration_minutes

  defp duration_minutes(type, interval), do: type.interval_count * interval

  defp format_ars(exact_price), do: "ARS #{format_localized_price(exact_price)}"

  defp format_localized_price(exact_price) do
    {whole, fraction} =
      case exact_price |> Decimal.to_string(:normal) |> String.split(".", parts: 2) do
        [whole] -> {whole, ""}
        [whole, fraction] -> {whole, fraction}
      end

    grouped_whole =
      whole
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(".", &Enum.join/1)
      |> String.reverse()

    "#{grouped_whole},#{String.pad_trailing(fraction, 2, "0")}"
  end

  defp save_type(%{assigns: %{editing_type_id: nil}} = socket, attributes) do
    case consultation_types().create_type(socket.assigns.current_internal_session, attributes) do
      {:ok, _consultation_type} ->
        socket
        |> reload_configuration()
        |> reset_type_form()

      {:error, {:validation, errors}} ->
        assign(socket, type_form_errors: backend_type_errors(errors))

      {:error, _reason} ->
        assign(socket, catalog_error: :unavailable)
    end
  end

  defp save_type(socket, attributes) do
    case consultation_types().update_type(
           socket.assigns.current_internal_session,
           socket.assigns.editing_type_id,
           attributes
         ) do
      {:ok, _consultation_type} ->
        socket
        |> reload_configuration()
        |> reset_type_form()

      {:error, {:validation, errors}} ->
        assign(socket, type_form_errors: backend_type_errors(errors))

      {:error, :not_found} ->
        socket

      {:error, _reason} ->
        assign(socket, catalog_error: :unavailable)
    end
  end

  defp reload_configuration(socket) do
    case consultation_types().get_own_configuration(socket.assigns.current_internal_session) do
      {:ok, configuration} -> assign_configuration(socket, configuration)
      {:error, _reason} -> assign(socket, catalog_error: :unavailable)
    end
  end

  defp assign_configuration(socket, configuration) do
    assign(socket,
      catalog: configuration.consultation_types,
      current_interval: configuration.agenda_interval_minutes,
      selected_interval: configuration.agenda_interval_minutes,
      catalog_error: nil
    )
  end

  defp parsed_interval_or_current(interval, current_interval) do
    case parse_interval(interval) do
      {:ok, parsed_interval} -> parsed_interval
      :error -> current_interval
    end
  end

  defp load_interval_review(socket, reviewed_availability) do
    case consultation_types().preview_agenda_interval(
           socket.assigns.current_internal_session,
           socket.assigns.selected_interval,
           reviewed_availability
         ) do
      {:ok, review} ->
        assign(socket, interval_review: review, interval_feedback: nil)

      {:error, {:validation, _errors}} ->
        assign(socket, interval_feedback: :invalid, interval_review: nil)

      {:error, _reason} ->
        assign(socket, interval_feedback: :unavailable, interval_review: nil)
    end
  end

  defp interval_review_attributes(params, socket) do
    current = socket.assigns.interval_review.reviewed_availability
    week_params = Map.get(params, "weekly_availability", %{})

    week =
      Map.new(@availability_days, fn {day, _label} ->
        day_params = Map.get(week_params, Atom.to_string(day), %{})
        current_windows = Map.fetch!(current.weekly_availability, day)

        windows =
          day_params
          |> Enum.reject(fn {key, _value} -> key == "_present" end)
          |> Enum.sort_by(fn {key, _value} -> parse_review_index(key) end)
          |> Enum.map(fn {index_text, window} ->
            current_window = Enum.at(current_windows, parse_review_index(index_text), %{})

            %{
              start: Map.get(window, "start", Map.get(current_window, :start, "")),
              end: Map.get(window, "end", Map.get(current_window, :end, ""))
            }
          end)

        {day, windows}
      end)

    %{
      weekly_availability: week,
      booking_horizon_days:
        parse_review_integer(Map.get(params, "booking_horizon_days"), current.booking_horizon_days),
      minimum_lead_minutes:
        parse_review_integer(Map.get(params, "minimum_lead_minutes"), current.minimum_lead_minutes)
    }
  end

  defp availability_attrs(availability, week) do
    %{
      weekly_availability: week,
      booking_horizon_days: availability.booking_horizon_days,
      minimum_lead_minutes: availability.minimum_lead_minutes
    }
  end

  defp availability_day(day_name) do
    case Enum.find(@availability_days, fn {day, _label} -> Atom.to_string(day) == day_name end) do
      {day, _label} -> {:ok, day}
      nil -> :error
    end
  end

  defp update_interval_review_copy(socket, params) do
    source =
      case availability_day(Map.get(params, "source", "")) do
        {:ok, day} -> day
        :error -> nil
      end

    targets =
      params
      |> Map.get("targets", [])
      |> List.wrap()
      |> Enum.flat_map(fn day_name ->
        case availability_day(day_name) do
          {:ok, day} when day != source -> [day]
          _invalid -> []
        end
      end)
      |> Enum.uniq()

    assign(socket,
      interval_review_copy_source: source,
      interval_review_copy_targets: targets
    )
  end

  defp parse_review_index(value) do
    case Integer.parse(value) do
      {index, ""} -> index
      _invalid -> 1_000_000
    end
  end

  defp parse_review_integer(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _invalid -> fallback
    end
  end

  defp parse_review_integer(_value, fallback), do: fallback

  defp format_interval_time(minutes), do: TimeGrid.format(minutes)

  defp format_review_boundary(%{day: day, time: time}) do
    label = @availability_days |> Keyword.fetch!(day)
    "#{label} #{time}"
  end

  defp interval_review_order_invalid?(start_value, end_value)
       when is_binary(start_value) and is_binary(end_value),
       do: start_value != "" and end_value != "" and end_value <= start_value

  defp interval_review_order_invalid?(_start_value, _end_value), do: false

  defp interval_review_overlap_indexes(windows) do
    indexed_windows = Enum.with_index(windows)

    Enum.reduce(indexed_windows, MapSet.new(), fn {window, index}, overlaps ->
      if Enum.any?(indexed_windows, fn {other, other_index} ->
           index != other_index and interval_review_windows_overlap?(window, other)
         end) do
        MapSet.put(overlaps, index)
      else
        overlaps
      end
    end)
  end

  defp interval_review_windows_overlap?(
         %{start: left_start, end: left_end},
         %{start: right_start, end: right_end}
       )
       when is_binary(left_start) and is_binary(left_end) and is_binary(right_start) and
              is_binary(right_end) do
    left_start < left_end and right_start < right_end and left_start < right_end and
      right_start < left_end
  end

  defp interval_review_windows_overlap?(_left, _right), do: false

  defp interval_review_described_by(
         grid_invalid?,
         grid_error_id,
         ordering_invalid?,
         ordering_error_id,
         overlap_invalid?,
         overlap_error_id
       ) do
    [
      grid_invalid? && grid_error_id,
      ordering_invalid? && ordering_error_id,
      overlap_invalid? && overlap_error_id
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
    |> case do
      "" -> nil
      ids -> ids
    end
  end

  defp interval_review_order_blocked?(weekly_availability) do
    Enum.any?(weekly_availability, fn {_day, windows} ->
      Enum.any?(windows, fn window ->
        interval_review_order_invalid?(window.start, window.end)
      end)
    end)
  end

  defp interval_review_blocked?(review) do
    Enum.any?(review.consultation_type_effects, &(not &1.compatible)) or
      review.incompatible_availability_boundaries != [] or
      review.future_appointment_conflicts != [] or
      map_size(review.availability_validation_errors) > 0 or
      interval_review_order_blocked?(review.reviewed_availability.weekly_availability) or
      Enum.any?(review.reviewed_availability.weekly_availability, fn {_day, windows} ->
        MapSet.size(interval_review_overlap_indexes(windows)) > 0
      end)
  end

  defp backend_type_errors(errors) do
    Map.new(errors, fn {field, reason} -> {field, [backend_type_error(field, reason)]} end)
  end

  defp backend_type_error(:name, :required), do: "Ingrese un nombre."
  defp backend_type_error(:name, :too_long), do: "El nombre admite hasta 32 caracteres."
  defp backend_type_error(:exact_price_ars, :nonnegative), do: "El precio no puede ser negativo."
  defp backend_type_error(:exact_price_ars, :scale), do: "El precio admite hasta dos decimales."
  defp backend_type_error(:exact_price_ars, _reason), do: "Ingrese un precio válido en ARS."
  defp backend_type_error(:color, _reason), do: "Seleccione un color válido."

  defp backend_type_error(:interval_count, _reason),
    do: "La cantidad no es compatible con el intervalo de Agenda actual."

  defp backend_type_error(_field, _reason), do: "No se pudieron guardar los cambios."

  defp consultation_types do
    Application.get_env(:origen, :consultation_types_context, ConsultationTypes)
  end

  defp reset_type_form(socket) do
    assign(socket,
      type_modal_open: false,
      editing_type_id: nil,
      type_form_params: @type_form_defaults,
      type_form_errors: %{}
    )
  end

  defp type_modal_title(nil), do: "Nuevo tipo de consulta"
  defp type_modal_title(_editing_type_id), do: "Editar tipo de consulta"

  defp type_submit_label(nil), do: "Agregar tipo de consulta"
  defp type_submit_label(_editing_type_id), do: "Guardar cambios"

  defp type_form_error_summary(nil),
    do: "Revise los campos indicados. El tipo de consulta no fue agregado."

  defp type_form_error_summary(_editing_type_id),
    do: "Revise los campos indicados. No se guardaron los cambios."

  defp status_color(:active), do: "success"
  defp status_color(:inactive), do: "gray"

  defp status_label(:active), do: "Activo"
  defp status_label(:inactive), do: "Inactivo"
end
