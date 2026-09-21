defmodule OrigenWeb.ConsultationTypeCatalogLive do
  use OrigenWeb, :live_view

  on_mount {OrigenWeb.InternalAuthLive, :ensure_professional}

  alias Origen.ConsultationTypes.Catalog

  @interval_options Enum.map(5..240//5, &{"#{&1} minutos", &1})
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
        reactivation_feedback: nil
      )

    case Catalog.execute({:list, %{professional_reference: "PRO-DEMO-001"}}) do
      {:ok, snapshot} ->
        {:ok,
         assign(socket,
           catalog: snapshot.consultation_types,
           current_interval: snapshot.agenda_interval_minutes,
           selected_interval: snapshot.agenda_interval_minutes,
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
           reactivation_feedback: nil
         )}

      :error ->
        {:noreply, assign(socket, interval_feedback: :invalid)}
    end
  end

  @impl true
  def handle_event("apply_interval", %{"interval_minutes" => interval}, socket) do
    with {:ok, selected_interval} <- parse_interval(interval),
         [] <- incompatible_active_types(socket.assigns.catalog, selected_interval) do
      {:noreply,
       assign(socket,
         current_interval: selected_interval,
         selected_interval: selected_interval,
         interval_feedback: :applied,
         reactivation_feedback: nil
       )}
    else
      :error ->
        {:noreply, assign(socket, interval_feedback: :invalid)}

      incompatible_types when is_list(incompatible_types) ->
        {:noreply,
         assign(socket,
           selected_interval: String.to_integer(interval),
           interval_feedback:
             {:incompatible, effective_maximum(String.to_integer(interval)), incompatible_types}
         )}
    end
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
    case Enum.find_index(socket.assigns.catalog, &(&1.id == id and &1.status == :active)) do
      nil ->
        {:noreply, socket}

      index ->
        catalog =
          List.update_at(socket.assigns.catalog, index, fn type ->
            type
            |> Map.put(:status, :inactive)
            |> Map.put(
              :inactive_duration_minutes,
              duration_minutes(type, socket.assigns.current_interval)
            )
          end)

        {:noreply, assign(socket, catalog: catalog)}
    end
  end

  def handle_event("deactivate_type", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("reactivate_type", %{"id" => id}, socket) when is_binary(id) do
    case inactive_type(socket.assigns.catalog, id) do
      nil ->
        {:noreply, socket}

      {index, consultation_type} ->
        if compatible_with_interval?(consultation_type, socket.assigns.current_interval) do
          catalog =
            List.update_at(socket.assigns.catalog, index, fn type ->
              type
              |> Map.put(:status, :active)
              |> Map.delete(:inactive_duration_minutes)
            end)

          {:noreply,
           assign(socket,
             catalog: catalog,
             reactivation_feedback: nil
           )}
        else
          {:noreply,
           assign(socket,
             reactivation_feedback:
               {:incompatible, consultation_type.name,
                prospective_duration_minutes(
                  consultation_type,
                  socket.assigns.current_interval
                )}
           )}
        end
    end
  end

  def handle_event("reactivate_type", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, visible_catalog: visible_catalog(assigns))

    ~H"""
    <main class="min-h-screen bg-page py-6 text-gray-900 sm:py-10">
      <.container max_width="xl">
        <div class="flex flex-col gap-6 sm:gap-8">
          <header class="space-y-2">
            <.h1 no_margin>Configuración</.h1>
            
            <.text_muted>
              Preferencias operativas de la práctica profesional.
            </.text_muted>
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
                    phx-submit="apply_interval"
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
                      :if={@selected_interval != @current_interval}
                      id="interval-change-warning"
                      color="warning"
                      variant="callout"
                      with_icon
                    >
                      Las cantidades de intervalos no cambiarán. Las duraciones de los tipos activos sí se recalcularán. {change_example(
                        @catalog,
                        @current_interval,
                        @selected_interval
                      )}
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
                    
                    <.incompatible_alert
                      :if={match?({:incompatible, _, _}, @interval_feedback)}
                      feedback={@interval_feedback}
                    />
                    <div>
                      <.button
                        type="submit"
                        color="primary"
                        disabled={@selected_interval == @current_interval}
                      >
                        Aplicar intervalo
                      </.button>
                    </div>
                  </form>
                </.card_content>
              </.card>
            </section>
            
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
                  class="block rounded-md bg-gray-50 p-4 text-sm font-semibold text-gray-700"
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
      </.container>
    </main>
    """
  end

  attr :feedback, :any, required: true

  defp incompatible_alert(%{feedback: {:incompatible, maximum, types}} = assigns) do
    assigns =
      assign(assigns, maximum: maximum, names: Enum.map_join(types, ", ", & &1.name))

    ~H"""
    <.alert id="interval-apply-error" color="danger" variant="callout" with_icon>
      <strong>No se aplicó el intervalo.</strong>
      Esta selección admite un máximo de {@maximum} intervalos; los tipos activos incompatibles son: {@names}.
      No se modificó ninguna cantidad.
    </.alert>
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
      class="inline-block size-4 shrink-0 rounded-sm border border-gray-500"
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

  defp incompatible_active_types(catalog, selected_interval) do
    maximum = effective_maximum(selected_interval)

    Enum.filter(catalog, fn type ->
      type.status == :active and type.interval_count > maximum
    end)
  end

  defp visible_catalog(%{catalog: catalog, show_inactive: true}), do: catalog

  defp visible_catalog(%{catalog: catalog, show_inactive: false}) do
    Enum.filter(catalog, &(&1.status == :active))
  end

  defp inactive_type(catalog, id) do
    case Enum.find_index(catalog, &(&1.id == id and &1.status == :inactive)) do
      nil -> nil
      index -> {index, Enum.at(catalog, index)}
    end
  end

  defp compatible_with_interval?(consultation_type, interval) do
    consultation_type.interval_count <= effective_maximum(interval)
  end

  defp prospective_duration_minutes(type, interval), do: type.interval_count * interval

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
    consultation_type =
      Map.merge(attributes, %{
        id: Ecto.UUID.generate(),
        status: :active
      })

    socket
    |> assign(catalog: socket.assigns.catalog ++ [consultation_type])
    |> reset_type_form()
  end

  defp save_type(socket, attributes) do
    editing_type_id = socket.assigns.editing_type_id

    case Enum.find_index(
           socket.assigns.catalog,
           &(&1.id == editing_type_id and &1.status == :active)
         ) do
      nil ->
        reset_type_form(socket)

      index ->
        catalog = List.update_at(socket.assigns.catalog, index, &Map.merge(&1, attributes))

        socket
        |> assign(catalog: catalog)
        |> reset_type_form()
    end
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
