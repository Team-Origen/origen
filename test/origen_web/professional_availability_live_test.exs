defmodule OrigenWeb.ProfessionalAvailabilityLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  @path "/configuracion/profesional"

  setup %{conn: conn} do
    professional = insert_active_internal_account!(:professional)

    {:ok, conn: log_in_internal_account(conn, professional), professional_account: professional}
  end

  test "loads the persisted availability summary through the authenticated professional page", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @path)

    assert has_element?(view, "#weekly-availability-heading", "Disponibilidad semanal")
    assert has_element?(view, "#availability-summary", "Lunes")
    assert has_element?(view, "#availability-summary", "08:00 a 12:00")
    assert has_element?(view, "#availability-summary-saturday", "Sábado")
    assert has_element?(view, "#availability-summary-saturday", "Sin disponibilidad")
    assert has_element?(view, "#booking-rules-heading", "Período de reserva")
    assert has_element?(view, "#booking-rules-summary", "30 días")
    assert has_element?(view, "#booking-rules-summary", "30 minutos")
    assert has_element?(view, "#timezone-heading", "Zona horaria")
    assert has_element?(view, "#timezone-summary", "Etc/UTC")
  end

  test "rejects anonymous and wrong-role access at the professional route" do
    anonymous_conn = get(build_conn(), @path)
    assert response(anonymous_conn, 401) == "Unauthorized"

    for role <- [:administrator, :secretary] do
      wrong_role_conn =
        build_conn()
        |> log_in_internal_account(insert_active_internal_account!(role))
        |> get(@path)

      assert response(wrong_role_conn, 403) == "Forbidden"
    end
  end

  test "opens a complete seven-day interval-aware draft editor", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    refute has_element?(view, "#availability-summary")

    for day <- ~w(monday tuesday wednesday thursday friday saturday sunday) do
      assert has_element?(view, "#availability-day-#{day}")

      assert has_element?(
               view,
               ~s(button[phx-click="add_availability_window"][phx-value-day="#{day}"])
             )

      assert has_element?(
               view,
               ~s(button[phx-click="clear_availability_day"][phx-value-day="#{day}"])
             )
    end

    assert has_element?(view, ~s(#availability-monday-0-start[type="time"][step="1800"]))
    assert has_element?(view, ~s(#availability-monday-0-end[type="time"][step="1800"]))
  end

  test "adds, removes, clears, and cancels weekly draft windows without changing persisted state",
       %{
         conn: conn
       } do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    refute has_element?(view, "#availability-saturday-0-start")

    view
    |> element(~s(button[phx-click="add_availability_window"][phx-value-day="saturday"]))
    |> render_click()

    assert has_element?(view, "#availability-saturday-0-start")

    view
    |> element(
      ~s(button[phx-click="remove_availability_window"][phx-value-day="saturday"][phx-value-index="0"])
    )
    |> render_click()

    refute has_element?(view, "#availability-saturday-0-start")

    view
    |> element(~s(button[phx-click="clear_availability_day"][phx-value-day="monday"]))
    |> render_click()

    refute has_element?(view, "#availability-monday-0-start")

    view
    |> element(~s(button[phx-click="cancel_availability"]), "Cancelar")
    |> render_click()

    assert has_element?(view, "#availability-summary-monday", "08:00 a 12:00")
  end

  test "edits booking controls inside the weekly availability form", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    assert has_element?(view, ~s(#booking-horizon-days[value="30"][min="7"][max="90"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[value="30"][step="5"]))

    view
    |> element("#availability-form")
    |> render_change(%{
      "availability" => %{"booking_horizon_days" => "45", "minimum_lead_minutes" => "60"}
    })

    assert has_element?(view, ~s(#booking-horizon-days[value="45"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[value="60"]))
  end

  defp open_editor(view) do
    view
    |> element(~s(button[phx-click="edit_availability"]), "Editar disponibilidad")
    |> render_click()
  end

  defp insert_active_internal_account!(role) do
    %{rows: [[account_id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: account_id, role: role, state: :active}
  end
end
