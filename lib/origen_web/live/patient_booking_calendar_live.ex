defmodule OrigenWeb.PatientBookingCalendarLive do
  use OrigenWeb, :live_view

  alias Origen.{Appointments.Calendar, ConsultationTypes, Patients}

  @impl true
  def mount(_params, session, socket) do
    email = session["patient_email"]

    if is_nil(email) do
      {:ok, push_navigate(socket, to: ~p"/access")}
    else
      profile = resolve_profile(email)

      if is_nil(profile) do
        {:ok, push_navigate(socket, to: ~p"/access")}
      else
        ready? = Patients.ready_for_booking?(profile)
        {:ok, profs} = Calendar.list_professionals()
        default_prof = hd(profs)
        types = fetch_types(default_prof.id)
        default_type = hd(types)

        {:ok,
         assign(socket,
           email: email,
           profile: profile,
           ready?: ready?,
           professionals: profs,
           prof_id: default_prof.id,
           consultation_types: types,
           selected_type_id: default_type.id,
           selected_type: default_type,
           date: next_weekday(Date.utc_today()),
           selected_slot: nil,
           confirmed?: false,
           booking_result: nil
         )
         |> load_schedule()}
      end
    end
  end

  @impl true
  def handle_event("change_prof", %{"prof_id" => id}, socket) do
    types = fetch_types(id)
    type = hd(types)

    {:noreply,
     assign(socket,
       prof_id: id,
       consultation_types: types,
       selected_type_id: type.id,
       selected_type: type,
       selected_slot: nil,
       confirmed?: false,
       booking_result: nil
     )
     |> load_schedule()}
  end

  def handle_event("change_type", %{"type_id" => id}, socket) do
    type =
      Enum.find(socket.assigns.consultation_types, &(&1.id == id)) || socket.assigns.selected_type

    {:noreply,
     assign(socket,
       selected_type_id: id,
       selected_type: type,
       selected_slot: nil,
       confirmed?: false,
       booking_result: nil
     )
     |> load_schedule()}
  end

  def handle_event("change_date", %{"date" => str}, socket) do
    case Date.from_iso8601(str) do
      {:ok, d} ->
        {:noreply,
         assign(socket,
           date: d,
           selected_slot: nil,
           confirmed?: false,
           booking_result: nil
         )
         |> load_schedule()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("nav_date", %{"step" => s}, socket) do
    {:noreply,
     assign(socket,
       date: Date.add(socket.assigns.date, String.to_integer(s)),
       selected_slot: nil,
       confirmed?: false,
       booking_result: nil
     )
     |> load_schedule()}
  end

  def handle_event("select_slot", %{"slot_id" => id}, socket) do
    slot = Enum.find(socket.assigns.schedule[:slots] || [], &(&1.id == id))

    {:noreply,
     assign(socket,
       selected_slot: slot,
       confirmed?: false,
       booking_result: nil
     )}
  end

  def handle_event("clear_slot", _params, socket) do
    {:noreply,
     assign(socket,
       selected_slot: nil,
       confirmed?: false,
       booking_result: nil
     )}
  end

  def handle_event("confirm_booking", _params, socket) do
    if socket.assigns.ready? and socket.assigns.selected_slot do
      params = %{
        professional_id: socket.assigns.prof_id,
        consultation_type_id: socket.assigns.selected_type.id,
        date: socket.assigns.date,
        slot: socket.assigns.selected_slot,
        snapshot_override: %{
          name: socket.assigns.selected_type.name,
          duration_minutes: socket.assigns.selected_type.interval_count * 15,
          exact_price_ars: socket.assigns.selected_type.exact_price_ars
        }
      }

      case Origen.Appointments.BookingService.reserve(socket.assigns.profile, params) do
        {:ok, result} ->
          {:noreply, assign(socket, confirmed?: true, booking_result: result)}

        {:error, :patient_not_ready_for_booking} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Debés completar tu perfil y verificar tu teléfono antes de reservar."
           )}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "No se pudo realizar la reserva: #{inspect(reason)}")}
      end
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "Debés completar tu perfil y verificar tu teléfono antes de reservar."
       )}
    end
  end

  defp load_schedule(socket) do
    duration =
      (socket.assigns[:selected_type] && socket.assigns.selected_type.interval_count * 15) || 30

    case Calendar.get_daily_schedule(socket.assigns.prof_id, socket.assigns.date,
           duration_minutes: duration,
           agenda_interval_minutes: duration
         ) do
      {:ok, s} -> assign(socket, schedule: s, error: nil)
      {:error, r} -> assign(socket, schedule: nil, error: r)
    end
  end

  defp fetch_types(prof_id) do
    case ConsultationTypes.Catalog.execute({:list, %{professional_reference: prof_id}}) do
      {:ok, %{consultation_types: list}} ->
        active = Enum.filter(list, &(&1.status == :active))
        if active == [], do: default_type_list(), else: active

      _ ->
        default_type_list()
    end
  end

  defp default_type_list do
    [
      %{
        id: "default-001",
        name: "Consulta general",
        interval_count: 2,
        exact_price_ars: Decimal.new("18000.00")
      }
    ]
  end

  defp resolve_profile(email) do
    case Patients.get_or_create_profile(email) do
      {:ok, p} -> p
      _ -> nil
    end
  end

  defp next_weekday(d) do
    case Date.day_of_week(d) do
      6 -> Date.add(d, 2)
      7 -> Date.add(d, 1)
      _ -> d
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
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
              <span class="text-sm font-medium text-stone-800 block">
                {@profile.persona.first_name} {@profile.persona.last_name}
              </span>
              <.link
                href={~p"/patient/session"}
                method="delete"
                class="text-xs text-[#0A3847] underline hover:text-[#35545A]"
              >
                Cambiar paciente
              </.link>
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
          :if={not @ready?}
          class="p-4 rounded-xl bg-amber-50 text-amber-800 text-sm flex items-start gap-3 border border-amber-200"
        >
          <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600 mt-0.5 shrink-0" />
          <div class="flex-1">
            <p class="font-semibold">Perfil pendiente de verificación</p>

            <p class="mt-0.5">
              Para confirmar turnos de manera autónoma, tu teléfono debe estar verificado.
            </p>
          </div>

          <.link
            navigate={~p"/patient/phone/verify"}
            class="px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-semibold shrink-0 hover:bg-amber-700"
          >
            Verificar Teléfono
          </.link>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-6 space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">
                Profesional
              </label>

              <form id="professional-form" phx-change="change_prof">
                <select
                  name="prof_id"
                  class="w-full rounded-lg border-stone-300 bg-white text-stone-900 text-sm font-medium focus:ring-[#0A3847] focus:border-[#0A3847]"
                >
                  <%= for p <- @professionals do %>
                    <option value={p.id} selected={p.id == @prof_id} class="bg-white text-stone-900">
                      {p.name} - {p.specialty}
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">
                Tipo de Consulta
              </label>

              <form id={"type-form-#{@prof_id}"} phx-change="change_type">
                <select
                  name="type_id"
                  class="w-full rounded-lg border-stone-300 bg-white text-stone-900 text-sm font-medium focus:ring-[#0A3847] focus:border-[#0A3847]"
                >
                  <%= for t <- @consultation_types do %>
                    <option
                      value={t.id}
                      selected={t.id == @selected_type_id}
                      class="bg-white text-stone-900"
                    >
                      {t.name} ({t.interval_count * 15} min)
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">
                Fecha
              </label>

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
          <% @confirmed? and @booking_result != nil -> %>
            <div class="bg-white rounded-xl shadow-sm border border-emerald-200 p-8 text-center space-y-4">
              <div class="w-12 h-12 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mx-auto">
                <.icon name="hero-check" class="w-6 h-6 stroke-[2.5]" />
              </div>

              <h2 class="text-xl font-bold text-stone-900">¡Turno Reservado con Éxito!</h2>

              <div class="bg-emerald-50 border border-emerald-200 rounded-lg p-4 text-sm text-emerald-900 max-w-md mx-auto space-y-1.5 text-left">
                <p>
                  <strong>Turno ID:</strong> #{@booking_result.appointment_id}
                </p>

                <p><strong>Profesional:</strong> {@schedule.professional_name}</p>

                <p>
                  <strong>Tipo de Consulta:</strong> {@booking_result.consultation_type_name ||
                    @selected_type.name}
                </p>

                <p>
                  <strong>Fecha y Horario:</strong> {Date.to_iso8601(@date)} de {@selected_slot.start_formatted} a {@selected_slot.end_formatted} hs
                </p>

                <p>
                  <strong>Importe:</strong> ${@booking_result.exact_price_ars}
                </p>

                <p>
                  <strong>Estado inicial (RF-10):</strong>
                  <span class="inline-block px-2 py-0.5 rounded text-xs font-semibold bg-emerald-200 text-emerald-800">
                    {String.capitalize(to_string(@booking_result.status))}
                  </span>
                </p>
              </div>

              <div class="pt-4 flex flex-col sm:flex-row gap-3 justify-center">
                <button
                  phx-click="clear_slot"
                  class="px-5 py-2.5 rounded-lg border border-[#0A3847] text-[#0A3847] text-sm font-semibold hover:bg-[#0A3847]/5 inline-flex"
                >
                  Reservar otro turno
                </button>

                <.link
                  navigate={~p"/patient/profile/complete"}
                  class="px-5 py-2.5 rounded-lg bg-[#0A3847] text-white text-sm font-semibold hover:bg-[#35545A] inline-flex"
                >
                  Volver a Mi Perfil
                </.link>
              </div>
            </div>
          <% @selected_slot -> %>
            <div class="bg-white rounded-xl shadow-sm border border-[#0A3847]/30 p-6 space-y-5">
              <div class="flex items-center justify-between border-b border-stone-100 pb-4">
                <h3 class="text-lg font-bold text-[#0A3847]">Confirmar Reserva</h3>

                <button
                  phx-click="clear_slot"
                  class="text-xs text-stone-500 hover:text-stone-800 underline"
                >
                  Cambiar horario
                </button>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-stone-50 rounded-lg p-4 text-sm">
                <div>
                  <span class="text-xs text-stone-500 block">Profesional y Consulta</span>
                  <span class="font-semibold text-stone-800">
                    {@schedule.professional_name} — {get_in(@selected_type, [:name]) ||
                      "Consulta general"}
                  </span>
                </div>

                <div>
                  <span class="text-xs text-stone-500 block">Fecha y Horario</span>
                  <span class="font-semibold text-stone-800">
                    {Date.to_iso8601(@date)} de {@selected_slot.start_formatted} a {@selected_slot.end_formatted} hs
                  </span>
                </div>
              </div>

              <div class="space-y-2 border-t pt-3 text-xs text-[#0A3847]">
                <h4 class="font-semibold uppercase tracking-wider text-stone-700">
                  Políticas de Cancelación y Asistencia
                </h4>

                <p>
                  <strong>Límite sin cargo:</strong> {@schedule.cancellation_policy.cutoff_description}
                </p>

                <p>
                  <strong>Política de multa ({@schedule.cancellation_policy.penalty_percentage}%):</strong> {@schedule.cancellation_policy.penalty_description}
                </p>
              </div>

              <div class="pt-2 flex flex-col sm:flex-row gap-3">
                <button
                  phx-click="confirm_booking"
                  disabled={not @ready?}
                  class={
                    "w-full sm:flex-1 py-2.5 px-4 rounded-lg font-semibold text-sm " <>
                      if @ready?,
                        do: "bg-[#0A3847] hover:bg-[#35545A] text-white",
                        else: "bg-stone-300 text-stone-500 cursor-not-allowed"
                  }
                >
                  {if @ready?, do: "Confirmar Turno", else: "Verificación de Teléfono Requerida"}
                </button>

                <button
                  phx-click="clear_slot"
                  class="p-2.5 border border-stone-300 rounded-lg text-sm text-stone-700 hover:bg-stone-50"
                >
                  Cancelar
                </button>
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
                        <span class="block text-base font-bold text-[#0A3847] group-hover:scale-105 transition-transform">
                          {slot.start_formatted}
                        </span>
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
