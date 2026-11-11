defmodule OrigenWeb.ProfessionalAgendaLive do
  @moduledoc """
  Vista LiveView de la agenda diaria del Profesional autenticado (PLN-10 / Issue #80).

  Permite al profesional consultar sus turnos programados del día en orden cronológico,
  navegar entre fechas mediante controles accesibles con teclado, y visualizar estados
  de carga, agenda vacía o errores de carga con soporte responsivo para pantallas angostas.
  """

  use OrigenWeb, :live_view

  alias Origen.Booking
  alias Origen.PatientAccess
  alias Origen.Patients
  alias OrigenWeb.Components.AppointmentLifecycle
  alias OrigenWeb.Components.AgendaAppointmentCard

  @lifecycle_statuses ~w(requested confirmed)

  @impl true
  def mount(_params, _session, socket) do
    date = Date.utc_today()

    {:ok,
     socket
     |> assign(
       selected_appointment: nil,
       page_title: "Agenda Diaria",
       date: date,
       loading: false,
       error: nil,
       appointments: [],
       access_action: nil,
       access_patient_id: nil,
       access_form: nil,
       access_error: nil,
       access_feedback: nil,
       history: [],
       history_error: nil,
       cancellation_appointment_id: nil,
       cancellation_reason: "",
       organization_timezone: Application.fetch_env!(:origen, :organization_timezone),
       lifecycle_statuses: @lifecycle_statuses
     )
     |> load_agenda(date)
     |> load_history()}
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
  def handle_event("open_turn_detail", %{"appointment_id" => id}, socket) do
    appointment =
      Enum.find(socket.assigns.appointments ++ socket.assigns.history, fn appointment ->
        to_string(appointment.id) == id
      end)

    {:noreply, assign(socket, selected_appointment: appointment)}
  end

  def handle_event("close_turn_detail", _params, socket) do
    {:noreply, assign(socket, selected_appointment: nil)}
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
  def handle_event("open_link_access", %{"patient-id" => patient_id}, socket) do
    {:noreply,
     socket
     |> assign(:access_action, :link)
     |> assign(:access_patient_id, patient_id)
     |> assign(:access_form, %{email: ""})
     |> assign(:access_error, nil)}
  end

  @impl true
  def handle_event("open_replace_access", %{"patient-id" => patient_id}, socket) do
    {:noreply,
     socket
     |> assign(:access_action, :replace)
     |> assign(:access_patient_id, patient_id)
     |> assign(:access_form, %{new_email: "", reason: ""})
     |> assign(:access_error, nil)}
  end

  @impl true
  def handle_event("cancel_access_action", _params, socket) do
    {:noreply,
     socket
     |> assign(:access_action, nil)
     |> assign(:access_patient_id, nil)
     |> assign(:access_form, nil)
     |> assign(:access_error, nil)}
  end

  @impl true
  def handle_event("submit_link_access", %{"access" => params}, socket) do
    account_id = socket.assigns.current_internal_session.account_id

    case Patients.link_patient_access_email(
           parse_patient_id(Map.get(params, "patient_id")),
           Map.get(params, "email", ""),
           account_id
         ) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> assign(:access_action, nil)
         |> assign(:access_patient_id, nil)
         |> assign(:access_form, nil)
         |> assign(:access_error, nil)
         |> assign(
           :access_feedback,
           "Correo de acceso vinculado. El paciente debe completar el Magic Link para verificar la posesión."
         )
         |> load_agenda(socket.assigns.date)}

      {:error, reason} ->
        {:noreply, assign(socket, :access_error, access_error_message(reason))}
    end
  end

  @impl true
  def handle_event("submit_replace_access", %{"access" => params}, socket) do
    account_id = socket.assigns.current_internal_session.account_id

    case Patients.replace_patient_access_email(
           parse_patient_id(Map.get(params, "patient_id")),
           Map.get(params, "new_email", ""),
           account_id,
           Map.get(params, "reason", "")
         ) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> assign(:access_action, nil)
         |> assign(:access_patient_id, nil)
         |> assign(:access_form, nil)
         |> assign(:access_error, nil)
         |> assign(
           :access_feedback,
           "Correo de acceso reemplazado. El nuevo correo debe completar el Magic Link para verificar la posesión."
         )
         |> load_agenda(socket.assigns.date)}

      {:error, reason} ->
        {:noreply, assign(socket, :access_error, access_error_message(reason))}
    end
  end

  @impl true
  def handle_event("open_cancellation", %{"appointment_id" => id_str}, socket) do
    case parse_appointment_id(id_str) do
      {:ok, appointment_id} ->
        {:noreply,
         assign(socket,
           cancellation_appointment_id: appointment_id,
           cancellation_reason: ""
         )}

      :error ->
        {:noreply, put_flash(socket, :error, "El identificador del turno no es válido.")}
    end
  end

  @impl true
  def handle_event("cancel_cancellation", _params, socket) do
    {:noreply,
     assign(socket,
       cancellation_appointment_id: nil,
       cancellation_reason: ""
     )}
  end

  @impl true
  def handle_event(
        "submit_cancellation",
        %{"appointment_id" => id_str, "cancellation" => %{"reason" => reason}},
        socket
      ) do
    with {:ok, appointment_id} <- parse_appointment_id(id_str),
         {:ok, _appointment} <-
           Booking.cancel_appointment(
             socket.assigns.current_internal_session,
             appointment_id,
             %{reason: reason}
           ) do
      {:noreply,
       socket
       |> assign(
         cancellation_appointment_id: nil,
         cancellation_reason: ""
       )
       |> put_flash(:info, "Turno cancelado y conservado en el historial.")
       |> load_agenda(socket.assigns.date)
       |> load_history()}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "El identificador del turno no es válido.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, lifecycle_error_message(reason))}
    end
  end

  @impl true
  def handle_event(
        "record_attendance",
        %{"appointment_id" => id_str, "outcome" => outcome},
        socket
      ) do
    case parse_appointment_id(id_str) do
      {:ok, appointment_id} ->
        case Booking.record_attendance(
               socket.assigns.current_internal_session,
               appointment_id,
               outcome
             ) do
          {:ok, _appointment} ->
            label = if outcome == "attended", do: "asistencia", else: "ausencia"

            {:noreply,
             socket
             |> put_flash(:info, "Se registró la #{label} del turno.")
             |> load_agenda(socket.assigns.date)
             |> load_history()}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, lifecycle_error_message(reason))}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "El identificador del turno no es válido.")}
    end
  end

  # Un ID malformado nunca debe tumbar el proceso LiveView: se parsea de forma
  # segura y ante fallo se informa con un mensaje claro y se recarga la agenda
  # para refrescar botones obsoletos.
  defp parse_patient_id(id_str) do
    case Integer.parse(to_string(id_str)) do
      {id, ""} when id > 0 -> id
      _ -> nil
    end
  end

  defp parse_appointment_id(id_str) do
    case Integer.parse(to_string(id_str)) do
      {id, ""} when id > 0 -> {:ok, id}
      _other -> :error
    end
  end

  defp load_history(socket) do
    case Booking.list_appointment_history(socket.assigns.current_internal_session) do
      {:ok, history} -> assign(socket, history: history, history_error: nil)
      {:error, _reason} -> assign(socket, history: [], history_error: :unavailable)
    end
  end

  defp lifecycle_error_message(:cancellation_reason_required),
    do: "Indicá un motivo para cancelar el turno."

  defp lifecycle_error_message(:unauthorized),
    do: "No tenés permiso para operar este turno."

  defp lifecycle_error_message(:invalid_status_transition),
    do: "El estado actual no permite esta operación."

  defp lifecycle_error_message(:appointment_not_found),
    do: "El turno solicitado no fue encontrado."

  defp lifecycle_error_message(:invalid_attendance_outcome),
    do: "El resultado de asistencia no es válido."

  defp lifecycle_error_message(_reason),
    do: "No se pudo actualizar el ciclo del turno."

  defp load_agenda(socket, date) do
    principal = socket.assigns.current_internal_session

    case Booking.get_professional_agenda(principal, %{date: date}) do
      {:ok, %{appointments: appointments}} ->
        appointments =
          Enum.map(appointments, fn appointment ->
            update_in(appointment, [:patient, :access_status], fn _ ->
              PatientAccess.access_status(appointment.patient.email)
            end)
          end)

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
    <OrigenWeb.RoleNavigation.navbar
      role={:professional}
      active="agenda"
      professional_identity={@current_professional_identity}
    />
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

            <.link
              id="create-professional-appointment"
              navigate={~p"/profesional/agenda/crear"}
              class="inline-flex items-center justify-center gap-2 rounded-lg bg-[#0A3847] px-4 py-2 text-sm font-semibold text-white hover:bg-[#12566B] focus-visible:outline-2 focus-visible:outline-offset-2"
            >
              <.icon name="hero-plus" class="size-5" /> Crear turno
            </.link>

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

        <div
          :if={@access_feedback}
          id="professional-access-feedback"
          role="status"
          class="bg-emerald-50 border border-emerald-200 rounded-xl p-4 text-sm text-emerald-800"
        >
          {@access_feedback}
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
          <% primary_appt_by_patient =
            Enum.reduce(@appointments, %{}, fn a, acc ->
              Map.put_new(acc, a.patient.id, a.id)
            end) %>
          <div id="agenda-appointments-list" class="space-y-3" role="list">
            <%= for appt <- @appointments do %>
              <% {status_label, status_classes} = status_badge(appt.status) %>
              <% primary_patient_card? =
                Map.get(primary_appt_by_patient, appt.patient.id) == appt.id %>
              <% patient_dom_key =
                if primary_patient_card?,
                  do: to_string(appt.patient.id),
                  else: "#{appt.patient.id}-#{appt.id}" %>
              <AgendaAppointmentCard.card id={"appointment-#{appt.id}"}>
                <:appointment>
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
                    id={"lifecycle-actions-#{appt.id}"}
                    class="pt-2 flex flex-wrap items-center gap-2"
                  >
                    <button
                      :if={to_string(appt.status) in @lifecycle_statuses}
                      type="button"
                      id={"cancel-appointment-#{appt.id}"}
                      phx-click="open_cancellation"
                      phx-value-appointment_id={appt.id}
                      class="rounded-md border border-rose-300 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-50 focus-visible:outline-2 focus-visible:outline-offset-2"
                    >
                      Cancelar con motivo
                    </button>
                    <button
                      :if={to_string(appt.status) == "confirmed"}
                      type="button"
                      phx-click="record_attendance"
                      phx-value-appointment_id={appt.id}
                      phx-value-outcome="attended"
                      class="rounded-md border border-emerald-300 px-2.5 py-1 text-xs font-semibold text-emerald-800 hover:bg-emerald-50 focus-visible:outline-2 focus-visible:outline-offset-2"
                    >
                      Marcar asistencia
                    </button>
                    <button
                      :if={to_string(appt.status) == "confirmed"}
                      type="button"
                      phx-click="record_attendance"
                      phx-value-appointment_id={appt.id}
                      phx-value-outcome="no_show"
                      class="rounded-md border border-amber-300 px-2.5 py-1 text-xs font-semibold text-amber-800 hover:bg-amber-50 focus-visible:outline-2 focus-visible:outline-offset-2"
                    >
                      Marcar ausencia
                    </button>
                    <OrigenWeb.AppointmentPaymentComponent.detail_button
                      id={"view-turn-#{appt.id}"}
                      appointment_id={appt.id}
                    />
                  </div>

                  <%= if @cancellation_appointment_id == appt.id do %>
                    <.form
                      for={%{}}
                      as={:cancellation}
                      id={"appointment-cancellation-form-#{appt.id}"}
                      phx-submit="submit_cancellation"
                      class="mt-3 space-y-2 rounded-lg border border-rose-100 bg-rose-50 p-3"
                    >
                      <input type="hidden" name="appointment_id" value={appt.id} />
                      <label
                        for={"cancellation-reason-#{appt.id}"}
                        class="block text-xs font-semibold text-rose-900"
                      >
                        Motivo de la cancelación (obligatorio)
                      </label>
                      <textarea
                        id={"cancellation-reason-#{appt.id}"}
                        name="cancellation[reason]"
                        rows="2"
                        required
                        aria-describedby={"cancellation-help-#{appt.id}"}
                        placeholder="Escribí el motivo de la cancelación"
                        class="w-full rounded-md border-rose-200 bg-white text-stone-900 placeholder:text-stone-500 text-sm focus:border-rose-500 focus:ring-rose-500"
                      >{@cancellation_reason}</textarea>
                      <p id={"cancellation-help-#{appt.id}"} class="text-xs text-rose-800">
                        El motivo queda visible en el historial autorizado del turno.
                      </p>
                      <div class="flex flex-wrap gap-2">
                        <button
                          type="submit"
                          class="rounded-md bg-rose-700 px-3 py-2 text-xs font-semibold text-white hover:bg-rose-800 focus-visible:outline-2 focus-visible:outline-offset-2"
                        >
                          Confirmar cancelación
                        </button>
                        <button
                          type="button"
                          phx-click="cancel_cancellation"
                          class="rounded-md border border-stone-300 px-3 py-2 text-xs font-semibold text-stone-700 hover:bg-white focus-visible:outline-2 focus-visible:outline-offset-2"
                        >
                          Volver
                        </button>
                      </div>
                    </.form>
                  <% end %>
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

                  <div :if={appt.patient.email} class="text-xs text-stone-500">
                    Acceso: {appt.patient.email}
                  </div>

                  <% {access_label, access_classes} = access_badge(appt.patient.access_status) %>
                  <div
                    :if={appt.patient.access_status != :verified}
                    id={"patient-access-status-#{patient_dom_key}"}
                    class={"mt-2 inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-semibold " <> access_classes}
                    role="status"
                  >
                    {access_label}
                  </div>

                  <div class="mt-2 flex flex-wrap justify-start sm:justify-end gap-2">
                    <button
                      :if={appt.patient.access_status == :unlinked}
                      type="button"
                      id={"btn-open-link-access-#{patient_dom_key}"}
                      phx-click="open_link_access"
                      phx-value-patient-id={appt.patient.id}
                      class="rounded-md border border-[#0A3847] px-2.5 py-1 text-xs font-semibold text-[#0A3847] hover:bg-stone-50"
                    >
                      Vincular correo
                    </button>
                  </div>

                  <%= if primary_patient_card? and to_string(@access_patient_id) == to_string(appt.patient.id) and @access_action do %>
                    <section
                      id={"patient-access-form-#{patient_dom_key}"}
                      class="mt-3 border-t border-stone-200 pt-3 text-left sm:text-right"
                    >
                      <div
                        :if={@access_error}
                        id={"patient-access-error-#{patient_dom_key}"}
                        role="alert"
                        class="mb-2 text-xs font-medium text-rose-700"
                      >
                        {@access_error}
                      </div>

                      <.form
                        for={%{}}
                        as={:access}
                        id={"patient-access-form-fields-#{patient_dom_key}"}
                        phx-submit={
                          if @access_action == :link,
                            do: "submit_link_access",
                            else: "submit_replace_access"
                        }
                        class="space-y-2"
                      >
                        <input type="hidden" name="access[patient_id]" value={appt.patient.id} />
                        <input
                          :if={@access_action == :link}
                          type="email"
                          name="access[email]"
                          placeholder="paciente@ejemplo.com"
                          required
                          aria-label="Correo de acceso personal"
                          class="w-full rounded-md border-stone-300 text-xs"
                        />
                        <input
                          :if={@access_action == :replace}
                          type="email"
                          name="access[new_email]"
                          placeholder="Nuevo correo personal"
                          required
                          aria-label="Nuevo correo de acceso personal"
                          class="w-full rounded-md border-stone-300 text-xs"
                        />
                        <textarea
                          :if={@access_action == :replace}
                          name="access[reason]"
                          placeholder="Motivo del reemplazo"
                          required
                          aria-label="Motivo del reemplazo"
                          class="w-full rounded-md border-stone-300 text-xs"
                          rows="2"
                        ></textarea>
                        <div class="flex justify-start sm:justify-end gap-2">
                          <button
                            type="button"
                            phx-click="cancel_access_action"
                            class="rounded-md px-2.5 py-1 text-xs text-stone-600 hover:bg-stone-100"
                          >
                            Cancelar
                          </button>
                          <button
                            type="submit"
                            class="rounded-md bg-[#0A3847] px-2.5 py-1 text-xs font-semibold text-white hover:bg-[#12566B]"
                          >
                            {if @access_action == :link,
                              do: "Vincular y enviar enlace",
                              else: "Reemplazar y enviar enlace"}
                          </button>
                        </div>
                      </.form>
                    </section>
                  <% end %>
                </:patient>
              </AgendaAppointmentCard.card>
            <% end %>
          </div>
        <% end %>

        <section id="professional-appointment-history" aria-labelledby="history-heading">
          <div class="mb-3 flex items-center justify-between">
            <div>
              <h2 id="history-heading" class="text-lg font-semibold text-[#0A3847]">
                Historial operativo
              </h2>
              <p class="mt-1 text-sm text-stone-600">
                Consultá los estados y resultados de los turnos de tu propia agenda.
              </p>
            </div>
            <span :if={is_nil(@history_error)} class="text-xs text-stone-500">
              {length(@history)} registros
            </span>
          </div>

          <div
            :if={@history_error}
            id="professional-history-error"
            role="alert"
            class="rounded-xl border border-red-200 bg-white p-6 text-sm text-red-800"
          >
            No se pudo cargar el historial operativo. Volvé a intentar más tarde.
          </div>

          <div
            :if={is_nil(@history_error) and @history == []}
            id="professional-history-empty"
            class="rounded-xl border border-dashed border-stone-300 bg-white p-8 text-center text-sm text-stone-600"
          >
            Todavía no hay registros en el historial de tu agenda.
          </div>

          <div
            :if={is_nil(@history_error) and @history != []}
            id="professional-history-list"
            class="space-y-3"
          >
            <div :for={appointment <- @history}>
              <AppointmentLifecycle.history
                appointment={appointment}
                timezone={@organization_timezone}
                professional_history={true}
              >
                <:actions>
                  <OrigenWeb.AppointmentPaymentComponent.detail_button
                    id={"history-view-turn-#{appointment.id}"}
                    appointment_id={appointment.id}
                  />
                </:actions>
              </AppointmentLifecycle.history>
            </div>
          </div>
          <.live_component
            :if={@selected_appointment}
            module={OrigenWeb.AppointmentPaymentComponent}
            id={"payment-#{@selected_appointment.id}"}
            appointment={@selected_appointment}
            principal={@current_internal_session}
            timezone={@organization_timezone}
          />
        </section>
      </div>
    </div>
    """
  end

  defp format_time(%DateTime{} = dt, timezone) do
    dt |> DateTime.shift_zone!(timezone) |> Calendar.strftime("%H:%M")
  end

  defp format_time(_, _timezone), do: "--:--"

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

  defp access_badge(:unlinked), do: {"Sin acceso", "bg-stone-50 text-stone-700 border-stone-200"}

  defp access_badge(:pending_verification),
    do: {"Pendiente de verificación", "bg-amber-50 text-amber-700 border-amber-200"}

  defp access_badge(:verified),
    do: {"Acceso verificado", "bg-emerald-50 text-emerald-700 border-emerald-200"}

  defp access_badge(_),
    do: {"Estado de acceso desconocido", "bg-stone-50 text-stone-700 border-stone-200"}

  defp access_error_message(:email_already_in_use),
    do: "Este correo ya está registrado por otra cuenta de paciente."

  defp access_error_message(:invalid_email), do: "El formato del correo es inválido."

  defp access_error_message(:already_has_access_email),
    do: "El paciente ya posee un correo de acceso vinculado."

  defp access_error_message(:same_email), do: "El nuevo correo coincide con el correo actual."
  defp access_error_message(:reason_required), do: "Indicá el motivo del reemplazo."
  defp access_error_message(:patient_not_found), do: "No se encontró el paciente."
  defp access_error_message(:unauthorized), do: "No tenés permiso para gestionar este acceso."
  defp access_error_message(_), do: "No se pudo actualizar el correo de acceso."

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
