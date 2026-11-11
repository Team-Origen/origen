defmodule Origen.TestSupport.AppointmentLifecycleIntegrationHelpers do
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint OrigenWeb.Endpoint
  @approval_modes %{"manual" => :manual, "automatic" => :automatic}
  @secretary_approval_modes %{"requested" => :requested, "confirmed" => :confirmed}

  alias Origen.{Availability, ConsultationTypes, PatientAccess, Patients, Repo, Sessions}
  alias Origen.Appointments.Calendar
  alias Origen.Booking.Appointment

  @moduledoc """
  Real-flow setup for #379 integration tests.

  Internal accounts, professional configuration, consultation types, and patient
  identities are test fixtures. Appointment rows are never inserted here:
  `book_as_patient!/5` and `book_as_secretary!/5` create them through the real
  LiveView booking journeys and persisted adapters.
  """

  def context! do
    suffix = System.unique_integer([:positive])
    professional = professional!(suffix, "Sofía", "Martínez", "manual", "requested")
    other_professional = professional!(suffix + 1_000, "Lucas", "Gómez", "automatic", "confirmed")
    secretary = internal_account!(suffix, :secretary)
    administrator = internal_account!(suffix, :administrator)

    patient = patient!(suffix, "Ana", "Pérez", "41")
    other_patient = patient!(suffix + 1, "Bruno", "Díaz", "42")

    %{
      suffix: suffix,
      professional: professional,
      other_professional: other_professional,
      secretary: secretary,
      administrator: administrator,
      patient: patient,
      other_patient: other_patient,
      date: future_weekday!(5),
      replacement_date: future_weekday!(8)
    }
  end

  def book_as_patient!(_ctx, patient, professional, date, time, type \\ nil) do
    type = type || professional.type
    conn = patient_conn!(patient.profile.email)
    {:ok, view, _html} = live(conn, "/paciente/turnos/reservar")

    render_change(view, "change_prof", %{"prof_id" => to_string(professional.id)})
    render_change(view, "change_type", %{"type_id" => type.id})
    render_change(view, "change_date", %{"date" => Date.to_iso8601(date)})

    {:ok, schedule} =
      Calendar.get_daily_schedule(to_string(professional.id), date,
        duration_minutes: type.interval_count * 30
      )

    slot = Enum.find(schedule.slots, &(&1.start_formatted == time))
    assert slot, "expected a real available slot at #{time} on #{date}"

    view
    |> element(~s(button[phx-value-slot_id="#{slot.id}"]))
    |> render_click()

    html = render_click(view, "confirm_booking")
    assert html =~ expected_booking_message(professional.approval_mode)

    start_time = DateTime.new!(date, slot.start_time, "Etc/UTC")

    Repo.get_by!(Appointment,
      patient_profile_id: patient.profile.id,
      professional_account_id: professional.id,
      start_time: start_time
    )
  end

  def book_as_secretary!(ctx, patient, professional, date, time) do
    {:ok, view, _html} =
      live(internal_conn(ctx.secretary.token), "/secretaria/pacientes")

    view
    |> form("#persona-search-form",
      search: %{
        "document_type" => "dni",
        "document_number" => patient.persona.document_number
      }
    )
    |> render_submit()

    view |> element("#start-assisted-booking") |> render_click()

    render_change(view, "update_booking_selection", %{
      "professional_id" => to_string(professional.id),
      "consultation_type_id" => professional.type.id,
      "date" => Date.to_iso8601(date)
    })

    view
    |> element(~s(button[phx-click="select_slot"][phx-value-time="#{time}"]))
    |> render_click()

    view |> element("#confirm-assisted-booking") |> render_click()
    assert has_element?(view, "#booking-success-message", "Confirmed")

    start_time = DateTime.new!(date, Time.from_iso8601!(time <> ":00"), "Etc/UTC")

    Repo.get_by!(Appointment,
      patient_profile_id: patient.profile.id,
      professional_account_id: professional.id,
      start_time: start_time
    )
  end

  def cancel_as_patient!(patient, appointment_id) do
    {:ok, view, _html} = live(patient_conn!(patient.profile.email), "/paciente/turnos")

    render_click(view, "cancel_appointment", %{"appointment_id" => to_string(appointment_id)})
    assert Repo.get!(Appointment, appointment_id).status == "cancelled"
  end

  def patient_conn!(email) do
    assert {:ok, :delivered} = PatientAccess.request_magic_link(email)

    token =
      receive do
        {:email, message} ->
          [_, encoded] =
            Regex.run(~r{/paciente/acceso/verificar\?token=([^"&]+)}, message.html_body)

          URI.decode_www_form(encoded)
      after
        1_000 -> flunk("expected a local Magic Link email for #{email}")
      end

    conn =
      Phoenix.ConnTest.get(
        Phoenix.ConnTest.build_conn(),
        "/paciente/acceso/verificar?token=#{token}"
      )

    assert Phoenix.ConnTest.redirected_to(conn) == "/paciente/turnos/reservar"
    conn
  end

  def internal_conn(token) do
    Phoenix.ConnTest.build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  defp professional!(suffix, first_name, last_name, approval_mode, secretary_approval_mode) do
    account = internal_account!(suffix, :professional)

    assert {:ok, _profile} =
             Origen.ProfessionalProfiles.save_own_profile(account.session, %{
               first_name: first_name,
               last_name: last_name,
               specialty: "Medicina General",
               license_type: "Nacional",
               license_number: "MN-#{suffix}"
             })

    assert {:ok, _configuration} =
             Availability.replace_own_configuration(account.session, %{
               weekly_availability: weekday_availability(),
               booking_horizon_days: 30,
               minimum_lead_minutes: 0
             })

    assert {:ok, _} =
             Origen.Booking.update_approval_configuration(account.session, %{
               approval_mode: Map.fetch!(@approval_modes, approval_mode),
               secretary_approval_mode:
                 Map.fetch!(@secretary_approval_modes, secretary_approval_mode)
             })

    assert {:ok, type} =
             ConsultationTypes.create_type(account.session, %{
               name: "Consulta #{first_name}",
               exact_price_ars: "18000.00",
               color: "#0A3847",
               interval_count: 1
             })

    assert {:ok, second_type} =
             ConsultationTypes.create_type(account.session, %{
               name: "Consulta alternativa #{first_name}",
               exact_price_ars: "22000.00",
               color: "#35545A",
               interval_count: 1
             })

    Map.merge(account, %{
      name: "#{first_name} #{last_name}",
      type: type,
      second_type: second_type,
      approval_mode: approval_mode
    })
  end

  defp internal_account!(suffix, role) do
    email = "lifecycle-#{role}-#{suffix}-#{System.unique_integer([:positive])}@example.test"

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ($1, 'active', $2, 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        [Atom.to_string(role), email]
      )

    {:ok, %{session: session, token: token}} = Sessions.create_session(id)
    %{id: id, session: session, token: token, role: role}
  end

  defp patient!(suffix, first_name, last_name, dni_prefix) do
    email = "lifecycle-patient-#{suffix}-#{System.unique_integer([:positive])}@example.test"

    document_number =
      "#{dni_prefix}#{rem(abs(suffix), 100_000) |> Integer.to_string() |> String.pad_leading(6, "0")}"

    {:ok, %{persona: persona, profile: profile}} =
      Patients.complete_profile(email, %{
        first_name: first_name,
        last_name: last_name,
        document_type: "dni",
        document_number: document_number,
        birthdate: ~D[1990-05-10],
        phone: "+5491133445566"
      })

    %{persona: persona, profile: profile}
  end

  defp expected_booking_message("manual"), do: "Solicitud enviada"
  defp expected_booking_message("automatic"), do: "Turno confirmado"

  defp weekday_availability do
    Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
      {day, [%{"start" => "08:00", "end" => "18:00"}]}
    end)
  end

  defp future_weekday!(days_ahead) do
    date = Date.add(Date.utc_today(), days_ahead)

    case Date.day_of_week(date) do
      6 -> Date.add(date, 2)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end
end
