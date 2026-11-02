defmodule OrigenWeb.ProfessionalPatientSelector do
  @moduledoc """
  Real data adapter for the professional booking journey (#316).

  All permissions, exact-DNI validation, availability and transactional writes
  remain in the public Booking API. No professional identity comes from the UI.
  """
  alias Origen.Booking

  def execute({:related, session}), do: Booking.list_professional_patients(session)

  def execute({:search, session, document}),
    do: Booking.find_professional_patient_by_dni(session, document)

  def execute({:consultations, session}),
    do: Booking.list_professional_consultation_types(session)

  def execute({:slots, session, consultation_id, date}) do
    with {:ok, schedule} <-
           Booking.get_professional_booking_schedule(session, consultation_id, date) do
      {:ok,
       Enum.map(schedule.slots, fn slot ->
         %{
           id: Calendar.strftime(slot.start_time, "%H%M"),
           label: Calendar.strftime(slot.start_time, "%H:%M"),
           start_time: DateTime.new!(date, slot.start_time, "Etc/UTC")
         }
       end)}
    end
  end

  def execute({:confirm, session, params}),
    do: Booking.reserve_professional_appointment(session, params)
end
