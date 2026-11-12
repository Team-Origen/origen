defmodule OrigenWeb.EconomicSummaryLiveTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    previous_timezone = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "Etc/UTC")

    fixture = Fixtures.create!()
    insert_profile!(fixture.professional_id, "Ana", "Gómez", "Psicología", "MN-A")
    insert_profile!(fixture.other_professional_id, "Lucía", "Sosa", "Nutrición", "MN-B")

    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous_timezone) end)
    %{fixture: fixture}
  end

  test "professional sees the real own summary and no fabricated appointment detail", %{
    conn: conn,
    fixture: fixture
  } do
    professional = Fixtures.professional_principal(fixture)
    appointment = appointment!(fixture, professional, today(), "10000")

    {:ok, view, html} =
      live(internal_conn(conn, professional.token), "/profesional/resumen-economico")

    assert has_element?(view, "#economic-summary.bg-page")
    assert has_element?(view, "#nav-summary[aria-current='page']")
    refute has_element?(view, "#professional-selector")
    assert has_element?(view, "#summary-pending", "10.000,00")
    assert has_element?(view, "#summary-total", "10.000,00")
    assert has_element?(view, "#period-context", Calendar.strftime(today(), "%m/%Y"))
    assert html =~ "Ana Gómez"
    refute html =~ "demo-a"
    refute html =~ "Datos ficticios"
    refute has_element?(view, "#attended-unpaid")
    refute html =~ "Paciente"
    assert appointment.id > 0
  end

  test "month and inclusive range use the backend period and reject reversed input", %{
    conn: conn,
    fixture: fixture
  } do
    professional = Fixtures.professional_principal(fixture)
    appointment!(fixture, professional, ~D[2026-11-01], "10000")
    appointment!(fixture, professional, ~D[2026-11-30], "5000")

    {:ok, view, _} =
      live(internal_conn(conn, professional.token), "/profesional/resumen-economico")

    month(view, "2026-11")
    assert has_element?(view, "#summary-paid", "0,00")
    assert has_element?(view, "#summary-pending", "15.000,00")
    assert has_element?(view, "#summary-total", "15.000,00")

    range(view, "2026-11-01", "2026-11-30")
    assert has_element?(view, "#summary-total", "15.000,00")

    range(view, "2026-11-30", "2026-11-01")
    assert has_element?(view, "#period-error", "La fecha final no puede ser anterior")
    assert has_element?(view, "#summary-total", "15.000,00")
  end

  test "professional session revocation clears the previously rendered summary", %{
    conn: conn,
    fixture: fixture
  } do
    professional = Fixtures.professional_principal(fixture)
    appointment!(fixture, professional, ~D[2026-11-15], "9000")

    {:ok, view, _} =
      live(internal_conn(conn, professional.token), "/profesional/resumen-economico")

    month(view, "2026-11")
    assert has_element?(view, "#summary-total", "9.000,00")

    assert :ok = Sessions.terminate_session(professional.token)
    month(view, "2026-11")

    refute has_element?(view, "#summary-total", "9.000,00")
    assert has_element?(view, "#summary-error[role='alert']")
  end

  defp appointment!(fixture, principal, date, price) do
    appointment =
      Fixtures.appointment!(fixture,
        start_time: DateTime.new!(date, ~T[09:00:00], "Etc/UTC"),
        status: "confirmed"
      )

    assert {:ok, %{final_price_ars: final_price}} =
             Booking.update_final_price(principal, appointment.id, price)

    assert Decimal.equal?(final_price, Decimal.new(price))
    appointment
  end

  defp month(view, value) do
    view
    |> form("#period-form", period: %{mode: "month", month: value})
    |> render_change()
  end

  defp range(view, from, to) do
    view
    |> form("#period-form", period: %{mode: "range", from: from, to: to})
    |> render_submit()
  end

  defp today do
    DateTime.now!(Application.fetch_env!(:origen, :organization_timezone)) |> DateTime.to_date()
  end

  defp insert_profile!(account_id, first_name, last_name, specialty, license_number) do
    Repo.query!(
      """
      INSERT INTO professional_profiles
        (owner_account_id, first_name, last_name, specialty, license_type, license_number)
      VALUES ($1, $2, $3, $4, 'Nacional', $5)
      """,
      [account_id, first_name, last_name, specialty, license_number]
    )
  end

  defp internal_conn(conn, token) do
    Phoenix.ConnTest.init_test_session(conn, %{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end
end
