defmodule OrigenWeb.PatientBookingRealDatabaseTimezoneFlowTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.{Availability, Booking, ConsultationTypes, PatientAccess, Patients, Repo, Sessions}
  alias Origen.Appointments.{Calendar, DatabaseCalendar}
  alias Origen.ConsultationTypes.DatabaseCatalog

  @timezone "America/Argentina/Buenos_Aires"

  setup do
    previous_timezone = Application.get_env(:origen, :organization_timezone)
    previous_calendar = Application.get_env(:origen, :appointments_calendar_adapter)
    previous_catalog = Application.get_env(:origen, :consultation_type_catalog_adapter)

    Application.put_env(:origen, :organization_timezone, @timezone)
    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)
    Application.put_env(:origen, :consultation_type_catalog_adapter, DatabaseCatalog)

    suffix = System.unique_integer([:positive])
    professional_id = insert_professional!(suffix)
    {:ok, %{session: professional}} = Sessions.create_session(professional_id)

    assert {:ok, _} =
             Origen.ProfessionalProfiles.save_own_profile(professional, %{
               first_name: "Horario",
               last_name: "Real",
               specialty: "Medicina General",
               license_type: "Libre",
               license_number: "TZ-#{suffix}"
             })

    assert {:ok, _} =
             Availability.replace_own_configuration(professional, %{
               weekly_availability: weekday_availability(),
               booking_horizon_days: 30,
               minimum_lead_minutes: 0
             })

    assert {:ok, type_30} =
             ConsultationTypes.create_type(professional, %{
               name: "Consulta 30",
               exact_price_ars: "1000.00",
               color: "#0A3847",
               interval_count: 1
             })

    assert {:ok, type_60} =
             ConsultationTypes.create_type(professional, %{
               name: "Consulta 60",
               exact_price_ars: "2000.00",
               color: "#35545A",
               interval_count: 2
             })

    email = "timezone-patient-#{suffix}@example.test"

    {:ok, %{profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: "Paciente",
        last_name: "Horario",
        document_type: "dni",
        document_number: "#{40_000_000 + rem(suffix, 9_000_000)}",
        birthdate: ~D[1990-01-15],
        phone: "+5491100000001"
      })

    on_exit(fn ->
      Application.put_env(:origen, :organization_timezone, previous_timezone)
      Application.put_env(:origen, :appointments_calendar_adapter, previous_calendar)
      Application.put_env(:origen, :consultation_type_catalog_adapter, previous_catalog)
    end)

    %{
      email: email,
      profile: profile,
      professional_id: professional_id,
      type_30: type_30,
      type_60: type_60
    }
  end

  test "keeps the selected 08:00 local slot through persistence and public history", ctx do
    booking_date = next_future_weekday()
    conn = authenticated_conn!(ctx.email)

    {:ok, view, html} = live(conn, ~p"/paciente/turnos/reservar")
    assert html =~ "Consulta 30 (30 min)"
    assert html =~ "Consulta 60 (60 min)"

    html = render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})
    assert html =~ "08:00"
    refute html =~ "06:00"

    assert {:ok, schedule_30} =
             Calendar.get_daily_schedule(to_string(ctx.professional_id), booking_date,
               duration_minutes: 30
             )

    slot_30 = Enum.find(schedule_30.slots, &(&1.start_formatted == "08:00"))
    assert slot_30

    html =
      view
      |> element(~s(button[phx-value-slot_id="#{slot_30.id}"]))
      |> render_click()

    assert html =~ "08:00 a 08:30"
    refute html =~ "06:00"

    html = render_click(view, "confirm_booking")
    assert html =~ "Turno confirmado"
    assert html =~ "08:00 a 08:30"
    refute html =~ "06:00"

    appointment_id = confirmation_appointment_id!(html)
    persisted = Repo.get!(Origen.Booking.Appointment, appointment_id)

    expected_start =
      DateTime.new!(booking_date, ~T[08:00:00], @timezone) |> DateTime.shift_zone!("Etc/UTC")

    expected_end = DateTime.add(expected_start, 30, :minute)

    assert DateTime.compare(persisted.start_time, expected_start) == :eq
    assert DateTime.compare(persisted.end_time, expected_end) == :eq
    assert persisted.snapshot_duration_minutes == 30
    assert persisted.snapshot_consultation_type_name == "Consulta 30"
    assert persisted.consultation_type_id == ctx.type_30.id

    patient_principal = %{
      patient_email: ctx.email,
      patient_authenticated_at: get_session(conn, :patient_authenticated_at)
    }

    assert {:ok, [patient_history]} = Booking.list_appointment_history(patient_principal)
    assert patient_history.id == appointment_id
    assert DateTime.compare(patient_history.start_time, expected_start) == :eq
    assert DateTime.compare(patient_history.end_time, expected_end) == :eq

    {:ok, history_view, _history_html} = live(conn, ~p"/paciente/turnos")
    assert has_element?(history_view, "#patient-appointment-#{appointment_id}")

    history_card = history_view |> element("#patient-appointment-#{appointment_id}") |> render()
    assert history_card =~ "08:00"
    refute history_card =~ "06:00"

    {:ok, %{session: professional}} = Sessions.create_session(ctx.professional_id)

    assert {:ok, %{appointments: [professional_appointment]}} =
             Booking.get_professional_agenda(professional, %{date: booking_date})

    assert professional_appointment.id == appointment_id
    assert professional_appointment.duration_minutes == 30
    assert professional_appointment.consultation_type_name == "Consulta 30"
    assert DateTime.compare(professional_appointment.start_time, expected_start) == :eq
    assert DateTime.compare(professional_appointment.end_time, expected_end) == :eq

    secretary_id = insert_secretary!(ctx.professional_id)
    {:ok, %{session: secretary}} = Sessions.create_session(secretary_id)

    assert {:ok, [secretary_appointment]} = Booking.list_appointment_history(secretary)
    assert secretary_appointment.id == appointment_id
    assert secretary_appointment.duration_minutes == 30
    assert secretary_appointment.consultation_type_name == "Consulta 30"
    assert DateTime.compare(secretary_appointment.start_time, expected_start) == :eq
    assert DateTime.compare(secretary_appointment.end_time, expected_end) == :eq
  end

  defp authenticated_conn!(email) do
    assert {:ok, :delivered} = PatientAccess.request_magic_link(email)
    token = receive_magic_token!(email)
    conn = get(build_conn(), ~p"/paciente/acceso/verificar?token=#{token}")
    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :patient_email) == email
    conn
  end

  defp receive_magic_token!(recipient) do
    receive do
      {:email, email} ->
        assert email.to == [{"", recipient}]
        [_, encoded] = Regex.run(~r{/paciente/acceso/verificar\?token=([^\"&]+)}, email.html_body)
        URI.decode_www_form(encoded)
    after
      1_000 -> flunk("Expected a local Magic Link email for #{recipient}")
    end
  end

  defp confirmation_appointment_id!(html) do
    [_, id] = Regex.run(~r/Turno ID:.*?(\d+)/s, html)
    String.to_integer(id)
  end

  defp insert_professional!(suffix) do
    Repo.query!(
      """
      INSERT INTO internal_accounts
        (role, state, email, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', $1, 'hash', decode('0102030405', 'hex'), clock_timestamp())
      RETURNING id
      """,
      ["timezone-professional-#{suffix}@example.test"]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_secretary!(suffix) do
    Repo.query!(
      """
      INSERT INTO internal_accounts
        (role, state, email, password_hash, totp_secret, activated_at)
      VALUES ('secretary', 'active', $1, 'hash', decode('0102030405', 'hex'), clock_timestamp())
      RETURNING id
      """,
      ["timezone-secretary-#{suffix}@example.test"]
    ).rows
    |> hd()
    |> hd()
  end

  defp weekday_availability do
    Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
      {day, [%{"start" => "08:00", "end" => "18:00"}]}
    end)
  end

  defp next_future_weekday do
    today = DateTime.now!(@timezone) |> DateTime.to_date()

    Enum.find(1..7, fn offset ->
      candidate = Date.add(today, offset)
      Date.day_of_week(candidate) in 1..5
    end)
    |> then(&Date.add(today, &1))
  end
end
