defmodule OrigenWeb.EconomicSummaryLive do
  @moduledoc """
  Informational economic-summary prototype. Financial data is fictional and local
  to this LiveView; it is not an implementation of the financial backend.
  """
  use OrigenWeb, :live_view

  @professionals [{"demo-a", "Lucía Méndez"}, {"demo-b", "Martín Salvatierra"}]
  @specialties %{"demo-a" => "Psicología", "demo-b" => "Nutrición"}
  @months ~w(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)

  @impl true
  def mount(_params, _session, socket) do
    expected = if socket.assigns.live_action == :professional, do: :professional, else: :secretary

    if socket.assigns.current_role == expected do
      today =
        DateTime.now!(Application.fetch_env!(:origen, :organization_timezone))
        |> DateTime.to_date()

      month = Date.beginning_of_month(today)
      identity = socket.assigns[:current_professional_identity]

      secretary_identity =
        case Origen.Accounts.get_own_navigation_identity(socket.assigns.current_internal_session) do
          {:ok, value} -> value
          _ -> nil
        end

      {:ok,
       socket
       |> assign(
         page_title: "Resumen económico",
         current_professional_identity: identity,
         secretary_identity: secretary_identity,
         professionals: @professionals,
         professional_options_open: false,
         selected_professional: if(expected == :professional, do: "demo-a", else: ""),
         seed_month: month,
         month: month,
         mode: "month",
         from: Date.to_iso8601(month),
         to: Date.to_iso8601(Date.end_of_month(month)),
         period_error: nil,
         consulted_from: month,
         consulted_to: Date.end_of_month(month)
       )
       |> summarize()}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("professional", %{"professional" => id}, socket) do
    # The professional view never accepts a client-selected identity.
    if socket.assigns.current_role == :secretary do
      selected = if id in ["demo-a", "demo-b"], do: id, else: ""

      {:noreply,
       socket
       |> assign(selected_professional: selected, professional_options_open: false)
       |> summarize()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_professionals", _params, socket) do
    {:noreply,
     assign(socket, :professional_options_open, !socket.assigns.professional_options_open)}
  end

  def handle_event("close_professionals", _params, socket) do
    {:noreply, assign(socket, :professional_options_open, false)}
  end

  def handle_event("period_change", %{"period" => params}, socket) do
    if Map.get(params, "mode") == "month" do
      handle_event("consult", %{"period" => params}, socket)
    else
      {:noreply, assign_inputs(socket, params)}
    end
  end

  def handle_event("consult", %{"period" => params}, socket) do
    socket = assign_inputs(socket, params)

    case period(params) do
      {:ok, from, to} ->
        {:noreply,
         socket
         |> assign(consulted_from: from, consulted_to: to, period_error: nil)
         |> summarize()}

      {:error, message} ->
        {:noreply, assign(socket, :period_error, message)}
    end
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
       consulted_from: target,
       consulted_to: Date.end_of_month(target),
       period_error: nil
     )
     |> summarize()}
  end

  defp assign_inputs(socket, params) do
    socket
    |> assign(:mode, Map.get(params, "mode", socket.assigns.mode))
    |> assign(:from, Map.get(params, "from", socket.assigns.from))
    |> assign(:to, Map.get(params, "to", socket.assigns.to))
    |> then(fn socket ->
      case Date.from_iso8601(Map.get(params, "month", "") <> "-01") do
        {:ok, date} -> assign(socket, :month, date)
        _ -> socket
      end
    end)
    |> assign(:period_error, nil)
  end

  defp period(%{"mode" => "month", "month" => value}) do
    case Date.from_iso8601(value <> "-01") do
      {:ok, date} -> {:ok, date, Date.end_of_month(date)}
      _ -> {:error, "Completá un período válido."}
    end
  end

  defp period(%{"mode" => "range", "from" => from, "to" => to}) do
    with {:ok, start} <- Date.from_iso8601(from),
         {:ok, finish} <- Date.from_iso8601(to) do
      if Date.compare(finish, start) == :lt,
        do: {:error, "La fecha final no puede ser anterior a la inicial."},
        else: {:ok, start, finish}
    else
      _ -> {:error, "Completá un período válido."}
    end
  end

  defp period(_), do: {:error, "Completá un período válido."}

  # Integer centavos keep the fictional example exact. These rows never come
  # from patient, booking or payment storage and cannot be used to record a payment.
  defp summarize(socket) do
    a = socket.assigns
    multiplier = if a.selected_professional == "demo-b", do: 2, else: 1

    names =
      if a.selected_professional == "demo-b" do
        [
          "Camila Torres",
          "Bruno Medina",
          "Elena Suárez",
          "Gabriel Molina",
          "Clara Navarro",
          "Diego Ferreyra",
          "Inés Ponce",
          "Mateo Aguirre",
          "Paula Villalba",
          "Santiago Vera",
          "Florencia Castro",
          "Tomás Peralta",
          "Marina Godoy",
          "Lautaro Ibáñez",
          "Victoria Luna"
        ]
      else
        [
          "Valentina Ríos",
          "Julián Acosta",
          "Sofía Benítez",
          "Nicolás Duarte",
          "Emilia Sosa",
          "Agustín Cabrera",
          "Catalina Funes",
          "Benjamín Paz",
          "Renata Silva",
          "Franco Correa",
          "Olivia Ramos",
          "Manuel Quiroga",
          "Josefina Arias",
          "Ignacio Leiva",
          "Malena Costa"
        ]
      end

    # Keep the initial month available and add November/December of that year.
    # Deduplicate when mounting in November or December to avoid double totals.
    months =
      [a.seed_month, Date.new!(a.seed_month.year, 11, 1), Date.new!(a.seed_month.year, 12, 1)]
      |> Enum.uniq()

    rows =
      months
      |> Enum.flat_map(fn month ->
        [
          {1, :attended, false, 400_000},
          {2, :confirmed, false, 600_000},
          {3, :confirmed, true, 1_000_000},
          {4, :cancelled, true, 800_000},
          {5, :no_show, true, 700_000},
          {6, :cancelled, false, 300_000},
          {7, :no_show, false, 300_000},
          {8, :attended, false, 500_000},
          {10, :attended, false, 750_000},
          {12, :confirmed, false, 800_000},
          {15, :attended, true, 900_000},
          {18, :confirmed, true, 650_000},
          {20, :cancelled, true, 450_000},
          {23, :no_show, false, 350_000},
          {27, :attended, false, 550_000}
        ]
        |> Enum.zip(names)
        |> Enum.map(fn {{day, status, paid, cents}, name} ->
          %{
            date: %{month | day: day},
            patient: name,
            status: status,
            paid: paid,
            cents: cents * multiplier
          }
        end)
      end)
      |> Enum.filter(
        &(Date.compare(&1.date, a.consulted_from) != :lt and
            Date.compare(&1.date, a.consulted_to) != :gt)
      )

    paid = rows |> Enum.filter(& &1.paid) |> Enum.map(& &1.cents) |> Enum.sum()

    pending =
      rows
      |> Enum.filter(&(!&1.paid and &1.status in [:confirmed, :attended]))
      |> Enum.map(& &1.cents)
      |> Enum.sum()

    detail = Enum.filter(rows, &(!&1.paid and &1.status == :attended))
    assign(socket, paid: paid, pending: pending, total: paid + pending, detail: detail)
  end

  defp money(cents) do
    whole =
      div(cents, 100)
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1.")
      |> String.reverse()

    whole <> "," <> String.pad_leading(Integer.to_string(rem(cents, 100)), 2, "0")
  end

  defp date(date), do: Calendar.strftime(date, "%d/%m/%Y")
  defp month_value(date), do: Calendar.strftime(date, "%Y-%m")
  defp month_title(date), do: "#{Enum.at(@months, date.month - 1)} #{date.year}"

  defp professional_name(%{current_role: :professional, current_professional_identity: identity})
       when is_map(identity) do
    Enum.join(Enum.reject([identity[:first_name], identity[:last_name]], &(&1 in [nil, ""])), " ")
    |> case do
      "" -> "Mi resumen"
      value -> value
    end
  end

  defp professional_name(%{current_role: :professional}), do: "Mi resumen"
  defp professional_name(assigns), do: Map.new(@professionals)[assigns.selected_professional]

  defp specialty(id), do: Map.get(@specialties, id, "")

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
                  value={month_value(@month)}
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
                <span class="min-w-0">
                  <span
                    id="selected-professional-name"
                    class="block truncate text-sm font-semibold text-text"
                  >{professional_name(assigns)}</span>
                  <span id="selected-professional-specialty" class="block text-xs text-text-muted">{specialty(
                    @selected_professional
                  )}</span>
                </span>
              </span>
              <span :if={@selected_professional == ""} class="flex flex-1 items-center gap-3 text-sm">
                <.icon name="hero-user-circle" class="size-10 text-text-muted" />
                Seleccioná un profesional
              </span>
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
              <li :for={{id, name} <- @professionals}>
                <button
                  id={"professional-option-#{id}"}
                  type="button"
                  phx-click="professional"
                  phx-value-professional={id}
                  aria-pressed={to_string(@selected_professional == id)}
                  class="flex w-full items-center gap-3 rounded-control px-3 py-3 text-left hover:bg-accent-100 focus-visible:ring-2 focus-visible:ring-primary-500"
                >
                  <.avatar name={name} size="sm" />
                  <span><span class="block text-sm font-semibold">{name}</span><span class="block text-xs text-text-muted">{specialty(
                    id
                  )}</span></span>
                </button>
              </li>
              <li>
                <button
                  id="professional-option-clear"
                  type="button"
                  phx-click="professional"
                  phx-value-professional=""
                  class="w-full rounded-control px-3 py-2 text-left text-sm text-text-muted hover:bg-accent-100"
                >Limpiar selección</button>
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
        <div :if={@selected_professional != ""} class="space-y-6">
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
                {id, label, cents, explanation} <- [
                  {"paid", "Pagado", @paid,
                   "Incluye pagos conservados en cancelaciones y ausencias."},
                  {"pending", "Pendiente", @pending,
                   "Turnos confirmados o asistidos que estén impagos."},
                  {"total", "Total considerado", @total, "Pagado + Pendiente."}
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
                <span class="mr-1 text-sm font-medium">ARS</span> {money(cents)}
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
            :if={@total == 0}
            id="empty-summary"
            role="status"
            class="rounded-surface border border-gray-200 bg-surface p-5 text-sm"
          >
            No hay turnos elegibles en este período. Los tres importes son cero.
          </p>
          <details
            id="attended-unpaid"
            open
            class="overflow-hidden rounded-surface border border-gray-200 bg-surface shadow-sm"
          >
            <summary class="cursor-pointer px-6 py-5 font-semibold hover:bg-accent-50">
              Atenciones pendientes de pago
              <span class="ml-2 rounded-full bg-accent-200 px-2.5 py-1 text-xs">{length(@detail)}</span>
            </summary>
            <div class="border-t border-gray-200">
              <p class="px-6 py-4 text-sm text-text-muted">
                Sólo turnos con asistencia registrada y sin pago. Es un subconjunto de Pendiente; no incluye reservas confirmadas.
              </p>
              <div :if={@detail != []} class="overflow-x-auto">
                <table class="w-full text-left text-sm">
                  <caption class="sr-only">
                    Atenciones impagas del profesional y período consultados.
                  </caption>
                  <thead class="bg-accent-100 text-text-muted">
                    <tr>
                      <th scope="col" class="px-6 py-3 font-medium">Fecha del turno</th><th
                        scope="col"
                        class="px-6 py-3 font-medium"
                      >
                        Paciente
                      </th><th scope="col" class="px-6 py-3 text-right font-medium">Importe</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={row <- @detail} class="border-t border-gray-100">
                      <td class="whitespace-nowrap px-6 py-4">{date(row.date)}</td><td class="px-6 py-4">
                        {row.patient}
                      </td><td class="whitespace-nowrap px-6 py-4 text-right font-semibold">
                        ARS {money(row.cents)}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p :if={@detail == []} class="px-6 pb-5 text-sm text-text-muted">
                No hay atenciones pendientes de pago en este período.
              </p>
            </div>
          </details>
        </div>
      </div>
    </main>
    """
  end
end
