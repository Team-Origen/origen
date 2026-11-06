defmodule OrigenWeb.PatientBookingCalendarFixtures do
  defmodule EmptyCalendar do
    @behaviour Origen.Appointments.Calendar

    @impl true
    def list_professionals, do: {:ok, []}

    @impl true
    def get_daily_schedule(_professional_id, date),
      do:
        {:ok,
         %{
           date: date,
           professional_id: "",
           professional_name: "",
           specialty: "",
           slots: [],
           cancellation_policy: %{}
         }}
  end

  defmodule ErrorCalendar do
    @behaviour Origen.Appointments.Calendar

    @impl true
    def list_professionals, do: {:error, :unavailable}

    @impl true
    def get_daily_schedule(_professional_id, _date), do: {:error, :unavailable}
  end

  defmodule ScheduleErrorCalendar do
    @behaviour Origen.Appointments.Calendar

    @impl true
    def list_professionals do
      {:ok, [%{id: "PRO-ERROR-001", name: "Dra. Error", specialty: "Pruebas"}]}
    end

    @impl true
    def get_daily_schedule(_professional_id, _date), do: {:error, :unavailable}
  end

  defmodule UnavailableCatalog do
    @behaviour Origen.ConsultationTypes.Catalog

    @impl true
    def execute(_operation), do: {:error, :unavailable}
  end

  defmodule EmptyCatalog do
    @behaviour Origen.ConsultationTypes.Catalog

    @impl true
    def execute({:list, %{professional_reference: _professional_reference}}) do
      {:ok,
       %{
         source: :test,
         professional_reference: "PRO-ERROR-001",
         agenda_interval_minutes: 30,
         consultation_types: []
       }}
    end
  end

  defmodule AvailableCatalog do
    @behaviour Origen.ConsultationTypes.Catalog

    @impl true
    def execute({:list, %{professional_reference: professional_reference}}) do
      {:ok,
       %{
         source: :test,
         professional_reference: professional_reference,
         agenda_interval_minutes: 30,
         consultation_types: [
           %{
             id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
             name: "Consulta de prueba",
             interval_count: 1,
             exact_price_ars: Decimal.new("10000.00"),
             status: :active
           }
         ]
       }}
    end
  end
end
