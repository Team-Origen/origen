defmodule OrigenWeb.SecretaryAgendaLive do
  @moduledoc """
  Centro de agendas operativas para la Secretaría.

  La pantalla consulta el historial operativo con el principal interno
  revalidado por `InternalAuthLive`; no resuelve solicitudes pendientes y
  delega todas las transiciones al contexto `Origen.Booking`.
  """

  use OrigenWeb, :live_view

  on_mount {OrigenWeb.InternalAuthLive, :ensure_authenticated}

  alias Origen.Appointments.Calendar, as: AppointmentCalendar
  alias Origen.Booking
  alias OrigenWeb.Components.AppointmentLifecycle

  @lifecycle_statuses ~w(requested confirmed)

  defp secretary_identity(principal) do
    case Origen.Accounts.get_own_navigation_identity(principal) do
      {:ok, identity} -> identity
      {:error, _} -> nil
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_role == :secretary do
      {:ok,
       socket
       |> assign(:secretary_identity, secretary_identity(socket.assigns.current_internal_session))
       |> assign(
         selected_appointment: nil,
         page_title: "Agenda del centro",
         date: organization_today(),
         appointments: [],
         history: [],
         history_error: nil,
         cancellation_appointment_id: nil,
         cancellation_reason: "",
         feedback: nil,
         organization_timezone: Application.fetch_env!(:origen, :organization_timezone),
         professional_names: %{},
         lifecycle_statuses: @lifecycle_statuses
       )
       |> load_history()}
    else
      {:ok, redirect(socket, to: "/")}
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
  def handle_event("change_date", %{"date" => date}, socket) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> {:noreply, assign(socket, date: parsed_date) |> load_history()}
      {:error, _} -> {:noreply, put_flash(socket, :error, "La fecha de la agenda no es válida.")}
    end
  end

  def handle_event("prev_day", _params, socket), do: move_date(socket, -1)
  def handle_event("next_day", _params, socket), do: move_date(socket, 1)

  def handle_event("today", _params, socket) do
    {:noreply, assign(socket, date: organization_today()) |> load_history()}
  end

  def handle_event("retry", _params, socket), do: {:noreply, load_history(socket)}

  def handle_event("open_cancellation", %{"appointment_id" => id}, socket) do
    case parse_id(id) do
      {:ok, appointment_id} ->
        {:noreply,
         assign(socket, cancellation_appointment_id: appointment_id, cancellation_reason: "")}

      :error ->
        {:noreply, put_flash(socket, :error, "El identificador del turno no es válido.")}
    end
  end

  def handle_event("cancel_cancellation", _params, socket) do
    {:noreply, assign(socket, cancellation_appointment_id: nil, cancellation_reason: "")}
  end

  def handle_event(
        "submit_cancellation",
        %{"appointment_id" => id, "cancellation" => %{"reason" => reason}},
        socket
      ) do
    with {:ok, appointment_id} <- parse_id(id),
         {:ok, _appointment} <-
           Booking.cancel_appointment(
             socket.assigns.current_internal_session,
             appointment_id,
             %{reason: reason}
           ) do
      {:noreply,
       socket
       |> assign(cancellation_appointment_id: nil, cancellation_reason: "")
       |> put_flash(:info, "Turno cancelado y conservado en el historial.")
       |> load_history()}
    else
      :error -> {:noreply, put_flash(socket, :error, "El identificador del turno no es válido.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, lifecycle_error_message(reason))}
    end
  end

  def handle_event(
        "record_attendance",
        %{"appointment_id" => id, "outcome" => outcome},
        socket
      ) do
    with {:ok, appointment_id} <- parse_id(id),
         {:ok, _appointment} <-
           Booking.record_attendance(
             socket.assigns.current_internal_session,
             appointment_id,
             outcome
           ) do
      label = if outcome == "attended", do: "asistencia", else: "ausencia"

      {:noreply,
       socket
       |> put_flash(:info, "Se registró la #{label} del turno.")
       |> load_history()}
    else
      :error -> {:noreply, put_flash(socket, :error, "El identificador del turno no es válido.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, lifecycle_error_message(reason))}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp move_date(socket, days) do
    {:noreply, assign(socket, date: Date.add(socket.assigns.date, days)) |> load_history()}
  end

  defp load_history(socket) do
    case Booking.list_appointment_history(socket.assigns.current_internal_session) do
      {:ok, history} ->
        assign(socket,
          history: history,
          appointments: Enum.filter(history, &same_date?(&1.start_time, socket.assigns.date)),
          history_error: nil,
          professional_names: professional_names()
        )

      {:error, _reason} ->
        assign(socket, history: [], appointments: [], history_error: :unavailable)
    end
  end

  defp professional_names do
    case AppointmentCalendar.list_professionals() do
      {:ok, professionals} ->
        Map.new(professionals, fn professional ->
          {to_string(professional.id), professional.name}
        end)

      {:error, _reason} ->
        %{}
    end
  end

  defp same_date?(%DateTime{} = datetime, %Date{} = date) do
    DateTime.shift_zone!(datetime, organization_timezone()) |> DateTime.to_date() == date
  end

  defp same_date?(_datetime, _date), do: false

  defp organization_today do
    organization_timezone() |> DateTime.now!() |> DateTime.to_date()
  end

  defp organization_timezone, do: Application.fetch_env!(:origen, :organization_timezone)

  defp professional_name(%{professional_name: name}, _names), do: name

  defp professional_name(appointment, names),
    do:
      Map.get(
        names,
        to_string(appointment.professional_account_id),
        "Profesional no identificado"
      )

  defp patient_identifier(%{patient_name: name}), do: name

  defp patient_identifier(_appointment), do: "Paciente no identificado"

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_id(_value), do: :error

  defp lifecycle_error_message(:cancellation_reason_required),
    do: "Indicá un motivo para cancelar el turno."

  defp lifecycle_error_message(:unauthorized), do: "No tenés permiso para operar este turno."

  defp lifecycle_error_message(:invalid_status_transition),
    do: "El estado actual no permite esta operación."

  defp lifecycle_error_message(:appointment_not_found),
    do: "El turno solicitado no fue encontrado."

  defp lifecycle_error_message(:invalid_attendance_outcome),
    do: "El resultado de asistencia no es válido."

  defp lifecycle_error_message(_reason), do: "No se pudo actualizar el ciclo del turno."

  defp status_badge(status) do
    case to_string(status) do
      "requested" -> {"Pendiente de aprobación", "bg-amber-50 text-amber-800 border-amber-200"}
      "confirmed" -> {"Confirmado", "bg-emerald-50 text-emerald-800 border-emerald-200"}
      "expired" -> {"Vencido", "bg-stone-100 text-stone-700 border-stone-300"}
      "cancelled" -> {"Cancelado", "bg-rose-50 text-rose-800 border-rose-200"}
      "attended" -> {"Asistió", "bg-blue-50 text-blue-800 border-blue-200"}
      "no_show" -> {"No asistió", "bg-blue-50 text-blue-800 border-blue-200"}
      other -> {String.capitalize(other), "bg-stone-50 text-stone-700 border-stone-200"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#F6F6F4] font-inter">
      <OrigenWeb.RoleNavigation.navbar
        role={:secretary}
        active="agenda"
        secretary_identity={@secretary_identity}
      />

      <main class="mx-auto max-w-5xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
        <header class="rounded-xl border border-stone-200 bg-white p-6 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wider text-[#35545A]">Secretaría</p>
          <h1 class="mt-1 text-2xl font-bold text-[#0A3847]">Agenda del centro</h1>
          <p class="mt-2 text-sm text-stone-600">
            Operá turnos de todas las agendas del centro. Las solicitudes pendientes no se aceptan ni se rechazan desde acá.
          </p>
        </header>

        <div
          :if={Phoenix.Flash.get(@flash, :error)}
          id="secretary-agenda-error"
          role="alert"
          class="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800"
        >
          {Phoenix.Flash.get(@flash, :error)}
        </div>
        <div
          :if={Phoenix.Flash.get(@flash, :info)}
          id="secretary-agenda-info"
          role="status"
          class="rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900"
        >
          {Phoenix.Flash.get(@flash, :info)}
        </div>

        <section
          class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm"
          aria-labelledby="secretary-agenda-date-heading"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 id="secretary-agenda-date-heading" class="text-lg font-semibold text-[#0A3847]">
                Agenda del día
              </h2>
              <p class="text-sm text-stone-600">{format_date(@date)}</p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <button
                type="button"
                phx-click="prev_day"
                aria-label="Día anterior"
                class="rounded-lg border border-stone-300 px-3 py-2 text-sm text-stone-700 hover:bg-stone-50"
              >Anterior</button>
              <button
                type="button"
                phx-click="today"
                class="rounded-lg border border-stone-300 px-3 py-2 text-sm text-stone-700 hover:bg-stone-50"
              >Hoy</button>
              <form id="secretary-agenda-date-form" phx-change="change_date">
                <label class="sr-only" for="secretary-agenda-date">Seleccionar fecha</label>
                <input
                  id="secretary-agenda-date"
                  type="date"
                  name="date"
                  value={Date.to_iso8601(@date)}
                  class="rounded-lg border-stone-300 bg-white px-3 py-2 text-sm text-stone-900 [color-scheme:light]"
                />
              </form>
              <button
                type="button"
                phx-click="next_day"
                aria-label="Día siguiente"
                class="rounded-lg border border-stone-300 px-3 py-2 text-sm text-stone-700 hover:bg-stone-50"
              >Siguiente</button>
            </div>
          </div>
        </section>

        <section
          :if={@history_error}
          id="secretary-agenda-history-error"
          role="alert"
          class="rounded-xl border border-red-200 bg-white p-6 text-sm text-red-800"
        >
          No se pudo cargar el historial operativo. Volvé a intentar más tarde.
          <button type="button" phx-click="retry" class="ml-2 font-semibold underline">Reintentar</button>
        </section>

        <section :if={is_nil(@history_error)} aria-labelledby="secretary-day-heading">
          <div class="mb-3 flex items-center justify-between">
            <div>
              <h2 id="secretary-day-heading" class="text-lg font-semibold text-[#0A3847]">
                Turnos del centro
              </h2>
              <p class="text-sm text-stone-600">Todas las agendas, ordenadas por horario.</p>
            </div>
            <span class="text-xs text-stone-500">{length(@appointments)} registros</span>
          </div>

          <div
            :if={@appointments == []}
            id="secretary-agenda-empty"
            class="rounded-xl border border-dashed border-stone-300 bg-white p-8 text-center text-sm text-stone-600"
          >
            No hay turnos para esta fecha.
          </div>

          <div :if={@appointments != []} id="secretary-agenda-list" class="space-y-3">
            <article
              :for={appointment <- @appointments}
              id={"secretary-appointment-#{appointment.id}"}
              class="rounded-xl border border-stone-200 bg-white p-4 shadow-sm"
            >
              <% {label, classes} = status_badge(appointment.status) %>
              <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h3 class="font-semibold text-stone-900">{appointment.consultation_type_name}</h3>
                  <p
                    id={"secretary-patient-#{appointment.id}"}
                    class="mt-1 text-sm font-medium text-stone-700"
                  >
                    {patient_identifier(appointment)}
                  </p>
                  <p class="mt-1 text-sm text-stone-600">
                    {local_time(appointment.start_time, @organization_timezone, "%d/%m/%Y · %H:%M")} a {local_time(
                      appointment.end_time,
                      @organization_timezone,
                      "%H:%M"
                    )} hs
                  </p>
                  <p class="mt-1 text-xs text-stone-500">
                    Profesional: {professional_name(appointment, @professional_names)}
                  </p>
                </div>
                <span class={"inline-flex w-fit rounded-full border px-3 py-1 text-xs font-semibold " <> classes}>{label}</span>
              </div>

              <div class="mt-4 flex flex-wrap gap-2 border-t border-stone-100 pt-4">
                <button
                  :if={to_string(appointment.status) in @lifecycle_statuses}
                  type="button"
                  id={"cancel-appointment-#{appointment.id}"}
                  phx-click="open_cancellation"
                  phx-value-appointment_id={appointment.id}
                  class="rounded-md border border-rose-300 px-3 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-50"
                >Cancelar con motivo</button>
                <button
                  :if={to_string(appointment.status) == "confirmed"}
                  type="button"
                  phx-click="record_attendance"
                  phx-value-appointment_id={appointment.id}
                  phx-value-outcome="attended"
                  class="rounded-md border border-emerald-300 px-3 py-2 text-xs font-semibold text-emerald-800 hover:bg-emerald-50"
                >Marcar asistencia</button>
                <button
                  :if={to_string(appointment.status) == "confirmed"}
                  type="button"
                  phx-click="record_attendance"
                  phx-value-appointment_id={appointment.id}
                  phx-value-outcome="no_show"
                  class="rounded-md border border-amber-300 px-3 py-2 text-xs font-semibold text-amber-800 hover:bg-amber-50"
                >Marcar ausencia</button>
                <OrigenWeb.AppointmentPaymentComponent.detail_button
                  id={"view-turn-#{appointment.id}"}
                  appointment_id={appointment.id}
                />
              </div>

              <.form
                :if={@cancellation_appointment_id == appointment.id}
                for={%{}}
                as={:cancellation}
                id={"appointment-cancellation-form-#{appointment.id}"}
                phx-submit="submit_cancellation"
                class="mt-3 space-y-2 rounded-lg border border-rose-100 bg-rose-50 p-3"
              >
                <input type="hidden" name="appointment_id" value={appointment.id} />
                <p
                  id={"cancellation-patient-#{appointment.id}"}
                  class="text-sm font-semibold text-rose-900"
                >
                  {patient_identifier(appointment)}
                </p>
                <label
                  for={"cancellation-reason-#{appointment.id}"}
                  class="block text-xs font-semibold text-rose-900"
                >Motivo de la cancelación (obligatorio)</label>
                <textarea
                  id={"cancellation-reason-#{appointment.id}"}
                  name="cancellation[reason]"
                  rows="2"
                  required
                  placeholder="Escribí el motivo de la cancelación"
                  class="w-full rounded-md border-rose-200 bg-white text-stone-900 placeholder:text-stone-500 text-sm"
                ></textarea>
                <p class="text-xs text-rose-800">
                  El motivo queda visible en el historial autorizado del paciente.
                </p>
                <div class="flex gap-2">
                  <button
                    type="submit"
                    class="rounded-md bg-rose-700 px-3 py-2 text-xs font-semibold text-white"
                  >Confirmar cancelación</button>
                  <button
                    type="button"
                    phx-click="cancel_cancellation"
                    class="rounded-md border border-stone-300 px-3 py-2 text-xs font-semibold text-stone-700"
                  >Volver</button>
                </div>
              </.form>
            </article>
          </div>
        </section>

        <section id="secretary-appointment-history" aria-labelledby="secretary-history-heading">
          <div class="mb-3 flex items-center justify-between">
            <div>
              <h2 id="secretary-history-heading" class="text-lg font-semibold text-[#0A3847]">
                Historial operativo del centro
              </h2>
              <p class="mt-1 text-sm text-stone-600">
                Estados, origen y motivo de todas las agendas autorizadas.
              </p>
            </div>
            <span :if={is_nil(@history_error)} class="text-xs text-stone-500">{length(@history)} registros</span>
          </div>
          <div
            :if={is_nil(@history_error) and @history == []}
            id="secretary-history-empty"
            class="rounded-xl border border-dashed border-stone-300 bg-white p-8 text-center text-sm text-stone-600"
          >
            Todavía no hay registros en el historial del centro.
          </div>
          <div
            :if={is_nil(@history_error) and @history != []}
            id="secretary-history-list"
            class="space-y-3"
          >
            <div
              :for={appointment <- @history}
              id={"secretary-history-appointment-#{appointment.id}-wrapper"}
            >
              <p class="mb-2 text-sm font-semibold text-stone-700">
                {patient_identifier(appointment)}
              </p>
              <AppointmentLifecycle.history
                appointment={appointment}
                timezone={@organization_timezone}
                id_prefix="secretary-history-appointment"
                professional_name={professional_name(appointment, @professional_names)}
                hide_appointment_number={true}
                professional_label="Profesional"
              />
              <OrigenWeb.AppointmentPaymentComponent.detail_button
                id={"history-view-turn-#{appointment.id}"}
                appointment_id={appointment.id}
              />
            </div>
          </div>
        </section>
        <.live_component
          :if={@selected_appointment}
          module={OrigenWeb.AppointmentPaymentComponent}
          id={"payment-#{@selected_appointment.id}"}
          appointment={@selected_appointment}
          principal={@current_internal_session}
          timezone={@organization_timezone}
          professional_name={professional_name(@selected_appointment, @professional_names)}
        />
      </main>
    </div>
    """
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  defp local_time(datetime, timezone, format),
    do: datetime |> DateTime.shift_zone!(timezone) |> Calendar.strftime(format)
end
