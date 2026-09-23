defmodule Origen.Booking.AgendaPrivacyRegressionTest do
  @moduledoc """
  Suite de regresión durable de seguridad y privacidad para la agenda del Profesional
  (PLN-10 / Issue #81).

  Verifica:
  1. Aislamiento horizontal estricto entre profesionales (A jamás ve turnos de B).
  2. Inmunidad ante manipulación de parámetros (IDOR / BOLA / parameter tampering).
  3. Aislamiento vertical estricto (rechazo de secretarías, administradores, pacientes y anónimos).
  4. Minimización de datos (no exposición de información clínica ni credenciales internas).
  5. Aislamiento en el canal Phoenix LiveView.
  """

  use OrigenWeb.LiveViewCase
  import Phoenix.LiveViewTest

  alias Origen.Booking
  alias Origen.Repo
  alias Origen.Sessions

  @consultation_type_id "e5b8c9d0-1234-4567-89ab-cdef01234567"
  @test_date ~D[2026-10-20]

  setup do
    # Dos profesionales distintos
    prof_a_id = insert_internal_account("prof_a", "professional")
    prof_b_id = insert_internal_account("prof_b", "professional")

    :ok = insert_consultation_type(prof_a_id)
    :ok = insert_consultation_type(prof_b_id)

    # Otros roles
    secretary_id = insert_internal_account("sec", "secretary")
    admin_id = insert_internal_account("admin", "administrator")

    # Pacientes
    patient_a = insert_patient_profile("Paciente", "DeProfA", "dni", "40111111", "+5491111111111")
    patient_b = insert_patient_profile("Paciente", "DeProfB", "dni", "40222222", "+5491122222222")

    # Sesiones activas
    {:ok, %{token: token_a, session: session_a}} = Sessions.create_session(prof_a_id)
    {:ok, %{token: token_b, session: session_b}} = Sessions.create_session(prof_b_id)
    {:ok, %{token: token_sec, session: session_sec}} = Sessions.create_session(secretary_id)
    {:ok, %{token: token_admin, session: session_admin}} = Sessions.create_session(admin_id)

    # Turno Profesional A (09:00 a 09:30)
    appt_a_id =
      insert_appointment!(
        prof_a_id,
        patient_a.profile_id,
        ~U[2026-10-20 09:00:00Z],
        ~U[2026-10-20 09:30:00Z],
        "confirmed",
        "Consulta Prof A"
      )

    # Turno Profesional B (09:00 a 09:30 - mismo horario pero de B)
    appt_b_id =
      insert_appointment!(
        prof_b_id,
        patient_b.profile_id,
        ~U[2026-10-20 09:00:00Z],
        ~U[2026-10-20 09:30:00Z],
        "reserved",
        "Consulta Prof B"
      )

    %{
      prof_a_id: prof_a_id,
      prof_b_id: prof_b_id,
      secretary_id: secretary_id,
      admin_id: admin_id,
      session_a: session_a,
      session_b: session_b,
      session_sec: session_sec,
      session_admin: session_admin,
      token_a: token_a,
      token_b: token_b,
      token_sec: token_sec,
      token_admin: token_admin,
      patient_a: patient_a,
      patient_b: patient_b,
      appt_a_id: appt_a_id,
      appt_b_id: appt_b_id
    }
  end

  describe "Criterio 1: Aislamiento horizontal estricto entre profesionales" do
    test "Profesional A no puede ver turnos de Profesional B y viceversa", ctx do
      {:ok, agenda_a} = Booking.get_professional_agenda(ctx.session_a, %{date: @test_date})
      assert length(agenda_a.appointments) == 1
      [item_a] = agenda_a.appointments
      assert item_a.id == ctx.appt_a_id
      assert item_a.consultation_type_name == "Consulta Prof A"
      assert item_a.patient.name == "Paciente DeProfA"
      refute Enum.any?(agenda_a.appointments, &(&1.id == ctx.appt_b_id))

      {:ok, agenda_b} = Booking.get_professional_agenda(ctx.session_b, %{date: @test_date})
      assert length(agenda_b.appointments) == 1
      [item_b] = agenda_b.appointments
      assert item_b.id == ctx.appt_b_id
      assert item_b.consultation_type_name == "Consulta Prof B"
      assert item_b.patient.name == "Paciente DeProfB"
      refute Enum.any?(agenda_b.appointments, &(&1.id == ctx.appt_a_id))
    end

    test "inyección de parámetros en el cliente no puede alterar el profesional consultado",
         ctx do
      tampered_payloads = [
        %{"professional_id" => ctx.prof_b_id, "date" => @test_date},
        %{"professional_account_id" => ctx.prof_b_id, "date" => @test_date},
        %{"account_id" => ctx.prof_b_id, "date" => @test_date},
        %{"owner_account_id" => ctx.prof_b_id, "date" => @test_date},
        %{"user_id" => ctx.prof_b_id, "date" => @test_date},
        %{professional_id: ctx.prof_b_id, date: @test_date},
        %{professional_account_id: ctx.prof_b_id, date: @test_date},
        %{account_id: ctx.prof_b_id, date: @test_date}
      ]

      for payload <- tampered_payloads do
        {:ok, agenda} = Booking.get_professional_agenda(ctx.session_a, payload)

        assert agenda.professional_account_id == ctx.prof_a_id
        assert length(agenda.appointments) == 1
        assert hd(agenda.appointments).id == ctx.appt_a_id
        refute Enum.any?(agenda.appointments, &(&1.id == ctx.appt_b_id))
      end
    end

    test "suplantación de session_id o account_id en el principal falla cerrado", ctx do
      # Sesión de A reclamando account_id de B
      fake_principal = %{session_id: ctx.session_a.session_id, account_id: ctx.prof_b_id}

      assert Booking.get_professional_agenda(fake_principal, %{date: @test_date}) ==
               {:error, :unauthorized}

      # Sesión de B reclamando account_id de A
      fake_principal_rev = %{session_id: ctx.session_b.session_id, account_id: ctx.prof_a_id}

      assert Booking.get_professional_agenda(fake_principal_rev, %{date: @test_date}) ==
               {:error, :unauthorized}

      # session_id inexistente
      assert Booking.get_professional_agenda(
               %{session_id: 999_999, account_id: ctx.prof_a_id},
               %{date: @test_date}
             ) == {:error, :unauthorized}
    end
  end

  describe "Criterio 2: Aislamiento vertical estricto frente a otros roles" do
    test "secretaría autenticada no puede consultar la agenda privada del profesional en backend",
         ctx do
      assert Booking.get_professional_agenda(ctx.session_sec, %{date: @test_date}) ==
               {:error, :unauthorized}
    end

    test "administrador autenticado no puede consultar la agenda privada del profesional en backend",
         ctx do
      assert Booking.get_professional_agenda(ctx.session_admin, %{date: @test_date}) ==
               {:error, :unauthorized}
    end

    test "paciente o llamada no autenticada es rechazada", ctx do
      assert Booking.get_professional_agenda(nil, %{date: @test_date}) == {:error, :unauthorized}
      assert Booking.get_professional_agenda(%{}, %{date: @test_date}) == {:error, :unauthorized}

      assert Booking.get_professional_agenda(%{role: :patient, id: ctx.patient_a.profile_id}, %{
               date: @test_date
             }) == {:error, :unauthorized}
    end

    test "sesión revocada o cuenta inactiva es rechazada inmediatamente", ctx do
      {:ok, %{token: revokable_token, session: revokable_session}} =
        Sessions.create_session(ctx.prof_a_id)

      :ok = Sessions.terminate_session(revokable_token)

      assert Booking.get_professional_agenda(revokable_session, %{date: @test_date}) ==
               {:error, :unauthorized}
    end

    test "barrera HTTP/LiveView rechaza roles no profesionales en /profesional/agenda",
         %{
           conn: conn
         } = ctx do
      # Anónimo -> 401
      anon_conn = get(conn, ~p"/profesional/agenda")
      assert anon_conn.status == 401
      assert anon_conn.resp_body == "Unauthorized"

      # Secretaría -> 403
      sec_conn =
        conn
        |> put_internal_session(ctx.token_sec)
        |> get(~p"/profesional/agenda")

      assert sec_conn.status == 403
      assert sec_conn.resp_body == "Forbidden"

      # Administrador -> 403
      admin_conn =
        conn
        |> put_internal_session(ctx.token_admin)
        |> get(~p"/profesional/agenda")

      assert admin_conn.status == 403
      assert admin_conn.resp_body == "Forbidden"
    end
  end

  describe "Criterio 3: No exposición de datos clínicos ni información sensible" do
    test "la proyección del turno contiene exclusivamente campos operativos permitidos", ctx do
      {:ok, agenda} = Booking.get_professional_agenda(ctx.session_a, %{date: @test_date})
      [appt] = agenda.appointments

      # Campos autorizados de nivel raíz
      allowed_appt_keys = [
        :consultation_type_name,
        :duration_minutes,
        :end_time,
        :id,
        :patient,
        :price_ars,
        :start_time,
        :status
      ]

      assert Enum.sort(Map.keys(appt)) == allowed_appt_keys

      # Campos autorizados del paciente
      allowed_patient_keys = [
        :document_number,
        :document_type,
        :email,
        :first_name,
        :id,
        :last_name,
        :name,
        :phone
      ]

      assert Enum.sort(Map.keys(appt.patient)) == allowed_patient_keys

      # Comprobar ausencia de campos clínicos o internos
      forbidden_substrings = [
        "clinical",
        "diagnosis",
        "notes",
        "history",
        "password",
        "secret",
        "hash",
        "token"
      ]

      for key <- Map.keys(appt) ++ Map.keys(appt.patient) do
        key_str = to_string(key)

        for forbidden <- forbidden_substrings do
          refute String.contains?(key_str, forbidden),
                 "El campo '#{key_str}' viola la minimización de datos clínicos/sensibles"
        end
      end
    end
  end

  describe "Criterio 4: Aislamiento verificado en el canal LiveView" do
    test "Profesional A visualiza exclusivamente sus turnos en la UI y nunca los de B",
         %{
           conn: conn
         } = ctx do
      conn = put_internal_session(conn, ctx.token_a)
      {:ok, view, html} = live(conn, ~p"/profesional/agenda?date=2026-10-20")

      # Visualiza su turno
      assert html =~ "Consulta Prof A"
      assert html =~ "Paciente DeProfA"
      assert has_element?(view, "#appointment-#{ctx.appt_a_id}")

      # Jamás visualiza el turno de B
      refute html =~ "Consulta Prof B"
      refute html =~ "Paciente DeProfB"
      refute has_element?(view, "#appointment-#{ctx.appt_b_id}")

      # Manipulación de formulario en cliente con parámetro espurio
      render_change(view, "change_date", %{
        "date" => "2026-10-20",
        "professional_id" => to_string(ctx.prof_b_id)
      })

      updated_html = render(view)
      assert updated_html =~ "Consulta Prof A"
      refute updated_html =~ "Consulta Prof B"
    end
  end

  # Helpers para fixtures

  defp put_internal_session(conn, token) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp insert_internal_account(prefix, role) do
    unique = System.unique_integer([:positive])
    email = "#{prefix}_#{unique}@example.com"

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

  defp insert_appointment!(prof_id, patient_id, start_time, end_time, status, type_name) do
    {:ok, %{rows: [[appt_id]]}} =
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
          $7, 30, 15000.50,
          clock_timestamp(), clock_timestamp()
        )
        RETURNING id
        """,
        [
          patient_id,
          prof_id,
          Ecto.UUID.dump!(@consultation_type_id),
          start_time,
          end_time,
          status,
          type_name
        ]
      )

    appt_id
  end
end
