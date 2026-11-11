defmodule OrigenWeb.InternalAccountsIntegrationTest do
  @moduledoc """
  End-to-end integration and verification suite for Issue #375 (parent #279):
  Internal staff account lifecycle (contract #372, backend #373, frontend #374).

  Verifies real database operations, real Phoenix LiveView, real session termination,
  real appointment preservation, future affected appointments count calculation
  without operational data leaks, immediate new booking cutoff across all three
  channels (Patient autonomous, Secretary assisted, Professional own), and reactivation
  without restoring cancelled appointments.
  """

  use OrigenWeb.LiveViewCase, async: false

  alias Origen.{
    Accounts,
    Appointments.AssistedBooking,
    Appointments.BookingService,
    Appointments.DatabaseCalendar,
    Booking,
    Booking.Appointment,
    Booking.ProfessionalPatientRelationship,
    ConsultationTypes.DatabaseCatalog,
    Patients,
    Patients.PatientProfile,
    Patients.Persona,
    Repo,
    Sessions
  }

  @accounts_path "/administrador/cuentas"

  setup do
    previous_calendar = Application.get_env(:origen, :appointments_calendar_adapter)
    previous_catalog = Application.get_env(:origen, :consultation_type_catalog_adapter)
    previous_context = Application.get_env(:origen, :admin_internal_accounts_context)

    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)
    Application.put_env(:origen, :consultation_type_catalog_adapter, DatabaseCatalog)
    # Ensure real Origen.Accounts context is used (no test double)
    Application.delete_env(:origen, :admin_internal_accounts_context)

    on_exit(fn ->
      if previous_calendar do
        Application.put_env(:origen, :appointments_calendar_adapter, previous_calendar)
      else
        Application.delete_env(:origen, :appointments_calendar_adapter)
      end

      if previous_catalog do
        Application.put_env(:origen, :consultation_type_catalog_adapter, previous_catalog)
      else
        Application.delete_env(:origen, :consultation_type_catalog_adapter)
      end

      if previous_context do
        Application.put_env(:origen, :admin_internal_accounts_context, previous_context)
      else
        Application.delete_env(:origen, :admin_internal_accounts_context)
      end
    end)

    Repo.delete_all(ProfessionalPatientRelationship)
    Repo.delete_all(Appointment)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    admin = insert_active_account!(:administrator, "admin-integracion@clinicaorigen.com")
    secretary = insert_active_account!(:secretary, "sec-integracion@clinicaorigen.com")

    prof =
      insert_bookable_professional!(
        "prof-integracion@clinicaorigen.com",
        "Mariana",
        "López",
        "Cardiología",
        "MN-55443"
      )

    {:ok, %{persona: persona, profile: patient}} =
      Patients.complete_profile("paciente-integracion@clinicaorigen.com", %{
        first_name: "Carlos",
        last_name: "Gutiérrez",
        document_type: "dni",
        document_number: "28.765.432",
        birthdate: ~D[1980-05-15],
        phone: "+5491144556677"
      })

    %{
      admin: admin,
      secretary: secretary,
      prof: prof,
      persona: persona,
      patient: patient
    }
  end

  describe "S1: Navbar navigation and role isolation" do
    test "administrator lands via navbar, sees accounts tab active and no operational tabs",
         %{admin: admin} do
      {:ok, view, _html} = live(conn_for(admin), @accounts_path)

      # Navbar item active for Administrator
      assert has_element?(
               view,
               "#role-navigation #nav-accounts[href='#{@accounts_path}'][aria-current='page']",
               "Cuentas"
             )

      # Strictly prohibited operational navbar destinations
      refute has_element?(view, "#nav-agenda")
      refute has_element?(view, "#nav-patients")
      refute has_element?(view, "#nav-summary")
      refute has_element?(view, "#nav-settings")

      # Screen sections
      assert has_element?(view, "#admin-internal-form")
      assert has_element?(view, "#internal-accounts-section")
    end

    test "non-administrator sessions are denied and redirected away",
         %{conn: conn, secretary: secretary, prof: prof} do
      # Secretary is redirected
      assert {:error, {:redirect, %{to: "/"}}} = live(conn_for(secretary), @accounts_path)

      # Professional is redirected
      assert {:error, {:redirect, %{to: "/"}}} = live(conn_for(prof), @accounts_path)

      # Anonymous is redirected
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, @accounts_path)
    end
  end

  describe "S3: Account creation and invitation reissuance with real database" do
    test "creates professional and secretary accounts in pending_activation and allows invitation reissue",
         %{admin: admin} do
      {:ok, view, _html} = live(conn_for(admin), @accounts_path)

      # 1. Create a Professional account
      prof_email = "nuevo.prof.#{System.unique_integer([:positive])}@clinicaorigen.com"

      view
      |> form("#admin-internal-form", form: %{"role" => "professional", "email" => prof_email})
      |> render_submit()

      assert has_element?(view, "[role='status']", "Invitación creada para #{prof_email}")

      # Verify in DB
      [%{id: new_prof_id, role: "professional", state: "pending_activation"}] =
        Repo.query!(
          "SELECT id, role, state FROM internal_accounts WHERE email = $1",
          [prof_email]
        ).rows
        |> Enum.map(fn [id, role, state] -> %{id: id, role: role, state: state} end)

      assert has_element?(view, "#account-row-#{new_prof_id}", prof_email)
      assert has_element?(view, "#account-row-#{new_prof_id}", "Pendiente de activación")
      assert has_element?(view, "#reissue-invitation-#{new_prof_id}")

      # 2. Reissue invitation for this pending account
      view
      |> element("#reissue-invitation-#{new_prof_id}")
      |> render_click()

      assert has_element?(
               view,
               "#lifecycle-feedback",
               "Invitación reemitida para #{prof_email}"
             )

      # Verify unconsumed invitation exists in DB
      [%{invitations_count: count}] =
        Repo.query!(
          """
          SELECT count(*)::integer AS count
          FROM internal_account_invitations
          WHERE account_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL
          """,
          [new_prof_id]
        ).rows
        |> Enum.map(fn [c] -> %{invitations_count: c} end)

      assert count == 1
    end
  end

  describe "S3: Account editing with real database and uniqueness validation" do
    test "updates email preserving id and history; rejects duplicate email",
         %{admin: admin, prof: prof, secretary: secretary} do
      {:ok, view, _html} = live(conn_for(admin), @accounts_path)

      new_email = "mariana.actualizada.#{System.unique_integer([:positive])}@clinicaorigen.com"

      # Open edit form for prof
      view
      |> element("#open-edit-account-#{prof.id}")
      |> render_click()

      assert has_element?(view, "#edit-account-form-#{prof.id}")

      # Submit new email
      view
      |> form("#edit-account-form-#{prof.id}", edit_account: %{"email" => new_email})
      |> render_submit()

      assert has_element?(
               view,
               "#lifecycle-feedback",
               "Correo actualizado a #{new_email}. Se conserva la identidad e historial de la cuenta."
             )

      # Verify DB row updated but ID preserved
      [%{id: prof_id, email: db_email, state: "active"}] =
        Repo.query!(
          "SELECT id, email, state FROM internal_accounts WHERE id = $1",
          [prof.id]
        ).rows
        |> Enum.map(fn [id, email, state] -> %{id: id, email: email, state: state} end)

      assert prof_id == prof.id
      assert db_email == new_email

      # Attempt duplicate email (assign secretary the same email as prof)
      view
      |> element("#open-edit-account-#{secretary.id}")
      |> render_click()

      view
      |> form("#edit-account-form-#{secretary.id}", edit_account: %{"email" => new_email})
      |> render_submit()

      assert has_element?(
               view,
               "#edit-account-error-#{secretary.id}",
               "Ya existe una cuenta con este correo"
             )

      # Secretary email in DB must remain unchanged
      [%{email: sec_db_email}] =
        Repo.query!(
          "SELECT email FROM internal_accounts WHERE id = $1",
          [secretary.id]
        ).rows
        |> Enum.map(fn [e] -> %{email: e} end)

      assert sec_db_email == secretary.email
    end
  end

  describe "S4, S5: Urgent deactivation, future affected turns count and immediate cutoff" do
    test "deactivates professional, shows exact affected count without leaking data, cuts sessions and new bookings, preserves existing appointments",
         %{admin: admin, prof: prof, secretary: secretary, patient: patient} do
      # 1. Create real appointments for the professional in PostgreSQL
      now = DateTime.utc_now()
      past_start = DateTime.add(now, -3600, :second)
      future_start_1 = DateTime.add(now, 3600, :second)
      future_start_2 = DateTime.add(now, 7200, :second)
      future_start_req = DateTime.add(now, 10800, :second)
      future_start_canc = DateTime.add(now, 14400, :second)

      # Past attended appointment
      past_appt =
        insert_appointment!(
          prof.id,
          patient.id,
          prof.consultation_type_id,
          past_start,
          "attended"
        )

      # Future confirmed appointments (2)
      future_conf_1 =
        insert_appointment!(
          prof.id,
          patient.id,
          prof.consultation_type_id,
          future_start_1,
          "confirmed"
        )

      future_conf_2 =
        insert_appointment!(
          prof.id,
          patient.id,
          prof.consultation_type_id,
          future_start_2,
          "confirmed"
        )

      # Future requested appointment (1)
      future_req =
        insert_appointment!(
          prof.id,
          patient.id,
          prof.consultation_type_id,
          future_start_req,
          "requested"
        )

      # Future cancelled appointment (1)
      future_canc =
        insert_appointment!(
          prof.id,
          patient.id,
          prof.consultation_type_id,
          future_start_canc,
          "cancelled"
        )

      # 2. Open an active session for the Professional
      {:ok, %{token: prof_token, session: prof_session}} = Sessions.create_session(prof.id)
      assert {:ok, _} = Sessions.fetch_session(prof_token)

      # 3. Mount AdminInternalLive and deactivate the Professional
      {:ok, view, _html} = live(conn_for(admin), @accounts_path)

      view
      |> element("#deactivate-account-#{prof.id}")
      |> render_click()

      # Verify feedback message and affected turns badge: 2 confirmed + 1 requested = 3 affected
      assert has_element?(
               view,
               "#lifecycle-feedback",
               "Existen 3 turnos futuros afectados para seguimiento por Secretaría"
             )

      assert has_element?(
               view,
               "#account-affected-turns-#{prof.id}",
               "Seguimiento para Secretaría: 3 turnos futuros afectados (no se cancelaron automáticamente)."
             )

      assert has_element?(view, "#account-row-#{prof.id}", "Desactivada")
      assert has_element?(view, "#reactivate-account-#{prof.id}")

      # Strict privacy: no patient names or details shown
      refute has_element?(view, "#internal-accounts-section", "Carlos Gutiérrez")
      refute has_element?(view, "#internal-accounts-section", "28765432")

      # 4. Verify Immediate Session Cutoff (C6)
      assert {:error, :unauthenticated} = Sessions.fetch_session(prof_token)
      assert {:error, :unauthenticated} = Sessions.touch_session(prof_token)

      # Navigation with old token fails closed with 401
      expired_conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:internal_session_token, prof_token)
        |> get("/profesional/agenda")

      assert expired_conn.status == 401

      # 5. Verify Immediate Cutoff of New Bookings across ALL 3 channels
      # Channel A: Patient Autonomous Booking
      assert {:ok, professionals_for_patients} = DatabaseCalendar.list_professionals()
      refute Enum.any?(professionals_for_patients, &(&1.id == prof.id))

      # Daily schedule check
      schedule_result =
        DatabaseCalendar.get_daily_schedule(prof.id, DateTime.to_date(future_start_1),
          interval_minutes: 30
        )

      assert match?({:error, _}, schedule_result)

      # Direct reserve attempt
      assert {:error, :professional_not_eligible} =
               BookingService.reserve(
                 patient,
                 %{
                   professional_id: prof.id,
                   consultation_type_id: prof.consultation_type_id,
                   date: ~D[2026-12-25],
                   slot: %{"start_time" => "10:00"}
                 }
               )

      # Channel B: Secretary Assisted Booking
      assert {:ok, professionals_for_sec} = AssistedBooking.list_professionals()
      refute Enum.any?(professionals_for_sec, &(&1.id == prof.id))

      assert {:error, :invalid_professional} =
               AssistedBooking.reserve(
                 secretary.id,
                 patient.id,
                 %{
                   professional_id: prof.id,
                   consultation_type_id: prof.consultation_type_id,
                   start_time: DateTime.add(now, 18000, :second)
                 }
               )

      # Channel C: Professional Booking
      assert {:error, reason} =
               Booking.reserve_professional_appointment(
                 prof_session,
                 patient.id,
                 %{
                   start_time: DateTime.add(now, 18000, :second),
                   consultation_type_id: prof.consultation_type_id
                 }
               )

      assert reason in [:unauthorized, :invalid_professional_account, :unauthenticated]

      # 6. Verify Preservation of Existing Appointments (no auto-cancellations!)
      assert Repo.get!(Appointment, past_appt.id).status == "attended"
      assert Repo.get!(Appointment, future_conf_1.id).status == "confirmed"
      assert Repo.get!(Appointment, future_conf_2.id).status == "confirmed"
      assert Repo.get!(Appointment, future_req.id).status == "requested"
      assert Repo.get!(Appointment, future_canc.id).status == "cancelled"

      # 7. Secretary follow-up: Secretary can cancel one confirmed appointment
      {:ok, %{session: sec_session}} = Sessions.create_session(secretary.id)

      assert {:ok, _} =
               Booking.cancel_appointment(
                 sec_session,
                 future_conf_1.id,
                 reason: "Cancelado por reestructuración operativa de la clínica",
                 now: DateTime.utc_now()
               )

      assert Repo.get!(Appointment, future_conf_1.id).status == "cancelled"
      assert Repo.get!(Appointment, future_conf_2.id).status == "confirmed"

      # 8. Reactivate Professional (S6 / C8): must NOT restore cancelled appointment
      view
      |> element("#reactivate-account-#{prof.id}")
      |> render_click()

      assert has_element?(
               view,
               "#lifecycle-feedback",
               "Cuenta reactivada para #{prof.email}. Se restableció el acceso; la reactivación no restaura turnos cancelados."
             )

      assert has_element?(view, "#account-row-#{prof.id}", "Activa")

      # Account state in DB is active
      [%{state: "active"}] =
        Repo.query!("SELECT state FROM internal_accounts WHERE id = $1", [prof.id]).rows
        |> Enum.map(fn [s] -> %{state: s} end)

      # The appointment cancelled by Secretary remains CANCELLED!
      assert Repo.get!(Appointment, future_conf_1.id).status == "cancelled"
      # The other confirmed appointment remains CONFIRMED!
      assert Repo.get!(Appointment, future_conf_2.id).status == "confirmed"
      # The requested appointment remains REQUESTED!
      assert Repo.get!(Appointment, future_req.id).status == "requested"

      # Professional is bookable again
      assert {:ok, active_professionals} = DatabaseCalendar.list_professionals()
      assert Enum.any?(active_professionals, &(&1.id == to_string(prof.id)))
    end

    test "deactivates secretary account with 0 affected turns and cuts access immediately",
         %{admin: admin, secretary: secretary} do
      {:ok, %{token: sec_token}} = Sessions.create_session(secretary.id)
      assert {:ok, _} = Sessions.fetch_session(sec_token)

      {:ok, view, _html} = live(conn_for(admin), @accounts_path)

      view
      |> element("#deactivate-account-#{secretary.id}")
      |> render_click()

      assert has_element?(
               view,
               "#lifecycle-feedback",
               "Cuenta desactivada para #{secretary.email}. Se revocaron las sesiones activas y el acceso inmediato (0 turnos futuros afectados)."
             )

      assert has_element?(view, "#account-row-#{secretary.id}", "Desactivada")

      # Secretary session terminated immediately
      assert {:error, :unauthenticated} = Sessions.fetch_session(sec_token)

      sec_conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:internal_session_token, sec_token)

      assert {:error, {:redirect, %{to: "/"}}} = live(sec_conn, "/secretaria/pacientes")
    end
  end

  describe "S3: Strict role isolation and default-deny (C9, C10, C11)" do
    test "administrator cannot operate on another administrator account or self-deactivate",
         %{admin: admin} do
      other_admin = insert_active_account!(:administrator, "otro-admin@clinicaorigen.com")

      assert {:error, :unauthorized} =
               Accounts.deactivate_internal_account(admin.id, other_admin.id)

      assert {:error, :unauthorized} =
               Accounts.deactivate_internal_account(admin.id, admin.id)

      assert {:error, :unauthorized} =
               Accounts.update_internal_account(admin.id, other_admin.id, %{
                 email: "nuevo-admin@clinicaorigen.com"
               })
    end

    test "non-administrator actors receive unauthorized for domain account lifecycle operations",
         %{secretary: secretary, prof: prof} do
      target = insert_active_account!(:secretary, "target@clinicaorigen.com")

      for actor_id <- [secretary.id, prof.id, 999_999] do
        assert {:error, :unauthorized} = Accounts.list_internal_accounts(actor_id)

        assert {:error, :unauthorized} =
                 Accounts.update_internal_account(actor_id, target.id, %{
                   email: "hack@clinicaorigen.com"
                 })

        assert {:error, :unauthorized} =
                 Accounts.deactivate_internal_account(actor_id, target.id)

        assert {:error, :unauthorized} = Accounts.reactivate_internal_account(actor_id, target.id)
      end
    end
  end

  # ---------------------------------------------------------------- helpers

  defp conn_for(account) do
    {:ok, %{token: token}} = Sessions.create_session(account.id)

    build_conn()
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp insert_active_account!(role, email) do
    password_hash = "argon2_test_hash"
    totp_secret = <<1, 2, 3, 4, 5>>

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES
          ($1, $2, 'active', $3, $4, clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [email, Atom.to_string(role), password_hash, totp_secret]
      )

    %{id: id, email: email, role: role, state: "active"}
  end

  defp insert_bookable_professional!(email, first_name, last_name, specialty, license_number) do
    prof = insert_active_account!(:professional, email)

    Repo.query!(
      """
      INSERT INTO professional_profiles
        (owner_account_id, first_name, last_name, specialty, license_type, license_number, created_at, updated_at)
      VALUES ($1, $2, $3, $4, 'Nacional', $5, clock_timestamp(), clock_timestamp())
      """,
      [prof.id, first_name, last_name, specialty, license_number]
    )

    week =
      Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
        {day, [%{"start" => "08:00", "end" => "18:00"}]}
      end)

    Repo.query!(
      """
      INSERT INTO agenda_settings
        (owner_account_id, interval_minutes, approval_mode, secretary_approval_mode, weekly_availability, booking_horizon_days, minimum_lead_minutes, created_at, updated_at)
      VALUES ($1, 30, 'manual', 'confirmed', $2, 30, 0, clock_timestamp(), clock_timestamp())
      """,
      [prof.id, week]
    )

    type_uuid = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at)
      VALUES ($1, $2, 'Consulta Cardiológica', 25000.00, '#0A3847', 1, 'active', clock_timestamp(), clock_timestamp())
      """,
      [Ecto.UUID.dump!(type_uuid), prof.id]
    )

    Map.merge(prof, %{
      first_name: first_name,
      last_name: last_name,
      consultation_type_id: type_uuid
    })
  end

  defp insert_appointment!(prof_id, patient_id, consultation_type_id, start_time, status) do
    duration = 30
    end_time = DateTime.add(start_time, duration, :minute)

    %Appointment{}
    |> Appointment.changeset(%{
      patient_profile_id: patient_id,
      professional_account_id: prof_id,
      consultation_type_id: consultation_type_id,
      start_time: start_time,
      end_time: end_time,
      status: status,
      snapshot_consultation_type_name: "Consulta Cardiológica",
      snapshot_duration_minutes: duration,
      snapshot_exact_price_ars: Decimal.new("25000.00")
    })
    |> Repo.insert!()
  end
end
