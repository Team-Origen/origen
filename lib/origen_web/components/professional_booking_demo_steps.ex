defmodule OrigenWeb.ProfessionalBookingDemoSteps do
  @moduledoc "Visual steps for the development booking demo; no data access or persistence."
  use OrigenWeb, :html

  attr :step, :integer, required: true
  attr :result, :any, default: nil

  def progress(assigns) do
    ~H"""
    <nav
      id="booking-progress"
      aria-label="Progreso de creación de turno"
      class="border-b border-stone-200 bg-stone-50 px-2 py-5 sm:px-4"
    >
      <p role="status" class="mb-5 text-xs font-medium tracking-wide text-black">
        <%= if @result do %>
          Demostración completada
        <% else %>
          Paso {@step} de 4 · {step_name(@step)}
        <% end %>
      </p>
      <ol class="flex items-start">
        <li
          :for={number <- 1..4}
          id={"booking-step-#{number}"}
          aria-current={if number == @step and is_nil(@result), do: "step", else: nil}
          data-state={
            cond do
              not is_nil(@result) or number < @step -> "completed"
              number == @step -> "current"
              true -> "pending"
            end
          }
          class="relative flex min-w-0 flex-1 flex-col items-center gap-2 text-center"
        >
          <span
            :if={number < 4}
            aria-hidden="true"
            class="absolute left-1/2 top-4 h-px w-full bg-stone-300"
          />
          <span
            aria-hidden="true"
            class={[
              "relative z-10 flex size-8 items-center justify-center rounded-full border text-xs",
              if(number == @step and is_nil(@result),
                do: "border-stone-600 bg-stone-100 font-bold text-black ring-4 ring-stone-50",
                else: "border-stone-300 bg-stone-50 text-black ring-4 ring-stone-50"
              )
            ]}
          >
            {if number < @step or not is_nil(@result), do: "✓", else: number}
          </span>
          <span class={[
            "px-1 text-xs leading-snug sm:text-sm",
            if(number == @step and is_nil(@result),
              do: "font-semibold text-black",
              else: "font-normal text-black"
            )
          ]}>
            {step_name(number)}
          </span>
          <span :if={number < @step or not is_nil(@result)} class="sr-only">Completado</span>
        </li>
      </ol>
    </nav>
    """
  end

  attr :patient, :map, required: true
  attr :consultations, :list, required: true
  attr :selected, :any, default: nil

  def consultation(assigns) do
    ~H"""
    <section
      aria-labelledby="consultation-step-title"
      class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm sm:p-8"
    >
      <h2 id="consultation-step-title" class="text-xl font-bold text-black">
        Elegí el tipo de consulta
      </h2>
      <p class="mt-2 text-sm text-stone-600">
        Paciente: {@patient.first_name} {@patient.last_name} · DNI {@patient.document_number}
      </p>
      <p class="mt-2 text-sm text-stone-500">
        Consultas de ejemplo. La duración determina los horarios que podés elegir.
      </p>
      <div class="mt-6 space-y-3" role="group" aria-label="Tipos de consulta de demostración">
        <button
          :for={consultation <- @consultations}
          id={"consultation-#{consultation.id}"}
          type="button"
          phx-click="select_consultation"
          phx-value-id={consultation.id}
          aria-pressed={to_string(not is_nil(@selected) and @selected.id == consultation.id)}
          class={[
            "flex w-full flex-wrap items-center justify-between gap-2 rounded-lg border p-4 text-left focus-visible:outline-2 focus-visible:outline-offset-2",
            if(not is_nil(@selected) and @selected.id == consultation.id,
              do: "border-[#0A3847] bg-teal-50",
              else: "border-stone-200 hover:bg-stone-50"
            )
          ]}
        >
          <span class="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-stone-50 px-3 py-1 text-sm font-semibold text-black">
            <span
              id={"consultation-color-#{consultation.id}"}
              role="img"
              aria-label={"Color asignado a #{consultation.name}"}
              title={"Color asignado a #{consultation.name}"}
              class="inline-block size-3 shrink-0 rounded-full border border-stone-300"
              style={"background-color: #{consultation.color}"}
            />
            {consultation.name}
          </span>
          <span class="flex flex-col gap-1 sm:items-end">
            <span class="font-semibold text-black">{format_ars(consultation.exact_price_ars)}</span>
            <span class="text-sm text-stone-600">{consultation.duration_minutes} minutos</span>
          </span>
        </button>
      </div>
      <p :if={@consultations == []} role="status" class="mt-4 text-sm text-stone-600">
        No hay tipos de consulta disponibles.
      </p>
      <.actions previous={1} next_id="consultation-next" disabled={is_nil(@selected)} />
    </section>
    """
  end

  attr :consultation, :map, required: true
  attr :date, :string, required: true
  attr :slots, :list, required: true
  attr :selected, :any, default: nil

  def schedule(assigns) do
    ~H"""
    <section
      aria-labelledby="schedule-step-title"
      class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm sm:p-8"
    >
      <h2 id="schedule-step-title" class="text-xl font-bold text-black">Elegí fecha y horario</h2>
      <p class="mt-2 text-sm text-stone-600">
        {@consultation.name} · {@consultation.duration_minutes} minutos
      </p>
      <p class="mt-2 text-sm text-stone-500">
        Disponibilidad ficticia: elegir un horario no lo reserva.
      </p>
      <form
        id="booking-date-form"
        phx-change="change_booking_date"
        phx-submit="change_booking_date"
        class="mt-6"
      >
        <label for="booking-date" class="mb-2 block text-sm font-semibold text-black">Fecha</label>
        <input
          id="booking-date"
          name="date"
          type="date"
          value={@date}
          min={Date.to_iso8601(Date.utc_today())}
          required
          class="w-full rounded-lg border-stone-300 text-black sm:w-auto"
        />
      </form>
      <h3 class="mt-6 text-sm font-semibold text-black">Horarios de demostración</h3>
      <div role="group" aria-label="Horarios de demostración" class="mt-3 flex flex-wrap gap-3">
        <button
          :for={slot <- @slots}
          id={"slot-#{slot.id}"}
          type="button"
          phx-click="select_booking_slot"
          phx-value-id={slot.id}
          aria-pressed={to_string(not is_nil(@selected) and @selected.id == slot.id)}
          class={[
            "rounded-lg border px-5 py-3 text-sm font-semibold focus-visible:outline-2 focus-visible:outline-offset-2",
            if(not is_nil(@selected) and @selected.id == slot.id,
              do: "border-[#0A3847] bg-[#0A3847] text-white",
              else: "border-stone-300 text-[#0A3847] hover:bg-stone-50"
            )
          ]}
        >{slot.label}</button>
      </div>
      <p :if={@slots == []} role="status" class="mt-3 text-sm text-stone-600">
        No hay horarios disponibles para la fecha seleccionada.
      </p>
      <.actions previous={2} next_id="slot-next" disabled={is_nil(@selected)} />
    </section>
    """
  end

  attr :patient, :map, required: true
  attr :consultation, :map, required: true
  attr :date, :string, required: true
  attr :slot, :map, required: true
  attr :result, :any, default: nil

  def confirmation(assigns) do
    ~H"""
    <section
      aria-labelledby="confirmation-step-title"
      class="rounded-xl border border-stone-200 bg-white p-5 shadow-sm sm:p-8"
    >
      <h2 id="confirmation-step-title" class="text-xl font-bold text-black">
        {if @result, do: "Demostración completada", else: "Revisá el turno de ejemplo"}
      </h2>
      <div
        :if={@result}
        id="booking-demo-result"
        role="status"
        class="mt-4 rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-emerald-900"
      >
        <p class="font-bold">Simulación de turno confirmado</p>
        <p class="mt-1">No se creó ningún turno ni relación en la base de datos.</p>
      </div>
      <dl id="booking-summary" class="mt-6 divide-y divide-stone-100">
        <div class="py-3">
          <dt class="text-sm text-black">Paciente</dt><dd class="font-semibold text-black">
            {@patient.first_name} {@patient.last_name}
          </dd>
        </div>
        <div class="py-3">
          <dt class="text-sm text-black">DNI</dt><dd class="text-stone-800">
            {@patient.document_number}
          </dd>
        </div>
        <div class="py-3">
          <dt class="text-sm text-black">Consulta</dt><dd class="text-stone-800">
            {@consultation.name} · {@consultation.duration_minutes} minutos
          </dd>
        </div>
        <div class="py-3">
          <dt class="text-sm text-black">Monto</dt><dd class="text-stone-800">
            {format_ars(@consultation.exact_price_ars)}
          </dd>
        </div>
        <div class="py-3">
          <dt class="text-sm text-black">Fecha</dt><dd class="text-stone-800">
            {display_date(@date)}
          </dd>
        </div>
        <div class="py-3">
          <dt class="text-sm text-black">Horario</dt><dd class="text-stone-800">{@slot.label}</dd>
        </div>
      </dl>
      <p :if={is_nil(@result)} class="mt-4 text-sm text-stone-500">
        En el recorrido real, una reserva del Profesional queda confirmada. Esta acción sólo simula ese resultado.
      </p>
      <footer class="mt-6 flex flex-wrap items-center justify-between gap-3 border-t border-stone-200 pt-4">
        <button
          :if={is_nil(@result)}
          type="button"
          phx-click="go_booking_step"
          phx-value-step="3"
          class="rounded-lg border border-stone-300 px-4 py-2 text-sm font-semibold text-stone-700"
        >Volver</button>
        <button
          :if={is_nil(@result)}
          id="simulate-booking"
          type="button"
          phx-click="simulate_booking"
          phx-disable-with="Simulando…"
          class="rounded-lg bg-[#0A3847] px-4 py-2 text-sm font-semibold text-white"
        >Simular confirmación</button>
        <.link
          :if={@result}
          navigate={~p"/profesional/agenda"}
          class="rounded-lg bg-[#0A3847] px-4 py-2 text-sm font-semibold text-white"
        >Volver a mi agenda</.link>
      </footer>
    </section>
    """
  end

  attr :previous, :integer, required: true
  attr :next_id, :string, required: true
  attr :disabled, :boolean, required: true

  defp actions(assigns) do
    ~H"""
    <footer class="mt-6 flex items-center justify-between gap-3 border-t border-stone-200 pt-4">
      <button
        type="button"
        phx-click="go_booking_step"
        phx-value-step={@previous}
        class="rounded-lg border border-stone-300 px-4 py-2 text-sm font-semibold text-stone-700"
      >Volver</button>
      <button
        id={@next_id}
        type="button"
        phx-click="next_booking_step"
        disabled={@disabled}
        class="rounded-lg bg-[#0A3847] px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-stone-200 disabled:text-stone-500"
      >Continuar</button>
    </footer>
    """
  end

  # Match the consultation-type catalog's ARS display without floating-point conversion.
  defp format_ars(price) do
    {whole, fraction} =
      case price |> Decimal.to_string(:normal) |> String.split(".", parts: 2) do
        [whole] -> {whole, ""}
        [whole, fraction] -> {whole, fraction}
      end

    grouped =
      whole
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(".", &Enum.join/1)
      |> String.reverse()

    "ARS #{grouped},#{String.pad_trailing(fraction, 2, "0")}"
  end

  defp step_name(1), do: "Paciente"
  defp step_name(2), do: "Consulta"
  defp step_name(3), do: "Fecha y horario"
  defp step_name(4), do: "Confirmación"

  defp display_date(date) do
    {:ok, parsed} = Date.from_iso8601(date)
    Calendar.strftime(parsed, "%d/%m/%Y")
  end
end
