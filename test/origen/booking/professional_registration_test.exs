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
