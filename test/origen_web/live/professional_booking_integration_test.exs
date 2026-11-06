defmodule OrigenWeb.ProfessionalBookingIntegrationTest do
  use OrigenWeb.LiveViewCase

  alias Origen.{Booking, Repo, Sessions}

  setup do
    previous = Application.get_env(:origen, :professional_patient_selector)
    Application.delete_env(:origen, :professional_patient_selector)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:origen, :professional_patient_selector),
        else: Application.put_env(:origen, :professional_patient_selector, previous)
    end)

    a = professional!("Consulta propia")
    b = professional!("Consulta ajena")
    related = patient!("Ana", "30111222")
    searched = patient!("Bruno", "30222333")
    date = Date.add(Date.utc_today(), 1)
    seed_booking!(a, related, Date.add(date, 1), "09:00:00")
    seed_booking!(b, searched, date, "10:00:00")

    %{a: a, b: b, related: related, searched: searched, date: date}
  end

  for mode <- ["automatic", "manual"] do
    test "related patient books a real confirmed appointment in #{mode} mode", ctx do
      Repo.query!("UPDATE agenda_settings SET approval_mode = $1 WHERE owner_account_id = $2", [
        unquote(mode),
        ctx.a.session.account_id
      ])

      {:ok, before_patients} = Booking.list_professional_patients(ctx.a.session)
      {:ok, view, html} = open_booking(ctx)
      refute html =~ "Demostración"
      refute html =~ "30222333"
      select_related(view, ctx.related)
      advance_to_confirmation(view, ctx.a.type, ctx.date)
      html = view |> element("#confirm-booking") |> render_click()
      assert html =~ "Turno confirmado"
      refute html =~ "Simulación"
      assert has_element?(view, "#booking-result")
      refute has_element?(view, "#confirm-booking")

      assert has_element?(
               view,
               "#booking-return-agenda[href='/profesional/agenda?date=#{ctx.date}']"
             )

      render_click(view, "confirm_booking", %{})

      assert {:ok, %{appointments: [appointment]}} = agenda(ctx.a, ctx.date)
      assert appointment.status == "confirmed"
      assert {:ok, ^before_patients} = Booking.list_professional_patients(ctx.a.session)

      assert {:ok, schedule} =
               Booking.get_professional_booking_schedule(ctx.a.session, ctx.a.type, ctx.date)

      refute Enum.any?(schedule.slots, &(&1.start_time == ~T[09:00:00]))

      {:ok, _agenda, html} =
        live(auth_conn(ctx.conn, ctx.a.token), "/profesional/agenda?date=#{ctx.date}")

      assert html =~ "Ana Integración"
      assert html =~ "Confirmado"
    end
  end

  test "exact DNI is minimal and search, selection and abandonment never create a relationship",
       ctx do
    before = observable_state(ctx)
    {:ok, view, _} = open_booking(ctx)
    view |> element("#tab-dni") |> render_click()

    for dni <- ["30222", "99999999", "3022233"] do
      html = view |> form("#patient-dni-form", %{dni: dni}) |> render_submit()
      refute html =~ "Bruno"
      assert observable_state(ctx) == before
    end

    html = view |> form("#patient-dni-form", %{dni: "30.222.333"}) |> render_submit()
    assert html =~ "Bruno Integración"
    refute has_element?(view, "#assisted-patient-form")

    for secret <- ["30222333@example.test", "+5491100000000", "Consulta ajena", "10:00"],
        do: refute(html =~ secret)

    view |> element("#patient-#{ctx.searched}") |> render_click()
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    view |> element("#cancel-patient-selection") |> render_click()
    assert_redirect(view, "/profesional/agenda")
    assert observable_state(ctx) == before
    {:ok, _, html} = open_booking(ctx)
    refute html =~ "30222333"
  end

  test "absent exact DNI offers an assisted form without registering on search or abandonment",
       ctx do
    {:ok, view, _} = open_booking(ctx)
    view |> element("#tab-dni") |> render_click()
    before = Repo.query!("SELECT count(*) FROM personas WHERE document_number = '99999999'").rows

    html = view |> form("#patient-dni-form", %{dni: "99.999.999"}) |> render_submit()
    assert html =~ "Alta asistida"
    assert has_element?(view, "#assisted-patient-form")
    assert has_element?(view, "#patient-selection-next[disabled]")

    assert Repo.query!("SELECT count(*) FROM personas WHERE document_number = '99999999'").rows ==
             before

    html =
      view
      |> form("#assisted-patient-form", %{
        "patient" => %{
          "first_name" => "Luz",
          "last_name" => "",
          "birthdate" => "1990-01-01",
          "phone" => "+5491100000000"
        }
      })
      |> render_submit()

    assert html =~ "Completá los datos obligatorios"
    assert has_element?(view, "#patient-selection-next[disabled]")

    view
    |> form("#assisted-patient-form", %{
      "patient" => %{
        "first_name" => "Luz",
        "last_name" => "Gómez",
        "birthdate" => "1990-01-01",
        "phone" => "+5491100000000",
        "email" => ""
      }
    })
    |> render_submit()

    assert has_element?(view, "#selected-patient", "Luz Gómez")
    assert has_element?(view, "#patient-selection-next:not([disabled])")

    assert Repo.query!("SELECT count(*) FROM personas WHERE document_number = '99999999'").rows ==
             before

    view |> element("#clear-patient-selection") |> render_click()
    assert has_element?(view, "#assisted-patient-form")
    view |> element("#tab-related") |> render_click()
    refute has_element?(view, "#assisted-patient-form")
    view |> element("#tab-dni") |> render_click()
    assert has_element?(view, "#patient-selection-next[disabled]")
    view |> element("#cancel-patient-selection") |> render_click()
    assert_redirect(view, "/profesional/agenda")

    assert Repo.query!("SELECT count(*) FROM personas WHERE document_number = '99999999'").rows ==
             before
  end

  test "assisted confirmation books once and persists identity only at the final step", ctx do
    {:ok, other_before} = agenda(ctx.b, ctx.date)
    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    assert patient_count("99999999") == 0
    refute has_element?(view, "#booking-result")

    html =
      render_click(view, "confirm_booking", %{
        "professional_id" => ctx.b.session.account_id,
        "patient_id" => ctx.related,
        "document_number" => "30111222",
        "status" => "requested"
      })

    assert html =~ "Turno confirmado"
    assert has_element?(view, "#booking-result")
    assert patient_count("99999999") == 1
    assert {:ok, %{appointments: [appointment]}} = agenda(ctx.a, ctx.date)
    assert appointment.status == "confirmed"
    assert appointment.patient.first_name == "Luz"
    assert {:ok, ^other_before} = agenda(ctx.b, ctx.date)
    assert {:ok, patients} = Booking.list_professional_patients(ctx.a.session)
    assert Enum.any?(patients, &(&1.document_number == "99999999"))
    render_click(view, "confirm_booking", %{})
    assert patient_count("99999999") == 1
    assert {:ok, %{appointments: [_]}} = agenda(ctx.a, ctx.date)
  end

  test "assisted booking preserves Buenos Aires wall time through confirmation", ctx do
    previous = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "America/Argentina/Buenos_Aires")
    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous) end)

    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    assert patient_count("99999999") == 0

    assert view |> element("#confirm-booking") |> render_click() =~ "Turno confirmado"
    assert patient_count("99999999") == 1
    assert {:ok, %{appointments: [appointment]}} = agenda(ctx.a, ctx.date)

    expected =
      DateTime.new!(ctx.date, ~T[09:00:00], "America/Argentina/Buenos_Aires")
      |> DateTime.shift_zone!("Etc/UTC")

    assert DateTime.compare(appointment.start_time, expected) == :eq
  end

  test "own schedule shows same-day Buenos Aires slots after local lead time", ctx do
    previous = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "America/Argentina/Buenos_Aires")
    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous) end)

    week =
      Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), fn day ->
        {day, [%{"start" => "14:00", "end" => "18:00"}]}
      end)

    Repo.query!(
      "UPDATE agenda_settings SET weekly_availability = $1 WHERE owner_account_id = $2",
      [
        week,
        ctx.a.session.account_id
      ]
    )

    assert {:ok, schedule} =
             Booking.get_professional_booking_schedule(
               ctx.a.session,
               ctx.a.type,
               ~D[2026-11-04],
               now: ~U[2026-11-04 17:15:00Z]
             )

    starts = Enum.map(schedule.slots, & &1.start_time)
    refute ~T[14:30:00] in starts
    assert ~T[15:00:00] in starts
  end

  test "existing patient booking uses local time and hides its occupied slot", ctx do
    previous = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "America/Argentina/Buenos_Aires")
    on_exit(fn -> Application.put_env(:origen, :organization_timezone, previous) end)

    {:ok, view, _} = open_booking(ctx)
    select_related(view, ctx.related)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    assert view |> element("#confirm-booking") |> render_click() =~ "Turno confirmado"
    assert {:ok, %{appointments: [appointment]}} = agenda(ctx.a, ctx.date)

    expected =
      DateTime.new!(ctx.date, ~T[09:00:00], "America/Argentina/Buenos_Aires")
      |> DateTime.shift_zone!("Etc/UTC")

    assert DateTime.compare(appointment.start_time, expected) == :eq
    {:ok, refreshed, _} = open_booking(ctx)
    select_related(refreshed, ctx.related)
    refreshed |> element("#patient-selection-next") |> render_click()
    refreshed |> element("#consultation-#{ctx.a.type}") |> render_click()
    refreshed |> element("#consultation-next") |> render_click()
    refreshed |> form("#booking-date-form", %{date: Date.to_iso8601(ctx.date)}) |> render_change()
    refute has_element?(refreshed, "#slot-0900")
  end

  test "an occupied slot rejects assisted booking without partial identity or relationship",
       ctx do
    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    seed_booking!(ctx.a, ctx.related, ctx.date, "09:00:00")
    before = observable_state(ctx)
    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute has_element?(view, "#booking-result")
    assert patient_count("99999999") == 0
    assert observable_state(ctx) == before
    view |> element("button[phx-click='go_booking_step'][phx-value-step='3']") |> render_click()
    refute has_element?(view, "#slot-0900")
    view |> element("#slot-0930") |> render_click()
    view |> element("#slot-next") |> render_click()
    view |> element("#confirm-booking") |> render_click()
    assert has_element?(view, "#booking-result", "Turno confirmado")
    assert patient_count("99999999") == 1
  end

  test "DNI registered after search never creates a second patient or a booking", ctx do
    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    patient!("Paciente existente", "99999999")
    before = observable_state(ctx)

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute has_element?(view, "#booking-result")
    assert patient_count("99999999") == 1
    assert observable_state(ctx) == before
    view |> element("#retry-assisted-search") |> render_click()
    html = view |> form("#patient-dni-form", %{dni: "99999999"}) |> render_submit()
    assert html =~ "Paciente existente"
    refute has_element?(view, "#assisted-patient-form")
  end

  test "revoked session cannot confirm assisted registration", ctx do
    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)

    Repo.query!("UPDATE internal_account_sessions SET revoked_at = NOW() WHERE id = $1", [
      ctx.a.session.session_id
    ])

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute has_element?(view, "#booking-result")
    assert patient_count("99999999") == 0
  end

  test "#320 real absent-DNI journey persists only at confirmation with no personal access",
       ctx do
    before = record_counts()
    {:ok, other_before} = agenda(ctx.b, ctx.date)
    {:ok, view, html} = open_booking(ctx)
    refute html =~ "Consulta ajena"
    select_absent(view)
    assert record_counts() == before
    assert patient_count("99999999") == 0
    assert {:ok, patients} = Booking.list_professional_patients(ctx.a.session)
    refute Enum.any?(patients, &(&1.document_number == "99999999"))
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    assert record_counts() == before
    view |> element("#cancel-patient-selection") |> render_click()
    assert_redirect(view, "/profesional/agenda")
    assert record_counts() == before

    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "Turno confirmado"
    refute html =~ "Consulta ajena"
    refute html =~ "Bruno Integración"

    assert record_counts() == Map.new(before, fn {key, count} -> {key, count + 1} end)

    assert [[profile_id, nil, nil, false]] =
             Repo.query!(
               """
               SELECT pp.id, pp.email, pp.contact_email, pp.phone_verified
               FROM patient_profiles pp JOIN personas p ON p.id = pp.persona_id
               WHERE p.document_number = $1
               """,
               ["99999999"]
             ).rows

    assert [[1]] =
             Repo.query!(
               """
               SELECT count(*) FROM professional_patient_relationships
               WHERE professional_account_id = $1 AND patient_profile_id = $2
               """,
               [ctx.a.session.account_id, profile_id]
             ).rows

    assert [[0]] =
             Repo.query!(
               """
               SELECT count(*) FROM professional_patient_relationships
               WHERE professional_account_id = $1 AND patient_profile_id = $2
               """,
               [ctx.b.session.account_id, profile_id]
             ).rows

    assert {:ok, %{appointments: [appointment]}} = agenda(ctx.a, ctx.date)
    assert appointment.status == "confirmed"
    assert appointment.patient.first_name == "Luz"
    assert {:ok, ^other_before} = agenda(ctx.b, ctx.date)
  end

  test "#320 a weekly window closed after selection rejects without any assisted writes", ctx do
    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    before = record_counts()
    {:ok, other_before} = agenda(ctx.b, ctx.date)

    Repo.query!(
      "UPDATE agenda_settings SET weekly_availability = $1 WHERE owner_account_id = $2",
      [
        Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []}),
        ctx.a.session.account_id
      ]
    )

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute has_element?(view, "#booking-result")
    assert record_counts() == before
    assert patient_count("99999999") == 0
    assert {:ok, ^other_before} = agenda(ctx.b, ctx.date)
    view |> element("button[phx-click='go_booking_step'][phx-value-step='3']") |> render_click()
    assert has_element?(view, "#slot-next[disabled]")
    refute has_element?(view, "#slot-0900")
  end

  test "#320 an active request entered after selection still occupies the slot", ctx do
    {:ok, view, _} = open_booking(ctx)
    select_absent(view)
    advance_to_confirmation(view, ctx.a.type, ctx.date)

    {:ok, pending} =
      Booking.persist_appointment(%{
        professional_account_id: ctx.a.session.account_id,
        patient_profile_id: ctx.related,
        consultation_type_id: ctx.a.type,
        start_time: DateTime.new!(ctx.date, ~T[09:00:00], "Etc/UTC"),
        status: "requested"
      })

    before = record_counts()
    {:ok, other_before} = agenda(ctx.b, ctx.date)
    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute html =~ "Ana Integración"
    refute html =~ "Consulta ajena"
    refute has_element?(view, "#booking-result")
    assert record_counts() == before
    assert patient_count("99999999") == 0
    assert {:ok, ^other_before} = agenda(ctx.b, ctx.date)

    assert [["requested"]] =
             Repo.query!("SELECT status FROM appointments WHERE id = $1", [pending.id]).rows

    view |> element("button[phx-click='go_booking_step'][phx-value-step='3']") |> render_click()
    assert has_element?(view, "#slot-next[disabled]")
    refute has_element?(view, "#slot-0900")
  end

  test "exact DNI confirmation creates only the actor's relationship and preserves B's activity",
       ctx do
    {:ok, other_before} = agenda(ctx.b, ctx.date)
    {:ok, view, _} = open_booking(ctx)
    select_exact(view, ctx.searched)
    advance_to_confirmation(view, ctx.a.type, ctx.date)

    html =
      render_click(view, "confirm_booking", %{
        "patient_id" => ctx.related,
        "professional_id" => ctx.b.session.account_id,
        "consultation_type_id" => ctx.b.type,
        "start_time" => "forged"
      })

    assert html =~ "Turno confirmado"
    assert {:ok, %{appointments: [appointment]}} = agenda(ctx.a, ctx.date)
    assert appointment.patient.first_name == "Bruno"
    assert {:ok, ^other_before} = agenda(ctx.b, ctx.date)
    assert {:ok, patients} = Booking.list_professional_patients(ctx.a.session)
    assert Enum.any?(patients, &(&1.id == ctx.searched))
    {:ok, _, html} = open_booking(ctx)
    assert html =~ "30222333"
    refute html =~ "Consulta ajena"

    assert {:ok, %{professional_account_id: owner}} =
             Booking.get_professional_agenda(ctx.a.session, %{
               "date" => Date.to_iso8601(ctx.date),
               "professional_account_id" => ctx.b.session.account_id
             })

    assert owner == ctx.a.session.account_id
  end

  test "forged selections and premature confirmation leave public state unchanged", ctx do
    before = observable_state(ctx)
    {:ok, view, _} = open_booking(ctx)
    render_click(view, "confirm_booking", %{})
    render_click(view, "select_patient", %{"id" => to_string(ctx.searched)})
    refute has_element?(view, "#selected-patient")
    assert has_element?(view, "#patient-selection-next[disabled]")
    select_related(view, ctx.related)
    view |> element("#patient-selection-next") |> render_click()
    render_click(view, "select_consultation", %{"id" => ctx.b.type})
    assert has_element?(view, "#consultation-next[disabled]")
    view |> element("#consultation-#{ctx.a.type}") |> render_click()
    view |> element("#consultation-next") |> render_click()
    render_click(view, "select_booking_slot", %{"id" => "forged"})
    assert has_element?(view, "#slot-next[disabled]")
    assert observable_state(ctx) == before
  end

  test "a slot occupied after selection rejects atomically and allows availability refresh",
       ctx do
    {:ok, view, _} = open_booking(ctx)
    select_exact(view, ctx.searched)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    seed_booking!(ctx.a, ctx.related, ctx.date, "09:00:00")
    before = observable_state(ctx)
    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute has_element?(view, "#booking-result")
    assert observable_state(ctx) == before
    view |> element("button[phx-click='go_booking_step'][phx-value-step='3']") |> render_click()
    refute has_element?(view, "#slot-0900")
    assert has_element?(view, "#slot-next[disabled]")
    view |> element("#slot-0930") |> render_click()
    view |> element("#slot-next") |> render_click()
    view |> element("#confirm-booking") |> render_click()
    assert has_element?(view, "#booking-result", "Turno confirmado")
  end

  test "session revoked after selection cannot confirm or create a relationship", ctx do
    {:ok, view, _} = open_booking(ctx)
    select_exact(view, ctx.searched)
    advance_to_confirmation(view, ctx.a.type, ctx.date)
    before = observable_state(ctx)
    {:ok, %{session: observer}} = Sessions.create_session(ctx.a.session.account_id)

    Repo.query!("UPDATE internal_account_sessions SET revoked_at = NOW() WHERE id = $1", [
      ctx.a.session.session_id
    ])

    html = view |> element("#confirm-booking") |> render_click()
    assert html =~ "No se creó el turno"
    refute has_element?(view, "#booking-result")
    assert observable_state(%{ctx | a: %{ctx.a | session: observer}}) == before
  end

  defp open_booking(ctx), do: live(auth_conn(ctx.conn, ctx.a.token), "/profesional/agenda/crear")

  defp auth_conn(conn, token),
    do: conn |> Plug.Test.init_test_session(%{}) |> put_session(:internal_session_token, token)

  defp select_related(view, patient), do: view |> element("#patient-#{patient}") |> render_click()

  defp select_exact(view, patient) do
    view |> element("#tab-dni") |> render_click()
    view |> form("#patient-dni-form", %{dni: "30.222.333"}) |> render_submit()
    view |> element("#patient-#{patient}") |> render_click()
  end

  defp select_absent(view) do
    view |> element("#tab-dni") |> render_click()
    view |> form("#patient-dni-form", %{dni: "99.999.999"}) |> render_submit()

    view
    |> form("#assisted-patient-form", %{
      "patient" => %{
        "first_name" => "Luz",
        "last_name" => "Gómez",
        "birthdate" => "1990-01-01",
        "phone" => "+5491100000000",
        "email" => ""
      }
    })
    |> render_submit()
  end

  defp patient_count(dni) do
    Repo.query!("SELECT count(*) FROM personas WHERE document_number = $1", [dni]).rows
    |> hd()
    |> hd()
  end

  defp record_counts do
    Map.new(
      ~w(personas patient_profiles appointments professional_patient_relationships audit_events),
      fn table ->
        [[count]] = Repo.query!("SELECT count(*) FROM #{table}").rows
        {table, count}
      end
    )
  end

  defp advance_to_confirmation(view, type, date) do
    view |> element("#patient-selection-next") |> render_click()
    view |> element("#consultation-#{type}") |> render_click()
    view |> element("#consultation-next") |> render_click()
    view |> form("#booking-date-form", %{date: Date.to_iso8601(date)}) |> render_change()
    view |> element("#slot-0900") |> render_click()
    view |> element("#slot-next") |> render_click()
  end

  defp agenda(actor, date),
    do: Booking.get_professional_agenda(actor.session, %{"date" => Date.to_iso8601(date)})

  defp observable_state(ctx) do
    {Booking.list_professional_patients(ctx.a.session),
     Booking.list_professional_patients(ctx.b.session), agenda(ctx.a, ctx.date),
     agenda(ctx.b, ctx.date)}
  end

  defp professional!(name) do
    [[id]] =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
      """).rows

    {:ok, %{session: session, token: token}} = Sessions.create_session(id)
    type = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, 15000, '#112233', 1, 'active')
      """,
      [Ecto.UUID.dump!(type), id, name]
    )

    week =
      Map.new(
        ~w(monday tuesday wednesday thursday friday saturday sunday),
        &{&1, [%{"start" => "09:00", "end" => "12:00"}]}
      )

    Repo.query!(
      """
      INSERT INTO agenda_settings (owner_account_id, interval_minutes, approval_mode, weekly_availability)
      VALUES ($1, 30, 'manual', $2)
      """,
      [id, week]
    )

    %{session: session, token: token, type: type}
  end

  defp patient!(name, dni) do
    [[persona]] =
      Repo.query!(
        """
        INSERT INTO personas (first_name, last_name, document_type, document_number, birthdate)
        VALUES ($1, 'Integración', 'dni', $2, '1990-01-01') RETURNING id
        """,
        [name, dni]
      ).rows

    [[patient]] =
      Repo.query!(
        """
        INSERT INTO patient_profiles (persona_id, email, state, phone, phone_verified)
        VALUES ($1, $2, 'completed', '+5491100000000', true) RETURNING id
        """,
        [persona, "#{dni}@example.test"]
      ).rows

    patient
  end

  defp seed_booking!(actor, patient, date, time) do
    {:ok, result} =
      Booking.reserve_professional_appointment(actor.session, %{
        patient_id: patient,
        patient_document_number: patient_dni(patient),
        consultation_type_id: actor.type,
        start_time: DateTime.new!(date, Time.from_iso8601!(time), "Etc/UTC")
      })

    result
  end

  defp patient_dni(patient) do
    [[dni]] =
      Repo.query!(
        "SELECT p.document_number FROM personas p JOIN patient_profiles pp ON pp.persona_id = p.id WHERE pp.id = $1",
        [patient]
      ).rows

    dni
  end
end
