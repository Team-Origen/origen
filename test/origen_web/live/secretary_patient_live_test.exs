defmodule OrigenWeb.SecretaryPatientLiveTest do
  use OrigenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Origen.Booking.Appointment
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @path "/secretaria/pacientes"

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)
    :ok
  end

  describe "mount authorization" do
    test "redirects unauthenticated visitors to the home page" do
      assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), @path)
    end

    test "redirects internal roles outside secretary and administrator" do
      conn =
        build_conn()
        |> log_in_internal_account(insert_active_internal_account!(:professional))

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, @path)
    end

    test "secretary and administrator mount the patient search view" do
      for role <- [:secretary, :administrator] do
        conn =
          build_conn()
          |> log_in_internal_account(insert_active_internal_account!(role))

        assert {:ok, _view, html} = live(conn, @path)
        assert html =~ "Búsqueda de pacientes"
        assert html =~ "Buscar persona"
      end
    end
  end

  describe "document search" do
    test "searching an existing persona renders the patient summary" do
      {:ok, _} =
        Patients.complete_profile("carlos@example.test", %{
          first_name: "Carlos",
          last_name: "López",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1988-07-20],
          phone: "+5491144332211"
        })

      {:ok, view, _html} = live(secretary_conn(), @path)

      html =
        view
        |> form("#persona-search-form",
          search: %{"document_type" => "dni", "document_number" => "35.987.654"}
        )
        |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert html =~ "Carlos López"
      assert has_element?(view, "#patient-summary-document", "DNI 35987654")
      assert has_element?(view, "#patient-summary-profile-state", "Completado")
      assert has_element?(view, "#patient-summary-phone", "+5491144332211")
      assert has_element?(view, "#patient-summary-phone-verified", "Teléfono no verificado")

      assert has_element?(
               view,
               ~s(button#start-assisted-booking[phx-click="start_assisted_booking"]),
               "Iniciar Reserva Asistida"
             )
    end

    test "searching an unknown document shows the assisted registration form" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      html =
        view
        |> form("#persona-search-form",
          search: %{"document_type" => "dni", "document_number" => "37000111"}
        )
        |> render_submit()

      assert html =~ "No encontramos una persona con el documento indicado"
      assert has_element?(view, "#persona-registration-section")
      assert has_element?(view, "#assisted-registration-form")
      refute has_element?(view, "#patient-summary-section")

      assert has_element?(
               view,
               ~s(input[type="hidden"][name="registration[document_type]"][value="dni"])
             )

      assert has_element?(
               view,
               ~s(input[type="hidden"][name="registration[document_number]"][value="37000111"])
             )

      assert has_element?(view, "#assisted-registration-form p strong", "DNI 37000111")

      for label <- ["Nombres", "Apellidos", "Fecha de nacimiento", "Teléfono", "Género"] do
        assert has_element?(view, "#assisted-registration-form label", label)
      end

      assert has_element?(view, "#assisted-registration-form button", "Registrar persona")
    end

    test "invalid searches keep real-time feedback without leaving the search form" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      html =
        view
        |> form("#persona-search-form", search: %{"document_number" => ""})
        |> render_submit()

      assert html =~ "no puede estar en blanco"
      refute has_element?(view, "#persona-registration-section")
      refute has_element?(view, "#patient-summary-section")
    end
  end

  describe "assisted registration" do
    test "registering a new persona creates the identity and shows the summary" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      html =
        view
        |> form("#assisted-registration-form",
          registration: %{
            "first_name" => "Ana",
            "last_name" => "Torres",
            "birthdate" => "1990-03-05",
            "phone" => "+5491155554444",
            "gender" => "femenino"
          }
        )
        |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert html =~ "Ana Torres"
      assert html =~ "Persona registrada correctamente."
      assert has_element?(view, "#patient-summary-document", "DNI 37000111")
      assert has_element?(view, "#patient-summary-profile-state", "Pendiente de completar")
      assert has_element?(view, "#patient-summary-phone", "+5491155554444")
      refute has_element?(view, "#assisted-registration-form")

      persona = Repo.get_by!(Persona, document_type: "dni", document_number: "37000111")
      profile = Repo.get_by!(PatientProfile, persona_id: persona.id)

      assert persona.first_name == "Ana"
      assert persona.last_name == "Torres"
      assert profile.state == "pending_completion"
      assert profile.phone == "+5491155554444"
      assert profile.email == "asistido-persona-#{persona.id}@origen.local"
    end

    test "submitting invalid registration data keeps the form with accessible errors" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      html =
        view
        |> form("#assisted-registration-form",
          registration: %{
            "first_name" => "",
            "last_name" => "",
            "birthdate" => "",
            "phone" => "",
            "gender" => ""
          }
        )
        |> render_submit()

      assert has_element?(view, "#assisted-registration-form")
      assert html =~ "no puede estar en blanco"
      refute has_element?(view, "#patient-summary-section")
      assert Repo.aggregate(Persona, :count) == 0
    end

    test "a new search resets the registration flow" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      assert has_element?(view, "#assisted-registration-form")

      view
      |> element("button", "Nueva búsqueda")
      |> render_click()

      refute has_element?(view, "#assisted-registration-form")
      refute has_element?(view, "#patient-summary-section")
      assert has_element?(view, "#persona-search-form")
    end
  end

  describe "assisted booking entry point" do
    test "iniciar reserva asistida abre la sección real sin aviso de próximamente" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      view
      |> form("#assisted-registration-form",
        registration: %{
          "first_name" => "Ana",
          "last_name" => "Torres",
          "birthdate" => "1990-03-05",
          "phone" => "+5491155554444",
          "gender" => "femenino"
        }
      )
      |> render_submit()

      refute has_element?(view, "#assisted-booking-notice")

      view
      |> element("#start-assisted-booking", "Iniciar Reserva Asistida")
      |> render_click()

      assert has_element?(view, "#assisted-booking-section")
      refute has_element?(view, "#assisted-booking-notice")
      refute render(view) =~ "próximamente"
    end

    test "C11: al iniciar reserva asistida muestra la sección con selector de profesionales y fecha" do
      {:ok, _} =
        Patients.complete_profile("carlos@example.test", %{
          first_name: "Carlos",
          last_name: "López",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1988-07-20],
          phone: "+5491144332211"
        })

      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "35.987.654"}
      )
      |> render_submit()

      view
      |> element("#start-assisted-booking", "Iniciar Reserva Asistida")
      |> render_click()

      assert has_element?(view, "#assisted-booking-section")
      assert has_element?(view, "#assisted-booking-heading", "Reserva asistida de turno")
      assert has_element?(view, "#booking-professional-select")
      assert has_element?(view, "#booking-consultation-type-select")
      assert has_element?(view, "#booking-date-input")
      assert has_element?(view, "#prof-approval-mode-badge")
      assert has_element?(view, "#confirm-assisted-booking")
      assert has_element?(view, "#cancel-assisted-booking")
    end

    test "C12: permite seleccionar horario disponible y confirmar la reserva asistida" do
      previous_adapter = Application.get_env(:origen, :appointments_calendar_adapter)

      on_exit(fn ->
        Application.put_env(:origen, :appointments_calendar_adapter, previous_adapter)
      end)

      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        Origen.Appointments.DatabaseCalendar
      )

      {:ok, %{profile: profile}} =
        Patients.complete_profile("carlos2@example.test", %{
          first_name: "Carlos",
          last_name: "López",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1988-07-20],
          phone: "+5491144332211"
        })

      prof_id = insert_active_internal_account!(:professional).id
      insert_complete_professional_profile!(prof_id)
      insert_weekly_agenda_settings!(prof_id, 30)

      type_uuid = "018f4a5b-0d62-7a44-8e32-2f608bfcb312"

      Repo.query!(
        """
        INSERT INTO consultation_types (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
        VALUES ($1, $2, 'Consulta de prueba', 18000.00, '#0A3847', 1, 'active')
        """,
        [Ecto.UUID.dump!(type_uuid), prof_id]
      )

      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "35.987.654"}
      )
      |> render_submit()

      view
      |> element("#start-assisted-booking", "Iniciar Reserva Asistida")
      |> render_click()

      assert has_element?(view, "#assisted-booking-section")

      # Fecha futura garantiza disponibilidad a cualquier hora de ejecución.
      future_date = Date.add(next_weekday(Date.utc_today()), 7)

      render_change(view, "update_booking_selection", %{"date" => Date.to_iso8601(future_date)})

      assert has_element?(view, "#booking-slots-grid button")

      view
      |> element("#booking-slots-grid button:first-child")
      |> render_click()

      view
      |> element("#confirm-assisted-booking")
      |> render_click()

      assert has_element?(view, "#booking-success-message")

      appointment =
        Repo.get_by!(Appointment,
          patient_profile_id: profile.id,
          professional_account_id: prof_id
        )

      assert appointment.status == "confirmed"
    end

    test "un profesional sin tipos de consulta no muestra tipos inventados y mantiene el botón deshabilitado" do
      previous_adapter = Application.get_env(:origen, :appointments_calendar_adapter)

      on_exit(fn ->
        Application.put_env(:origen, :appointments_calendar_adapter, previous_adapter)
      end)

      Application.put_env(
        :origen,
        :appointments_calendar_adapter,
        Origen.Appointments.DatabaseCalendar
      )

      {:ok, _} =
        Patients.complete_profile("carlos3@example.test", %{
          first_name: "Carlos",
          last_name: "López",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1988-07-20],
          phone: "+5491144332211"
        })

      prof_id = insert_active_internal_account!(:professional).id
      insert_complete_professional_profile!(prof_id)
      insert_weekly_agenda_settings!(prof_id, 30)

      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "35.987.654"}
      )
      |> render_submit()

      view
      |> element("#start-assisted-booking", "Iniciar Reserva Asistida")
      |> render_click()

      assert has_element?(view, "#assisted-booking-section")
      refute has_element?(view, "#booking-consultation-type-select option")
      refute render(view) =~ "Consulta General"
      assert has_element?(view, "#confirm-assisted-booking[disabled]")
    end
  end

  describe "defensive guards" do
    test "confirmar reserva sin búsqueda previa no rompe la vista y muestra el error" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      html = render_click(view, "confirm_assisted_booking", %{})

      assert has_element?(view, "#booking-error-message")
      assert html =~ "Por favor seleccioná todos los campos y un horario disponible."
    end
  end

  defp secretary_conn do
    build_conn()
    |> log_in_internal_account(insert_active_internal_account!(:secretary))
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

  defp insert_complete_professional_profile!(prof_id) do
    Repo.query!(
      """
      INSERT INTO professional_profiles
        (owner_account_id, first_name, last_name, specialty, license_type, license_number)
      VALUES ($1, 'Sofía', 'Martínez', 'Medicina General', 'Nacional', 'MN-12345')
      """,
      [prof_id]
    )

    :ok
  end

  defp insert_weekly_agenda_settings!(prof_id, interval_minutes) do
    week =
      Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
        {day, [%{"start" => "08:00", "end" => "18:00"}]}
      end)

    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days, minimum_lead_minutes)
      VALUES ($1, $2, $3, 30, 0)
      """,
      [prof_id, interval_minutes, week]
    )

    :ok
  end

  defp next_weekday(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, 2)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end
end
