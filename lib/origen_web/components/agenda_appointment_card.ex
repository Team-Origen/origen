defmodule OrigenWeb.Components.AgendaAppointmentCard do
  @moduledoc """
  Existing Mi agenda appointment row layout, shared with the isolated design preview.
  Callers retain their own content, controls and event handlers.
  """
  use OrigenWeb, :html

  attr :id, :string, required: true
  slot :appointment, required: true
  slot :patient, required: true

  def card(assigns) do
    ~H"""
    <div
      id={@id}
      role="listitem"
      class="bg-white rounded-xl shadow-sm border border-stone-200 p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 hover:border-stone-300 transition"
    >
      <div data-section="appointment" class="space-y-1">{render_slot(@appointment)}</div>
      <div
        data-section="patient"
        class="text-left sm:text-right border-t sm:border-t-0 pt-3 sm:pt-0 border-stone-100 space-y-0.5"
      >
        {render_slot(@patient)}
      </div>
    </div>
    """
  end
end
