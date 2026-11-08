defmodule OrigenWeb.PatientBookingCalendarLive do
  use OrigenWeb, :live_view

  alias Origen.{Appointments.Calendar, ConsultationTypes, Patients}

  @generic_booking_error "No se pudo completar la reserva. Volvé a intentar más tarde."
  @stale_slot_error "Ese horario ya no está disponible. Actualizamos la disponibilidad; elegí otro horario."

  @impl true
  def mount(_params, session, socket) do
    email = session["patient_email"]
    profile = if(email, do: resolve_profile(email))
    ready? = profile != nil and Patients.ready_for_booking?(profile)
    {profs, professionals_error} = list_professionals()
    default_prof = List.first(profs)

    {types, agenda_interval_minutes, catalog_error} =
      if default_prof, do: fetch_catalog(default_prof.id), else: {[], 30, nil}

    default_type = List.first(types)

    {:ok,
     assign(socket,
       email: email,
       profile: profile,
       ready?: ready?,
       professionals: profs,
       professionals_error: professionals_error,
       prof_id: default_prof && default_prof.id,
       consultation_types: types,
       catalog_error: catalog_error,
       selected_type_id: default_type && default_type.id,
       selected_type: default_type,
       agenda_interval_minutes: agenda_interval_minutes,
       date: next_weekday(Date.utc_today()),
       selected_slot: nil,
       booking_result: nil,
       booking_in_progress?: false
     )
     |> load_schedule()}
  end

  @impl true
  def handle_event("change_prof", %{"prof_id" => id}, socket) do
    case Enum.find(socket.assigns.professionals, &same_id?(&1.id, id)) do
      nil ->
        {:noreply, socket}

      professional ->
        {types, agenda_interval_minutes, catalog_error} = fetch_catalog(professional.id)
        type = List.first(types)

        {:noreply,
         assign(socket,
           prof_id: professional.id,
           consultation_types: types,
           catalog_error: catalog_error,
           selected_type_id: type && type.id,
           selected_type: type,
           agenda_interval_minutes: agenda_interval_minutes,
           selected_slot: nil,
           booking_result: nil,
           booking_in_progress?: false
         )
         |> load_schedule()}
    end
  end

  def handle_event("change_type", %{"type_id" => id}, socket) do
    case Enum.find(socket.assigns.consultation_types, &same_id?(&1.id, id)) do
      nil ->
        {:noreply, socket}

      type ->
        {:noreply,
         assign(socket,
           selected_type_id: type.id,
           selected_type: type,
           selected_slot: nil,
           booking_result: nil,
           booking_in_progress?: false
         )
         |> load_schedule()}
    end
  end

  def handle_event("change_date", %{"date" => value}, socket) do
    case parse_date(value) do
      {:ok, date} ->
        {:noreply,
         assign(socket,
           date: date,
           selected_slot: nil,
           booking_result: nil,
           booking_in_progress?: false
         )
         |> load_schedule()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("nav_date", %{"step" => step}, socket) do
    case navigation_step(step) do
      {:ok, step} ->
        {:noreply,
         assign(socket,
           date: Date.add(socket.assigns.date, step),
           selected_slot: nil,
           booking_result: nil,
           booking_in_progress?: false
         )
         |> load_schedule()}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("select_slot", %{"slot_id" => id}, socket) do
    case Enum.find(
           (socket.assigns.schedule && socket.assigns.schedule.slots) || [],
           &same_id?(&1.id, id)
         ) do
      nil ->
        {:noreply, socket}

      slot ->
        {:noreply,
         assign(socket,
           selected_slot: slot,
           booking_result: nil,
           booking_in_progress?: false
         )}
    end
  end

  def handle_event("clear_slot", _params, socket) do
    refresh_schedule? = not is_nil(socket.assigns.booking_result)

    socket = assign(socket, selected_slot: nil, booking_result: nil, booking_in_progress?: false)
    socket = if refresh_schedule?, do: load_schedule(socket), else: socket

    {:noreply, socket}
  end

  def handle_event("confirm_booking", _params, %{assigns: %{booking_result: result}} = socket)
      when not is_nil(result),
      do: {:noreply, socket}

  def handle_event(
        "confirm_booking",
        _params,
        %{assigns: %{booking_in_progress?: true}} = socket
      ),
      do: {:noreply, socket}

  def handle_event("confirm_booking", _params, socket) do
    case booking_selection(socket) do
      {:error, :profile_not_ready} ->
        {:noreply, put_flash(socket, :error, "Completá tu perfil para reservar.")}

      {:error, :invalid_selection} ->
        {:noreply, put_flash(socket, :error, "Seleccioná un horario disponible para reservar.")}

      {:ok, params} ->
        socket = assign(socket, booking_in_progress?: true)

        case Origen.Appointments.BookingService.reserve(socket.assigns.profile, params) do
          {:ok, result} ->
            {:noreply,
             assign(socket,
               booking_in_progress?: false,
               booking_result: result_snapshot(socket, result, params)
             )}

          {:error, :overlap_detected} ->
            socket = assign(socket, selected_slot: nil, booking_in_progress?: false)

            {:noreply,
             socket
             |> load_schedule()
             |> put_flash(:error, @stale_slot_error)}

          {:error, :patient_not_ready_for_booking} ->
            {:noreply,
             socket
             |> assign(booking_in_progress?: false)
             |> put_flash(:error, "Completá tu perfil para reservar.")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> assign(booking_in_progress?: false)
             |> put_flash(:error, @generic_booking_error)}
        end
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp load_schedule(%{assigns: %{professionals_error: error}} = socket) when not is_nil(error),
    do: assign(socket, schedule: nil, error: error)

  defp load_schedule(%{assigns: %{prof_id: nil}} = socket),
    do: assign(socket, schedule: nil, error: nil)

  defp load_schedule(%{assigns: %{selected_type: nil}} = socket),
    do: assign(socket, schedule: nil, error: nil)

  defp load_schedule(socket) do
    duration =
      socket.assigns.selected_type.interval_count * socket.assigns.agenda_interval_minutes

    case Calendar.get_daily_schedule(socket.assigns.prof_id, socket.assigns.date,
           duration_minutes: duration
         ) do
      {:ok, schedule} ->
        professional =
          Enum.find(socket.assigns.professionals, &same_id?(&1.id, socket.assigns.prof_id))

        schedule =
          Map.merge(schedule, %{
            professional_name: professional && professional.name,
            specialty: professional && professional.specialty
          })

        assign(socket, schedule: schedule, error: nil)

      {:error, _reason} ->
        assign(socket, schedule: nil, error: :unavailable)
    end
  end

  defp booking_selection(%{assigns: assigns}) do
    with true <- assigns.ready?,
         %{} = professional <- Enum.find(assigns.professionals, &same_id?(&1.id, assigns.prof_id)),
         %{} = type <-
           Enum.find(assigns.consultation_types, &same_id?(&1.id, assigns.selected_type_id)),
         %Date{} = date <- assigns.date,
         %{} = slot <-
           Enum.find(
             (assigns.schedule && assigns.schedule.slots) || [],
             &same_id?(&1.id, assigns.selected_slot && assigns.selected_slot.id)
           ) do
      {:ok,
       %{
         professional_id: professional.id,
         consultation_type_id: type.id,
         date: date,
         slot: slot
       }}
    else
      false -> {:error, :profile_not_ready}
      _ -> {:error, :invalid_selection}
    end
  end

  defp result_snapshot(socket, result, params) do
    professional =
      Enum.find(socket.assigns.professionals, &same_id?(&1.id, params.professional_id))

    Map.merge(result, %{
      date: params.date,
      start_formatted: params.slot.start_formatted,
      end_formatted: params.slot.end_formatted,
      professional_name: professional && professional.name
    })
  end

  defp list_professionals do
    case Calendar.list_professionals() do
      {:ok, professionals} -> {professionals, nil}
      {:error, _reason} -> {[], :unavailable}
    end
  end

  defp fetch_catalog(prof_id) do
    case ConsultationTypes.Catalog.execute({:list, %{professional_reference: prof_id}}) do
      {:ok, %{consultation_types: list, agenda_interval_minutes: interval}} ->
        active = Enum.filter(list, &(&1.status == :active))
        {active, interval, nil}

      _ ->
        {[], 30, :unavailable}
    end
  end

  defp resolve_profile(email),
    do:
      (case Patients.get_or_create_profile(email) do
         {:ok, p} -> p
         _ -> nil
       end)

  defp same_id?(left, right)
       when (is_integer(left) or is_binary(left)) and (is_integer(right) or is_binary(right)),
       do: to_string(left) == to_string(right)

  defp same_id?(_left, _right), do: false

  defp parse_date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp parse_date(_value), do: :error

  defp navigation_step("-1"), do: {:ok, -1}
  defp navigation_step("1"), do: {:ok, 1}
  defp navigation_step(_step), do: :error

  defp next_weekday(d),
    do:
      (case Date.day_of_week(d) do
         6 -> Date.add(d, 2)
         7 -> Date.add(d, 1)
         _ -> d
       end)

  defp status_label("confirmed"), do: "Confirmado"
  defp status_label("requested"), do: "Pendiente de aprobación"
  defp status_label(_status), do: "Procesando"

  @impl true
  def render(assigns) do
    ~H"""
    <OrigenWeb.RoleNavigation.navbar
      role={:patient}
      active="book"
      patient_profile={@current_patient_profile}
    />
    <div class="min-h-screen bg-[#F6F6F4] py-8 px-4 sm:px-6 lg:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-[#0A3847]">Calendario de Reservas</h1>

            <p class="text-sm text-stone-600">
              Seleccioná un profesional, tipo de consulta y horario disponible.
            </p>
          </div>

          <%= if @profile && @profile.persona do %>
            <div class="text-right">
              <span class="text-xs text-stone-500 block">Paciente</span>
              <span class="text-sm font-medium text-stone-800">{@profile.persona.first_name} {@profile.persona.last_name}</span>
            </div>
          <% end %>
        </div>

        <div
          :if={Phoenix.Flash.get(@flash, :error)}
          class="p-4 rounded-xl bg-red-50 text-red-800 text-sm flex items-center gap-2 border border-red-200"
        >
          <.icon name="hero-exclamation-circle" class="w-5 h-5 text-red-600 shrink-0" />
          <span>{Phoenix.Flash.get(@flash, :error)}</span>
        </div>

        <div
          :if={@profile && not @ready?}
          class="p-4 rounded-xl bg-amber-50 text-amber-800 text-sm border border-amber-200"
        >
          Completá tu perfil para reservar de manera autónoma.
        </div>

        <div
          :if={@professionals != []}
          class="bg-white rounded-xl shadow-sm border border-stone-200 p-6 space-y-4"
        >
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">Profesional</label>
              <form id="professional-form" phx-change="change_prof">
                <select
                  name="prof_id"
                  class="w-full rounded-lg border-stone-300 bg-white text-stone-900 text-sm font-medium focus:ring-[#0A3847] focus:border-[#0A3847]"
                >
                  <%= for p <- @professionals do %>
                    <option
                      value={p.id}
                      selected={same_id?(p.id, @prof_id)}
                      class="bg-white text-stone-900"
                    >
                      {p.name} - {p.specialty}
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">Tipo de Consulta</label>
              <form id="type-form" phx-change="change_type">
                <select
                  name="type_id"
                  class="w-full rounded-lg border-stone-300 bg-white text-stone-900 text-sm font-medium focus:ring-[#0A3847] focus:border-[#0A3847]"
                >
                  <%= for t <- @consultation_types do %>
                    <option
                      value={t.id}
                      selected={same_id?(t.id, @selected_type_id)}
                      class="bg-white text-stone-900"
                    >
                      {t.name} ({t.interval_count * @agenda_interval_minutes} min)
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">Fecha</label>
              <div class="flex items-center gap-2">
                <button
                  phx-click="nav_date"
                  phx-value-step="-1"
                  class="p-2 border border-stone-300 rounded-lg bg-white hover:bg-stone-50 text-stone-800"
                  title="Día anterior"
                >
                  <.icon name="hero-chevron-left" class="w-4 h-4" />
                </button>

                <form id="date-form" phx-change="change_date" class="flex-1">
                  <input
                    type="date"
                    name="date"
                    value={Date.to_iso8601(@date)}
                    class="w-full rounded-lg border-stone-300 bg-white text-stone-900 text-sm text-center font-medium focus:ring-[#0A3847] focus:border-[#0A3847]"
                  />
                </form>

                <button
                  phx-click="nav_date"
                  phx-value-step="1"
                  class="p-2 border border-stone-300 rounded-lg bg-white hover:bg-stone-50 text-stone-800"
                  title="Día siguiente"
                >
                  <.icon name="hero-chevron-right" class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <%= cond do %>
          <% @professionals_error != nil -> %>
            <p
              id="patient-professionals-error"
              role="alert"
              class="p-6 bg-white text-red-800 text-center rounded-xl border border-red-200"
            >
              No se pudo cargar la lista de profesionales. Volvé a intentar más tarde.
            </p>
          <% @professionals == [] -> %>
            <p
              role="status"
              class="p-6 bg-white text-stone-600 text-center rounded-xl border border-stone-200"
            >
              No hay profesionales disponibles para reservar en este momento.
            </p>
          <% @catalog_error -> %>
            <p
              id="patient-catalog-error"
              role="alert"
              class="p-6 bg-white text-red-800 text-center rounded-xl border border-red-200"
            >
              No se pudieron cargar los tipos de consulta. Volvé a intentar más tarde.
            </p>
          <% @consultation_types == [] -> %>
            <p
              id="patient-catalog-empty"
              role="status"
              class="p-6 bg-white text-stone-600 text-center rounded-xl border border-stone-200"
            >
              No hay tipos de consulta disponibles para este profesional.
            </p>
          <% @booking_result != nil -> %>
            <div class="bg-white rounded-xl shadow-sm border border-emerald-200 p-8 text-center space-y-4">
              <div class="w-12 h-12 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mx-auto">
                <.icon name="hero-check" class="w-6 h-6 stroke-[2.5]" />
              </div>

              <h2 class="text-xl font-bold text-stone-900">
                {if @booking_result.status == "confirmed",
                  do: "Turno confirmado",
                  else: "Solicitud enviada"}
              </h2>

              <p class="text-sm text-stone-600">
                {if @booking_result.status == "confirmed",
                  do: "Tu turno quedó confirmado.",
                  else: "La solicitud queda pendiente de aprobación profesional."}
              </p>

              <div class="bg-emerald-50 border border-emerald-200 rounded-lg p-4 text-sm text-emerald-900 max-w-md mx-auto space-y-1.5 text-left">
                <p><strong>Turno ID:</strong> #{@booking_result.appointment_id}</p>
                <p><strong>Profesional:</strong> {@booking_result.professional_name}</p>
                <p><strong>Tipo de Consulta:</strong> {@booking_result.consultation_type_name}</p>
                <p>
                  <strong>Fecha y Horario:</strong> {Date.to_iso8601(@booking_result.date)} de {@booking_result.start_formatted} a {@booking_result.end_formatted} hs
                </p>
                <p><strong>Importe:</strong> ${@booking_result.exact_price_ars}</p>
                <p>
                  <strong>Estado:</strong>
                  <span class="inline-block px-2 py-0.5 rounded text-xs font-semibold bg-emerald-200 text-emerald-800">
                    {status_label(@booking_result.status)}
                  </span>
                </p>
              </div>

              <div class="pt-4">
                <button
                  phx-click="clear_slot"
                  class="px-5 py-2.5 rounded-lg bg-[#0A3847] text-white text-sm font-semibold hover:bg-[#35545A] inline-flex"
                >
                  Reservar otro turno
                </button>
              </div>
            </div>
          <% @selected_slot -> %>
            <div class="bg-white rounded-xl shadow-sm border border-[#0A3847]/30 p-6 space-y-5">
              <div class="flex items-center justify-between border-b border-stone-100 pb-4">
                <h3 class="text-lg font-bold text-[#0A3847]">Confirmar Reserva</h3>

                <button
                  phx-click="clear_slot"
                  class="text-xs text-stone-500 hover:text-stone-800 underline"
                >Cambiar horario</button>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-stone-50 rounded-lg p-4 text-sm">
                <div>
                  <span class="text-xs text-stone-500 block">Profesional y Consulta</span>
                  <span class="font-semibold text-stone-800">{@schedule.professional_name} — {@selected_type.name}</span>
                </div>

                <div>
                  <span class="text-xs text-stone-500 block">Fecha y Horario</span>
                  <span class="font-semibold text-stone-800">{Date.to_iso8601(@date)} de {@selected_slot.start_formatted} a {@selected_slot.end_formatted} hs</span>
                </div>
              </div>

              <div class="pt-2 flex flex-col sm:flex-row gap-3">
                <button
                  phx-click="confirm_booking"
                  phx-disable-with="Reservando…"
                  disabled={not @ready? or @booking_in_progress?}
                  aria-busy={@booking_in_progress?}
                  class={"w-full sm:flex-1 py-2.5 px-4 rounded-lg font-semibold text-sm " <> if @ready? and not @booking_in_progress?, do: "bg-[#0A3847] hover:bg-[#35545A] text-white", else: "bg-stone-300 text-stone-500 cursor-not-allowed"}
                >
                  {cond do
                    @booking_in_progress? -> "Reservando…"
                    @ready? -> "Confirmar Turno"
                    true -> "Completá tu perfil para reservar"
                  end}
                </button>

                <button
                  phx-click="clear_slot"
                  class="p-2.5 border border-stone-300 rounded-lg text-sm text-stone-700 hover:bg-stone-50"
                >Cancelar</button>
              </div>
            </div>
          <% true -> %>
            <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-6">
              <h3 class="text-sm font-semibold text-stone-700 uppercase tracking-wider mb-4">
                Horarios Disponibles para {Date.to_iso8601(@date)}
              </h3>

              <%= cond do %>
                <% @error != nil -> %>
                  <p class="p-4 bg-red-50 text-red-800 text-sm text-center rounded-lg border border-red-200">
                    No pudimos cargar la disponibilidad en este momento.
                  </p>
                <% @schedule && @schedule.slots == [] -> %>
                  <p class="p-6 bg-stone-50 text-stone-600 text-sm text-center rounded-lg border border-dashed border-stone-300">
                    No hay turnos disponibles para este día.
                  </p>
                <% @schedule -> %>
                  <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                    <%= for slot <- @schedule.slots do %>
                      <button
                        phx-click="select_slot"
                        phx-value-slot_id={slot.id}
                        class="p-3 border border-stone-200 rounded-lg hover:border-[#0A3847] hover:bg-[#DDE6DB]/20 text-center transition-all group focus:outline-none focus:ring-2 focus:ring-[#0A3847]"
                      >
                        <span class="block text-base font-bold text-[#0A3847] group-hover:scale-105 transition-transform">{slot.start_formatted}</span>
                        <span class="block text-xs text-stone-500">hasta {slot.end_formatted}</span>
                      </button>
                    <% end %>
                  </div>
                <% true -> %>
                  <div class="text-center py-6 text-stone-400 text-sm">
                    Cargando disponibilidad...
                  </div>
              <% end %>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
