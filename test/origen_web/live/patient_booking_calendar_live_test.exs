defmodule OrigenWeb.PatientBookingCalendarLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Patients, Repo}
  alias Origen.Patients.{PatientProfile, Persona}

  @email "ana_cal@example.test"

  setup %{conn: conn} do
    Enum.each([PatientProfile, Persona], &Repo.delete_all/1)
    Repo.query!("DELETE FROM appointments")
    Repo.query!("DELETE FROM consultation_types")
    Repo.query!("DELETE FROM internal_accounts WHERE role = 'professional'")

    prof_res =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'dra.martinez@example.test', 'hash', decode('0102030405', 'hex'), clock_timestamp())
      RETURNING id
      """)

    prof_id = hd(prof_res.rows) |> hd()
    type_uuid = "018f4a5b-0d62-7a44-8e32-2f608bfcb001"

    Repo.query!(
      """
      INSERT INTO consultation_types (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Consulta general', 18000.00, '#0A3847', 2, 'active')
      """,
      [Ecto.UUID.dump!(type_uuid), prof_id]
    )

    attrs = %{
      first_name: "Ana",
      last_name: "Gómez",
      document_type: "dni",
      document_number: "38123456",
      birthdate: ~D[1994-05-20],
      phone: "+5491133445566"
    }

    {:ok, %{profile: p}} = Patients.complete_profile(@email, attrs)

    authed =
      Plug.Conn.put_session(Phoenix.ConnTest.init_test_session(conn, %{}), :patient_email, @email)

    %{conn: authed, profile: p, prof_id: prof_id}
  end

  describe "calendar view rendering and navigation" do
    test "renders view, slots, unverified warning and navigates dates", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "Calendario de Reservas" and html =~ "Medicina General"
      assert html =~ "Perfil pendiente de"
      assert html =~ "Cambiar paciente"
      html_future = render_change(view, "change_date", %{"date" => "2026-09-28"})
      assert html_future =~ "09:00"
      assert has_element?(view, "button[phx-click='select_slot']")

      # Weekend empty state & Day 31 simulated error
      assert render_change(view, "change_date", %{"date" => "2026-09-26"}) =~
               "No hay turnos disponibles"

      assert render_change(view, "change_date", %{"date" => "2026-10-31"}) =~
               "No pudimos cargar la disponibilidad"

      # Next/prev navigation
      assert render_click(view, "nav_date", %{"step" => "1"}) =~ "Horarios Disponibles para"
      assert render_click(view, "nav_date", %{"step" => "-1"}) =~ "Horarios Disponibles para"
    end
  end

  describe "session guard" do
    test "unauthenticated user is redirected to /access", %{} do
      bare_conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})

      assert {:error, {:live_redirect, %{to: "/access"}}} = live(bare_conn, ~p"/patient/calendar")
    end
  end

  describe "slot selection, policies and booking confirmation" do
    test "selecting a slot shows confirmation panel with policies and clears slot", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")

      render_change(view, "change_date", %{"date" => "2026-09-25"})
      html = render_click(view, "select_slot", %{"slot_id" => "SLOT-2026-09-25-0900"})

      assert html =~ "Confirmar Reserva"
      assert html =~ "2026-09-25 de 09:00 a 09:30 hs"
      assert html =~ "Límite sin cargo:"
      assert html =~ "18:00" and html =~ "anterior a la cita (D-1)" and html =~ "50%"

      assert render_click(view, "clear_slot") =~ "Horarios Disponibles para 2026-09-25"
    end

    test "unverified patient receives error, verified patient confirms successfully", %{
      conn: conn,
      profile: profile
    } do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")

      render_change(view, "change_date", %{"date" => "2026-09-25"})
      render_click(view, "select_slot", %{"slot_id" => "SLOT-2026-09-25-0900"})

      # Unverified rejection
      assert render_click(view, "confirm_booking") =~ "completar tu perfil y verificar tu tel"

      # Verify phone and confirm
      Repo.update!(Ecto.Changeset.change(profile, %{phone_verified: true}))
      {:ok, v2, _} = live(conn, ~p"/patient/calendar")
      render_change(v2, "change_date", %{"date" => "2026-09-25"})
      render_click(v2, "select_slot", %{"slot_id" => "SLOT-2026-09-25-0900"})
      html = render_click(v2, "confirm_booking")

      assert html =~ "Turno Reservado con" and html =~ "Dra. Sof" and html =~ "09:00"
      assert html =~ "Turno ID:" and html =~ "Estado inicial (RF-10):" and html =~ "Importe:"
    end

    test "after a successful booking, selecting a new slot allows a second reservation", %{
      conn: conn,
      profile: profile
    } do
      Repo.update!(Ecto.Changeset.change(profile, %{phone_verified: true}))
      {:ok, view, _} = live(conn, ~p"/patient/calendar")

      # Primera reserva
      render_change(view, "change_date", %{"date" => "2026-10-01"})
      render_click(view, "select_slot", %{"slot_id" => "SLOT-2026-10-01-0900"})
      html1 = render_click(view, "confirm_booking")
      assert html1 =~ "Turno Reservado con"

      # Presionar "Reservar otro turno" (clear_slot) debe volver a la grilla
      html2 = render_click(view, "clear_slot")
      assert html2 =~ "Horarios Disponibles para"
      refute html2 =~ "Turno Reservado con"

      # Segunda reserva en el mismo view
      render_change(view, "change_date", %{"date" => "2026-10-02"})
      render_click(view, "select_slot", %{"slot_id" => "SLOT-2026-10-02-0900"})
      html3 = render_click(view, "confirm_booking")
      assert html3 =~ "Turno Reservado con"
    end

    test "changing consultation type recalculates slot availability", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "Tipo de Consulta"
      assert html =~ "Consulta general"

      render_change(view, "change_date", %{"date" => "2026-09-25"})

      html_control =
        render_change(view, "change_type", %{"type_id" => "018f4a5b-0d62-7a44-8e32-2f608bfcb002"})

      assert html_control =~ "Control"
      assert html_control =~ "09:00"
    end

    test "changing professional resets consultation type and duration", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")

      html_procedure =
        render_change(view, "change_type", %{"type_id" => "018f4a5b-0d62-7a44-8e32-2f608bfcb004"})

      assert html_procedure =~ "Procedimiento (60 min)"

      html_lucas = render_change(view, "change_prof", %{"prof_id" => "PRO-DEMO-002"})

      assert html_lucas =~ "Dr. Lucas Varela"
      assert html_lucas =~ "Consulta general (30 min)"
      assert html_lucas =~ ~s(id="type-form-PRO-DEMO-002")
      refute html_lucas =~ "Procedimiento (60 min)"
    end
  end
end
