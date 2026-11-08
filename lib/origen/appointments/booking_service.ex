defmodule Origen.Appointments.BookingService do
  @moduledoc """
  Application service for autonomous patient appointment reservations.

  The service validates the authenticated patient's completed profile, revalidates
  the professional, consultation type, schedule, and slot in the transaction, and
  delegates appointment persistence to the shared booking engine.
  """

  alias Origen.Appointments.DatabaseCalendar
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Patients
  alias Origen.Patients.PatientProfile
  alias Origen.Repo

  @type reservation_params :: %{
          required(:professional_id) => integer() | String.t(),
          required(:consultation_type_id) => String.t(),
          required(:date) => Date.t(),
          required(:slot) => map(),
          # Legacy callers may provide this, but reserve/2 ignores it.
          optional(:snapshot_override) => map(),
          optional(:now) => DateTime.t()
        }

  @type reservation_result :: %{
          appointment: Appointment.t(),
          appointment_id: integer(),
          status: String.t(),
          consultation_type_name: String.t(),
          duration_minutes: integer(),
          exact_price_ars: Decimal.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t()
        }

  @doc """
  Executes an autonomous appointment reservation for the authenticated patient.

  Patient identity is taken exclusively from `profile`; any patient id supplied
  in the params is ignored. Catalog snapshots are resolved by `Booking` from the
  persisted consultation type, never from client-provided snapshot data.
  The optional legacy `:snapshot_override` input remains accepted for older
  callers but is ignored; the persisted catalog name, duration, and price
  always win. The autonomous flow resolves status from the professional's
  approval mode and does not call `determine_initial_status/2`.
  """
  @spec reserve(PatientProfile.t() | nil, reservation_params()) ::
          {:ok, reservation_result()} | {:error, term()}
  def reserve(nil, _params), do: {:error, :unauthenticated}

  def reserve(%PatientProfile{} = profile, params) when is_map(params) do
    if Patients.ready_for_booking?(profile) do
      do_reserve(profile, params)
    else
      {:error, :patient_not_ready_for_booking}
    end
  end

  def reserve(%PatientProfile{}, _params), do: {:error, :invalid_reservation_params}

  defp do_reserve(profile, params) do
    with {:ok, date} <- fetch_date(params),
         {:ok, slot} <- fetch_slot(params),
         {:ok, start_datetime} <- build_start_datetime(date, slot),
         {:ok, professional_id} <- fetch_professional_id(params),
         {:ok, consultation_type_id} <- fetch_consultation_type_id(params),
         {:ok, now} <- fetch_now(params) do
      Repo.transaction(fn ->
        lock_eligible_professional!(professional_id)
        config = lock_booking_configuration!(professional_id, consultation_type_id)

        ensure_slot_available!(
          professional_id,
          profile.id,
          date,
          start_datetime,
          config.duration_minutes,
          now
        )

        attrs = %{
          patient_profile_id: profile.id,
          professional_account_id: professional_id,
          consultation_type_id: consultation_type_id,
          start_time: start_datetime,
          status: initial_status(config.approval_mode)
        }

        # Keep the legacy input compatible, but never pass snapshot_override to
        # the shared engine: persisted catalog values are the trust boundary.
        case Booking.persist_appointment(attrs, nil) do
          {:ok, appointment} ->
            establish_relationship!(appointment)

            %{
              appointment: appointment,
              appointment_id: appointment.id,
              status: appointment.status,
              consultation_type_name: appointment.snapshot_consultation_type_name,
              duration_minutes: appointment.snapshot_duration_minutes,
              exact_price_ars: appointment.snapshot_exact_price_ars,
              start_time: appointment.start_time,
              end_time: appointment.end_time
            }

          {:error, reason} ->
            Repo.rollback(map_collision(reason))
        end
      end)
    end
  end

  defp lock_eligible_professional!(professional_id) do
    case Repo.query(
           """
           SELECT a.id
           FROM internal_accounts a
           JOIN professional_profiles p ON p.owner_account_id = a.id
           WHERE a.id = $1 AND a.role = 'professional' AND a.state = 'active'
             AND NULLIF(btrim(p.first_name, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.last_name, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.specialty, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.license_type, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.license_number, E' \\t\\n\\r'), '') IS NOT NULL
           FOR SHARE OF a, p
           """,
           [professional_id]
         ) do
      {:ok, %{rows: [[^professional_id]]}} -> :ok
      {:ok, %{rows: []}} -> Repo.rollback(:professional_not_eligible)
      {:error, _} -> Repo.rollback(:unavailable)
    end
  end

  defp lock_booking_configuration!(professional_id, consultation_type_id) do
    case Repo.query(
           """
           SELECT ct.status, ct.interval_count, s.interval_minutes, s.approval_mode
           FROM consultation_types ct
           JOIN agenda_settings s ON s.owner_account_id = ct.owner_account_id
           WHERE ct.id = $1 AND ct.owner_account_id = $2
           FOR SHARE OF ct, s
           """,
           [Ecto.UUID.dump!(consultation_type_id), professional_id]
         ) do
      {:ok, %{rows: [["inactive", _interval_count, _agenda_interval, _approval_mode]]}} ->
        Repo.rollback(:consultation_type_inactive)

      {:ok, %{rows: [["active", interval_count, agenda_interval, approval_mode]]}}
      when is_integer(agenda_interval) and approval_mode in ["automatic", "manual"] ->
        %{duration_minutes: interval_count * agenda_interval, approval_mode: approval_mode}

      {:ok, %{rows: []}} ->
        Repo.rollback(:consultation_type_not_found)

      {:error, _} ->
        Repo.rollback(:unavailable)
    end
  end

  defp ensure_slot_available!(
         professional_id,
         patient_id,
         date,
         start_datetime,
         duration_minutes,
         now
       ) do
    case DatabaseCalendar.get_daily_schedule(professional_id, date,
           duration_minutes: duration_minutes,
           now: now
         ) do
      {:ok, %{slots: slots}} ->
        expected_end = DateTime.add(start_datetime, duration_minutes, :minute)

        available? =
          Enum.any?(slots, fn slot ->
            DateTime.compare(
              DateTime.new!(date, slot.start_time, "Etc/UTC"),
              start_datetime
            ) == :eq and
              DateTime.compare(DateTime.new!(date, slot.end_time, "Etc/UTC"), expected_end) ==
                :eq
          end)

        if available? do
          :ok
        else
          case Booking.check_overlaps(%{
                 professional_account_id: professional_id,
                 patient_profile_id: patient_id,
                 start_time: start_datetime,
                 end_time: expected_end
               }) do
            {:error, :professional_schedule_conflict} -> Repo.rollback(:overlap_detected)
            {:error, :patient_schedule_conflict} -> Repo.rollback(:overlap_detected)
            _ -> Repo.rollback(:invalid_slot_time)
          end
        end

      {:error, _reason} ->
        Repo.rollback(:availability_unavailable)
    end
  end

  defp initial_status("manual"), do: "requested"
  defp initial_status(_automatic), do: "confirmed"

  @deprecated "Use reserve/2; autonomous status is resolved from approval_mode and reserve/2 does not call this helper."
  @doc """
  Legacy compatibility helper for callers that still need the pre-#306 date rule.

  Dates on D-1 or D return `"confirmed"`; dates more than one day ahead return
  `"reserved"`. Autonomous `reserve/2` does not call this helper: it uses the
  professional's approval mode, returning `"confirmed"` for automatic approval
  and `"requested"` for manual approval at every date.
  """
  @spec determine_initial_status(Date.t(), DateTime.t()) :: String.t()
  def determine_initial_status(%Date{} = appointment_date, %DateTime{} = now) do
    if Date.diff(appointment_date, DateTime.to_date(now)) <= 1 do
      "confirmed"
    else
      "reserved"
    end
  end

  defp establish_relationship!(%Appointment{} = appointment) do
    %ProfessionalPatientRelationship{}
    |> ProfessionalPatientRelationship.changeset(%{
      professional_account_id: appointment.professional_account_id,
      patient_profile_id: appointment.patient_profile_id,
      first_appointment_id: appointment.id
    })
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:professional_account_id, :patient_profile_id]
    )
    |> case do
      {:ok, _relationship} ->
        :ok

      {:error, %Ecto.Changeset{} = changeset} ->
        if constraint_violation?(changeset, "professional_patient_relationships_unique_pair") do
          :ok
        else
          Repo.rollback({:relationship_validation_error, changeset})
        end
    end
  end

  defp constraint_violation?(changeset, constraint_name) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
      Keyword.get(opts, :constraint_name) == constraint_name
    end)
  end

  defp map_collision(:slot_already_booked), do: :overlap_detected
  defp map_collision(:patient_schedule_conflict), do: :overlap_detected
  defp map_collision({:validation_error, changeset}), do: map_collision_from_changeset(changeset)
  defp map_collision(reason), do: reason

  defp map_collision_from_changeset(changeset) do
    if constraint_violation?(changeset, "appointments_no_professional_overlap") or
         constraint_violation?(changeset, "appointments_no_patient_overlap") do
      :overlap_detected
    else
      {:validation_error, changeset}
    end
  end

  defp fetch_date(params) do
    case fetch_param(params, :date) do
      %Date{} = date -> {:ok, date}
      _ -> {:error, :invalid_slot_time}
    end
  end

  defp fetch_slot(params) do
    case fetch_param(params, :slot) do
      slot when is_map(slot) -> {:ok, slot}
      _ -> {:error, :invalid_slot_time}
    end
  end

  defp fetch_professional_id(params),
    do: parse_professional_id(fetch_param(params, :professional_id))

  defp fetch_consultation_type_id(params) do
    case Ecto.UUID.cast(fetch_param(params, :consultation_type_id)) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :invalid_consultation_type_id}
    end
  end

  defp fetch_now(params) do
    case Map.get(params, :now, DateTime.utc_now()) do
      %DateTime{} = now -> {:ok, now}
      _ -> {:error, :invalid_now}
    end
  end

  defp build_start_datetime(%Date{} = date, slot) do
    time_value =
      fetch_param(slot, :start_time) ||
        fetch_param(slot, :start_formatted)

    with {:ok, time} <- parse_slot_time(time_value),
         {:ok, datetime} <- DateTime.new(date, time, "Etc/UTC") do
      {:ok, datetime}
    else
      _ -> {:error, :invalid_slot_time}
    end
  end

  defp parse_slot_time(%Time{} = time), do: {:ok, time}

  defp parse_slot_time(value) when is_binary(value) do
    normalized = if byte_size(value) == 5, do: value <> ":00", else: value
    Time.from_iso8601(normalized)
  end

  defp parse_slot_time(_), do: {:error, :invalid_slot_time}

  defp parse_professional_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_professional_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> {:error, :invalid_professional_id}
    end
  end

  defp parse_professional_id(_), do: {:error, :invalid_professional_id}

  defp fetch_param(params, key) do
    Map.get(params, key, Map.get(params, Atom.to_string(key)))
  end
end
