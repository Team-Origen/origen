defmodule OrigenWeb.AppointmentPaymentPreviewLive do
  @moduledoc """
  Development-only payment UI preview (#386). All data lives in the LiveView process.
  No Booking, Repo or payment services are called. Reloading restores the fixtures.
  """
  use OrigenWeb, :live_view

  alias OrigenWeb.Components.AgendaAppointmentCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       appointments: fixtures(),
       selected: nil,
       action: nil,
       error: nil,
       role: "professional",
       feedback: nil,
       page_title: "Mi agenda · Demostración"
     )}
  end

  @impl true
  def handle_event("open", %{"id" => id}, socket) do
    selected =
      Enum.find(visible(socket.assigns.appointments, socket.assigns.role), &(&1.id == id))

    {:noreply, assign(socket, selected: selected, action: nil, error: nil, feedback: nil)}
  end

  def handle_event("card_action", %{"id" => id, "action" => action}, socket) do
    selected =
      Enum.find(visible(socket.assigns.appointments, socket.assigns.role), &(&1.id == id))

    candidate = assign(socket, selected: selected)

    if allowed?(candidate.assigns, action) and action in ["cancelled", "attended", "no_show"] do
      {:noreply, assign(candidate, action: action, error: nil, feedback: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close", _, socket),
    do: {:noreply, assign(socket, selected: nil, action: nil, error: nil)}

  def handle_event("role", %{"preview" => %{"role" => role}}, socket)
      when role in ["professional", "secretary", "patient"] do
    {:noreply, assign(socket, role: role, selected: nil, action: nil, error: nil, feedback: nil)}
  end

  def handle_event("reset", _, socket) do
    {:noreply,
     assign(socket,
       appointments: fixtures(),
       selected: nil,
       action: nil,
       error: nil,
       feedback: "Ejemplos restablecidos."
     )}
  end

  def handle_event("action", %{"action" => action}, socket) do
    if allowed?(socket.assigns, action) do
      {:noreply, assign(socket, action: action, error: nil, feedback: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_action", _, socket),
    do: {:noreply, assign(socket, action: nil, error: nil)}

  def handle_event("price", %{"price" => %{"amount" => amount}}, socket) do
    if socket.assigns.action == "price" and allowed?(socket.assigns, "price") do
      case Decimal.parse(amount) do
        {price, ""} ->
          if Decimal.compare(price, Decimal.new(0)) != :lt and Decimal.scale(price) <= 2 do
            {:noreply, update_selected(socket, %{price: price}, "Precio actualizado en la demo.")}
          else
            {:noreply,
             assign(socket,
               error: "Ingresá un importe mayor o igual a cero, con hasta dos decimales."
             )}
          end

        _ ->
          {:noreply, assign(socket, error: "Ingresá un importe válido mayor o igual a cero.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("pay", %{"payment" => %{"method" => method}}, socket) do
    if socket.assigns.action == "pay" and allowed?(socket.assigns, "pay") and
         method in ["cash", "transfer"] do
      {:noreply,
       update_selected(
         socket,
         %{
           paid: true,
           method: method,
           actor: actor(socket.assigns.role),
           paid_at: DateTime.utc_now()
         },
         "Pago registrado sólo en la demo."
       )}
    else
      {:noreply, assign(socket, error: "Seleccioná efectivo o transferencia.")}
    end
  end

  def handle_event("confirm", _, socket) do
    action = socket.assigns.action

    if allowed?(socket.assigns, action) do
      changes =
        if action == "correct",
          do: %{paid: false, method: nil, actor: nil, paid_at: nil},
          else: %{status: action}

      message =
        if action == "correct",
          do: "El pago volvió a pendiente en la demo.",
          else: "Estado del turno actualizado sólo en la demo."

      {:noreply, update_selected(socket, changes, message)}
    else
      {:noreply, socket}
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  defp allowed?(%{selected: nil}, _), do: false
  defp allowed?(%{role: "patient"}, _), do: false
  # Preview-only interaction constraint; does not change the approved payment contract.
  defp allowed?(%{selected: %{status: "cancelled"}}, _), do: false

  defp allowed?(%{selected: appointment}, action) do
    case action do
      "price" -> not appointment.paid
      "pay" -> not appointment.paid and appointment.status in ["confirmed", "attended"]
      "correct" -> appointment.paid
      action when action in ["attended", "no_show"] -> appointment.status == "confirmed"
      "cancelled" -> appointment.status in ["requested", "confirmed"]
      _ -> false
    end
  end

  defp update_selected(socket, changes, message) do
    appointment = Map.merge(socket.assigns.selected, changes)
    # Keep mock action evidence in memory, without exposing a history widget.
    appointment = %{
      appointment
      | actions:
          appointment.actions ++
            [%{changes: changes, at: DateTime.utc_now(), actor: actor(socket.assigns.role)}]
    }

    appointments =
      Enum.map(socket.assigns.appointments, fn a ->
        if a.id == appointment.id, do: appointment, else: a
      end)

    assign(socket,
      selected: appointment,
      appointments: appointments,
      action: nil,
      error: nil,
      feedback: message
    )
  end

  defp visible(appointments, "secretary"), do: appointments

  defp visible(appointments, "professional"),
    do: Enum.filter(appointments, &(&1.professional == "Dra. García"))

  defp visible(appointments, "patient"),
    do: Enum.filter(appointments, &(&1.patient == "Ana Pérez"))

  defp actor("secretary"), do: "Secretaría (demo)"
  defp actor(_), do: "Dra. García (demo)"
  defp status("confirmed"), do: "Confirmado"
  defp status("attended"), do: "Asistió"
  defp status("no_show"), do: "No asistió"
  defp status("cancelled"), do: "Cancelado"
  defp status("requested"), do: "Pendiente de aprobación"
  defp status("expired"), do: "Vencido"
  defp method("cash"), do: "Efectivo"
  defp method("transfer"), do: "Transferencia"

  defp money(price) do
    [whole, fraction] =
      ((price |> Decimal.round(2) |> Decimal.to_string(:normal) |> String.split(".")) ++ [""])
      |> Enum.take(2)

    "$" <> whole <> "," <> String.pad_trailing(fraction, 2, "0")
  end

  defp status_classes("confirmed"), do: "bg-emerald-50 text-emerald-700 border-emerald-200"
  defp status_classes("requested"), do: "bg-indigo-50 text-indigo-700 border-indigo-200"
  defp status_classes("cancelled"), do: "bg-rose-50 text-rose-700 border-rose-200"
  defp status_classes("no_show"), do: "bg-amber-50 text-amber-700 border-amber-200"
  defp status_classes(_), do: "bg-stone-100 text-stone-700 border-stone-300"

  defp fixtures do
    [
      {"1", "10:00", "Ana Pérez", "confirmed", false, "10000", "Dra. García"},
      {"2", "11:00", "Ana Pérez", "confirmed", true, "8500", "Dra. García"},
      {"3", "12:00", "Juan López", "attended", true, "10000", "Dra. García"},
      {"4", "13:00", "Lucía Gómez", "requested", false, "9000", "Dra. García"},
      {"5", "14:00", "Pedro Ruiz", "cancelled", true, "7000", "Dra. García"},
      {"6", "15:00", "María Díaz", "no_show", false, "9000", "Dra. García"},
      {"7", "16:00", "Sofía Ramos", "attended", false, "0", "Dra. García"},
      {"8", "16:30", "Luis Torres", "expired", false, "8000", "Dra. García"},
      {"9", "17:00", "Elena Sosa", "confirmed", false, "12000", "Dr. López"}
    ]
    |> Enum.map(fn {id, time, patient, state, paid, price, professional} ->
      %{
        id: id,
        time: time,
        end_time:
          (time <> ":00") |> Time.from_iso8601!() |> Time.add(3600) |> Calendar.strftime("%H:%M"),
        duration_minutes: 60,
        patient: patient,
        document_number: to_string(30_111_221 + String.to_integer(id)),
        phone: "110000000#{id}",
        email:
          if(patient == "Ana Pérez",
            do: "ana.perez@example.test",
            else: "paciente#{id}@example.test"
          ),
        status: state,
        paid: paid,
        price: Decimal.new(price),
        professional: professional,
        method: if(paid, do: "cash"),
        actor: if(paid, do: "Secretaría (demo)"),
        paid_at: if(paid, do: ~U[2026-11-09 12:00:00Z]),
        actions: []
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto max-w-5xl space-y-5 p-4 sm:p-6">
      <div
        id="mock-notice"
        class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"
      >
        <strong>Demostración de diseño · #386.</strong> Turnos y pagos ficticios.
        Ninguna acción guarda datos reales. Al recargar se restablecen los ejemplos.
      </div>
      <header class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 class="text-2xl font-bold text-[#0A3847]">Mi agenda</h1>
            <p class="text-sm text-stone-600">9 de noviembre de 2026 · Datos de ejemplo</p>
          </div>
          <button
            id="reset-demo"
            phx-click="reset"
            class="rounded-lg border border-stone-300 px-4 py-2 text-sm"
          >Restablecer ejemplos</button>
        </div>
        <form id="role-form" phx-change="role" class="mt-4">
          <label for="preview-role" class="text-sm font-medium text-stone-700">Vista de demostración</label>
          <select
            id="preview-role"
            name="preview[role]"
            class="ml-2 rounded-lg border-stone-300 text-sm"
          >
            <option value="professional" selected={@role == "professional"}>Profesional</option>
            <option value="secretary" selected={@role == "secretary"}>Secretaría</option>
            <option value="patient" selected={@role == "patient"}>Paciente</option>
          </select>
        </form>
      </header>
      <p :if={@feedback} role="status" class="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800">
        {@feedback}
      </p>
      <div id="agenda-appointments-list" aria-label="Turnos de ejemplo" class="space-y-3" role="list">
        <AgendaAppointmentCard.card
          :for={a <- visible(@appointments, @role)}
          id={"appointment-#{a.id}"}
        >
          <:appointment>
            <div class="flex flex-wrap items-center gap-2.5">
              <span class="text-lg font-bold text-[#0A3847]">{a.time} - {a.end_time}</span>
              <span
                data-status={a.status}
                class={"text-xs font-semibold px-2.5 py-0.5 rounded-full border " <> status_classes(a.status)}
              >{status(a.status)}</span>
              <span
                id={"payment-status-#{a.id}"}
                class={[
                  "text-xs font-semibold px-2.5 py-0.5 rounded-full border",
                  if(a.paid,
                    do: "border-emerald-200 bg-emerald-50 text-emerald-800",
                    else: "border-amber-200 bg-amber-50 text-amber-900"
                  )
                ]}
              >{if a.paid, do: "Pagado", else: "Pendiente de pago"}</span>
            </div>
            <p class="text-xs sm:text-sm font-medium text-stone-700">
              Consulta <span class="text-stone-400 font-normal">• {a.duration_minutes} min</span>
            </p>
            <p :if={@role == "secretary"} class="text-xs text-stone-500">{a.professional}</p>
            <div class="pt-2 flex flex-wrap items-center gap-2">
              <button
                :for={
                  {action, label, colors} <- [
                    {"cancelled", "Cancelar con motivo",
                     "border-red-300 text-red-700 hover:bg-red-50"},
                    {"attended", "Marcar asistencia",
                     "border-emerald-300 text-emerald-800 hover:bg-emerald-50"},
                    {"no_show", "Marcar ausencia",
                     "border-orange-300 text-orange-700 hover:bg-orange-50"}
                  ]
                }
                :if={allowed?(%{selected: a, role: @role}, action)}
                id={"card-#{action}-#{a.id}"}
                type="button"
                phx-click="card_action"
                phx-value-id={a.id}
                phx-value-action={action}
                class={"rounded-md border bg-white px-2.5 py-1 text-xs font-semibold focus-visible:outline-2 focus-visible:outline-offset-2 " <> colors}
              >{label}</button>
              <button
                id={"open-#{a.id}"}
                type="button"
                phx-click="open"
                phx-value-id={a.id}
                class="rounded-md border border-blue-300 bg-white px-2.5 py-1 text-xs font-semibold text-blue-700 hover:bg-blue-50 focus-visible:outline-2 focus-visible:outline-offset-2"
                aria-label={"Ver detalle del turno de #{a.patient} a las #{a.time}"}
              >Ver detalle</button>
            </div>
          </:appointment>
          <:patient>
            <div class="text-xs text-stone-400 font-medium">Paciente</div>
            <div class="text-sm font-semibold text-stone-900">{a.patient}</div>
            <div :if={@role != "patient"} class="text-xs text-stone-500">
              DNI: {a.document_number}
            </div>
            <div :if={@role != "patient"} class="text-xs text-stone-500">Tel: {a.phone}</div>
            <div :if={@role != "patient"} class="text-xs text-stone-500">Acceso: {a.email}</div>
          </:patient>
        </AgendaAppointmentCard.card>
      </div>
      <div :if={@selected} class="fixed inset-0 z-50 overflow-y-auto bg-stone-900/50 p-4 sm:p-8">
        <.focus_wrap
          id="turn-detail"
          role="dialog"
          aria-modal="true"
          aria-labelledby="detail-title"
          phx-window-keydown="close"
          phx-key="Escape"
          class="mx-auto max-w-lg rounded-xl bg-white p-5 shadow-xl text-black"
        >
          <div class="flex items-center justify-between gap-3">
            <h2 id="detail-title" class="text-xl font-bold text-black">Detalle del turno</h2>
            <button
              id="close-detail"
              phx-click="close"
              aria-label="Cerrar detalle"
              class="rounded-lg p-2 text-black"
            >✕</button>
          </div>
          <p class="mt-4 font-semibold">{@selected.patient} · Consulta</p>
          <p id="detail-schedule" class="text-sm text-black">
            09/11/2026 · {@selected.time} - {@selected.end_time} · {@selected.duration_minutes} min · {@selected.professional}
          </p>
          <section class="mt-5 border-t border-stone-200 pt-4">
            <h3 class="font-semibold text-black">Estado del turno</h3>
            <span
              id="detail-status"
              class={"mt-1 inline-flex text-xs font-semibold px-2.5 py-0.5 rounded-full border " <> status_classes(@selected.status)}
            >{status(@selected.status)}</span>
            <div :if={@role != "patient" and is_nil(@action)} class="mt-3 flex flex-wrap gap-2">
              <button
                :for={
                  {action, label} <- [
                    {"attended", "Registrar asistencia"},
                    {"no_show", "Registrar ausencia"},
                    {"cancelled", "Cancelar turno"}
                  ]
                }
                :if={allowed?(assigns, action)}
                id={"action-#{action}"}
                phx-click="action"
                phx-value-action={action}
                class={"rounded-lg border bg-white px-3 py-2 text-sm " <> action_colors(action)}
              >{label}</button>
            </div>
          </section>
          <section id="payment-detail" class="mt-5 border-t border-stone-200 pt-4">
            <h3 class="font-semibold text-black">Pago</h3>
            <p class="mt-1">{if @selected.paid, do: "Pagado", else: "Pendiente de pago"}</p>
            <p class="mt-1">Precio final (pesos argentinos · ARS): {money(@selected.price)}</p>
            <div
              :if={@selected.paid and @role != "patient"}
              class="mt-2 space-y-1 text-sm text-black"
            >
              <p>Método: {method(@selected.method)}</p>
              <p>Registrado por: {@selected.actor}</p>
              <p>Fecha: {Calendar.strftime(@selected.paid_at, "%d/%m/%Y %H:%M UTC")}</p>
            </div>
            <div :if={is_nil(@action) and @role != "patient"} class="mt-3 flex flex-wrap gap-2">
              <button
                :if={allowed?(assigns, "price")}
                id="edit-price"
                phx-click="action"
                phx-value-action="price"
                class="rounded-lg border border-blue-300 bg-white px-3 py-2 text-sm text-blue-700 hover:bg-blue-50"
              >Editar precio</button>
              <button
                :if={allowed?(assigns, "pay")}
                id="register-payment"
                phx-click="action"
                phx-value-action="pay"
                class="rounded-lg border border-blue-300 bg-white px-3 py-2 text-sm font-semibold text-blue-700 hover:bg-blue-50"
              >Registrar pago</button>
              <button
                :if={allowed?(assigns, "correct")}
                id="correct-payment"
                phx-click="action"
                phx-value-action="correct"
                class="rounded-lg border border-stone-300 px-3 py-2 text-sm"
              >Corregir marca de pago</button>
            </div>
            <p
              :if={
                not @selected.paid and @role != "patient" and
                  @selected.status not in ["confirmed", "attended"]
              }
              class="mt-3 text-sm text-black"
            >
              Este estado del turno no admite registrar pagos.
            </p>
          </section>
          <div :if={@action} class="mt-5 rounded-xl border border-stone-200 bg-stone-50 p-4">
            <p :if={@error} role="alert" class="mb-3 text-sm text-black">{@error}</p>
            <form :if={@action == "price"} id="price-form" phx-submit="price">
              <label for="final-price" class="block text-sm font-semibold">Precio final (ARS)</label>
              <input
                id="final-price"
                name="price[amount]"
                type="number"
                min="0"
                step="0.01"
                required
                value={Decimal.to_string(@selected.price)}
                class="mt-2 w-full rounded-lg border-stone-300"
              />
              <button
                phx-disable-with="Guardando…"
                class="mt-3 rounded-lg bg-stone-100 px-4 py-2 text-sm text-black"
              >Guardar precio</button>
            </form>
            <form :if={@action == "pay"} id="payment-form" phx-submit="pay">
              <p class="font-semibold">Registrar pago · ARS {money(@selected.price)}</p>
              <label for="payment-method" class="mt-3 block text-sm">Método de pago</label>
              <select
                id="payment-method"
                name="payment[method]"
                required
                class="mt-2 w-full rounded-lg border-stone-300"
              >
                <option value="">Seleccionar método</option><option value="cash">Efectivo</option><option value="transfer">
                  Transferencia
                </option>
              </select>
              <button
                phx-disable-with="Registrando…"
                class="mt-3 rounded-lg border border-blue-300 bg-white px-4 py-2 text-sm text-blue-700 hover:bg-blue-50"
              >Registrar pago</button>
            </form>
            <div :if={@action not in ["price", "pay"]}>
              <p class="font-semibold">{confirmation(@action)}</p>
              <p :if={@action == "correct"} class="mt-1 text-sm text-black">
                El precio final volverá a estar disponible para edición.
              </p>
              <button
                id="confirm-action"
                phx-click="confirm"
                phx-disable-with="Aplicando…"
                class="mt-3 rounded-lg bg-stone-100 px-4 py-2 text-sm text-black"
              >{if @action == "correct", do: "Volver a pendiente", else: "Confirmar"}</button>
            </div>
            <button
              id="cancel-action"
              phx-click="cancel_action"
              class="mt-3 rounded-lg px-4 py-2 text-sm text-black"
            >Cancelar</button>
          </div>
        </.focus_wrap>
      </div>
    </main>
    """
  end

  defp action_colors("attended"), do: "border-emerald-300 text-emerald-800 hover:bg-emerald-50"
  defp action_colors("no_show"), do: "border-orange-300 text-orange-700 hover:bg-orange-50"
  defp action_colors("cancelled"), do: "border-red-300 text-red-700 hover:bg-red-50"

  defp confirmation("correct"), do: "¿Volver este pago a pendiente?"
  defp confirmation("attended"), do: "¿Confirmar que el paciente asistió?"
  defp confirmation("no_show"), do: "¿Confirmar que el paciente no asistió?"
  defp confirmation("cancelled"), do: "¿Cancelar este turno?"
end
