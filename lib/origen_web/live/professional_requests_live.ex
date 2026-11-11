defmodule OrigenWeb.ProfessionalRequestsLive do
  @moduledoc "Professional-only general pending request resolution, relocated from Agenda (#472)."
  use OrigenWeb, :live_view

  alias Origen.Booking
  alias OrigenWeb.Components.AgendaAppointmentCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Solicitudes",
       loading: false,
       error: nil,
       appointments: [],
       organization_timezone: Application.fetch_env!(:origen, :organization_timezone)
     )
     |> load_requests()}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    {:noreply, load_requests(socket)}
  end

  @impl true
  def handle_event("accept_request", %{"id" => id_str}, socket) do
    case parse_appointment_id(id_str) do
      {:ok, appt_id} ->
        actor = socket.assigns.current_internal_session

        case Booking.accept_request(actor, appt_id) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "Solicitud aceptada y turno confirmado.")
             |> load_requests()}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, resolution_error_message(reason))
             |> load_requests()}
        end

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "El identificador del turno no es válido.")
         |> load_requests()}
    end
  end

  @impl true
  def handle_event("reject_request", %{"id" => id_str}, socket) do
    case parse_appointment_id(id_str) do
      {:ok, appt_id} ->
        actor = socket.assigns.current_internal_session

        case Booking.reject_request(actor, appt_id) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "Solicitud rechazada y horario liberado.")
             |> load_requests()}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, resolution_error_message(reason))
             |> load_requests()}
        end

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "El identificador del turno no es válido.")
         |> load_requests()}
    end
  end

  defp parse_appointment_id(id_str) do
    case Integer.parse(to_string(id_str)) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  # Los motivos de error se mapean a mensajes claros en español; nunca se filtra
  # el término interno (`inspect/1`) hacia la interfaz.

  defp resolution_error_message(:invalid_status_transition),
    do: "La solicitud ya fue procesada o cambió de estado."

  defp resolution_error_message(:appointment_not_found),
    do: "El turno solicitado no fue encontrado."

  defp resolution_error_message(:unauthorized),
    do: "No tenés permiso para resolver esta solicitud."

  defp resolution_error_message(:invalid_approval_mode),
    do: "La modalidad de aprobación seleccionada no es válida."

  defp resolution_error_message(:invalid_secretary_approval_mode),
    do: "La subconfiguración de Secretaría seleccionada no es válida."

  defp resolution_error_message(_other),
    do: "No se pudo procesar la solicitud."

  defp load_requests(socket) do
    case Booking.list_professional_pending_requests(socket.assigns.current_internal_session) do
      {:ok, appointments} ->
        assign(socket, loading: false, error: nil, appointments: appointments)

      {:error, _} ->
        assign(socket, loading: false, error: :unavailable, appointments: [])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <OrigenWeb.RoleNavigation.navbar
      role={:professional}
      active="requests"
      professional_identity={@current_professional_identity}
    />
    <div class="min-h-screen bg-[#F6F6F4] py-6 sm:py-8 px-4 sm:px-6 lg:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <!-- Mensajes de resultado de la resolución de solicitudes -->
        <div
          :if={Phoenix.Flash.get(@flash, :error)}
          id="requests-flash-error"
          role="alert"
          class="p-4 rounded-xl bg-red-50 text-red-800 text-sm flex items-center gap-2 border border-red-200"
        >
          <.icon name="hero-exclamation-circle" class="w-5 h-5 text-red-600 shrink-0" />
          <span>{Phoenix.Flash.get(@flash, :error)}</span>
        </div>

        <div
          :if={Phoenix.Flash.get(@flash, :info)}
          id="requests-flash-info"
          role="status"
          class="p-4 rounded-xl bg-emerald-50 text-emerald-800 text-sm flex items-center gap-2 border border-emerald-200"
        >
          <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 shrink-0" />
          <span>{Phoenix.Flash.get(@flash, :info)}</span>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-5 sm:p-6">
          <h1 class="text-2xl font-bold text-[#0A3847]">Solicitudes</h1>
          <p class="text-sm text-stone-600 mt-0.5">
            Todas las solicitudes pendientes, ordenadas por fecha y hora del turno.
          </p>
        </div>

        <!-- Estado de error -->
        <%= if @error do %>
          <div
            id="requests-error-state"
            role="alert"
            class="bg-red-50 border border-red-200 rounded-xl p-6 text-center space-y-3"
          >
            <.icon name="hero-exclamation-triangle" class="w-10 h-10 text-red-600 mx-auto" />
            <h2 class="text-base font-semibold text-red-900">
              No pudimos cargar las solicitudes
            </h2>
            <p class="text-sm text-red-700 max-w-md mx-auto">
              Ocurrió un problema al consultar las solicitudes. Por favor, intentá nuevamente.
            </p>
            <div>
              <button
                type="button"
                phx-click="retry"
                class="px-4 py-2 text-sm font-semibold rounded-lg bg-red-600 text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-1 transition"
              >
                Reintentar
              </button>
            </div>
          </div>
        <% end %>

        <!-- Estado vacío -->
        <%= if is_nil(@error) and @appointments == [] do %>
          <div
            id="requests-empty-state"
            class="bg-white border border-stone-200 rounded-xl p-10 text-center space-y-3 shadow-sm"
          >
            <.icon name="hero-calendar" class="w-12 h-12 text-stone-400 mx-auto" />
            <h2 class="text-lg font-semibold text-stone-800">
              No hay solicitudes pendientes
            </h2>
            <p class="text-sm text-stone-500 max-w-sm mx-auto">
              No tenés solicitudes pendientes de aprobación.
            </p>
          </div>
        <% end %>

        <div
          :if={is_nil(@error) and @appointments != []}
          id="requests-list"
          class="space-y-3"
          role="list"
        >
          <%= for appt <- @appointments do %>
            <% {status_label, status_classes} = status_badge(appt.status) %>
            <AgendaAppointmentCard.card id={"appointment-#{appt.id}"}>
              <:appointment>
                <time
                  datetime={DateTime.to_iso8601(appt.start_time)}
                  class="text-sm font-semibold text-stone-700"
                >{format_datetime(appt.start_time, @organization_timezone)}</time>
                <div class="flex items-center gap-2.5">
                  <span class="text-lg font-bold text-[#0A3847]">
                    {format_time(appt.start_time, @organization_timezone)} - {format_time(
                      appt.end_time,
                      @organization_timezone
                    )}
                  </span>
                  <span class={"text-xs font-semibold px-2.5 py-0.5 rounded-full border " <> status_classes}>
                    {status_label}
                  </span>
                </div>

                <p class="text-xs sm:text-sm font-medium text-stone-700">
                  {appt.consultation_type_name}
                  <span class="text-stone-400 font-normal">
                    • {appt.duration_minutes} min
                  </span>
                </p>

                <div
                  :if={to_string(appt.status) == "requested"}
                  id={"request-actions-#{appt.id}"}
                  class="pt-2 flex items-center gap-2"
                >
                  <button
                    type="button"
                    id={"accept-request-#{appt.id}"}
                    phx-click="accept_request"
                    phx-value-id={appt.id}
                    class="px-2.5 py-1 text-xs font-semibold rounded bg-emerald-600 text-white hover:bg-emerald-700 shadow-sm transition"
                  >
                    Aceptar
                  </button>
                  <button
                    type="button"
                    id={"reject-request-#{appt.id}"}
                    phx-click="reject_request"
                    phx-value-id={appt.id}
                    class="px-2.5 py-1 text-xs font-semibold rounded border border-rose-300 text-rose-700 bg-white hover:bg-rose-50 shadow-sm transition"
                  >
                    Rechazar
                  </button>
                </div>
              </:appointment>
              <:patient>
                <div class="text-xs text-stone-400 font-medium">Paciente</div>
                <div class="text-sm font-semibold text-stone-900">
                  {appt.patient.name}
                </div>
                <%= if appt.patient.document_number do %>
                  <div class="text-xs text-stone-500">
                    {format_document_type(appt.patient.document_type)}: {appt.patient.document_number}
                  </div>
                <% end %>
              </:patient>
            </AgendaAppointmentCard.card>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_time(%DateTime{} = dt, timezone) do
    dt |> DateTime.shift_zone!(timezone) |> Calendar.strftime("%H:%M")
  end

  defp format_time(_, _timezone), do: "--:--"

  defp format_datetime(%DateTime{} = dt, timezone) do
    dt |> DateTime.shift_zone!(timezone) |> Calendar.strftime("%d/%m/%Y %H:%M")
  end

  defp status_badge(status) do
    case to_string(status) do
      "reserved" -> {"Reservado", "bg-sky-50 text-sky-700 border-sky-200"}
      "confirmed" -> {"Confirmado", "bg-emerald-50 text-emerald-700 border-emerald-200"}
      "attended" -> {"Atendido", "bg-stone-100 text-stone-700 border-stone-300"}
      "expired" -> {"Vencido", "bg-stone-100 text-stone-700 border-stone-300"}
      "cancelled" -> {"Cancelado", "bg-rose-50 text-rose-700 border-rose-200"}
      "no_show" -> {"Ausente", "bg-amber-50 text-amber-700 border-amber-200"}
      "requested" -> {"Solicitado", "bg-indigo-50 text-indigo-700 border-indigo-200"}
      other -> {String.capitalize(other), "bg-stone-50 text-stone-700 border-stone-200"}
    end
  end

  defp format_document_type(type) do
    case to_string(type) do
      "dni" -> "DNI"
      "passport" -> "Pasaporte"
      "identity_card" -> "Cédula"
      other -> String.upcase(other)
    end
  end
end
