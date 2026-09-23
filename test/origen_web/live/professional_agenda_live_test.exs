defmodule OrigenWeb.ProfessionalAgendaLiveTest do
  @moduledoc """
  Pruebas de integración para la vista LiveView de la agenda diaria del Profesional
  (Issue #80 / PLN-10).
  """

  use OrigenWeb.LiveViewCase

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

  # Helpers para fixtures

  defp put_internal_session(conn, token) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp insert_internal_account(email, role) do
    {:ok, %{rows: [[account_id]]}} =
      Ecto.Adapters.SQL.query(
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
      Ecto.Adapters.SQL.query(
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
      Ecto.Adapters.SQL.query(
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
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
        VALUES ($1, $2, $3, $4, '1990-01-01', clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [first_name, last_name, doc_type, doc_num]
      )

    {:ok, %{rows: [[profile_id]]}} =
      Ecto.Adapters.SQL.query(
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
      Ecto.Adapters.SQL.query(
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
