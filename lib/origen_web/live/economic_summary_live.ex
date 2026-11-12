defmodule OrigenWeb.EconomicSummaryLive do
  @moduledoc """
  Read-only economic summary screen backed by `Origen.Booking.economic_summary/3`.

  The Professional is always derived from the active session. Secretaries may
  select one active Professional from the database-backed calendar listing.
  """
  use OrigenWeb, :live_view

  alias Origen.Appointments.DatabaseCalendar
  alias Origen.Booking

  @months ~w(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)

  @impl true
  def mount(_params, _session, socket) do
    expected_role =
      if socket.assigns.live_action == :professional, do: :professional, else: :secretary

    if socket.assigns.current_role == expected_role do
      month = organization_today() |> Date.beginning_of_month()
      professionals = if expected_role == :secretary, do: list_professionals(), else: []

      selected =
        if expected_role == :professional,
          do: to_string(socket.assigns.current_account_id),
          else: ""

      socket =
        socket
        |> assign(
          page_title: "Resumen económico",
          current_professional_identity: socket.assigns[:current_professional_identity],
          secretary_identity: secretary_identity(socket.assigns.current_internal_session),
          professionals: professionals,
          professionals_error:
            if(expected_role == :secretary and professionals == [], do: :unavailable, else: nil),
          professional_options_open: false,
          selected_professional: selected,
          month: month,
          month_input: month_value(month),
          mode: "month",
          from: Date.to_iso8601(month),
          to: Date.to_iso8601(Date.end_of_month(month)),
          period_params: %{"mode" => "month", "month" => month_value(month)},
          period_error: nil,
          summary_error: nil,
          summary: nil,
          consulted_from: month,
          consulted_to: Date.end_of_month(month)
        )

      {:ok, load_summary(socket)}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("professional", %{"professional" => ""}, socket) do
    {:noreply,
     assign(socket,
       selected_professional: "",
       professional_options_open: false,
       summary: nil,
       summary_error: nil,
       period_error: nil
     )}
  end

  def handle_event("professional", %{"professional" => id}, socket) do
    with {:ok, professional_id} <- parse_professional_id(id),
         true <- listed_professional?(socket.assigns.professionals, professional_id) do
      {:noreply,
       socket
       |> assign(
         selected_professional: to_string(professional_id),
         professional_options_open: false,
         summary_error: nil,
         period_error: nil
       )
       |> load_summary()}
    else
      _ ->
        {:noreply,
         assign(socket,
           professional_options_open: false,
           summary_error: "Seleccioná un profesional activo válido."
         )}
    end
  end

  def handle_event("professional", _params, socket) do
    {:noreply,
     assign(socket,
       professional_options_open: false,
       summary_error: "Seleccioná un profesional activo válido."
     )}
  end

  def handle_event("toggle_professionals", _params, socket) do
    {:noreply,
     assign(socket, :professional_options_open, !socket.assigns.professional_options_open)}
  end

  def handle_event("close_professionals", _params, socket) do
    {:noreply, assign(socket, :professional_options_open, false)}
  end

  def handle_event("period_change", %{"period" => params}, socket) do
    socket = assign_inputs(socket, params)

    if socket.assigns.mode == "month" do
      {:noreply, consult(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("consult", %{"period" => params}, socket) do
    {:noreply, socket |> assign_inputs(params) |> consult()}
  end

  def handle_event("month", %{"direction" => direction}, socket)
      when direction in ["previous", "next"] do
    month = socket.assigns.month

    target =
      if direction == "previous",
        do: Date.add(month, -1),
        else: Date.add(Date.end_of_month(month), 1)

    target = Date.beginning_of_month(target)

    {:noreply,
     socket
     |> assign(
       month: target,
       mode: "month",
       from: Date.to_iso8601(target),
       to: Date.to_iso8601(Date.end_of_month(target)),
       month_input: month_value(target),
       period_params: %{"mode" => "month", "month" => month_value(target)},
       period_error: nil
     )
     |> load_summary()}
  end

  defp consult(socket) do
    socket = assign(socket, period_params: period_params(socket), period_error: nil)

    case selected_id(socket) do
      {:ok, _id} -> load_summary(socket)
      :error -> socket
    end
  end

  defp load_summary(socket) do
    with {:ok, professional_id} <- selected_id(socket),
         {:ok, summary} <-
           Booking.economic_summary(
             socket.assigns.current_internal_session,
             professional_id,
             socket.assigns.period_params
           ) do
      assign(socket,
        summary: summary,
        summary_error: nil,
        period_error: nil,
        consulted_from: summary.period.from,
        consulted_to: summary.period.to
      )
    else
      {:error, reason} -> handle_summary_error(socket, reason)
      :error -> socket
    end
  end

  defp handle_summary_error(socket, reason)
       when reason in [
              :invalid_period,
              :range_reversed,
              :invalid_timezone,
              :ambiguous_period_boundary,
              :nonexistent_period_boundary
            ] do
    assign(socket, period_error: period_error_message(reason))
  end

  defp handle_summary_error(socket, :unauthorized) do
    assign(socket,
      summary: nil,
      summary_error: "No tenés permiso para consultar este resumen."
    )
  end

  defp handle_summary_error(socket, :invalid_professional_selection) do
    assign(socket,
      summary: nil,
      summary_error: "Seleccioná un profesional activo válido."
    )
  end

  defp handle_summary_error(socket, _reason) do
    assign(socket, summary: nil, summary_error: "No se pudo cargar el resumen económico.")
  end

  defp assign_inputs(socket, params) do
    socket
    |> assign(:mode, Map.get(params, "mode", socket.assigns.mode))
    |> assign(:from, Map.get(params, "from", socket.assigns.from))
    |> assign(:to, Map.get(params, "to", socket.assigns.to))
    |> then(fn socket ->
      month_input = Map.get(params, "month", socket.assigns.month_input)
      month_input = if is_binary(month_input), do: month_input, else: ""
      socket = assign(socket, :month_input, month_input)

      case Date.from_iso8601(month_input <> "-01") do
        {:ok, date} -> assign(socket, :month, date)
        _ -> socket
      end
    end)
    |> assign(period_error: nil, summary_error: nil)
  end

  defp period_params(%{assigns: %{mode: "month", month_input: month_input}}),
    do: %{"mode" => "month", "month" => month_input}

  defp period_params(%{assigns: %{mode: "range", from: from, to: to}}),
    do: %{"mode" => "range", "from" => from, "to" => to}

  defp period_params(_socket), do: %{}

  defp selected_id(%{assigns: %{selected_professional: selected}}),
    do: parse_professional_id(selected)

  defp parse_professional_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_professional_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> :error
    end
  end

  defp parse_professional_id(_id), do: :error

  defp listed_professional?(professionals, id),
    do: Enum.any?(professionals, &(to_string(&1.id) == to_string(id)))

  defp list_professionals do
    case DatabaseCalendar.list_professionals() do
      {:ok, professionals} -> professionals
      {:error, _reason} -> []
    end
  end

  defp secretary_identity(principal) do
    case Origen.Accounts.get_own_navigation_identity(principal) do
      {:ok, identity} -> identity
      {:error, _reason} -> nil
    end
  end

  defp organization_today do
    Application.fetch_env!(:origen, :organization_timezone)
    |> DateTime.now!()
    |> DateTime.to_date()
  end

  defp period_error_message(:range_reversed),
    do: "La fecha final no puede ser anterior a la inicial."

  defp period_error_message(_reason), do: "Completá un período válido."

  defp selected_professional(assigns) do
    Enum.find(assigns.professionals, &(to_string(&1.id) == assigns.selected_professional))
  end

  defp professional_name(%{current_role: :professional, current_professional_identity: identity})
       when is_map(identity) do
    [identity[:first_name], identity[:last_name]]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> "Mi resumen"
      value -> value
    end
  end

  defp professional_name(assigns) do
    case selected_professional(assigns) do
      %{name: name} -> name
      _ -> "Profesional"
    end
  end

  defp specialty(assigns) do
    case selected_professional(assigns) do
      %{specialty: specialty} -> specialty
      _ -> ""
    end
  end

  defp zero_summary?(%{total: total}), do: Decimal.equal?(total, Decimal.new("0"))
  defp zero_summary?(_summary), do: false

  defp money(%Decimal{} = amount) do
    parts = String.split(Decimal.to_string(amount, :normal), ".") ++ [""]
    [whole, fraction | _] = Enum.take(parts, 2)
    fraction = String.pad_trailing(fraction, 2, "0")

    whole =
      whole
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1.")
      |> String.reverse()

    whole <> "," <> fraction
  end

  defp date(date), do: Calendar.strftime(date, "%d/%m/%Y")
  defp month_value(date), do: Calendar.strftime(date, "%Y-%m")
  defp month_title(date), do: "#{Enum.at(@months, date.month - 1)} #{date.year}"

  @impl true
  def render(assigns) do
    ~H"""
    <OrigenWeb.RoleNavigation.navbar
      role={@current_role}
      active="summary"
      professional_identity={@current_professional_identity}
      secretary_identity={@secretary_identity}
    />
    <main id="economic-summary" data-theme="light" class="min-h-screen bg-page text-text">
      <section aria-label="Filtros del resumen" class="border-b border-gray-200 bg-surface">
        <div class="mx-auto flex max-w-7xl flex-col gap-6 px-4 py-5 sm:px-6 lg:flex-row lg:items-end lg:justify-between lg:px-8">
          <form
            id="period-form"
            phx-change="period_change"
            phx-submit="consult"
            class="flex flex-wrap items-end gap-3"
          >
            <div class="space-y-1">
              <label
                for="period-mode"
                class="block text-xs font-semibold uppercase tracking-wider text-text-muted"
              >Período</label>
              <select
                id="period-mode"
                name="period[mode]"
                class="rounded-control border border-border bg-surface px-3 py-2.5 focus:ring-2 focus:ring-primary-500"
              >
                <option value="month" selected={@mode == "month"}>Mes calendario</option>
                <option value="range" selected={@mode == "range"}>Rango de fechas</option>
              </select>
            </div>
            <div hidden={@mode != "month"} class="flex items-end gap-2">
              <button
                id="previous-month"
                type="button"
                phx-click="month"
                phx-value-direction="previous"
                aria-label="Mes anterior"
                class="rounded-control border border-border p-2.5 hover:bg-accent-100"
              ><.icon name="hero-chevron-left" class="size-5" /></button>
              <div class="space-y-1">
                <label for="period-month" class="block text-xs font-semibold text-text-muted">Mes y año</label>
                <input
                  id="period-month"
                  type="month"
                  name="period[month]"
                  value={@month_input}
                  class="rounded-control border border-border bg-surface px-3 py-2"
                />
              </div>
              <button
                id="next-month"
                type="button"
                phx-click="month"
                phx-value-direction="next"
                aria-label="Mes siguiente"
                class="rounded-control border border-border p-2.5 hover:bg-accent-100"
              ><.icon name="hero-chevron-right" class="size-5" /></button>
            </div>
            <div hidden={@mode != "range"} class="flex flex-wrap gap-3">
              <div class="space-y-1">
                <label for="period-from" class="block text-xs font-semibold text-text-muted">Fecha inicial</label>
                <input
                  id="period-from"
                  type="date"
                  name="period[from]"
                  value={@from}
                  aria-describedby="range-help period-error"
                  class="rounded-control border border-border bg-surface px-3 py-2"
                />
              </div>
              <div class="space-y-1">
                <label for="period-to" class="block text-xs font-semibold text-text-muted">Fecha final</label>
                <input
                  id="period-to"
                  type="date"
                  name="period[to]"
                  value={@to}
                  min={@from}
                  aria-describedby="range-help period-error"
                  class="rounded-control border border-border bg-surface px-3 py-2"
                />
              </div>
            </div>
            <button
              :if={@mode == "range"}
              type="submit"
              phx-disable-with="Consultando…"
              class="rounded-control bg-primary-700 px-5 py-2.5 font-semibold text-white hover:bg-primary-800 focus:ring-2 focus:ring-primary-500"
            >Consultar resumen</button>
            <p :if={@mode == "range"} id="range-help" class="w-full text-sm text-text-muted">
              Incluye ambos días. Para un solo día, elegí la misma fecha en ambos campos.
            </p>
            <p
              :if={@period_error}
              id="period-error"
              role="alert"
              class="w-full text-sm font-medium text-red-700"
            >
              {@period_error}
            </p>
          </form>
          <div
            :if={@current_role == :secretary}
            id="professional-selector"
            class="relative min-w-60 space-y-1"
            phx-click-away="close_professionals"
            phx-window-keydown="close_professionals"
            phx-key="Escape"
          >
            <p class="text-xs font-semibold uppercase tracking-wider text-text-muted">Profesional</p>
            <button
              id="professional-profile-button"
              type="button"
              phx-click="toggle_professionals"
              aria-expanded={to_string(@professional_options_open)}
              aria-controls="professional-options"
              class="flex w-full items-center gap-3 rounded-control border border-accent-300 bg-accent-100 px-3 py-3 text-left focus-visible:ring-2 focus-visible:ring-primary-500"
            >
              <span
                :if={@selected_professional != ""}
                id="selected-professional-card"
                class="flex min-w-0 flex-1 items-center gap-3"
              >
                <.avatar
                  id="selected-professional-avatar"
                  name={professional_name(assigns)}
                  size="md"
                />
                <span class="min-w-0"><span
                  id="selected-professional-name"
                  class="block truncate text-sm font-semibold text-text"
                >{professional_name(assigns)}</span><span
                  id="selected-professional-specialty"
                  class="block text-xs text-text-muted"
                >{specialty(assigns)}</span></span>
              </span>
              <span :if={@selected_professional == ""} class="flex flex-1 items-center gap-3 text-sm"><.icon
                name="hero-user-circle"
                class="size-10 text-text-muted"
              />Seleccioná un profesional</span>
              <.icon
                name="hero-chevron-down"
                class={["size-4 shrink-0", @professional_options_open && "rotate-180"]}
              />
            </button>
            <ul
              :if={@professional_options_open}
              id="professional-options"
              aria-label="Seleccionar profesional"
              class="absolute right-0 z-30 mt-2 w-full min-w-64 overflow-hidden rounded-surface border border-gray-200 bg-surface p-1 shadow-lg"
            >
              <li :for={professional <- @professionals}>
                <button
                  id={"professional-option-#{professional.id}"}
                  type="button"
                  phx-click="professional"
                  phx-value-professional={professional.id}
                  aria-pressed={to_string(@selected_professional == to_string(professional.id))}
                  class="flex w-full items-center gap-3 rounded-control px-3 py-3 text-left hover:bg-accent-100 focus-visible:ring-2 focus-visible:ring-primary-500"
                >
                  <.avatar name={professional.name} size="sm" />
                  <span><span class="block text-sm font-semibold">{professional.name}</span><span class="block text-xs text-text-muted">{professional.specialty}</span></span>
                </button>
              </li>
              <li>
                <button
                  id="professional-option-clear"
                  type="button"
                  phx-click="professional"
                  phx-value-professional=""
                  class="w-full rounded-control px-3 py-2 text-left text-sm text-text-muted hover:bg-accent-100"
                >
                  Limpiar selección
                </button>
              </li>
            </ul>
          </div>
        </div>
      </section>
      <div class="mx-auto max-w-7xl space-y-7 px-4 py-8 sm:px-6 lg:px-8">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">Resumen económico</h1>
            <p class="mt-3 max-w-2xl text-sm text-text-muted">
              Resumen de los turnos del período seleccionado.
            </p>
          </div>
        </div>
        <p
          :if={@selected_professional == ""}
          id="select-professional-notice"
          class="rounded-surface border border-gray-200 bg-surface p-8 text-center text-text-muted"
        >
          Seleccioná un profesional para consultar su resumen.
        </p>
        <p
          :if={@professionals_error}
          id="summary-error"
          role="alert"
          class="rounded-surface border border-red-200 bg-red-50 p-5 text-sm text-red-700"
        >
          No se pudo cargar la lista de profesionales activos.
        </p>
        <p
          :if={@summary_error}
          id="summary-error"
          role="alert"
          class="rounded-surface border border-red-200 bg-red-50 p-5 text-sm text-red-700"
        >
          {@summary_error}
        </p>
        <div :if={@selected_professional != "" and @summary} class="space-y-6">
          <div class="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 pb-4">
            <h2 class="text-lg font-semibold">{professional_name(assigns)}</h2>
            <p id="period-context" class="text-sm text-text-muted">
              Período consultado: {date(@consulted_from)} al {date(@consulted_to)}
              <span class="sr-only">{month_title(@consulted_from)}</span>
            </p>
          </div>
          <div class="grid gap-4 md:grid-cols-3" aria-label="Importes del período">
            <section
              :for={
                {id, label, amount, explanation} <- [
                  {"paid", "Pagado", @summary.paid,
                   "Incluye pagos conservados en cancelaciones y ausencias."},
                  {"pending", "Pendiente", @summary.pending,
                   "Turnos confirmados o asistidos que estén impagos."},
                  {"total", "Total considerado", @summary.total, "Pagado + Pendiente."}
                ]
              }
              id={"summary-#{id}"}
              class={[
                "rounded-surface border p-6 shadow-sm",
                if(id == "total",
                  do: "border-primary-700 bg-primary-700 text-white",
                  else: "border-gray-200 bg-surface"
                )
              ]}
            >
              <h3 class="text-sm font-semibold">{label}</h3>
              <p class="mt-4 text-3xl font-semibold tracking-tight">
                <span class="mr-1 text-sm font-medium">ARS</span> {money(amount)}
              </p>
              <p class={[
                "mt-4 text-sm leading-relaxed",
                if(id == "total", do: "text-primary-100", else: "text-text-muted")
              ]}>
                {explanation}
              </p>
            </section>
          </div>
          <p
            :if={zero_summary?(@summary)}
            id="empty-summary"
            role="status"
            class="rounded-surface border border-gray-200 bg-surface p-5 text-sm"
          >
            No hay turnos elegibles en este período. Los tres importes son cero.
          </p>
        </div>
      </div>
    </main>
    """
  end
end
