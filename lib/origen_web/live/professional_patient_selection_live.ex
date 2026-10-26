defmodule OrigenWeb.ProfessionalPatientSelectionLive do
  @moduledoc """
  Patient selection preparation for #315. No booking or relationship writes.

  `:professional_patient_selector` is a server-configured contract boundary for
  #314. It accepts `{:related, session}` and `{:search, session, exact_document}`,
  returning `{:ok, patients}`, `{:ok, patient | nil}` or `{:error, reason}`.
  Development config enables a clearly labeled visual demo; no real backend
  adapter is enabled by default. Authorization and exact-match validation remain
  the responsibility of the eventual backend adapter.
  """
  use OrigenWeb, :live_view

  alias Origen.Patients.Persona

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Crear turno · Paciente",
        demo: demo?(),
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
  def handle_event("change_patient_tab", %{"tab" => tab}, socket)
      when tab in ["related", "dni"] do
    socket =
      socket
      |> assign(tab: tab, selected: nil, patients: [], searched: false, dni: "", error: nil)

    {:noreply, if(tab == "related", do: load_related(socket), else: socket)}
  end

  def handle_event("search_patient", %{"dni" => dni}, %{assigns: %{tab: "dni"}} = socket)
      when is_binary(dni) do
    document = Persona.normalize_number(dni)

    socket =
      socket
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

  def handle_event("select_patient", %{"id" => id}, socket)
      when is_binary(id) do
    case Enum.find(socket.assigns.patients, &(to_string(&1.id) == id)) do
      nil -> {:noreply, assign(socket, selected: nil, error: "La selección no es válida.")}
      patient -> {:noreply, assign(socket, selected: patient, error: nil)}
    end
  end

  def handle_event("clear_patient_selection", _params, socket),
    do: {:noreply, assign(socket, selected: nil, error: nil)}

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp load_related(socket) do
    case execute(socket, {:related, socket.assigns.current_internal_session}) do
      {:ok, patients} when is_list(patients) ->
        assign(socket, patients: Enum.map(patients, &project/1))

      {:error, reason} ->
        assign(socket, error: message(reason))
    end
  end

  defp execute(_socket, request) do
    case Application.get_env(:origen, :professional_patient_selector) do
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

  defp message(:invalid_document), do: "Revisá el DNI ingresado. Ingresá el documento completo."

  defp message(:unavailable),
    do:
      "La selección de pacientes todavía no está disponible. Falta conectar el servicio de pacientes."

  defp message(_), do: "No se pudieron consultar los pacientes. Intentá nuevamente."

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

        <section
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
              Por ahora sólo está preparado el paso de selección de paciente. No se creará ningún turno.
            </p>
            <button
              id="patient-selection-next"
              type="button"
              disabled
              aria-describedby="patient-only-notice"
              class="mt-3 rounded-lg bg-[#0A3847] px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-stone-200 disabled:text-stone-500"
            >Continuar</button>
          </footer>
        </section>
      </div>
    </main>
    """
  end
end
