defmodule OrigenWeb.EconomicSummaryLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Repo, Sessions}

  test "professional sees branded mock, own scope, totals and attended-only detail", %{conn: conn} do
    {:ok, view, html} =
      live(internal_conn(conn, "professional"), "/profesional/resumen-economico")

    assert html =~ "Datos ficticios"
    assert has_element?(view, "#economic-summary.bg-page")
    assert has_element?(view, "#nav-summary[aria-current='page']")
    refute has_element?(view, "#professional-selector")
    assert has_element?(view, "#summary-paid", "25.000,00")
    assert has_element?(view, "#summary-pending", "10.000,00")
    assert has_element?(view, "#summary-total", "35.000,00")
    assert has_element?(view, "#attended-unpaid", "Paciente Demo A")
    refute has_element?(view, "#attended-unpaid", "Reserva Demo")
    refute has_element?(view, "#attended-unpaid a")
    assert has_element?(view, "#attended-unpaid", "Sólo turnos con asistencia registrada")
    assert has_element?(view, "#period-context", Calendar.strftime(today(), "%m/%Y"))
  end

  test "consult button appears only for ranges and calendar selection updates automatically", %{
    conn: conn
  } do
    {:ok, view, _} = live(internal_conn(conn, "professional"), "/profesional/resumen-economico")
    refute has_element?(view, "#period-form button[type='submit']")

    previous = today() |> Date.beginning_of_month() |> Date.add(-1)

    view
    |> form("#period-form", period: %{mode: "month", month: Calendar.strftime(previous, "%Y-%m")})
    |> render_change()

    assert has_element?(view, "#summary-total", "0,00")
    assert has_element?(view, "#period-context", Calendar.strftime(previous, "%m/%Y"))

    view |> form("#period-form", period: %{mode: "range"}) |> render_change()
    assert has_element?(view, "#period-form button[type='submit']", "Consultar resumen")
    date = Date.to_iso8601(%{today() | day: 1})

    view
    |> form("#period-form", period: %{mode: "range", from: date, to: date})
    |> render_change()

    assert has_element?(view, "#summary-total", "0,00")
    range(view, date, date)
    assert has_element?(view, "#summary-total", "4.000,00")

    view
    |> form("#period-form", period: %{mode: "month", month: Calendar.strftime(today(), "%Y-%m")})
    |> render_change()

    refute has_element?(view, "#period-form button[type='submit']")
    assert has_element?(view, "#summary-total", "35.000,00")
  end

  test "month arrows and inclusive single-day ranges filter the same fictional dataset", %{
    conn: conn
  } do
    {:ok, view, _} = live(internal_conn(conn, "professional"), "/profesional/resumen-economico")
    view |> element("#previous-month") |> render_click()
    assert has_element?(view, "#summary-paid", "0,00")
    assert has_element?(view, "#empty-summary")
    view |> element("#next-month") |> render_click()
    assert has_element?(view, "#summary-total", "35.000,00")

    date = Date.to_iso8601(%{today() | day: 1})
    range(view, date, date)
    assert has_element?(view, "#summary-pending", "4.000,00")
    assert has_element?(view, "#summary-paid", "0,00")
    assert has_element?(view, "#attended-unpaid", "Paciente Demo A")

    start = %{today() | day: 1}
    finish = Date.end_of_month(start)
    range(view, Date.to_iso8601(start), Date.to_iso8601(finish))
    assert has_element?(view, "#summary-total", "35.000,00")
  end

  test "invalid and reversed ranges show errors without replacing the consulted result", %{
    conn: conn
  } do
    {:ok, view, _} = live(internal_conn(conn, "professional"), "/profesional/resumen-economico")
    range(view, "2026-11-20", "2026-11-19")
    assert has_element?(view, "#period-error", "La fecha final no puede ser anterior")
    assert has_element?(view, "#summary-total", "35.000,00")
    range(view, "", "")
    assert has_element?(view, "#period-error", "Completá un período válido")
    assert has_element?(view, "#summary-total", "35.000,00")
  end

  test "secretary opens selection from the profile button and choosing closes it", %{conn: conn} do
    {:ok, view, _} = live(internal_conn(conn, "secretary"), "/secretaria/resumen-economico")
    assert has_element?(view, "#professional-profile-button[aria-expanded='false']")
    refute has_element?(view, "#professional-options")
    view |> element("#professional-profile-button") |> render_click()
    assert has_element?(view, "#professional-profile-button[aria-expanded='true']")
    assert has_element?(view, "#professional-options")
    view |> element("#professional-option-demo-a") |> render_click()
    refute has_element?(view, "#professional-options")
    assert has_element?(view, "#professional-profile-button", "Profesional Demo A")
    assert has_element?(view, "#summary-total", "35.000,00")
    view |> element("#professional-profile-button") |> render_click()
    view |> element("#professional-option-demo-b") |> render_click()
    assert has_element?(view, "#professional-profile-button", "Nutrición")
    assert has_element?(view, "#summary-total", "70.000,00")
    view |> element("#professional-profile-button") |> render_click()
    view |> element("#professional-profile-button") |> render_click()
    refute has_element?(view, "#professional-options")
  end

  test "secretary selector displays the selected avatar, name and specialty", %{conn: conn} do
    {:ok, view, _} = live(internal_conn(conn, "secretary"), "/secretaria/resumen-economico")
    refute has_element?(view, "#selected-professional-card")
    select_professional(view, "demo-a")
    assert has_element?(view, "#selected-professional-avatar")
    assert has_element?(view, "#selected-professional-name", "Profesional Demo A")
    assert has_element?(view, "#selected-professional-specialty", "Psicología")
    select_professional(view, "demo-b")
    assert has_element?(view, "#selected-professional-name", "Profesional Demo B")
    assert has_element?(view, "#selected-professional-specialty", "Nutrición")
    refute has_element?(view, "#selected-professional-card", "Psicología")
    select_professional(view, "")
    refute has_element?(view, "#selected-professional-card")
    refute has_element?(view, "#summary-total")
  end

  test "secretary selects one fictional professional and never aggregates them", %{conn: conn} do
    {:ok, view, _} = live(internal_conn(conn, "secretary"), "/secretaria/resumen-economico")
    assert has_element?(view, "#select-professional-notice")
    refute has_element?(view, "#summary-total")
    select_professional(view, "demo-a")
    assert has_element?(view, "#summary-total", "35.000,00")
    select_professional(view, "demo-b")
    assert has_element?(view, "#summary-total", "70.000,00")
    refute has_element?(view, "#attended-unpaid", "Paciente Demo A")
    view |> render_change("professional", %{"professional" => "all"})
    refute has_element?(view, "#summary-total")
  end

  test "unauthenticated and wrong-role access is denied on both routes", %{conn: conn} do
    assert response(get(conn, "/profesional/resumen-economico"), 401)
    assert {:error, {:redirect, _}} = live(build_conn(), "/secretaria/resumen-economico")

    for role <- ["administrator", "secretary"] do
      assert response(
               get(internal_conn(build_conn(), role), "/profesional/resumen-economico"),
               403
             )
    end

    for role <- ["administrator", "professional"] do
      assert {:error, {:redirect, _}} =
               live(internal_conn(build_conn(), role), "/secretaria/resumen-economico")
    end
  end

  defp select_professional(view, id) do
    view |> element("#professional-profile-button") |> render_click()
    option = if id == "", do: "clear", else: id
    view |> element("#professional-option-#{option}") |> render_click()
  end

  defp range(view, start, finish) do
    view
    |> form("#period-form", period: %{mode: "range", from: start, to: finish})
    |> render_submit()
  end

  defp today do
    DateTime.now!(Application.fetch_env!(:origen, :organization_timezone)) |> DateTime.to_date()
  end

  defp internal_conn(conn, role) do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', 'hash', decode('0102030405', 'hex'), clock_timestamp()) RETURNING id
        """,
        ["summary-#{System.unique_integer([:positive])}@example.test", role]
      )

    {:ok, %{token: token}} = Sessions.create_session(id)
    init_test_session(conn, %{internal_session_token: token})
  end
end
