defmodule Origen.Appointments.MockCalendar do
  @moduledoc """
  Deterministic mock calendar adapter used for reviewing the patient booking UI (#91, #92)
  without requiring a production database or external schedule dependencies.
  """

  @behaviour Origen.Appointments.Calendar

  alias Origen.Appointments.Availability

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

  @demo_windows [{~T[09:00:00], ~T[12:00:00]}, {~T[14:00:00], ~T[17:00:00]}]
  @demo_occupancies []

  @impl true
  def list_professionals do
    {:ok, @professionals}
  end

  @impl true
  def get_daily_schedule(professional_id, date), do: get_daily_schedule(professional_id, date, [])

  @impl true
  def get_daily_schedule(professional_id, %Date{} = date, opts) do
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
            duration = Keyword.get(opts, :duration_minutes, 30)
            interval = Keyword.get(opts, :agenda_interval_minutes, duration)

            now =
              Keyword.get(opts, :now) ||
                if(Application.get_env(:origen, :env) == :test,
                  do: ~U[2026-09-23 08:00:00Z],
                  else: DateTime.utc_now()
                )

            slots =
              Availability.calculate_slots(
                date,
                @demo_windows,
                @demo_occupancies,
                agenda_interval_minutes: interval,
                duration_minutes: duration,
                min_lead_time_minutes: Keyword.get(opts, :min_lead_time_minutes, 30),
                now: now
              )

            {:ok,
             %{
               date: date,
               professional_id: professional.id,
               professional_name: professional.name,
               specialty: professional.specialty,
               slots: slots,
               cancellation_policy: @default_policy
             }}
        end
    end
  end
end
