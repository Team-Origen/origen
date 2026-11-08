defmodule OrigenWeb.PatientBookingIntegrationTest do
  use OrigenWeb.LiveViewCase, async: false

  alias Origen.{Availability, Booking, ConsultationTypes, PatientAccess, Patients, Repo, Sessions}
  alias Origen.Appointments.{Calendar, DatabaseCalendar}
  alias Origen.ConsultationTypes.DatabaseCatalog

  setup do
    previous_calendar = Application.get_env(:origen, :appointments_calendar_adapter)
    previous_catalog = Application.get_env(:origen, :consultation_type_catalog_adapter)

    Application.put_env(:origen, :appointments_calendar_adapter, DatabaseCalendar)
    Application.put_env(:origen, :consultation_type_catalog_adapter, DatabaseCatalog)

    on_exit(fn ->
      Application.put_env(:origen, :appointments_calendar_adapter, previous_calendar)
      Application.put_env(:origen, :consultation_type_catalog_adapter, previous_catalog)
    end)

    suffix = System.unique_integer([:positive])
    professional_id = insert_professional!(suffix)
    {:ok, %{session: principal}} = Sessions.create_session(professional_id)

    assert {:ok, _profile} =
             Origen.ProfessionalProfiles.save_own_profile(principal, %{
               first_name: "Sofía",
               last_name: "Martínez",
               specialty: "Medicina General",
               license_type: "Libre",
               license_number: "MN-#{suffix}"
             })

    assert {:ok, _configuration} =
             Availability.replace_own_configuration(principal, %{
               weekly_availability: weekday_availability(),
               booking_horizon_days: 30,
               minimum_lead_minutes: 0
             })

    assert {:ok, consultation_type} =
             ConsultationTypes.create_type(principal, %{
               name: "Consulta general",
               exact_price_ars: "18000.00",
               color: "#0A3847",
               interval_count: 1
             })

    %{
      professional_id: professional_id,
      principal: principal,
      consultation_type_id: consultation_type.id,
      suffix: suffix
    }
  end

  test "magic-link HTTP session reaches the persisted calendar and confirms a real booking",
       ctx do
    email = "patient-#{ctx.suffix}@example.test"
    profile = complete_patient!(email, "401#{ctx.suffix}", "Ana")
    conn = authenticated_conn!(email)

    booking_date = next_weekday(Date.utc_today(), 2)
    {:ok, view, html} = live(conn, ~p"/paciente/turnos/reservar")

    assert html =~ "Calendario de Reservas"
    assert html =~ "Sofía Martínez"
    assert html =~ "Consulta general (30 min)"
    assert profile.phone_verified == false

    assert render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)}) =~
             "08:00"

    {:ok, schedule} =
      Calendar.get_daily_schedule(to_string(ctx.professional_id), booking_date,
        duration_minutes: 30
      )

    slot = Enum.find(schedule.slots, &(&1.start_formatted == "09:00"))
    assert slot

    view
    |> element(~s(button[phx-value-slot_id="#{slot.id}"]))
    |> render_click()

    html = render_click(view, "confirm_booking")
    assert html =~ "Turno confirmado"
    assert html =~ "Consulta general"
    refute html =~ "Pendiente de aprobación"
    refute html =~ "D-1"
    refute html =~ "Verificación de Teléfono"

    {:ok, after_booking} =
      Calendar.get_daily_schedule(to_string(ctx.professional_id), booking_date,
        duration_minutes: 30
      )

    refute Enum.any?(after_booking.slots, &(&1.id == slot.id))

    assert {:ok, agenda} = Booking.get_professional_agenda(ctx.principal, %{date: booking_date})

    assert [%{status: "confirmed", patient: %{id: patient_id}} = appointment] =
             agenda.appointments

    assert patient_id == profile.id
    assert appointment.consultation_type_name == "Consulta general"
    assert appointment.duration_minutes == 30
    assert Decimal.equal?(appointment.price_ars, Decimal.new("18000.00"))

    assert {:ok, related_patients} = Booking.list_professional_patients(ctx.principal)
    assert Enum.any?(related_patients, &(&1.id == profile.id))
  end

  test "the same real journey creates a requested appointment on D-1 in manual mode", ctx do
    Repo.query!(
      "UPDATE agenda_settings SET approval_mode = 'manual' WHERE owner_account_id = $1",
      [
        ctx.professional_id
      ]
    )

    email = "manual-patient-#{ctx.suffix}@example.test"
    profile = complete_patient!(email, "402#{ctx.suffix}", "Bruno")
    conn = authenticated_conn!(email)
    booking_date = Date.add(Date.utc_today(), 1)

    {:ok, view, _html} = live(conn, ~p"/paciente/turnos/reservar")
    render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

    {:ok, schedule} =
      Calendar.get_daily_schedule(to_string(ctx.professional_id), booking_date,
        duration_minutes: 30
      )

    slot = Enum.find(schedule.slots, &(&1.start_formatted == "10:00"))
    assert slot

    view
    |> element(~s(button[phx-value-slot_id="#{slot.id}"]))
    |> render_click()

    html = render_click(view, "confirm_booking")
    assert html =~ "Solicitud enviada"
    assert html =~ "Pendiente de aprobación"
    refute html =~ "D-1"

    assert {:ok, agenda} = Booking.get_professional_agenda(ctx.principal, %{date: booking_date})
    assert [%{status: "requested", patient: %{id: patient_id}}] = agenda.appointments
    assert patient_id == profile.id

    {:ok, refreshed} =
      Calendar.get_daily_schedule(to_string(ctx.professional_id), booking_date,
        duration_minutes: 30
      )

    refute Enum.any?(refreshed.slots, &(&1.id == slot.id))
  end

  test "a stale selected slot is rejected through the real LiveView without partial effects",
       ctx do
    first =
      complete_patient!("stale-first-#{ctx.suffix}@example.test", "403#{ctx.suffix}", "Carla")

    second =
      complete_patient!("stale-second-#{ctx.suffix}@example.test", "404#{ctx.suffix}", "Diego")

    conn = authenticated_conn!(first.email)
    booking_date = next_weekday(Date.utc_today(), 3)

    {:ok, view, _html} = live(conn, ~p"/paciente/turnos/reservar")
    render_change(view, "change_date", %{"date" => Date.to_iso8601(booking_date)})

    {:ok, schedule} =
      Calendar.get_daily_schedule(to_string(ctx.professional_id), booking_date,
        duration_minutes: 30
      )

    slot = Enum.find(schedule.slots, &(&1.start_formatted == "11:00"))
    assert slot

    view
    |> element(~s(button[phx-value-slot_id="#{slot.id}"]))
    |> render_click()

    assert {:ok, _} =
             Origen.Appointments.BookingService.reserve(second, %{
               professional_id: ctx.professional_id,
               consultation_type_id: ctx.consultation_type_id,
               date: booking_date,
               slot: slot
             })

    html = render_click(view, "confirm_booking")
    assert html =~ "Ese horario ya no está disponible"
    refute has_element?(view, "#booking-result")

    assert {:ok, agenda} = Booking.get_professional_agenda(ctx.principal, %{date: booking_date})
    assert [%{patient: %{id: second_id}}] = agenda.appointments
    assert second_id == second.id

    assert {:ok, related} = Booking.list_professional_patients(ctx.principal)
    assert Enum.any?(related, &(&1.id == second.id))
    refute Enum.any?(related, &(&1.id == first.id))
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
        [_, encoded] = Regex.run(~r{/paciente/acceso/verificar\?token=([^"&]+)}, email.html_body)
        URI.decode_www_form(encoded)
    after
      1_000 -> flunk("Expected a local Magic Link email for #{recipient}")
    end
  end

  defp complete_patient!(email, document_number, first_name) do
    {:ok, %{profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: first_name,
        last_name: "Integración",
        document_type: "dni",
        document_number: document_number,
        birthdate: ~D[1990-01-01],
        phone: "+5491112345678"
      })

    profile
  end

  defp insert_professional!(suffix) do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ('professional', 'active', $1, 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        ["professional-#{suffix}@example.test"]
      )

    id
  end

  defp weekday_availability do
    Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
      {day, [%{"start" => "08:00", "end" => "18:00"}]}
    end)
  end

  defp next_weekday(date, days_ahead) do
    target = Date.add(date, days_ahead)

    case Date.day_of_week(target) do
      6 -> Date.add(target, 2)
      7 -> Date.add(target, 1)
      _ -> target
    end
  end
end
