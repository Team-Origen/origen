defmodule OrigenWeb.PatientBookingCalendarLive do
  use OrigenWeb, :live_view

  alias Origen.{Appointments.Calendar, Patients}

  @impl true
  def mount(_params, session, socket) do
    email = session["patient_email"]
    profile = if email, do: resolve_profile(email)
    ready? = profile != nil and Patients.ready_for_booking?(profile)
    {:ok, profs} = Calendar.list_professionals()

    {:ok,
     assign(socket,
       email: email,
       profile: profile,
       ready?: ready?,
       professionals: profs,
       prof_id: hd(profs).id,
       date: next_weekday(Date.utc_today()),
       selected_slot: nil,
       confirmed?: false
     )
     |> load_schedule()}
  end

  @impl true
  def handle_event("change_prof", %{"prof_id" => id}, socket) do
    {:noreply,
     assign(socket, prof_id: id, selected_slot: nil, confirmed?: false) |> load_schedule()}
  end

  def handle_event("change_date", %{"date" => str}, socket) do
    case Date.from_iso8601(str) do
      {:ok, d} ->
        {:noreply,
         assign(socket, date: d, selected_slot: nil, confirmed?: false) |> load_schedule()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("nav_date", %{"step" => s}, socket) do
    new_d = Date.add(socket.assigns.date, String.to_integer(s))

    {:noreply,
     assign(socket, date: new_d, selected_slot: nil, confirmed?: false) |> load_schedule()}
  end

  def handle_event("select_slot", %{"slot_id" => id}, socket) do
    slot = Enum.find(socket.assigns.schedule[:slots] || [], &(&1.id == id))
    {:noreply, assign(socket, selected_slot: slot)}
  end

  def handle_event("clear_slot", _params, socket),
    do: {:noreply, assign(socket, selected_slot: nil)}

  def handle_event("confirm_booking", _params, socket) do
    if socket.assigns.ready? and socket.assigns.selected_slot do
      {:noreply, assign(socket, confirmed?: true)}
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "DebÃ©s completar tu perfil y verificar tu telÃ©fono antes de reservar."
       )}
    end
  end

  defp load_schedule(socket) do
    case Calendar.get_daily_schedule(socket.assigns.prof_id, socket.assigns.date) do
      {:ok, s} -> assign(socket, schedule: s, error: nil)
      {:error, r} -> assign(socket, schedule: nil, error: r)
    end
  end

  defp resolve_profile(email),
    do:
      (case Patients.get_or_create_profile(email) do
         {:ok, p} -> p
         _ -> nil
       end)

  defp next_weekday(d),
    do:
      (case Date.day_of_week(d) do
         6 -> Date.add(d, 2)
         7 -> Date.add(d, 1)
         _ -> d
       end)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#F6F6F4] py-8 px-4 sm:px-6 lg:px-8">
      <div class="max-w-4xl mx-auto space-y-6">
        <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-[#0A3847]">Calendario de Reservas</h1>

            <p class="text-sm text-stone-600">
              SeleccionÃ¡ un profesional y un horario disponible para tu consulta.
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
          class="p-4 rounded-xl bg-red-50 text-red-800 text-sm flex items-center gap-2"
        >
          <.icon name="hero-exclamation-circle" class="w-5 h-5 text-red-600 shrink-0" />
          <span>{Phoenix.Flash.get(@flash, :error)}</span>
        </div>

        <%= if not @ready? do %>
          <div class="p-4 rounded-xl bg-amber-50 text-amber-800 text-sm flex items-start gap-3">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600 mt-0.5 shrink-0" />
            <div class="flex-1">
              <p class="font-semibold">Perfil pendiente de verificaciÃ³n</p>

              <p class="mt-0.5">
                Para confirmar turnos de manera autÃ³noma, tu telÃ©fono debe estar verificado.
              </p>
            </div>

            <.link
              navigate={~p"/patient/phone/verify"}
              class="px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-semibold"
            >
              Verificar TelÃ©fono
            </.link>
          </div>
        <% end %>

        <div class="bg-white rounded-xl shadow-sm border border-stone-200 p-6 space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-semibold text-stone-700 uppercase tracking-wider mb-1.5">Profesional</label>
              <form id="professional-form" phx-change="change_prof">
                <select
                  name="prof_id"
                  class="w-full rounded-lg border-stone-300 text-sm"
                >
                  <%= for p <- @professionals do %>
                    <option value={p.id} selected={p.id == @prof_id}>{p.name} - {p.specialty}</option>
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
                  class="p-2 rounded-lg border border-stone-300 hover:bg-stone-50 text-stone-600"
                  title="DÃ­a anterior"
                >
                  <.icon name="hero-chevron-left" class="w-4 h-4" />
                </button>

                <form id="date-form" phx-change="change_date" class="flex-1">
                  <input
                    type="date"
                    name="date"
                    value={Date.to_iso8601(@date)}
                    class="w-full rounded-lg border-stone-300 text-sm text-center font-medium"
                  />
                </form>

                <button
                  phx-click="nav_date"
                  phx-value-step="1"
                  class="p-2 rounded-lg border border-stone-300 hover:bg-stone-50 text-stone-600"
                  title="DÃ­a siguiente"
                >
                  <.icon name="hero-chevron-right" class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <%= cond do %>
          <% @confirmed? and @selected_slot -> %>
            <div class="bg-white rounded-xl shadow-sm border border-emerald-200 p-8 text-center space-y-4">
              <div class="w-12 h-12 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mx-auto font-bold text-xl">
                âœ“
              </div>

              <h2 class="text-xl font-bold text-stone-900">Â¡Turno Reservado con Ã‰xito!</h2>

              <p class="text-sm text-stone-600 max-w-md mx-auto">
                Tu turno con <strong>{@schedule.professional_name}</strong>
                para el dÃ­a <strong>{Date.to_iso8601(@date)}</strong>
                a las <strong>{@selected_slot.start_formatted} hs</strong>
                ha sido confirmado.
              </p>

              <div class="pt-4">
                <.link
                  navigate={~p"/patient/profile/complete"}
                  class="px-5 py-2.5 rounded-lg bg-[#0A3847] text-white text-sm font-semibold inline-flex"
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
                >Cambiar horario</button>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-stone-50 rounded-lg p-4 text-sm">
                <div>
                  <span class="text-xs text-stone-500 block">Profesional</span>
                  <span class="font-semibold text-stone-800">{@schedule.professional_name} ({@schedule.specialty})</span>
                </div>

                <div>
                  <span class="text-xs text-stone-500 block">Fecha y Horario</span>
                  <span class="font-semibold text-stone-800">{Date.to_iso8601(@date)} de {@selected_slot.start_formatted} a {@selected_slot.end_formatted} hs</span>
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
                  class={"w-full sm:flex-1 py-2.5 px-4 rounded-lg font-semibold text-sm shadow-sm " <> if @ready?, do: "bg-[#0A3847] hover:bg-[#35545A] text-white", else: "bg-stone-300 text-stone-500 cursor-not-allowed"}
                >
                  {if @ready?, do: "Confirmar Turno", else: "VerificaciÃ³n de TelÃ©fono Requerida"}
                </button>

                <button
                  phx-click="clear_slot"
                  class="w-full sm:w-auto py-2.5 px-4 rounded-lg border border-stone-300 hover:bg-stone-50 text-stone-700 text-sm font-medium"
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
                  <p class="p-4 bg-red-50 text-red-800 text-sm text-center rounded-lg">
                    No pudimos cargar la disponibilidad en este momento.
                  </p>
                <% @schedule && @schedule.slots == [] -> %>
                  <p class="p-6 bg-stone-50 text-stone-600 text-sm text-center rounded-lg border border-dashed">
                    No hay turnos disponibles para este día.
                  </p>
                <% @schedule -> %>
                  <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                    <%= for slot <- @schedule.slots do %>
                      <button
                        phx-click="select_slot"
                        phx-value-slot_id={slot.id}
                        class="p-3 border rounded-lg hover:border-[#0A3847] hover:bg-[#DDE6DB]/20 text-center"
                      >
                        <span class="block text-base font-bold text-[#0A3847]">{slot.start_formatted}</span>
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
