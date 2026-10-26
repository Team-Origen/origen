defmodule Origen.Booking.ProfessionalRegistration do
  @moduledoc false

  # Internal staged foundation, not a booking API. The final gate deliberately
  # rolls everything back until #286 supplies write-time block validation.
  alias Ecto.Multi
  alias Origen.Booking
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Sessions

  @fields ~w(first_name last_name document_number birthdate phone email consultation_type_id start_time)a
  @days ~w(monday tuesday wednesday thursday friday saturday sunday)

  @doc false
  def transaction(principal, attrs) do
    Multi.new()
    |> Multi.run(:owner, fn _repo, _changes -> owner(principal) end)
    |> Multi.run(:input, fn _repo, _changes -> input(attrs) end)
    |> Multi.run(:snapshot, fn repo, %{owner: owner, input: input} ->
      snapshot(repo, owner, input)
    end)
    |> Multi.insert(:persona, fn %{input: input} ->
      Persona.assisted_changeset(%Persona{}, Map.put(input, :document_type, "dni"))
    end)
    |> Multi.insert(:profile, fn %{persona: persona} ->
      PatientProfile.changeset(%PatientProfile{}, %{
        persona_id: persona.id,
        phone: persona.phone,
        contact_email: persona.email,
        state: "completed"
      })
    end)
    |> Multi.run(:appointment, fn _repo, changes ->
      Booking.persist_appointment(
        %{
          professional_account_id: changes.owner,
          patient_profile_id: changes.profile.id,
          consultation_type_id: changes.input.consultation_type_id,
          start_time: changes.input.start_time,
          status: "confirmed"
        },
        changes.snapshot
      )
    end)
    |> Multi.insert(:relationship, fn %{appointment: appointment} ->
      ProfessionalPatientRelationship.changeset(%ProfessionalPatientRelationship{}, %{
        professional_account_id: appointment.professional_account_id,
        patient_profile_id: appointment.patient_profile_id,
        first_appointment_id: appointment.id
      })
    end)
    |> Multi.run(:audit, fn repo, %{owner: owner, appointment: appointment} ->
      repo.query(
        """
        INSERT INTO audit_events (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
        VALUES ('professional', $1, 'appointment_confirmed', 'appointment', $2, 'succeeded')
        """,
        ["internal_account:#{owner}", "appointment:#{appointment.id}"]
      )
    end)
    |> Multi.run(:blocks, fn _repo, _changes -> {:error, :block_validation_unavailable} end)
  end

  defp owner(%{session_id: session_id, account_id: account_id}) do
    case Sessions.revalidate_principal(session_id, account_id) do
      {:ok, %{role: :professional, account_id: owner}} -> {:ok, owner}
      _ -> {:error, :unauthorized}
    end
  end

  defp owner(_), do: {:error, :unauthorized}

  defp input(attrs) when is_map(attrs) do
    allowed = @fields ++ Enum.map(@fields, &Atom.to_string/1)

    if Enum.all?(Map.keys(attrs), &(&1 in allowed)) do
      input = Map.new(@fields, &{&1, Map.get(attrs, &1, Map.get(attrs, Atom.to_string(&1)))})

      case input.start_time do
        %DateTime{utc_offset: 0, std_offset: 0} -> {:ok, input}
        _ -> {:error, :invalid_start_time}
      end
    else
      {:error, :invalid_fields}
    end
  end

  defp input(_), do: {:error, :invalid_fields}

  defp snapshot(repo, owner, input) do
    # Match configuration writers' lock order: agenda settings, then type.
    settings =
      repo.query!(
        """
        SELECT weekly_availability, booking_horizon_days, minimum_lead_minutes, interval_minutes
        FROM agenda_settings WHERE owner_account_id = $1 FOR UPDATE
        """,
        [owner]
      ).rows

    with [[week, horizon, lead, interval]] <- settings,
         {:ok, uuid} <- Ecto.UUID.dump(input.consultation_type_id),
         [[name, price, count]] <-
           repo.query!(
             """
             SELECT name, exact_price_ars, interval_count FROM consultation_types
             WHERE id = $1 AND owner_account_id = $2 AND status = 'active' FOR UPDATE
             """,
             [uuid, owner]
           ).rows,
         true <- available?(input.start_time, count * interval, week, horizon, lead, interval) do
      {:ok, %{name: name, exact_price_ars: price, duration_minutes: count * interval}}
    else
      _ -> {:error, :unavailable}
    end
  end

  # Weekly windows and horizon use organization-local dates; lead time compares
  # absolute instants. Weekly availability is not block coverage.
  defp available?(start, duration, week, horizon, lead, interval) do
    timezone = Application.fetch_env!(:origen, :organization_timezone)
    now = DateTime.utc_now()
    start = DateTime.shift_zone!(start, timezone)
    date = DateTime.to_date(start)
    finish = DateTime.add(start, duration, :minute)
    day = Enum.at(@days, Date.day_of_week(date) - 1)
    minute = start.hour * 60 + start.minute

    ends_within_day =
      DateTime.to_date(finish) == date or
        (DateTime.to_date(finish) == Date.add(date, 1) and
           DateTime.to_time(finish) == ~T[00:00:00])

    DateTime.compare(start, DateTime.add(now, lead, :minute)) != :lt and
      Date.diff(date, DateTime.to_date(DateTime.shift_zone!(now, timezone))) <= horizon and
      ends_within_day and start.second == 0 and
      elem(start.microsecond, 0) == 0 and rem(minute, interval) == 0 and
      Enum.any?(Map.get(week, day, []), fn window ->
        minute >= minutes(window["start"]) and minute + duration <= minutes(window["end"])
      end)
  end

  defp minutes(text) do
    [hour, minute] = String.split(text, ":")
    String.to_integer(hour) * 60 + String.to_integer(minute)
  end
end
