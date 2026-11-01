defmodule Origen.Booking.ProfessionalRegistrationTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Booking.{Appointment, ProfessionalPatientRelationship, ProfessionalRegistration}
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Sessions.InternalSession
  alias Origen.{ConsultationTypes, Repo, Sessions}

  setup do
    timezone = Application.fetch_env!(:origen, :organization_timezone)
    Application.put_env(:origen, :organization_timezone, "America/Argentina/Buenos_Aires")
    on_exit(fn -> Application.put_env(:origen, :organization_timezone, timezone) end)

    [[account_id]] =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
      """).rows

    {:ok, %{session: principal}} = Sessions.create_session(account_id)

    {:ok, type} =
      ConsultationTypes.create_type(principal, %{
        name: "Consulta",
        color: "#0A7C86",
        interval_count: 2,
        exact_price_ars: "12000"
      })

    attrs = %{
      first_name: "Ana",
      last_name: "Torres",
      document_number: "37.111.222",
      birthdate: ~D[1990-03-05],
      phone: "+5491155554444",
      consultation_type_id: type.id,
      start_time: next_weekday()
    }

    %{account_id: account_id, principal: principal, attrs: attrs}
  end

  test "registers absent patient and commits confirmed booking atomically", context do
    attrs = Map.put(context.attrs, :email, "ana@example.com")
    assert {:ok, result} = ProfessionalRegistration.register_and_book(context.principal, attrs)

    assert_durable_registration(result, context.account_id)
    assert result.persona.document_number == "37111222"
    assert result.profile.contact_email == "ana@example.com"
    assert result.profile.email == nil
    refute result.profile.phone_verified
    assert result.appointment.snapshot_duration_minutes == 60
    assert result.response == Booking.to_response(result.appointment, true)
  end

  test "contact email is optional", context do
    assert {:ok, result} =
             ProfessionalRegistration.register_and_book(
               context.principal,
               Map.put(context.attrs, :email, nil)
             )

    assert result.persona.email == nil
    assert result.profile.contact_email == nil
    assert_durable_registration(result, context.account_id)
  end

  for principal_kind <- [:map, :session] do
    @principal_kind principal_kind
    test "#{principal_kind} principal commits durably through the Booking context", context do
      principal =
        case @principal_kind do
          :map -> context.principal
          :session -> Repo.get!(InternalSession, context.principal.session_id)
        end

      assert {:ok, result} =
               Booking.register_and_reserve_professional_appointment(principal, context.attrs)

      assert_durable_registration(result, context.account_id)
    end
  end

  test "missing principal and forged fields reject without writes", context do
    assert {:error, :owner, :unauthorized, %{}} =
             reject_without_writes(%{context | principal: %{}}, context.attrs)

    for field <- [:actor, :professional_account_id, :status, :duration_minutes, :price] do
      assert {:error, :input, :invalid_fields, _} =
               reject_without_writes(context, Map.put(context.attrs, field, "forged"))
    end
  end

  test "weekly windows use organization wall time rather than UTC", context do
    date = DateTime.to_date(context.attrs.start_time)
    set_window(context.account_id, date, "09:00", "10:00")

    assert {:error, :snapshot, :unavailable, _} =
             attempt(context, DateTime.new!(date, ~T[09:00:00], "Etc/UTC"))

    assert {:ok, result} = attempt(context, DateTime.new!(date, ~T[12:00:00], "Etc/UTC"))
    assert_durable_registration(result, context.account_id)
  end

  test "local weekday permits an exclusive midnight end but rejects an overrun", context do
    date = DateTime.to_date(context.attrs.start_time)
    set_window(context.account_id, date, "23:00", "24:00")
    next_date = Date.add(date, 1)

    assert {:ok, result} = attempt(context, DateTime.new!(next_date, ~T[02:00:00], "Etc/UTC"))
    assert_durable_registration(result, context.account_id)

    assert {:error, :snapshot, :unavailable, _} =
             attempt(context, DateTime.new!(next_date, ~T[02:30:00], "Etc/UTC"))
  end

  test "invalid session identifiers and mismatched accounts reject maps and structs", context do
    session = Repo.get!(InternalSession, context.principal.session_id)

    for principal <- [
          %{context.principal | session_id: nil},
          %{session | id: nil},
          %{context.principal | session_id: -1},
          %{session | id: -1},
          %{context.principal | account_id: -1},
          %{session | account_id: -1}
        ] do
      assert {:error, :owner, :unauthorized, %{}} =
               reject_without_writes(%{context | principal: principal}, context.attrs)
    end
  end

  for denial <- [:revoked, :inactive, :wrong_role] do
    @denial denial
    test "#{denial} persisted principal cannot register or write", context do
      seed_existing_booking(context)
      session = Repo.get!(InternalSession, context.principal.session_id)

      case @denial do
        :revoked ->
          Repo.query!("UPDATE internal_account_sessions SET revoked_at = NOW() WHERE id = $1", [
            context.principal.session_id
          ])

        :inactive ->
          Repo.query!(
            """
            UPDATE internal_accounts SET state = 'pending_activation',
              password_hash = NULL, totp_secret = NULL, activated_at = NULL WHERE id = $1
            """,
            [context.account_id]
          )

        :wrong_role ->
          Repo.query!("UPDATE internal_accounts SET role = 'secretary' WHERE id = $1", [
            context.account_id
          ])
      end

      for principal <- [context.principal, session] do
        assert {:error, :owner, :unauthorized, %{}} =
                 reject_without_writes(%{context | principal: principal}, context.attrs)
      end
    end
  end

  test "duplicate normalized DNI reaches the database unique constraint without changing records",
       context do
    seed_existing_booking(context)
    attrs = %{context.attrs | document_number: "38.111-222"}

    assert {:error, :persona, changeset, changes} = reject_without_writes(context, attrs)
    assert changeset.valid? == false
    assert {_, metadata} = Keyword.fetch!(changeset.errors, :document_type)
    assert metadata[:constraint] == :unique
    assert metadata[:constraint_name] == "personas_document_unique"
    refute Map.has_key?(changes, :profile)
  end

  test "missing required identity and booking fields leave existing records untouched", context do
    seed_existing_booking(context)

    for field <- [:first_name, :last_name, :document_number, :birthdate, :phone] do
      assert {:error, :persona, changeset, _} =
               reject_without_writes(context, Map.delete(context.attrs, field))

      assert {_, metadata} = Keyword.fetch!(changeset.errors, field)
      assert metadata[:validation] == :required
    end

    assert {:error, :input, :invalid_start_time, _} =
             reject_without_writes(context, Map.delete(context.attrs, :start_time))

    assert {:error, :snapshot, :unavailable, _} =
             reject_without_writes(context, Map.delete(context.attrs, :consultation_type_id))
  end

  test "occupied slot rolls back the newly inserted identity and profile", context do
    existing = seed_existing_booking(context)
    attrs = %{context.attrs | start_time: existing.start_time}

    assert {:error, :appointment, :slot_already_booked, changes} =
             reject_without_writes(context, attrs)

    assert changes.persona.document_number == "37111222"
    refute Repo.get(Persona, changes.persona.id)
    refute Repo.get(PatientProfile, changes.profile.id)
    refute Map.has_key?(changes, :relationship)
  end

  test "foreign consultation type and client-selected agenda are denied", context do
    seed_existing_booking(context)

    [[foreign_id]] =
      Repo.query!("""
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
      """).rows

    {:ok, %{session: foreign}} = Sessions.create_session(foreign_id)

    {:ok, type} =
      ConsultationTypes.create_type(foreign, %{
        name: "Foreign consultation",
        color: "#0A7C86",
        interval_count: 2,
        exact_price_ars: "12000"
      })

    assert {:error, :snapshot, :unavailable, changes} =
             reject_without_writes(context, %{context.attrs | consultation_type_id: type.id})

    refute Map.has_key?(changes, :persona)

    assert {:error, :input, :invalid_fields, _} =
             reject_without_writes(
               context,
               Map.put(context.attrs, :professional_account_id, foreign_id)
             )
  end

  test "closed weekly agenda rejects without changing existing records", context do
    seed_existing_booking(context)

    Repo.query!(
      "UPDATE agenda_settings SET weekly_availability = $1 WHERE owner_account_id = $2",
      [
        Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []}),
        context.account_id
      ]
    )

    assert {:error, :snapshot, :unavailable, changes} =
             reject_without_writes(context, context.attrs)

    refute Map.has_key?(changes, :persona)
  end

  @tag skip: System.get_env("PROFESSIONAL_REGISTRATION_RACE") != "1"
  test "concurrent registration for the same DNI has one winner and rolls back duplicate loser" do
    fixture = registration_race_fixture()
    dni = race_document_number()
    payloads = List.duplicate(Map.put(fixture.attrs, :document_number, dni), 2)

    try do
      results = race_registrations(fixture.principal, payloads)
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert [{:error, {:persona, changeset}}] = Enum.filter(results, &match?({:error, _}, &1))
      assert {_, metadata} = Keyword.fetch!(changeset.errors, :document_type)
      assert metadata[:constraint] == :unique
      assert metadata[:constraint_name] == "personas_document_unique"

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        assert_race_records(fixture, [dni])
      end)
    after
      cleanup_registration_race(fixture, [dni])
    end
  end

  @tag skip: System.get_env("PROFESSIONAL_REGISTRATION_RACE") != "1"
  test "concurrent registration for the same slot on the same agenda has one winner and rolls back slot loser" do
    fixture = registration_race_fixture()
    documents = for _ <- 1..2, do: race_document_number()
    payloads = Enum.map(documents, &Map.put(fixture.attrs, :document_number, &1))

    try do
      results = race_registrations(fixture.principal, payloads)
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &(&1 == {:error, {:appointment, :slot_already_booked}})) == 1

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        assert_race_records(fixture, documents)
      end)
    after
      cleanup_registration_race(fixture, documents)
    end
  end

  defp race_document_number do
    suffix = Ecto.UUID.generate() |> String.replace("-", "") |> String.slice(0, 24)
    "RACE" <> String.upcase(suffix)
  end

  defp registration_race_fixture do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      [[account_id]] =
        Repo.query!("""
        INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
        VALUES ('professional', 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
        """).rows

      {:ok, %{session: principal}} = Sessions.create_session(account_id)

      {:ok, type} =
        ConsultationTypes.create_type(principal, %{
          name: "Race consultation",
          color: "#0A7C86",
          interval_count: 2,
          exact_price_ars: "12000"
        })

      start = next_weekday()
      set_window(account_id, DateTime.to_date(start), "09:00", "17:00")

      %{
        account_id: account_id,
        principal: principal,
        attrs: %{
          first_name: "Race",
          last_name: "Patient",
          birthdate: ~D[1990-03-05],
          phone: "+5491155554444",
          consultation_type_id: type.id,
          start_time: start
        }
      }
    end)
  end

  defp race_registrations(principal, payloads) do
    parent = self()

    tasks =
      for payload <- payloads do
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
            send(parent, {:ready, self()})

            receive do
              :go -> :ok
            after
              5000 -> raise "race barrier timeout"
            end

            Booking.register_and_reserve_professional_appointment(principal, payload)
          end)
        end)
      end

    try do
      ready =
        for _ <- tasks do
          assert_receive {:ready, pid}, 5000
          pid
        end

      Enum.each(ready, &send(&1, :go))
      Enum.map(tasks, &Task.await(&1, 10000))
    after
      Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))
    end
  end

  defp assert_race_records(fixture, documents) do
    account_id = fixture.account_id
    start = fixture.attrs.start_time
    personas = from p in Persona, where: p.document_number in ^documents
    assert Repo.aggregate(personas, :count) == 1

    assert Repo.aggregate(
             from(p in PatientProfile, join: i in subquery(personas), on: p.persona_id == i.id),
             :count
           ) == 1

    appointments = from a in Appointment, where: a.professional_account_id == ^account_id
    assert Repo.aggregate(appointments, :count) == 1
    assert Repo.aggregate(from(a in appointments, where: a.start_time == ^start), :count) == 1

    assert Repo.aggregate(
             from(r in ProfessionalPatientRelationship,
               where: r.professional_account_id == ^account_id
             ),
             :count
           ) == 1

    actor_ref = "internal_account:#{account_id}"

    assert Repo.aggregate(
             from(a in "audit_events",
               where: a.actor_kind == "professional" and a.actor_ref == ^actor_ref
             ),
             :count
           ) == 1
  end

  defp cleanup_registration_race(fixture, documents) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      account_id = fixture.account_id

      Repo.delete_all(
        from r in ProfessionalPatientRelationship, where: r.professional_account_id == ^account_id
      )

      Repo.delete_all(from a in Appointment, where: a.professional_account_id == ^account_id)

      persona_ids = from p in Persona, where: p.document_number in ^documents, select: p.id
      Repo.delete_all(from p in PatientProfile, where: p.persona_id in subquery(persona_ids))
      Repo.delete_all(from p in Persona, where: p.document_number in ^documents)

      for table <- ~w(consultation_types agenda_settings) do
        Repo.query!("DELETE FROM #{table} WHERE owner_account_id = $1", [account_id])
      end

      Repo.query!("DELETE FROM internal_account_sessions WHERE account_id = $1", [account_id])
      # Audit is append-only; retain its synthetic actor account for referential traceability.
    end)
  end

  defp assert_durable_registration(result, account_id) do
    assert result.appointment.status == "confirmed"
    assert result.appointment.professional_account_id == account_id
    assert result.profile.state == "completed"
    assert result.relationship.first_appointment_id == result.appointment.id
    assert Repo.get!(Appointment, result.appointment.id) == result.appointment
    assert Repo.get!(Persona, result.persona.id).document_number == result.persona.document_number
    assert Repo.get!(PatientProfile, result.profile.id) == result.profile

    assert Repo.get_by!(ProfessionalPatientRelationship,
             professional_account_id: account_id,
             patient_profile_id: result.profile.id
           ) == result.relationship

    entity_ref = "appointment:#{result.appointment.id}"

    assert %{event: "appointment_confirmed", result: "succeeded"} =
             Repo.one(
               from a in "audit_events",
                 where: a.entity_ref == ^entity_ref,
                 select: %{event: a.event, result: a.result}
             )
  end

  defp reject_without_writes(context, attrs) do
    before = persisted_records()
    result = ProfessionalRegistration.transaction(context.principal, attrs) |> Repo.transaction()
    assert persisted_records() == before
    result
  end

  defp persisted_records do
    # Compare complete rows, not only counts: updates to existing data must also fail the test.
    for table <-
          ~w(personas patient_profiles appointments professional_patient_relationships audit_events internal_accounts internal_account_sessions agenda_settings consultation_types),
        into: %{} do
      {table, Repo.query!("SELECT * FROM #{table} ORDER BY id").rows}
    end
  end

  defp seed_existing_booking(context) do
    persona =
      %Persona{}
      |> Persona.assisted_changeset(%{context.attrs | document_number: "38111222"})
      |> Repo.insert!()

    profile =
      %PatientProfile{}
      |> PatientProfile.changeset(%{
        persona_id: persona.id,
        phone: context.attrs.phone,
        state: "completed"
      })
      |> Repo.insert!()

    {:ok, appointment} =
      Origen.Booking.persist_appointment(%{
        professional_account_id: context.account_id,
        patient_profile_id: profile.id,
        consultation_type_id: context.attrs.consultation_type_id,
        start_time: DateTime.add(context.attrs.start_time, 60, :minute),
        status: "confirmed"
      })

    %Origen.Booking.ProfessionalPatientRelationship{}
    |> Origen.Booking.ProfessionalPatientRelationship.changeset(%{
      professional_account_id: context.account_id,
      patient_profile_id: profile.id,
      first_appointment_id: appointment.id
    })
    |> Repo.insert!()

    Repo.query!(
      """
      INSERT INTO audit_events (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
      VALUES ('professional', $1, 'appointment_confirmed', 'appointment', $2, 'succeeded')
      """,
      ["internal_account:#{context.account_id}", "appointment:#{appointment.id}"]
    )

    appointment
  end

  defp attempt(context, start) do
    ProfessionalRegistration.transaction(context.principal, %{context.attrs | start_time: start})
    |> Repo.transaction()
  end

  defp set_window(account_id, date, start, finish) do
    days = ~w(monday tuesday wednesday thursday friday saturday sunday)
    day = Enum.at(days, Date.day_of_week(date) - 1)
    week = Map.new(days, &{&1, []}) |> Map.put(day, [%{"start" => start, "end" => finish}])

    Repo.query!(
      "UPDATE agenda_settings SET weekly_availability = $1 WHERE owner_account_id = $2",
      [week, account_id]
    )
  end

  defp next_weekday do
    date = Date.add(Date.utc_today(), 3)

    date =
      if Date.day_of_week(date) > 5, do: Date.add(date, 8 - Date.day_of_week(date)), else: date

    DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
  end
end
