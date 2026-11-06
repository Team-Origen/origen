defmodule OrigenWeb.PatientBookingCalendarLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Patients, Repo}
  alias Origen.Patients.{PatientProfile, Persona}
  alias OrigenWeb.PatientBookingCalendarFixtures

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

    Repo.query!("DELETE FROM professional_patient_relationships")
    Repo.query!("DELETE FROM appointments")
    Repo.query!("DELETE FROM consultation_types")
    Repo.query!("DELETE FROM agenda_settings")
    Repo.query!("DELETE FROM professional_profiles")
    Enum.each([PatientProfile, Persona], &Repo.delete_all/1)
    Repo.query!("DELETE FROM internal_accounts WHERE role = 'professional'")

    prof_res =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'dra.martinez@example.test', 'hash', decode('0102030405', 'hex'), clock_timestamp())
      RETURNING id
      """)

    prof_id = hd(prof_res.rows) |> hd()

    {:ok, %{session: principal}} = Origen.Sessions.create_session(prof_id)

    assert {:ok, _} =
             Origen.ProfessionalProfiles.save_own_profile(principal, %{
               first_name: "Sofía",
               last_name: "Martínez",
               specialty: "Medicina General",
               license_type: "Libre",
               license_number: "AB/001"
             })

    week =
      ~s({"monday":[{"start":"08:00","end":"18:00"}],"tuesday":[{"start":"08:00","end":"18:00"}],"wednesday":[{"start":"08:00","end":"18:00"}],"thursday":[{"start":"08:00","end":"18:00"}],"friday":[{"start":"08:00","end":"18:00"}],"saturday":[],"sunday":[]})

    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days,
         minimum_lead_minutes, approval_mode, secretary_approval_mode)
      VALUES ($1, 30, $2::jsonb, 30, 0, 'automatic', 'confirmed')
      """,
      [prof_id, week]
    )

    Application.put_env(
      :origen,
      :appointments_calendar_adapter,
      Origen.Appointments.DatabaseCalendar
    )

    Application.put_env(:origen, :consultation_type_catalog_adapter, PersistedCatalog)

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
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, @email)
      |> Plug.Conn.put_session(:patient_authenticated_at, DateTime.to_iso8601(DateTime.utc_now()))

    %{conn: authed, profile: p, prof_id: prof_id}
  end

  describe "patient session authorization" do
    test "redirects when the patient session is absent", %{} do
      unauthenticated_conn =
        Phoenix.ConnTest.build_conn() |> Phoenix.ConnTest.init_test_session(%{})

      assert {:error, {:redirect, %{to: "/access"}}} =
               live(unauthenticated_conn, ~p"/patient/calendar")
    end

    test "redirects when the patient session was invalidated", %{conn: conn, profile: profile} do
      invalidated_at = DateTime.add(DateTime.utc_now(), 1, :second)
      Repo.update!(Ecto.Changeset.change(profile, sessions_invalidated_at: invalidated_at))

      assert {:error, {:redirect, %{to: "/access"}}} =
               live(conn, ~p"/patient/calendar")
    end
  end

  describe "calendar view rendering and navigation" do
    test "professional list failures render a safe generic error", %{conn: conn} do
      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        PatientBookingCalendarFixtures.ErrorCalendar
      )

      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "No se pudo cargar la lista de profesionales"
      assert has_element?(view, "#patient-professionals-error")
      refute has_element?(view, "button[phx-click='confirm_booking']")
    end

    test "catalog failures render an honest error without fabricated slots", %{conn: conn} do
      Application.put_env(
        :origen,
        :consultation_type_catalog_adapter,
        PatientBookingCalendarFixtures.UnavailableCatalog
      )

      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "No se pudieron cargar los tipos de consulta"
      assert has_element?(view, "#patient-catalog-error")
      refute has_element?(view, "button[phx-click='select_slot']")
    end

    test "empty catalogs render a clear empty state without fabricated slots", %{conn: conn} do
      Application.put_env(
        :origen,
        :consultation_type_catalog_adapter,
        PatientBookingCalendarFixtures.EmptyCatalog
      )

      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "No hay tipos de consulta disponibles"
      assert has_element?(view, "#patient-catalog-empty")
      refute has_element?(view, "button[phx-click='select_slot']")
    end

    test "daily schedule failures render an honest availability error", %{conn: conn} do
      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        PatientBookingCalendarFixtures.ScheduleErrorCalendar
      )

      Application.put_env(
        :origen,
        :consultation_type_catalog_adapter,
        PatientBookingCalendarFixtures.AvailableCatalog
      )

      {:ok, view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "No pudimos cargar la disponibilidad"
      refute has_element?(view, "button[phx-click='select_slot']")
    end

    test "empty eligible list renders safely and forged events cannot create a booking", %{
      conn: conn,
      prof_id: prof_id
    } do
      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        PatientBookingCalendarFixtures.EmptyCalendar
      )

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

    test "rejects forged selections and malformed navigation without changing state", %{
      conn: conn,
      prof_id: prof_id
    } do
      {:ok, view, _} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      view
      |> element(~s(button[phx-value-slot_id="SLOT-#{Date.to_iso8601(booking_date)}-0800"]))
      |> render_click()

      selected = render(view)
      render_click(view, "select_slot", %{"slot_id" => "forged-slot"})
      render_change(view, "change_type", %{"type_id" => "forged-type"})
      render_change(view, "change_prof", %{"prof_id" => "forged-professional"})
      render_change(view, "change_date", %{"date" => "not-a-date"})
      render_click(view, "nav_date", %{"step" => "not-a-number"})

      assert render(view) == selected
      assert has_element?(view, "option[value='#{prof_id}'][selected]")
    end

    test "rejects a forged Professional selection without changing the selected schedule", %{
      conn: conn,
      prof_id: prof_id
    } do
      {:ok, view, _} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})
      before = view |> element("#professional-form") |> render()
      render_change(view, "change_prof", %{"prof_id" => "999999"})
      assert view |> element("#professional-form") |> render() == before
      assert has_element?(view, "option[value='#{prof_id}'][selected]")
      assert has_element?(view, "button[phx-click='select_slot']")
    end

    test "confirming without a selected slot is rejected without changing availability", %{
      conn: conn,
      prof_id: prof_id
    } do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      {:ok, before} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      html = render_click(view, "confirm_booking")
      assert html =~ "Seleccioná un horario disponible para reservar"
      refute html =~ "No se pudo realizar la reserva:"

      {:ok, after_attempt} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      assert Enum.map(after_attempt.slots, & &1.id) == Enum.map(before.slots, & &1.id)
    end

    test "an incomplete profile receives a completion reminder without phone verification copy",
         %{
           conn: conn,
           profile: profile
         } do
      Repo.update!(Ecto.Changeset.change(profile, state: "pending_completion"))

      {:ok, _view, html} = live(conn, ~p"/patient/calendar")

      assert html =~ "Completá tu perfil para reservar"
      refute html =~ "verificar tu teléfono"
      refute html =~ "Verificar Teléfono"
    end

    test "renders the real profile and slots and navigates dates", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))

      assert html =~ "Calendario de Reservas" and html =~ "Medicina General"
      refute html =~ "Perfil pendiente de verificación"
      html_future = render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})
      assert html_future =~ "09:00"
      assert has_element?(view, "button[phx-click='select_slot']")

      saturday = next_weekday(booking_date, 6)

      assert render_change(view, "change_date", %{"date" => Date.to_iso8601(saturday)}) =~
               "No hay turnos disponibles"

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
        UPDATE agenda_settings
        SET interval_minutes = 20,
            weekly_availability = $2::jsonb,
            booking_horizon_days = 30,
            minimum_lead_minutes = 0
        WHERE owner_account_id = $1
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
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))

      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      html =
        view
        |> element(~s(button[phx-value-slot_id="SLOT-#{Date.to_iso8601(booking_date)}-0800"]))
        |> render_click()

      assert html =~ "Confirmar Reserva"
      assert html =~ "#{Date.to_iso8601(booking_date)}"
      refute html =~ "Políticas de Cancelación y Asistencia"
      refute html =~ "D-1"
      refute html =~ "Verificación de Teléfono"

      assert render_click(view, "clear_slot") =~
               "Horarios Disponibles para #{Date.to_iso8601(booking_date)}"
    end

    test "an unverified patient confirms once and keeps the result and occupied slot stable", %{
      conn: conn,
      profile: profile,
      prof_id: prof_id
    } do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      {:ok, before} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      slot = Enum.find(before.slots, &(&1.start_formatted == "08:00"))

      view
      |> element(~s(button[phx-value-slot_id="#{slot.id}"]))
      |> render_click()

      first_html = render_click(view, "confirm_booking")
      assert first_html =~ "Turno confirmado"
      assert first_html =~ "Sofía Martínez"
      assert first_html =~ "Consulta general"
      assert first_html =~ "18000.00"
      refute first_html =~ "D-1"
      refute first_html =~ "RF-10"

      {:ok, after_first} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      refute Enum.any?(after_first.slots, &(&1.id == slot.id))

      assert {:error, :overlap_detected} =
               Origen.Appointments.BookingService.reserve(profile, %{
                 professional_id: prof_id,
                 consultation_type_id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
                 date: booking_date,
                 slot: slot
               })

      assert render_click(view, "confirm_booking") == first_html

      {:ok, after_duplicate} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      refute Enum.any?(after_duplicate.slots, &(&1.id == slot.id))

      html_after_clear = render_click(view, "clear_slot")
      refute html_after_clear =~ "Turno confirmado"
      refute has_element?(view, "button[phx-value-slot_id='#{slot.id}']")
    end

    test "booking failures use a generic sanitized message and preserve availability", %{
      conn: conn,
      prof_id: prof_id
    } do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      {:ok, before} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      slot = Enum.find(before.slots, &(&1.start_formatted == "08:00"))

      view
      |> element(~s(button[phx-value-slot_id="#{slot.id}"]))
      |> render_click()

      Repo.query!("UPDATE professional_profiles SET specialty = '' WHERE owner_account_id = $1", [
        prof_id
      ])

      html = render_click(view, "confirm_booking")
      assert html =~ "No se pudo completar la reserva"
      refute html =~ "professional_not_eligible"
      refute html =~ "No se pudo realizar la reserva:"

      {:ok, after_attempt} =
        Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
          duration_minutes: 60
        )

      assert Enum.any?(after_attempt.slots, &(&1.id == slot.id))
    end

    test "manual approval renders a pending request result", %{conn: conn, prof_id: prof_id} do
      Repo.query!(
        "UPDATE agenda_settings SET approval_mode = 'manual' WHERE owner_account_id = $1",
        [prof_id]
      )

      {:ok, view, _html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      view
      |> element(~s(button[phx-value-slot_id="SLOT-#{Date.to_iso8601(booking_date)}-0800"]))
      |> render_click()

      html = render_click(view, "confirm_booking")
      assert html =~ "Solicitud enviada"
      assert html =~ "Pendiente de aprobación"
      refute html =~ "Estado inicial (RF-10)"
    end

    test "a stale slot reports a conflict and refreshes availability", %{
      conn: conn,
      prof_id: prof_id
    } do
      {:ok, view, _html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))
      render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

      slot =
        %{id: slot_id, start_formatted: start_formatted} =
        view
        |> render()
        |> then(fn _ ->
          {:ok, schedule} =
            Origen.Appointments.Calendar.get_daily_schedule(to_string(prof_id), booking_date,
              duration_minutes: 60
            )

          Enum.find(schedule.slots, &(&1.start_formatted == "08:00"))
        end)

      view |> element(~s(button[phx-value-slot_id="#{slot_id}"])) |> render_click()

      other_email = "stale_other@example.test"

      {:ok, %{profile: other}} =
        Patients.complete_profile(other_email, %{
          first_name: "Otro",
          last_name: "Paciente",
          document_type: "dni",
          document_number: "38123457",
          birthdate: ~D[1994-05-20],
          phone: "+5491133445567"
        })

      assert {:ok, _} =
               Origen.Appointments.BookingService.reserve(other, %{
                 professional_id: prof_id,
                 consultation_type_id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
                 date: booking_date,
                 slot: Map.put(slot, :start_time, Time.from_iso8601!(start_formatted <> ":00"))
               })

      html = render_click(view, "confirm_booking")
      assert html =~ "Ese horario ya no está disponible"
      refute has_element?(view, "button[phx-value-slot_id='#{slot_id}']")
      refute html =~ "No se pudo realizar la reserva:"
    end

    test "changing consultation type recalculates slot availability", %{
      conn: conn,
      prof_id: prof_id
    } do
      control_id = "018f4a5b-0d62-7a44-8e32-2f608bfcb002"

      Repo.query!(
        """
        INSERT INTO consultation_types
          (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
        VALUES ($1, $2, 'Control', 12000.00, '#0A3847', 2, 'active')
        """,
        [Ecto.UUID.dump!(control_id), prof_id]
      )

      {:ok, view, html} = live(conn, ~p"/patient/calendar")
      booking_date = next_weekday(Date.utc_today(), Date.day_of_week(Date.utc_today()))

      assert html =~ "Tipo de Consulta"
      assert html =~ "Consulta general"

      html_control =
        view
        |> render_change("change_type", %{"type_id" => control_id})

      assert html_control =~ "Control"

      assert render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)}) =~
               "09:00"
    end
  end

  defp next_weekday(date, target_day) do
    offset = rem(target_day - Date.day_of_week(date) + 7, 7)
    Date.add(date, if(offset == 0, do: 7, else: offset))
  end
end
