defmodule Origen.Booking.ProfessionalRegistrationTest do
  use Origen.DataCase, async: false

  alias Origen.Booking.ProfessionalRegistration
  alias Origen.Patients.{PatientProfile, Persona}
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

  test "atomic foundation builds confirmed booking but cannot commit before block integration", %{
    account_id: account_id,
    principal: principal,
    attrs: attrs
  } do
    assert {:error, :blocks, :block_validation_unavailable, changes} =
             ProfessionalRegistration.transaction(principal, attrs) |> Repo.transaction()

    assert changes.persona.document_number == "37111222"
    assert changes.profile.email == nil
    assert changes.profile.contact_email == nil
    refute changes.profile.phone_verified
    assert changes.appointment.status == "confirmed"
    assert changes.appointment.professional_account_id == account_id
    assert changes.appointment.snapshot_duration_minutes == 60
    assert changes.relationship.first_appointment_id == changes.appointment.id
    assert changes.audit.num_rows == 1

    refute Repo.get(Persona, changes.persona.id)
    refute Repo.get(PatientProfile, changes.profile.id)
    refute Repo.get(Origen.Booking.Appointment, changes.appointment.id)
    refute Repo.get(Origen.Booking.ProfessionalPatientRelationship, changes.relationship.id)

    assert [[0]] =
             Repo.query!(
               "SELECT count(*) FROM audit_events WHERE entity_ref = $1",
               ["appointment:#{changes.appointment.id}"]
             ).rows

    assert {:error, :owner, :unauthorized, %{}} =
             ProfessionalRegistration.transaction(%{}, attrs) |> Repo.transaction()

    for field <- [:actor, :professional_account_id, :status, :duration_minutes, :price] do
      assert {:error, :input, :invalid_fields, _} =
               ProfessionalRegistration.transaction(principal, Map.put(attrs, field, "forged"))
               |> Repo.transaction()
    end

    Repo.query!(
      "UPDATE agenda_settings SET weekly_availability = $1 WHERE owner_account_id = $2",
      [
        Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []}),
        account_id
      ]
    )

    assert {:error, :snapshot, :unavailable, rejected} =
             ProfessionalRegistration.transaction(principal, attrs) |> Repo.transaction()

    refute Map.has_key?(rejected, :persona)
    refute Repo.get_by(Persona, document_number: "37111222")
  end

  test "weekly windows use organization wall time rather than UTC", context do
    date = DateTime.to_date(context.attrs.start_time)
    set_window(context.account_id, date, "09:00", "10:00")

    assert {:error, :snapshot, :unavailable, _} =
             attempt(context, DateTime.new!(date, ~T[09:00:00], "Etc/UTC"))

    assert {:error, :blocks, :block_validation_unavailable, _} =
             attempt(context, DateTime.new!(date, ~T[12:00:00], "Etc/UTC"))
  end

  test "local weekday permits an exclusive midnight end but rejects an overrun", context do
    date = DateTime.to_date(context.attrs.start_time)
    set_window(context.account_id, date, "23:00", "24:00")
    next_date = Date.add(date, 1)

    assert {:error, :blocks, :block_validation_unavailable, _} =
             attempt(context, DateTime.new!(next_date, ~T[02:00:00], "Etc/UTC"))

    assert {:error, :snapshot, :unavailable, _} =
             attempt(context, DateTime.new!(next_date, ~T[02:30:00], "Etc/UTC"))
  end

  for denial <- [:revoked, :inactive, :wrong_role] do
    @denial denial
    test "#{denial} persisted principal cannot register or write", context do
      seed_existing_booking(context)

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

      assert {:error, :owner, :unauthorized, %{}} = reject_without_writes(context, context.attrs)
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
