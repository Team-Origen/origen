defmodule OrigenWeb.PatientBookingCalendarLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Patients, Repo}
  alias Origen.Patients.{PatientProfile, Persona}

  @email "ana_cal@example.test"

  defmodule PersistedCatalog do
    def execute({:list, %{professional_reference: professional_reference}}) do
      {professional_id, ""} = Integer.parse(professional_reference)

      [[interval]] =
        Origen.Repo.query!(
          "SELECT interval_minutes FROM agenda_settings WHERE owner_account_id = $1",
          [professional_id]
        ).rows

      types =
        Origen.Repo.query!(
          """
          SELECT id, name, interval_count, exact_price_ars, status
          FROM consultation_types
          WHERE owner_account_id = $1
          ORDER BY created_at, id
          """,
          [professional_id]
        ).rows
        |> Enum.map(fn [id, name, interval_count, exact_price_ars, status] ->
          %{
            id: Ecto.UUID.load!(id),
            name: name,
            interval_count: interval_count,
            exact_price_ars: exact_price_ars,
            status: String.to_existing_atom(status)
          }
        end)

      {:ok,
       %{
         source: :database,
         professional_reference: professional_reference,
         agenda_interval_minutes: interval,
         consultation_types: types
       }}
    end
  end

  setup %{conn: conn} do
    previous_calendar = Application.get_env(:origen, :appointments_calendar_adapter)
    previous_catalog = Application.get_env(:origen, :consultation_type_catalog_adapter)

    on_exit(fn ->
      Application.put_env(:origen, :appointments_calendar_adapter, previous_calendar)
      Application.put_env(:origen, :consultation_type_catalog_adapter, previous_catalog)
    end)

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
      last_name: "GÃ³mez",
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
    test "empty eligible list renders safely and forged events cannot create a booking", %{
      conn: conn,
      profile: profile,
      prof_id: prof_id
    } do
      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        Origen.Appointments.DatabaseCalendar
      )

      Repo.update!(Ecto.Changeset.change(profile, %{phone_verified: true}))
      before = Repo.query!("SELECT count(*) FROM appointments").rows
      {:ok, view, html} = live(conn, ~p"/patient/calendar")
      assert html =~ "No hay profesionales disponibles"
      refute has_element?(view, "#professional-form")
      refute has_element?(view, "button[phx-click='select_slot']")
      refute has_element?(view, "button[phx-click='confirm_booking']")

      for {event, params} <- [
            {"change_prof", %{"prof_id" => to_string(prof_id)}},
            {"change_type", %{"type_id" => "forged"}},
            {"change_date", %{"date" => "2026-09-25"}},
            {"nav_date", %{"step" => "1"}},
            {"select_slot", %{"slot_id" => "forged"}},
            {"confirm_booking", %{}}
          ] do
        assert render_click(view, event, params) =~ "No hay profesionales disponibles"
      end

      assert Repo.query!("SELECT count(*) FROM appointments").rows == before
    end

    test "rejects a forged Professional selection without changing the selected schedule", %{
      conn: conn
    } do
      {:ok, view, _} = live(conn, ~p"/patient/calendar")
      render_change(view, "change_date", %{"date" => "2026-09-25"})
      before = view |> element("#professional-form") |> render()
      render_change(view, "change_prof", %{"prof_id" => "999999"})
      assert view |> element("#professional-form") |> render() == before
      assert has_element?(view, "option[value='PRO-DEMO-001'][selected]")
      assert has_element?(view, "button[phx-value-slot_id='SLOT-2026-09-25-0900']")
      refute render(view) =~ "No pudimos cargar la disponibilidad"
      html = render_change(view, "change_prof", %{"prof_id" => "PRO-DEMO-002"})
      assert has_element?(view, "option[value='PRO-DEMO-002'][selected]")
      # The second mock Professional has no catalog: never invent an offer.
      assert html =~ "No se pudieron cargar los tipos de consulta"
      refute has_element?(view, "button[phx-click='select_slot']")
    end

    test "renders view, slots, unverified warning and navigates dates", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "Calendario de Reservas" and html =~ "Medicina General"
      assert html =~ "Perfil pendiente de"
      html_future = render_change(view, "change_date", %{"date" => "2026-09-25"})
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

    test "uses a persisted non-default slot grid while keeping duration contiguous", %{
      conn: conn,
      prof_id: prof_id
    } do
      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        Origen.Appointments.DatabaseCalendar
      )

      Application.put_env(:origen, :consultation_type_catalog_adapter, PersistedCatalog)

      {:ok, %{session: owner}} = Origen.Sessions.create_session(prof_id)

      assert {:ok, _} =
               Origen.ProfessionalProfiles.save_own_profile(owner, %{
                 first_name: "Sofía",
                 last_name: "Martínez",
                 specialty: "Cardiología",
                 license_type: "Nacional",
                 license_number: "AB/001"
               })

      friday = next_weekday(Date.utc_today(), 5)

      week =
        Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []})
        |> Map.put("friday", [%{"start" => "09:00", "end" => "12:00"}])

      Repo.query!(
        """
        INSERT INTO agenda_settings
          (owner_account_id, interval_minutes, weekly_availability,
           booking_horizon_days, minimum_lead_minutes)
        VALUES ($1, 20, $2, 30, 0)
        """,
        [prof_id, week]
      )

      Repo.query!(
        "UPDATE consultation_types SET interval_count = 3 WHERE owner_account_id = $1",
        [prof_id]
      )

      {:ok, view, html} = live(conn, ~p"/patient/calendar")
      assert html =~ "Consulta general (60 min)"

      html = render_change(view, "change_date", %{"date" => Date.to_iso8601(friday)})
      assert html =~ "09:20"
      assert html =~ "10:20"

      view
      |> element(~s(button[phx-value-slot_id="SLOT-#{Date.to_iso8601(friday)}-0920"]))
      |> render_click()

      assert render(view) =~ "09:20 a 10:20"
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
      profile: profile,
      prof_id: prof_id
    } do
      {:ok, %{session: principal}} = Origen.Sessions.create_session(prof_id)

      assert {:ok, _} =
               Origen.ProfessionalProfiles.save_own_profile(principal, %{
                 first_name: "Sofía",
                 last_name: "Martínez",
                 specialty: "Medicina General",
                 license_type: "Libre",
                 license_number: "AB/001"
               })

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
      assert html =~ "Turno ID:" and html =~ "Estado inicial (RF-10):" and html =~ "Importe:"
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
  end

  defp next_weekday(date, target_day) do
    offset = rem(target_day - Date.day_of_week(date) + 7, 7)
    Date.add(date, if(offset == 0, do: 7, else: offset))
  end
end
