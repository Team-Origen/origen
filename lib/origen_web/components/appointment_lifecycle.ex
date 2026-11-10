defmodule OrigenWeb.Components.AppointmentLifecycle do
  use OrigenWeb, :html

  attr :appointment, :map, required: true
  attr :timezone, :string, required: true

  def history(assigns) do
    ~H"""
    <article
      id={"professional-history-appointment-#{@appointment.id}"}
      class="rounded-xl border border-stone-200 bg-white p-4 shadow-sm"
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h3 class="font-semibold text-stone-900">
            {@appointment.consultation_type_name}
          </h3>
          <p class="mt-1 text-sm text-stone-600">
            {local_time(@appointment.start_time, @timezone, "%d/%m/%Y · %H:%M")} a {local_time(
              @appointment.end_time,
              @timezone,
              "%H:%M"
            )} hs
          </p>
          <p class="mt-1 text-xs text-stone-500">Turno #{@appointment.id}</p>
        </div>

        <span class={"inline-flex w-fit rounded-full border px-3 py-1 text-xs font-semibold #{status_class(@appointment.status)}"}>
          {status_label(@appointment.status)}
        </span>
      </div>

      <div
        :if={@appointment.cancellation_origin || @appointment.cancellation_reason}
        class="mt-3 border-t border-stone-100 pt-3 text-sm"
      >
        <p :if={@appointment.cancellation_origin}>
          <span class="font-semibold text-stone-600">Origen:</span>
          {cancellation_origin_label(@appointment.cancellation_origin)}
        </p>
        <p :if={@appointment.cancellation_reason}>
          <span class="font-semibold text-stone-600">Motivo:</span>
          {@appointment.cancellation_reason}
        </p>
      </div>
    </article>
    """
  end

  defp local_time(datetime, timezone, format),
    do: datetime |> DateTime.shift_zone!(timezone) |> Calendar.strftime(format)

  defp status_label("requested"), do: "Pendiente de aprobación"
  defp status_label("confirmed"), do: "Confirmado"
  defp status_label("expired"), do: "Vencido"
  defp status_label("cancelled"), do: "Cancelado"
  defp status_label("attended"), do: "Asistió"
  defp status_label("no_show"), do: "No asistió"
  defp status_label(_status), do: "Estado no disponible"

  defp status_class("confirmed"), do: "bg-emerald-100 text-emerald-800 border-emerald-200"
  defp status_class("requested"), do: "bg-amber-100 text-amber-800 border-amber-200"
  defp status_class("expired"), do: "bg-stone-200 text-stone-700 border-stone-300"
  defp status_class("cancelled"), do: "bg-red-100 text-red-800 border-red-200"

  defp status_class(status) when status in ["attended", "no_show"],
    do: "bg-blue-100 text-blue-800 border-blue-200"

  defp status_class(_status), do: "bg-stone-100 text-stone-700 border-stone-200"

  defp cancellation_origin_label("professional"), do: "Profesional"
  defp cancellation_origin_label("secretary"), do: "Secretaría"
  defp cancellation_origin_label("patient"), do: "Paciente"
  defp cancellation_origin_label(origin) when is_binary(origin), do: origin
  defp cancellation_origin_label(_origin), do: "Sin origen informado"
end
