defmodule OrigenWeb.AppointmentPaymentComponent do
  @moduledoc "Appointment detail dialog with real staff payment controls shared by the agendas."
  use OrigenWeb, :live_component

  alias Origen.Booking

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:professional_name, fn -> nil end)
     |> assign_new(:action, fn -> nil end)
     |> assign_new(:confirm_reversal, fn -> false end)
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:feedback, fn -> nil end)
     |> load_payment()}
  end

  @impl true
  def handle_event("start_price", _params, socket),
    do: {:noreply, assign(socket, action: :price, error: nil, feedback: nil)}

  def handle_event("start_payment", _params, socket),
    do: {:noreply, assign(socket, action: :pay, error: nil, feedback: nil)}

  def handle_event("cancel_action", _params, socket),
    do: {:noreply, assign(socket, action: nil, confirm_reversal: false, error: nil)}

  def handle_event("update_price", %{"payment" => %{"price" => price}}, socket) do
    result =
      Booking.update_final_price(socket.assigns.principal, socket.assigns.appointment.id, price)

    {:noreply, finish(socket, result, "Precio final actualizado.")}
  end

  def handle_event("register_payment", %{"payment" => %{"method" => method}}, socket) do
    result =
      Booking.record_payment(socket.assigns.principal, socket.assigns.appointment.id, method)

    {:noreply, finish(socket, result, "Pago total registrado.")}
  end

  def handle_event("open_reversal", _params, socket) do
    {:noreply,
     socket |> load_payment() |> assign(confirm_reversal: true, error: nil, feedback: nil)}
  end

  def handle_event("cancel_reversal", _params, socket) do
    {:noreply, assign(socket, confirm_reversal: false, error: nil, feedback: nil)}
  end

  def handle_event("confirm_reversal", _params, socket) do
    # Only this server-side confirmation step can submit true to the domain.
    if socket.assigns.confirm_reversal do
      result =
        Booking.revert_payment(socket.assigns.principal, socket.assigns.appointment.id, true)

      {:noreply,
       socket |> assign(confirm_reversal: false) |> finish(result, "Marca pagada corregida.")}
    else
      {:noreply, assign(socket, error: "Primero confirmá la corrección.", feedback: nil)}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp finish(socket, {:ok, _payment}, message) do
    socket |> assign(action: nil, error: nil, feedback: message) |> load_payment()
  end

  defp finish(socket, {:error, reason}, _message) do
    socket |> assign(error: error_message(reason), feedback: nil) |> load_payment()
  end

  defp load_payment(socket) do
    principal = socket.assigns.principal
    id = socket.assigns.appointment.id

    with {:ok, payment} <- Booking.get_payment(principal, id),
         {:ok, actions} <- Booking.list_payment_actions(principal, id) do
      assign(socket, payment: payment, actions: actions, unavailable: false)
    else
      {:error, _} ->
        # Do not retain a previous projection if a session or scope is no longer valid.
        assign(socket, payment: nil, actions: [], unavailable: true, confirm_reversal: false)
    end
  end

  defp error_message(:invalid_final_price),
    do: "El precio debe ser un importe válido, mayor o igual a cero."

  defp error_message(:payment_already_paid),
    do: "El turno ya está pagado. Corregí la marca antes de editar el precio."

  defp error_message(:invalid_payment_method), do: "Elegí efectivo o transferencia."

  defp error_message(:payment_not_eligible),
    do: "Solo se puede pagar un turno confirmado o asistido."

  defp error_message(:payment_not_paid), do: "El pago ya está pendiente."
  defp error_message(:unauthorized), do: "No tenés permiso para operar este pago."
  defp error_message(_), do: "No se pudo actualizar el pago. Volvé a intentar."

  defp method_label("cash"), do: "Efectivo"
  defp method_label("transfer"), do: "Transferencia"
  defp method_label(_), do: "No disponible"
  defp action_label("paid"), do: "Pago total"
  defp action_label("reverted"), do: "Corrección"

  defp timestamp(datetime, timezone),
    do: datetime |> DateTime.shift_zone!(timezone) |> Calendar.strftime("%d/%m/%Y %H:%M")

  attr :id, :string, required: true
  attr :appointment_id, :integer, required: true

  def detail_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      phx-click={
        JS.push("open_turn_detail", value: %{appointment_id: to_string(@appointment_id)})
        |> JS.push_focus()
      }
      aria-haspopup="dialog"
      class="rounded-md border border-sky-300 bg-white px-2.5 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-50 focus-visible:outline-2 focus-visible:outline-offset-2"
    >Ver turno</button>
    """
  end

  defp status_label(status) do
    case to_string(status) do
      "requested" -> "Pendiente de aprobación"
      "confirmed" -> "Confirmado"
      "attended" -> "Asistió"
      "cancelled" -> "Cancelado"
      "no_show" -> "No asistió"
      "expired" -> "Vencido"
      _ -> "Estado no disponible"
    end
  end

  defp patient_name(%{patient_name: name}), do: name
  defp patient_name(%{patient: %{name: name}}), do: name
  defp patient_name(%{patient_profile_id: id}), do: "Paciente ##{id}"
  defp patient_name(_), do: "Paciente"

  defp duration(appointment),
    do: DateTime.diff(appointment.end_time, appointment.start_time, :minute)

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="fixed inset-0 z-50 overflow-y-auto bg-stone-900/50 p-4 sm:p-8">
      <.focus_wrap
        id="turn-detail"
        role="dialog"
        aria-modal="true"
        aria-labelledby="detail-title"
        phx-window-keydown={JS.push("close_turn_detail") |> JS.pop_focus()}
        phx-key="Escape"
        class="mx-auto max-w-lg rounded-xl bg-white p-5 text-stone-900 shadow-xl"
      >
        <div class="flex items-center justify-between gap-3">
          <h2 id="detail-title" class="text-xl font-bold">Detalle del turno</h2>
          <button
            id="close-turn-detail"
            type="button"
            phx-click={JS.push("close_turn_detail") |> JS.pop_focus()}
            aria-label="Cerrar detalle"
            class="rounded-lg p-2"
          >✕</button>
        </div>
        <p class="mt-4 font-semibold">
          {patient_name(@appointment)} · {@appointment.consultation_type_name}
        </p>
        <p :if={@professional_name} class="text-sm">Profesional: {@professional_name}</p>
        <p id="detail-schedule" class="text-sm">
          {timestamp(@appointment.start_time, @timezone)} - {Calendar.strftime(
            DateTime.shift_zone!(@appointment.end_time, @timezone),
            "%H:%M"
          )} · {duration(@appointment)} min
        </p>
        <section class="mt-5 border-t border-stone-200 pt-4">
          <h3 class="font-semibold">Estado del turno</h3>
          <span
            id="detail-status"
            class="mt-1 inline-flex rounded-full border border-stone-300 px-2.5 py-0.5 text-xs font-semibold"
          >{status_label(@appointment.status)}</span>
        </section>
        <section class="mt-5 space-y-3 border-t border-stone-200 pt-4" aria-label="Pago del turno">
          <h3 class="font-semibold">Pago</h3>
          <p :if={@unavailable} role="alert" class="text-red-800">
            No se pudo consultar el pago. Actualizá la agenda para reintentar.
          </p>
          <p :if={@error} id={"payment-error-#{@appointment.id}"} role="alert" class="text-red-800">
            {@error}
          </p>
          <p :if={@feedback} role="status" class="text-emerald-800">{@feedback}</p>
          <%= if @payment do %>
            <div class="flex flex-wrap items-center justify-between gap-2">
              <p class="font-semibold text-stone-900">Precio final: ${@payment.final_price_ars}</p>
              <span class="rounded-full border border-stone-300 bg-white px-2 py-1 text-xs font-semibold text-stone-800">
                {if @payment.payment_status == "paid", do: "Pagado", else: "Pendiente"}
              </span>
            </div>
            <%= if @payment.payment_status == "pending" do %>
              <div :if={is_nil(@action)} class="flex flex-wrap gap-2">
                <button
                  id={"payment-edit-price-#{@appointment.id}"}
                  type="button"
                  phx-click="start_price"
                  phx-target={@myself}
                  class="rounded-lg border border-sky-300 bg-white px-3 py-2 text-sm text-sky-700 hover:bg-sky-50"
                >Editar precio</button>
                <button
                  :if={to_string(@appointment.status) in ["confirmed", "attended"]}
                  id={"payment-start-register-#{@appointment.id}"}
                  type="button"
                  phx-click="start_payment"
                  phx-target={@myself}
                  class="rounded-lg border border-sky-300 bg-white px-3 py-2 text-sm font-semibold text-sky-700 hover:bg-sky-50"
                >Registrar pago</button>
              </div>
              <p :if={to_string(@appointment.status) not in ["confirmed", "attended"]} class="text-sm">
                Este estado del turno no admite registrar pagos.
              </p>
              <form
                :if={@action == :price}
                id={"payment-price-form-#{@appointment.id}"}
                phx-submit="update_price"
                phx-target={@myself}
                class="flex flex-wrap items-end gap-2"
              >
                <div>
                  <label
                    for={"payment-price-#{@appointment.id}"}
                    class="block text-xs font-semibold text-stone-700"
                  >Precio final (ARS)</label>
                  <input
                    id={"payment-price-#{@appointment.id}"}
                    name="payment[price]"
                    value={@payment.final_price_ars}
                    type="text"
                    inputmode="decimal"
                    required
                    class="w-36 rounded-md border-stone-300 bg-white text-stone-900"
                  />
                </div>
                <button
                  type="submit"
                  class="rounded-md border border-stone-300 bg-white px-3 py-2 font-semibold text-stone-800"
                >Guardar precio</button>
              </form>
              <form
                :if={@action == :pay and to_string(@appointment.status) in ["confirmed", "attended"]}
                id={"payment-register-form-#{@appointment.id}"}
                phx-submit="register_payment"
                phx-target={@myself}
                class="flex flex-wrap items-end gap-2"
              >
                <div>
                  <label
                    for={"payment-method-#{@appointment.id}"}
                    class="block text-xs font-semibold text-stone-700"
                  >Método de pago total</label>
                  <select
                    id={"payment-method-#{@appointment.id}"}
                    name="payment[method]"
                    class="rounded-md border-stone-300 bg-white text-stone-900"
                  >
                    <option value="cash">Efectivo</option>
                    <option value="transfer">Transferencia</option>
                  </select>
                </div>
                <button
                  type="submit"
                  class="rounded-md bg-[#0A3847] px-3 py-2 font-semibold text-white"
                >Registrar pago total</button>
              </form>
            <% else %>
              <p class="text-xs text-stone-700">
                {method_label(@payment.payment_method)} · {@payment.paid_actor_ref} · {timestamp(
                  @payment.paid_at,
                  @timezone
                )}
              </p>
              <p class="text-xs text-stone-600">Precio bloqueado mientras el turno está pagado.</p>
              <button
                id={"payment-revert-#{@appointment.id}"}
                type="button"
                phx-click="open_reversal"
                phx-target={@myself}
                class="rounded-md border border-amber-400 px-3 py-2 font-semibold text-amber-900"
              >Corregir marca pagada</button>
              <div
                :if={@confirm_reversal}
                id={"payment-revert-confirmation-#{@appointment.id}"}
                role="group"
                aria-label="Confirmar corrección del pago"
                class="space-y-2 rounded-md border border-amber-300 bg-amber-50 p-3"
              >
                <p class="text-stone-900">¿Confirmás volver este pago a pendiente?</p>
                <div class="flex flex-wrap gap-2">
                  <button
                    id={"payment-revert-confirm-#{@appointment.id}"}
                    type="button"
                    phx-click="confirm_reversal"
                    phx-target={@myself}
                    class="rounded-md bg-[#0A3847] px-3 py-2 font-semibold text-white"
                  >Confirmar corrección</button>
                  <button
                    id={"payment-revert-cancel-#{@appointment.id}"}
                    type="button"
                    phx-click="cancel_reversal"
                    phx-target={@myself}
                    class="rounded-md border border-stone-300 bg-white px-3 py-2 font-semibold text-stone-800"
                  >Volver</button>
                </div>
              </div>
            <% end %>
            <details
              :if={@actions != []}
              id={"payment-history-#{@appointment.id}"}
              class="text-xs text-stone-700"
            >
              <summary class="cursor-pointer font-semibold">Historial de pago</summary>
              <ol class="mt-2 space-y-1">
                <li :for={action <- @actions}>
                  {action_label(action.action)} · ${action.amount_ars} · {method_label(action.method)} · {action.actor_ref} · {timestamp(
                    action.occurred_at,
                    @timezone
                  )}
                </li>
              </ol>
            </details>
            <button
              :if={@action}
              id={"payment-cancel-action-#{@appointment.id}"}
              type="button"
              phx-click="cancel_action"
              phx-target={@myself}
              class="rounded-lg px-4 py-2 text-sm"
            >Cancelar</button>
          <% end %>
        </section>
      </.focus_wrap>
    </div>
    """
  end
end
