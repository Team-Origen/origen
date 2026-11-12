defmodule OrigenWeb.EconomicSummaryIntegrationTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.Booking
  alias Origen.Repo
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

  test "secretary selects one active real professional and never aggregates", %{
    conn: conn,
    fixture: fixture
  } do
    professional = Fixtures.professional_principal(fixture)

    other =
      Fixtures.professional_principal(%{fixture | professional_id: fixture.other_professional_id})

    appointment!(fixture, professional, ~D[2026-11-10], "10000")

    appointment!(
      %{fixture | professional_id: fixture.other_professional_id},
      other,
      ~D[2026-11-10],
      "20000",
      fixture.other_patient_id
    )

    secretary = Fixtures.secretary_principal(fixture)

    {:ok, view, html} =
      live(internal_conn(conn, secretary.token), "/secretaria/resumen-economico")

    refute html =~ "demo-a"
    refute html =~ "demo-b"
    assert has_element?(view, "#select-professional-notice")

    select_professional(view, fixture.professional_id)
    month(view, "2026-11")
    assert has_element?(view, "#selected-professional-name", "Ana Gómez")
    assert has_element?(view, "#summary-total", "10.000,00")

    select_professional(view, fixture.other_professional_id)
    assert has_element?(view, "#selected-professional-name", "Lucía Sosa")
    assert has_element?(view, "#summary-total", "20.000,00")
    refute has_element?(view, "#summary-total", "30.000,00")
  end

  test "late payment updates the original appointment period through the public LiveView flow", %{
    conn: conn,
    fixture: fixture
  } do
    professional = Fixtures.professional_principal(fixture)
    appointment = appointment!(fixture, professional, ~D[2026-11-20], "6000")

    {:ok, view, _} =
      live(internal_conn(conn, professional.token), "/profesional/resumen-economico")

    month(view, "2026-11")
    assert has_element?(view, "#summary-pending", "6.000,00")

    assert {:ok, _} = Booking.record_payment(professional, appointment.id, :cash)
    month(view, "2026-11")
    assert has_element?(view, "#summary-paid", "6.000,00")
    assert has_element?(view, "#summary-pending", "0,00")
    assert has_element?(view, "#summary-total", "6.000,00")
  end

  test "forged professional selections are rejected without rendering totals", %{
    conn: conn,
    fixture: fixture
  } do
    secretary = Fixtures.secretary_principal(fixture)
    {:ok, view, _} = live(internal_conn(conn, secretary.token), "/secretaria/resumen-economico")

    render_click(view, "professional", %{"professional" => "9223372036854775808"})

    refute has_element?(view, "#summary-paid")
    refute has_element?(view, "#summary-pending")
    refute has_element?(view, "#summary-total")
    assert has_element?(view, "#summary-error[role='alert']")
  end

  test "navbar exposes the summary entry for the authorized roles", %{
    conn: conn,
    fixture: fixture
  } do
    professional = Fixtures.professional_principal(fixture)
    secretary = Fixtures.secretary_principal(fixture)

    {:ok, professional_view, _} =
      live(internal_conn(conn, professional.token), "/profesional/resumen-economico")

    assert has_element?(
             professional_view,
             "#nav-summary[href='/profesional/resumen-economico'][aria-current='page']"
           )

    {:ok, secretary_view, _} =
      live(internal_conn(conn, secretary.token), "/secretaria/resumen-economico")

    assert has_element?(
             secretary_view,
             "#nav-summary[href='/secretaria/resumen-economico'][aria-current='page']"
           )
  end

  defp appointment!(fixture, principal, date, price, patient_id \\ nil) do
    appointment =
      Fixtures.appointment!(fixture,
        professional_account_id: principal.account_id,
        patient_profile_id: patient_id || fixture.patient_id,
        start_time: DateTime.new!(date, ~T[09:00:00], "Etc/UTC"),
        status: "confirmed"
      )

    assert {:ok, %{final_price_ars: final_price}} =
             Booking.update_final_price(principal, appointment.id, price)

    assert Decimal.equal?(final_price, Decimal.new(price))
    appointment
  end

  defp select_professional(view, id) do
    view |> element("#professional-profile-button") |> render_click()
    view |> element("#professional-option-#{id}") |> render_click()
  end

  defp month(view, value) do
    view
    |> form("#period-form", period: %{mode: "month", month: value})
    |> render_change()
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
