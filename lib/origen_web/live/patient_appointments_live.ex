defmodule OrigenWeb.PatientAppointmentsLive do
  use OrigenWeb, :live_view

  alias Origen.Appointments.Calendar, as: AppointmentCalendar
  alias Origen.Booking

  @cancellable_statuses ~w(requested confirmed)

  @impl true
  def mount(_params, session, socket) do
    principal = patient_principal(session)

    {:ok,
     socket
     |> assign(
       page_title: "Mis turnos",
       principal: principal,
       appointments: [],
       payments: %{},
       history_error: nil,
       feedback: nil,
       now: DateTime.utc_now(),
       organization_timezone: Application.fetch_env!(:origen, :organization_timezone),
       professional_names: %{}
     )
     |> load_history()}
  end

  @impl true
  def handle_event("cancel_appointment", %{"appointment_id" => appointment_id}, socket) do
    socket = assign(socket, now: DateTime.utc_now(), feedback: nil)

    case parse_id(appointment_id) do
      {:ok, id} ->
        case Booking.cancel_appointment(socket.assigns.principal, id) do
          {:ok, _appointment} ->
            {:noreply,
             socket
             |> assign(feedback: {:ok, "Turno cancelado."})
             |> load_history()}

          {:error, reason} ->
            {:noreply, assign(socket, feedback: {:error, cancellation_error(reason)})}
        end

      :error ->
        {:noreply, assign(socket, feedback: {:error, "No se pudo cancelar el turno."})}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp load_history(socket) do
    case Booking.list_appointment_history(socket.assigns.principal) do
      {:ok, appointments} ->
        assign(socket,
          appointments:
            Enum.sort_by(
              appointments,
              &{DateTime.to_unix(&1.start_time, :microsecond), &1.id},
              :desc
            ),
          payments:
            Map.new(appointments, fn appointment ->
              projection =
                case Booking.get_payment(socket.assigns.principal, appointment.id) do
                  {:ok, payment} -> payment
                  {:error, _} -> nil
                end

              {appointment.id, projection}
            end),
          history_error: nil,
          professional_names: professional_names()
        )

      {:error, _reason} ->
        assign(socket, appointments: [], payments: %{}, history_error: :unavailable)
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

  defp patient_principal(session) do
    %{
      patient_email: Map.get(session, "patient_email") || Map.get(session, :patient_email),
      patient_authenticated_at:
        Map.get(session, "patient_authenticated_at") ||
          Map.get(session, :patient_authenticated_at)
    }
  end

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_id(_value), do: :error

  defp cancellation_error(:patient_cancellation_not_allowed),
    do: "No se puede cancelar un turno que ya comenzó."

  defp cancellation_error(:unauthorized), do: "No se pudo cancelar el turno solicitado."
  defp cancellation_error(:invalid_status_transition), do: "Este turno ya no se puede cancelar."

  defp cancellation_error(_reason),
    do: "No se pudo cancelar el turno. Volvé a intentar más tarde."

  defp can_cancel?(appointment, now) do
    appointment.status in @cancellable_statuses and
      DateTime.compare(appointment.start_time, now) == :gt
  end

  defp status_label("requested"), do: "Pendiente de aprobación"
  defp status_label("confirmed"), do: "Confirmado"
  defp status_label("expired"), do: "Vencido"
  defp status_label("cancelled"), do: "Cancelado"
  defp status_label("attended"), do: "Asistió"
  defp status_label("no_show"), do: "No asistió"
  defp status_label(_status), do: "Estado no disponible"

  defp status_class("confirmed"), do: "bg-emerald-100 text-emerald-800"
  defp status_class("requested"), do: "bg-amber-100 text-amber-800"
  defp status_class("expired"), do: "bg-stone-200 text-stone-700"
  defp status_class("cancelled"), do: "bg-red-100 text-red-800"

  defp status_class(status) when status in ["attended", "no_show"],
    do: "bg-blue-100 text-blue-800"

  defp status_class(_status), do: "bg-stone-100 text-stone-700"

  defp cancellation_origin_label("professional"), do: "Profesional"
  defp cancellation_origin_label("secretary"), do: "Secretaría"
  defp cancellation_origin_label("patient"), do: "Paciente"
  defp cancellation_origin_label(origin) when is_binary(origin), do: origin
  defp cancellation_origin_label(_origin), do: "Sin origen informado"

  defp professional_name(appointment, names),
    do: Map.get(names, to_string(appointment.professional_account_id), "Profesional")

  defp local_time(datetime, timezone, format),
    do: datetime |> DateTime.shift_zone!(timezone) |> Calendar.strftime(format)

  @impl true
  def render(assigns) do
    ~H"""
    <OrigenWeb.RoleNavigation.navbar
      role={:patient}
      active="turns"
      patient_profile={@current_patient_profile}
    />

    <div class="min-h-screen bg-[#F6F6F4] font-inter">
      <main class="mx-auto max-w-4xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
        <header class="rounded-xl border border-stone-200 bg-white p-6 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wider text-[#35545A]">Paciente</p>
          <h1 class="mt-1 text-2xl font-bold text-[#0A3847]">Mis turnos</h1>
          <p class="mt-2 text-sm text-stone-600">
            Consultá tus turnos actuales y el historial de solicitudes, cancelaciones y resultados.
          </p>
        </header>

        <div
          :if={@feedback}
          role={if elem(@feedback, 0) == :ok, do: "status", else: "alert"}
          class={
            if elem(@feedback, 0) == :ok,
              do: "rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900",
              else: "rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800"
          }
        >
          {elem(@feedback, 1)}
        </div>

        <div
          :if={@history_error}
          id="patient-appointments-error"
          role="alert"
          class="rounded-xl border border-red-200 bg-white p-6 text-sm text-red-800"
        >
          No se pudo cargar tu historial de turnos. Volvé a intentar más tarde.
        </div>

        <section
          :if={is_nil(@history_error) and @appointments == []}
          id="patient-appointments-empty"
          class="rounded-xl border border-dashed border-stone-300 bg-white p-8 text-center"
        >
          <.icon name="hero-calendar" class="mx-auto h-10 w-10 text-stone-400" />
          <h2 class="mt-3 text-lg font-semibold text-stone-800">Todavía no tenés turnos</h2>
          <p class="mx-auto mt-1 max-w-md text-sm text-stone-600">
            Cuando reserves un turno o recibas una actualización, va a aparecer acá.
          </p>
          <.link
            navigate={~p"/paciente/turnos/reservar"}
            class="mt-5 inline-flex rounded-lg bg-[#0A3847] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#35545A]"
          >
            Reservar un turno
          </.link>
        </section>

        <section
          :if={is_nil(@history_error) and @appointments != []}
          aria-labelledby="appointments-heading"
        >
          <div class="mb-3 flex items-center justify-between">
            <h2 id="appointments-heading" class="text-lg font-semibold text-[#0A3847]">
              Historial de turnos
            </h2>
            <span class="text-xs text-stone-500">{length(@appointments)} registros</span>
          </div>

          <div id="patient-appointments-list" class="space-y-4">
            <article
              :for={appointment <- @appointments}
              id={"patient-appointment-#{appointment.id}"}
              class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm"
            >
              <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h3 class="font-semibold text-stone-900">{appointment.consultation_type_name}</h3>
                  <p class="mt-1 text-sm text-stone-600">
                    {local_time(appointment.start_time, @organization_timezone, "%d/%m/%Y · %H:%M")} a {local_time(
                      appointment.end_time,
                      @organization_timezone,
                      "%H:%M"
                    )} hs
                  </p>
                  <p class="mt-1 text-xs text-stone-500">
                    {professional_name(appointment, @professional_names)} · Turno #{appointment.id}
                  </p>
                </div>

                <span class={"inline-flex w-fit rounded-full px-3 py-1 text-xs font-semibold #{status_class(appointment.status)}"}>
                  {status_label(appointment.status)}
                </span>
              </div>

              <div class="mt-4 grid gap-3 border-t border-stone-100 pt-4 text-sm sm:grid-cols-2">
                <% payment = Map.get(@payments, appointment.id) %>
                <%= if payment do %>
                  <p>
                    <span class="block text-xs font-semibold uppercase tracking-wide text-stone-500">Precio final</span>
                    <span id={"patient-final-price-#{appointment.id}"} class="text-stone-800">${payment.final_price_ars}</span>
                  </p>
                  <p>
                    <span class="block text-xs font-semibold uppercase tracking-wide text-stone-500">Estado de pago</span>
                    <span id={"patient-payment-state-#{appointment.id}"} class="text-stone-800">
                      {if payment.payment_status == "paid", do: "Pagado", else: "Pendiente"}
                    </span>
                  </p>
                <% else %>
                  <p class="text-stone-600">Precio y estado de pago no disponibles.</p>
                <% end %>
                <div :if={appointment.cancellation_origin || appointment.cancellation_reason}>
                  <span class="block text-xs font-semibold uppercase tracking-wide text-stone-500">Cancelación</span>
                  <p :if={appointment.cancellation_origin} class="text-stone-800">
                    Origen: {cancellation_origin_label(appointment.cancellation_origin)}
                  </p>
                  <p :if={appointment.cancellation_reason} class="text-stone-800">
                    Motivo: {appointment.cancellation_reason}
                  </p>
                </div>
              </div>

              <div :if={can_cancel?(appointment, @now)} class="mt-4 border-t border-stone-100 pt-4">
                <button
                  type="button"
                  phx-click="cancel_appointment"
                  phx-value-appointment_id={appointment.id}
                  data-confirm="¿Querés cancelar este turno?"
                  class="rounded-lg border border-red-300 px-3 py-2 text-sm font-semibold text-red-700 hover:bg-red-50"
                >
                  Cancelar turno
                </button>
                <p class="mt-2 text-xs text-stone-500">
                  Podés cancelar hasta antes del inicio, sin multa.
                </p>
              </div>
            </article>
          </div>
        </section>
      </main>
    </div>
    """
  end
end
