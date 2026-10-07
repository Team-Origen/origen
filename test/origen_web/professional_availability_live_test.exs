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
