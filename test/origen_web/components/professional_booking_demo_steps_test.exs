defmodule OrigenWeb.ProfessionalBookingDemoStepsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias OrigenWeb.ProfessionalBookingDemoSteps

  test "progress renders the current step and makes progress non-interactive" do
    html = render_component(&ProfessionalBookingDemoSteps.progress/1, %{step: 2, result: nil})

    assert html =~ "Paso 2 de 4 · Consulta"
    assert html =~ ~s(id="booking-step-2")
    assert html =~ ~s(aria-current="step")
    assert html =~ ~s(data-state="completed")
    refute html =~ "<button"
    refute html =~ "phx-click"
  end

  test "consultation renders catalog amounts, colors, and guarded advance" do
    consultation = %{
      id: "initial",
      name: "Consulta inicial",
      duration_minutes: 45,
      exact_price_ars: Decimal.new("25000.00"),
      color: "#0A7C86"
    }

    html =
      render_component(&ProfessionalBookingDemoSteps.consultation/1, %{
        patient: %{first_name: "Ana", last_name: "Ejemplo", document_number: "30111222"},
        consultations: [consultation],
        selected: nil
      })

    assert html =~ "ARS 25.000,00"
    assert html =~ ~s(background-color: #0A7C86)
    assert html =~ ~s(id="consultation-next")
    assert html =~ "disabled"
  end

  test "confirmation labels the result as simulated and retains the selected amount" do
    html =
      render_component(&ProfessionalBookingDemoSteps.confirmation/1, %{
        patient: %{first_name: "Lucía", last_name: "Ejemplo", document_number: "99000123"},
        consultation: %{
          name: "Seguimiento",
          duration_minutes: 30,
          exact_price_ars: Decimal.new("18000.00")
        },
        date: "2026-10-27",
        slot: %{label: "10:30"},
        result: %{simulated: true}
      })

    assert html =~ "Simulación de turno confirmado"
    assert html =~ "No se creó ningún turno ni relación en la base de datos."
    assert html =~ "ARS 18.000,00"
    refute html =~ "simulate-booking"
  end
end
