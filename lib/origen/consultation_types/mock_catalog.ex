defmodule Origen.ConsultationTypes.MockCatalog do
  @moduledoc """
  Deterministic non-production catalog used to review the consultation-type UI.
  """

  @behaviour Origen.ConsultationTypes.Catalog

  @impl true
  def execute(operation) do
    if demo_enabled?() do
      execute_demo(operation)
    else
      {:error, :unavailable}
    end
  end

  defp execute_demo({:list, %{professional_reference: "PRO-DEMO-001"}}) do
    {:ok,
     %{
       source: :demo,
       professional_reference: "PRO-DEMO-001",
       agenda_interval_minutes: 15,
       consultation_types: [
         %{
           id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
           reference: "TC-001",
           name: "Consulta general",
           interval_count: 2,
           exact_price_ars: Decimal.new("18000.00"),
           color: "#0A7C86",
           status: :active
         },
         %{
           id: "018f4a5b-0d62-7a44-8e32-2f608bfcb002",
           reference: "TC-002",
           name: "Control",
           interval_count: 1,
           exact_price_ars: Decimal.new("12000.00"),
           color: "#4DB5E6",
           status: :active
         },
         %{
           id: "018f4a5b-0d62-7a44-8e32-2f608bfcb003",
           reference: "TC-003",
           name: "Consulta especializada",
           interval_count: 3,
           exact_price_ars: Decimal.new("25000.00"),
           color: "#B47CC7",
           status: :active
         },
         %{
           id: "018f4a5b-0d62-7a44-8e32-2f608bfcb004",
           reference: "TC-004",
           name: "Procedimiento",
           interval_count: 4,
           exact_price_ars: Decimal.new("35000.00"),
           color: "#FFD000",
           status: :active
         },
         %{
           id: "018f4a5b-0d62-7a44-8e32-2f608bfcb005",
           reference: "TC-005",
           name: "Seguimiento",
           interval_count: 2,
           exact_price_ars: Decimal.new("15000.00"),
           color: "#D6F5A3",
           status: :inactive,
           inactive_duration_minutes: 30
         },
         %{
           id: "018f4a5b-0d62-7a44-8e32-2f608bfcb006",
           reference: "TC-006",
           name: "Urgencia",
           interval_count: 3,
           exact_price_ars: Decimal.new("30000.00"),
           color: "#FF0000",
           status: :active
         }
       ]
     }}
  end

  defp execute_demo(_operation), do: {:error, :unavailable}

  defp demo_enabled? do
    Application.get_env(:origen, :consultation_catalog_demo_enabled, false) and Mix.env() != :prod
  end
end
