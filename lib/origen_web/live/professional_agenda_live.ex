defmodule OrigenWeb.ProfessionalAgendaLive do
  @moduledoc """
  Vista LiveView de la agenda diaria del Profesional autenticado (PLN-10 / Issue #80).

  Permite al profesional consultar sus turnos programados del día en orden cronológico,
  navegar entre fechas mediante controles accesibles con teclado, y visualizar estados
  de carga, agenda vacía o errores de carga con soporte responsivo para pantallas angostas.
  """

  use OrigenWeb, :live_view

  alias Origen.Booking

  @impl true
  def mount(_params, _session, socket) do
    date = Date.utc_today()
    approval_config = load_approval_config(socket.assigns[:current_internal_session])

    {:ok,
     socket
     |> assign(
       page_title: "Agenda Diaria",
       date: date,
       loading: false,
       error: nil,
       appointments: [],
       approval_config: approval_config
     )
     |> load_agenda(date)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case Map.get(params, "date") do
      nil ->
        {:noreply, socket}

      date_str when is_binary(date_str) ->
        case Date.from_iso8601(date_str) do
          {:ok, parsed_date} ->
            {:noreply, load_agenda(socket, parsed_date)}

          {:error, _} ->
            {:noreply, assign(socket, error: :invalid_date, appointments: [], loading: false)}
        end
    end
  end

  @impl true
  def handle_event("change_date", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, parsed_date} ->
        {:noreply,
         push_patch(socket, to: ~p"/profesional/agenda?date=#{Date.to_iso8601(parsed_date)}")}

      {:error, _} ->
        {:noreply, assign(socket, error: :invalid_date, appointments: [], loading: false)}
    end
  end

  def handle_event("prev_day", _params, socket) do
    new_date = Date.add(socket.assigns.date, -1)
    {:noreply, push_patch(socket, to: ~p"/profesional/agenda?date=#{Date.to_iso8601(new_date)}")}
  end

  def handle_event("next_day", _params, socket) do
    new_date = Date.add(socket.assigns.date, 1)
    {:noreply, push_patch(socket, to: ~p"/profesional/agenda?date=#{Date.to_iso8601(new_date)}")}
  end

  def handle_event("today", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/profesional/agenda?date=#{Date.to_iso8601(Date.utc_today())}")}
  end

  def handle_event("retry", _params, socket) do
    {:noreply, load_agenda(socket, socket.assigns.date)}
  end

  @impl true
  def handle_event("accept_request", %{"id" => id_str}, socket) do
    case parse_appointment_id(id_str) do
      {:ok, appt_id} ->
        actor_id = socket.assigns.current_internal_session.account_id

        case Booking.accept_request(actor_id, appt_id) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "Solicitud aceptada y turno confirmado.")
             |> load_agenda(socket.assigns.date)}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, resolution_error_message(reason))
             |> load_agenda(socket.assigns.date)}
        end

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "El identificador del turno no es válido.")
         |> load_agenda(socket.assigns.date)}
    end
  end

  @impl true
  def handle_event("reject_request", %{"id" => id_str}, socket) do
    case parse_appointment_id(id_str) do
      {:ok, appt_id} ->
        actor_id = socket.assigns.current_internal_session.account_id

        case Booking.reject_request(actor_id, appt_id) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "Solicitud rechazada y horario liberado.")
             |> load_agenda(socket.assigns.date)}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, resolution_error_message(reason))
             |> load_agenda(socket.assigns.date)}
        end

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "El identificador del turno no es válido.")
         |> load_agenda(socket.assigns.date)}
    end
  end

  @impl true
  def handle_event("update_approval_config", params, socket) do
    actor_id = socket.assigns.current_internal_session.account_id

    attrs = %{
      approval_mode: Map.get(params, "approval_mode"),
      secretary_approval_mode: Map.get(params, "secretary_approval_mode")
    }

    case Booking.update_approval_configuration(actor_id, attrs) do
      {:ok, config} ->
        {:noreply,
         socket
         |> assign(:approval_config, config)
         |> put_flash(
           :info,
           "Configuración de aprobación actualizada. Las solicitudes pendientes existentes conservan su estado."
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, resolution_error_message(reason))}
    end
  end

  defp load_approval_config(%{account_id: account_id}) when is_integer(account_id) do
    case Booking.get_approval_configuration(account_id) do
      {:ok, config} -> config
      _ -> %{approval_mode: :automatic, secretary_approval_mode: :confirmed}
    end
  end

  defp load_approval_config(_),
    do: %{approval_mode: :automatic, secretary_approval_mode: :confirmed}

  # Un ID malformado nunca debe tumbar el proceso LiveView: se parsea de forma
  # segura y ante fallo se informa con un mensaje claro y se recarga la agenda
  # para refrescar botones obsoletos.
  defp parse_appointment_id(id_str) do
    case Integer.parse(to_string(id_str)) do
      {id, ""} when id > 0 -> {:ok, id}
      _other -> :error
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

  defp load_agenda(socket, date) do
    principal = socket.assigns.current_internal_session

    case Booking.get_professional_agenda(principal, %{date: date}) do
      {:ok, %{appointments: appointments}} ->
        assign(socket,
          date: date,
          appointments: appointments,
          error: nil,
          loading: false
        )

      {:error, :invalid_date} ->
        assign(socket,
          date: date,
          appointments: [],
          error: :invalid_date,
          loading: false
        )

      {:error, _reason} ->
        assign(socket,
          date: date,
          appointments: [],
          error: :unavailable,
          loading: false
        )
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#F6F6F4] py-6 sm:py-8 px-4 sm:px-6 lg:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <!-- Mensajes de resultado de la resolución de solicitudes -->
        <div
          :if={Phoenix.Flash.get(@flash, :error)}
          id="agenda-flash-error"
          role="alert"
          class="p-4 rounded-xl bg-red-50 text-red-800 text-sm flex items-center gap-2 border border-red-200"
        >
          <.icon name="hero-exclamation-circle" class="w-5 h-5 text-red-600 shrink-0" />
          <span>{Phoenix.Flash.get(@flash, :error)}</span>
        </div>

        <div
          :if={Phoenix.Flash.get(@flash, :info)}
          id="agenda-flash-info"
          role="status"
          class="p-4 rounded-xl bg-emerald-50 text-emerald-800 text-sm flex items-center gap-2 border border-emerald-200"
        >
          <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 shrink-0" />
          <span>{Phoenix.Flash.get(@flash, :info)}</span>
        </div>

        <!-- Header con navegación por fecha -->
        <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-5 sm:p-6 space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold text-[#0A3847]">Agenda Diaria</h1>
              <p class="text-sm text-stone-600 mt-0.5">
                {format_date_spanish(@date)}
              </p>
            </div>

            <!-- Controles de navegación de fecha -->
            <div class="flex items-center gap-2 flex-wrap">
              <button
                type="button"
                phx-click="prev_day"
                aria-label="Día anterior"
                class="inline-flex items-center justify-center p-2 rounded-lg border border-stone-300 text-stone-700 bg-white hover:bg-stone-50 focus:outline-none focus:ring-2 focus:ring-[#0A3847] focus:ring-offset-1 transition"
              >
                <.icon name="hero-chevron-left" class="w-5 h-5" />
              </button>

              <button
                type="button"
                id="btn-today-nav"
                phx-click="today"
                aria-label="Ir a hoy"
                class="px-3 py-2 text-xs sm:text-sm font-medium rounded-lg border border-stone-300 text-stone-700 bg-white hover:bg-stone-50 focus:outline-none focus:ring-2 focus:ring-[#0A3847] focus:ring-offset-1 transition"
              >
                Hoy
              </button>

              <form id="agenda-date-form" phx-change="change_date" class="inline-block">
                <input
                  type="date"
                  name="date"
                  value={Date.to_iso8601(@date)}
                  aria-label="Seleccionar fecha de agenda"
                  class="text-xs sm:text-sm rounded-lg border-stone-300 py-1.5 px-2.5 text-stone-800 focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847] transition"
                />
              </form>

              <button
                type="button"
                phx-click="next_day"
                aria-label="Día siguiente"
                class="inline-flex items-center justify-center p-2 rounded-lg border border-stone-300 text-stone-700 bg-white hover:bg-stone-50 focus:outline-none focus:ring-2 focus:ring-[#0A3847] focus:ring-offset-1 transition"
              >
                <.icon name="hero-chevron-right" class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>

        <!-- Configuración de modalidad de aprobación y regla de Secretaría (#323) -->
        <div
          id="approval-config-panel"
          class="bg-white rounded-xl shadow-sm border border-stone-200 p-5 sm:p-6 space-y-4"
        >
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
            <div>
              <h2 class="text-base font-bold text-[#0A3847]">
                Modalidad de aprobación de reservas
              </h2>
              <p
                id="approval-mode-notice"
                class="text-xs text-stone-500 mt-0.5"
              >
                El cambio de modalidad aplica únicamente a reservas nuevas y no resuelve automáticamente las solicitudes pendientes existentes.
              </p>
            </div>
          </div>

          <form
            id="approval-config-form"
            phx-change="update_approval_config"
            class="grid grid-cols-1 sm:grid-cols-2 gap-4"
          >
            <div>
              <label
                for="select-approval-mode"
                class="block text-xs font-semibold text-stone-700 mb-1"
              >
                Modalidad general
              </label>
              <select
                id="select-approval-mode"
                name="approval_mode"
                class="w-full text-xs sm:text-sm rounded-lg border-stone-300 py-2 px-3 text-stone-800 focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847] transition"
              >
                <option
                  value="automatic"
                  selected={@approval_config.approval_mode == :automatic}
                >
                  Automática (confirma nuevas reservas)
                </option>
                <option
                  value="manual"
                  selected={@approval_config.approval_mode == :manual}
                >
                  Manual (solicitudes requieren aprobación)
                </option>
              </select>
            </div>

            <div>
              <label
                for="select-secretary-approval-mode"
                class="block text-xs font-semibold text-stone-700 mb-1"
              >
                Regla para Secretaría (en modo manual)
              </label>
              <select
                id="select-secretary-approval-mode"
                name="secretary_approval_mode"
                class="w-full text-xs sm:text-sm rounded-lg border-stone-300 py-2 px-3 text-stone-800 focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847] transition"
              >
                <option
                  value="confirmed"
                  selected={@approval_config.secretary_approval_mode == :confirmed}
                >
                  Secretaría confirma directamente
                </option>
                <option
                  value="requested"
                  selected={@approval_config.secretary_approval_mode == :requested}
                >
                  Secretaría deja pendiente de aprobación
                </option>
              </select>
            </div>
          </form>
        </div>

        <!-- Estado de error -->
        <%= if @error do %>
          <div
            id="agenda-error-state"
            role="alert"
            class="bg-red-50 border border-red-200 rounded-xl p-6 text-center space-y-3"
          >
            <.icon name="hero-exclamation-triangle" class="w-10 h-10 text-red-600 mx-auto" />
            <h2 class="text-base font-semibold text-red-900">
              <%= if @error == :invalid_date do %>
                Fecha no válida
              <% else %>
                No pudimos cargar la agenda
              <% end %>
            </h2>
            <p class="text-sm text-red-700 max-w-md mx-auto">
              <%= if @error == :invalid_date do %>
                Por favor, seleccioná una fecha en formato válido para continuar.
              <% else %>
                Ocurrió un problema al consultar los turnos. Por favor, intentá nuevamente.
              <% end %>
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
            id="agenda-empty-state"
            class="bg-white border border-stone-200 rounded-xl p-10 text-center space-y-3 shadow-sm"
          >
            <.icon name="hero-calendar" class="w-12 h-12 text-stone-400 mx-auto" />
            <h2 class="text-lg font-semibold text-stone-800">
              No hay turnos programados
            </h2>
            <p class="text-sm text-stone-500 max-w-sm mx-auto">
              No se encontraron turnos para esta fecha. Podés navegar a otro día utilizando los controles superiores.
            </p>
            <div class="pt-2">
              <button
                type="button"
                phx-click="today"
                class="px-3.5 py-2 text-xs font-semibold rounded-lg border border-stone-300 text-stone-700 hover:bg-stone-50 transition"
              >
                Volver a hoy
              </button>
            </div>
          </div>
        <% end %>

        <!-- Listado cronológico de turnos -->
        <%= if is_nil(@error) and @appointments != [] do %>
          <div id="agenda-appointments-list" class="space-y-3" role="list">
            <%= for appt <- @appointments do %>
              <% {status_label, status_classes} = status_badge(appt.status) %>
              <div
                id={"appointment-#{appt.id}"}
                role="listitem"
                class="bg-white rounded-xl shadow-sm border border-stone-200 p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 hover:border-stone-300 transition"
              >
                <!-- Horario y tipo de consulta -->
                <div class="space-y-1">
                  <div class="flex items-center gap-2.5">
                    <span class="text-lg font-bold text-[#0A3847]">
                      {format_time(appt.start_time)} - {format_time(appt.end_time)}
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
                </div>

                <!-- Datos no clínicos del Paciente -->
                <div class="text-left sm:text-right border-t sm:border-t-0 pt-3 sm:pt-0 border-stone-100 space-y-0.5">
                  <div class="text-xs text-stone-400 font-medium">Paciente</div>
                  <div class="text-sm font-semibold text-stone-900">
                    {appt.patient.name}
                  </div>
                  <%= if appt.patient.document_number do %>
                    <div class="text-xs text-stone-500">
                      {format_document_type(appt.patient.document_type)}: {appt.patient.document_number}
                    </div>
                  <% end %>
                  <%= if appt.patient.phone do %>
                    <div class="text-xs text-stone-500">
                      Tel: {appt.patient.phone}
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  defp format_time(_), do: "--:--"

  defp format_date_spanish(%Date{} = d) do
    day_name =
      case Date.day_of_week(d) do
        1 -> "Lunes"
        2 -> "Martes"
        3 -> "Miércoles"
        4 -> "Jueves"
        5 -> "Viernes"
        6 -> "Sábado"
        7 -> "Domingo"
      end

    month_name =
      case d.month do
        1 -> "enero"
        2 -> "febrero"
        3 -> "marzo"
        4 -> "abril"
        5 -> "mayo"
        6 -> "junio"
        7 -> "julio"
        8 -> "agosto"
        9 -> "septiembre"
        10 -> "octubre"
        11 -> "noviembre"
        12 -> "diciembre"
      end

    "#{day_name}, #{d.day} de #{month_name} de #{d.year}"
  end

  defp status_badge(status) do
    case to_string(status) do
      "reserved" -> {"Reservado", "bg-sky-50 text-sky-700 border-sky-200"}
      "confirmed" -> {"Confirmado", "bg-emerald-50 text-emerald-700 border-emerald-200"}
      "attended" -> {"Atendido", "bg-stone-100 text-stone-700 border-stone-300"}
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
