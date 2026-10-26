defmodule OrigenWeb.ProfessionalProfileIntegrationTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Origen.{Availability, ConsultationTypes, Patients, ProfessionalProfiles, Sessions}
  alias Origen.Appointments.{Calendar, DatabaseCalendar}

  @settings "/configuracion/profesional"
  @editor @settings <> "/perfil"
  @profile %{
    "first_name" => "Sofía",
    "last_name" => "Martínez",
    "specialty" => "Cardiología",
    "license_type" => "Libre provincial",
    "license_number" => "PRIVADA-001/X"
  }
  @adapter_keys [:appointments_calendar_adapter, :consultation_type_catalog_adapter]

  defmodule UnavailableCatalog do
    def execute(_operation), do: {:error, :unavailable}
  end

  setup %{conn: conn} do
    previous = Map.new(@adapter_keys, &{&1, Application.get_env(:origen, &1)})

    on_exit(fn ->
      Enum.each(previous, fn {key, value} -> Application.put_env(:origen, key, value) end)
    end)

    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)

    Application.put_env(
      :origen,
      :consultation_type_catalog_adapter,
      Origen.ConsultationTypes.DatabaseCatalog
    )

    professional = account!(:professional)
    conn = log_in_internal_account(conn, professional)
    {:ok, principal} = Sessions.touch_session(get_session(conn, :internal_session_token))
    {:ok, conn: conn, principal: principal}
  end

  test "real incomplete preparation, persisted settings, profile and photo-free Patient reservation",
       %{conn: conn, principal: principal} do
    {:ok, settings, _} = live(conn, @settings)
    assert has_element?(settings, "#profile-entry-status", "Perfil incompleto")
    assert {:ok, before_list} = Calendar.list_professionals()
    refute Enum.any?(before_list, &(&1.id == to_string(principal.account_id)))

    # Change the interval through its review/confirmation flow before adding the catalog.
    settings |> form("#agenda-interval-form", interval_minutes: "20") |> render_change()
    settings |> element("#open-interval-change-modal") |> render_click()

    settings
    |> element("#agenda-interval-change-modal button", "Revisar cambios")
    |> render_click()

    settings |> form("#interval-review-form") |> render_submit()
    assert has_element?(settings, "#current-agenda-interval", "20 minutos")

    settings |> element("button[phx-click='open_new_type']") |> render_click()

    settings
    |> form("#new-consultation-type-form",
      consultation_type: %{
        "name" => "Consulta integrada",
        "currency" => "ARS",
        "exact_price_ars" => "21.500,50",
        "color" => "#0A7C86",
        "interval_count" => "3"
      }
    )
    |> render_submit()

    assert has_element?(settings, "#consultation-types-table-view", "Consulta integrada")
    assert has_element?(settings, "#consultation-types-table-view", "60 minutos")
    assert has_element?(settings, "#consultation-types-table-view", "ARS 21.500,50")

    settings |> element("button[phx-click='edit_availability']") |> render_click()

    for day <- ~w(monday tuesday wednesday thursday friday saturday sunday) do
      settings
      |> element("button[phx-click='clear_availability_day'][phx-value-day='#{day}']")
      |> render_click()

      settings
      |> element("button[phx-click='add_availability_window'][phx-value-day='#{day}']")
      |> render_click()
    end

    settings |> form("#availability-form", availability: availability_params()) |> render_submit()
    assert has_element?(settings, "#availability-save-success")
    assert has_element?(settings, "#booking-rules-summary", "14 días")
    assert has_element?(settings, "#booking-rules-summary", "60 minutos")
    assert {:ok, catalog} = ConsultationTypes.get_own_configuration(principal)
    assert {:ok, availability} = Availability.get_own_configuration(principal)
    assert catalog.agenda_interval_minutes == 20
    assert availability.booking_horizon_days == 14
    assert availability.minimum_lead_minutes == 60

    editor = open_editor(conn)
    editor |> form("#profile-form", profile: @profile) |> render_submit()
    assert has_element?(editor, "#profile-status", "Perfil completo")
    assert {:ok, profile} = ProfessionalProfiles.get_own_profile(principal)
    assert profile.complete?
    refute Map.has_key?(profile, :photo)
    assert {:ok, ^catalog} = ConsultationTypes.get_own_configuration(principal)
    assert {:ok, ^availability} = Availability.get_own_configuration(principal)

    {:ok, summary, _} = live(conn, @settings)
    assert has_element?(summary, "#profile-patient-preview", "Sofía Martínez")
    assert has_element?(summary, "#profile-summary-details", "Cardiología")
    assert has_element?(summary, "#profile-license-summary", "PRIVADA-001/X")
    refute has_element?(summary, "#profile-patient-preview", "PRIVADA-001/X")

    patient_conn = patient_conn!()
    {:ok, calendar, html} = live(patient_conn, "/patient/calendar")
    assert html =~ "Sofía Martínez - Cardiología"
    assert html =~ "Consulta integrada (60 min)"
    refute html =~ "PRIVADA-001/X"
    date = Date.add(Date.utc_today(), 2)
    calendar |> form("#date-form", date: Date.to_iso8601(date)) |> render_change()
    slot = "SLOT-#{date}-0920"
    assert has_element?(calendar, "button[phx-value-slot_id='#{slot}']")
    calendar |> element("button[phx-value-slot_id='#{slot}']") |> render_click()
    assert render(calendar) =~ "09:20 a 10:20"
    assert render(calendar) =~ "Sofía Martínez"
    calendar |> element("button[phx-click='confirm_booking']") |> render_click()
    assert render(calendar) =~ "Turno ID:"
    assert render(calendar) =~ "Consulta integrada"
    assert render(calendar) =~ "21500.50"

    assert {:ok, schedule} =
             Calendar.get_daily_schedule(to_string(principal.account_id), date,
               duration_minutes: 60
             )

    assert is_list(schedule.slots)

    # Horizon stays real, rather than falling back to the demo calendar.
    render_change(calendar, "change_date", %{
      "date" => Date.to_iso8601(Date.add(Date.utc_today(), 15))
    })

    refute has_element?(calendar, "button[phx-click='select_slot']")

    # Losing a required datum removes this account from a fresh Patient list,
    # but never erases its settings or existing appointments.
    editor |> element("#profile-edit") |> render_click()

    editor
    |> form("#profile-form", profile: Map.put(@profile, "specialty", ""))
    |> render_submit()

    {:ok, without_profile, _} = live(patient_conn, "/patient/calendar")

    refute has_element?(
             without_profile,
             "#professional-form option[value='#{principal.account_id}']"
           )

    assert {:ok, ^catalog} = ConsultationTypes.get_own_configuration(principal)
    assert {:ok, ^availability} = Availability.get_own_configuration(principal)
  end

  test "complete profile without active consultations cannot offer a fabricated reservation", %{
    conn: conn,
    principal: principal
  } do
    assert {:ok, _} = ConsultationTypes.get_own_configuration(principal)
    editor = open_editor(conn)
    editor |> form("#profile-form", profile: @profile) |> render_submit()
    {:ok, calendar, _} = live(build_conn(), "/patient/calendar")
    assert has_element?(calendar, "#professional-form option[value='#{principal.account_id}']")

    assert has_element?(
             calendar,
             "#patient-catalog-empty",
             "No hay tipos de consulta disponibles"
           )

    refute has_element?(calendar, "button[phx-click='select_slot']")
    refute has_element?(calendar, "#type-form option")
    render_change(calendar, "change_prof", %{"prof_id" => to_string(principal.account_id)})
    assert has_element?(calendar, "#patient-catalog-empty")
    render_click(calendar, "confirm_booking", %{})
    refute render(calendar) =~ "Turno ID:"
  end

  test "catalog failure displays an honest error and offers no fabricated slots", %{conn: conn} do
    editor = open_editor(conn)
    editor |> form("#profile-form", profile: @profile) |> render_submit()
    Application.put_env(:origen, :consultation_type_catalog_adapter, UnavailableCatalog)
    {:ok, calendar, _} = live(build_conn(), "/patient/calendar")

    assert has_element?(
             calendar,
             "#patient-catalog-error",
             "No se pudieron cargar los tipos de consulta"
           )

    refute has_element?(calendar, "#type-form option")
    refute has_element?(calendar, "button[phx-click='select_slot']")
  end

  test "forged owner identifiers cannot read or mutate another profile through the editor", %{
    conn: conn,
    principal: principal
  } do
    other = account!(:professional)
    {:ok, %{session: other_principal}} = Sessions.create_session(other)

    assert {:ok, other_before} =
             ProfessionalProfiles.save_own_profile(
               other_principal,
               Map.put(@profile, "first_name", "Privado")
             )

    assert {:ok, catalog} = ConsultationTypes.get_own_configuration(other_principal)
    assert {:ok, availability} = Availability.get_own_configuration(other_principal)
    {:ok, editor, _} = live(conn, @editor <> "?owner_account_id=#{other.id}")
    render_async(editor)
    refute render(editor) =~ "Privado"
    editor |> element("#profile-edit") |> render_click()

    render_submit(editor, "save_profile", %{
      "profile" => Map.put(@profile, "owner_account_id", other.id)
    })

    assert {:ok, ^other_before} = ProfessionalProfiles.get_own_profile(other_principal)
    assert {:ok, ^catalog} = ConsultationTypes.get_own_configuration(other_principal)
    assert {:ok, ^availability} = Availability.get_own_configuration(other_principal)
    assert {:ok, own} = ProfessionalProfiles.get_own_profile(principal)
    assert own.first_name == "Sofía"
    assert own.owner_account_id == principal.account_id
  end

  defp open_editor(conn) do
    {:ok, view, _} = live(conn, @editor)
    render_async(view)
    assert has_element?(view, "#profile-edit", "Completar perfil")
    view |> element("#profile-edit") |> render_click()
    view
  end

  defp availability_params do
    week =
      Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
        {day, %{"_present" => "true", "0" => %{"start" => "08:00", "end" => "12:00"}}}
      end)

    %{
      "weekly_availability" => week,
      "booking_horizon_days" => "14",
      "minimum_lead_minutes" => "60"
    }
  end

  defp patient_conn! do
    email = "issue304@example.test"
    phone = "+5491133445304"

    assert {:ok, %{profile: profile}} =
             Patients.complete_profile(email, %{
               first_name: "Paciente",
               last_name: "Integración",
               document_type: "dni",
               document_number: "38304304",
               birthdate: ~D[1994-05-20],
               phone: phone
             })

    assert {:ok, %{code: code}} =
             Patients.request_phone_verification(profile, phone,
               code: "123456",
               return_code: true
             )

    assert {:ok, _} = Patients.verify_phone_code(email, code)
    build_conn() |> Plug.Test.init_test_session(%{}) |> put_session(:patient_email, email)
  end

  defp account!(role) do
    %{rows: [[id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW()) RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: id, role: role, state: :active}
  end
end
