defmodule OrigenWeb.ProfessionalPatientSelectorDemo do
  @moduledoc """
  Development-only visual fixtures for patient selection. Never reads or writes
  the database and never creates professional-patient relationships.
  """

  @patients [
    %{id: "demo-ana", first_name: "Ana", last_name: "Ejemplo", document_number: "30111222"},
    %{
      id: "demo-martin",
      first_name: "Martín",
      last_name: "Demostración",
      document_number: "32444555"
    }
  ]

  # Registered in the demo, but not related to the Professional.
  @search_only_patient %{
    id: "demo-search-only",
    first_name: "Lucía",
    last_name: "Ejemplo",
    document_number: "99000123"
  }

  @searchable_patients @patients ++ [@search_only_patient]

  @consultations [
    %{
      id: "demo-initial",
      name: "Consulta inicial",
      duration_minutes: 45,
      exact_price_ars: Decimal.new("25000.00"),
      color: "#0A7C86"
    },
    %{
      id: "demo-followup",
      name: "Consulta de seguimiento",
      duration_minutes: 30,
      exact_price_ars: Decimal.new("18000.00"),
      color: "#7C3AED"
    }
  ]

  @slots [
    %{id: "0900", label: "09:00"},
    %{id: "1030", label: "10:30"},
    %{id: "1400", label: "14:00"}
  ]

  def enabled?, do: Application.get_env(:origen, :dev_routes, false) == true

  def execute(request) do
    if enabled?(), do: respond(request), else: {:error, :unavailable}
  end

  defp respond({:related, _session}), do: {:ok, @patients}

  defp respond({:consultations, _session}), do: {:ok, @consultations}

  defp respond({:slots, _session, consultation_id, %Date{} = date}) do
    if Enum.any?(@consultations, &(&1.id == consultation_id)) and
         Date.compare(date, Date.utc_today()) != :lt,
       do: {:ok, @slots},
       else: {:error, :invalid_selection}
  end

  defp respond({:simulate_confirmation, _session, selection}) do
    valid? =
      Enum.any?(@searchable_patients, &(&1.id == selection.patient_id)) and
        Enum.any?(@consultations, &(&1.id == selection.consultation_id)) and
        Enum.any?(@slots, &(&1.id == selection.slot_id)) and
        Date.compare(selection.date, Date.utc_today()) != :lt

    if valid?,
      do: {:ok, %{simulated: true, state: :confirmed}},
      else: {:error, :invalid_selection}
  end

  defp respond({:search, _session, document}) do
    if Regex.match?(~r/^\d{7,8}$/, document) do
      {:ok, Enum.find(@searchable_patients, &(&1.document_number == document))}
    else
      {:error, :invalid_document}
    end
  end
end
