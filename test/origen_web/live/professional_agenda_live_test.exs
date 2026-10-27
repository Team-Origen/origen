defmodule OrigenWeb.ProfessionalAgendaLiveTest do
  @moduledoc """
  Pruebas de integración para la vista LiveView de la agenda diaria del Profesional
  (Issue #80 / PLN-10).
  """

  use OrigenWeb.LiveViewCase

  alias Ecto.Adapters.SQL
  alias Origen.Repo
  alias Origen.Sessions

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"

  setup do
    professional_id = insert_internal_account("dr.house@example.com", "professional")
    secretary_id = insert_internal_account("secretary@example.com", "secretary")
    admin_id = insert_internal_account("admin@example.com", "administrator")

    :ok = insert_agenda_settings(professional_id)
    :ok = insert_consultation_type(professional_id)

    {:ok, %{token: prof_token}} = Sessions.create_session(professional_id)
    {:ok, %{token: sec_token}} = Sessions.create_session(secretary_id)
    {:ok, %{token: admin_token}} = Sessions.create_session(admin_id)

    patient_1 = insert_patient_profile("Mario", "Bros", "dni", "35111222", "+5491144445555")
    patient_2 = insert_patient_profile("Luigi", "Bros", "dni", "35333444", "+5491166667777")

    %{
      professional_id: professional_id,
      prof_token: prof_token,
      sec_token: sec_token,
      admin_token: admin_token,
      patient_1: patient_1,
      patient_2: patient_2
    }
  end

  defmodule PatientSelectorDouble do
    def execute({:related, _session}) do
      {:ok, [patient("related", "Mario", "35111222")]}
    end

    def execute({:search, _session, "35333444"}),
      do: {:ok, patient("exact", "Luigi", "35333444")}

    def execute({:search, _session, "123"}), do: {:error, :invalid_document}
    def execute({:search, _session, _dni}), do: {:ok, nil}

    defp patient(id, name, dni) do
      %{
        id: id,
        first_name: name,
        last_name: "Bros",
        document_number: dni,
        phone: "private-phone",
        email: "private-email",
        other_professional: "private-activity"
      }
    end
  end

  describe "patient selection preparation (#315)" do
    setup do
      previous = Application.get_env(:origen, :professional_patient_selector)
      Application.put_env(:origen, :professional_patient_selector, PatientSelectorDouble)

      on_exit(fn ->
        if previous do
          Application.put_env(:origen, :professional_patient_selector, previous)
        else
          Application.delete_env(:origen, :professional_patient_selector)
        end
      end)

      :ok
    end

    test "agenda links to a separate patient-only view and cancel returns", %{
      conn: conn,
      prof_token: token
    } do
      conn = put_internal_session(conn, token)
      {:ok, agenda, _} = live(conn, ~p"/profesional/agenda")

      assert has_element?(
               agenda,
               "#create-professional-appointment[href='/profesional/agenda/crear']"
             )

      {:ok, view, html} = live(conn, ~p"/profesional/agenda/crear")
      assert html =~ "Seleccioná al paciente"
      assert has_element?(view, "#cancel-patient-selection[href='/profesional/agenda']")
      refute has_element?(view, "#approval-config-panel")
      refute has_element?(view, "[phx-click='confirm_booking']")
      assert has_element?(view, "#patient-selection-next[disabled]")
    end

    test "related selection only renders minimum identity and can be abandoned", %{
      conn: conn,
      prof_token: token
    } do
      {:ok, view, html} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      assert html =~ "Mario"
      assert html =~ "35111222"

      for private <- ["private-phone", "private-email", "private-activity"],
          do: refute(html =~ private)

      view |> element("#patient-related") |> render_click()
      assert has_element?(view, "#selected-patient", "Mario")
      view |> element("#clear-patient-selection") |> render_click()
      refute has_element?(view, "#selected-patient")
      assert has_element?(view, "#patient-selection-next[disabled]")
    end

    test "exact DNI supports invalid, missing, found and tab reset states", %{
      conn: conn,
      prof_token: token
    } do
      {:ok, view, _} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      view |> element("#tab-dni") |> render_click()
      assert has_element?(view, "#tab-dni[aria-selected='true']")
      html = view |> form("#patient-dni-form", %{dni: "123"}) |> render_submit()
      assert html =~ "Revisá el DNI ingresado"
      html = view |> form("#patient-dni-form", %{dni: "99999999"}) |> render_submit()
      assert html =~ "No se encontró un paciente registrado"
      html = view |> form("#patient-dni-form", %{dni: "35.333.444"}) |> render_submit()
      assert html =~ "Luigi"
      refute html =~ "private-email"
      view |> element("#patient-exact") |> render_click()
      assert has_element?(view, "#selected-patient", "Luigi")
      view |> element("#tab-related") |> render_click()
      refute has_element?(view, "#selected-patient")
      refute has_element?(view, "#patient-exact")
      html = render_click(view, "select_patient", %{"id" => "forged"})
      assert html =~ "La selección no es válida"
      refute has_element?(view, "#selected-patient")
    end

    test "unavailable backend is explicit and never fabricates patients", %{
      conn: conn,
      prof_token: token
    } do
      Application.delete_env(:origen, :professional_patient_selector)
      {:ok, view, html} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      assert html =~ "La selección de pacientes todavía no está disponible"
      refute has_element?(view, "[phx-click='select_patient']")
      assert has_element?(view, "#patient-selection-next[disabled]")
    end

    test "patient view retains professional-only access", %{conn: conn, sec_token: token} do
      assert get(conn, ~p"/profesional/agenda/crear").status == 401
      assert get(put_internal_session(conn, token), ~p"/profesional/agenda/crear").status == 403
    end
  end

  describe "development visual mock (#315)" do
    setup do
      old_adapter = Application.get_env(:origen, :professional_patient_selector)
      old_dev = Application.get_env(:origen, :dev_routes)

      Application.put_env(
        :origen,
        :professional_patient_selector,
        OrigenWeb.ProfessionalPatientSelectorDemo
      )

      Application.put_env(:origen, :dev_routes, true)

      on_exit(fn ->
        for {key, value} <- [professional_patient_selector: old_adapter, dev_routes: old_dev] do
          if is_nil(value),
            do: Application.delete_env(:origen, key),
            else: Application.put_env(:origen, key, value)
        end
      end)

      :ok
    end

    test "shows two fictional related patients and exact search", %{
      conn: conn,
      prof_token: token
    } do
      {:ok, view, html} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      assert has_element?(view, "#patient-demo-notice", "Datos ficticios")
      assert html =~ "Ana"
      assert html =~ "Martín"
      assert has_element?(view, "#patient-demo-ana")
      assert has_element?(view, "#patient-demo-martin")
      view |> element("#patient-demo-ana") |> render_click()
      assert has_element?(view, "#selected-patient", "Ana")
      assert has_element?(view, "#patient-selection-next:not([disabled])")
      view |> element("#tab-dni") |> render_click()
      html = view |> form("#patient-dni-form", %{dni: "30.111.222"}) |> render_submit()
      assert html =~ "Ana"
      refute html =~ "Martín"
      html = view |> form("#patient-dni-form", %{dni: "30111"}) |> render_submit()
      assert html =~ "Revisá el DNI"
      html = view |> form("#patient-dni-form", %{dni: "99999999"}) |> render_submit()
      assert html =~ "No se encontró un paciente registrado"
    end

    test "demo walks through all four steps and ends with an explicitly simulated result", %{
      conn: conn,
      prof_token: token
    } do
      {:ok, view, _} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      assert has_element?(view, "#booking-step-1[aria-current='step']", "Paciente")
      refute has_element?(view, "#booking-progress button")
      refute has_element?(view, "#booking-progress [phx-click]")
      assert has_element?(view, "#booking-progress ol > li", "Paciente")
      assert has_element?(view, "#booking-step-1[data-state='current']")
      assert has_element?(view, "#booking-step-2[data-state='pending']")
      assert has_element?(view, "#patient-selection-next[disabled]")
      view |> element("#patient-demo-ana") |> render_click()
      view |> element("#patient-selection-next") |> render_click()
      assert has_element?(view, "#booking-step-2[aria-current='step']", "Consulta")
      assert has_element?(view, "#booking-progress", "Paso 2 de 4")
      assert has_element?(view, "#consultation-demo-initial", "45 minutos")
      assert has_element?(view, "#consultation-next[disabled]")
      view |> element("#consultation-demo-initial") |> render_click()
      view |> element("#consultation-next") |> render_click()
      assert has_element?(view, "#booking-step-3[aria-current='step']", "Fecha y horario")
      assert has_element?(view, "#slot-next[disabled]")
      view |> element("#slot-0900") |> render_click()
      view |> element("#slot-next") |> render_click()
      assert has_element?(view, "#booking-step-4[aria-current='step']", "Confirmación")
      assert has_element?(view, "#booking-summary", "Ana Ejemplo")
      assert has_element?(view, "#booking-summary", "30111222")
      assert has_element?(view, "#booking-summary", "Consulta inicial")
      assert has_element?(view, "#booking-summary", "09:00")
      view |> element("#simulate-booking") |> render_click()
      assert has_element?(view, "#booking-demo-result", "No se creó ningún turno")
      refute has_element?(view, "#simulate-booking")
      assert has_element?(view, "#booking-step-4", "✓")
    end

    test "back preserves selections but changing consultation or patient invalidates later steps",
         %{conn: conn, prof_token: token} do
      {:ok, view, _} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      view |> element("#patient-demo-ana") |> render_click()
      view |> element("#patient-selection-next") |> render_click()
      view |> element("#consultation-demo-initial") |> render_click()
      view |> element("#consultation-next") |> render_click()
      view |> element("#slot-0900") |> render_click()
      view |> element("#slot-next") |> render_click()
      view |> element("button[phx-click='go_booking_step'][phx-value-step='3']") |> render_click()
      assert has_element?(view, "#slot-0900[aria-pressed='true']")
      view |> element("button[phx-click='go_booking_step'][phx-value-step='2']") |> render_click()
      view |> element("#consultation-demo-followup") |> render_click()
      view |> element("#consultation-next") |> render_click()
      refute has_element?(view, "#slot-0900[aria-pressed='true']")
      assert has_element?(view, "#slot-next[disabled]")
      view |> element("button[phx-click='go_booking_step'][phx-value-step='2']") |> render_click()
      view |> element("button[phx-click='go_booking_step'][phx-value-step='1']") |> render_click()
      view |> element("#patient-demo-martin") |> render_click()
      view |> element("#patient-selection-next") |> render_click()
      assert has_element?(view, "#consultation-next[disabled]")
      assert has_element?(view, "#booking-step-3[data-state='pending']")
    end

    test "cannot skip steps or use forged selections and changing date clears the selected slot",
         %{conn: conn, prof_token: token} do
      {:ok, view, _} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      render_click(view, "go_booking_step", %{"step" => "4"})
      render_click(view, "simulate_booking", %{})
      assert has_element?(view, "#booking-step-1[aria-current='step']")
      refute has_element?(view, "#booking-demo-result")
      view |> element("#patient-demo-ana") |> render_click()
      view |> element("#patient-selection-next") |> render_click()
      render_click(view, "select_consultation", %{"id" => "foreign"})
      assert has_element?(view, "#consultation-next[disabled]")
      view |> element("#consultation-demo-initial") |> render_click()
      view |> element("#consultation-next") |> render_click()
      render_click(view, "select_booking_slot", %{"id" => "foreign"})
      assert has_element?(view, "#slot-next[disabled]")
      view |> element("#slot-0900") |> render_click()

      view
      |> form("#booking-date-form", %{date: Date.to_iso8601(Date.add(Date.utc_today(), 1))})
      |> render_change()

      assert has_element?(view, "#slot-next[disabled]")
      html = view |> form("#booking-date-form", %{date: "invalid"}) |> render_change()
      assert html =~ "Revisá la fecha"
      refute has_element?(view, "#slot-0900")
    end

    test "search-only demo patient is found by exact DNI but never added to related list", %{
      conn: conn,
      prof_token: token
    } do
      conn = put_internal_session(conn, token)
      {:ok, view, html} = live(conn, ~p"/profesional/agenda/crear")
      refute html =~ "Lucía"
      refute html =~ "99000123"
      assert has_element?(view, "#patient-demo-ana")
      assert has_element?(view, "#patient-demo-martin")
      view |> element("#tab-dni") |> render_click()
      html = view |> form("#patient-dni-form", %{dni: "9900012"}) |> render_submit()
      assert html =~ "No se encontró un paciente registrado"
      refute html =~ "Lucía"
      html = view |> form("#patient-dni-form", %{dni: "99000123"}) |> render_submit()
      assert html =~ "Lucía Ejemplo"
      assert html =~ "99000123"
      refute html =~ "Ana"
      refute html =~ "Martín"
      view |> element("#patient-demo-search-only") |> render_click()
      assert has_element?(view, "#selected-patient", "Lucía Ejemplo")
      view |> element("#patient-selection-next") |> render_click()
      view |> element("#consultation-demo-initial") |> render_click()
      view |> element("#consultation-next") |> render_click()
      view |> element("#slot-0900") |> render_click()
      view |> element("#slot-next") |> render_click()
      assert has_element?(view, "#booking-summary", "Lucía Ejemplo")
      view |> element("#simulate-booking") |> render_click()
      assert has_element?(view, "#booking-demo-result", "No se creó ningún turno")
      {:ok, fresh, html} = live(conn, ~p"/profesional/agenda/crear")
      refute html =~ "Lucía"
      refute html =~ "99000123"
      refute has_element?(fresh, "#patient-demo-search-only")
    end

    test "consultation options show their catalog price and color without losing selection", %{
      conn: conn,
      prof_token: token
    } do
      {:ok, view, _} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      view |> element("#patient-demo-ana") |> render_click()
      view |> element("#patient-selection-next") |> render_click()
      assert has_element?(view, "#consultation-demo-initial", "ARS 25.000,00")
      assert has_element?(view, "#consultation-demo-initial", "45 minutos")
      assert has_element?(view, "#consultation-demo-followup", "ARS 18.000,00")
      assert has_element?(view, "#consultation-demo-followup", "30 minutos")

      assert has_element?(
               view,
               "#consultation-color-demo-initial[style='background-color: #0A7C86']"
             )

      assert has_element?(
               view,
               "#consultation-color-demo-followup[style='background-color: #7C3AED']"
             )

      view |> element("#consultation-demo-followup") |> render_click()

      assert has_element?(
               view,
               "#consultation-demo-followup[aria-pressed='true']",
               "ARS 18.000,00"
             )

      assert has_element?(view, "#consultation-demo-initial", "ARS 25.000,00")
      view |> element("#consultation-next") |> render_click()
      view |> element("#slot-0900") |> render_click()
      view |> element("#slot-next") |> render_click()
      assert has_element?(view, "#booking-summary", "ARS 18.000,00")
    end

    test "demo is unavailable without development routes enabled", %{
      conn: conn,
      prof_token: token
    } do
      Application.put_env(:origen, :dev_routes, false)
      {:ok, view, html} = live(put_internal_session(conn, token), ~p"/profesional/agenda/crear")
      assert html =~ "La selección de pacientes todavía no está disponible"
      refute has_element?(view, "#patient-demo-ana")
      refute has_element?(view, "#patient-demo-notice")
    end
  end

  describe "autenticación y autorización (Issue #80)" do
    test "usuario no autenticado es rechazado con 401", %{conn: conn} do
      conn = get(conn, ~p"/profesional/agenda")
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "usuario con rol secretaria es rechazado con 403", %{conn: conn, sec_token: sec_token} do
      conn =
        conn
        |> put_internal_session(sec_token)
        |> get(~p"/profesional/agenda")

      assert conn.status == 403
      assert conn.resp_body == "Forbidden"
    end

    test "usuario con rol administrador es rechazado con 403", %{
      conn: conn,
      admin_token: admin_token
    } do
      conn =
        conn
        |> put_internal_session(admin_token)
        |> get(~p"/profesional/agenda")

      assert conn.status == 403
      assert conn.resp_body == "Forbidden"
    end

    test "profesional autenticado accede exitosamente a la agenda", %{
      conn: conn,
      prof_token: prof_token
    } do
      conn = put_internal_session(conn, prof_token)
      {:ok, _view, html} = live(conn, ~p"/profesional/agenda")

      assert html =~ "Agenda Diaria"
      assert html =~ "Hoy"
      assert html =~ "aria-label=\"Día anterior\""
      assert html =~ "aria-label=\"Día siguiente\""
    end
  end

  describe "visualización cronológica de turnos y estados (Issue #80)" do
    test "muestra los turnos en orden cronológico con paciente no clínico y tipo", %{
      conn: conn,
      prof_token: prof_token,
      professional_id: prof_id,
      patient_1: p1,
      patient_2: p2
    } do
      # Insertar turno 1: 11:00 a 11:30
      insert_appointment!(
        prof_id,
        p2.profile_id,
        ~U[2026-10-15 11:00:00Z],
        ~U[2026-10-15 11:30:00Z],
        "confirmed"
      )

      # Insertar turno 2: 09:00 a 09:30 (más temprano)
      insert_appointment!(
        prof_id,
        p1.profile_id,
        ~U[2026-10-15 09:00:00Z],
        ~U[2026-10-15 09:30:00Z],
        "reserved"
      )

      conn = put_internal_session(conn, prof_token)
      {:ok, view, html} = live(conn, ~p"/profesional/agenda?date=2026-10-15")

      assert html =~ "Agenda Diaria"
      assert html =~ "Mario Bros"
      assert html =~ "Luigi Bros"
      assert html =~ "Consulta General"
      assert html =~ "Reservado"
      assert html =~ "Confirmado"
      assert html =~ "Tel: +5491144445555"
      assert html =~ "DNI: 35111222"

      # Validar orden cronológico: 09:00 debe aparecer antes que 11:00 en el HTML
      pos_first = :binary.match(html, "09:00 - 09:30") |> elem(0)
      pos_second = :binary.match(html, "11:00 - 11:30") |> elem(0)
      assert pos_first < pos_second

      # Elementos de lista accesibles
      assert has_element?(view, "#agenda-appointments-list")
    end

    test "muestra estado de agenda vacía cuando no hay turnos", %{
      conn: conn,
      prof_token: prof_token
    } do
      conn = put_internal_session(conn, prof_token)
      {:ok, view, html} = live(conn, ~p"/profesional/agenda?date=2026-11-20")

      assert has_element?(view, "#agenda-empty-state")
      assert html =~ "No hay turnos programados"
      assert html =~ "No se encontraron turnos para esta fecha"
      refute has_element?(view, "#agenda-appointments-list")
    end

    test "muestra estado de error ante fecha inválida", %{
      conn: conn,
      prof_token: prof_token
    } do
      conn = put_internal_session(conn, prof_token)
      {:ok, view, html} = live(conn, ~p"/profesional/agenda?date=invalida")

      assert has_element?(view, "#agenda-error-state")
      assert html =~ "Fecha no válida"
      assert has_element?(view, "button[phx-click='retry']")
    end
  end

  describe "navegación de fechas e interacción con teclado (Issue #80)" do
    test "navega al día siguiente y al día anterior mediante eventos de botones accesibles", %{
      conn: conn,
      prof_token: prof_token,
      professional_id: prof_id,
      patient_1: p1
    } do
      # Turno en 2026-10-16
      insert_appointment!(
        prof_id,
        p1.profile_id,
        ~U[2026-10-16 10:00:00Z],
        ~U[2026-10-16 10:30:00Z],
        "reserved"
      )

      conn = put_internal_session(conn, prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda?date=2026-10-15")

      # Inicialmente vacío en 2026-10-15
      assert has_element?(view, "#agenda-empty-state")

      # Clic en día siguiente (botón accesible con aria-label)
      view
      |> element("button[aria-label='Día siguiente']")
      |> render_click()

      assert_patch(view, ~p"/profesional/agenda?date=2026-10-16")
      assert render(view) =~ "10:00 - 10:30"
      assert render(view) =~ "Mario Bros"

      # Clic en día anterior
      view
      |> element("button[aria-label='Día anterior']")
      |> render_click()

      assert_patch(view, ~p"/profesional/agenda?date=2026-10-15")
      assert has_element?(view, "#agenda-empty-state")
    end

    test "cambio directo de fecha mediante selector date input", %{
      conn: conn,
      prof_token: prof_token,
      professional_id: prof_id,
      patient_1: p1
    } do
      insert_appointment!(
        prof_id,
        p1.profile_id,
        ~U[2026-12-01 14:00:00Z],
        ~U[2026-12-01 14:30:00Z],
        "reserved"
      )

      conn = put_internal_session(conn, prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda?date=2026-10-15")

      # Cambio de fecha vía formulario/input
      render_change(view, "change_date", %{"date" => "2026-12-01"})

      assert_patch(view, ~p"/profesional/agenda?date=2026-12-01")
      assert render(view) =~ "14:00 - 14:30"
      assert render(view) =~ "Mario Bros"
    end

    test "botón Hoy regresa al día actual", %{
      conn: conn,
      prof_token: prof_token
    } do
      conn = put_internal_session(conn, prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda?date=2026-10-15")

      view
      |> element("#btn-today-nav")
      |> render_click()

      today = Date.to_iso8601(Date.utc_today())
      assert_patch(view, ~p"/profesional/agenda?date=#{today}")
    end
  end

  describe "resolución de solicitudes de turno (#323)" do
    test "C11: muestra botones de aceptar y rechazar exclusivamente para turnos en estado requested",
         ctx do
      today = Date.utc_today()
      start_1 = DateTime.new!(today, ~T[09:00:00], "Etc/UTC")
      end_1 = DateTime.new!(today, ~T[09:30:00], "Etc/UTC")

      insert_appointment!(
        ctx.professional_id,
        ctx.patient_1.profile_id,
        start_1,
        end_1,
        "requested"
      )

      start_2 = DateTime.new!(today, ~T[10:00:00], "Etc/UTC")
      end_2 = DateTime.new!(today, ~T[10:30:00], "Etc/UTC")

      insert_appointment!(
        ctx.professional_id,
        ctx.patient_2.profile_id,
        start_2,
        end_2,
        "confirmed"
      )

      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      # El turno solicitado muestra badge Solicitado y botones de acción
      assert has_element?(view, ".border-indigo-200", "Solicitado")
      assert has_element?(view, "button[phx-click='accept_request']", "Aceptar")
      assert has_element?(view, "button[phx-click='reject_request']", "Rechazar")

      # El turno confirmado muestra badge Confirmado
      assert has_element?(view, ".border-emerald-200", "Confirmado")
    end

    test "C12: al hacer clic en Aceptar, confirma la solicitud reactivamente", ctx do
      today = Date.utc_today()
      start_1 = DateTime.new!(today, ~T[11:00:00], "Etc/UTC")
      end_1 = DateTime.new!(today, ~T[11:30:00], "Etc/UTC")

      insert_appointment!(
        ctx.professional_id,
        ctx.patient_1.profile_id,
        start_1,
        end_1,
        "requested"
      )

      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      view
      |> element("button[phx-click='accept_request']", "Aceptar")
      |> render_click()

      assert has_element?(view, ".border-emerald-200", "Confirmado")
      refute has_element?(view, "button[phx-click='accept_request']")
    end

    test "C12: al hacer clic en Rechazar, cancela la solicitud y libera el slot", ctx do
      today = Date.utc_today()
      start_1 = DateTime.new!(today, ~T[14:00:00], "Etc/UTC")
      end_1 = DateTime.new!(today, ~T[14:30:00], "Etc/UTC")

      insert_appointment!(
        ctx.professional_id,
        ctx.patient_1.profile_id,
        start_1,
        end_1,
        "requested"
      )

      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      view
      |> element("button[phx-click='reject_request']", "Rechazar")
      |> render_click()

      assert has_element?(view, ".border-rose-200", "Cancelado")
      refute has_element?(view, "button[phx-click='reject_request']")
    end

    test "C13: un ID malformado no tumba la vista y muestra un error claro sin filtrar términos internos",
         ctx do
      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      html = render_click(view, "accept_request", %{"id" => "invalid-id"})

      assert html =~ "El identificador del turno no es válido."
      refute html =~ "inspect"
      refute html =~ ":invalid_id"

      # El proceso LiveView sigue vivo y operativo
      assert render(view) =~ "Agenda Diaria"
    end

    test "C14: un error de resolución mapea a mensaje claro y recarga la agenda", ctx do
      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      html = render_click(view, "reject_request", %{"id" => "999999"})

      assert html =~ "El turno solicitado no fue encontrado."
      refute html =~ "inspect"
      refute html =~ ":appointment_not_found"
      assert render(view) =~ "Agenda Diaria"
    end

    test "C15: permite configurar modalidad y subconfiguración de Secretaría preservando pendientes y mostrando el aviso de alcance",
         ctx do
      today = Date.utc_today()
      start_1 = DateTime.new!(today, ~T[15:00:00], "Etc/UTC")
      end_1 = DateTime.new!(today, ~T[15:30:00], "Etc/UTC")

      insert_appointment!(
        ctx.professional_id,
        ctx.patient_1.profile_id,
        start_1,
        end_1,
        "requested"
      )

      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      assert has_element?(view, "#approval-config-panel")
      assert has_element?(view, "#approval-config-form")
      assert has_element?(view, "#select-approval-mode")
      assert has_element?(view, "#select-secretary-approval-mode")

      assert has_element?(
               view,
               "#approval-mode-notice",
               "El cambio de modalidad aplica únicamente a reservas nuevas y no resuelve automáticamente las solicitudes pendientes existentes."
             )

      html =
        view
        |> form("#approval-config-form", %{
          "approval_mode" => "manual",
          "secretary_approval_mode" => "requested"
        })
        |> render_change()

      assert html =~
               "Configuración de aprobación actualizada. Las solicitudes pendientes existentes conservan su estado."

      assert {:ok, %{approval_mode: :manual, secretary_approval_mode: :requested}} =
               Origen.Booking.get_approval_configuration(ctx.professional_id)

      # La solicitud pendiente previa sigue en estado Solicitado sin resolverse automáticamente
      assert has_element?(view, ".border-indigo-200", "Solicitado")
      assert has_element?(view, "button[phx-click='accept_request']", "Aceptar")
    end

    test "C16: un valor inválido en la configuración de aprobación muestra un error claro sin romper la vista",
         ctx do
      conn = put_internal_session(ctx.conn, ctx.prof_token)
      {:ok, view, _html} = live(conn, ~p"/profesional/agenda")

      html =
        render_change(view, "update_approval_config", %{
          "approval_mode" => "invalid_mode",
          "secretary_approval_mode" => "confirmed"
        })

      assert html =~ "La modalidad de aprobación seleccionada no es válida."
      refute html =~ "inspect"
      refute html =~ ":invalid_approval_mode"
    end
  end

  # Helpers para fixtures

  defp put_internal_session(conn, token) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp insert_internal_account(email, role) do
    {:ok, %{rows: [[account_id]]}} =
      SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES ($1, $2, 'active', 'hashed_pass_placeholder', decode('010203', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [email, role]
      )

    account_id
  end

  defp insert_agenda_settings(owner_account_id) do
    {:ok, _} =
      SQL.query(
        Repo,
        """
        INSERT INTO public.agenda_settings (owner_account_id, interval_minutes, created_at, updated_at)
        VALUES ($1, 30, clock_timestamp(), clock_timestamp())
        ON CONFLICT (owner_account_id) DO NOTHING
        """,
        [owner_account_id]
      )

    :ok
  end

  defp insert_consultation_type(owner_account_id) do
    {:ok, _} =
      SQL.query(
        Repo,
        """
        INSERT INTO public.consultation_types (
          id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at
        ) VALUES (
          $1, $2, 'Consulta General', 15000.50, '#112233', 1, 'active', clock_timestamp(), clock_timestamp()
        )
        ON CONFLICT (id) DO NOTHING
        """,
        [Ecto.UUID.dump!(@consultation_type_id), owner_account_id]
      )

    :ok
  end

  defp insert_patient_profile(first_name, last_name, doc_type, doc_num, phone) do
    unique = System.unique_integer([:positive])

    {:ok, %{rows: [[persona_id]]}} =
      SQL.query(
        Repo,
        """
        INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
        VALUES ($1, $2, $3, $4, '1990-01-01', clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [first_name, last_name, doc_type, doc_num]
      )

    {:ok, %{rows: [[profile_id]]}} =
      SQL.query(
        Repo,
        """
        INSERT INTO public.patient_profiles (persona_id, email, state, phone, phone_verified, created_at, updated_at)
        VALUES ($1, $2, 'completed', $3, true, clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [persona_id, "patient_#{unique}@example.com", phone]
      )

    %{profile_id: profile_id, persona_id: persona_id}
  end

  defp insert_appointment!(prof_id, patient_id, start_time, end_time, status) do
    {:ok, _} =
      SQL.query(
        Repo,
        """
        INSERT INTO public.appointments (
          patient_profile_id, professional_account_id, consultation_type_id,
          start_time, end_time, status,
          snapshot_consultation_type_name, snapshot_duration_minutes, snapshot_exact_price_ars,
          created_at, updated_at
        ) VALUES (
          $1, $2, $3,
          $4, $5, $6,
          'Consulta General', 30, 15000.50,
          clock_timestamp(), clock_timestamp()
        )
        """,
        [
          patient_id,
          prof_id,
          Ecto.UUID.dump!(@consultation_type_id),
          start_time,
          end_time,
          status
        ]
      )

    :ok
  end
end
