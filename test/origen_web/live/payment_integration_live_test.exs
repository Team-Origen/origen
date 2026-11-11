defmodule OrigenWeb.PaymentIntegrationLiveTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    fixture = Fixtures.create!()
    professional = Fixtures.professional_principal(fixture)
    secretary = Fixtures.secretary_principal(fixture)
    %{fixture: fixture, professional: professional, secretary: secretary}
  end

  for {role, path, method, status} <- [
        {:professional, "/profesional/agenda", "cash", "confirmed"},
        {:secretary, "/secretaria/agenda", "transfer", "attended"}
      ] do
    test "#{role} edits, pays, confirms correction and repays through real UI", context do
      principal = Map.fetch!(context, unquote(role))
      appointment = appointment(context.fixture, status: unquote(status))
      {:ok, view, _} = live(internal_conn(principal), unquote(path))
      id = appointment.id

      assert has_element?(view, "#nav-agenda[href='#{unquote(path)}']")
      open_detail(view, id)
      assert has_element?(view, "#payment-#{id}", "Pendiente")
      set_price(view, id, "80.00")

      assert {:ok, %{final_price_ars: price, payment_status: "pending"}} =
               Booking.get_payment(principal, id)

      assert Decimal.equal?(price, "80.00")
      assert_snapshot_unchanged(principal, appointment)

      pay(view, id, unquote(method))
      assert has_element?(view, "#payment-#{id}", "Pagado")
      refute has_element?(view, "#payment-price-form-#{id}")
      assert {:ok, paid} = Booking.get_payment(principal, id)
      assert paid.payment_status == "paid"
      assert paid.payment_method == unquote(method)
      assert paid.paid_actor_ref == "internal_account:#{principal.account_id}"
      assert %DateTime{} = paid.paid_at
      assert Decimal.equal?(paid.paid_amount_ars, "80.00")
      assert {:ok, [action]} = Booking.list_payment_actions(principal, id)

      view |> element("#payment-revert-#{id}") |> render_click()
      assert has_element?(view, "#payment-revert-confirmation-#{id}")
      refute has_element?(view, "#payment-revert-confirmation-#{id} textarea")
      view |> element("#payment-revert-cancel-#{id}") |> render_click()
      assert {:ok, ^paid} = Booking.get_payment(principal, id)
      assert {:ok, [^action]} = Booking.list_payment_actions(principal, id)

      view |> element("#payment-revert-#{id}") |> render_click()
      view |> element("#payment-revert-confirm-#{id}") |> render_click()
      assert has_element?(view, "#payment-edit-price-#{id}")

      assert {:ok, %{payment_status: "pending", paid_at: nil}} =
               Booking.get_payment(principal, id)

      assert {:ok, [^action, correction]} = Booking.list_payment_actions(principal, id)
      assert correction.action == "reverted"
      assert correction.actor_ref == "internal_account:#{principal.account_id}"
      assert %DateTime{} = correction.occurred_at
      assert has_element?(view, "#payment-history-#{id}", "Corrección")

      set_price(view, id, "0")
      pay(view, id, unquote(method))

      assert {:ok, %{payment_status: "paid", paid_amount_ars: amount}} =
               Booking.get_payment(principal, id)

      assert Decimal.equal?(amount, "0")

      assert {:ok, [^action, ^correction, %{action: "paid"}]} =
               Booking.list_payment_actions(principal, id)

      {:ok, reloaded, _} = live(internal_conn(principal), unquote(path))
      open_detail(reloaded, id)
      assert has_element?(reloaded, "#payment-#{id}", "Pagado")
      assert_snapshot_unchanged(principal, appointment)
    end
  end

  for {outcome, role, path} <- [
        {:cancelled, :professional, "/profesional/agenda"},
        {:no_show, :secretary, "/secretaria/agenda"}
      ] do
    test "#{role} preserves payment on #{outcome} and corrects without enabling repayment",
         context do
      principal = Map.fetch!(context, unquote(role))
      appointment = appointment(context.fixture, status: "confirmed")
      id = appointment.id
      {:ok, view, _} = live(internal_conn(principal), unquote(path))
      open_detail(view, id)
      pay(view, id, "cash")
      view |> element("#close-turn-detail") |> render_click()
      assert {:ok, paid} = Booking.get_payment(principal, id)

      if unquote(outcome) == :cancelled do
        view |> element("#cancel-appointment-#{id}") |> render_click()

        view
        |> form("#appointment-cancellation-form-#{id}",
          cancellation: %{reason: "Agenda ajustada"}
        )
        |> render_submit()
      else
        view
        |> element(
          "[phx-click='record_attendance'][phx-value-appointment_id='#{id}'][phx-value-outcome='no_show']"
        )
        |> render_click()
      end

      assert {:ok, ^paid} = Booking.get_payment(principal, id)
      open_detail(view, id)
      assert has_element?(view, "#payment-#{id}", "Pagado")
      view |> element("#payment-revert-#{id}") |> render_click()
      view |> element("#payment-revert-confirm-#{id}") |> render_click()
      set_price(view, id, "75.00")

      assert {:ok, %{payment_status: "pending", final_price_ars: price}} =
               Booking.get_payment(principal, id)

      assert Decimal.equal?(price, "75.00")
      refute has_element?(view, "#payment-register-form-#{id}")

      assert {:error, :payment_not_eligible} =
               Booking.record_payment(principal, id, "cash")

      assert {:ok, history} = Booking.list_appointment_history(principal)
      assert Enum.find(history, &(&1.id == id)).status == to_string(unquote(outcome))

      assert {:ok, [%{action: "paid"}, %{action: "reverted"}]} =
               Booking.list_payment_actions(principal, id)
    end
  end

  test "requested appointments cannot be paid and invalid prices leave all public state unchanged",
       context do
    appointment = appointment(context.fixture, status: "requested")
    id = appointment.id
    principal = context.professional
    {:ok, before} = Booking.get_payment(principal, id)
    {:ok, history} = Booking.list_appointment_history(principal)
    {:ok, view, _} = live(internal_conn(principal), "/profesional/agenda")
    open_detail(view, id)
    refute has_element?(view, "#payment-register-form-#{id}")

    for price <- ["-1", "abc"] do
      set_price(view, id, price)
      assert has_element?(view, "#payment-error-#{id}", "precio")
      assert {:ok, ^before} = Booking.get_payment(principal, id)
      assert {:ok, []} = Booking.list_payment_actions(principal, id)
      assert {:ok, ^history} = Booking.list_appointment_history(principal)
    end
  end

  test "professional cannot operate another agenda; secretary can; administrator is denied",
       context do
    appointment =
      appointment(context.fixture,
        professional_account_id: context.fixture.other_professional_id,
        status: "confirmed"
      )

    id = appointment.id
    {:ok, view, html} = live(internal_conn(context.professional), "/profesional/agenda")
    refute has_element?(view, "#payment-#{id}")
    refute html =~ "account:#{context.fixture.other_professional_id}"
    assert {:error, :unauthorized} = Booking.record_payment(context.professional, id, "cash")
    {:ok, secretary_view, _} = live(internal_conn(context.secretary), "/secretaria/agenda")
    open_detail(secretary_view, id)
    pay(secretary_view, id, "transfer")
    assert {:ok, %{payment_status: "paid"}} = Booking.get_payment(context.secretary, id)
    admin = Fixtures.admin_principal(context.fixture)

    assert get(internal_conn(admin), "/profesional/agenda").status == 403
    assert {:error, {:redirect, _}} = live(internal_conn(admin), "/secretaria/agenda")

    assert {:error, :unauthorized} = Booking.get_payment(admin, id)
  end

  test "paid history outside the selected day remains reachable for correction", context do
    appointment =
      appointment(context.fixture,
        status: "attended",
        start_time: DateTime.add(today(), -2, :day)
      )

    assert {:ok, _} = Booking.record_payment(context.professional, appointment.id, "cash")
    {:ok, view, _} = live(internal_conn(context.professional), "/profesional/agenda")

    assert has_element?(
             view,
             "#professional-appointment-history #history-view-turn-#{appointment.id}"
           )

    view |> element("#history-view-turn-#{appointment.id}") |> render_click()
    view |> element("#payment-revert-#{appointment.id}") |> render_click()
    view |> element("#payment-revert-confirm-#{appointment.id}") |> render_click()

    assert {:ok, %{payment_status: "pending"}} =
             Booking.get_payment(context.professional, appointment.id)
  end

  test "cards keep lifecycle controls and open the original staged dialog without inline financial forms",
       context do
    appointment = appointment(context.fixture, status: "confirmed")
    id = appointment.id
    {:ok, view, _} = live(internal_conn(context.professional), "/profesional/agenda")

    assert has_element?(
             view,
             "#appointment-#{id} #lifecycle-actions-#{id} #view-turn-#{id}",
             "Ver turno"
           )

    assert has_element?(view, "#view-turn-#{id}.border-sky-300.text-sky-700")
    assert has_element?(view, "#cancel-appointment-#{id}", "Cancelar con motivo")
    assert has_element?(view, "#appointment-#{id} [phx-value-outcome='attended']")
    assert has_element?(view, "#appointment-#{id} [phx-value-outcome='no_show']")
    refute has_element?(view, "#appointment-#{id} form[phx-submit='update_price']")
    refute has_element?(view, "#appointment-#{id} form[phx-submit='register_payment']")
    refute has_element?(view, "[role='dialog']")
    open_detail(view, id)

    assert has_element?(
             view,
             "#turn-detail[role='dialog'][aria-modal='true']",
             "Detalle del turno"
           )

    assert has_element?(view, "#detail-schedule", "30 min")
    assert has_element?(view, "#detail-status", "Confirmado")
    assert has_element?(view, "#payment-#{id}", "Precio final")
    refute has_element?(view, "#payment-price-form-#{id}")
    refute has_element?(view, "#payment-register-form-#{id}")
    view |> element("#payment-edit-price-#{id}") |> render_click()
    assert has_element?(view, "#turn-detail #payment-price-form-#{id}")
    view |> element("#payment-cancel-action-#{id}") |> render_click()
    refute has_element?(view, "#payment-price-form-#{id}")
    view |> element("#close-turn-detail") |> render_click()
    refute has_element?(view, "[role='dialog']")

    assert {:ok, %{payment_status: "pending", final_price_ars: price}} =
             Booking.get_payment(context.professional, id)

    assert Decimal.equal?(price, "100.00")
    assert {:ok, []} = Booking.list_payment_actions(context.professional, id)
    view |> element("#history-view-turn-#{id}") |> render_click()
    assert has_element?(view, "#turn-detail", "Detalle del turno")
    refute has_element?(view, "#professional-appointment-history form[phx-submit='update_price']")
  end

  defp today, do: DateTime.new!(Date.utc_today(), ~T[10:00:00], "Etc/UTC")

  defp appointment(fixture, attrs) do
    Fixtures.appointment!(fixture, Keyword.put_new(attrs, :start_time, today()))
  end

  defp internal_conn(principal) do
    build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, principal.token)
  end

  defp open_detail(view, id) do
    view |> element("#view-turn-#{id}") |> render_click()
  end

  defp set_price(view, id, price) do
    unless has_element?(view, "#payment-price-form-#{id}") do
      view |> element("#payment-edit-price-#{id}") |> render_click()
    end

    view |> form("#payment-price-form-#{id}", payment: %{price: price}) |> render_submit()
  end

  defp pay(view, id, method) do
    view |> element("#payment-start-register-#{id}") |> render_click()
    view |> form("#payment-register-form-#{id}", payment: %{method: method}) |> render_submit()
  end

  defp assert_snapshot_unchanged(principal, appointment) do
    assert {:ok, history} = Booking.list_appointment_history(principal)
    entry = Enum.find(history, &(&1.id == appointment.id))
    assert Decimal.equal?(entry.price_ars, "100.00")
    assert entry.start_time == appointment.start_time
  end
end
