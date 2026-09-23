defmodule Origen.Appointments.MockCalendar do
  @moduledoc """
  Deterministic mock calendar adapter used for reviewing the patient booking UI (#91)
  without requiring a production database or external schedule dependencies.
  """

  @behaviour Origen.Appointments.Calendar

  @professionals [
    %{
      id: "PRO-DEMO-001",
      name: "Dra. Sofía Martínez",
      specialty: "Medicina General"
    },
    %{
      id: "PRO-DEMO-002",
      name: "Dr. Lucas Varela",
      specialty: "Cardiología"
    }
  ]

  @default_policy %{
    cutoff_description:
      "Podés cancelar sin costo hasta las 18:00 del día anterior a la cita (D-1).",
    penalty_percentage: 50,
    penalty_description:
      "Cancelaciones posteriores a las 18:00 de D-1 o inasistencias aplican una política de multa del 50% según RF-16."
  }

  @impl true
  def list_professionals do
    {:ok, @professionals}
  end

  @impl true
  def get_daily_schedule(professional_id, %Date{} = date) do
    case Enum.find(@professionals, &(&1.id == professional_id)) do
      nil ->
        {:error, :invalid_professional}

      professional ->
        cond do
          date.day == 31 ->
            {:error, :schedule_temporarily_unavailable}

          Date.day_of_week(date) in [6, 7] ->
            {:ok,
             %{
               date: date,
               professional_id: professional.id,
               professional_name: professional.name,
               specialty: professional.specialty,
               slots: [],
               cancellation_policy: @default_policy
             }}

          true ->
            {:ok,
             %{
               date: date,
               professional_id: professional.id,
               professional_name: professional.name,
               specialty: professional.specialty,
               slots: generate_weekday_slots(date),
               cancellation_policy: @default_policy
             }}
        end
    end
  end

  defp generate_weekday_slots(date) do
    times = [
      {~T[09:00:00], ~T[09:30:00], "09:00", "09:30"},
      {~T[09:30:00], ~T[10:00:00], "09:30", "10:00"},
      {~T[10:00:00], ~T[10:30:00], "10:00", "10:30"},
      {~T[10:30:00], ~T[11:00:00], "10:30", "11:00"},
      {~T[11:00:00], ~T[11:30:00], "11:00", "11:30"},
      {~T[11:30:00], ~T[12:00:00], "11:30", "12:00"},
      {~T[14:00:00], ~T[14:30:00], "14:00", "14:30"},
      {~T[14:30:00], ~T[15:00:00], "14:30", "15:00"},
      {~T[15:00:00], ~T[15:30:00], "15:00", "15:30"},
      {~T[15:30:00], ~T[16:00:00], "15:30", "16:00"},
      {~T[16:00:00], ~T[16:30:00], "16:00", "16:30"},
      {~T[16:30:00], ~T[17:00:00], "16:30", "17:00"}
    ]

    date_str = Date.to_iso8601(date)

    Enum.map(times, fn {start_t, end_t, start_f, end_f} ->
      slot_id = "SLOT-" <> date_str <> "-" <> String.replace(start_f, ":", "")

      %{
        id: slot_id,
        start_time: start_t,
        end_time: end_t,
        start_formatted: start_f,
        end_formatted: end_f,
        status: :available
      }
    end)
  end
end
