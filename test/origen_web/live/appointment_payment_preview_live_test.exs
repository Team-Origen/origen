defmodule OrigenWeb.AppointmentPaymentPreviewLiveTest do
  use OrigenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :skip_db

  defp preview(conn) do
    live_isolated(conn, OrigenWeb.AppointmentPaymentPreviewLive)
  end

  test "detail state badge uses the same colors as its agenda card", %{conn: conn} do
    {:ok, view, _} = preview(conn)

    for {id, colors, label} <- [
          {"1", ".bg-emerald-50.text-emerald-700.border-emerald-200", "Confirmado"},
          {"3", ".bg-stone-100.text-stone-700.border-stone-300", "Asistió"},
          {"4", ".bg-indigo-50.text-indigo-700.border-indigo-200", "Pendiente de aprobación"},
          {"5", ".bg-rose-50.text-rose-700.border-rose-200", "Cancelado"},
          {"6", ".bg-amber-50.text-amber-700.border-amber-200", "No asistió"},
          {"8", ".bg-stone-100.text-stone-700.border-stone-300", "Vencido"}
        ] do
      view |> element("#open-#{id}") |> render_click()
      assert has_element?(view, "#appointment-#{id} [data-status]#{colors}", label)
      assert has_element?(view, "#detail-status#{colors}", label)
      view |> element("#close-detail") |> render_click()
    end
  end

  test "detail includes start, end and duration with the existing general information", %{
    conn: conn
  } do
    {:ok, view, _} = preview(conn)
    view |> element("#open-1") |> render_click()
    assert has_element?(view, "#turn-detail", "Ana Pérez · Consulta")
    assert has_element?(view, "#detail-schedule", "10:00 - 11:00 · 60 min")
    assert has_element?(view, "#detail-schedule", "09/11/2026")
    assert has_element?(view, "#detail-schedule", "Dra. García")
  end

  test "detail retains state action labels with agenda colors", %{conn: conn} do
    {:ok, view, _} = preview(conn)
    view |> element("#open-1") |> render_click()

    assert has_element?(
             view,
             "#action-attended.text-emerald-800.border-emerald-300",
             "Registrar asistencia"
           )

    assert has_element?(
             view,
             "#action-no_show.text-orange-700.border-orange-300",
             "Registrar ausencia"
           )

    assert has_element?(view, "#action-cancelled.text-red-700.border-red-300", "Cancelar turno")
  end

  test "payment buttons use blue outlines without changing their forms", %{conn: conn} do
    {:ok, view, _} = preview(conn)
    view |> element("#open-1") |> render_click()
    assert has_element?(view, "#payment-detail", "Precio final (pesos argentinos · ARS):")

    assert has_element?(
             view,
             "#edit-price.text-blue-700.border-blue-300.bg-white",
             "Editar precio"
           )

    assert has_element?(
             view,
             "#register-payment.text-blue-700.border-blue-300.bg-white",
             "Registrar pago"
           )

    view |> element("#register-payment") |> render_click()

    assert has_element?(
             view,
             "#payment-form button.text-blue-700.border-blue-300.bg-white",
             "Registrar pago"
           )

    assert has_element?(view, "#cancel-action", "Cancelar")
  end

  test "preserves Mi agenda row layout, appointment context and patient column", %{conn: conn} do
    {:ok, view, _} = preview(conn)
    assert has_element?(view, "#agenda-appointments-list.space-y-3[role=list]")
    assert has_element?(view, "#appointment-1[role=listitem].sm\\:flex-row")
    assert has_element?(view, "#appointment-1 [data-section=appointment]", "10:00 - 11:00")
    assert has_element?(view, "#appointment-1 [data-section=appointment]", "Consulta")
    assert has_element?(view, "#appointment-1 [data-section=appointment]", "60 min")
    assert has_element?(view, "#appointment-1 [data-section=appointment]", "Confirmado")
    assert has_element?(view, "#appointment-1 [data-section=appointment]", "Pendiente de pago")
    assert has_element?(view, "#appointment-1 [data-section=patient]", "Ana Pérez")
    assert has_element?(view, "#appointment-1 [data-section=patient]", "DNI: 30111222")
    assert has_element?(view, "#appointment-1 [data-section=patient]", "Tel: 1100000001")
    assert has_element?(view, "#appointment-1 [data-section=patient]", "ana.perez@example.test")
    assert has_element?(view, "#appointment-1 [data-section=appointment] #open-1", "Ver detalle")
    refute has_element?(view, "button", "Ver turno")
    refute has_element?(view, "#appointment-1 form")

    view |> element("#open-1") |> render_click()
    assert has_element?(view, "#turn-detail.text-black")
    refute has_element?(view, "#turn-detail [class*=text-stone-]")
    refute has_element?(view, "#turn-detail [class*=text-white]")
    assert has_element?(view, "#edit-price")
    assert has_element?(view, "#register-payment")
  end

  test "cards show both states and the four requested actions with their colors", %{conn: conn} do
    {:ok, view, _html} = preview(conn)
    assert has_element?(view, "#mock-notice", "ficticios")
    assert has_element?(view, "#appointment-1", "Confirmado")
    assert has_element?(view, "#appointment-1", "Pendiente de pago")
    refute has_element?(view, "#payment-form")
    assert has_element?(view, "#card-cancelled-1.text-red-700", "Cancelar con motivo")
    assert has_element?(view, "#card-attended-1.text-emerald-800", "Marcar asistencia")
    assert has_element?(view, "#card-no_show-1.text-orange-700", "Marcar ausencia")
    assert has_element?(view, "#open-1.text-blue-700.border-blue-300.bg-white", "Ver detalle")
    assert has_element?(view, "#payment-status-2.bg-emerald-50", "Pagado")

    view |> element("#open-1") |> render_click()
    assert has_element?(view, "[role=dialog]", "Ana Pérez")
    assert has_element?(view, "button", "Registrar asistencia")
    refute has_element?(view, "#payment-form")
    refute has_element?(view, "summary", "Historial")
  end

  test "card actions select the correct appointment and await confirmation", %{conn: conn} do
    {:ok, view, _} = preview(conn)
    view |> element("#card-attended-1") |> render_click()
    assert has_element?(view, "#turn-detail", "Ana Pérez")
    assert has_element?(view, "#turn-detail", "¿Confirmar que el paciente asistió?")
    assert has_element?(view, "#appointment-1", "Confirmado")
    view |> element("#confirm-action") |> render_click()
    assert has_element?(view, "#appointment-1", "Asistió")
    refute has_element?(view, "#card-attended-1")
    view |> element("#close-detail") |> render_click()
    view |> element("#card-no_show-2") |> render_click()
    view |> element("#cancel-action") |> render_click()
    assert has_element?(view, "#appointment-2", "Confirmado")
    assert has_element?(view, "#appointment-2", "Pagado")
  end

  test "edit zero price, pay and cancel/confirm correction without changing appointment", %{
    conn: conn
  } do
    {:ok, view, _} = preview(conn)
    view |> element("#open-1") |> render_click()
    view |> element("#edit-price") |> render_click()
    view |> form("#price-form", price: %{amount: "-1"}) |> render_submit()
    assert has_element?(view, "[role=alert]", "mayor o igual a cero")
    view |> form("#price-form", price: %{amount: "0"}) |> render_submit()
    view |> element("#register-payment") |> render_click()
    view |> form("#payment-form", payment: %{method: "transfer"}) |> render_submit()
    assert has_element?(view, "#appointment-1", "Pagado")
    assert has_element?(view, "#payment-detail", "Transferencia")
    assert has_element?(view, "#payment-detail", "$0,00")
    refute has_element?(view, "#edit-price")

    view |> element("#correct-payment") |> render_click()
    view |> element("#cancel-action") |> render_click()
    assert has_element?(view, "#appointment-1", "Pagado")
    view |> element("#correct-payment") |> render_click()
    view |> element("#confirm-action") |> render_click()
    assert has_element?(view, "#appointment-1", "Pendiente de pago")
    assert has_element?(view, "#appointment-1", "Confirmado")
    assert has_element?(view, "#edit-price")
  end

  test "absence and cancellation preserve paid marks and cannot receive new payments", %{
    conn: conn
  } do
    {:ok, view, _} = preview(conn)
    view |> element("#open-2") |> render_click()
    view |> element("#action-no_show") |> render_click()
    view |> element("#confirm-action") |> render_click()
    assert has_element?(view, "#appointment-2", "No asistió")
    assert has_element?(view, "#appointment-2", "Pagado")
    view |> element("#correct-payment") |> render_click()
    view |> element("#confirm-action") |> render_click()
    refute has_element?(view, "#register-payment")
    assert has_element?(view, "#payment-detail", "no admite registrar pagos")

    view |> element("#close-detail") |> render_click()
    view |> element("#open-1") |> render_click()
    view |> element("#register-payment") |> render_click()
    view |> form("#payment-form", payment: %{method: "cash"}) |> render_submit()
    view |> element("#action-cancelled") |> render_click()
    view |> element("#cancel-action") |> render_click()
    assert has_element?(view, "#appointment-1", "Confirmado")
    view |> element("#action-cancelled") |> render_click()
    view |> element("#confirm-action") |> render_click()
    assert has_element?(view, "#appointment-1", "Cancelado")
    assert has_element?(view, "#appointment-1", "Pagado")
  end

  test "cancelled mock appointments are read-only even for submitted events", %{conn: conn} do
    {:ok, view, _} = preview(conn)
    view |> element("#open-5") |> render_click()
    before = render(view)

    for action <- ~w(price pay correct attended no_show cancelled) do
      refute has_element?(view, "#action-#{action}")
      render_click(view, "action", %{"action" => action})
      render_click(view, "confirm")
      render_submit(view, "price", %{"price" => %{"amount" => "1"}})
      render_click(view, "card_action", %{"id" => "5", "action" => action})
      assert render(view) == before
    end

    refute has_element?(view, "#edit-price")
    refute has_element?(view, "#register-payment")
    refute has_element?(view, "#correct-payment")
    assert has_element?(view, "#payment-detail", "$7000,00")
    assert has_element?(view, "#payment-detail", "Pagado")
  end

  test "attended mocks cannot be cancelled or show conflicting operational states", %{conn: conn} do
    {:ok, view, _} = preview(conn)

    for id <- ~w(3 7) do
      refute has_element?(view, "#card-cancelled-#{id}")
      view |> element("#open-#{id}") |> render_click()
      refute has_element?(view, "#action-cancelled")
      before = render(view)
      render_click(view, "action", %{"action" => "cancelled"})
      render_click(view, "confirm")
      render_click(view, "card_action", %{"id" => id, "action" => "cancelled"})
      assert render(view) == before
      assert has_element?(view, "#detail-status", "Asistió")
      refute has_element?(view, "#detail-status", "Cancelado")
      view |> element("#close-detail") |> render_click()
    end

    view |> element("#open-7") |> render_click()
    assert has_element?(view, "#register-payment")
  end

  test "ineligible requests, patient view and reset cannot expose financial actions", %{
    conn: conn
  } do
    {:ok, view, _} = preview(conn)
    view |> element("#open-4") |> render_click()
    refute has_element?(view, "#register-payment")
    view |> element("#close-detail") |> render_click()
    view |> form("#role-form", preview: %{role: "patient"}) |> render_change()
    view |> element("#open-2") |> render_click()
    assert has_element?(view, "#payment-detail", "Pagado")
    refute has_element?(view, "#correct-payment")
    refute has_element?(view, "#payment-detail", "Registrado por")
    refute has_element?(view, "#payment-detail", "Efectivo")
    view |> element("#reset-demo") |> render_click()
    refute has_element?(view, "[role=dialog]")
    assert has_element?(view, "#appointment-2", "Confirmado")
  end
end
