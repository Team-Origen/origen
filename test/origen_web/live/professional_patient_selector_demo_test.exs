defmodule OrigenWeb.ProfessionalPatientSelectorDemoTest do
  use ExUnit.Case, async: false

  alias OrigenWeb.ProfessionalPatientSelectorDemo, as: Demo

  setup do
    previous = Application.get_env(:origen, :dev_routes)
    Application.put_env(:origen, :dev_routes, true)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:origen, :dev_routes),
        else: Application.put_env(:origen, :dev_routes, previous)
    end)

    %{session: %{account_id: 1, role: :professional}}
  end

  test "related list and exact search remain separate even after simulation", %{session: session} do
    assert {:ok, related} = Demo.execute({:related, session})
    assert Enum.map(related, & &1.document_number) == ["30111222", "32444555"]
    assert {:ok, nil} = Demo.execute({:search, session, "9900012"})
    assert {:error, :invalid_document} = Demo.execute({:search, session, "990"})
    assert {:ok, nil} = Demo.execute({:search, session, "99999999"})
    assert {:ok, patient} = Demo.execute({:search, session, "99000123"})
    assert patient.first_name == "Lucía"
    assert patient.last_name == "Ejemplo"
    refute Enum.any?(related, &(&1.id == patient.id))

    assert {:ok, %{simulated: true, state: :confirmed}} =
             Demo.execute(
               {:simulate_confirmation, session,
                %{
                  patient_id: patient.id,
                  consultation_id: "demo-initial",
                  slot_id: "0900",
                  date: Date.utc_today()
                }}
             )

    assert {:ok, ^related} = Demo.execute({:related, session})
  end

  test "demo catalog preserves price, color, duration and availability contracts", %{
    session: session
  } do
    assert {:ok, [initial, followup]} = Demo.execute({:consultations, session})
    assert initial.duration_minutes == 45
    assert Decimal.equal?(initial.exact_price_ars, Decimal.new("25000.00"))
    assert initial.color == "#0A7C86"
    assert followup.duration_minutes == 30
    assert Decimal.equal?(followup.exact_price_ars, Decimal.new("18000.00"))
    assert followup.color == "#7C3AED"
    assert {:ok, slots} = Demo.execute({:slots, session, initial.id, Date.utc_today()})
    assert Enum.map(slots, & &1.label) == ["09:00", "10:30", "14:00"]

    assert {:error, :invalid_selection} =
             Demo.execute({:slots, session, "foreign", Date.utc_today()})
  end

  test "all operations are unavailable when development routes are disabled", %{session: session} do
    Application.put_env(:origen, :dev_routes, false)

    for request <- [
          {:related, session},
          {:search, session, "99000123"},
          {:consultations, session},
          {:slots, session, "demo-initial", Date.utc_today()},
          {:simulate_confirmation, session, %{}}
        ] do
      assert {:error, :unavailable} = Demo.execute(request)
    end
  end
end
