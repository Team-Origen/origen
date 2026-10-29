defmodule OrigenWeb.ProfessionalPatientSelectionLive do
  @moduledoc """
  Professional booking journey with real session-bound Booking operations (#316).

  Selection is kept server-side and confirmation ignores all client parameters.
  The default adapter delegates to Booking for authorization and atomic writes.
  The explicitly configured development demo remains a simulation, never a
  fallback for a failed real operation.
  """
  use OrigenWeb, :live_view

  alias Origen.Patients.Persona
  alias OrigenWeb.ProfessionalBookingDemoSteps

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Crear turno · Paciente",
        demo: demo?(),
        real_booking: real_booking?(),
        step: 1,
        consultations: [],
        consultation: nil,
        booking_date: Date.to_iso8601(Date.utc_today()),
        slots: [],
        slot: nil,
        result: nil,
        journey_error: nil,
        tab: "related",
        patients: [],
        selected: nil,
        searched: false,
        dni: "",
        error: nil
      )

    {:ok, load_related(socket)}
  end

  @impl true
  def handle_event("change_patient_tab", %{"tab" => tab}, %{assigns: %{step: 1}} = socket)
      when tab in ["related", "dni"] do
    socket =
      socket
      |> reset_booking()
      |> assign(tab: tab, selected: nil, patients: [], searched: false, dni: "", error: nil)

    {:noreply, if(tab == "related", do: load_related(socket), else: socket)}
  end

  def handle_event("search_patient", %{"dni" => dni}, %{assigns: %{tab: "dni", step: 1}} = socket)
      when is_binary(dni) do
    document = Persona.normalize_number(dni)

    socket =
      socket
      |> reset_booking()
      |> assign(selected: nil, patients: [], searched: true, dni: dni, error: nil)

    result =
      if document == "" or not Regex.match?(~r/^[A-Z0-9]{1,32}$/, document),
        do: {:error, :invalid_document},
        else: execute(socket, {:search, socket.assigns.current_internal_session, document})

    case result do
      {:ok, nil} ->
        {:noreply, socket}

      {:ok, patient} when is_map(patient) ->
        {:noreply, assign(socket, patients: [project(patient)])}

      {:error, reason} ->
        {:noreply, assign(socket, error: message(reason))}
    end
  end

  def handle_event("select_patient", %{"id" => id}, %{assigns: %{step: 1}} = socket)
      when is_binary(id) do
    socket = reset_booking(socket)

    case Enum.find(socket.assigns.patients, &(to_string(&1.id) == id)) do
      nil -> {:noreply, assign(socket, selected: nil, error: "La selección no es válida.")}
      patient -> {:noreply, assign(socket, selected: patient, error: nil)}
    end
  end

  def handle_event("clear_patient_selection", _params, %{assigns: %{step: 1}} = socket),
    do: {:noreply, socket |> reset_booking() |> assign(selected: nil, error: nil)}

  def handle_event(
        "next_booking_step",
        _params,
        %{assigns: %{step: 1, selected: patient}} = socket
      )
      when not is_nil(patient) do
    case journey_execute(socket, {:consultations, socket.assigns.current_internal_session}) do
      {:ok, consultations} ->
        {:noreply, assign(socket, step: 2, consultations: consultations, journey_error: nil)}

      _ ->
        {:noreply,
         assign(socket, journey_error: "No se pudieron consultar los tipos de consulta.")}
    end
  end

  def handle_event(
        "next_booking_step",
        _params,
        %{assigns: %{step: 2, consultation: consultation}} = socket
      )
      when not is_nil(consultation) do
    if journey_enabled?(socket),
      do: {:noreply, socket |> assign(step: 3) |> load_slots()},
      else: {:noreply, socket}
  end

  def handle_event(
        "next_booking_step",
        _params,
        %{assigns: %{step: 3, slot: slot}} = socket
      )
      when not is_nil(slot) do
    if journey_enabled?(socket),
      do: {:noreply, assign(socket, step: 4, journey_error: nil)},
      else: {:noreply, socket}
  end

  def handle_event("go_booking_step", %{"step" => target}, %{assigns: %{result: nil}} = socket)
      when target in ["1", "2", "3"] do
    step = String.to_integer(target)

    if step < socket.assigns.step do
      socket = assign(socket, step: step, journey_error: nil)
      {:noreply, if(step == 3, do: load_slots(socket), else: socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_consultation", %{"id" => id}, %{assigns: %{step: 2}} = socket) do
    case Enum.find(socket.assigns.consultations, &(&1.id == id)) do
      nil ->
        {:noreply, assign(socket, journey_error: "La consulta seleccionada no es válida.")}

      consultation ->
        {:noreply,
         assign(socket, consultation: consultation, slots: [], slot: nil, journey_error: nil)}
    end
  end

  def handle_event("change_booking_date", %{"date" => date}, %{assigns: %{step: 3}} = socket) do
    {:noreply, socket |> assign(booking_date: date, slot: nil, slots: []) |> load_slots()}
  end

  def handle_event("select_booking_slot", %{"id" => id}, %{assigns: %{step: 3}} = socket) do
    case Enum.find(socket.assigns.slots, &(&1.id == id)) do
      nil -> {:noreply, assign(socket, journey_error: "El horario seleccionado no es válido.")}
      slot -> {:noreply, assign(socket, slot: slot, journey_error: nil)}
    end
  end

  def handle_event(
        "simulate_booking",
        _params,
        %{assigns: %{demo: true, step: 4, result: nil}} = socket
      ) do
    with %{id: patient_id} <- socket.assigns.selected,
         %{id: consultation_id} <- socket.assigns.consultation,
         %{id: slot_id} <- socket.assigns.slot,
         {:ok, date} <- Date.from_iso8601(socket.assigns.booking_date),
         {:ok, %{simulated: true} = result} <-
           demo_execute(
             socket,
             {:simulate_confirmation, socket.assigns.current_internal_session,
              %{
                patient_id: patient_id,
                consultation_id: consultation_id,
                slot_id: slot_id,
                date: date
              }}
           ) do
      {:noreply, assign(socket, result: result, journey_error: nil)}
    else
      _ ->
        {:noreply,
         assign(socket, journey_error: "No se pudo completar la simulación. Revisá la selección.")}
    end
  end

  def handle_event(
        "confirm_booking",
        _params,
        %{assigns: %{real_booking: true, step: 4, result: nil}} = socket
      ) do
    with true <- real_booking?(),
         %{id: patient_id, document_number: document} <- socket.assigns.selected,
         %{id: consultation_id} <- socket.assigns.consultation,
         %{start_time: start_time} <- socket.assigns.slot,
         {:ok, result} <-
           journey_execute(
             socket,
             {:confirm, socket.assigns.current_internal_session,
              %{
                patient_id: patient_id,
                patient_document_number: document,
                consultation_type_id: consultation_id,
                start_time: start_time
              }}
           ) do
      {:noreply, assign(socket, result: result, journey_error: nil)}
    else
      {:error, reason} -> {:noreply, assign(socket, journey_error: booking_message(reason))}
      _ -> {:noreply, assign(socket, journey_error: booking_message(:unavailable))}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp reset_booking(socket) do
    assign(socket,
      consultations: [],
      consultation: nil,
      slots: [],
      slot: nil,
      result: nil,
      journey_error: nil
    )
  end

  defp load_slots(socket) do
    with {:ok, date} <- Date.from_iso8601(socket.assigns.booking_date),
         true <- Date.compare(date, Date.utc_today()) != :lt,
         {:ok, slots} <-
           journey_execute(
             socket,
             {:slots, socket.assigns.current_internal_session, socket.assigns.consultation.id,
              date}
           ) do
      selected = socket.assigns.slot
      slot = if selected, do: Enum.find(slots, &(&1.id == selected.id))
      assign(socket, slots: slots, slot: slot, journey_error: nil)
    else
      {:error, :invalid_format} ->
        assign(socket, slots: [], slot: nil, journey_error: "Revisá la fecha ingresada.")

      false ->
        assign(socket,
          slots: [],
          slot: nil,
          journey_error: "Revisá la fecha: elegí hoy o un día posterior."
        )

      _ ->
        assign(socket,
          slots: [],
          slot: nil,
          journey_error: "No se pudieron consultar los horarios disponibles."
        )
    end
  end

  defp demo_execute(socket, request) do
    if demo?(), do: execute(socket, request), else: {:error, :unavailable}
  end

  defp journey_enabled?(socket),
    do: (socket.assigns.demo and demo?()) or (socket.assigns.real_booking and real_booking?())

  defp journey_execute(socket, request) do
    if journey_enabled?(socket), do: execute(socket, request), else: {:error, :unavailable}
  end

  defp adapter,
    do:
      Application.get_env(
        :origen,
        :professional_patient_selector,
        OrigenWeb.ProfessionalPatientSelector
      )

  defp real_booking?, do: adapter() == OrigenWeb.ProfessionalPatientSelector

  defp load_related(socket) do
    case execute(socket, {:related, socket.assigns.current_internal_session}) do
      {:ok, patients} when is_list(patients) ->
        assign(socket, patients: Enum.map(patients, &project/1))

      {:error, reason} ->
        assign(socket, error: message(reason))
    end
  end

  defp execute(_socket, request) do
    case adapter() do
      nil -> {:error, :unavailable}
      adapter -> adapter.execute(request)
    end
  end

  defp demo? do
    Application.get_env(:origen, :professional_patient_selector) ==
      OrigenWeb.ProfessionalPatientSelectorDemo and
      OrigenWeb.ProfessionalPatientSelectorDemo.enabled?()
  end

  defp project(patient),
    do: Map.take(patient, [:id, :first_name, :last_name, :document_number])

  defp message(reason) when reason in [:invalid_document, :invalid_dni],
    do: "Revisá el DNI ingresado. Ingresá el documento completo."

  defp message(:unavailable),
    do:
      "La selección de pacientes todavía no está disponible. Falta conectar el servicio de pacientes."

  defp message(_), do: "No se pudieron consultar los pacientes. Intentá nuevamente."

  defp booking_message(reason)
       when reason in [
              :slot_already_booked,
              :slot_unavailable,
              :professional_schedule_conflict,
              :patient_schedule_conflict
            ],
       do:
         "No se creó el turno. El horario ya no está disponible. Volvé a fecha y horario para actualizar las opciones."

  defp booking_message(:unauthorized),
    do: "No se creó el turno. Tu sesión no permite esta operación. Volvé a iniciar sesión."

  defp booking_message(_),
    do: "No se creó el turno. Revisá la selección o intentá nuevamente."

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-[#F6F6F4] px-4 py-8 sm:px-6">
      <div class="mx-auto max-w-3xl space-y-6">
        <aside
          :if={@demo}
          id="patient-demo-notice"
          role="status"
          class="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950"
        >
          <p class="font-bold">Demostración · Datos ficticios · No crea turnos</p>
          <p class="mt-1">
            Los pacientes de esta demostración son ejemplos visuales, no relaciones reales del Profesional.
          </p>
          <p class="mt-1">
            Probá buscar los DNI 30111222 o 32444555. También hay un paciente de ejemplo que sólo aparece por DNI exacto, no en Mis pacientes.
          </p>
        </aside>
        <header class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-sm font-medium text-stone-500">Mi agenda</p>
            <h1 class="text-2xl font-bold text-black">Crear turno</h1>
          </div>
          <.link
            id="cancel-patient-selection"
            navigate={~p"/profesional/agenda"}
            class="rounded-lg border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700"
          >
            Cancelar y volver a la agenda
          </.link>
        </header>

        <ProfessionalBookingDemoSteps.progress step={@step} result={@result} demo={@demo} />

        <p
          :if={@journey_error}
          role="alert"
          class="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"
        >
          {@journey_error}
        </p>

        <section
          :if={@step == 1}
          aria-labelledby="patient-step-title"
          class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm sm:p-8"
        >
          <span class="inline-flex rounded-full bg-[#0A3847] px-3 py-1 text-xs font-semibold text-white">Paciente</span>
          <h2 id="patient-step-title" class="mt-4 text-xl font-bold text-black">
            Seleccioná al paciente
          </h2>
          <p class="mt-2 text-sm text-stone-600">
            Elegí uno de tus pacientes relacionados o buscá un paciente registrado por DNI exacto.
          </p>
          <p class="mt-2 text-sm text-stone-500">
            Buscar o seleccionar no crea un turno ni una relación con el paciente.
          </p>

          <div
            role="tablist"
            aria-label="Forma de seleccionar paciente"
            class="mt-6 flex gap-2 border-b border-stone-200 pb-3"
          >
            <button
              :for={{tab, label} <- [{"related", "Mis pacientes"}, {"dni", "Buscar por DNI"}]}
              id={"tab-#{tab}"}
              type="button"
              role="tab"
              aria-selected={to_string(@tab == tab)}
              aria-controls="patient-results"
              phx-click="change_patient_tab"
              phx-value-tab={tab}
              class={[
                "rounded-lg px-4 py-2 text-sm font-semibold focus-visible:outline-2 focus-visible:outline-offset-2",
                if(@tab == tab, do: "bg-[#0A3847] text-white", else: "bg-stone-100 text-black")
              ]}
            >
              {label}
            </button>
          </div>

          <div
            id="patient-results"
            role="tabpanel"
            aria-labelledby={"tab-#{@tab}"}
            class="mt-5 space-y-4"
          >
            <form
              :if={@tab == "dni"}
              id="patient-dni-form"
              phx-submit="search_patient"
              class="flex flex-wrap items-end gap-3"
            >
              <div class="flex-1">
                <label for="patient-dni" class="mb-1 block text-sm font-medium text-black">DNI completo</label>
                <input
                  id="patient-dni"
                  name="dni"
                  value={@dni}
                  required
                  maxlength="64"
                  autocomplete="off"
                  class="w-full rounded-lg border-stone-300 text-black"
                />
              </div>
              <button
                type="submit"
                phx-disable-with="Buscando…"
                class="rounded-lg bg-[#0A3847] px-4 py-2 font-semibold text-white"
              >Buscar</button>
            </form>

            <p
              :if={@error}
              role="alert"
              class="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900"
            >
              {@error}
            </p>
            <p
              :if={is_nil(@error) and @patients == [] and @tab == "related"}
              role="status"
              class="text-sm text-stone-600"
            >
              Todavía no tenés pacientes relacionados. Podés buscar un paciente registrado por DNI exacto.
            </p>
            <p
              :if={is_nil(@error) and @searched and @patients == []}
              role="status"
              class="text-sm text-stone-600"
            >
              No se encontró un paciente registrado con ese DNI. Podés corregirlo o cancelar.
            </p>

            <ul aria-label="Pacientes disponibles" class="space-y-3">
              <li
                :for={patient <- @patients}
                class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-stone-200 p-4"
              >
                <div>
                  <p class="font-semibold text-black">{patient.first_name} {patient.last_name}</p>
                  <p class="text-sm text-stone-600">DNI {patient.document_number}</p>
                </div>
                <button
                  id={"patient-#{patient.id}"}
                  type="button"
                  phx-click="select_patient"
                  phx-value-id={patient.id}
                  class="rounded-lg border border-[#0A3847] px-4 py-2 text-sm font-semibold text-black"
                >Elegir</button>
              </li>
            </ul>

            <div
              :if={@selected}
              id="selected-patient"
              role="status"
              class="rounded-lg border border-emerald-200 bg-emerald-50 p-4"
            >
              <p class="font-semibold text-emerald-900">Paciente seleccionado</p>
              <p class="text-sm text-emerald-900">
                {@selected.first_name} {@selected.last_name} · DNI {@selected.document_number}
              </p>
              <button
                id="clear-patient-selection"
                type="button"
                phx-click="clear_patient_selection"
                class="mt-2 text-sm font-semibold underline"
              >Quitar selección</button>
            </div>
          </div>

          <footer class="mt-6 flex flex-col items-end border-t border-stone-200 pt-4">
            <p id="patient-only-notice" class="w-full text-sm text-stone-500">
              <span :if={@demo}>Podés recorrer los siguientes pasos con datos ficticios. No se creará ningún turno.</span>
              <span :if={@real_booking}>El turno y la relación se crean únicamente al confirmar al final del recorrido.</span>
              <span :if={not @demo and not @real_booking}>El servicio de reserva no está disponible.</span>
            </p>
            <button
              id="patient-selection-next"
              type="button"
              phx-click="next_booking_step"
              disabled={is_nil(@selected) or not (@demo or @real_booking)}
              aria-describedby="patient-only-notice"
              class="mt-3 rounded-lg bg-[#0A3847] px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-stone-200 disabled:text-stone-500"
            >Continuar</button>
          </footer>
        </section>
        <ProfessionalBookingDemoSteps.consultation
          :if={@step == 2}
          patient={@selected}
          consultations={@consultations}
          selected={@consultation}
          demo={@demo}
        />
        <ProfessionalBookingDemoSteps.schedule
          :if={@step == 3}
          consultation={@consultation}
          date={@booking_date}
          slots={@slots}
          selected={@slot}
          demo={@demo}
        />
        <ProfessionalBookingDemoSteps.confirmation
          :if={@step == 4}
          patient={@selected}
          consultation={@consultation}
          date={@booking_date}
          slot={@slot}
          result={@result}
          demo={@demo}
        />
      </div>
    </main>
    """
  end
end
