defmodule OrigenWeb.PatientBookingCalendarLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Patients, Repo}
  alias Origen.Patients.{PatientProfile, Persona}

  @email "ana_cal@example.test"

  setup %{conn: conn} do
    Enum.each([PatientProfile, Persona], &Repo.delete_all/1)

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

    %{conn: authed, profile: p}
  end

  describe "calendar view rendering and navigation" do
    test "renders view, slots, unverified warning and navigates dates", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "Calendario de Reservas" and html =~ "Medicina General"
      assert html =~ "09:00" and html =~ "hasta 09:30" and html =~ "Perfil pendiente de"
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

      assert html =~ "Turno Reservado con" and html =~ "Dra. Sof" and html =~ "09:00 hs" and
               html =~ "ha sido confirmado"
    end
  end
end
